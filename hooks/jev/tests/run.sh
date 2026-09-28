#!/bin/bash
# Table-driven tests for hooks/jev/{stop-gate,qa-crosscheck}.sh with a fake curl (no network).
# Run: bash hooks/jev/tests/run.sh   (exit 1 when any case fails; needs jq)

HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT=$(cd "$HERE/../../.." && pwd -P)
GATE="$ROOT/hooks/jev/stop-gate.sh"
CROSS="$ROOT/hooks/jev/qa-crosscheck.sh"
BASH_BIN=${BASH:-bash}

T=$(mktemp -d)
T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
PROJ="$T/proj"
BIN="$T/bin"
CFG="$PROJ/.claude/project-profile/jev.json"
mkdir -p "$PROJ/.claude/project-profile" "$BIN"
# Plugin settings as Claude Code exports them to hooks; each case may override one.
KEY=test-key SG=true QC=true

# Fake curl: records the request body, argv and -K config, answers with $FAKE_RESP, or fails when FAKE_FAIL=1.
cat >"$BIN/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" >"$FAKE_DIR/args"
while [ $# -gt 0 ]; do [ "$1" = -K ] && cat "$2" >"$FAKE_DIR/config"; shift; done
cat >"$FAKE_DIR/body.json"
echo called >>"$FAKE_DIR/calls"
[ "${FAKE_FAIL:-0}" = 1 ] && exit 7
printf '%s' "$FAKE_RESP"
EOF
chmod +x "$BIN/curl"

noul() {  # noul <P(claims verified)> <P(evidence supports)>
  printf '{"model":"jev-test","answers":{"claims_verified":{"type":"noul","noul":%s},"evidence_supports":{"type":"noul","noul":%s}}}' "$1" "$2"
}
choice() { printf '{"model":"jev-test","answers":{"verdict":{"type":"choice","choice":"%s","confidence":%s,"probabilities":{"%s":0.9}}}}' "$1" "$2" "$1"; }

# Transcript: an earlier turn, then the current prompt, one Bash call and its result.
TR="$T/transcript.jsonl"
cat >"$TR" <<'EOF'
{"type":"user","message":{"role":"user","content":"old request"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"old1","name":"Bash","input":{"command":"echo OLD_EVIDENCE"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"old1","content":"OLD_EVIDENCE"}]}}
{"type":"user","message":{"role":"user","content":"세션 리다이렉트 고쳐줘"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"pnpm vitest run src/utils"}}]}}
{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":[{"type":"text","text":"Tests 12 passed (12)"}]}]}}
EOF

PASS=0
FAIL=0
check() {  # check <name> <condition result 0/1>
  if [ "$2" = 0 ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: $1"; echo "  out: $OUT"; fi
}

# gate <stop_hook_active> <last_assistant_message> [transcript] → OUT, CALLS
gate() {
  rm -f "$T/calls" "$T/body.json"
  OUT=$(jq -cn --arg m "$2" --arg tr "${3:-$TR}" --argjson a "$1" \
      '{hook_event_name: "Stop", stop_hook_active: $a, last_assistant_message: $m, transcript_path: $tr}' |
    CLAUDE_PLUGIN_OPTION_JEV_API_KEY="$KEY" CLAUDE_PLUGIN_OPTION_JEV_STOP_GATE="$SG" CLAUDE_PLUGIN_DATA="$T/data" \
      CLAUDE_PROJECT_DIR="$PROJ" PATH="$BIN:$PATH" FAKE_DIR="$T" \
      FAKE_RESP="${FAKE_RESP:-}" FAKE_FAIL="${FAKE_FAIL:-0}" "$BASH_BIN" "$GATE")
  CALLS=$([ -f "$T/calls" ] && wc -l <"$T/calls" | tr -d ' ' || echo 0)
}
cross() {  # cross <input JSON> → OUT
  rm -f "$T/calls"
  OUT=$(printf '%s' "$1" |
    CLAUDE_PLUGIN_OPTION_JEV_API_KEY="$KEY" CLAUDE_PLUGIN_OPTION_JEV_QA_CROSSCHECK="$QC" CLAUDE_PLUGIN_DATA="$T/data" \
      CLAUDE_PROJECT_DIR="$PROJ" PATH="$BIN:$PATH" FAKE_DIR="$T" \
      FAKE_RESP="${FAKE_RESP:-}" FAKE_FAIL="${FAKE_FAIL:-0}" "$BASH_BIN" "$CROSS")
}
CLAIM="다 고쳤습니다. E2E로 확인 완료."

# --- stop-gate ---
SG=false FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM"
check "jev_stop_gate off → silent, no call" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"

KEY= FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM"
check "no key → silent, no call" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"

echo '{"disabled":true}' >"$CFG"
FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM"
check "project opted out in jev.json → silent, no call" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"

# A committed jev.json cannot switch a check on, supply a key, or move the endpoint.
jq -n '{stopGate: {enabled: true}, qaCrossCheck: {enabled: true}, keyFile: "/etc/passwd", endpoint: "https://attacker.example/x"}' >"$CFG"
SG=false FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM"
check "jev.json enabled flags ignored while the plugin switch is off" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"
KEY= FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM"
check "jev.json keyFile ignored without a plugin key" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"
rm -f "$CFG"

FAKE_RESP=$(noul 0.95 0.05) gate true "$CLAIM"
check "stop_hook_active → silent, no call" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"

FAKE_RESP=$(noul 0.95 0.05) gate false "파일 구조를 정리한 표입니다."
check "no claim words → no call" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"

FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM"
check "claimed, unsupported (score 0.9) → additionalContext nudge" \
  "$(printf '%s' "$OUT" | jq -e '.hookSpecificOutput.hookEventName == "Stop" and (.hookSpecificOutput.additionalContext | test("score 0.9"))' >/dev/null; echo $?)"
check "body carries current prompt, command and result" \
  "$(jq -e '.state.request == "세션 리다이렉트 고쳐줘" and (.state.evidence | test("\\$ pnpm vitest run src/utils")) and (.state.evidence | test("12 passed")) and .model == "jev-latest"' "$T/body.json" >/dev/null; echo $?)"
check "body excludes the earlier turn" "$(jq -e '.state.evidence | test("OLD_EVIDENCE") | not' "$T/body.json" >/dev/null; echo $?)"

FAKE_RESP=$(noul 0.95 0.9) gate false "$CLAIM"
check "claimed and supported (score 0.1) → silent" "$([ -z "$OUT" ] && [ "$CALLS" = 1 ]; echo $?)"

FAKE_RESP=$(noul 0.5 0.5) gate false "$CLAIM"
check "score 0.25 below default 0.6 → silent" "$([ -z "$OUT" ]; echo $?)"

FAKE_RESP='{"model":"jev-test","answers":{"claims_verified":{"type":"noul","noul":0.9}}}' gate false "$CLAIM"
check "one answer missing → fail-open" "$([ -z "$OUT" ]; echo $?)"

echo '{"stopGate":{"enabled":true,"threshold":0.2},"model":"jev-9.9.9"}' >"$CFG"
FAKE_RESP=$(noul 0.5 0.5) gate false "$CLAIM"
check "custom threshold and pinned model" \
  "$([ -n "$OUT" ] && jq -e '.model == "jev-9.9.9"' "$T/body.json" >/dev/null; echo $?)"

echo '{"stopGate":{"enabled":true}}' >"$CFG"
FAKE_FAIL=1 gate false "$CLAIM"
check "network failure → fail-open" "$([ -z "$OUT" ]; echo $?)"

FAKE_RESP='{"error":"bad"}' gate false "$CLAIM"
check "malformed response → fail-open" "$([ -z "$OUT" ]; echo $?)"

FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM" "$T/missing.jsonl"
check "missing transcript → no call" "$([ -z "$OUT" ] && [ "$CALLS" = 0 ]; echo $?)"

jq -n '{endpoint: "https://attacker.example/x", timeoutSeconds: "5 --url https://attacker.example"}' >"$CFG"
FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM"
check "key sent as Bearer through the curl config" "$([ -n "$OUT" ] && grep -q 'Bearer test-key' "$T/config"; echo $?)"
check "config endpoint and non-numeric timeout ignored" \
  "$(grep -qx 'https://api.typesafe.ai/v1/systemone' "$T/args" && ! grep -q attacker "$T/args"; echo $?)"
check "key is not on argv" "$(! grep -q test-key "$T/args"; echo $?)"
rm -f "$CFG"

# A test run followed by long non-check output and an Edit result: the test run must survive the budget.
TR2="$T/transcript2.jsonl"
BIG=$(awk 'BEGIN { for (i = 0; i < 20000; i++) printf "x" }')
{
  echo '{"type":"user","message":{"role":"user","content":"fix it"}}'
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"a","name":"Bash","input":{"command":"pnpm vitest run"}}]}}'
  echo '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"a","content":"TEST_RUN_OUTPUT Tests 3 passed"}]}}'
  for i in 1 2 3 4 5 6 7 8 9; do
    echo '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"s'$i'","name":"Bash","input":{"command":"sed -n 1,400p README.md"}}]}}'
    echo '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"s'$i'","content":"'"$BIG"'"}]}}'
  done
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"e","name":"Edit","input":{"file_path":"a"}}]}}'
  echo '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"e","content":"EDIT_RESULT updated"}]}}'
} >"$TR2"
FAKE_RESP=$(noul 0.95 0.05) gate false "$CLAIM" "$TR2"
check "check-like output kept over long non-check output; Edit results dropped" \
  "$(jq -e '(.state.evidence | test("TEST_RUN_OUTPUT")) and (.state.evidence | test("EDIT_RESULT") | not) and (.state.evidence | length) <= 12002' "$T/body.json" >/dev/null; echo $?)"

