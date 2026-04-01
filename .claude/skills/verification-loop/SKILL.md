---
name: verification-loop
description: "6-phase verification system for pre-merge quality assurance. Use in Phase 4-5 of team workflow, before creating PRs, or after completing feature implementations. Covers build, type check, lint, test, security scan, and diff review."
---

# Verification Loop

Systematic quality assurance in 6 sequential phases. Stop on CRITICAL failure.

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

## Output Format

```markdown
| Phase | Status | Details |
|-------|--------|---------|
| Build | ✅/❌ | ... |
| Type Check | ✅/❌ | ... |
| Lint | ✅/❌ | ... |
| Tests | ✅/❌ | X pass, Y fail |
| Security | ✅/❌ | ... |
| Diff Review | ✅/⚠️/❌ | ... |

**Overall: READY / NEEDS FIXES**
```

## When to Run

- After completing a feature or significant code change
- Before creating a PR
- After Phase 3 (Implementation) in team workflow
- As Phase 4-5 checkpoint in team workflow
- After resolving escalation issues
