#!/bin/bash
# Jev second opinion on one agentic-testing verdict. Advisory: it never changes the verdict.
# Opt-in: .claude/project-profile/jev.json → "qaCrossCheck": {"enabled": true}.
# stdin: {"scenario": "<expected outcome>", "observation": "<raw observed evidence>", "verdict": "passed|failed|blocked"}
# stdout: one JSON line —
#   {"status": "agree|contested|uncertain", "jev": "<label>", "confidence": n, "probabilities": {…}, "model": "…"}
#   {"status": "skipped", "reason": "…"}   (not enabled, no key, network or response failure)
# Tests: bash hooks/jev/tests/run.sh

HERE=${BASH_SOURCE[0]%/*}
[ "$HERE" = "${BASH_SOURCE[0]}" ] && HERE=.
. "$HERE/lib.sh"

skip() { printf '{"status":"skipped","reason":"%s"}\n' "$1"; exit 0; }

INPUT=$(cat)
jev_enabled qaCrossCheck || skip "qaCrossCheck not enabled in .claude/project-profile/jev.json (or jq/curl missing)"
STATE=$(printf '%s' "$INPUT" | jq -ce '{scenario, observation} | select(.scenario and .observation)' 2>/dev/null) \
  || skip "input needs scenario and observation"
VERDICT=$(printf '%s' "$INPUT" | jq -r '.verdict // empty')

QUESTIONS='{"verdict":{"type":"choice","instructions":"Classify the QA result of `scenario` given `observation`.","criteria":{
  "passed":"The expected outcome was directly observed, including persistence after reload or in the data store when the scenario concerns saved data.",
  "failed":"The app was reachable and the steps ran, but the observed behavior differs from the expected outcome.",
  "blocked":"The steps could not run because of a missing server, account, seed data, device, test driver or tool, or access.",
  "insufficient_evidence":"The steps ran but the observation lacks the evidence the scenario requires, for example only a 200 response or a toast with no reload or data check."}}}'

RESP=$(jev_call "$STATE" "$QUESTIONS") || skip "Jev call failed (key, network, or response)"

OUT=$(printf '%s' "$RESP" | jq -c --arg v "$VERDICT" '
  .answers.verdict as $a
  | { status: (if ($a.confidence // 0) < 0.5 then "uncertain" elif $a.choice == $v then "agree" else "contested" end),
      jev: $a.choice, confidence: $a.confidence, probabilities: $a.probabilities, model: .model }') \
  || skip "unexpected Jev response"
jev_log qa-crosscheck "$(printf '%s' "$OUT" | jq -r .model)" "agent=$VERDICT" "$(printf '%s' "$OUT" | jq -r '.jev + " " + .status')"
printf '%s\n' "$OUT"
