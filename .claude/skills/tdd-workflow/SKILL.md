---
name: tdd-workflow
description: "Test-Driven Development workflow using Vitest 4.x. Use in Phase 3 (Implementation) when Designers write code. Enforces Red-Green-Refactor cycle with 80%+ coverage. Covers unit, integration, and E2E test patterns."
---

# TDD Workflow

## Test Framework

**Default**: Vitest 4.x for unit and integration tests. Playwright for E2E.

Project profile overrides this default. Read `testing.md` from `.claude/project-profile/` to detect the actual framework. If the project uses a different framework (Jest, Mocha, Bun test, etc.), translate the patterns below to that framework's idiom.

## Red-Green-Refactor Cycle

```
1. RED    — Write failing test (MUST fail for the right reason)
2. GREEN  — Write MINIMUM code to pass (no extra features)
3. REFACTOR — Clean up while keeping tests green
4. REPEAT — One cycle per public behavior
```

## Step-by-Step

### 1. Define Test Cases

For every public function/component/hook, identify these three cases BEFORE writing any test:
- Happy path (expected behavior with valid input)
- At least one edge case (null, empty, boundary values)
- At least one error case (invalid input, dependency failure)

### 2. Write Failing Test (RED)

```typescript
// calculateTotal.test.ts
import { describe, it, expect } from 'vitest';
import { calculateTotal } from './calculateTotal';

describe('calculateTotal', () => {
  it('sums item prices multiplied by quantities', () => {
    const items = [
      { price: 100, quantity: 2 },
      { price: 50, quantity: 1 },
    ];
    expect(calculateTotal(items)).toBe(250);
  });

  it('returns 0 for empty array', () => {
    expect(calculateTotal([])).toBe(0);
  });

  it('returns 0 for null input', () => {
    expect(calculateTotal(null)).toBe(0);
  });
});
```

Run the test and verify failure:
```bash
npx vitest run calculateTotal.test.ts
```

Expected failure reason: `calculateTotal` is not defined, or implementation is incomplete. If the failure is a syntax error in the test itself, fix the test before proceeding.

### 3. Minimal Implementation (GREEN)

Write the MINIMUM code required to make the tests pass. Do not add features beyond what tests require.

```typescript
// calculateTotal.ts
type Item = { price: number; quantity: number };

export function calculateTotal(items: Item[] | null): number {
  if (!items) return 0;
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

Run tests and verify pass:
```bash
npx vitest run calculateTotal.test.ts
```

### 4. Refactor

With tests green, apply these refactors in order:
1. Extract shared logic when the same pattern appears 3+ times
2. Improve naming (replace abbreviations with full words)
3. Simplify conditionals (early returns, guard clauses)
4. Run tests after EACH refactor. If tests fail, revert to the last green state.

### 5. Commit

One commit per RED→GREEN→REFACTOR cycle:
```bash
git add <specific files>
git commit -m "feat: add calculateTotal with TDD"
```

## Test Type Selection Matrix

| Target | Test Type | Framework | Rationale |
|--------|-----------|-----------|-----------|
| Pure function / utility | Unit | Vitest | No framework dependency |
| Data transformation | Unit | Vitest | Pure input/output |
| Store / state management | Integration | Vitest | Needs reactive environment |
| Composable / custom hook | Integration | Vitest + `@testing-library/react` (or framework equivalent) | Needs component context |
| API integration | Integration | Vitest + MSW or nock | Needs mock server |
| User workflow spanning pages | E2E | Playwright | Needs real browser |

## Vitest 4.x Patterns

### Mocking

```typescript
import { vi, describe, it, expect, beforeEach } from 'vitest';
import * as api from './api';

vi.mock('./api', () => ({
  fetchUser: vi.fn(),
}));

describe('UserService', () => {
  beforeEach(() => {
    vi.mocked(api.fetchUser).mockReset();
  });

  it('returns user when API succeeds', async () => {
    vi.mocked(api.fetchUser).mockResolvedValue({ id: '1', name: 'Test' });
    const result = await getUser('1');
    expect(result.name).toBe('Test');
  });
});
```

### Setup / Teardown

```typescript
import { beforeEach, afterEach, beforeAll, afterAll } from 'vitest';

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});
```

### Coverage

```bash
npx vitest run --coverage
```

Default coverage provider: `v8`. Add `@vitest/coverage-v8` to devDependencies if not already present.

Required thresholds (enforced via `vitest.config.ts`):
```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80,
      },
    },
  },
});
```

### Concurrent vs Sequential

- Use `it.concurrent` for independent tests (no shared state)
- Use `describe.sequential` when tests MUST run in order (integration flows)

## Quality Checklist (MUST evaluate every item before committing)

- [ ] Every test describes behavior (WHAT), not implementation (HOW)
- [ ] Each test asserts ONE thing (single responsibility)
- [ ] Zero `any` types in test code
- [ ] Mocks exist ONLY at external boundaries (API, timers, filesystem, random)
- [ ] Every public function has ≥ 3 tests (happy, edge, error)
- [ ] Coverage ≥ 80% for lines, functions, branches, statements

## Anti-Patterns (MUST NOT do)

| Anti-pattern | Correct pattern |
|--------------|----------------|
| `expect(result).toBeTruthy()` | `expect(result).toBe(true)` |
| Test internal state | Test public API behavior |
| Mock internal functions | Mock only external boundaries |
| Share mutable state between tests | Fresh setup in `beforeEach` |
| Write implementation before tests | Tests FIRST — no exceptions |
| `test.skip` without follow-up ticket | Fix the test or remove it |
| `.only` committed to the repo | Use CLI `--grep` flag locally instead |
