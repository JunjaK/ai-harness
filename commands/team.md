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
   - Cross-review: two parallel objection passes (each architect gets the counterpart plan), Leader mediates
   - Optional: Spawn Architect C if infra/security concerns
   - Save plan to project docs
   - Present plan to user for review
3. **Phase 2 — UI/UX** (conditional, autonomous):
   - If UI/UX changes identified, spawn UI/UX Master
4. **Leader Approval Gate**:
   - Leader reviews and approves/rejects
5. **Phase 3 — Implementation** (autonomous):
   - Spawn Designer x N in parallel worktrees with TDD enforcement
   - Merge all worktrees after completion
6. **Phase 4 — Lightweight Verification** (autonomous, one pass):
   - Run one Tester on the merged tree: changed unit/integration tests, relevant type/lint/build gates, and at most one existing smoke E2E per affected user-facing flow
   - Failed or blocked required checks end this run with an incomplete report and a fix/unblock list; no automatic QA-to-implementation loop
7. **Phase 5 — Final Review** (autonomous):
   - Spawn Architect C for security audit
   - Reconcile plan/index/wiki with final code and checks, write up to 5 risk-ordered deferred QA items (or `- No scenarios: <reason>`) into the completed plan, then SHIP or escalate

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
Verification: VERIFY_PASS — [checks run], net-new failures 0, pre-existing failures [list or none]
Unverified: [checks and reasons, or none]
Deferred QA: [pending count and completed plan path; run /team-qa later]
```

When Phase 4 returns `VERIFY_FAIL` or `VERIFY_BLOCKED`, emit the `WORKFLOW ABORTED` report from `escalation.md` instead, with `Verification:` naming the outcome and the failed check or missing prerequisite, and `Plan:` giving the active plan path that holds the evidence.

## Related
- `/team-run` — Autonomous mode (no user involvement)
- `/team-qa` — Run accumulated deferred QA items later
- `/team-brainstorm` — Planning only mode (no implementation)
- `team-workflow` skill — Full orchestration logic
- `/plan-visualizer` — render the plan as an HTML diagram, if you want one (never automatic)
