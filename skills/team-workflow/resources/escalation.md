# Escalation Rules

This document is the **sole normative source** for escalation classification, phase routing, counter semantics, and report formats. Agent definitions (`team-designer.md`, `team-tester.md`, `team-leader.md`) point here rather than keeping their own copies — a duplicated copy is exactly the defect class (divergent classification lists, a phase graph drawn 4 times) this document exists to remove. Do not reintroduce a local list or ASCII path-tree in any other file.

## Phase 4 verification outcomes

Phase 4 runs one bounded verification pass on the merged result. Full or exploratory QA is a separate `/team-qa` invocation. Report every failed or unavailable check with its command, exit status, relevant output, baseline comparison, affected files, and next action; then emit one overall outcome. No Phase 4 outcome retries P4, returns to P3/P1, or invokes a Phase 4.5.

| Outcome | Evidence and route |
|---|---|
| `VERIFY_PASS` | Required affected unit/integration tests (or the full deterministic suite when explicitly requested for this task) and relevant authoritative build/type/lint gates show no net-new failure against a reliable baseline. Record any proven pre-existing failures. Run at most one existing smoke E2E per affected flow when its prerequisites are already available. Record missing optional smoke coverage as a proposed `/team-qa` case. Continue to P5. |
| `VERIFY_FAIL` | A required check or executed smoke has a net-new failure, or a changed behavior has no collected relevant test. Record the reproducible observation, baseline evidence, likely owner, and acceptance check. End this run with the report; correction is a later task, not an automatic loop. |
| `VERIFY_BLOCKED` | A required check could not run or its failing result cannot be attributed because the baseline or another prerequisite is unavailable. Record the exact missing evidence, service, device, credential, permission, fixture, or tool and who can provide it. End this run as unverified; an optional smoke not already runnable belongs in the proposed QA list and does not block the light pass. |

The Tester does not edit implementation code, repair test setup, or write QA archive files in P4. The Phase 5 orchestrator deduplicates, prioritizes, and writes up to five pending QA entries; no filler entries are required. A standalone `/team-qa` run may use a deeper QA process without changing this team's one-pass transition graph.

## Classification (deterministic, not subjective)

An agent MUST classify an issue as either "Simple Fix" or "Fundamental Issue" using the explicit criteria below. Ambiguous cases default to "Fundamental Issue" (escalate up).

### Simple Fix (retry in current phase, max 3 attempts)

ALL of the following MUST be true:
- Issue is contained within a single file
- Fix does not change the plan's architecture or contracts
- Fix does not require another agent's input
- Root cause is identified (not guessing)

Examples:
- Import path wrong — rename to correct path
- Type property mismatch on a local (non-shared) type — fix the type
- Test assertion off-by-one — fix the assertion
- Lint/formatting violation — apply the project formatter
- Null check missing on internal data — add the check
- Mock data incorrect — update the fixture

### Fundamental Issue (escalate up)

ANY of the following MUST be true:
- API endpoint specified in plan does not exist or has a different shape
- Module/composable/hook required by plan is not available in the codebase
- Fix would require modifying another agent's files
- Fix would change the plan's architecture, data flow, or contracts
- Fix would require a new API endpoint, new DB table, or new dependency
- Circular dependency introduced by following the plan literally
- Plan assumes behavior that contradicts existing code
- Root cause is not identified after 2 debugging attempts

Examples:
- Backend returns `{ items: [...] }` but plan expects `{ data: [...] }`
- Plan says to use `useUserStore` but store doesn't exist
- Plan requires a new REST endpoint not in Arch B's plan
- Refactoring to fix an issue would touch files assigned to another Designer

## Phase Transition Table (SSOT)

The single normative graph for the workflow — routing, classification, counter effects, and abort thresholds in one place. `skills/team-workflow/SKILL.md`'s mermaid is the **visual** rendering of this same graph (node set MUST equal this table's `From` ∪ `To` state set); this table is the **rules** rendering. If the two ever disagree, this table wins and the mermaid is stale.

