---
paths:
  - "_docs/**"
---

# `_docs/` plan storage

Loads when `_docs/` is touched. The 3-bucket model is kept **always-on** in `CLAUDE.md` (it governs decisions made before any doc file is read). Full detail: `docs-lifecycle` skill.

`_docs/` top level has **two kinds of bucket**. Base set:

- **Lifecycle** — `active/{planning,processing}/`, `complete/`, `reference/`, `deprecated/`. All rules below apply.
- **Collection** — `intent/`, `handoff/`. Status↔folder lockstep exempt; **not lifecycle-tidied by default**.

Hard rules:
- Folder ↔ `status` lockstep (**lifecycle buckets only**): `planning → processing → complete → reference`, or `→ deprecated`, or revive `deprecated → active`.
- Filename `YYYY-MM-DD-<topic>[-<kind>].md` (all hyphens; `<kind>` ∈ intent/research/stack-decision/spec/plan/impl/findings/handoff, required when ≥2 docs share topic+date). Topics come from the `index.md` controlled vocabulary (reuse-or-register). **Applies to every bucket, collections included.**
- Every status move is a **reference-safe transaction** — rewrite cross-bucket links (incl. `.claude/wiki/` and every collection bucket).
- A task's sidecar docs **merge into one** on completion — **lifecycle buckets only**. A collection doc is never swept into a merge.
- **Collection buckets are agent-read, agent-append, never agent-reorganized.** Create new files freely; MUST NOT merge, restructure, rename, or `git rm` existing ones on your own initiative. Deprecate in place under `<collection>/deprecated/`. A project that wants a collection actively curated (e.g. AI-reconstructed meeting notes) MUST say so in its project-profile; absent that line, leave it raw.
- **Worktree isolation**: `_docs/` lives ONLY in the **primary working tree**; linked worktrees read/write doc **content** files there by absolute path (`$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/_docs`), each owning distinct files — only `index.md` edits + status-moves are orchestrator-serialized. Keeps plans readable from main without cd-ing into a worktree. (Detail: `docs-lifecycle` → Concurrency.)
- `index.md` is the SSOT (① status list ② handoffs ③ topic vocabulary ④ declared collection buckets) — MUST update on any create/move/merge.
- **Intent** lives in `_docs/intent/` (flat, `YYYY-MM-DD-<topic>-intent.md`), the durable record of what was asked. Rejected/superseded intents go to `_docs/intent/deprecated/`, never the global `deprecated/`.
- **Handoffs** live in `_docs/handoff/` (flat, dated `YYYY-MM-DD-<topic>-handoff.md`), link their spec via `related:`, keep only the latest per work-stream (`git rm` superseded — the one curated collection, by its ephemeral nature). Generate with the `handoff` skill.

Apply at every phase transition and before marking work complete. Orphan-document defenses (6 invariants) are enforced by `/docs-sweep`.
