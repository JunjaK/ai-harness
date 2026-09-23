---
name: verification-loop
description: "Full verification reference with checkpoint support and reliability gates. Team Phase 4 uses only its bounded one-pass subset; deeper QA runs through /team-qa."
---

# Verification Loop

Systematic quality assurance in 6 sequential phases (plus an opt-in human comprehension gate) with checkpoint tracking and reliability gates. Stop on CRITICAL failure.

In the team workflow, this is a reference for authoritative commands and baseline comparison. `agents/team-tester.md` defines the bounded Phase 4 pass: affected unit/integration tests, at most one already existing smoke E2E per affected flow, and relevant build/type/lint gates. The full deterministic loop runs only when explicitly requested; `/team-qa` separately verifies deferred scenarios. Neither is an automatic team phase.

**Package manager**: Commands below use Bun (default). If project has `pnpm-lock.yaml`, translate `bun run` → `pnpm run`, `bunx` → `pnpm exec`. If `package-lock.json`, translate to `npm run` / `npx`.

## Phases

### Phase 0: Contract Sync (conditional)
If this change touched the **server contract** (DB schema → response, request/response DTO, enum, endpoint shape) AND the client is **code-generated** (project-profile `api-layer.md` → "Generated Code"), regenerate and re-verify the client BEFORE anything below. Type-checking before regenerating verifies stale types — the most expensive failure mode, because it passes while being wrong.

Run the `contract-sync` skill (regenerate → isolate churn → authoritative type-check → cross-check consumption sites). Skip this phase only when there is no codegen or the change provably alters no served shape.

### Phase 1: Build
Verify the project builds without errors.
```bash
# Adapt to your build system
bun run build
```
**Pass**: Build command exit code 0. If displaying only the last lines, preserve the build command's exit status (`set -o pipefail`) or inspect its captured exit code; a successful `tail` is not a successful build.
**Common failures**: Missing imports, circular dependencies, env issues

### Phase 2: Type Check
Run the project's **authoritative** type-check command — the one that actually compiles the app sources, recorded in project-profile `stack.md` → "Build & Verify". Do NOT assume `bunx tsc --noEmit`: a root `tsconfig.json` that is solution-style (`"files": []` + `"references"`) makes `tsc --noEmit` a **no-op that always exits 0**, hiding a real error backlog. Likewise a `typecheck` npm script may point at the wrong config. Verify the command actually checks code before trusting a green result (see §"Vacuity guard").
```bash
# Use the authoritative command from project-profile. Examples:
#   tsc --noEmit -p tsconfig.app.json       (app-scoped, not the empty root)
#   vue-tsc -p .nuxt/tsconfig.app.json       (Nuxt/Vue)
#   pyright / mypy --strict / go vet ./...    (non-TS)
<authoritative-typecheck-command>
```
**Pass**: Zero **net-new** type errors vs the recorded baseline (see §"Baseline & Net-New"). Absolute zero only for greenfield projects with no baseline.
**Common failures**: Type mismatches, missing properties, incorrect generics

**Complementary checks (during implementation, NOT a replacement):**
- `LSP` tool with `hover` — inspect inferred types on any symbol
- `mcp__ide__getDiagnostics` (when IDE is connected) — live diagnostics per file
- Note: editor/LSP diagnostics go **stale mid-edit** and can emit false cascades (e.g. a large inferred store collapsing to `any`). The standalone compiler run is the authority — re-run it before asserting a result.

### Phase 3: Lint
Run the project's authoritative linter (from project-profile; `bunx eslint .` / `bunx biome check` / etc.).
```bash
<authoritative-lint-command> --max-warnings=0
```
**Pass**: Zero **net-new** errors vs baseline (see §"Baseline & Net-New"). Warnings acceptable if the project configures them as such.
**Common failures**: Unused imports, formatting issues, rule violations

### Phase 4: Tests
The commands below are examples for broader standalone deterministic verification. Team Phase 4 follows `agents/team-tester.md`: selected affected unit/integration tests and at most one ready, existing smoke E2E per affected flow. It does not run broad coverage instrumentation unless the project already requires that gate or the user explicitly requests it.

**Default: scoped to this task's changes, not the full suite.** On a large repo, an unscoped run on every verification pass is the dominant CPU/time cost. Vitest and Playwright both detect affected tests via git + the import graph natively — use that instead of a custom scope calculation. Run the full suite only when the user explicitly asks for it in the current request (e.g. "run the full suite", "전체 테스트 돌려줘", "total test").

