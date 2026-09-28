#!/bin/bash
# Jev second opinion on one agentic-testing verdict. Advisory: it never changes the verdict.
# Called by mcp/jev_server.py (tool qa_crosscheck), which passes the plugin settings through;
# opt-in: the plugin setting jev_qa_crosscheck plus a Jev API key (README → "Jev checks").
# stdin: {"scenario": "<expected outcome>", "observation": "<raw observed evidence>", "verdict": "passed|failed|blocked"}
# stdout: one JSON line —
#   {"status": "agree|contested|uncertain", "jev": "<label>", "confidence": n, "probabilities": {…},
#    "on_target": n, "model": "…"}  (+ "note" when an off-target run changed Jev's label)
#   {"status": "ready"}  for `qa-crosscheck.sh --status`: switches and key are usable, no Jev call made
#   {"status": "skipped", "reason": "…"}   (switch off, no key, project opted out, network or response failure)
# Tests: bash hooks/jev/tests/run.sh

HERE=${BASH_SOURCE[0]%/*}
[ "$HERE" = "${BASH_SOURCE[0]}" ] && HERE=.
. "$HERE/lib.sh"

skip() { jq -cn --arg r "$1" '{status: "skipped", reason: $r}' 2>/dev/null || printf '{"status":"skipped","reason":"jq is missing"}\n'; exit 0; }

jev_enabled jev_qa_crosscheck || skip "$JEV_SKIP"
if [ "${1:-}" = "--status" ]; then
  printf '{"status":"ready"}\n'
  exit 0
fi
INPUT=$(cat)
STATE=$(printf '%s' "$INPUT" | jq -ce '{scenario, observation} | select(.scenario and .observation)' 2>/dev/null) \
  || skip "input needs scenario and observation"
VERDICT=$(printf '%s' "$INPUT" | jq -r '.verdict // empty')

QUESTIONS='{"verdict":{"type":"choice","instructions":"Classify the QA result of `scenario` given `observation`.","criteria":{
  "passed":"The expected outcome was directly observed, including persistence after reload or in the data store when the scenario concerns saved data.",
  "failed":"The app was reachable and the steps ran, but the observed behavior differs from the expected outcome.",
  "blocked":"The steps could not run because of a missing server, account, seed data or test fixture file, device, test driver or tool, or access.",
  "insufficient_evidence":"The steps ran but the observation lacks the evidence the scenario requires, for example only a 200 response or a toast with no reload or data check."}},
 "on_target":{"type":"noul","instructions":"Does `observation` show that the steps were performed on the target app or page of `scenario`: the target was running and in front, and the actions reached it? Answer no when it shows another app or page in front, the target process not running, or a launch that did not reach the target."}}'

RESP=$(jev_call "$STATE" "$QUESTIONS") || skip "Jev call failed (key, network, or response)"

# A run that never reached the target (another app in front, no target process) says nothing about the
# feature, yet the choice alone read such runs as `failed` (nivoca: 0.75–0.90). Below 0.35 on `on_target`,
# a passed/failed label becomes insufficient_evidence. On 15 probe cases (jev-1.13.0) the two off-target
# runs scored 0.10–0.15 and every on-target passed/failed run 0.55–0.97.
OUT=$(printf '%s' "$RESP" | jq -c --arg v "$VERDICT" '
  .answers.verdict as $a | (.answers.on_target.noul // 1) as $t
  | (($a.choice == "passed" or $a.choice == "failed") and $t < 0.35) as $off
  | (if $off then "insufficient_evidence" else $a.choice end) as $label
  | { status: (if $label == $v then "agree"
              elif $off then "contested"   # rests on on_target, not on the choice'"'"'s confidence
              elif ($a.confidence // 0) < 0.5 then "uncertain" else "contested" end),
      jev: $label, confidence: $a.confidence, probabilities: $a.probabilities, on_target: $t, model: .model }
  + (if $off then {note: ("Jev chose " + $a.choice + ", but the evidence does not show the steps ran on the target app or page")} else {} end)') \
  || skip "unexpected Jev response"
jev_log qa-crosscheck "$(printf '%s' "$OUT" | jq -r .model)" "agent=$VERDICT" \
  "$(printf '%s' "$OUT" | jq -r '"\(.jev) \(.status) confidence=\(.confidence) on_target=\(.on_target)"')"
printf '%s\n' "$OUT"
