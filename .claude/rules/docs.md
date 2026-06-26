---
paths:
  - "_docs/**"
  - "_note/**"
---

# `_docs/` plan storage

Loads when `_docs/`/`_note/` are touched. The 3-bucket model and the `_note/` read-only rule are kept **always-on** in `CLAUDE.md` (they govern decisions made before any doc file is read). Full detail: `docs-lifecycle` skill.

`_docs/` is organized by **status × date/topic**. Hard rules:
- Folder ↔ `status` lockstep: `planning → processing → complete → reference`, or `→ deprecated`, or revive `deprecated → active`.
- Filename `YYYY-MM-DD-<topic>[-<kind>].md` (all hyphens; `<kind>` ∈ brief/research/stack-decision/spec/plan/impl/findings, required when ≥2 docs share topic+date). Topics come from the `index.md` controlled vocabulary (reuse-or-register).
- Every status move is a **reference-safe transaction** — rewrite cross-bucket links (incl. `.claude/wiki/`), warn on `_note/`.
- A task's sidecar docs **merge into one** on completion.
- `index.md` is the SSOT (① status list ② handoffs ③ topic vocabulary) — MUST update on any create/move/merge.
- **Handoffs** live in `_docs/handoff/` (flat, dated `YYYY-MM-DD-<topic>-handoff.md`), link their spec via `related:`, keep only the latest per work-stream (`git rm` superseded). Generate with the `handoff` skill.

Apply at every phase transition and before marking work complete. Orphan-document defenses (6 invariants) are enforced by `/docs-sweep`.
