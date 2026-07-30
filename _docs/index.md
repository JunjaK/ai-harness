# AI Harness — `_docs` Index

> Layout: `docs-lifecycle` v2 — status buckets (`active/{planning,processing}`, `complete`, `reference`, `deprecated`) × date/topic foldering. `status`↔folder lockstep. Every `topic` below is drawn from the **Topic vocabulary (SSOT)** at the bottom — new topics reuse an existing entry or are added there in the same commit. Rows sorted `(topic, date, kind)`.

## Active & Complete

| Topic | Kind | Status | Date | Path |
|-------|------|--------|------|------|
| agentic-testing | impl | complete | 2026-06-23 | [complete/agentic-testing/2026-06-23-agentic-testing-impl.md](complete/agentic-testing/2026-06-23-agentic-testing-impl.md) |
| agentic-testing | plan | complete | 2026-06-23 | [complete/agentic-testing/2026-06-23-agentic-testing-plan.md](complete/agentic-testing/2026-06-23-agentic-testing-plan.md) |
| debug-command | findings | complete | 2026-07-10 | [complete/debug-command/2026-07-10-debug-command.md](complete/debug-command/2026-07-10-debug-command.md) |
| doc-storage | plan | complete | 2026-06-23 | [complete/doc-storage/2026-06-23-doc-storage.md](complete/doc-storage/2026-06-23-doc-storage.md) |
| docs-lifecycle | plan | complete | 2026-06-25 | [complete/docs-lifecycle/2026-06-25-docs-lifecycle.md](complete/docs-lifecycle/2026-06-25-docs-lifecycle.md) |
| docs-sweep | plan | complete | 2026-06-25 | [complete/docs-sweep/2026-06-25-docs-sweep.md](complete/docs-sweep/2026-06-25-docs-sweep.md) |
| graph-orchestration | plan | processing | 2026-07-30 | [active/processing/2026-07-30/2026-07-30-graph-orchestration-plan.md](active/processing/2026-07-30/2026-07-30-graph-orchestration-plan.md) |
| harness-v2 | plan | complete | 2026-04-16 | [complete/harness-v2/2026-04-16-harness-v2.md](complete/harness-v2/2026-04-16-harness-v2.md) |
| ponytail-yagni | plan | complete | 2026-06-23 | [complete/ponytail-yagni/2026-06-23-ponytail-yagni.md](complete/ponytail-yagni/2026-06-23-ponytail-yagni.md) |
| scenario-to-e2e | impl | complete | 2026-07-06 | [complete/scenario-to-e2e/2026-07-06-scenario-to-e2e.md](complete/scenario-to-e2e/2026-07-06-scenario-to-e2e.md) |
| team-new | plan | complete | 2026-06-25 | [complete/team-new/2026-06-25-team-new.md](complete/team-new/2026-06-25-team-new.md) |
| test-scenario-doc | plan | complete | 2026-06-24 | [complete/test-scenario-doc/2026-06-24-test-scenario-doc.md](complete/test-scenario-doc/2026-06-24-test-scenario-doc.md) |

## Handoffs (flat, keep-latest-per-stream)

| Topic | Date | Path |
|-------|------|------|
| brain-memory | 2026-06-26 | [handoff/2026-06-26-brain-memory-trigger-handoff.md](handoff/2026-06-26-brain-memory-trigger-handoff.md) |

## Topic vocabulary (SSOT)

The authoritative topic list. A doc's `topic` MUST be one of these; add a new entry here (kebab-case, subject-based) only when none fits.

| Topic | Meaning |
|-------|---------|
| `agentic-testing` | Adapter × mode-aware agentic E2E testing layer |
| `brain-memory` | brain memory(facts) 기록 — harness 미통합 결정(약한 연결 유지); 작성=native, 운반=claude-brain |
| `debug-command` | `/debug` 커맨드 (solo systematic-debug 진입점, `/team` 에스컬레이션) + 관련 세션 findings |
| `doc-storage` | 3-bucket document storage × LLM wiki |
| `docs-lifecycle` | `_docs` lifecycle v2 (buckets + date/topic foldering + orphan defenses) |
| `docs-sweep` | `/docs-sweep` periodic active-doc reaping + orphan lint + SessionStart nudge |
| `graph-orchestration` | Team-workflow run-state persistence (F1/F2) + escalation transition-table SSOT (F3/F4) — graph-format engineering, Option B |
| `harness-v2` | Harness v2 evolution |
| `ponytail-yagni` | ponytail YAGNI decision-ladder integration |
| `scenario-to-e2e` | test-scenario-doc(SCENARIOS SSOT) → Playwright e2e 생성 스킬 (grounded 실측+green-gate, scaffold 폴백) |
| `team-new` | `/team-new` greenfield project bootstrap (research → scaffold → profile) |
| `test-scenario-doc` | Human QA checklist skill + `/test-scenario-doc` command |
| `project-bootstrap` | **RESERVED** for `/team-new` greenfield bootstrap — feature work MUST NOT reuse |
