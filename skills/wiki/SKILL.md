---
name: wiki
description: "Build and maintain the agent wiki (.claude/wiki/) — a persistent, compounding knowledge base. Use when ingesting a source into the wiki, querying it, or linting it for drift. The wiki links to the SSOT (code / _docs/ / _note/); it routes and synthesizes, it does NOT duplicate facts."
---

# Wiki

The agent's compounding knowledge layer. Unlike RAG (re-derive from raw docs on every query), the wiki is **built once and kept current** — an interlinked set of markdown pages under `.claude/wiki/` that the agent owns and maintains.

Three layers (Karpathy LLM Wiki): **raw sources** (`_note/` human, `_docs/` project, `learnings/`, external) → **the wiki** (`.claude/wiki/`, this skill owns) → **the schema** (`.claude/wiki/schema.md`, conventions).

## Where it lives

`.claude/wiki/` is the **agent** bucket (see `docs-lifecycle` Three-bucket section). Bootstrapped by `/team-init`:
- `index.md` — content catalog (entities / concepts / sources). Read FIRST on query.
- `log.md` — append-only chronicle, prefix `## [YYYY-MM-DD] ingest|query|lint | <title>`.
- `schema.md` — structure + conventions (read before any operation).
- `<page>.md` — entity / concept / overview / comparison pages.

**Core rule: link, don't duplicate.** A page routes to and synthesizes the SSOT (code, `_docs/`, `_note/`); it never restates a fact that lives elsewhere. A duplicated fact goes stale. (`continuous-learning` §7.)

## Operation: ingest

User-driven, **one source at a time, supervised** (the preferred flow). Trigger: the human points at a source ("ingest this").

1. Read `schema.md` for current conventions.
2. Read the source. Extract the key information (do not copy it verbatim).
3. Discuss takeaways with the human if non-trivial.
4. Write/update the summary page for the source.
5. Update entity/concept pages the source touches — a single source may touch 10–15 pages.
6. Add cross-references between affected pages; link to the SSOT (code / `_docs/` / `_note/`).
7. Update `index.md` (new/changed pages, one-line summaries).
8. Append to `log.md`: `## [<date>] ingest | <source title>`.

Sources: `_note/` (**read-only** — read for context, never modify), `_docs/` (on completion), `.claude/session-state/learnings/`, external docs the user provides.

## Operation: query

1. Read `index.md` to find relevant pages.
2. Drill into those pages; follow cross-links.
3. Answer **with citations** (the page + the SSOT it links to).
4. **File good answers back.** A useful comparison, analysis, or discovered connection is a new wiki page — do not let it vanish into chat. Update `index.md` + append `## [<date>] query | <question>` to `log.md`.

## Operation: lint

Periodic health check (when a page feels stale, at workflow completion, or on request). This IS the `continuous-learning` §7 self-audit applied to the wiki — reuse it, do not reinvent.

Check for:
- **Contradictions** between pages.
- **Stale claims** newer sources/code have superseded — follow a page's claims to the code and flag any that no longer hold (**verify it still exists**).
- **Orphans** — pages with no inbound links.
- **Missing cross-references** between related pages.
- **Concept gaps** — important concepts mentioned but lacking their own page; data gaps a search could fill.

Output: fixes applied + suggested new questions/sources to investigate. Append `## [<date>] lint | <scope>` to `log.md`.

## Relationship to continuous-learning (no overlap)

- **continuous-learning** owns the lifecycle of reusable *patterns/instincts* (HOW to work) — learnings, confidence scoring, skill evolution.
- **wiki** owns the synthesis of *knowledge/facts* (WHAT is true) about a domain/codebase.
- `learnings/` is **one ingest source** for the wiki. A high-confidence, project-stable learning MAY be promoted to a wiki page (in parallel with §6 profile promotion — routing, not duplication).
- continuous-learning **§7 governs** wiki maintenance (link-don't-duplicate, same-change-same-update, self-audit = lint).

## Scale note

At small scale the `index.md` catalog is enough to navigate — no embedding/RAG infrastructure needed. If the wiki outgrows comfortable index navigation, a local markdown search tool (e.g. qmd) is a future option, not a requirement.
