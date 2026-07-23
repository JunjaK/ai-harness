---
name: verification-loop
description: "6-phase verification system (+ an opt-in human comprehension quiz gate) with checkpoint support and reliability gates. Use in Phase 4-5 of team workflow, before creating PRs, or after completing feature implementations. Covers build, type check, lint, test, security scan, diff review, a human-understanding gate, checkpoints, and reliability gates."
---

# Verification Loop

Systematic quality assurance in 6 sequential phases (plus an opt-in human comprehension gate) with checkpoint tracking and reliability gates. Stop on CRITICAL failure.

**Package manager**: Commands below use Bun (default). If project has `pnpm-lock.yaml`, translate `bun run` → `pnpm run`, `bunx` → `pnpm exec`. If `package-lock.json`, translate to `npm run` / `npx`.

## Phases

### Phase 0: Contract Sync (conditional)
If this change touched the **server contract** (DB schema → response, request/response DTO, enum, endpoint shape) AND the client is **code-generated** (project-profile `api-layer.md` → "Generated Code"), regenerate and re-verify the client BEFORE anything below. Type-checking before regenerating verifies stale types — the most expensive failure mode, because it passes while being wrong.

Run the `contract-sync` skill (regenerate → isolate churn → authoritative type-check → cross-check consumption sites). Skip this phase only when there is no codegen or the change provably alters no served shape.

### Phase 1: Build
Verify the project builds without errors.
```bash
# Adapt to your build system
bun run build 2>&1 | tail -20
```
**Pass**: Exit code 0
**Common failures**: Missing imports, circular dependencies, env issues

### Phase 2: Type Check
Run the project's **authoritative** type-check command — the one that actually compiles the app sources, recorded in project-profile `stack.md` → "Build & Verify". Do NOT assume `bunx tsc --noEmit`: a root `tsconfig.json` that is solution-style (`"files": []` + `"references"`) makes `tsc --noEmit` a **no-op that always exits 0**, hiding a real error backlog. Likewise a `typecheck` npm script may point at the wrong config. Verify the command actually checks code before trusting a green result (see §"Vacuity guard").
```bash
# Use the authoritative command from project-profile. Examples:
#   tsc --noEmit -p tsconfig.app.json       (app-scoped, not the empty root)
#   vue-tsc -p .nuxt/tsconfig.app.json       (Nuxt/Vue)
#   pyright / mypy --strict / go vet ./...    (non-TS)
<authoritative-typecheck-command> 2>&1 | head -50
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
<authoritative-lint-command> --max-warnings=0 2>&1 | head -30
```
**Pass**: Zero **net-new** errors vs baseline (see §"Baseline & Net-New"). Warnings acceptable if the project configures them as such.
**Common failures**: Unused imports, formatting issues, rule violations

### Phase 4: Tests
Run the full test suite. Use command from project-profile `testing.md`. Default for Vitest 4.x:
```bash
bunx vitest run --coverage 2>&1
```
**Pass**: All tests pass, coverage ≥ 80% (lines, functions, branches, statements)
**Common failures**: Broken assertions, missing mocks, flaky tests

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
| Tests | ✅/❌ | X pass, Y fail, Z% coverage |
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

Two hard thresholds, measured by re-running the loop — no other metric is required:

- **Tests: ≥ 80% of runs green** (one pass; below that treat the suite as flaky, not the code as broken).
- **Security scan: 100% of 3 runs clean** — any single failing run blocks the merge.

A test that passes on retry but not on first run is **flaky**: quarantine it (`.skip` or a separate suite) with the root cause recorded, and fix it — a flaky test never counts as a pass.

## Output Format

```markdown
| Phase | Status | Details |
|-------|--------|---------|
| Build | ✅/❌ | ... |
| Type Check | ✅/❌ | ... |
| Lint | ✅/❌ | ... |
| Tests | ✅/❌ | X pass, Y fail, Z% coverage |
| Security | ✅/❌ | ... |
| Diff Review | ✅/⚠️/❌ | ... |

**Overall: READY / NEEDS FIXES**
**Checkpoint**: {name} (delta from previous: ...)
**Reliability**: tests X/Y runs green · security 3/3 clean
```

## When to Run

- After completing a feature or significant code change
- Before creating a PR
- After Phase 3 (Implementation) in team workflow
- As Phase 4-5 checkpoint in team workflow
- After resolving escalation issues
- When comparing quality between checkpoints
- Before merging a large / long-horizon change you couldn't fully explain from the diff — run Phase 7 (comprehension quiz)
