---
title: "Claude team lightweight verification and deferred QA"
status: complete
topic: team-quality
kind: plan
scope: harness
created: 2026-09-23
updated: 2026-09-23
related: [skills/team-workflow/SKILL.md, skills/team-workflow/resources/escalation.md]
---

# Team verification and deferred QA

## Intent

Strengthen the Claude team harness's verification and document updates using the supplied event-driven workflow example. The user clarified that deep QA must run only through a separate command to control token use. Preserve parallel implementation and the five-phase team graph while removing automatic QA feedback loops.

## Current gaps

- A heavy agentic QA pass inside every team run spends tokens before the user is ready to verify several tasks together.
- The implementation report has no durable queue of later QA scenarios, and the completed document does not distinguish implementation status from QA verdicts.
- Parallel implementation needs one trustworthy, small merged-tree check before completion.

## Changes

1. Phase 4 runs one Tester on the merged result: affected unit/integration tests, authoritative type/lint/build checks, and at most one ready, existing smoke E2E per changed user-facing flow. `VERIFY_PASS` proceeds; `VERIFY_FAIL` or `VERIFY_BLOCKED` records evidence and stops without an automatic correction loop.
2. Phase 5 writes up to five unrun, risk-ordered QA scenarios into the implementation archive. `status: complete` means implementation complete; each scenario has its own pending/passed/failed/blocked status.
3. `/team-qa` later selects a risk-ordered batch of at most five pending scenarios across archives, verifies them, and updates the same documents. Test generation requires explicit `--crystallize`; failures do not automatically start implementation work.
4. At completion and later QA updates, reconcile documents, index, and wiki with current code and evidence. Add no dependency or new workflow engine.

## Verification

- Check graph/table state consistency, scenario schema and archive links, and no claims of completed QA for pending/blocked cases.
- Run repository validators or focused checks available for Markdown/JSON/shell; inspect the final diff and worktree status.

## Result

- Phase 4 now has one lightweight merged-tree Tester pass and no agentic Phase 4.5 or QA→implementation loop. It reports `VERIFY_PASS`, `VERIFY_FAIL`, or `VERIFY_BLOCKED` with per-check evidence and baseline comparison.
- Phase 5 writes deferred QA entries into the implementation archive and reports their count/path. The standalone `/team-qa` command performs later batches; default verification does not generate tests or fix code.
- Failed/blocked implementation verification remains in the active plan. Deferred QA verdicts update the completed archive separately. Document and wiki freshness checks apply at both boundaries.
- Claude plugin/marketplace manifests are prepared at `1.29.0`; the Codex adapter remains `1.28.0`. No release or remote update was performed as part of this change.

## Verification evidence

- `claude plugin validate . --strict`, `claude plugin validate skills --strict`, `claude plugin validate agents --strict`, and `claude plugin validate commands --strict`: passed.
- `git diff --check`: passed.
- Read-only invariant check: `_docs/index.md` links resolve, the transition table and Mermaid graph have the same states, and all three lightweight verification outcomes appear in the escalation rules, workflow, and README.
- The root plugin manifest also validates without `--strict`. Its existing strict warning says the root `CLAUDE.md` is not injected into a consumer project; README already documents that boundary.

## Deferred QA

### QA-2026-09-23-team-quality-plan-01 — Lightweight team completion
- Priority: P1
- Preconditions: Claude plugin version 1.29.0 installed in a disposable project with a working unit test and one existing smoke E2E; no live production target.
- Actions: Run `/team-run` on a small user-facing change, then inspect its agent dispatch, test report, and completed `_docs` archive.
- Expected: One Phase 4 Tester checks changed unit/integration tests and no more than one existing smoke E2E for the changed flow; no Phase 4.5 agent is dispatched. The completion report links an archive containing pending `## Deferred QA` entries.
- Source: `skills/team-workflow/SKILL.md` Phase 4 and Phase 5; `commands/team-run.md`.
- Status: passed
- Evidence: 2026-09-23 · target: disposable Bun + TS fixture (1 `bun:test` unit, 1 Playwright smoke E2E, profile from `/team-init`) with the plugin loaded via `claude -p --plugin-dir <this repo>` at `0383cc4` (installed 1.28.0 disabled in the fixture's local settings), `--permission-mode auto`, `disableAllHooks: true` · method: `/junjak-ai-harness:team-run` on "show today's date under the greeting", stream-json log inspected for `Agent` dispatches · observed: success in 42 turns / 12m38s; dispatches = team-leader, architect-fe, architect-infra (P1), uiux-master, 1 designer, **1 team-tester**, architect-infra (P5); **0 team-agentic-tester**; Tester ran `bun test test/` 5/0, `tsc` exit 0, `playwright home.spec.ts` 2 passed (the existing smoke + the E2E the Designer added for the new flow); report emitted `Verification: VERIFY_PASS — …` and linked `_docs/complete/home/2026-09-23-home-plan.md` with 4 pending Deferred QA entries · follow-ups found: the Leader proposed 2 Testers from a stale sizing formula (fixed in `8ea27d9`); consumer projects are not told to gitignore `.claude/session-state/` (pre-existing, not fixed) · artifact: session scratch logs only, not retained

### QA-2026-09-23-team-quality-plan-02 — Deferred batch verdicts
- Priority: P1
- Preconditions: A disposable project with at least six pending `## Deferred QA` entries across completed plan archives and a verified local QA target.
- Actions: Invoke `/team-qa` without arguments, inspect selected IDs and updated archives, then invoke an exact QA ID for a recheck.
- Expected: The default run selects at most five pending entries in P0→P2 order and records each verdict/evidence in its original archive; unselected entries stay pending. A named recheck appends dated evidence without changing the archive's lifecycle status from `complete`.
- Source: `commands/team-qa.md`; `skills/docs-lifecycle/SKILL.md` Deferred QA entry contract.
- Status: passed
- Evidence: 2026-09-23 · target: copy of the same fixture with 6 seeded pending entries across two archives (P0×1, P1×2, P2×3; one expected pass set, one deliberate expectation mismatch, one missing-credential case), plugin via `--plugin-dir` at `8ea27d9`, same flags as QA-…-01 · method: `/junjak-ai-harness:team-qa` without arguments, then `/junjak-ai-harness:team-qa QA-2026-09-10-serve-plan-01`; archive diffs checked with git · observed: one `team-agentic-tester` dispatch; selected exactly 5 in P0→P1→P2 order with oldest archive first; verdicts 3 passed / 1 failed (reproducible mismatch with expected-vs-observed and repro steps) / 1 blocked (missing `STAGING_URL` and vault account, owner named); the sixth entry stayed `pending`; `updated` bumped, `status: complete` and `index.md` unchanged; `TEAM QA COMPLETE` report block emitted · recheck: only the named entry changed, `Status: failed` kept, new dated result appended after the original Evidence (`‖ recheck 2026-09-23 …`), lifecycle status unchanged · artifact: session scratch logs only, not retained
