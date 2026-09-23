---
name: docs-lifecycle
description: "Manage the lifecycle of project documents (intent, plans, specs, findings) in `_docs/` — the lifecycle-vs-collection bucket split, status↔folder lockstep, date/topic foldering, reference-safe moves, and merging a task's scattered sidecar docs into ONE archive on completion. Use whenever an intent/plan/spec is created, moves between stages, a topic is renamed, a project declares a collection bucket, or a task finishes; and whenever `_docs/` is accumulating multiple files for the same task. Trigger at every team-workflow phase transition and before marking any work complete — scattered, status-stale, or orphaned docs, and reorganized append-only records, are the failures this prevents."
---

# Docs Lifecycle

Keep `_docs/` honest and useful as it grows under heavy plan-writing volume. The failure this prevents is **orphan documents** — docs that drift out of `status`, get stranded by a folder move, fragment across near-duplicate topic folders, pile up in `active/` forever, or lose inbound links when a file moves. The fix is a fixed two-axis layout (status × date/topic), a **reference-safe move transaction**, a **merge-on-completion** rule, and six invariants an automated lint enforces.

## Three-bucket document storage

`_docs/` is one of **three document buckets**. Each has a different OWNER, who decides who may write it and what automation applies. Classify by ownership, not by name.

| Bucket | Owner | Location | Automation | What lives here |
|--------|-------|----------|------------|-----------------|
| `_docs/` | the project | repo root | this skill (move/merge/`git rm`) + `/docs-sweep` lint | intent, plans, specs, ADRs, findings — project knowledge |
| `.claude/wiki/` | the agent | `.claude/` (tool-coupled) | the `wiki` skill (ingest/query/lint) | the agent's compounding knowledge synthesis |
| `_workspace/` | nobody (throwaway) | repo root, gitignored but for `README.md` | none — delete freely | run byproducts; layout declared in its `README.md` |

### The discriminator (classify ANY new document with this)

> **"If you swapped this agent CLI for a different one, would this document still be meaningful?"**
> - **Yes** → the project → repo root with a `_` prefix (`_docs/`).
> - **No — agent-only knowledge** → under `.claude/`.
> - **Keeps nothing once the task ends** → `_workspace/<context>/`.
>
> The axis is **ownership and tool-coupling, NOT the name.**

The rest of this skill governs the **`_docs/` bucket**.

## Two kinds of top-level bucket

`_docs/` top level mixes two axes. Which one a folder is on decides whether the lifecycle machinery touches it.

| | Lifecycle buckets | Collection buckets |
|---|---|---|
| Base set | `active/{planning,processing}/`, `complete/`, `reference/`, `deprecated/` | `intent/`, `handoff/` |
| Second axis | date (`active`) → topic (`complete`/`reference`) | flat |
| status↔folder lockstep | **enforced** | **exempt** (frontmatter `status` still kept honest) |
| merge-on-complete | **applies** | **never** |
| Agent may reorganize | yes, via the transactions below | **no** |

**Collection buckets are agent-read, agent-append, never agent-reorganized.** Write new files freely; MUST NOT merge, restructure, rename, or `git rm` an existing one on your own initiative. They exist to hold durable records — what was asked, a raw transcript, source material — whose value is being *unaltered*. Deprecate in place under `<collection>/deprecated/`; never move a collection doc into the global `deprecated/`.

> **Curation is opt-in, per project.** A project that wants a collection actively reshaped (e.g. AI-reconstructed meeting notes from a transcript + a human summary) MUST declare it in its project-profile. Absent that line, leave the bucket raw — the default is *keep, don't tidy*.

### Collection bucket contract

Everything a collection bucket must satisfy, so `/docs-sweep` can lint one it has never seen:

| Rule | |
|---|---|
| Filename | `YYYY-MM-DD-<topic>-<kind>.md` — the standard grammar, no exception |
| `kind` | **equals the folder name** (`intent/` → `kind: intent`) |
| `index.md` | registration REQUIRED — I1 applies verbatim |
| Frontmatter | same block as any `_docs/` doc; `status` is honest but does NOT drive the folder |
| Deprecation | `<collection>/deprecated/`, in place |
| Links | fully in scope for the reference-rewrite sweep and the dangling-link lint |

**Declaring a new collection** is data, not a rule change: create the folder, add a row to `index.md` §④, and record it in the project-profile (`project-analyzer` §10 → "Document buckets"). A collection folder present on disk but absent from §④ is an orphan-fragmentation defect (I3).

The base set ships two. Projects commonly add `meetings/`, `inquiry/` (questions put to teammates or third parties), `proposal/`. MUST NOT invent one ad hoc mid-task.

