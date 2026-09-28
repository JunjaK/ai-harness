#!/usr/bin/env python3
"""Minimal MCP stdio server exposing the harness's Jev QA cross-check as a typed tool.

The Bash tool never receives plugin settings, and the Jev key is a sensitive userConfig value that
Claude Code substitutes only into hook and MCP configuration. This server receives the settings
through its MCP `env` (see .claude-plugin/plugin.json) and runs hooks/jev/qa-crosscheck.sh with
them, so the check logic stays in one place and the key never enters the agent's context.

Protocol: newline-delimited JSON-RPC 2.0 over stdin/stdout (MCP stdio transport). Standard library only.
Tests: python3 mcp/tests/test_jev_server.py
"""

import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "hooks", "jev", "qa-crosscheck.sh")
FALLBACK_PROTOCOL = "2025-06-18"

TOOL = {
    "name": "qa_crosscheck",
    "description": (
        "Jev second opinion on one QA verdict. Pass the scenario's expected outcome, the RAW observed "
        "evidence (commands, outputs, reload or data-store checks — not a summary), and your verdict. "
        "Returns status agree / contested / uncertain / skipped with Jev's label and confidence. "
        "Advisory: never change your verdict because of it; report a contested result to the user."
    ),
    "inputSchema": {
        "type": "object",
        "properties": {
            "scenario": {"type": "string", "description": "Expected outcome being verified"},
            "observation": {"type": "string", "description": "Raw observed evidence"},
            "verdict": {"type": "string", "enum": ["passed", "failed", "blocked"]},
        },
        "required": ["scenario", "observation", "verdict"],
        "additionalProperties": False,
    },
}


def run_crosscheck(args):
    env = dict(os.environ)
    # Empty or unsubstituted values count as unset.
    for name in ("CLAUDE_PLUGIN_OPTION_JEV_API_KEY", "CLAUDE_PLUGIN_OPTION_JEV_QA_CROSSCHECK", "CLAUDE_PROJECT_DIR"):
        if env.get(name, "").startswith("${"):
            env.pop(name)
    try:
        proc = subprocess.run(
            ["bash", SCRIPT],
            input=json.dumps(args),
            capture_output=True,
            text=True,
            env=env,
            cwd=env.get("CLAUDE_PROJECT_DIR") or None,
            timeout=30,
        )
        out = proc.stdout.strip().splitlines()
        return out[-1] if out else json.dumps({"status": "skipped", "reason": "no output from qa-crosscheck.sh"})
    except (OSError, subprocess.SubprocessError) as exc:
        return json.dumps({"status": "skipped", "reason": "qa-crosscheck.sh failed: %s" % type(exc).__name__})


def handle(msg):
    method = msg.get("method")
    if method == "initialize":
        requested = (msg.get("params") or {}).get("protocolVersion") or FALLBACK_PROTOCOL
        return {
            "protocolVersion": requested,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "jev", "version": "1"},
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": [TOOL]}
    if method == "tools/call":
        params = msg.get("params") or {}
        if params.get("name") != TOOL["name"]:
            raise LookupError("unknown tool: %s" % params.get("name"))
        args = params.get("arguments") or {}
        text = run_crosscheck({k: args.get(k, "") for k in ("scenario", "observation", "verdict")})
        return {"content": [{"type": "text", "text": text}], "isError": False}
    raise LookupError("method not found: %s" % method)


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if "id" not in msg:  # notification (e.g. notifications/initialized): no reply
            continue
        try:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "result": handle(msg)}
        except LookupError as exc:
            reply = {"jsonrpc": "2.0", "id": msg["id"], "error": {"code": -32601, "message": str(exc)}}
        sys.stdout.write(json.dumps(reply) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
