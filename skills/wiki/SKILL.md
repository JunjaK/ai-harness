---
name: wiki
description: "Build and maintain the agent wiki (.claude/wiki/) — a persistent, compounding knowledge base. Use when ingesting a source into the wiki, querying it, or linting it for drift. The wiki links to the SSOT (code / _docs/); it routes and synthesizes, it does NOT duplicate facts."
---

# Wiki

The agent's compounding knowledge layer. Unlike RAG (re-derive from raw docs on every query), the wiki is **built once and kept current** — an interlinked set of markdown pages under `.claude/wiki/` that the agent owns and maintains.

Three layers (Karpathy LLM Wiki): **raw sources** (`_docs/` project — lifecycle docs AND collections like `intent/`, `learnings/`, external) → **the wiki** (`.claude/wiki/`, this skill owns) → **the schema** (`.claude/wiki/schema.md`, conventions).

## Where it lives

`.claude/wiki/` is the **agent** bucket (see `docs-lifecycle` Three-bucket section). Bootstrapped by `/team-init`:
- `index.md` — content catalog (entities / concepts / sources). Read FIRST on query.
- `log.md` — append-only chronicle, prefix `## [YYYY-MM-DD] ingest|query|lint | <title>`.
- `schema.md` — structure + conventions (read before any operation).
- `<page>.md` — entity / concept / overview / comparison pages.

**Core rule: link, don't duplicate.** A page routes to and synthesizes the SSOT (code, `_docs/`); it never restates a fact that lives elsewhere. A duplicated fact goes stale. (`continuous-learning` §5.)

The wiki is optional until the project has bootstrapped it. A team run does not create a page for every task, deferred QA scenario, QA retry, or transient failure. Update an existing page only when its routing or stable claim changed; create a new page when a durable concept needs its own navigation entry. A completed implementation archive may contain `pending` deferred QA; neither the archive's `status: complete` nor a wiki link to it establishes QA passage.

## Operation: ingest

User-driven, **one source at a time, supervised** (the preferred flow). Trigger: the human points at a source ("ingest this").

1. Read `schema.md` for current conventions.
2. Read the source. Extract the key information (do not copy it verbatim).
3. Discuss takeaways with the human if non-trivial.
4. Write/update the summary page for the source.
5. Update entity/concept pages the source touches — a single source may touch 10–15 pages.
6. Add cross-references between affected pages; link to the SSOT (code / `_docs/`).
7. Update `index.md` (new/changed pages, one-line summaries).
8. Append to `log.md`: `## [<date>] ingest | <source title>`.

Sources: `_docs/` — lifecycle docs on completion, plus collection buckets (`intent/` and any project-declared one) which are **append-only: read for context, never reorganize** — `.claude/session-state/learnings/`, and external docs the user provides.

## Operation: maintain after a code or document change

This is the automatic **same-change** upkeep of existing knowledge, distinct from supervised source ingest. At implementation merge, required lightweight verification, the completion archive/link transaction, and a later standalone `/team-qa` result, search the wiki for touched symbols, paths, commands, APIs, and moved `_docs/` links. If no existing page makes a claim about the change, record **no wiki update needed** in that boundary's document check; do not create one just to log the run.

For each affected page:

1. Follow its source links to the current code, project-profile, or `_docs/` document. Check the specific claim and link target; an old date or a prior PASS is not evidence of current behavior.
2. Repair invalid claims and moved links in the same change. A failed or blocked required implementation check must not become a wiki claim of working behavior; keep its transient details in the active plan. Later deferred QA verdicts belong in the completed archive's `## Deferred QA` entries. A `pending`, `failed`, or `blocked` QA entry must not be restated as a verified wiki claim; link to the entry and correct any affected existing page when the observed result contradicts it.
3. Keep the page's summary and cross-links in `index.md` aligned with the page. Add/remove a catalog row only when the page set changes; revise a row when its description or target changed.
4. Append a concise `## [<date>] lint | <scope>` entry to `log.md` only when wiki content was checked or repaired. Name the source checked and pages changed; do not append an ingest entry for routine maintenance.

The orchestrator serializes edits to shared wiki pages, `index.md`, and `log.md` after parallel worktrees merge, as it does for `_docs/index.md`. A later `/team-qa` run performs the same freshness check against its archive and observed evidence, updating shared wiki files only when a stable claim or route actually changes. Collection source documents remain read-only for synthesis; only a reference rewrite required by `docs-lifecycle` may change a link inside one.

## Operation: query

1. Read `index.md` to find relevant pages.
2. Drill into those pages; follow cross-links and verify cited paths, commands, and behavioral claims against the current source before relying on them.
3. Answer **with citations** (the page + the SSOT it links to).
4. **File good answers back.** A useful comparison, analysis, or discovered connection is a new wiki page — do not let it vanish into chat. Update `index.md` + append `## [<date>] query | <question>` to `log.md`.

## Operation: lint

Periodic health check (when a page feels stale, at workflow completion, or on request). This IS the `continuous-learning` §5 self-audit applied to the wiki — reuse it, do not reinvent.

Check for:
- **Contradictions** between pages.
- **Stale claims** newer sources/code have superseded — follow a page's claims to the code and flag any that no longer hold (**verify it still exists**).
- **Catalog drift** — `index.md` entries missing, pointing to deleted pages, or summarizing a claim the page no longer makes.
- **Broken source links** after `_docs/` moves, including links into lifecycle and collection buckets.
- **Orphans** — pages with no inbound links.
- **Missing cross-references** between related pages.
- **Concept gaps** — important concepts mentioned but lacking their own page; data gaps a search could fill.

Output: fixes applied + suggested new questions/sources to investigate. Append `## [<date>] lint | <scope>` to `log.md`.

## Relationship to continuous-learning (no overlap)

- **continuous-learning** owns the lifecycle of reusable *patterns* (HOW to work) — learnings, confidence scoring, skill evolution.
- **wiki** owns the synthesis of *knowledge/facts* (WHAT is true) about a domain/codebase.
- `learnings/` is **one ingest source** for the wiki. When `continuous-learning` §4 promotes a learning to `_docs/reference/` or the project-profile, a wiki page may link to that destination — the wiki routes to the SSOT and does not keep its own copy of the fact.
- continuous-learning **§5 governs** wiki maintenance (link-don't-duplicate, same-change-same-update, self-audit = lint).

## Scale note

At small scale the `index.md` catalog is enough to navigate — no embedding/RAG infrastructure needed. If the wiki outgrows comfortable index navigation, a local markdown search tool (e.g. qmd) is a future option, not a requirement.
