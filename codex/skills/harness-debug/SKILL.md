---
name: harness-debug
description: Diagnose and fix a reproducible bug, failing test, or unexpected behavior in a bounded area. Use when root cause needs investigation; route broad feature or contract changes to harness-team.
---

# Systematic debug

This is a Codex-ready counterpart to Claude's `/debug`; it does not depend on
`superpowers:systematic-debugging` or Claude's `Skill()` tool.

1. Capture the exact symptom and reproduce it with the smallest relevant check.
   Read the full failure, nearby code, recent diff, and a working comparison.
   If three reasonable reproduction attempts fail, report what was tried and ask
   for missing steps instead of guessing.
2. Trace the failing value or control flow to its origin. State one testable root
   cause before editing. For TS/JS, inspect declared and generated types and
   references; do not repair a downstream type assertion to hide an upstream
   mismatch. For other stacks, use the project's native checker.
3. When the existing test framework or a reproducible command can express the
   failure, add or run a focused regression check that fails before the
   fix. Apply the smallest root-cause correction and rerun that check. Run the
   relevant type/build checks if the changed surface requires them. Do not add
   dependencies or unrelated cleanup.
4. If the fix needs a new API contract, crosses three or more modules, or changes
   an agreed plan, switch to `$harness-team` with the evidence collected so far.
   Do not repeatedly patch symptoms.
5. Report root cause with file location, changed files, executed checks and
   outcomes, and one of `fixed`, `fixed but unverified`, or `not fixed`.