Use command from project-profile `testing.md`. Default for Vitest 4.x / Playwright, scoped:
```bash
bunx vitest run --changed --coverage 2>&1
npx playwright test --only-changed 2>&1
```
`--changed`/`--only-changed` compare against uncommitted changes by default; pass an explicit ref (`--changed origin/main`, `--only-changed=origin/main`) when the change is already fully committed (e.g. reviewing a finished branch).

User explicitly requested a full run → drop the flag:
```bash
bunx vitest run --coverage 2>&1
npx playwright test 2>&1
```

**Pass**: All tests run (scoped or full, per above) pass, coverage ≥ 80% (lines, functions, branches, statements) on the files actually run
**Common failures**: Broken assertions, missing mocks, flaky tests
**Caveat**: both flags are heuristics over the import graph (static imports only; `--changed` needs `forceRerunTriggers` for config-driven reruns, `--only-changed` won't see dynamically-loaded fixtures). Not a substitute for an occasional full run — that's what the explicit-request escape hatch is for, not an automatic periodic one.

**After parallel implementation merges**: verify the merged tree, not only each Designer's isolated worktree. In team Phase 4, run the relevant gates once after the last merge. Review shared contracts across Designer boundaries (imports, generated clients, API shapes, migrations, route wiring); select a focused integration check where the changed-test heuristic misses a dependency. A green worktree report does not replace this merged-tree gate.

For team Phase 4, classify the one-pass result using `skills/team-workflow/resources/escalation.md`'s verification outcomes. A failed or blocked required check ends that run with evidence; it does not trigger a QA retry or return to implementation. Record omitted optional smoke checks and the pending `/team-qa` case; do not silently turn a required check into an optional one.

### Phase 5: Security Scan
Check changed files for:
- Hardcoded secrets (`password`, `secret`, `api_key`, `token`)
- Debug statements (`console.log`, `debugger`) in production code
- Hardcoded URLs (should use env variables)
- Unsafe patterns (eval, innerHTML with user input)

### Phase 6: Diff Review
Review `git diff` for:
- Unused imports or dead code
- Missing error handling
- Missing i18n (hardcoded user-facing text)
- Type safety issues (`any`, `as` casts)
- Missing test coverage for new code paths

### Phase 7: Comprehension Quiz (human gate — opt-in)
Phases 1–6 verify the *machine* is satisfied; this verifies the *human* understands what shipped. For a large or long-horizon change (many files, a new subsystem, an overnight/away run), a green diff is not enough — reading a diff gives only light understanding when behavior depends on existing code paths.

Generate a short quiz on the change — what was done, why, which existing paths it touches, what could break — and have the human answer it. Merge only after they pass. This is the human-understanding counterpart to the machine gates, aligned with "network 200 / UI success ≠ verified": a change no one can explain is a change no one can safely merge.

**Opt-in**: run it before merge on anything you couldn't confidently explain from the diff alone; skip it for small, self-evident changes. Deliver the quiz as an HTML report (context + intuition + what-changed, quiz at the bottom) when the change is big enough to warrant reading.

## Baseline & Net-New (applies to Phase 2 & 3)

Greenfield projects gate on absolute zero. **Legacy projects accumulate a baseline** of pre-existing type/lint errors that no single task can clear — demanding absolute zero there is unactionable and pressures masking. So gate on **net-new** errors instead:

1. **Record the baseline** once (and refresh it deliberately): run the authoritative type-check/lint on the untouched base and store the count + a normalized snapshot. Normalize by stripping `file:line:col` so unrelated line shifts don't read as new errors — compare error *signatures* (rule + message + symbol), not raw lines.
2. **Gate on the delta**: `net-new = current − baseline`. Net-new must be **0**. A net-new count that is negative (you fixed some) is good; positive blocks.
3. **Verify per file, not in bulk**: when fixing pre-existing errors, apply and re-check file by file. Batch auto-fixing across a large baseline regresses — a fix valid in isolation can break a caller elsewhere.
4. **Never mask a net-new error that flags a real bug.** A type error can be correctly *blocking* an incomplete or wrong code path; silencing it with `as any`/`@ts-ignore`/a cast hides a runtime defect. Investigate the error's intent before suppressing — the test for "is this safe to ignore" is "does the runtime behavior remain correct," not "does the red go away."

The Tester already applies this judgment to **tests** (failure predates task → pre-existing; else → regression). Phase 2 & 3 extend the same net-new discipline to **types and lint**.

## Vacuity guard (applies to Phase 1–4)

A green result is only trustworthy if the command actually exercised the code. Before trusting any PASS, confirm the command is not vacuous:
- **Type-check**: a solution-style root `tsconfig.json` (`"files": []`) makes `tsc --noEmit` check nothing. Confirm the command targets the app's real tsconfig (the one with `include`/sources). If a typed framework wrapper exists (`vue-tsc`, `astro check`), the bare `tsc` may under-check.
- **Tests**: zero tests collected is not a pass. Confirm a non-zero test count ran.
- **Lint**: zero files linted (bad glob / wrong cwd) is not a pass. Confirm files were actually scanned.
- **Background process / server**: a start command exiting 0 — or printing `listening on :PORT` — is not proof it stayed up. At the moment you claim "running", re-confirm the process is alive and the port answers (health `curl` / `lsof -i :PORT` / `ps`). A server that crashed just after boot, or a port already released, is not a pass.

Record the **authoritative** command in project-profile `stack.md` so every phase and every agent uses the verified one, never a convenience alias whose behavior is unknown.

## Checkpoint System

### What is a Checkpoint?

A checkpoint is an explicit verification snapshot taken at milestones. It saves the current verification state so you can:
- Compare before/after quality across implementation phases
- Roll back to a known-good state if later changes break things
- Track quality progression across the team workflow

### When to Checkpoint

| Trigger | Action |
|---------|--------|
| Phase 1 plan finalized | Checkpoint: baseline (pre-implementation) |
| Each Designer completes TDD cycle | Checkpoint: per-worktree verification |
| All worktrees merged | Checkpoint: integration verification |
| Before PR creation | Checkpoint: final gate |

### Checkpoint Format

Save to `.claude/session-state/checkpoints/`:

```markdown
# Checkpoint: {name}
**Timestamp**: {ISO datetime}
**Phase**: {workflow phase}
**Trigger**: {what caused this checkpoint}

## Verification Results
| Phase | Status | Details |
|-------|--------|---------|
| Build | ✅/❌ | ... |
| Type Check | ✅/❌ | ... |
| Lint | ✅/❌ | ... |
| Tests | ✅/❌/unverified | X pass, Y fail, Z% coverage; selected test count |
| Security | ✅/❌ | ... |
| Diff Review | ✅/⚠️/❌ | ... |

## Delta from Previous Checkpoint
- Tests: +N new, -M removed, coverage Δ{+/-X%}
- New issues: {list}
- Resolved issues: {list}
```

### Checkpoint vs Continuous

| Model | When | How |
|-------|------|-----|
| **Checkpoint** | At defined milestones | Explicit snapshot, compare deltas |
| **Continuous** | After every significant change | Run full verify loop each time |

**Default**: Use continuous for small tasks (< 3 files). Use checkpoints for team workflows.

## Reliability Gates

For a separately requested full verification run, these reliability gates apply. They do not cause the team Phase 4 pass to repeat:

- **Tests: every required final-gate check green on the merged result.** A retry can diagnose a flaky test but does not convert its first failure into a pass; record the cause, fix it, and rerun. Do not quarantine a newly failing required test merely to make the gate green.
- **Security scan: 100% of 3 runs clean** — any single failing run blocks the merge.

A test that passes on retry but not on first run is **flaky**: record the first failure and its cause, then repair it. An unresolved flaky test never counts as a pass; a new `.skip` is not a repair.

## Output Format

```markdown
| Phase | Status | Details |
|-------|--------|---------|
| Build | ✅/❌ | ... |
| Type Check | ✅/❌ | ... |
| Lint | ✅/❌ | ... |
| Tests | ✅/❌/unverified | X pass, Y fail, Z% coverage; selected test count |
| Security | ✅/❌ | ... |
| Diff Review | ✅/⚠️/❌ | ... |

**Overall: READY / NEEDS FIXES**
**Checkpoint**: {name} (delta from previous: ...)
**Reliability**: required final checks green on merged tree · security 3/3 clean
```

## When to Run

- After completing a feature or significant code change
- Before creating a PR
- As the command and baseline reference for the bounded team Phase 4 pass
- During a separately requested `/team-qa` run
- In a later, explicitly requested verification run after resolving an issue
- When comparing quality between checkpoints
- Before merging a large / long-horizon change you couldn't fully explain from the diff — run Phase 7 (comprehension quiz)
