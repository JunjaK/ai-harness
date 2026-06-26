# AI Harness — `_docs` Index

> Layout: `docs-lifecycle` v2 — status buckets (`active/{planning,processing}`, `complete`, `reference`, `deprecated`) × date/topic foldering. `status`↔folder lockstep. Every `topic` below is drawn from the **Topic vocabulary (SSOT)** at the bottom — new topics reuse an existing entry or are added there in the same commit. Rows sorted `(topic, date, kind)`.

## Active & Complete

| Topic | Kind | Status | Date | Path |
|-------|------|--------|------|------|
| agentic-testing | impl | processing | 2026-06-23 | [active/processing/2026-06-23/2026-06-23-agentic-testing-impl.md](active/processing/2026-06-23/2026-06-23-agentic-testing-impl.md) |
| agentic-testing | plan | processing | 2026-06-23 | [active/processing/2026-06-23/2026-06-23-agentic-testing-plan.md](active/processing/2026-06-23/2026-06-23-agentic-testing-plan.md) |
| doc-storage | plan | processing | 2026-06-23 | [active/processing/2026-06-23/2026-06-23-doc-storage-plan.md](active/processing/2026-06-23/2026-06-23-doc-storage-plan.md) |
| docs-lifecycle | plan | planning | 2026-06-25 | [active/planning/2026-06-25/2026-06-25-docs-lifecycle-plan.md](active/planning/2026-06-25/2026-06-25-docs-lifecycle-plan.md) |
| docs-sweep | plan | planning | 2026-06-25 | [active/planning/2026-06-25/2026-06-25-docs-sweep-plan.md](active/planning/2026-06-25/2026-06-25-docs-sweep-plan.md) |
| harness-v2 | plan | planning | 2026-04-16 | [active/planning/2026-04-16/2026-04-16-harness-v2-plan.md](active/planning/2026-04-16/2026-04-16-harness-v2-plan.md) |
| ponytail-yagni | plan | processing | 2026-06-23 | [active/processing/2026-06-23/2026-06-23-ponytail-yagni-plan.md](active/processing/2026-06-23/2026-06-23-ponytail-yagni-plan.md) |
| team-new | plan | planning | 2026-06-25 | [active/planning/2026-06-25/2026-06-25-team-new-plan.md](active/planning/2026-06-25/2026-06-25-team-new-plan.md) |
| test-scenario-doc | plan | processing | 2026-06-24 | [active/processing/2026-06-24/2026-06-24-test-scenario-doc-plan.md](active/processing/2026-06-24/2026-06-24-test-scenario-doc-plan.md) |

## Handoffs (flat, keep-latest-per-stream)

| Topic | Date | Path |
|-------|------|------|
| agentic-testing | 2026-06-23 | [handoff/2026-06-23-agentic-testing-handoff.md](handoff/2026-06-23-agentic-testing-handoff.md) |

## Topic vocabulary (SSOT)

The authoritative topic list. A doc's `topic` MUST be one of these; add a new entry here (kebab-case, subject-based) only when none fits.

| Topic | Meaning |
|-------|---------|
| `agentic-testing` | Adapter × mode-aware agentic E2E testing layer |
| `brain-memory` | brain memory(facts) 기록 — harness 미통합 결정(약한 연결 유지); 작성=native, 운반=claude-brain |
| `doc-storage` | 3-bucket document storage × LLM wiki |
| `docs-lifecycle` | `_docs` lifecycle v2 (buckets + date/topic foldering + orphan defenses) |
| `docs-sweep` | `/docs-sweep` periodic active-doc reaping + orphan lint + SessionStart nudge |
| `harness-v2` | Harness v2 evolution |
| `ponytail-yagni` | ponytail YAGNI decision-ladder integration |
| `team-new` | `/team-new` greenfield project bootstrap (research → scaffold → profile) |
| `test-scenario-doc` | Human QA checklist skill + `/test-scenario-doc` command |
| `project-bootstrap` | **RESERVED** for `/team-new` greenfield bootstrap — feature work MUST NOT reuse |
