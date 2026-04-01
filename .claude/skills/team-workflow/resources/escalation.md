# Escalation Rules

## Self-Judgment Criteria

Each agent independently classifies issues:

### Simple Fix (retry in current phase)
- Import path errors
- Type property mismatches (fixable locally)
- Test assertion value corrections
- Lint/formatting issues
- Missing null checks
- Small logic errors with obvious fix

### Fundamental Issue (escalate up)
- API endpoint missing or returns wrong shape
- Architectural flaw in module design
- Data flow not covered in plan
- Circular dependency introduced
- Feature requirement misunderstood
- Cross-file dependency conflict

## Escalation Paths

```
Phase 5 (Final Review)
  └─ security issue found → Phase 3 (fix) or Phase 1 (re-plan)

Phase 4 (Verification)
  ├─ test failure (simple) → retry in Phase 4 (max 3)
  ├─ test failure (implementation wrong) → Phase 3 (Designer re-review)
  └─ test failure (plan wrong) → Phase 1 (re-plan)

Phase 3 (Implementation)
  ├─ code issue (simple) → retry in Phase 3 (max 3)
  └─ plan issue (fundamental) → Phase 1 (re-plan)

Phase 2 (UI/UX)
  └─ UI/UX conflict with plan → Phase 1 (re-plan)
```

## Retry Limits

| Scope | Limit | On Exceed |
|-------|-------|-----------|
| Per-phase retries | 3 | Auto-escalate to higher phase |
| Global re-plan cycles | 3 | ABORT — report to user for manual intervention |

## Escalation Report Format

```markdown
⚠ ESCALATION: [Source Phase] → [Target Phase]
Reason: [clear description of the issue]
Retry count: [current phase] attempt [N/3]
Global cycle: [N/3]
Affected files: [list]
Recommendation: [re-plan / targeted fix / abort]
```

## Status Report Format

Reported to user on every escalation (both `/team` and `/team-run`):

```
TEAM STATUS UPDATE
Phase: [current phase name]
Event: [escalation / phase complete / retry]
Details: [what happened and what's next]
Progress: Phase [N]/5
```
