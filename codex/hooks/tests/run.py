#!/usr/bin/env python3
"""Focused Codex guardrail tests; uses only the Python standard library."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).resolve().parents[1] / "guardrails.py"
PRESET = Path(__file__).resolve().parents[1] / "presets/default.json"


class GuardrailsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name) / "project"
        self.project.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.project)], check=True)
        subprocess.run(["git", "-C", str(self.project), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "commit", "-q",
                        "--allow-empty", "-m", "init"], check=True)
        self.config = self.project / ".claude/project-profile/guardrails.json"
        self.config.parent.mkdir(parents=True)
        self.policy = json.loads(PRESET.read_text())
        self.save()

    def save(self) -> None:
        self.config.write_text(json.dumps(self.policy))

    def decision(self, command: str, cwd: Path | None = None) -> tuple[str, str]:
        event = {"hook_event_name": "PreToolUse", "tool_name": "Bash",
                 "tool_input": {"command": command}, "cwd": str(cwd or self.project),
                 "permission_mode": "default"}
        result = subprocess.run(["python3", str(HOOK)], input=json.dumps(event),
                                text=True, capture_output=True, check=True)
        if not result.stdout:
            return "allow", ""
        output = json.loads(result.stdout)["hookSpecificOutput"]
        return output["permissionDecision"], output["permissionDecisionReason"]

    def test_main_commit_denied(self) -> None:
        self.assertEqual(self.decision("git commit -m x")[0], "deny")

    def test_stage_ask_becomes_deny(self) -> None:
        subprocess.run(["git", "-C", str(self.project), "switch", "-q", "-c", "stage"], check=True)
        decision, reason = self.decision("git push origin HEAD:stage")
        self.assertEqual(decision, "deny")
        self.assertIn("cannot prompt", reason)

    def test_forbidden_direct_chain_and_nested(self) -> None:
        self.policy["forbiddenCommands"] = ["pnpm test"]
        self.save()
        for command in ("pnpm test", "echo safe && pnpm test --runInBand",
                        "bash -c 'pnpm test'", "bash -lc 'pnpm test'", "echo $(pnpm test)",
                        "echo safe | xargs pnpm test"):
            with self.subTest(command=command):
                decision, reason = self.decision(command)
                self.assertEqual(decision, "deny")
                self.assertIn("forbidden command", reason)

    def test_literal_echo_is_allowed(self) -> None:
        self.policy["forbiddenCommands"] = ["pnpm test"]
        self.save()
        self.assertEqual(self.decision("echo 'pnpm test'")[0], "allow")
        self.assertEqual(self.decision("pnpm tester")[0], "allow")

    def test_feature_branch_allowed(self) -> None:
        subprocess.run(["git", "-C", str(self.project), "switch", "-q", "-c", "feature"], check=True)
        self.assertEqual(self.decision("git commit -m x")[0], "allow")

    def test_linked_worktree_uses_primary_config(self) -> None:
        worktree = Path(self.temp.name) / "linked"
        subprocess.run(["git", "-C", str(self.project), "worktree", "add", "-q",
                        "-b", "linked", str(worktree)], check=True)
        self.assertEqual(self.decision("git checkout main && git commit -m x", worktree)[0], "deny")

    def test_no_config_is_noop(self) -> None:
        self.config.unlink()
        self.assertEqual(self.decision("git commit -m x")[0], "allow")

    def test_invalid_forbidden_config_denied(self) -> None:
        self.policy["forbiddenCommands"] = "pnpm test"
        self.save()
        self.assertEqual(self.decision("echo safe")[0], "deny")


if __name__ == "__main__":
    unittest.main()
