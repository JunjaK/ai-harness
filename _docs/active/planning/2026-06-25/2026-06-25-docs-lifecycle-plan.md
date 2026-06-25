---
title: "Plan — docs-lifecycle v2: bucket adoption + date/topic foldering + orphan defenses"
status: planning
topic: docs-lifecycle
kind: plan
scope: harness
created: 2026-06-25
updated: 2026-06-25
---

# Plan — docs-lifecycle v2: bucket adoption + date/topic foldering + orphan defenses

> Sub-project **#2 of 3** (FOUNDATION). Downstream `#3 /docs-sweep` and `#1 /team-new` both consume this layout, so this lands first.

## Goal

Make `_docs/` survive heavy plan-writing volume without producing **orphan documents**. Adopt the status-bucket lifecycle the `docs-lifecycle` skill only *described* but the repo never implemented, and add a second organizing axis: **date subfolders for active docs, topic subfolders for done docs**. Every structural weakness that could strand a document is closed by an explicit, automated defense.

## Non-goals

- The reaping/lint *automation* and the SessionStart nudge — that is sub-project **#3** (`/docs-sweep`). This spec only **defines** the 6 invariants the lint will enforce.
- `/team-new` greenfield bootstrap — sub-project **#1**. This spec only reserves its `project-bootstrap` topic and confirms the foldering it writes into.

## Background — the correction that reframed this work

The original premise was "the status buckets exist; just add a second axis." **They do not exist on disk.** Verified reality:

- Real `_docs/` is `{category}/plan-{feature}.md` (`harness-evolution/`) + a free-text `Status`/`Category` table in `index.md`. No `active/`, `complete/`, `reference/` directories.
- `docs-lifecycle/SKILL.md` *describes* `active/{planning,processing}/ complete/ reference/ deprecated/` but **nothing adopted it**.
- Four places hardcode the old path: `agents/team-leader.md`, `skills/team-workflow/SKILL.md`, `skills/plan-visualizer/SKILL.md`, and `CLAUDE.md` "Plan Storage".
- `docs-lifecycle/SKILL.md:86` writes the merge target **flat** (`complete/YYYY-MM-DD-<feature>.md`) — directly contradicting the planned `complete/<topic>/` subfolder.
- `docs-lifecycle/SKILL.md:109` references a **`handoff` skill that does not exist**.

So this is **bucket introduction + migration of 8 docs + 4 path rewrites + handoff-skill implementation + the foldering/transaction rules** — not an additive tweak. Decisions taken: **full migration**, **implement the handoff skill**.

## Decisions (locked)

| # | Decision |
|---|----------|
| D1 | Keep status as the **top-level axis** (status↔folder lockstep preserved); add date/topic as a **2nd axis inside** each bucket. |
| D2 | Active (`planning`,`processing`) → **date** subfolder (`<created>/`). Done (`complete`) → **topic** subfolder. `reference/` already topic. `deprecated/`, `handoff/` stay flat. |
| D3 | Filename grammar: **`YYYY-MM-DD-<topic>[-<kind>].md`**, all hyphens. `<kind>` REQUIRED when ≥2 docs share topic+date (`brief`/`research`/`stack-decision`/`spec`/`plan`/`impl`/`findings`). |
| D4 | Date = **`created`** (immutable). The created-date folder leaf does **not** change on `planning→processing`. |
| D5 | Topic = **kebab-case**, drawn from a **controlled vocabulary enumerated in `index.md`** (SSOT). New topic only if no existing `complete/`/`reference/` topic fits. |
| D6 | Every status transition is a **reference-safe transaction** (below). |
| D7 | **Full migration** of the 8 existing docs + 4 path rewrites. |
| D8 | **Implement** the `handoff` skill (resolve the dangling reference). |

## Target structure

```
_docs/
├── active/
│   ├── planning/<created>/    YYYY-MM-DD-<topic>[-<kind>].md
│   └── processing/<created>/  YYYY-MM-DD-<topic>[-<kind>].md
├── complete/<topic>/          YYYY-MM-DD-<topic>[-<kind>].md
├── reference/<topic>/         (unchanged: topic-foldered durable synthesis)
├── deprecated/                (flat)
├── handoff/                   (flat, ephemeral, keep-latest-per-stream)
└── index.md                   ① status doc list  ② TOPIC VOCABULARY (SSOT)
```

`exempt` means **exempt from date/topic subfoldering ONLY** — `deprecated/`, `handoff/`, and the act of *pointing into* `reference/` are all still **in-scope for the reference-rewrite sweep and the dangling-link lint**. This disambiguation is load-bearing (it closes orphan modes 1 & 6).

