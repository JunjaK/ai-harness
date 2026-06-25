---
name: docs-lifecycle
description: "Manage the lifecycle of project documents (plans, specs, findings) in `_docs/` — status↔folder lockstep, date/topic foldering, reference-safe moves, and merging a task's scattered sidecar docs into ONE archive on completion. Use whenever a plan/spec is created, moves between stages, a topic is renamed, or a task finishes; and whenever `_docs/` is accumulating multiple files for the same task. Trigger at every team-workflow phase transition and before marking any work complete — scattered, status-stale, or orphaned docs are the failure this prevents."
---

# Docs Lifecycle

Keep `_docs/` honest and useful as it grows under heavy plan-writing volume. The failure this prevents is **orphan documents** — docs that drift out of `status`, get stranded by a folder move, fragment across near-duplicate topic folders, pile up in `active/` forever, or lose inbound links when a file moves. The fix is a fixed two-axis layout (status × date/topic), a **reference-safe move transaction**, a **merge-on-completion** rule, and six invariants an automated lint enforces.

## Three-bucket document storage

`_docs/` is one of **three document buckets**. Each has a different OWNER, who decides who may write it and what automation applies. Classify by ownership, not by name.

| Bucket | Owner | Location | Automation | What lives here |
|--------|-------|----------|------------|-----------------|
| `_docs/` | the project | repo root | this skill (move/merge/`git rm`) + `/docs-sweep` lint | plans, specs, ADRs, findings — project knowledge |
| `_note/` | the human | repo root, one central dir | **none — agent read-only** | the owner's personal / research / scratch notes |
| `.claude/wiki/` | the agent | `.claude/` (tool-coupled) | the `wiki` skill (ingest/query/lint) | the agent's compounding knowledge synthesis |

### The discriminator (classify ANY new document with this)

> **"If you swapped this agent CLI for a different one, would this document still be meaningful?"**
> - **Yes** → project or human → repo root with a `_` prefix (`_docs/` or `_note/`).
> - **No — agent-only knowledge** → under `.claude/`.
>
> The axis is **ownership and tool-coupling, NOT the name.**

### `_note/` governance (human-owned, agent read-only)

- **Agent read-only (load-bearing).** MUST NOT create, move, merge, reorganize, or delete anything under `_note/` on your own initiative. Modify ONLY on explicit human request; otherwise read for context and leave untouched.
- **Exempt from `_docs/` automation** (folder lifecycle, status frontmatter, merge-on-completion). But see the reference-safe transaction: a move that breaks a `_note/` link is **surfaced as a warning** (the agent does not edit `_note/`, it tells the human).
- **No frontmatter / lifecycle required.** One central `_note/` at repo root; preserve provenance with `_note/<source>/` subfolders.
- **Graduation path.** A note the owner judges project-canonical can be promoted `_note/ → _docs/` — owner decides, never the agent unprompted.

The rest of this skill governs the **`_docs/` bucket**.

## Folder lifecycle — two axes

Top axis = **status** (status↔folder lockstep). Second axis inside each bucket = **date for active, topic for done**.

```
_docs/
├── active/
│   ├── planning/<created>/     YYYY-MM-DD-<topic>[-<kind>].md   # date subfolder
│   └── processing/<created>/   YYYY-MM-DD-<topic>[-<kind>].md   # date subfolder
├── complete/<topic>/           YYYY-MM-DD-<topic>[-<kind>].md   # topic subfolder
├── reference/<topic>/          # durable consolidated synthesis, topic subfolder
├── deprecated/                 # flat
├── handoff/                    # flat, ephemeral, keep-latest-per-stream
└── index.md                    # ① status list  ② handoffs  ③ TOPIC VOCABULARY (SSOT)
```

Lifecycle: `planning → processing → complete → (consolidate) → reference`, or from anywhere `→ deprecated`; and `deprecated → active/planning` (revive). `reference/` and `complete/` are **never flat dumps** — always grouped by topic subfolder.

**`exempt` means exempt from date/topic SUBFOLDERING ONLY.** `deprecated/`, `handoff/`, and links *pointing into* `reference/` are still fully **in-scope for the reference-rewrite sweep and the dangling-link lint**. Nothing is exempt from "links must resolve."

## Filename grammar

**`YYYY-MM-DD-<topic>[-<kind>].md`** — all hyphens, no underscores. `<topic>` is the kebab-case controlled-vocabulary topic. `<kind>` ∈ `brief | research | stack-decision | spec | plan | impl | findings | handoff` and is **REQUIRED whenever ≥2 docs share the same (topic, date)** (e.g. the three greenfield bootstrap sidecars). The index key is `(topic, date, kind)` — this is what keeps the 1:1 index invariant under collisions.

## Frontmatter (every `_docs/**/*.md`)

```yaml
---
title: <document title>
status: planning | processing | complete | deprecated | reference
topic: <kebab-case — MUST be in index.md vocabulary>
kind: brief | research | stack-decision | spec | plan | impl | findings | handoff
scope: <fullstack | backend | frontend | …, if the project has boundaries>
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: [<repo-relative paths to paired docs>]
revived: YYYY-MM-DD   # only present after a deprecated→active revive
---
```