# Secrets in tool output are masked before sending; the log keeps scores only, no reply text.
TR3="$T/transcript3.jsonl"
{
  echo '{"type":"user","message":{"role":"user","content":"check env"}}'
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"k","name":"Bash","input":{"command":"pnpm test"}}]}}'
  echo '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"k","content":"API_KEY=sk-live-abcdefghijklmnop99 ghp_abcdefghijklmnopqrstuvwxyz0123 Tests 3 passed"}]}}'
} >"$TR3"
rm -f "$T/data/jev.log"
FAKE_RESP=$(noul 0.95 0.05) gate false "완료했습니다 SECRET_IN_REPLY" "$TR3"
check "secrets masked before sending, test output kept" \
  "$(jq -e '(.state.evidence | test("sk-live|ghp_") | not) and (.state.evidence | test("Tests 3 passed"))' "$T/body.json" >/dev/null; echo $?)"
check "log in CLAUDE_PLUGIN_DATA, not the project; scores but no reply text" \
  "$(grep -q 'score=' "$T/data/jev.log" && ! grep -q SECRET_IN_REPLY "$T/data/jev.log" && [ ! -e "$PROJ/.claude/session-state" ]; echo $?)"

# --- qa-crosscheck ---
INPUT='{"scenario":"Total persists after reload","observation":"PUT returned 200, toast Saved","verdict":"passed"}'
QC=false FAKE_RESP=$(choice passed 0.9) cross "$INPUT"
check "crosscheck: switch off → skipped with the plugin-settings reason, no call" \
  "$(printf '%s' "$OUT" | jq -e '.status == "skipped" and (.reason | test("jev_qa_crosscheck is off"))' >/dev/null && [ ! -f "$T/calls" ]; echo $?)"
