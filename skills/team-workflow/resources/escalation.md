# Escalation Rules

This document is the **sole normative source** for escalation classification, phase routing, counter semantics, and report formats. Agent definitions (`team-designer.md`, `team-tester.md`, `team-leader.md`) point here rather than keeping their own copies — a duplicated copy is exactly the defect class (divergent classification lists, a phase graph drawn 4 times) this document exists to remove. Do not reintroduce a local list or ASCII path-tree in any other file.

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
| P4 | conjunctive gate ALL true (flaky/fixture/setup) | Simple Fix | P4 | `retries.p4++` | `>= 3 → force Fundamental` |
| P4 | implementation violates plan | Fundamental | P3 | `retries.p3` **preserved, never reset** | if `retries.p3 >= 3` → P1 |
| P4 | plan itself wrong | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| P4 | PASS + user-facing flow changed + 4.5 precondition met | — | P4.5 | — | — |
| P4 | PASS + (no user-facing change OR 4.5 precondition unmet) | — | P5 | — | — (non-blocking skip, log reason) |
| P4.5 | goals met, specs green | — | P5 | — | — |
| P4.5 | goal unmet / verdict distrusted | Fundamental | P3 or P1 per gate | per target | per target |
| P5 | SHIP | — | DONE | — | — |
| P5 | security issue, code-local | Simple Fix | P3 | `retries.p5++` | `>= 3 → ABORT` |
| P5 | security issue, architectural | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| any | blocking external dep, or user cancels | — | ABORT | — | emit abort report |

### Counter Semantics

- `retries.pN` increments only on a pN→pN re-entry (same-phase retry) — never on entry from a different phase.
- `globalCycle` increments on every entry into P1 after the first (i.e., every re-plan cycle) — not on every escalation.
- Neither counter ever decrements or resets within a single `runId`.
- The abort check is evaluated on **every write** to the counters — not deferred to a separate check step.
- Counters are persisted, not recalled from context: `.claude/session-state/team-run.json` (schema + storage rules: `checkpoint` skill's team-workflow integration table; read/write contract: `team-workflow/SKILL.md` → "State Tracking").

## Retry Limits (hard caps)

| Scope | Limit | On Exceed |
|-------|-------|-----------|
| Per-phase retries | 3 | Auto-escalate to higher phase (see table's Abort column for the exact target per transition) |
| Global re-plan cycles | 3 | ABORT workflow, report to user |

Counters increment on every retry, not every escalation. Resetting counters is NOT allowed during a single workflow run (`runId`).

## Escalation Report Format (REQUIRED)

An escalation report has two blocks. **Agents emit only the first** — a Designer or Tester cannot know orchestrator-level state (`Global cycle`, cross-phase retry counts); requiring it in the agent-emitted block would guarantee either a fabricated number or a blank field. The orchestrator appends the second block itself, read from `.claude/session-state/team-run.json` — never from an agent's report, never from memory.

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
- Any per-phase retry reaches 3 AND escalation target has also reached its retry limit
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
