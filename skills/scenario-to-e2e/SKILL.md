---
name: scenario-to-e2e
description: >-
  Turn a test-scenario-doc (the manual QA checklist from `test-scenario-doc`) into runnable Playwright
  E2E specs. Reads the doc's structured `SCENARIOS` config (steps/expect/fail) as the source of truth,
  drives the live app to resolve REAL selectors, and crystallizes each scenario into a `.spec.ts` that
  it runs and green-gates — never fabricating selectors, never claiming pass without a green run. Falls
  back to a clearly-marked "unverified scaffold" when the app/driver is unavailable. Use whenever the
  user wants to generate Playwright e2e tests FROM a test scenario doc / QA checklist / 테스트 시나리오
  문서 — "시나리오로 e2e 만들어줘", "scenario doc → playwright", "convert the QA checklist to e2e".
  On-demand (not phase-wired). Pairs with `test-scenario-doc` (input) and `e2e-testing` (house style).
---

# Scenario → E2E

> Bridges the **human** manual layer (`test-scenario-doc`) to the **deterministic** Playwright layer
> (`e2e-testing`). The scenario doc's `SCENARIOS` config is the **single source of truth**; the HTML
> checklist and the generated specs are both consumers of it.
>
> **Link, don't duplicate**: Playwright conventions live in `e2e-testing`; the generate→run→green
> crystallization discipline is borrowed from `agentic-testing`. This skill only owns the *mapping*
> from scenario fields to a runnable, verified spec. On-demand — not wired into any team phase.

## Two hard lines (they define the whole design)

1. **No fabricated selectors.** Scenario steps are human prose ("검색창에 빈 값으로 Enter"); they do
   NOT carry real selectors/routes. MUST resolve every interaction against the **live DOM** or mark
   that scenario a scaffold TODO. MUST NOT invent a plausible-looking `getByTestId`/`getByRole`.
2. **No unverified "done".** A generated spec that was never executed is not a deliverable. Every
   grounded spec MUST be RUN and reported at its real status (green / failing-bug / could-not-stabilize).
   MUST NOT report a spec as passing without a green run.

## Mode selection (do this first)

```
resolveMode():
  driverAvailable = Playwright MCP present  OR  agent-browser CLI+skill installed (see agent-browser-e2e gate)
  appReachable    = the doc's SETUP_HTML URL responds (or user gave a base URL)
  IF driverAvailable AND appReachable:  RETURN GROUNDED     # default — resolves real selectors + green-gates
  ELSE:                                  RETURN SCAFFOLD     # fallback — TODO selectors, marked UNVERIFIED
```

Never silently skip a scenario. If GROUNDED can't ground a particular card, that one card drops to
SCAFFOLD and is reported as unverified — the rest stay grounded.

## Input resolution (the config is the contract)

The shared data model is `test-scenario-doc`'s config: `META`, `GROUPS`, `MODE_LABEL`, `SETUP_HTML`,
`SCENARIOS[]` (each: `id`, `group`, `mode`, `title`, `edge`, `pre`, `steps[]`, `expect`, `fail`, `ref`).

- **Same session** (the doc was just generated here): reuse that config directly — don't re-parse.
- **Existing `.html` doc**: read the file, extract the `<script id="ts-config">` block, and recover
  `META`/`GROUPS`/`MODE_LABEL`/`SCENARIOS` from the object literals. Ignore the fixed runtime block.
- **Base URL / login**: pull from `SETUP_HTML` (env table). Feed the URL to `baseURL`; feed the
  account to an auth fixture — but as **env vars / `storageState`**, never a hardcoded password.

## Field → Playwright mapping

| Scenario field | Becomes | Notes |
|---|---|---|
| `GROUPS[]` | one `.spec.ts` per group, `test.describe(group.title)` | mirrors `e2e-testing` file org; small docs may collapse to one file |
| `id` + `title` | `test('<id> · <title>', …)` | **keep `id` as the prefix** — traceability + regression anchor back to the doc |
| `mode` (`MODE_LABEL` key) | `test`/`describe` tag: `{ tag: '@smoke'/'@regression'/'@edge' }` | lets `--grep @smoke` filter by test type |
| `pre` | `beforeEach` setup / navigation / seeded state | hoist to `beforeEach` when shared across the group |
| `steps[]` | ordered actions, each preceded by `// step N: <text>` | grounded mode resolves each to a real locator; comment keeps the human intent visible |
| `expect` | the PASS assertion(s) — `toBeVisible`/`toHaveURL`/`toHaveText` | must reflect what's **actually observable**, matching the doc's `expect` intent |
| `fail` | negative guard + `// FAIL SYMPTOM: <fail>` comment | e.g. `await expect(page.locator('.error-toast')).toHaveCount(0)` |
| `ref` | `// ref: <ref>` comment; if it's an API route → `waitForResponse` on it | ties the assertion to the route the doc names |
| `edge` | `// area: <edge>` comment | context only |

