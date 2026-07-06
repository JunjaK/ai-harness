---
name: agentic-testing
description: "Agentic E2E testing layer (Phase 4.5). Use AFTER deterministic E2E passes and BEFORE human final review. An agent explores a goal via the stack's UI/API driver, verifies goal achievement, and crystallizes the path into a deterministic test. Stack-agnostic via project-profile adapters (web/TS base, Spring-Kotlin, Flutter)."
---

# Agentic Testing

> **Tests enforce journeys. Agents verify goals. Explore once, regress forever.**
> Position: **Phase 4.5** — after `team-tester` Phase 4 = PASS, before Phase 5. Complements (never replaces) deterministic E2E.

Two roles, one loop: at the late-stage checkpoint an agent (1) explores a goal to **verify** it (catching goal-level failures deterministic E2E missed → report to human) and (2) **crystallizes** the discovered path into a reusable deterministic test that joins the cheap CI layer.

## Precondition (MUST — abort if unmet)

1. MUST read `.claude/project-profile/{index.md, stack.md, testing.md}`. If absent → **ABORT**: "Run /team-init first."
2. MUST read `testing.md` → "Agentic Testing Adapter". If missing → require `/team-init --update`.
3. Staleness: if `Profile-Generated-At` is far behind HEAD → require `/team-init --update` before running.

## Adapter resolution (stack-agnostic; base = web/TS)

Resolve the adapter from `testing.md`'s "Agentic Testing Adapter" (derived from `stack.md`). The pipeline is fixed; the driver, emitter, and concurrency swap per surface. The emitter reuses each stack's existing testing skill as house style (link, don't duplicate).

| Surface | Explorer driver | Generator emitter (house-style skill) | Concurrency | Status |
|---|---|---|---|---|
| **web/TS (base)** | Playwright MCP (`mcp__plugin_playwright_playwright__*`) | `.spec.ts` ← `e2e-testing` | one shared browser → **serialize Explorer** | ready |
| **Spring/Kotlin (backend API)** | HTTP calls | `WebTestClient`/`@SpringBootTest` + Testcontainers ← `springboot-tdd`·`kotlin-testing` | stateless → **true parallel** (per-worker DB isolation) | ready |
| **Flutter/Dart (mobile UI)** | maestro · Patrol · mobile MCP | `integration_test` · maestro yaml | single device → **serialize per device** | **driver-gated** |
| Cross-journey (Flutter→Spring) | UI drive + backend assert | both layers | depends on above | later |

- **Driver unavailable** (e.g. mobile, no maestro/Patrol/MCP): do NOT run the goal — report `driver unavailable` (no silent skip).
- CLI execution model is a non-goal (article reliability). MCP-first.

## Goal derivation

Source = plan/spec acceptance criteria. Express goals as **outcomes** (not UI steps), risk-ordered (auth/payment/data first).

## Run-at-all gate (autonomous, NOT dollar-gated)

Run a goal only if ALL hold; else log the skip reason:
- **VALUE**: no overlap with an existing passing test for this flow.
- **TIME**: bounded steps (~25) and target reachable.
- **NOISE**: deterministically assertable (subjective/aesthetic → defer to `web-reviewer`/`impeccable`).

(This harness runs on a Claude Code subscription, not metered API — gate on value/time/noise, not cost.)

## Pipeline (Explorer → Generator)

1. **Explorer** (Sonnet + adapter driver): goal → adapt → verify. Record `met?`, the observed path, and evidence.
2. **Generator** (Opus): crystallize the path via the emitter house-style skill → **RUN the generated test** → keep ONLY if green (self-repair ≤2 attempts, else DISCARD). `met=false` → no spec, escalate to human.

Generated tests MUST obey the emitter skill's conventions (e.g. `e2e-testing`: `getByRole` > … > `getByTestId`; `waitForResponse`/`waitFor`, never `waitForTimeout`).

## Orchestration mode (standard vs ultracode)

The mode switch lives at the **orchestration layer** (`team-workflow` / `team-leader`) — a skill or spawned subagent cannot call the Workflow tool. `agents/team-agentic-tester.md` is the **standard-mode executor**.

```
selectMode(ctx):
  IF NOT workflowCallable():              RETURN STANDARD   # hard fallback
  IF NOT ultracodeActive(ctx):            RETURN STANDARD
  IF derivedGoalCount(ctx) < 2:           RETURN STANDARD   # 1 goal → fan-out buys nothing
  IF NOT targetReachable(ctx):            RETURN STANDARD
  RETURN ULTRACODE
```

| Aspect | Standard (default/fallback) | Ultracode |
|---|---|---|
| Execution | single `team-agentic-tester`, goals sequential | orchestrator runs a Workflow `pipeline()` fan-out (adapter concurrency policy) |
| Verdict trust | single judgment | perspective-diverse verify (skeptic + criteria-judge, agree to accept) + `verification-loop` vacuity guard |
| Generated spec | generate→run→repair ×2, discard non-green | same; headless spec-runs fan out |
| Edge sweep | none | bounded completeness-critic (≤2 rounds) |

**Shared-driver caveat**: web's Playwright MCP is one browser — under ultracode, serialize the Explorer lane (mutex); only Generator + headless runs fan out. Backend HTTP is stateless → Explorer may fan out too.

## Output (extends the team-tester report)

Per goal: `id`, `outcome`, `met`, `trustworthy` (ultracode verify), `green`, `specPath|null`, `skipReason|null`. Sections: Verified+crystallized / Verified-not-crystallizable / Unmet (→ human escalation) / Distrusted verdicts.

**Artifacts**: runtime artifacts (screenshots/traces/reports) follow the `_test/` gitignored **Artifact Layout** in `e2e-testing`; crystallized specs are committed **code** in the project's test dir, not `_test/`.

## See also (link, do not duplicate)
- `skills/agent-browser-e2e/SKILL.md` — on-demand `agent-browser` browser-driving + headless Auth Vault login (separate from this phase; the Phase 4.5 web Explorer stays Playwright MCP)
- `skills/e2e-testing/SKILL.md` — deterministic layer + web emitter conventions
- `skills/verification-loop/SKILL.md` — vacuity guard (applied to "met" claims)
- `skills/team-workflow/SKILL.md` — Phase 4.5 + Orchestration Mode

## Dry-run acceptance runbook (run in a real web/TS project)

1. `/team-init` → confirm `testing.md` has the Agentic Testing Adapter (Surface: web).
2. Pick one existing user-facing flow with acceptance criteria.
3. Standard mode: dispatch `team-agentic-tester`.
4. Confirm: (a) goal-verification report produced; (b) a generated `*.spec.ts` re-runs GREEN deterministically.
5. Negative: rename `.claude/project-profile` → confirm ABORT with "Run /team-init first."
