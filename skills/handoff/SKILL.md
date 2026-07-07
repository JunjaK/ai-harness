---
name: handoff
description: "Write a handoff document — a state layer over a spec/plan capturing what's done, what's left, and how to resume — when work passes to another agent or a future session. Use at session end with unfinished work, before a compaction that ends active work, or when explicitly handing a task off. Writes into `_docs/handoff/` per the docs-lifecycle convention and links (never duplicates) the spec it hands off."
---

# Handoff

A handoff is the **state layer** over a spec/plan: not the design (that lives in the spec), but "where the work actually is right now and how to pick it up." It exists so the next agent or session resumes in minutes instead of re-deriving context. Governed by `docs-lifecycle` (the `_docs/handoff/` bucket); this skill is how you write one correctly. The read/resume counterpart is the **`take-over`** skill — it consumes this doc, verifies its state against the repo, and **graduates** it into its durable `_docs` home (a `complete/` archive or a `plan`) on intake. A handoff is a temp carrier — never left to linger, never bare-deleted.

## When to write one

- Session ending with active (`processing`) work that isn't done.
- A compaction is about to end an active work-stream (the pre-compact hook may trigger this).
- Explicitly handing a task to another agent/teammate.
- NOT for completed work — that goes through `docs-lifecycle` merge-on-complete into `complete/<topic>/`, not a handoff.

## Hard rules

- **Location**: `_docs/handoff/` (flat — handoffs are often cross-cutting, so no topic subfolder). Exempt from date/topic subfoldering but NOT from the reference-rewrite sweep.
- **Name**: `YYYY-MM-DD-<topic>-handoff.md`, where `<topic>` is from the `index.md` controlled vocabulary.
- **Link, never duplicate**: `related:` points at the spec/plan/impl docs being handed off. Do NOT restate the design — if you find yourself copying architecture into the handoff, link instead.
- **Keep only the latest per work-stream**: before writing, `git rm` any superseded handoff for the same topic (git history is the trail; a stale handoff is a liability). Update `index.md` accordingly.
- **`related:` must resolve**: it is subject to docs-lifecycle invariants I2/I6 — if a linked doc later moves, the reference-safe move transaction repoints this handoff.

## Frontmatter

```yaml
---
title: <topic> handoff — YYYY-MM-DD
status: processing
topic: <kebab-case, in index.md vocabulary>
kind: handoff
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: [<repo-relative paths to the spec/plan/impl docs>]
---
```

## Body (sections — omit empty ones)

1. **State** — what is DONE (with evidence: commits, passing tests, merged PRs) vs NOT done. Be concrete and falsifiable.
2. **Remaining work** — the ordered list of what's left, each item actionable on its own.
3. **How to resume** — exact commands / files / branch / worktree to re-enter; any env or infra preconditions.
4. **Open questions / risks** — decisions still pending, known traps, things that bit you.
5. **Pointers** — `related:` spelled out in prose with one-line "what's in each."

## Procedure

1. Identify the work-stream topic (reuse an `index.md` vocabulary entry; do not invent a near-duplicate).
2. `git rm` any prior handoff for the same topic; remove its `index.md` row.
3. Write `_docs/handoff/YYYY-MM-DD-<topic>-handoff.md` with the frontmatter + body above, `related:` linking the spec(s).
4. Add an `index.md` row (active list) for the new handoff.
5. One commit: `docs: handoff <topic> (state + remaining work)`.
