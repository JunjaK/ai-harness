---
description: "Team Workflow (Interactive) — multi-agent team workflow with user involvement in planning"
---

# Team Workflow — Interactive Mode

Start a multi-agent team workflow with user involvement during the planning phase.

## Usage

```
/team [task description]
```

If no task description provided, ask the user for one.

## Workflow

1. **Load skill**: Invoke the `team-workflow` skill for orchestration logic
2. **Phase 1 — Planning** (user involved):
   - Spawn Team Leader with instruction to ask user about ambiguous decisions
   - Spawn Architects A + B in parallel
   - Cross-review via TeamCreate dialog
   - Optional: Spawn Architect C if infra/security concerns
   - Save plan to project docs
   - Present plan to user for review
3. **Phase 2 — UI/UX** (conditional, autonomous):
   - If UI/UX changes identified, spawn UI/UX Master
4. **Leader Approval Gate**:
   - Leader reviews and approves/rejects
5. **Visualize plan** — Generate HTML diagram using `plan-visualizer` skill
   - Save to `_docs/{category}/plan-{feature}.visual.html` (same dir as plan .md)
   - Add `[View Plan Diagram](./plan-{feature}.visual.html)` link in plan .md
6. **Phase 3 — Implementation** (autonomous):
   - Spawn Designer x N in parallel worktrees with TDD enforcement
   - Merge all worktrees after completion
6. **Phase 4 — Verification** (autonomous):
   - Spawn Tester x N in parallel
   - Loop until all tests pass (max 3 retries)
7. **Phase 5 — Final Review** (autonomous):
   - Spawn Architect C for security audit
   - SHIP or escalate

## Escalation

On any escalation, report to user:
```
⚠ ESCALATION: [Source Phase] → [Target Phase]
Reason: [description]
```

## On Completion

```
TEAM WORKFLOW COMPLETE
Task: [description]
Phases completed: 5/5
Files modified: [list]
Tests: [pass count] pass, 0 fail
```

## Related
- `/team-run` — Autonomous mode (no user involvement)
- `/team-brainstorm` — Planning only mode (no implementation)
- `team-workflow` skill — Full orchestration logic
- `plan-visualizer` skill — HTML diagram generation
