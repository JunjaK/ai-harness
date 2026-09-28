#!/bin/bash
# Jev second opinion on one agentic-testing verdict. Advisory: it never changes the verdict.
# Called by mcp/jev_server.py (tool qa_crosscheck), which passes the plugin settings through;
# opt-in: the plugin setting jev_qa_crosscheck plus a Jev API key (README → "Jev checks").
# stdin: {"scenario": "<expected outcome>", "observation": "<raw observed evidence>", "verdict": "passed|failed|blocked"}
# stdout: one JSON line —
#   {"status": "agree|contested|uncertain", "jev": "<label>", "confidence": n, "probabilities": {…}, "model": "…"}
#   {"status": "skipped", "reason": "…"}   (switch off, no key, project opted out, network or response failure)
# Tests: bash hooks/jev/tests/run.sh

HERE=${BASH_SOURCE[0]%/*}
[ "$HERE" = "${BASH_SOURCE[0]}" ] && HERE=.
. "$HERE/lib.sh"

skip() { jq -cn --arg r "$1" '{status: "skipped", reason: $r}' 2>/dev/null || printf '{"status":"skipped","reason":"jq is missing"}\n'; exit 0; }

INPUT=$(cat)
jev_enabled jev_qa_crosscheck || skip "$JEV_SKIP"
STATE=$(printf '%s' "$INPUT" | jq -ce '{scenario, observation} | select(.scenario and .observation)' 2>/dev/null) \
  || skip "input needs scenario and observation"
VERDICT=$(printf '%s' "$INPUT" | jq -r '.verdict // empty')

QUESTIONS='{"verdict":{"type":"choice","instructions":"Classify the QA result of `scenario` given `observation`.","criteria":{
  "passed":"The expected outcome was directly observed, including persistence after reload or in the data store when the scenario concerns saved data.",
  "failed":"The app was reachable and the steps ran, but the observed behavior differs from the expected outcome.",
  "blocked":"The steps could not run because of a missing server, account, seed data or test fixture file, device, test driver or tool, or access.",
  "insufficient_evidence":"The steps ran but the observation lacks the evidence the scenario requires, for example only a 200 response or a toast with no reload or data check."}}}'

RESP=$(jev_call "$STATE" "$QUESTIONS") || skip "Jev call failed (key, network, or response)"

OUT=$(printf '%s' "$RESP" | jq -c --arg v "$VERDICT" '
  .answers.verdict as $a
  | { status: (if ($a.confidence // 0) < 0.5 then "uncertain" elif $a.choice == $v then "agree" else "contested" end),
      jev: $a.choice, confidence: $a.confidence, probabilities: $a.probabilities, model: .model }') \
  || skip "unexpected Jev response"
jev_log qa-crosscheck "$(printf '%s' "$OUT" | jq -r .model)" "agent=$VERDICT" \
  "$(printf '%s' "$OUT" | jq -r '"\(.jev) \(.status) confidence=\(.confidence)"')"
printf '%s\n' "$OUT"
