---
name: plan-visualizer
description: "Generate interactive HTML visualization of team plans. Use after plan is finalized in /team, /team-run, or /team-brainstorm. Creates a visual diagram showing team composition, phase flow, file assignments, and dependency graph. Saves HTML alongside the plan .md file."
---

# Plan Visualizer

Generate an interactive HTML diagram from a finalized team plan. The HTML file is saved in the same directory as the plan .md file.

## When to Use

- After Phase 1 (Planning) completes in `/team`, `/team-run`, or `/team-brainstorm`
- After plan updates (post-escalation re-planning)

## Input

The orchestrator provides:
- Plan document content (from `_docs/active/planning/<created>/<created>-<topic>-plan.md`)
- Team composition (which roles are involved)
- File assignments (Designer → file mapping)

## Output

Save HTML file at: `_docs/active/planning/<created>/<created>-<topic>-plan.visual.html`
Add link in plan .md under the title:

```markdown
# [Task Name]

> Status: Planning
> [View Plan Diagram](./<created>-<topic>-plan.visual.html)
```

## Sections

Fill `resources/template.html` — the full self-contained skeleton (dark-theme CSS tokens, role/phase colors, six section shells). Read it and fill the placeholders; do not re-invent the markup or the palette.

| # | Section | Content |
|---|---------|---------|
| 1 | Header | Task name · status badge · team members · timestamp |
| 2 | Team Composition | One card per role (icon/name/responsibility); `.inactive` for roles not in this task |
| 3 | Phase Flow | 5 phases as connected nodes; dashed border = conditional (UI/UX); red arrows = escalation; Leader Gate as a gate node |
| 4 | File Assignment | Designer ID → files → scope, color-coded per Designer; worktree branch if known |
| 5 | Dependency Graph | Components/stores/APIs as nodes with data-flow arrows; frontend=green, backend=blue, shared=yellow |
| 6 | Risk Summary | Only if plan-review ran — CRITICAL/HIGH first, each with recommendation |

Skip any section with no data (e.g. no file assignments yet).

## Generation Rules

1. **Self-contained**: No external CSS/JS/fonts — everything inline
2. **Dark theme**: Use the CSS custom properties defined in `resources/template.html` — do not introduce new colors
3. **Responsive**: Works on desktop and tablet
4. **Dynamic content**: Fill sections based on actual plan data
5. **Same directory**: Save HTML next to the plan .md file
6. **Link in .md**: Always add `[View Plan Diagram](./filename.visual.html)` link

## Integration Points

| Caller | Generate | Update |
|--------|----------|--------|
| `/team-brainstorm` | after Step 7 (Save plan) — final output | — |
| `/team` | after Phase 1 + 2, before Leader Gate | after each phase completes |
| `/team-run` | after Phase 1 | after Phase 3, 4, 5 with progress indicators |

On escalation-driven re-planning, regenerate with the phase flow highlighting the re-entry point plus an escalation-log section.
