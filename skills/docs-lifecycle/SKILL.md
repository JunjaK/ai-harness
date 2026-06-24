---
name: docs-lifecycle
description: "Manage the lifecycle of project documents (plans, specs, findings) in `_docs/` — status↔folder lockstep, and merging a task's scattered sidecar docs into ONE archive document on completion. Use whenever a plan/spec is created, moves between stages, or a task finishes; and whenever `_docs/` is accumulating multiple files for the same task. Trigger this at every team-workflow phase transition and before marking any work complete — scattered, status-stale docs are the failure this prevents."
---

# Docs Lifecycle

Keep `_docs/` honest and useful as it grows. Two problems this prevents: (1) a document's stated `status` drifting out of sync with where it actually is in the work, and (2) a finished task leaving behind a scatter of spec + plan + metrics + findings files that no future reader can reassemble. The fix is a fixed folder lifecycle with status in lockstep, and a **merge-on-completion** rule.

## Three-bucket document storage

`_docs/` is one of **three document buckets**. Each bucket has a different OWNER, and the owner decides who may write it and what automation applies. Classify every document by ownership, not by name.

| Bucket | Owner | Location | Automation | What lives here |
|--------|-------|----------|------------|-----------------|
| `_docs/` | the project | repo root | this skill (auto-move, merge-on-complete, `git rm`) | plans, specs, ADRs, findings — project knowledge |
| `_note/` | the human | repo root, one central dir | **none — agent read-only** | the owner's personal / research / scratch notes |
| `.claude/wiki/` | the agent | `.claude/` (tool-coupled) | the `wiki` skill (ingest/query/lint) | the agent's compounding knowledge synthesis |

### The discriminator (classify ANY new document with this)

> **"If you swapped this agent CLI for a different one, would this document still be meaningful?"**
> - **Yes** → it belongs to the project or the human → repo root with a `_` prefix (`_docs/` or `_note/`).
> - **No — it is agent-only knowledge** → under `.claude/`.
>
> The axis is **ownership and tool-coupling, NOT the name.** "They all start with `_`, group them" and "put everything under `.claude/`" are both wrong groupings. Decide per document with this question.

### `_note/` governance (human-owned, agent read-only)

`_note/` is the owner's unstructured scratch tier — a place to keep notes without `_docs/` automation friction.

- **Agent read-only (load-bearing).** MUST NOT create, move, merge, reorganize, or delete anything under `_note/` on your own initiative. Modify `_note/` ONLY when the human explicitly asks; otherwise read it for context and leave it untouched. Without this rule `_note/` regresses into an unmanaged junk drawer.
- **Exempt from `_docs/` automation.** `_note/` is NOT subject to the folder lifecycle, status frontmatter, or merge-on-completion below. Never apply the `_docs/` rules to it.
- **No frontmatter / lifecycle required.** Notes are dumped freely; forcing the 6-field frontmatter defeats a scratch tier.
- **One central dir at repo root.** Keep a single `_note/` at the repo root (not per-subdir / per-submodule). In multi-repo or submodule setups this stops personal notes from polluting shared history; preserve provenance with subfolders (`_note/<source>/`).
- **Graduation path.** A note the owner judges project-canonical can be promoted `_note/ → _docs/` — but only the owner decides, never the agent unprompted.

The rest of this skill governs the **`_docs/` bucket**.

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

## Handoff documents

A handoff is a **state layer** over a spec/plan — "what's done, what's left, how to resume" — written when work passes to another agent or a future session. It is ephemeral and **links** to the spec (never duplicates the design).

- **Location: `_docs/handoff/`** (flat, dated). Naming: `YYYY-MM-DD-<topic>-handoff.md`. Handoffs are often cross-cutting (span multiple specs), so they do NOT live under a single category folder.
- **`related:` links the spec/plan docs** it hands off; the design stays in those — the handoff carries only current state + remaining work + reproduction.
- **Retention: keep only the latest handoff per work-stream.** When a newer handoff supersedes it, or the work completes, `git rm` the stale one (git history is the trail — a stale handoff is a liability, not an archive).
- Index: list a live handoff in `index.md` like any active doc; remove its row when superseded.
- Generation: use the `handoff` skill — it detects this convention and writes into `_docs/handoff/`.

## Index

`_docs/index.md` lists active + complete docs (one line each). Update it in the same change as any create / status-move / merge — a stale index is as misleading as a stale status.

## Team Workflow Integration

- **Phase 1 complete**: plan written → `active/planning/`, `status: planning`, indexed.
- **Phase 3 start**: `planning → processing`.
- **Phase 5 complete (merged)**: apply the merge rule → `complete/`. If several PRs follow one plan, merge once at series completion (or per-PR if the user prefers).
- Replaces the harness's coarser single-plan "In Progress/Verification" status with the explicit folder lifecycle above; the plan doc still lives under `_docs/<category>/` but now carries status↔folder discipline and gets consolidated on completion.
