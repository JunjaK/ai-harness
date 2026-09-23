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
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def starts_with_forbidden(words: list[str], patterns: list[list[str]]) -> bool:
    while words and (re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*=.*", words[0])
                     or words[0] in {"env", "command", "exec", "nohup", "time", "sudo"}):
        words = words[1:]
    if words and words[0] == "xargs":
        words = words[1:]
        while words and words[0].startswith("-"):
            words = words[1:]
    return any(words[:len(pattern)] == pattern for pattern in patterns)


def forbidden_match(command: str, patterns: list[tuple[str, list[str]]], depth: int = 0) -> str | None:
    if depth > 3:
        return None
    try:
        words = shell_words(command)
    except ValueError:
        # A malformed quoted command with a configured forbidden phrase is unsafe to run.
        return next((name for name, _ in patterns if name in command), None)
    segment: list[str] = []
    for word in [*words, ";"]:
        if word and all(char in ";&|()\n" for char in word):
            if segment:
                match = next((name for name, pattern in patterns
                              if starts_with_forbidden(segment, [pattern])), None)
                if match:
                    return match
                for index, token in enumerate(segment):
                    if (token == "--command" or re.fullmatch(r"-[A-Za-z]*c", token)) and index + 1 < len(segment):
                        nested = forbidden_match(segment[index + 1], patterns, depth + 1)
                        if nested:
                            return nested
                    if token == "eval" and index + 1 < len(segment):
                        nested = forbidden_match(" ".join(segment[index + 1:]), patterns, depth + 1)
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
