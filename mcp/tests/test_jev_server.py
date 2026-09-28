#!/usr/bin/env python3
"""Stdio tests for mcp/jev_server.py with a fake curl (no network).

Run: python3 mcp/tests/test_jev_server.py   (exit 1 when any case fails; needs bash and jq)
"""

import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SERVER = os.path.join(ROOT, "mcp", "jev_server.py")
FAILS = []


def check(name, ok, detail=""):
    if not ok:
        FAILS.append(name)
        print("FAIL: %s %s" % (name, detail))


def session(env, messages):
    """Send messages (one JSON per line) and return the replies keyed by id."""
    proc = subprocess.run(
        [sys.executable, SERVER],
        input="".join(json.dumps(m) + "\n" for m in messages),
        capture_output=True, text=True, env=env, timeout=60,
    )
    replies = {}
    for line in proc.stdout.splitlines():
        msg = json.loads(line)
        replies[msg["id"]] = msg
    return replies


def call(i, args):
    return {"jsonrpc": "2.0", "id": i, "method": "tools/call", "params": {"name": "qa_crosscheck", "arguments": args}}


def tool_json(reply):
    return json.loads(reply["result"]["content"][0]["text"])


with tempfile.TemporaryDirectory() as tmp:
    tmp = os.path.realpath(tmp)
    binary = os.path.join(tmp, "bin")
    project = os.path.join(tmp, "proj")
    os.makedirs(binary)
    os.makedirs(project)
    with open(os.path.join(binary, "curl"), "w") as f:
        f.write('#!/bin/bash\nwhile [ $# -gt 0 ]; do [ "$1" = -K ] && cat "$2" >"$FAKE_DIR/config"; shift; done\n'
                'cat >"$FAKE_DIR/body.json"\n'
                'printf \'{"model":"jev-test","answers":{"verdict":{"type":"choice","choice":"insufficient_evidence",'
                '"confidence":0.98,"probabilities":{"insufficient_evidence":0.98}}}}\'\n')
    os.chmod(os.path.join(binary, "curl"), 0o755)

    base = {"PATH": binary + os.pathsep + os.environ["PATH"], "FAKE_DIR": tmp, "CLAUDE_PLUGIN_DATA": os.path.join(tmp, "data"),
            "CLAUDE_PROJECT_DIR": project}
    on = dict(base, CLAUDE_PLUGIN_OPTION_JEV_API_KEY="test-key", CLAUDE_PLUGIN_OPTION_JEV_QA_CROSSCHECK="true")
    args = {"scenario": "Value persists after reload", "observation": "PUT 200, toast Saved", "verdict": "passed"}

    r = session(on, [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        call(3, args),
        {"jsonrpc": "2.0", "id": 4, "method": "nope"},
        {"jsonrpc": "2.0", "id": 5, "method": "tools/call", "params": {"name": "other", "arguments": {}}},
        {"jsonrpc": "2.0", "id": 6, "method": "ping"},
    ])
    check("initialize echoes protocol and advertises tools",
          r[1]["result"]["protocolVersion"] == "2025-06-18" and "tools" in r[1]["result"]["capabilities"])
    check("notification gets no reply", set(r) == {1, 2, 3, 4, 5, 6}, str(sorted(r)))
    tools = r[2]["result"]["tools"]
    check("tools/list has qa_crosscheck with required fields",
          len(tools) == 1 and tools[0]["name"] == "qa_crosscheck"
          and tools[0]["inputSchema"]["required"] == ["scenario", "observation", "verdict"])
    out = tool_json(r[3])
    check("tools/call returns the script's verdict", out.get("status") == "contested" and out.get("jev") == "insufficient_evidence", str(out))
    with open(os.path.join(tmp, "config")) as f:
        check("key from the MCP env reaches curl", "Bearer test-key" in f.read())
    with open(os.path.join(tmp, "body.json")) as f:
        body = json.load(f)
    check("scenario and observation sent, verdict not", body["state"] == {"scenario": args["scenario"], "observation": args["observation"]})
    check("unknown method → error", r[4].get("error", {}).get("code") == -32601)
    check("unknown tool → error", r[5].get("error", {}).get("code") == -32601)
    check("ping → empty result", r[6].get("result") == {})
    check("log written to CLAUDE_PLUGIN_DATA", os.path.exists(os.path.join(tmp, "data", "jev.log")))

    # An unset userConfig value (unsubstituted placeholder or empty) must behave as unset.
    for label, key in (("placeholder key", "${user_config.jev_api_key}"), ("empty key", "")):
        env = dict(on, CLAUDE_PLUGIN_OPTION_JEV_API_KEY=key)
        out = tool_json(session(env, [call(1, args)])[1])
        check("%s → skipped naming the key" % label, out.get("status") == "skipped" and "no Jev API key" in out.get("reason", ""), str(out))

    off = dict(on, CLAUDE_PLUGIN_OPTION_JEV_QA_CROSSCHECK="false")
    out = tool_json(session(off, [call(1, args)])[1])
    check("switch off → skipped", out.get("status") == "skipped" and "jev_qa_crosscheck is off" in out.get("reason", ""), str(out))

print("jev MCP tests: %d failed" % len(FAILS))
sys.exit(1 if FAILS else 0)
