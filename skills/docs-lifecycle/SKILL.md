---
name: docs-lifecycle
description: "Manage the lifecycle of project documents (plans, specs, findings) in `_docs/` — status↔folder lockstep, and merging a task's scattered sidecar docs into ONE archive document on completion. Use whenever a plan/spec is created, moves between stages, or a task finishes; and whenever `_docs/` is accumulating multiple files for the same task. Trigger this at every team-workflow phase transition and before marking any work complete — scattered, status-stale docs are the failure this prevents."
---

# Docs Lifecycle

Keep `_docs/` honest and useful as it grows. Two problems this prevents: (1) a document's stated `status` drifting out of sync with where it actually is in the work, and (2) a finished task leaving behind a scatter of spec + plan + metrics + findings files that no future reader can reassemble. The fix is a fixed folder lifecycle with status in lockstep, and a **merge-on-completion** rule.

## Folder lifecycle

```
_docs/
├── active/
│   ├── planning/     # spec/plan being written (before implementation starts)
│   └── processing/   # implementation in progress
├── complete/         # implemented, verified, merged (staging area)
├── reference/        # durable, consolidated reference (organized by topic subfolder)
├── deprecated/       # abandoned / superseded / out of scope
└── index.md          # one line per active + complete doc
```

Lifecycle: `planning → processing → complete → (consolidate) → reference`, or from anywhere `→ deprecated` (or delete). `reference/` is never a flat dump — group by topic subfolder (`reference/auth/`, `reference/api-standard/`), created when first needed.

## Frontmatter (every `_docs/**/*.md`)

```yaml
---
title: <document title>
status: planning | processing | complete | deprecated | reference
scope: <fullstack | backend | frontend | …, if the project has boundaries>
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: [<relative paths to paired docs>]
---
```

**`status` MUST match the folder.** They are one fact stored twice; when they disagree, a reader can't trust either. A status change is therefore always: move the file to the new folder (`git mv`) + update `status` + update `updated` — in the same change.

> Write docs in the project's working language (match existing `_docs/`), keeping code identifiers, paths, and API routes verbatim.

## Status transitions

| Trigger | Action |
|---------|--------|
| New spec/plan written | `status: planning`, place in `active/planning/` |
| First implementation commit (or first task → in-progress) | `planning → processing`: `git mv` to `active/processing/`, bump `updated` |
| Implemented + verified + merged | `processing → complete`: apply the **merge rule below** |
| Abandoned / superseded | Judge worth: decision rationale useful later → `deprecated/`; pure noise/duplicate → delete (`git rm`; history keeps it) |
| Consolidating completed work | Write a new consolidated doc directly into `reference/<topic>/` |

## Merge rule (REQUIRED on completion)

When a task produced **multiple sidecar docs** (spec, plan, metrics, findings, sub-reports), merge them into **one** document when moving to `complete/` — do not archive a scatter.

1. Create one file `_docs/complete/YYYY-MM-DD-<feature>.md` (keep the start date as prefix).
2. Body sections, in this order (omit empty ones — do NOT copy every step verbatim):
   - `## Spec` — intent / goal / non-goal / architecture decisions
   - `## Plan` — the meaningful decisions and phase outcomes (not the full step list)
   - `## Findings & Metrics` — what was discovered, measured, the design lessons
   - `## Final Summary` — PR link, commit range, one-line impact
3. Clear `related:` (it is now one self-contained file).
4. `git rm` the original sidecar docs (history preserves them).
5. Update `index.md`: remove the originals from Active, add the one consolidated file to Complete.
6. One commit: `docs: archive <feature> to complete (merged spec + plan + metrics)`.

**Exception**: a task with a single active doc and no sidecars → just `git mv` it to `complete/`, body unchanged.

**Why**: a completed task's spec + plan + findings split across files has near-zero archive value. One document answering "why we started / how we did it / what we learned" is what makes the next task able to reuse it — and it stops `active/` from bloating.

## Index

`_docs/index.md` lists active + complete docs (one line each). Update it in the same change as any create / status-move / merge — a stale index is as misleading as a stale status.

## Team Workflow Integration

- **Phase 1 complete**: plan written → `active/planning/`, `status: planning`, indexed.
- **Phase 3 start**: `planning → processing`.
- **Phase 5 complete (merged)**: apply the merge rule → `complete/`. If several PRs follow one plan, merge once at series completion (or per-PR if the user prefers).
- Replaces the harness's coarser single-plan "In Progress/Verification" status with the explicit folder lifecycle above; the plan doc still lives under `_docs/<category>/` but now carries status↔folder discipline and gets consolidated on completion.
