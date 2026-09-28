#!/usr/bin/env python3
"""Minimal MCP stdio server that runs the harness's Jev checks with the plugin settings.

Tools:
  qa_crosscheck — second opinion on one QA verdict (called by agentic-testing).
  stop_gate     — the Stop check, called by the plugin's `mcp_tool` Stop hook, not by the model.

Claude Code fills this server's MCP `env` (see .claude-plugin/plugin.json) from user or managed
settings and the OS credential store, and that env replaces anything a project's settings.json `env`
sets. The Bash tool never receives plugin settings, and command hooks can inherit a project-supplied
CLAUDE_PLUGIN_OPTION_* when an option is unset, so both checks run here. The scripts in hooks/jev/
hold the check logic; the key never enters the agent's context.

Protocol: newline-delimited JSON-RPC 2.0 over stdin/stdout (MCP stdio transport). Standard library only.
Tests: python3 mcp/tests/test_jev_server.py
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = {
    "qa_crosscheck": os.path.join(ROOT, "hooks", "jev", "qa-crosscheck.sh"),
    "stop_gate": os.path.join(ROOT, "hooks", "jev", "stop-gate.sh"),
}
OPTIONS = ("CLAUDE_PLUGIN_OPTION_JEV_API_KEY", "CLAUDE_PLUGIN_OPTION_JEV_QA_CROSSCHECK",
           "CLAUDE_PLUGIN_OPTION_JEV_STOP_GATE", "CLAUDE_PROJECT_DIR")
FALLBACK_PROTOCOL = "2025-06-18"

QA_TOOL = {
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

STOP_TOOL = {
    "name": "stop_gate",
    "description": ("Internal: called by the plugin's Stop hook with the hook's input. Do not call it yourself. "
                    "It accepts only this project's transcript for the given session and returns nothing otherwise."),
    "inputSchema": {
        "type": "object",
        "properties": {
            "stop_hook_active": {"type": ["string", "boolean"]},
            "last_assistant_message": {"type": "string"},
            "transcript_path": {"type": "string"},
            "session_id": {"type": "string"},
        },
    },
}
TOOLS = {"qa_crosscheck": QA_TOOL, "stop_gate": STOP_TOOL}


def run_script(name, payload, session_id=""):
    """Run a hooks/jev script with the settings from this server's env; return its stdout."""
    env = dict(os.environ)
    # An unset option can arrive as an unsubstituted placeholder; treat it as unset.
    for option in OPTIONS:
        if env.get(option, "").startswith("${"):
            env.pop(option)
    if session_id:
        env["CLAUDE_CODE_SESSION_ID"] = session_id
    try:
        proc = subprocess.run(
            ["bash", SCRIPTS[name]],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env=env,
            cwd=env.get("CLAUDE_PROJECT_DIR") or None,
            timeout=30,
        )
        return proc.stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        return "" if name == "stop_gate" else json.dumps(
            {"status": "skipped", "reason": "%s failed: %s" % (name, type(exc).__name__)})


UUID_JSONL = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jsonl")


def transcript_allowed(path, session_id):
    """stop_gate reads the file it is given, and the model can call the tool too. Accept only this
    project's Claude Code transcript for the given session: <config>/projects/<project dir with every
    non-alphanumeric character as "-">/<session_id>.jsonl, after resolving symlinks."""
    project = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not (path and session_id and project):
        return False
    real = os.path.realpath(path)
    if not UUID_JSONL.fullmatch(os.path.basename(real)) or os.path.basename(real) != session_id + ".jsonl":
        return False
    config = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.join(os.path.expanduser("~"), ".claude")
    projects = os.path.realpath(os.path.join(config, "projects"))
    dirs = {os.path.join(projects, re.sub(r"[^A-Za-z0-9]", "-", p)) for p in (project, os.path.realpath(project))}
    return os.path.dirname(real) in dirs


def call_tool(name, args):
    if name == "qa_crosscheck":
        out = run_script(name, {k: args.get(k, "") for k in ("scenario", "observation", "verdict")})
        lines = out.splitlines()
        return lines[-1] if lines else json.dumps({"status": "skipped", "reason": "no output from qa-crosscheck.sh"})
    # stop_gate: the hook passes its own input; the script's stdout is the hook's output (often empty).
    if not transcript_allowed(args.get("transcript_path", ""), args.get("session_id", "")):
        return ""
    active = args.get("stop_hook_active")
    payload = {
        "hook_event_name": "Stop",
        "stop_hook_active": active is True or str(active).lower() == "true",
        "last_assistant_message": args.get("last_assistant_message", ""),
        "transcript_path": args.get("transcript_path", ""),
    }
    return run_script(name, payload, args.get("session_id", ""))


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
        return {"tools": list(TOOLS.values())}
    if method == "tools/call":
        params = msg.get("params") or {}
        if params.get("name") not in TOOLS:
            raise LookupError("unknown tool: %s" % params.get("name"))
        text = call_tool(params["name"], params.get("arguments") or {})
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
