#!/usr/bin/env python3
"""Codex PreToolUse adapter for the shared branch evaluator and local command bans."""

import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


def deny(reason: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}))


def project_config(cwd: Path) -> tuple[Path, Path] | None:
    for root in (cwd, *cwd.parents):
        config = root / ".claude/project-profile/guardrails.json"
        if config.is_file():
            return root, config
    # Linked worktrees often omit the ignored project profile. Resolve their
    # common Git directory back to the primary checkout that owns the config.
    try:
        git = subprocess.run(["git", "-C", str(cwd), "rev-parse", "--path-format=absolute",
                              "--git-common-dir"], text=True, capture_output=True)
    except OSError:
        return None
    if git.returncode == 0:
        root = Path(git.stdout.strip()).resolve().parent
        config = root / ".claude/project-profile/guardrails.json"
        if config.is_file():
            return root, config
    return None


def shell_words(command: str) -> list[str]:
    # Keep quotes so a literal argument cannot masquerade as a command in the
    # conservative scan below. Substitutions are inspected separately.
    lexer = shlex.shlex(command, posix=False, punctuation_chars=";&|\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def executable_subcommands(command: str) -> list[str]:
    """Extract backticks and $(...) outside single quotes, including double quotes."""
    nested: list[str] = []
    quote = ""
    index = 0
    while index < len(command):
        char = command[index]
        if char == "\\" and quote != "'":
            index += 2
            continue
        if char in {"'", '"'}:
            if not quote:
                quote = char
            elif quote == char:
                quote = ""
            index += 1
            continue
        if quote != "'" and char == "`":
            end = index + 1
            while end < len(command) and command[end] != "`":
                end += 2 if command[end] == "\\" else 1
            if end < len(command):
                nested.append(command[index + 1:end])
                index = end + 1
                continue
        if quote != "'" and command.startswith("$(", index):
            start = index + 2
            end = start
            depth = 1
            inner_quote = ""
            while end < len(command) and depth:
                current = command[end]
                if current == "\\" and inner_quote != "'":
                    end += 2
                    continue
                if current in {"'", '"'}:
                    if not inner_quote:
                        inner_quote = current
                    elif inner_quote == current:
                        inner_quote = ""
                elif not inner_quote and command.startswith("$(", end):
                    depth += 1
                    end += 2
                    continue
                elif not inner_quote and current == ")":
                    depth -= 1
                end += 1
            if depth == 0:
                nested.append(command[start:end - 1])
                index = end
                continue
        index += 1
    return nested


def unquote_word(word: str) -> str:
    try:
        parsed = shlex.split(word)
    except ValueError:
        return word
    return parsed[0] if len(parsed) == 1 else word


def forbidden_in_segment(words: list[str], patterns: list[tuple[str, list[str]]]) -> str | None:
    plain = [unquote_word(word) for word in words]
    first = 0
    while first < len(plain) and re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*=.*", plain[first]):
        first += 1
    wrappers = {"env", "command", "exec", "nohup", "time", "sudo", "xargs",
                "timeout", "nice", "ionice", "stdbuf", "setsid", "doas",
                "chronic", "caffeinate"}
    wrapped = first < len(plain) and Path(plain[first]).name in wrappers
    for index, raw in enumerate(words):
        # Unknown programs may launch a visible forbidden command. Treat
        # unquoted command words after them as executable, but leave quoted
        # text in e.g. `echo "pnpm test"` alone.
        if index == 0 or not raw.startswith(("'", '"')):
            for name, pattern in patterns:
                if plain[index:index + len(pattern)] == pattern:
                    return name

        # A variable or command substitution may be the program name. Its
        # value is unknown, so the remaining forbidden arguments are enough.
        dynamic = raw.startswith(("$", "`")) or (
            raw.startswith('"') and plain[index].startswith("$")
            and (index == first or wrapped)
        )
        if dynamic:
            end = index
            if raw.startswith("`") and not raw.endswith("`"):
                while end + 1 < len(words) and not words[end].endswith("`"):
                    end += 1
            elif raw.startswith("$(") and not raw.endswith(")"):
                while end + 1 < len(words) and not words[end].endswith(")"):
                    end += 1
            for name, pattern in patterns:
                if plain[end + 1:end + len(pattern)] == pattern[1:]:
                    return name
    return None


def forbidden_match(command: str, patterns: list[tuple[str, list[str]]], depth: int = 0) -> str | None:
    if depth > 8:
        return next((name for name, _ in patterns if name in command), None)
    for nested_command in executable_subcommands(command):
        match = forbidden_match(nested_command, patterns, depth + 1)
        if match:
            return match
    try:
        words = shell_words(command)
    except ValueError:
        # A malformed quoted command with a configured forbidden phrase is unsafe to run.
        return next((name for name, _ in patterns if name in command), None)
    segment: list[str] = []
    for word in [*words, ";"]:
        if word and all(char in ";&|\n" for char in word):
            if segment:
                match = forbidden_in_segment(segment, patterns)
                if match:
                    return match
                for index, token in enumerate(segment):
                    if (token == "--command" or re.fullmatch(r"-[A-Za-z]*c", token)) and index + 1 < len(segment):
                        nested = forbidden_match(unquote_word(segment[index + 1]), patterns, depth + 1)
                        if nested:
                            return nested
                    if token == "eval" and index + 1 < len(segment):
                        nested = forbidden_match(" ".join(unquote_word(part) for part in segment[index + 1:]), patterns, depth + 1)
                        if nested:
                            return nested
                segment = []
        else:
            segment.append(word)
    return None


def main() -> int:
    raw = sys.stdin.read()
    try:
        event = json.loads(raw)
        if event.get("tool_name") != "Bash":
            return 0
        command = event["tool_input"]["command"]
        cwd = Path(event["cwd"]).resolve()
        if not isinstance(command, str):
            raise ValueError("tool_input.command must be a string")
    except (ValueError, KeyError, TypeError, AttributeError) as error:
        deny(f"[guardrails] deny — invalid Codex hook input: {error}")
        return 0

    found = project_config(cwd)
    if found is None:
        return 0
    project, config = found
    try:
        policy = json.loads(config.read_text())
        forbidden = policy.get("forbiddenCommands", [])
        if not isinstance(forbidden, list) or any(
            not isinstance(item, str) or not item.strip() for item in forbidden
        ):
            raise ValueError("forbiddenCommands must be an array of nonempty command prefixes")
        patterns = [(item, shlex.split(item)) for item in forbidden]
        if any(not words for _, words in patterns):
            raise ValueError("forbiddenCommands contains an empty command prefix")
    except (OSError, ValueError, TypeError) as error:
        deny(f"[guardrails] deny — invalid {config}: {error}")
        return 0

    match = forbidden_match(command, patterns)
    if match:
        deny(f"[guardrails] deny — forbidden command prefix {match!r} in {config}. Ask the user to run it or change the policy.")
        return 0

    evaluator = Path(__file__).with_name("branch-evaluator.sh")
    environment = dict(os.environ, CLAUDE_PROJECT_DIR=str(project))
    bash = os.environ.get("BASH") or shutil.which("bash") or "/bin/bash"
    try:
        result = subprocess.run([bash, str(evaluator)],
                                input=raw, text=True, capture_output=True, env=environment)
    except OSError as error:
        deny(f"[guardrails] deny — branch evaluator could not start: {error}")
        return 0
    if result.returncode == 2:
        sys.stderr.write(result.stderr)
        return 2
    if result.returncode != 0:
        deny(f"[guardrails] deny — branch evaluator failed (exit {result.returncode}).")
        return 0
    if not result.stdout.strip():
        return 0
    try:
        output = json.loads(result.stdout)
        decision = output["hookSpecificOutput"]["permissionDecision"]
        if decision == "ask":
            reason = output["hookSpecificOutput"]["permissionDecisionReason"]
            deny(f"{reason} Codex PreToolUse cannot prompt for this rule; ask the user to run it.")
        elif decision == "deny":
            print(result.stdout.strip())
        else:
            deny("[guardrails] deny — branch evaluator returned an unsupported decision.")
    except (ValueError, KeyError, TypeError):
        deny("[guardrails] deny — branch evaluator returned invalid output.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