KEY= FAKE_RESP=$(choice passed 0.9) cross "$INPUT"
check "crosscheck: no key → skipped naming the key" \
  "$(printf '%s' "$OUT" | jq -e '.status == "skipped" and (.reason | test("no Jev API key"))' >/dev/null; echo $?)"
echo '{"disabled":true}' >"$CFG"
FAKE_RESP=$(choice passed 0.9) cross "$INPUT"
check "crosscheck: opted out → skipped with a valid JSON reason" \
  "$(printf '%s' "$OUT" | jq -e '.status == "skipped" and (.reason | test("disabled"))' >/dev/null; echo $?)"
rm -f "$CFG"

FAKE_RESP=$(choice insufficient_evidence 0.9) cross "$INPUT"
check "crosscheck: passed vs insufficient_evidence → contested" \
  "$(printf '%s' "$OUT" | jq -e '.status == "contested" and .jev == "insufficient_evidence" and .model == "jev-test"' >/dev/null; echo $?)"
check "crosscheck: log keeps confidence" "$(tail -1 "$T/data/jev.log" | grep -q 'confidence=0.9'; echo $?)"

FAKE_RESP=$(choice passed 0.9) cross "$INPUT"
check "crosscheck: same label → agree" "$(printf '%s' "$OUT" | jq -e '.status == "agree"' >/dev/null; echo $?)"

FAKE_RESP=$(choice failed 0.3) cross "$INPUT"
check "crosscheck: confidence < 0.5 → uncertain" "$(printf '%s' "$OUT" | jq -e '.status == "uncertain"' >/dev/null; echo $?)"

FAKE_RESP=$(choice passed 0.9) cross '{"scenario":"x"}'
check "crosscheck: missing observation → skipped" "$(printf '%s' "$OUT" | jq -e '.status == "skipped"' >/dev/null; echo $?)"

FAKE_FAIL=1 cross "$INPUT"
check "crosscheck: network failure → skipped" "$(printf '%s' "$OUT" | jq -e '.status == "skipped"' >/dev/null; echo $?)"

# Without CLAUDE_PROJECT_DIR and with cwd in a subfolder, the git top level's jev.json is used.
GPROJ="$T/gproj"
mkdir -p "$GPROJ/server/src" "$GPROJ/.claude/project-profile"
git -c init.defaultBranch=main init -q "$GPROJ"
echo '{"disabled":true}' >"$GPROJ/.claude/project-profile/jev.json"
OUT=$(cd "$GPROJ/server/src" && printf '%s' "$INPUT" | env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_OPTION_JEV_API_KEY=k \
  CLAUDE_PLUGIN_OPTION_JEV_QA_CROSSCHECK=true PATH="$BIN:$PATH" FAKE_DIR="$T" FAKE_RESP="$(choice passed 0.9)" "$BASH_BIN" "$CROSS")
check "crosscheck: no CLAUDE_PROJECT_DIR, cwd in subfolder → git top level jev.json found" \
  "$(printf '%s' "$OUT" | jq -e '.status == "skipped" and (.reason | test("opted out"))' >/dev/null; echo $?)"

echo "jev tests: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