| From | Guard | Class | To | Counter | Abort |
|---|---|---|---|---|---|
| START | task received | — | P1 | `globalCycle = 1` | — |
| P1 | any UI/UX trigger matched | — | P2 | — | — |
| P1 | no UI/UX trigger | — | GATE | — | — |
| P2 | no conflict with plan | — | GATE | — | — |
| P2 | UI/UX conflicts with plan | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| GATE | Leader approves | — | P3 | — | — |
| GATE | Leader rejects | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| P3 | conjunctive gate ALL true | Simple Fix | P3 | `retries.p3++` | `>= 3 → force Fundamental → P1` |
| P3 | any Fundamental condition true, or ambiguous | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| P3 | all Designers done + merged | — | P4 | — | — |
| P4 | `VERIFY_PASS` + evidence and QA candidates handed off | — | P5 | — | — |
| P4 | `VERIFY_FAIL` + failed-check evidence recorded | — | ABORT | — | emit verification report; no automatic correction |
| P4 | `VERIFY_BLOCKED` + prerequisite recorded | — | ABORT | — | emit unverified report; no automatic retry |
| P5 | SHIP | — | DONE | — | — |
| P5 | security issue, code-local | Simple Fix | P3 | `retries.p5++` | `>= 3 → ABORT` |
| P5 | security issue, architectural | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| any | blocking external dep outside P4, or user cancels | — | ABORT | — | emit abort report |

### Counter Semantics

- `retries.pN` increments only where the matching table row says so. P4 has no retry transition, so `retries.p4` does not increment.
- At a cap, persist the increment and apply the row's `Abort`-column consequence without entering its nominal `To` state.
- `globalCycle` increments on every entry into P1 after the first (i.e., every re-plan cycle) — not on every escalation.
- Neither counter ever decrements or resets within a single `runId`.
- The abort check is evaluated on **every write** to the counters — not deferred to a separate check step.
- Counters are persisted, not recalled from context: `.claude/session-state/team-run.json` (schema + storage rules: `checkpoint` skill's team-workflow integration table; read/write contract: `team-workflow/SKILL.md` → "State Tracking").

## Retry Limits (hard caps)

| Scope | Limit | On Exceed |
|-------|-------|-----------|
| Per-phase retries | 3 | Apply the table's `Abort`-column consequence (reroute, reclassify, or abort) |
| Global re-plan cycles | 3 | ABORT workflow, report to user |

Counters increment only as specified by the transition row. Resetting counters is NOT allowed during a single workflow run (`runId`).

## Escalation Report Format (REQUIRED outside P4)

For Phase 4, use the one-pass verification report in `agents/team-tester.md`, including failed-check evidence or blocked prerequisites. The escalation report below applies to other phases. **Agents emit only the first block** — a Designer cannot know orchestrator-level state (`Global cycle`, cross-phase retry counts); requiring it in the agent-emitted block would guarantee either a fabricated number or a blank field. The orchestrator appends the second block itself, read from `.claude/session-state/team-run.json` — never from an agent's report, never from memory.

### Agent-emitted block

```markdown
⚠ ESCALATION: [Source Phase] → [Target Phase]
Agent: [agent name + identifier if multiple]
Classification: [per this document's Classification section]
Reason: [specific issue, not "something went wrong"]
Attempts: [source phase] [N/3]
Affected files: [explicit list]
Root cause (if known): [description]
Tried approaches: [list of what was attempted, with outcomes]
Recommendation: re-plan / targeted fix / abort
```

### Orchestrator-filled block

```markdown
Global cycle: [N/3]
Cross-phase retries: P1=N/3, P2=N/3, P3=N/3, P4=N/3, P5=N/3
```

## Status Report Format (reported to user on EVERY escalation)

```
TEAM STATUS UPDATE
Phase: [current phase name]
Event: escalation / phase complete / retry
Details: [what happened, in one sentence]
Progress: Phase [N]/5
Retry counts: P1=N/3, P2=N/3, P3=N/3, P4=N/3, P5=N/3
Global cycle: [N/3]
```

Both `/team` and `/team-run` MUST emit this status update. Values come from `.claude/session-state/team-run.json`, not from conversation recall.

## Abort Conditions (workflow MUST stop)

Abort triggers are enumerated per-transition in the table's Abort column above. Summary:
- Global re-plan cycles (`globalCycle`) reach 3
- A capped transition's `Abort` column resolves to `ABORT`
- Phase 4 reports `VERIFY_FAIL` or `VERIFY_BLOCKED`
- Blocking issue detected with no viable path forward (e.g., external dependency unavailable)
- User explicitly cancels

On abort, emit final report:
```
WORKFLOW ABORTED
Reason: [cause]
Phases completed: [list]
Phases failed: [list]
Unresolved issues: [list]
Recommendation for user: [next steps]
```
