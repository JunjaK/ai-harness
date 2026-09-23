---
name: agentic-testing
description: "On-demand, adapter-based agent QA. Verify archived /team-qa scenarios or a directly supplied outcome through a real UI/API driver; record passed, failed, or blocked evidence. Test generation is opt-in via --crystallize."
---

# Agentic Testing

> Tests enforce journeys. Agents verify goals. `/team-qa` invokes this skill **after** team implementation has reported completion; direct goal verification can invoke it independently.

The default is **verify-only**. The implementation run performs unit tests and focused E2E/smoke checks, then records a small deferred QA queue. This skill performs the deeper, later verification only when asked. It never starts a team phase loop or treats a QA failure as permission to edit implementation.

## Profile and adapter gate

1. Read `.claude/project-profile/{index.md, stack.md, testing.md}`. If absent, report the missing profile (`/team-init`); a scenario that needs the unknown adapter or fixture is `blocked`, not `failed`.
2. Read `testing.md` → "Agentic Testing Adapter". If absent or stale relative to the current stack, report `/team-init --update` and mark affected scenarios `blocked`.
3. Read the selected archive's `## Deferred QA` cards and `Source` criteria. For direct use without an archive, take explicit user goals and acceptance criteria. Ground actions and expectations in current code or docs; an ungrounded criterion is `blocked` with what to clarify.

## Adapter resolution

Resolve the adapter from `testing.md`; use the existing test style only for optional crystallization. A driver must exercise the real surface, not merely inspect code.

| Surface | Verification driver | Optional deterministic emitter | Concurrency |
|---|---|---|---|
| web/TS | `agent-browser` after the `agent-browser-e2e` gate; Playwright MCP if that gate fails | existing Playwright `.spec.ts` conventions in `reference/e2e-testing.md` | sequential when a browser is shared |
| Spring/Kotlin API | HTTP calls against a verified local target | project's `WebTestClient`/`@SpringBootTest` + Testcontainers style | isolate data per worker |
| Flutter/Dart UI | maestro, Patrol, or mobile MCP on a booted device | project's integration-test or maestro style | sequential per device |

Driver unavailable is `blocked` with the missing tool/device stated. For mobile, verify on a booted simulator or emulator; do not infer iOS behavior from Android. On Windows/Linux, iOS Simulator is unavailable; record iOS as blocked and leave the iOS result unverified.

## Fixtures and target before the first action

Read `testing.md` → "E2E Fixtures" and `reference/e2e-testing.md` → "Preconditions". Use the project's existing dedicated E2E account, credential source, and idempotent seed path. Never invent credentials or test data. Confirm the target is local and any shared seed/reset operation is coordinated. Missing account, seed, target, or access is `blocked` with the prerequisite and next action; it is not evidence that the feature failed. Do not run automated writes against production or staging.

## Verify-only pipeline

1. Select the requested goals; `/team-qa` defaults to at most five pending archived scenarios, risk ordered. This skill never autonomously expands that batch.
2. Apply a per-goal run gate: the outcome is observable, the target is reachable, and the actions are bounded (roughly 25 steps). If a gate fails, record `blocked` and the reason. Existing passing tests may inform evidence, but do not claim this run passed without a fresh check.
3. Explore the goal through the adapter. Record the actual path and outcome. For data changes, confirm persistence after reload or through the authoritative data source. Apply `reference/verification-loop.md`'s vacuity guard to every `passed` claim.
4. Report `passed` only for observed outcomes, `failed` for a reproducible mismatch between expected and observed, and `blocked` when verification could not be completed. Include date, environment, method, evidence/artifact path, and actionable follow-up. A response code or absence of an error is not a pass.
5. For `/team-qa`, return each verdict under its exact scenario ID and archive path. The command writes `Status`/`Evidence` back to that same completed archive. Preserve earlier dated evidence when a named scenario is rechecked. No team escalation counter, rollback, automatic implementation fix, or recursive retry applies.

## Optional crystallization

Only when the user explicitly requests `--crystallize`: after a goal is **passed**, emit a deterministic regression test for an outcome worth rerunning and assertable without fragile timing. Follow the project's existing emitter conventions; for web, use `reference/e2e-testing.md` (`getByRole` before test IDs, response/element waits rather than fixed sleeps). Run the generated test. Allow at most two test-only repairs; discard it if it stays red. A green QA verdict and a green generated spec are distinct claims. Specs belong in the project's test directory; transient screenshots/traces/reports belong under its gitignored `_workspace/e2e/<run>/` layout.

## See also

- `commands/team-qa.md` — deferred queue selection and archive update contract
- `agents/team-agentic-tester.md` — scenario executor/report format
- `skills/agent-browser-e2e/SKILL.md` — web driver gate and login handling
- `reference/e2e-testing.md` — fixture, artifact, and optional test-emitter conventions