**Three facts stored twice, kept in lockstep:** `status`==bucket; `topic`==topic folder (for `complete`/`reference`); `created`==date folder (for `active`). When they disagree a reader can't trust any of them — so a transition always moves the file **and** fixes frontmatter **and** updates the index, in one commit.

> Write docs in the project's working language (match existing `_docs/`), keeping code identifiers, paths, and API routes verbatim.

## Controlled topic vocabulary (SSOT in index.md)

`index.md` carries the **authoritative list of topics**. Rules:

- A new doc's `topic` MUST reuse an existing vocabulary entry if one fits. Create a new topic ONLY when none fits, and add it to `index.md` in the same commit.
- A topic folder under `complete/` or `reference/` that is **not** in the vocabulary is an orphan-fragmentation defect (lint invariant I3).
- Topics are kebab-case, subject-based (`auth`, `agentic-testing`, `doc-storage`), not feature-based — many features can file under one topic.
- `project-bootstrap` is **reserved** for `/team-new` greenfield bootstrap; feature work MUST NOT reuse it.

## Status transitions

| Trigger | Action |
|---------|--------|
| New spec/plan written | `status: planning`, place in `active/planning/<created>/`, assign topic from vocabulary |
| First implementation commit (or first task → in-progress) | `planning → processing`: reference-safe move to `active/processing/<created>/` (date leaf unchanged), bump `updated` |
| Implemented + verified + merged | `processing → complete`: apply the **merge rule** → `complete/<topic>/` |
| Abandoned / superseded | decision rationale useful later → `deprecated/`; pure noise → `git rm` |
| Revived | `deprecated → active/planning/<today>/`: keep original `created`, add `revived:` |
| Consolidating completed work | write a new consolidated doc into `reference/<topic>/` |

## Reference-safe move transaction (REQUIRED for every move)

Any move of doc `X` from `P_old` to `P_new` is **one atomic commit**:

1. `git mv P_old P_new`.
2. **Cross-bucket reference rewrite**: `grep -rl 'P_old' _docs/ .claude/wiki/` → rewrite `P_old`→`P_new` in every hit. Covers ALL `_docs/` buckets (incl. `deprecated/`, `handoff/`) and agent-owned `.claude/wiki/`.
3. **`_note/` is read-only**: if `grep -rl 'P_old' _note/` hits, **emit a warning** listing those files for the human — never edit `_note/`, never leave the break silent.
4. Update `X`'s frontmatter (`status`/`topic`/`created` as applicable; bump `updated`).
5. Update `index.md` (the row + topic vocabulary if a topic was added).
6. If the move empties a date folder, `rmdir` it (only when empty; never recursive).
7. One commit.

### Transaction types

