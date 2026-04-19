# Team Agent Roles — Quick Reference

| Role | Agent | Model | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | opus | Always (Phase 1, Gate, Escalation) |
| Architect A (FE) | `team-architect-fe` | opus | Phase 1 (parallel with B) |
| Architect B (BE) | `team-architect-be` | opus | Phase 1 (parallel with A) |
| Architect C (Infra) | `team-architect-infra` | opus | Phase 1 (on-demand) + Phase 5 (always) |
| UI/UX Master | `team-uiux-master` | sonnet | Phase 2 (conditional) |
| Designer x N | `team-designer` | opus | Phase 3 (parallel, worktree isolated) |
| Tester x N | `team-tester` | sonnet | Phase 4 (parallel) |

## Agent Invocation

All agents are invoked via the `Agent` tool:

```
Agent(
  subagent_type="general-purpose",
  prompt="[agent .md content]\n\nTask: [specific task]",
  mode="bypassPermissions"
)
```

For Designers, add worktree isolation:
```
Agent(
  subagent_type="general-purpose",
  prompt="[agent .md content]\n\nTask: [specific task]",
  mode="bypassPermissions",
  isolation="worktree"
)
```

## Cross-Review Dialog

Phase 1 cross-review uses TeamCreate for multi-agent dialog:
- Participants: Team Leader + Architect A + Architect B
- Purpose: Review each other's plans for consistency
- Terminates when Leader approves the consolidated plan
