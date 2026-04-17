# Escalation Rules

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

## Escalation Paths

```
Phase 5 (Final Review)
  └─ security issue → Phase 3 (Designer fix) OR Phase 1 (re-plan if architectural)

Phase 4 (Verification)
  ├─ flaky test (simple fix) → retry in Phase 4 (max 3)
  ├─ implementation wrong → Phase 3 (Designer)
  └─ plan wrong → Phase 1 (re-plan)

Phase 3 (Implementation)
  ├─ simple fix → retry in Phase 3 (max 3)
  └─ fundamental issue → Phase 1 (re-plan)

Phase 2 (UI/UX)
  └─ UI/UX conflicts with plan → Phase 1 (re-plan)
```

## Retry Limits (hard caps)

| Scope | Limit | On Exceed |
|-------|-------|-----------|
| Per-phase retries | 3 | Auto-escalate to higher phase |
| Global re-plan cycles | 3 | ABORT workflow, report to user |

Counters increment on every retry, not every escalation. Resetting counters is NOT allowed during a single workflow run.

## Escalation Report Format (REQUIRED)

```markdown
⚠ ESCALATION: [Source Phase] → [Target Phase]
Agent: [agent name + identifier if multiple]
Reason: [specific issue, not "something went wrong"]
Classification: Simple Fix / Fundamental Issue
Retry count: [source phase] attempt [N/3]
Global cycle: [N/3]
Affected files: [explicit list]
Root cause (if known): [description]
Tried approaches: [list of what was attempted, with outcomes]
Recommendation: re-plan / targeted fix / abort
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

Both `/team` and `/team-run` MUST emit this status update.

## Abort Conditions (workflow MUST stop)

Abort when ANY of the following occurs:
- Global re-plan cycles reach 3
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
