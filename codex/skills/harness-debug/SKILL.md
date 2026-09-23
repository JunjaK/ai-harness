---
name: harness-debug
description: Diagnose and fix a reproducible bug, failing test, or unexpected behavior in a bounded area. Use when root cause needs investigation; route broad feature or contract changes to harness-team.
---

# Systematic debug

Use this self-contained workflow with Codex tools.

1. Capture the exact symptom and reproduce it with the smallest relevant check.
   Read the full failure, nearby code, recent diff, and a working comparison.
   If three reasonable reproduction attempts fail, report what was tried and ask
   for missing steps instead of guessing.
2. Narrow the failure boundary: trace the failing value or control flow from
   the observed error toward its source, comparing a working path when possible.
   Change one diagnostic variable at a time. For TS/JS, inspect declared and
   generated types and references; do not hide an upstream mismatch with a
   downstream assertion. For other stacks, use the project's native checker.
3. State a falsifiable root-cause hypothesis and check it against evidence
   before editing. A stack trace location or a passing retry alone is not a
   cause. If the check contradicts the hypothesis, revise it and keep tracing;
   do not patch a symptom while the cause remains unknown.
4. When an existing test framework or reproducible command can express the
   failure, run a focused check that fails before the fix. Apply the smallest
   correction to the confirmed cause, rerun that check, then run relevant
   type/build checks. Do not add dependencies or unrelated cleanup.
5. If the fix needs a new API contract, crosses three or more modules, or changes
   an agreed plan, switch to `$harness-team` with the evidence collected so far.
   Do not repeatedly patch symptoms.
6. Report root cause with file location, changed files, executed checks and
   outcomes, and one of `fixed`, `fixed but unverified`, or `not fixed`.

Red flags: repeated speculative edits, multiple simultaneous changes that
obscure which one helped, a fix justified only by a green test that never
reproduced the bug, or an explanation that does not account for the original
symptom. Stop and return to evidence when any of these appears.