## Frontmatter (every `_docs/**/*.md`, except `_note/`)

```yaml
---
title: <title>
status: planning | processing | complete | deprecated | reference
topic: <kebab-case, must be in index.md vocabulary>
kind: brief | research | stack-decision | spec | plan | impl | findings | handoff
scope: <fullstack | backend | frontend | …>
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: [<repo-relative paths>]
revived: YYYY-MM-DD        # only when un-deprecated
---
```

`status` MUST equal the bucket; `topic` MUST equal the topic folder (for `complete`/`reference`); `created` MUST equal the date folder (for `active`). Three facts, each stored twice, kept in lockstep by the transaction.

## The reference-safe transaction (core mechanism — D6)

Any move of a doc `X` (old path `P_old` → new path `P_new`) is **one atomic unit**:

1. `git mv P_old P_new`.
2. **Cross-bucket reference rewrite**: `grep -rl 'P_old' _docs/ .claude/wiki/` → rewrite each hit `P_old`→`P_new`. Covers **every** `_docs/` bucket (incl. `deprecated/`, `handoff/`) **and** the agent-owned `.claude/wiki/`.
3. **`_note/` is read-only**: do NOT edit it. If `grep -rl 'P_old' _note/` hits, **emit a warning** listing those files so the human can fix them. Never silently leave them dangling without surfacing.
4. Update frontmatter (`status`/`topic`/`created` as applicable, bump `updated`).
5. Update `index.md` (the doc's row + topic-vocabulary list).
6. If a date folder is left empty by the move, `rmdir` it (only if empty; never recursive).
7. One commit.

**Concurrency (closes orphan mode = parallel-worktree race):** `_docs/` moves are **orchestrator-serialized**. Phase-3 Designer worktrees write doc **content** only; the **team-leader/orchestrator** performs every `git mv` + `index.md` edit + commit, after worktree merge. `index.md` rows sort by `(topic, date, kind)` to shrink conflict surface. `_docs/index.md` is added to the parallelization **merge-order** as a shared mutable file. Auto-`rmdir` guards on "empty AND not currently locked."

### Transaction types

| Type | Trigger | Move |
|------|---------|------|
| **status-move** | `planning→processing→complete`, or `*→deprecated` | bucket change (+ date→topic on complete) |
| **merge-on-complete** | task done with sidecars | collapse sidecars → one `complete/<topic>/YYYY-MM-DD-<topic>.md`; **before any `git rm`, run the cross-bucket sweep to repoint inbound `related:` (handoff/wiki) at the consolidated doc** (closes orphan mode 6) |
| **topic-rename / merge** | a topic vocabulary entry is renamed or merged | re-home `complete/<old>/` **and** `reference/<old>/` subtrees + rewrite filenames + cross-bucket link rewrite + update SSOT; if target topic exists it becomes a MERGE honoring "loses nothing" (closes orphan mode 3) |
| **deprecated-revive** | a deprecated doc is revived | `deprecated/→active/planning/<today>/`; KEEP original `created`, add `revived:` field (avoids depending on a possibly-rmdir'd old date folder); cross-bucket link rewrite (closes orphan mode 5) |

## The 6 orphan-mode invariants (lint enforces in #3; defined here)

| I# | Invariant | Orphan mode it kills |
|----|-----------|----------------------|
| I1 | `index.md` ↔ disk is **bidirectional 1:1** (every active+complete doc has exactly one row; every row resolves to a file). | index drift |
| I2 | **No dangling link** in any `_docs/**` doc (every `related:` + inline `_docs/` link resolves). | broken-link on move |
| I3 | **No off-vocabulary topic folder** under `complete/` or `reference/` (every topic folder ∈ `index.md` SSOT). | topic fragmentation |
| I4 | **No empty date folder** under `active/**`. | empty-folder litter |
| I5 | **Merge-on-complete loses nothing**: every sidecar enumerated via `related:` + same-(topic,date) grep before `git rm`. | merge deletion |
| I6 | **No dangling `_docs/` link from `.claude/wiki/**`**; `_note/` references to moved docs are surfaced as warnings. | cross-bucket rot |

## handoff skill (D8 — implement)

New `skills/handoff/SKILL.md`. A handoff is a **state layer** over a spec/plan ("done / left / how to resume"), written when work passes to another agent/session.

- Writes into `_docs/handoff/` (flat), name `YYYY-MM-DD-<topic>-handoff.md`, `kind: handoff`.
- `related:` links the spec/plan it hands off; **never duplicates** the design.
- **Retention: keep only the latest per work-stream**; `git rm` superseded ones (history is the trail).
- Subject to the reference-rewrite sweep & I2/I6 (its `related:` must always resolve).
- Fixes the dangling `docs-lifecycle/SKILL.md:109` reference (it now points at a real skill).

## Migration plan (D7) — the 8 docs + 4 rewrites

Current → new (topic in **bold**; all currently `harness-evolution` category):

| Current | Status | New path |
|---------|--------|----------|
| `harness-evolution/plan-harness-v2.md` (+`.visual.html`) | Planning | `active/planning/2026-04-16/2026-04-16-`**`harness-v2`**`-plan.md` (+ `.visual.html` sidecar travels with it) |
| `harness-evolution/plan-agentic-testing.md` | Processing | `active/processing/2026-06-23/2026-06-23-`**`agentic-testing`**`-plan.md` |
| `harness-evolution/impl-agentic-testing.md` | Processing | `active/processing/2026-06-23/2026-06-23-agentic-testing-impl.md` |
| `harness-evolution/plan-doc-storage-system.md` | Processing | `active/processing/2026-06-23/2026-06-23-`**`doc-storage`**`-plan.md` |
| `harness-evolution/plan-ponytail-yagni.md` | Processing | `active/processing/2026-06-23/2026-06-23-`**`ponytail-yagni`**`-plan.md` |
| `harness-evolution/plan-test-scenario-doc.md` | Processing | `active/processing/2026-06-24/2026-06-24-`**`test-scenario-doc`**`-plan.md` |
| `handoff/2026-06-23-session-handoff.md` | Processing | `handoff/2026-06-23-agentic-testing-handoff.md` (stays flat; renamed to match `topic`; add frontmatter) |
| *this file* `plan-docs-lifecycle-v2.md` | Planning | `active/planning/2026-06-25/2026-06-25-`**`docs-lifecycle`**`-plan.md` |

Migration steps:
1. `git mv` each into the new layout (reference-safe sweep per move — rewrite any inbound links, esp. the handoff's `related:`).
2. **Add frontmatter** to every migrated doc (they currently have none): `title/status/topic/kind/created/updated/related`. `created` from the index table date; `updated` = today.
3. Rewrite `index.md`: new two-section format (status doc list + topic vocabulary). Seed vocabulary: `agentic-testing, doc-storage, ponytail-yagni, test-scenario-doc, harness-v2, docs-lifecycle` (+ reserved `project-bootstrap` for #1).
4. **4 hardcoded-path rewrites** (parallelizable — disjoint files):
   - `agents/team-leader.md` (L161, L208) `_docs/{category}/plan-{feature}.md` → new layout.
   - `skills/team-workflow/SKILL.md` (L86/L93/L153 references; Phase 1/3/5 doc paths).
   - `skills/plan-visualizer/SKILL.md` (L18/L24/L31 path assumptions).
   - `CLAUDE.md` "Plan Storage" (L247-256 ASCII layout + lifecycle sentence) + Skills-row L288 summary.
5. Rewrite `docs-lifecycle/SKILL.md`: folder lifecycle (L42-53), status transitions (L73-81), **merge target L86** (`complete/<topic>/`), index section (L111-113, add vocabulary SSOT), handoff section (L101-109, point at the real skill), and add the reference-safe-transaction + transaction-types + 6-invariants + concurrency sections.

## Files changed (summary)

- **Rewrite**: `skills/docs-lifecycle/SKILL.md`.
- **New**: `skills/handoff/SKILL.md`.
- **Rewrite paths**: `agents/team-leader.md`, `skills/team-workflow/SKILL.md`, `skills/plan-visualizer/SKILL.md`, `CLAUDE.md`.
- **Migrate**: 8 `_docs/` files + `index.md` rewrite.

## Verification

1. **I3/I4 by construction** after migration: no off-vocab topic folder, no empty date folder.
2. **I1**: every `index.md` row resolves; every active/complete doc has a row. (manual + the #3 lint once built.)
3. **I2/I6**: `grep -rn '_docs/.*plan-' _docs .claude CLAUDE.md agents skills` returns **zero** stale `{category}/plan-*` paths after the 4 rewrites + migration.
4. The handoff doc's `related:` resolves post-move.
5. `docs-lifecycle/SKILL.md` has no remaining reference to a non-existent skill; `skills/handoff/` exists.

## Downstream hooks (for #3 / #1)

- **#3** consumes: the bucket layout, the 6 invariants (lint targets), the reference-safe transaction (sweep reuse), `updated` frontmatter (staleness source).
- **#1** consumes: `active/planning/<date>/` for G0-G2 bootstrap docs (`-<kind>` sidecars), reserved topic `project-bootstrap`, merge-on-complete for the final handoff, the `handoff` skill.
