#!/bin/bash
# Table-driven tests for hooks/browser-guard.sh. Needs jq.
# Run: bash hooks/browser-guard/tests/run.sh   (exit 1 when any case fails)

HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT=$(cd "$HERE/../../.." && pwd -P)
HOOK="$ROOT/hooks/browser-guard.sh"
BASH_BIN=${BASH:-bash}

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
NOJQ="$T/nojq"
mkdir -p "$NOJQ"
for t in cat grep sed head awk; do ln -s "$(command -v "$t")" "$NOJQ/$t"; done

PASS=0
FAIL=0

# run <tool> <command> [PATH] → OUT, CODE
run() {
  local json
  json=$(jq -cn --arg t "$1" --arg c "$2" '{hook_event_name: "PreToolUse", tool_name: $t, tool_input: {command: $c}}')
  OUT=$(printf '%s' "$json" | CLAUDE_PLUGIN_ROOT=/plugin PATH="${3:-$PATH}" "$BASH_BIN" "$HOOK" 2>"$T/err")
  CODE=$?
}

check() {  # check <name> <expect deny|allow> <tool> <command>
  run "$3" "$4"
  local got=allow
  [ "$CODE" -ne 0 ] && got="exit$CODE"
  printf '%s' "$OUT" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && got=deny
  if [ "$got" = "$2" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); printf 'FAIL %s: expected %s, got %s\n  out=%s\n  err=%s\n' "$1" "$2" "$got" "$OUT" "$(cat "$T/err")"; fi
}

NL=$'\n'

# --- denied programs ---
check "plain agent-browser" deny Bash "agent-browser open https://example.com"
check "npx -y agent-browser" deny Bash "npx -y agent-browser open https://example.com"
check "env assignment prefix" deny Bash "FOO=1 agent-browser snapshot -i"
check "after cd &&" deny Bash "cd /tmp && agent-browser open x"
check "aside after ;" deny Bash "echo hi; aside guide"
check "inside bash -c" deny Bash "bash -c \"agent-browser open x\""
check "inside \$(…)" deny Bash "u=\$(agent-browser get url)"
check "absolute path" deny Bash "/Users/x/.bun/bin/agent-browser --version"
check "timeout wrapper" deny Bash "timeout 10 agent-browser open x"
check "second heredoc-free line" deny Bash "ls${NL}aside guide"
check "eval quoted" deny Bash "eval \"agent-browser open x\""
check "eval bare" deny Bash "eval agent-browser open x"
check "xargs" deny Bash "xargs -n 1 agent-browser open < urls.txt"
check "bash --login -c" deny Bash "bash --login -c 'agent-browser open x'"
check "backslash-escaped name" deny Bash "a\\gent-browser open x"

# --- ego rules ---
check "clear all profiles" deny Bash "ego-browser import --clear-existing-profiles"
check "clear browser cookies" deny Bash "ego-browser nodejs <<'EOF'${NL}await page.cdp(\"Network.clearBrowserCookies\");${NL}EOF"
check "named space without profileId" deny Bash "ego-browser nodejs <<'EOF'${NL}const task = await taskSpace(\"inspect app\");${NL}EOF"
check "multi-line space without profileId" deny Bash "ego-browser nodejs <<'EOF'${NL}const task = await taskSpace(${NL}  \"inspect app\"${NL});${NL}EOF"
check "space by variable" deny Bash "ego-browser nodejs -e 'const t = await taskSpace(name);'"
check "profileId only inside a string" deny Bash "ego-browser nodejs -e 'await taskSpace(\"profileId\");'"
check "space before paren" deny Bash "ego-browser nodejs -e 'await taskSpace (\"x\");'"
check "quoted ego program, clear all" deny Bash "\"ego-browser\" import --clear-existing-profiles"
check "quoted ego program, CDP clear" deny Bash "\"ego-browser\" nodejs -e 'await page.cdp(\"Storage.clearCookies\")'"

# --- Playwright MCP ---
check "playwright mcp click" deny mcp__plugin_playwright_playwright__browser_click ""
check "playwright mcp navigate" deny mcp__playwright__browser_navigate ""

# --- allowed ---
check "grep for the name" allow Bash "grep -rn agent-browser ."
check "commit message with ;" allow Bash "git commit -m \"x; agent-browser removed\""
check "echo quoted aside" allow Bash "echo \"aside guide\""
check "ls a folder named aside" allow Bash "ls aside/"
check "ego version" allow Bash "ego-browser --version"
check "resume by number" allow Bash "ego-browser nodejs <<'EOF'${NL}const task = await taskSpace(12);${NL}EOF"
check "new space with profileId" allow Bash "ego-browser nodejs <<'EOF'${NL}const task = await taskSpace(\"qa\", { profileId: \"Profile 37\" });${NL}EOF"
check "multi-line with profileId" allow Bash "ego-browser nodejs <<'EOF'${NL}const task = await taskSpace(\"qa\", {${NL}  profileId: id,${NL}});${NL}EOF"
check "claim/takeOver/list spaces" allow Bash "ego-browser nodejs -e 'await claimTaskSpace(7); await takeOverTaskSpace(7); await listTaskSpaces();'"
check "taskSpace text without ego" allow Bash "grep -n 'taskSpace(' notes.md"
check "single-site clear" allow Bash "ego-browser nodejs -e 'await page.cdp(\"Storage.clearDataForOrigin\", {});'"
check "playwright test suite" allow Bash "bunx playwright test"
check "qa-profile script" allow Bash "node /plugin/skills/browser-e2e/scripts/qa-profile.mjs --space-name qa"
check "shorthand profileId" allow Bash "ego-browser nodejs -e 'const t = await taskSpace(\"qa\", { profileId });'"
check "aside as a selector in an ego script" allow Bash "ego-browser nodejs -e 'await task.page(\"p1\").waitForSelector(\"aside\");'"
check "grep CDP name without ego" allow Bash "grep -rn Network.clearBrowserCookies docs/"
check "other tool" allow Read ""
check "chrome extension tool" allow mcp__claude-in-chrome__navigate ""

# --- without jq: a Bash command that mentions a browser CLI is denied (exit 2), others pass; MCP still blocks ---
run Bash "agent-browser open x" "$NOJQ"
if [ "$CODE" -eq 2 ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL no-jq bash browser: code=$CODE out=$OUT"; fi
run Bash "ls -la" "$NOJQ"
if [ "$CODE" -eq 0 ] && [ -z "$OUT" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL no-jq bash other: code=$CODE out=$OUT"; fi
run mcp__plugin_playwright_playwright__browser_click "" "$NOJQ"
if [ "$CODE" -eq 2 ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL no-jq mcp: code=$CODE out=$OUT"; fi

echo "browser-guard: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
