---
description: "Team Brainstorm — Leader + Architects가 plan만 논의 (구현 없음, 시각화 포함)"
---

# Team Brainstorm — Planning Only Mode

Lightweight team discussion: Leader + Architects brainstorm and produce a plan without proceeding to implementation. Includes visual HTML diagram of the plan.

## Usage

```
/team-brainstorm [task description]
```

If no task description provided, ask the user for one.

## Workflow

1. **Load skill**: Invoke the `team-workflow` skill for agent definitions
2. **Spawn Team Leader** with task description
   - Leader drafts rough plan
   - Leader asks user about ambiguous decisions (always interactive)
   - Once the *what/why/constraints* have settled — before any architect runs — the Leader writes `_docs/intent/<created>-<topic>-intent.md` (`kind: intent`, a **collection** doc: it stays put, is never merged, and moves to `intent/deprecated/` if the idea is dropped). Register it in `index.md` §① + §④.
3. **Spawn Architects A + B** (parallel) for detailed plans
4. **Cross-Review** — two parallel objection passes (each architect receives the counterpart plan, returns objections only), Leader mediates and finalizes
5. **Optional**: Spawn Architect C if infra/security concerns
6. **Optional**: Spawn UI/UX Master if visual changes needed
7. **Save plan** to `_docs/active/planning/<created>/<created>-<topic>-plan.md`, `related:`→ the intent (both ways)
8. **Present plan** to user for review

No diagram is generated here. If the user wants one, they run `/plan-visualizer`.

## Output

```
📋 TEAM BRAINSTORM COMPLETE
Task: [description]
Intent: _docs/intent/<created>-<topic>-intent.md          (the ask — stays here)
Plan: _docs/active/planning/<created>/<created>-<topic>-plan.md   (the design — rides the lifecycle)
Team: Leader + Arch A + Arch B [+ Arch C] [+ UI/UX Master]

Ready to execute? Use:
  /team-run "[task description]"
```

## What This Does NOT Do

- No Phase 3 (Implementation) — no code written
- No Phase 4 (Verification) — no tests run
- No Phase 5 (Security Review) — no audit
- No file modifications — only plan documents created

## Related
- `/team` — Full workflow with user involvement in planning
- `/team-run` — Full workflow autonomous
- `/plan-visualizer` — render the plan as an HTML diagram, if you want one (never automatic)
