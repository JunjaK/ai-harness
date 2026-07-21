---
description: "Debug — solo systematic debug of a bug / test failure / unexpected behavior under the Iron Law (root cause before any fix); layers the TS/LSP debug skill for TypeScript targets, escalates to /team when it turns Fundamental. The non-team-workflow debugging entry point."
---

# Debug

The **solo, direct** entry point for debugging — a deterministic way to force the systematic methodology on a specific bug instead of relying on description auto-trigger (the known undertriggering failure). This is the general-case counterpart to the team pipeline's Phase 3-4 debugging: no planning ceremony, no architects, just root-cause-first investigation. When the bug outgrows solo scope, it hands off **up** to `/team` rather than grinding.

## Usage

```
/debug <symptom>   # systematic debug on the described bug / failing test / unexpected behavior
/debug             # debug the current failure in context (last error · failing test · recent diff)
```

## What It Does

Run `Skill(skill="superpowers:systematic-debugging")` under its **Iron Law — no fixes without root-cause investigation first**, layering the harness `debug` skill's LSP patterns when the target is TypeScript. `superpowers` is a hard dependency: if the skill is unregistered, ABORT and tell the user to install it.

1. **Frame — no fix yet.** Capture the symptom (from `<symptom>` or context: last error, failing test, recent diff). Establish reproduction; if not reproducible after 3 attempts → request repro steps, do not guess.
2. **Route by stack.** TS/JS target → also load the `debug` skill (`goToDefinition` / `findReferences` / `incomingCalls`, structural traps); non-TS → the native checker from project-profile `stack.md`.
3. **Investigate (Phase 1-2).** Read errors completely, check recent changes (`git diff`), instrument component boundaries in multi-layer systems, trace the bad value **backward** to its origin, find a working reference and list every difference.
4. **Hypothesize + test (Phase 3).** One hypothesis stated as "X is root cause because Y" → smallest possible change → one variable at a time. Fails → new hypothesis, never stack fixes.
5. **Fix + verify (Phase 4).** Failing test first (`tdd-workflow`) → single root-cause fix (no "while I'm here") → confirm via `verification-loop`. A network 200 / green UI is **not** proof — verify DB-level persistence where the change touches data (value survives a refresh).
6. **Escalate at the boundary (see below).** When the bug crosses solo scope, STOP and route up.

Effort: start `xhigh`; escalate `/effort max` only after `xhigh` fails twice on the **same** bug.

## Boundary — solo `/debug` vs `/team`

`/debug` owns the direct, single-thread bug hunt. It MUST STOP and escalate when the issue is **Fundamental**, not solo:

- **3+ fixes failed**, or each fix reveals a new problem elsewhere → architectural, not a failed hypothesis → `/team`.
- **Root cause spans 3+ modules**, or needs an **API / backend contract change** not already planned → `/team` (or `contract-sync` if it's a generated-client drift).
- **Cross-cutting** (API + UI + state together) → `/team`.
- **prd/stg data or destructive DB op** implicated → STOP; assistant writes SQL + local dry-run + verify queries only, **human executes** (never autonomous on production data).

A trivial one-line mechanical bug (typo, obvious off-by-one) doesn't need `/debug` — just fix it. Reach for `/debug` the moment you'd otherwise start guessing.

## On Completion

Report with the three-way honesty distinction — **fixed / fixed-but-unverified / not fixed** are different states and MUST NOT be collapsed:

```
🐛 DEBUG <symptom>
Root cause: <one-line, file:line>  |  UNVERIFIED — <why not pinned>
Fix:        <what changed, file:line>  |  none (escalated)
Verified:   <test/build green · DB-persistence evidence>  |  NOT VERIFIED (smoke 미실시)
Status:     fixed · fixed-unverified · escalated→/team · not-reproduced
```

## Related

- `superpowers:systematic-debugging` skill — the general methodology (Iron Law · 4 phases · red flags) this command fires
- `debug` skill (harness) — the TS/LSP-accelerated layer loaded for TypeScript targets
- `tdd-workflow` skill — the failing test the root-cause fix is written against
- `verification-loop` skill — confirm the fix before claiming success (no self-report trust)
- `/team` · `/team-run` — escalation target when the bug is a Fundamental Issue (cross-cutting / 3+ modules / BE change)

ARGUMENTS: $ARGUMENTS
