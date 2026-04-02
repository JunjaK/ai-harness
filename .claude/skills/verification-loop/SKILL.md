---
name: verification-loop
description: "6-phase verification system with checkpoint support and pass@k metrics. Use in Phase 4-5 of team workflow, before creating PRs, or after completing feature implementations. Covers build, type check, lint, test, security scan, diff review, checkpoints, and evaluation metrics."
---

# Verification Loop

Systematic quality assurance in 6 sequential phases with checkpoint tracking and pass@k evaluation. Stop on CRITICAL failure.

## Phases

### Phase 1: Build
Verify the project builds without errors.
```bash
# Adapt to your build system
npm run build 2>&1 | tail -20
```
**Pass**: Exit code 0
**Common failures**: Missing imports, circular dependencies, env issues

### Phase 2: Type Check
Run type checking on the full project.
```bash
# TypeScript
npx tsc --noEmit 2>&1 | head -50
```
**Pass**: Zero type errors
**Common failures**: Type mismatches, missing properties, incorrect generics

### Phase 3: Lint
Run linter and check for violations.
```bash
npx eslint . --max-warnings=0 2>&1 | head -30
```
**Pass**: No errors (warnings acceptable if configured)
**Common failures**: Unused imports, formatting issues, rule violations

### Phase 4: Tests
Run the full test suite.
```bash
npm test 2>&1
```
**Pass**: All tests pass, coverage ≥ 80%
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

## Pass@k Evaluation Metrics

### What is pass@k?

**pass@k**: At least 1 of k attempts succeeds. Use when any working solution suffices.
**pass^k**: All k attempts must succeed. Use when consistency is critical.

### Measuring pass@k

After running verification k times (e.g., k=3):

```
pass@1 = (successes / total_runs)
pass@3 = 1 - C(n-c, k) / C(n, k)    # where n=total, c=successes
```

### Practical Application

| Metric | Target | Use Case |
|--------|--------|----------|
| pass@1 ≥ 90% | Build, type check, lint | These should almost never fail |
| pass@1 ≥ 80% | Tests | Allows for some flaky tests |
| pass@3 ≥ 95% | Full verification loop | At least 1 of 3 runs clean |
| pass^3 = 100% | Security scan | Every run must pass |

### Tracking Flaky Tests

If pass@1 < pass@3, you have flaky tests. Track them:

```markdown
## Flaky Test Report
| Test | pass@1 | pass@3 | Root Cause |
|------|--------|--------|------------|
| auth.test.ts:45 | 60% | 95% | Race condition in token refresh |
| api.test.ts:120 | 80% | 100% | Timeout on slow CI |
```

**Action**: Quarantine flaky tests (mark as `.skip` or move to separate suite) until root cause is fixed.

### Grader Types

| Grader | Input | Output | When |
|--------|-------|--------|------|
| **Binary** | Exit code | pass/fail | Build, lint, type check |
| **Threshold** | Coverage % | pass if ≥ threshold | Test coverage |
| **Checklist** | Scan results | pass if all items clear | Security scan |
| **Subjective** | Diff review | pass/warn/fail | Code quality review |

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
**pass@1**: X% | **pass@3**: Y%
```

## When to Run

- After completing a feature or significant code change
- Before creating a PR
- After Phase 3 (Implementation) in team workflow
- As Phase 4-5 checkpoint in team workflow
- After resolving escalation issues
- When comparing quality between checkpoints
