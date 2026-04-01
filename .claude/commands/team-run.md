---
description: "Team Workflow (Autonomous) — multi-agent team workflow with full auto-execution"
---

# Team Workflow — Autonomous Mode

Run a full multi-agent team workflow autonomously without user interaction.

## Usage

```
/team-run <task description>
```

Task description is required. If not provided, ask the user.

## Workflow

Same as `/team` but with key differences:

1. **Phase 1 — Planning** (autonomous):
   - Team Leader makes ALL decisions without asking user
   - No user review of plan (Leader self-approves rough plan)
   - Still saves plan to project docs
2. **Phases 2-5**: Identical to `/team`

## Key Difference from /team

| Aspect | /team | /team-run |
|--------|-------|-----------|
| Phase 1 user involvement | Leader asks about ambiguous decisions | Leader decides autonomously |
| Plan review | User reviews before proceeding | Auto-proceed after Leader approval |
| Escalation reporting | Yes (always) | Yes (always) |
| Everything else | Same | Same |

## Orchestration

1. **Load skill**: Read `.claude/skills/team-workflow/SKILL.md`
2. Execute all 5 phases following skill orchestration logic
3. All agents run with `mode: "bypassPermissions"`
4. Designers use `isolation: "worktree"` for parallel work

## Escalation

Same as `/team` — always report to user:
```
⚠ ESCALATION: [Source Phase] → [Target Phase]
Reason: [description]
```

## On Completion

```
TEAM WORKFLOW COMPLETE (autonomous)
Task: [description]
Phases completed: 5/5
Escalations: [count]
Files modified: [list]
Tests: [pass count] pass, 0 fail
```

## Related
- `/team` — Interactive mode (user involved in planning)
- `team-workflow` skill — Full orchestration logic