- **status-move** — the table above. `processing→complete` also flips date-axis → topic-axis.
- **merge-on-complete** — see Merge rule.
- **topic-rename / merge** — renaming or merging a vocabulary topic: re-home `complete/<old>/` AND `reference/<old>/` subtrees, rewrite filenames, cross-bucket link rewrite, update the SSOT. If the target topic already exists this becomes a MERGE that honors "loses nothing" (I5). Free-form topic-folder renames outside this transaction are forbidden.
- **deprecated-revive** — `deprecated/→active/planning/<today>/`: KEEP original `created` (so it does not depend on a possibly-rmdir'd old date folder), add `revived: <today>`, cross-bucket link rewrite.

### Concurrency (orchestrator-serialized)

`_docs/` moves are **serialized through the team-leader/orchestrator**. Parallel Phase-3 Designer worktrees write doc **content** only; the orchestrator performs every `git mv` + `index.md` edit + commit **after** worktree merge. `index.md` rows sort by `(topic, date, kind)` to shrink merge-conflict surface. `_docs/index.md` is part of the parallelization **merge-order** as a shared mutable file. Auto-`rmdir` only when the folder is empty and unlocked.

## Merge rule (REQUIRED on completion)

When a task produced **multiple sidecar docs** (spec, plan, metrics, findings, sub-reports), merge them into **one** on the move to `complete/` — do not archive a scatter.

1. Create one file `_docs/complete/<topic>/YYYY-MM-DD-<topic>.md` (start date as prefix; topic from vocabulary).
2. Body sections, in order (omit empty ones — do NOT copy every step verbatim):
   - `## Spec` — intent / goal / non-goal / architecture decisions
   - `## Plan` — meaningful decisions and phase outcomes (not the full step list)
   - `## Findings & Metrics` — what was discovered, measured, design lessons
   - `## Final Summary` — PR link, commit range, one-line impact
3. **Before any `git rm`**, enumerate sidecars via `related:` + a same-`(topic,date)` grep, and run the cross-bucket reference-rewrite so every inbound link (handoff/wiki `related:`) repoints to the consolidated doc — never delete-then-leave-dangling (I5/I6).
4. Clear `related:` (now one self-contained file).
5. `git rm` the original sidecars (history preserves them).
6. Update `index.md`: remove originals from the active list, add the consolidated file under Complete.
7. One commit: `docs: archive <topic> to complete (merged spec + plan + metrics)`.

**Exception**: a task with a single active doc and no sidecars → just a reference-safe move to `complete/<topic>/`, body unchanged.

## Orphan-mode invariants (lint enforces — see `/docs-sweep`)

| I# | Invariant |
|----|-----------|
| I1 | `index.md` ↔ disk is bidirectional 1:1 (key `(topic,date,kind)`). |
| I2 | No dangling link in any `_docs/**` doc (`related:` + inline `_docs/` links resolve). |
| I3 | No off-vocabulary topic folder under `complete/` or `reference/`. |
| I4 | No empty date folder under `active/**`. |
| I5 | Merge-on-complete loses nothing (sidecars enumerated + inbound links repointed before `git rm`). |
| I6 | No dangling `_docs/` link from `.claude/wiki/**`; `_note/` references to moved docs are surfaced as warnings. |

## Sweep & Lint (`/docs-sweep`)

`active/` accumulates and orphans creep in over time. `/docs-sweep` drains and re-verifies; a `SessionStart` hook nudges when it's overdue. Two halves:

### REAP — drain `active/` (signal-gated, NEVER age-gated)

For each `_docs/active/**/*.md`: `staleness = today − frontmatter.updated` (default threshold **14 days**). Then gather **signals** — linked PR merged? branch gone? recent commits touching its `related:`/own path? — and **let signals decide; age only flags**:

- Strong "done" signal (PR merged / branch gone) → propose **`→ complete`** (apply the Merge rule).
- Strong "abandoned" signal (superseded / explicitly dropped) → propose **`→ deprecated`**.
- **No corroborating signal** (local-only / no-remote repo — e.g. a fresh `/team-new` bootstrap) → age can **only FLAG** → propose **`snooze`** (bump `updated`, record a one-line reason). **NEVER silent auto-complete.**

Signal precedence on conflict: `PR merged` > `branch gone` > `recent commits`. **Every reap action requires a per-doc decision** (human, or orchestrator on strong signals only in autonomous mode).

### LINT — enforce the 6 invariants

Static pass over `_docs/**` + `.claude/wiki/**`; report + auto-fix where safe:

| I# | Check | Auto-fix |
|----|-------|----------|
| I1 | `index.md` ↔ disk 1:1 (key `(topic,date,kind)`) | propose row add/remove |
| I2 | no dangling `_docs/` link (ignore `<other-repo>/_docs/…` prefixes) | no (needs intent) |
| I3 | no off-vocabulary `complete/`/`reference/` topic folder | propose vocab-add or topic-rename |
| I4 | no empty `active/**` date folder | `rmdir` |
| I5 | no `active/` sidecar sharing `(topic,date)` with a `complete/<topic>` doc | propose merge |
| I6 | no dangling `_docs/` link from `.claude/wiki/`; `_note/` refs surfaced as warnings | wiki: yes; `_note/`: warn-only |

### Detection — `SessionStart` hook

`hooks/session-start.sh` does a cheap mtime scan of `_docs/active/`; if any doc is older than the threshold it emits **one** non-blocking nudge line (`exit 0`, stdout) — `⚠ N stale active docs (untouched >14d) — run /docs-sweep`. Silent when clean; exits 0 silently when `_docs/active` is absent (so it never false-alarms in repos that haven't adopted the layout).

## Handoff documents

A handoff is a **state layer** over a spec/plan — "what's done, what's left, how to resume" — written when work passes to another agent or future session. Ephemeral; **links** to the spec, never duplicates the design.

- **Location: `_docs/handoff/`** (flat, dated). Name `YYYY-MM-DD-<topic>-handoff.md`, `kind: handoff`. Handoffs are often cross-cutting, so they do not live under a topic folder.
- **`related:` links the spec/plan docs**; the design stays there — the handoff carries only current state + remaining work + reproduction. Its `related:` is subject to the reference-rewrite sweep (I2/I6) — it never dangles.
- **Retention: keep only the latest per work-stream.** When superseded or the work completes, `git rm` the stale one.
- Index: list a live handoff like any active doc; remove its row when superseded.
- **Generation: use the `handoff` skill** — it writes into `_docs/handoff/` with this convention.

## Index

`_docs/index.md` has **three sections**: ① a status doc list (active + complete, one line each, sorted `(topic,date,kind)`), ② a handoffs list (flat, keep-latest-per-stream), and ③ the **topic vocabulary** (SSOT). Update all three in the same change as any create / move / merge / topic-rename — a stale index is as misleading as a stale status, and the vocabulary list is what prevents topic fragmentation.

## Team Workflow Integration

- **Phase 1 complete**: plan written → `active/planning/<created>/`, `status: planning`, topic assigned, indexed.
- **Phase 3 start**: `planning → processing` (reference-safe move).
- **Phase 5 complete (merged)**: apply the merge rule → `complete/<topic>/`. If several PRs follow one plan, merge once at series completion (or per-PR if the user prefers).
- All `_docs/` moves are orchestrator-serialized (above). The plan doc path is `_docs/active/<status>/<created>/…` / `_docs/complete/<topic>/…` — the old flat `_docs/{category}/plan-{feature}.md` layout is retired.
