---
description: "Run deferred team QA on demand from completed plan archives; verify a bounded batch and record evidence without restarting implementation."
---

# /team-qa — Deferred QA

Run the QA scenarios saved by `/team` or `/team-run` **after** their implementation report. This command runs only when invoked; it is not a team-workflow phase or a completion gate.

## Usage

```
/team-qa [topic | _docs/complete/<topic>/<archive>.md | QA-<plan-id>-<nn>] [--all] [--crystallize]
```

- No scope: search `_docs/complete/*/*.md` for `## Deferred QA` scenarios with `Status: pending`.
- Topic: search that topic's completed archives. Path: inspect only that completed archive. Resolve `_docs` in the primary working tree with `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/_docs`, including when invoked from a linked worktree. Reject paths outside `_docs/complete/`.
- Exact QA ID: run only that entry, including a previously `failed` or `blocked` entry requested for recheck; append the new dated evidence instead of replacing the old result. If the ID appears in more than one archive, stop and list the matches rather than choosing one.
- Default batch: at most **5 pending scenarios**, ordered by `Priority: P0`, then `P1`, then `P2`; within a priority, oldest archive date/path and scenario ID first. `--all` runs every pending scenario in the selected scope. Say how many remain queued. Do not silently expand the batch to unrelated features.

## Scenario contract

Read the archived plan's `## Deferred QA` entries, each with `### QA-<plan-id>-<nn> — <title>` and `Priority`, `Preconditions`, `Actions`, `Expected`, `Source`, `Status`, `Evidence`. `<plan-id>` is the completed archive's filename stem. `- No scenarios: <specific reason>` means the team intentionally queued zero cases; skip that archive. Use the written source and current code to resolve exact behavior; do not invent URLs, credentials, fixture data, or acceptance criteria. A scenario without executable actions or an observable expected outcome is `blocked` with the missing detail named in Evidence.

## Run

1. Show the selected IDs, source archive paths, priorities, and expected batch size. If the selection is empty, report that plainly (including a `No scenarios` reason for a specifically requested archive) and stop.
2. Dispatch `team-agentic-tester` with the selected IDs and archive paths; that agent invokes the `agentic-testing` skill. Use its **verify-only** path: inspect current profile and fixtures, use the project adapter and browser-driver gate where applicable, perform the actions, and check the observable outcome. Pass `--crystallize` only when the user explicitly supplied it. This single dispatch avoids loading the same skill twice.
3. Run each selected scenario once, with bounded exploration. Verify the real outcome; a response code or UI click alone does not prove persistence. Classify each result as `passed` (outcome observed), `failed` (reproducible mismatch), or `blocked` (environment, account, fixture, permissions, driver, or missing criterion prevented verification). A failed scenario is not retried through the team phase state machine.
4. Update **the same completed archive**: change only the selected scenario's `Status` and `Evidence` fields; Evidence includes date, target/environment, method, observed result, and artifact or command path when one exists. For failure include reproduction steps, expected versus observed, and affected source criterion. For blocked include the missing prerequisite and next action. Update frontmatter `updated` when the archive content changes; keep its lifecycle `status: complete`, path, and index row unchanged. Leave every unselected scenario's status untouched. Do not overwrite older evidence when explicitly rechecking a result; append a dated result within Evidence.
5. Report counts for passed, failed, blocked, and still pending; link the touched archive(s). Failed and blocked items are follow-up work for the user to schedule. Do not start Designer fixes, re-plan, roll back, or recursively invoke `/team` or `/team-run`. Once a fix or prerequisite is ready, the user can request a named recheck; then run only those named IDs and append new evidence.

`--crystallize` is an explicit opt-in after verification: emit a deterministic regression test only for a passed, valuable, assertable scenario, using the project's existing test conventions. Run it and keep it only if green. Its outcome never changes a `passed` QA verdict into a generated-test claim.

## Report

```
TEAM QA COMPLETE
Scope: [no scope | topic | archive path | QA ID] [--all] [--crystallize]
Selected: [IDs, P0→P2]
Result: [n] passed, [n] failed, [n] blocked
Still pending: [count in scope, or 0]
Archives updated: [paths]
Follow-up: [failed → reproduction + /debug or new /team task; blocked → missing prerequisite and owner; or none]
Crystallized tests: [paths, or none / not requested]
```

## Related

- `agentic-testing` — adapter-based goal verification; optional test generation
- `team-agentic-tester` — standalone scenario executor
- `/test-scenario-doc` — optional human-run checklist export, separate from agent QA
