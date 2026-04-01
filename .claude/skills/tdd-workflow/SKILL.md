---
name: tdd-workflow
description: "Test-Driven Development workflow. Use in Phase 3 (Implementation) when Designers write code. Enforces Red-Green-Refactor cycle with 80%+ coverage. Covers unit, integration, and E2E test patterns."
---

# TDD Workflow

## Red-Green-Refactor Cycle

```
1. RED    — Write failing test (must fail for the right reason)
2. GREEN  — Write MINIMUM code to pass (no extra features)
3. REFACTOR — Clean up while keeping tests green
4. REPEAT
```

## Step-by-Step

### 1. Define Test Cases
Before coding, identify:
- Happy path (expected behavior)
- Edge cases (null, empty, boundary values)
- Error cases (invalid input, API failures)

### 2. Write Failing Test (RED)
```typescript
describe('calculateTotal', () => {
  it('should sum all item prices with quantities', () => {
    const items = [
      { price: 100, quantity: 2 },
      { price: 50, quantity: 1 },
    ];
    expect(calculateTotal(items)).toBe(250);
  });

  it('should return 0 for empty array', () => {
    expect(calculateTotal([])).toBe(0);
  });

  it('should handle null input gracefully', () => {
    expect(calculateTotal(null)).toBe(0);
  });
});
```

Run to confirm failure:
```bash
npm test -- --run path/to/test.test.ts
```

### 3. Minimal Implementation (GREEN)
Write MINIMUM code to pass:
```typescript
function calculateTotal(items: Item[] | null): number {
  if (!items) return 0;
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}
```

### 4. Refactor
With tests green, improve:
- Extract shared logic
- Improve naming
- Simplify conditionals
- Run tests after EACH change

### 5. Commit
```bash
git add .
git commit -m "feat: add calculateTotal with TDD"
```

## Test Type Selection

| Target | Test Type | Why |
|--------|-----------|-----|
| Pure function, utility | Unit | No framework dependency |
| Data transformation | Unit | Pure input/output |
| State management (store) | Integration | Needs reactivity |
| API integration | Integration | Needs mock server |
| User workflow | E2E | Needs real browser |

## Quality Checklist

- [ ] Tests describe WHAT, not HOW
- [ ] Each test tests ONE thing
- [ ] No `any` types in test code
- [ ] Mocks only at external boundaries (API, timers)
- [ ] Edge cases covered (null, empty, boundary)
- [ ] Coverage ≥ 80% for new code

## Anti-Patterns

| Don't | Do Instead |
|-------|-----------|
| `expect(result).toBeTruthy()` | `expect(result).toBe(true)` |
| Test internal state | Test public API behavior |
| Mock internal functions | Mock external boundaries |
| Share mutable state between tests | Fresh setup in `beforeEach` |
| Write implementation before tests | Tests FIRST, always |
