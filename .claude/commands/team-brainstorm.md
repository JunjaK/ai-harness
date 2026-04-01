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

1. **Load skill**: Read `.claude/skills/team-workflow/SKILL.md` for agent definitions
2. **Spawn Team Leader** with task description
   - Leader drafts rough plan
   - Leader asks user about ambiguous decisions (always interactive)
3. **Spawn Architects A + B** (parallel) for detailed plans
4. **Cross-Review** via TeamCreate dialog (Leader + Arch A + Arch B)
5. **Optional**: Spawn Architect C if infra/security concerns
6. **Optional**: Spawn UI/UX Master if visual changes needed
7. **Save plan** to `_docs/{category}/plan-{feature}.md`
8. **Generate visualization** — create HTML diagram of the plan
   - Save to `_docs/{category}/plan-{feature}.visual.html`
   - Add link in plan .md: `[View Plan Diagram](./plan-{feature}.visual.html)`
9. **Present plan** to user for review

## Visualization

After the plan is finalized, generate an HTML file with:
- **Team composition** — roles involved and why
- **Phase flow** — which phases will execute
- **File assignment** — Designer file distribution (if determined)
- **Dependency graph** — component/store/API relationships
- **Risk highlights** — from plan-review (if applicable)

Use the plan-visualizer skill: `.claude/skills/plan-visualizer/SKILL.md`

## Output

```
📋 TEAM BRAINSTORM COMPLETE
Task: [description]
Plan: _docs/{category}/plan-{feature}.md
Diagram: _docs/{category}/plan-{feature}.visual.html
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
- `plan-visualizer` skill — HTML diagram generation