### `intent/` — the request record

`_docs/intent/YYYY-MM-DD-<topic>-intent.md` holds what was asked and why, before any spec exists. It is the head of the artifact chain (`intent → spec → plan → impl`) and the one document that survives rejection: most intents never become specs, and a rejected one still records the decision. Written from a `brainstorm` / `/team-brainstorm` result; the paired `spec` and `plan` then live in `active/planning/<date>/` and ride the normal lifecycle, linking back via `related:`.

## Folder lifecycle — two axes

Top axis = **status** (status↔folder lockstep). Second axis inside each bucket = **date for active, topic for done**.

```
_docs/
├── active/                     # ── lifecycle ──
│   ├── planning/<created>/     YYYY-MM-DD-<topic>[-<kind>].md   # date subfolder
│   └── processing/<created>/   YYYY-MM-DD-<topic>[-<kind>].md   # date subfolder
├── complete/<topic>/           YYYY-MM-DD-<topic>[-<kind>].md   # topic subfolder
├── reference/<topic>/          # durable consolidated synthesis, topic subfolder
├── deprecated/                 # flat — abandoned specs/plans only
├── intent/                     # ── collection ── flat, durable request record
│   └── deprecated/             #    rejected / superseded intents, in place
├── handoff/                    # ── collection ── flat, ephemeral, keep-latest-per-stream
└── index.md                    # ① status list ② handoffs ③ TOPIC VOCABULARY ④ COLLECTIONS (SSOT)
```

Lifecycle: `planning → processing → complete → (consolidate) → reference`, or from anywhere `→ deprecated`; and `deprecated → active/planning` (revive). `reference/` and `complete/` are **never flat dumps** — always grouped by topic subfolder. Collection buckets never enter this cycle.

**`exempt` means exempt from date/topic SUBFOLDERING and status-lockstep ONLY.** `deprecated/`, every collection bucket, and links *pointing into* `reference/` are still fully **in-scope for the reference-rewrite sweep and the dangling-link lint**. Nothing is exempt from "links must resolve."

## Filename grammar

**`YYYY-MM-DD-<topic>[-<kind>].md`** — all hyphens, no underscores. `<topic>` is the kebab-case controlled-vocabulary topic. `<kind>` ∈ `intent | research | stack-decision | spec | plan | impl | findings | handoff` (plus any declared collection's name) and is **REQUIRED whenever ≥2 docs share the same (topic, date)** (e.g. the greenfield bootstrap's `research` + `stack-decision` pair). The index key is `(topic, date, kind)` — this is what keeps the 1:1 index invariant under collisions.

## Frontmatter (every `_docs/**/*.md`)

```yaml
---
title: <document title>
status: planning | processing | complete | deprecated | reference
topic: <kebab-case — MUST be in index.md vocabulary>
kind: intent | research | stack-decision | spec | plan | impl | findings | handoff
scope: <fullstack | backend | frontend | …, if the project has boundaries>
created: YYYY-MM-DD
updated: YYYY-MM-DD
related: [<repo-relative paths to paired docs>]
revived: YYYY-MM-DD   # only present after a deprecated→active revive
---
```

**Three facts stored twice, kept in lockstep:** `status`==bucket; `topic`==topic folder (for `complete`/`reference`); `created`==date folder (for `active`). When they disagree a reader can't trust any of them — so a transition always moves the file **and** fixes frontmatter **and** updates the index, in one commit.

`updated` records the last substantive review or change, not a claim that implementation or QA passed. A failed required implementation check leaves a lifecycle doc in `active/processing/`; record the evidence and next action there. Deferred QA is independent: a completed implementation stays in `complete/` while its QA scenarios are `pending`, `failed`, or `blocked`. A date alone never proves that a doc's claims are current.

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
| Brainstorm settled on what to build | write `_docs/intent/<today>-<topic>-intent.md` (`kind: intent`), register its row in `index.md` §① (`intent/` itself is already declared in §④). No folder movement afterwards — it stays put for good |
| Intent rejected or superseded | move to `_docs/intent/deprecated/` (in place; NOT the global `deprecated/`), set `status: deprecated` |
| New spec/plan written | `status: planning`, place in `active/planning/<created>/`, assign topic from vocabulary |
| First implementation commit (or first task → in-progress) | `planning → processing`: reference-safe move to `active/processing/<created>/` (date leaf unchanged), bump `updated` |
| Implementation integrated, applicable required lightweight checks and final security review passed | `processing → complete`: apply the **merge rule** → `complete/<topic>/`; deferred QA may still be pending |
| Abandoned / superseded | decision rationale useful later → `deprecated/`; pure noise → `git rm` |
| Revived | `deprecated → active/planning/<today>/`: keep original `created`, add `revived:` |
| Consolidating completed work | write a new consolidated doc into `reference/<topic>/` |

