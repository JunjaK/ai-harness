---
description: "Plan Visualizer — render a finalized team plan as an interactive HTML diagram (explicit request only; no phase auto-fires it)"
---

# Plan Visualizer

Turn a plan document into an interactive HTML diagram — team composition, phase flow, file assignments, dependency graph — saved alongside the plan `.md`.

**On-demand only.** No workflow phase generates this by itself; `/team`, `/team-run`, and `/team-brainstorm` finish their planning phase without it. Run this command when you actually want the picture.

## Usage

```
/plan-visualizer                      # visualize the most recent plan in _docs/active/planning/
/plan-visualizer <path-to-plan.md>    # visualize a specific plan
```

## What It Does

Invoke the `plan-visualizer` skill.

- No path given → resolve the newest `_docs/active/planning/<created>/<created>-<topic>-plan.md`. If none exists, say so and stop; MUST NOT visualize a `complete/` doc or invent a plan.
- Path given → use it verbatim.
- Write the HTML next to the plan `.md`, then report its absolute path.

## Related

- `plan-visualizer` skill — the generator this command fires
- `/team` · `/team-run` · `/team-brainstorm` — produce the plans this renders

ARGUMENTS: $ARGUMENTS