## GROUNDED pipeline (default)

Driver + concurrency follow `agentic-testing`'s web/TS adapter (one shared browser → **serialize** the
exploration lane; only the headless spec re-runs may fan out). Process scenarios in **id/risk order**
(auth/payment/data-mutation first).

Per scenario:

1. **Drive** the live app: apply `pre`, then walk `steps[]`, observing the real DOM at each step.
2. **Resolve** each interaction to a real locator by `e2e-testing` priority — `getByRole` >
   `getByLabel` > `getByPlaceholder` > `getByText` > `getByTestId`. If a target isn't findable in the
   live DOM → this scenario becomes SCAFFOLD (do not invent).
3. **Assert** from the observed success signal, encoding `expect` (PASS) and a guard against `fail`.
4. **Crystallize** into `.spec.ts` per `e2e-testing` (Page Object when a page repeats across scenarios;
   `waitForResponse`/`waitFor`, **never `waitForTimeout`**).
5. **Run it headless, then classify by why it's red — this is where honesty lives:**
   - **green** → keep. ✅
   - **red because the app reproduces the `fail` symptom** → this is a real bug the doc predicted.
     Keep the spec as a **documented failing test** (`test.fail()` if the failure is expected/known, or
     leave failing) and **escalate to the human** — a scenario that fails for real is a finding, not noise.
   - **red because the spec is flaky/mis-located** → self-repair ≤2 (apply the `e2e-testing` flaky
     fixes). Still red → mark `test.fixme` with a `// could not stabilize` note and report it. Never
     delete silently; never leave it green-looking.

MUST NOT edit backend code or generated API types (backend is SSOT). MUST NOT hardcode secrets.

## SCAFFOLD fallback (no app/driver, or an ungroundable card)

Emit a compilable skeleton per scenario so the human can wire selectors and run:

```ts
// ⚠ UNVERIFIED — generated from the scenario doc without a running app.
//   Selectors are TODO. Run against the app to ground + green-gate.
test('S1 · 로그인 → 대시보드 진입', { tag: '@smoke' }, async ({ page }) => {
  // pre: 미로그인 상태
  // step 1: 로그인 페이지에서 계정 입력 후 제출
  // TODO(selector): locate inputs + submit
  // step 2: 대시보드로 리다이렉트되는지
  // EXPECT: 올바른 자격증명이면 대시보드로 이동 + 사용자 이름 표시.
  await expect(page).toHaveURL(/dashboard/); // TODO: confirm real route
  // FAIL SYMPTOM: 에러 토스트 / 빈 화면 / 무한 로딩.
  // ref: POST /auth/login
});
```

Every scaffolded scenario is listed as `unverified` in the report — no silent skip.

## Output

- **Location**: the project's existing E2E dir (read `.claude/project-profile/testing.md` if present),
  else `tests/e2e/from-scenarios/`. One file per `GROUP` — **unless** the project splits specs by auth
  state (next bullet).
- **Respect the project's existing split conventions — mirror, don't impose.** If the project separates
  specs by **auth state** (distinct Playwright `projects` with their own `storageState`, e.g.
  `*.noauth.spec.ts` vs `*.auth.spec.ts`), route each scenario by its `pre` (needs login or not) into the
  matching project/file. Auth state is **orthogonal** to `GROUP`, so do NOT collapse authed + unauthed
  scenarios into one file just because they share a group — follow the project's existing split.
- **Summary report** (print; mirrors the `agentic-testing` output shape). Per scenario:
  `id · spec path · mode(grounded|scaffold) · status(green|failing-bug|fixme|unverified) · note`,
  then counts. Sections: Green / Failing-as-designed (→ human) / Could-not-stabilize / Unverified-scaffold.

## Re-test rounds (versioning)

When the scenario doc is re-versioned after fixes (`…-ver2.html`, `storageKey :v2`), regenerate ONLY
the changed/carried-over scenarios — mirror the doc's "drop already-passed, keep failures/holds" rule
so specs and the checklist stay in lockstep.

## See also (link, do not duplicate)
- `skills/test-scenario-doc/SKILL.md` — the input: the manual QA doc + the shared `SCENARIOS` config
- `skills/e2e-testing/SKILL.md` — Playwright house style (selectors, waits, POM, config) the specs obey
- `skills/agentic-testing/SKILL.md` — the driver/concurrency adapter + the generate→run→green discipline
- `skills/agent-browser-e2e/SKILL.md` — driver gate (agent-browser vs Playwright MCP) for GROUNDED mode
- `skills/verification-loop/SKILL.md` — vacuity guard applied to the "green" claim