## Reference-safe move transaction (REQUIRED for every move)

Any move of doc `X` from `P_old` to `P_new` is **one atomic commit**:

1. `git mv P_old P_new`.
2. **Cross-bucket reference rewrite**: `grep -rl 'P_old' _docs/ .claude/wiki/` → rewrite `P_old`→`P_new` in every hit. Covers ALL `_docs/` buckets — lifecycle AND every collection (`intent/`, `handoff/`, project-declared ones) — plus agent-owned `.claude/wiki/`. Rewriting a link inside a collection doc is the one edit allowed there without asking.
3. Update `X`'s frontmatter (`status`/`topic`/`created` as applicable; bump `updated`).
4. Update `index.md` (the row + topic vocabulary if a topic was added).
5. If the move empties a date folder, `rmdir` it (only when empty; never recursive).
6. One commit.

### Transaction types

- **status-move** — the table above. `processing→complete` also flips date-axis → topic-axis.
- **merge-on-complete** — see Merge rule.
- **topic-rename / merge** — renaming or merging a vocabulary topic: re-home `complete/<old>/` AND `reference/<old>/` subtrees, rewrite filenames, cross-bucket link rewrite, update the SSOT. If the target topic already exists this becomes a MERGE that honors "loses nothing" (I5). Free-form topic-folder renames outside this transaction are forbidden.
- **deprecated-revive** — `deprecated/→active/planning/<today>/`: KEEP original `created` (so it does not depend on a possibly-rmdir'd old date folder), add `revived: <today>`, cross-bucket link rewrite.

### Concurrency — `_docs/` lives in the primary tree

`_docs/` is a **primary-worktree-only** bucket: every doc file physically lives in the repo's primary working tree, never in a linked worktree's checkout (a doc inside `../proj-feature-a/_docs/…` is unreadable from main until merged — the pain this rule removes). Any worktree agent resolves it by absolute path, cwd-independent:

```bash
DOCS="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/_docs"
```

- Worktree agents **read** plans/specs from `"$DOCS/…"`, and **write** their own doc **content** files there directly by absolute path — each owning **distinct** files (no-overlap, same rule as code). Such writes land in the main tree instantly, so a plan is readable from main with no cd and no merge round-trip.
- **`index.md` edits and status-moves (`git mv`) are serialized through the team-leader/orchestrator** — `index.md` is the one shared mutable doc. The orchestrator performs every `git mv` + `index.md` edit + commit after worktrees finish; rows sort by `(topic, date, kind)` to shrink merge-conflict surface; `_docs/index.md` is part of the parallelization **merge-order** as a shared mutable file. Auto-`rmdir` only when the folder is empty and unlocked.

## Evidence-driven updates during a team run

The active plan is the compact record of what was attempted and what remains. At each phase boundary, the orchestrator checks the affected plan/spec against the **current** diff, test report, security report, and project-profile. Correct a contradicted claim in the same change that reveals it; do not defer it to `/docs-sweep`. Record evidence links or command + scope + outcome, not copied terminal logs or a new document per retry. If a claim cannot be checked, mark it **unverified** with the missing evidence and owner/next action; never infer PASS from implementation, a stale plan, or another platform's result.

| Event | Required document action |
|-------|--------------------------|
| Phase 1 plan accepted | Create or update the intent and planning plan, their `related:` links, and `index.md` rows. Check existing claims against current code/profile before reusing them. |
| Phase 3 implementation begins or the merged code changes the plan | Move `planning → processing` by the reference-safe transaction; update decisions, actual implementation scope, and any invalidated spec/plan claims. |
| Required lightweight verification finishes | Add a short dated result to the **existing processing plan**: base ref and merged HEAD or changed scope, unit tests and focused lightweight E2E/smoke checks, environment, relevant event code(s) from `team-workflow/resources/escalation.md`, evidence location, affected acceptance criteria, and next action. Record each distinct issue and its route. A failed check identifies fix/retest work; an unavailable check identifies the missing dependency and the check still unrun. Keep `status: processing` and its index row until required checks pass. Later attempts do not erase earlier findings. |
| Final security review finds an implementation or required-check issue | Record the issue, affected claim, decision/owner and required recheck in the processing plan; keep it active until required checks and review pass. |
| Implementation completion is ready | Reconcile the active plan with final integrated code, required lightweight verification and security evidence. A required check that could not run remains labeled unverified and ends the run without a completion claim. Draft up to five task-specific deferred QA scenarios in the plan, then carry them into the completion archive; for a non-behavioral task with none, record why. Update affected project-profile/ADR/wiki pointers and perform the completion merge and index/link transaction. Report implementation complete with the number and path of pending QA scenarios; do not report them as QA PASS. |
| Standalone `/team-qa` run finishes later | Update each selected scenario's `Status` and `Evidence` in the **same** `complete/<topic>/` archive. Bump its `updated` frontmatter, check affected code/docs/wiki claims against observed results, and repair index/link targets only if their path, status, or summary changed. Record a failed/blocked scenario and its follow-up there; a defect needing code work opens a linked fix task rather than silently relabeling implementation completion or recreating an active plan. |

Only create a separate findings or reference doc when its information remains useful beyond this task. A retry, routine PASS, or transient infrastructure block belongs in the current plan or completed archive, according to the phase. `index.md` changes when a file/row/topic/status or indexed summary changes, not for each content-only QA result; verify its path and status still match the document after every phase. If a code or contract change invalidates an existing `.claude/wiki/` page, use the `wiki` skill to repair that page and its catalog in the same change. Do not generate a new wiki page for every run.

## Merge rule (REQUIRED on completion)

When a task produced **multiple sidecar docs** (spec, plan, metrics, findings, sub-reports), merge them into **one** on the move to `complete/` — do not archive a scatter.

1. Create one file `_docs/complete/<topic>/YYYY-MM-DD-<topic>.md` (start date as prefix; topic from vocabulary).
2. Body sections, in order (omit empty ones — do NOT copy every step verbatim):
   - `## Spec` — intent / goal / non-goal / architecture decisions
   - `## Plan` — meaningful decisions and phase outcomes (not the full step list)
   - `## Findings & Metrics` — what was discovered, measured, design lessons
   - `## Final Summary` — PR link, commit range, one-line impact
   - `## Deferred QA` — up to five task-specific unrun scenarios; for a non-behavioral task with none, state the reason under this heading
3. **Before any `git rm`**, enumerate sidecars via `related:` + a same-`(topic,date)` grep, and run the cross-bucket reference-rewrite so every inbound link (intent/handoff/wiki `related:`) repoints to the consolidated doc — never delete-then-leave-dangling (I5/I6). **Sidecars means lifecycle docs only** — a collection doc sharing the `(topic, date)` is never merged or removed.
4. Remove `related:` entries for merged sidecars; retain a valid link to the durable intent and any independent source record. The archive body remains self-contained without copying collection content.
5. `git rm` the original sidecars (history preserves them).
6. Update `index.md`: remove originals from the active list, add the consolidated file under Complete.
7. One commit: `docs: archive <topic> to complete (merged spec + plan + metrics)`.

**Exception**: a task with a single active doc and no sidecars → add its `## Deferred QA` section, then reference-safe move to `complete/<topic>/` without merging sidecars.

### Deferred QA entry contract

Before moving to `complete/`, add `## Deferred QA` to the plan. Carry the same section into the merged archive; for a single-doc move, add it before moving. Each scenario has a stable ID based on the final archive filename stem (`<plan-id>`), so later `/team-qa` runs update the same entry rather than creating another document:

```markdown
## Deferred QA

### QA-<plan-id>-01 — <scenario title>
- Priority: P0 | P1 | P2
- Preconditions: <environment, account/data and setup needed>
- Actions: <reproducible user or API steps>
- Expected: <observable outcome, including failure behavior where relevant>
- Source: <acceptance criterion or code/issue link>
- Status: pending
- Evidence: —
```

Use one scenario per heading and increment `01`–`05`; use at most five per task, with no filler cases. For a non-behavioral task with no manual QA worth deferring, keep the heading and write `- No scenarios: <specific reason>`. `Source` must identify the claim being checked; `Expected` must be observable, not "works correctly." Valid `Status` values are exactly `pending`, `passed`, `failed`, and `blocked`. A standalone `/team-qa` run selects pending entries by default, records the run date, method/environment, observed outcome and artifact path (or explicit reason no artifact exists) in `Evidence`, and changes `Status` to the observed verdict. Re-run a failed/blocked entry only when requested or after its dependency/fix changes, preserving prior evidence in that entry. Deferred QA results update the completed archive's `updated` date; they do not create a new lifecycle bucket or imply that `status: complete` means QA passed.

## Orphan-mode invariants (lint enforces — see `/docs-sweep`)

| I# | Invariant |
|----|-----------|
| I1 | `index.md` ↔ disk is bidirectional 1:1 (key `(topic,date,kind)`). |
| I2 | No dangling link in any `_docs/**` doc (`related:` + inline `_docs/` links resolve). |
| I3 | No off-vocabulary topic folder under `complete/` or `reference/`, and no collection bucket missing from `index.md` §④. |
| I4 | No empty date folder under `active/**`. |
| I5 | Merge-on-complete loses nothing (sidecars enumerated + inbound links repointed before `git rm`). |
| I6 | No dangling `_docs/` link from `.claude/wiki/**`; no collection doc reorganized or removed outside its own bucket. |

## Sweep & Lint (`/docs-sweep`)

`active/` accumulates and orphans creep in over time. `/docs-sweep` drains and re-verifies; a `SessionStart` hook nudges when it's overdue. Two halves:

### REAP — drain `active/` (signal-gated, NEVER age-gated)

For each `_docs/active/**/*.md` (**lifecycle only — collection buckets are never reaped**): `staleness = today − frontmatter.updated` (default threshold **14 days**). Then gather **signals** — linked PR merged? branch gone? recent commits touching its `related:`/own path? — and **let signals decide; age only flags**:

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
| I3 | no off-vocabulary `complete/`/`reference/` topic folder; no undeclared collection bucket (absent from `index.md` §④) | propose vocab-add / topic-rename / collection declaration |
| I4 | no empty `active/**` date folder | `rmdir` |
| I5 | no `active/` sidecar sharing `(topic,date)` with a `complete/<topic>` doc | propose merge |
| I6 | no dangling `_docs/` link from `.claude/wiki/`; no collection doc outside its bucket | wiki: yes; collection: report-only |

### Detection — `SessionStart` hook

`hooks/session-start.sh` does a cheap mtime scan of `_docs/active/`; if any doc is older than the threshold it emits **one** non-blocking nudge line (`exit 0`, stdout) — `⚠ N stale active docs (untouched >14d) — run /docs-sweep`. Silent when clean; exits 0 silently when `_docs/active` is absent (so it never false-alarms in repos that haven't adopted the layout).

## Handoff documents

The handoff contract (location, naming, `related:` link-don't-duplicate, keep-latest-per-stream) is owned by the **`handoff`** skill — use it to write one. Only two docs-lifecycle facts apply here: `_docs/handoff/` is exempt from date/topic subfoldering, and a live handoff is listed in `index.md` §② like any active doc (row removed when superseded).

`handoff/` is the **one collection the agent may prune** — keep-latest-per-stream is its defining contract and a superseded handoff is noise, not a record. That exception is specific to this bucket; it does NOT generalize to `intent/` or any project-declared collection.

## Index

`_docs/index.md` has **four sections**: ① a status doc list (active + complete + every collection doc, one line each, sorted `(topic,date,kind)`), ② a handoffs list (flat, keep-latest-per-stream), ③ the **topic vocabulary** (SSOT), and ④ the **declared collection buckets** (SSOT — base `intent/`, `handoff/` plus whatever this project added). Update all four in the same change as any create / move / merge / topic-rename — a stale index is as misleading as a stale status, the vocabulary prevents topic fragmentation, and §④ is what lets the lint tell a legitimate collection from a stray folder.

## Team Workflow Integration

- **Phase 1 complete**: plan written → `active/planning/<created>/`, `status: planning`, topic assigned, indexed.
- **Phase 3 start**: `planning → processing` (reference-safe move).
- **Required lightweight verification result**: apply the evidence-driven update above before routing the next phase; a failed or blocked required check remains `processing` with a fix/retest or unblock action.
- **Implementation complete (integrated)**: add the deferred QA entries, then apply the merge rule → `complete/<topic>/`. If several PRs follow one plan, merge once at series completion (or per-PR if the user prefers).
- **Before reporting implementation completion**: compare the archive and linked knowledge pages with final code, required lightweight verification and security evidence; run `/docs-sweep --lint-only` (all six invariants) and fix broken paths/index rows. State the pending QA count and completed archive path in the report.
- **Later `/team-qa`**: update selected scenario verdicts and evidence in the same archive, refresh `updated`, and check documentation freshness at this boundary; preserve `status: complete` while tracking a new fix task for any implementation defect.
- All `_docs/` moves are orchestrator-serialized (above). The plan doc path is `_docs/active/<status>/<created>/…` / `_docs/complete/<topic>/…` — the old flat `_docs/{category}/plan-{feature}.md` layout is retired.
