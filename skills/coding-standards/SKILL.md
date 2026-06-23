---
name: coding-standards
description: "Universal coding standards and best practices. Use in Phase 3 (Implementation) as the baseline for Designer agents. Covers readability, KISS, DRY, YAGNI, TypeScript patterns, error handling, and code smell detection."
---

# Coding Standards

Universal standards applicable across all projects.

## Principles

### 1. Readability First
- Code is read more than written
- Clear variable and function names
- Self-documenting code over comments
- Consistent formatting

### 2. KISS (Keep It Simple)
- Simplest solution that works
- No over-engineering
- No premature optimization
- Easy to understand > clever code

### 3. DRY (Don't Repeat Yourself)
- Extract common logic into functions
- Create reusable components
- Share utilities across modules

### 4. YAGNI — Decision Ladder (the best code is the code you never wrote)

Before writing ANY code, walk this ladder top-down and STOP at the first rung that satisfies the need:

1. **Does this need to exist?** → no: skip it (YAGNI).
2. **Already in this codebase?** → reuse it, don't rewrite.
3. **Stdlib does it?** → use it.
4. **Native platform feature?** → use it (e.g. `<input type="date">` over a date-picker library).
5. **Installed dependency?** → use it; don't add another.
6. **One line?** → one line.
7. **Only then:** write the minimum that works.

- Don't build features before needed; no speculative generality; start simple, refactor when needed.
- **Lazy, not negligent.** Minimalism applies to *solution complexity ONLY*. Trust-boundary validation, data-loss handling, security, accessibility, and tests are NEVER on the chopping block — the harness gates these hard (TDD, verification-loop, Phase 5 security). Cutting them is not minimalism, it's a defect.
- **Lazy about the solution, never about reading.** Understand the existing code flow before deciding what to cut or reuse.
- The `ponytail` plugin operationalizes this ladder (modes + `/ponytail-review`); see CLAUDE.md "Code Minimalism (ponytail)".

## TypeScript Standards

### Strict Mode (REQUIRED)

`tsconfig.json` MUST include:
```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true
  }
}
```

### Type Safety Rules

- Zero `any` types in production code (use `unknown` + type narrowing)
- Zero `as` casts without a `// ts-expect-error: [reason]` comment or explicit refinement
- Every exported function MUST have explicit parameter and return types
- `type` for unions, `interface` for object shapes that may be extended

### Variables & Naming
```typescript
// ✅ Descriptive names
const isUserAuthenticated = true;
const maxRetryCount = 3;
const fetchUserById = async (id: string) => { ... };

// ❌ Vague names
const flag = true;
const n = 3;
const doStuff = async (x: string) => { ... };
```

### Error Handling
```typescript
// ✅ Specific error handling
try {
  const data = await fetchUser(id);
  return data;
} catch (error) {
  if (error instanceof NotFoundError) {
    return null;
  }
  throw error; // Re-throw unexpected errors
}

// ❌ Silent swallow
try {
  const data = await fetchUser(id);
} catch (error) {
  // silently ignored
}
```

### Async/Await
```typescript
// ✅ Parallel when independent
const [users, posts] = await Promise.all([
  fetchUsers(),
  fetchPosts(),
]);

// ❌ Sequential when independent
const users = await fetchUsers();
const posts = await fetchPosts();
```

### Type Safety
```typescript
// ✅ Explicit types at boundaries
function processOrder(order: Order): ProcessedOrder { ... }

// ❌ any/unknown without narrowing
function processOrder(order: any): any { ... }
```

## Reactivity & Effects (frameworks with reactive state)

Applies to Vue, Svelte, Solid, MobX, RxJS, React effects — anywhere a value change can implicitly trigger code.

- **Prefer explicit event/lifecycle/hook triggers over reactive watchers.** A `watch`/`$effect`/`useEffect`/`autorun` makes "when and why did this run" implicit — it fires on dependency changes you may not have intended, runs in an order that's hard to reason about, and is a frequent source of redundant work and feedback loops. An explicit handler (`onSubmit`, `afterChange`, a lifecycle hook, an event bus) says exactly when it runs.
- **Before adding a watcher, justify it**: is there a concrete event or lifecycle point that expresses the same intent? Use the watcher only when the trigger genuinely is "this derived value changed and there is no event for it."
- **Never chain watchers that write state other watchers read** — that is an implicit dependency graph that re-runs unpredictably. Make the flow explicit.
- Why this matters: most "why did this run twice / in the wrong order / infinitely" bugs in reactive UIs trace back to a watcher doing work that an event should have done.

## Data Integrity (write / sync / migration / automated-write paths)

Operations that mutate user data, transition state, or run automated/AI writes need a higher-scrutiny lens than read paths.

- **Validate at the input boundary AND re-validate on the server.** Client-side validation (a form/widget) is a UX affordance, not a guarantee — paste, import, and direct-API paths bypass it. The backstop is server-side re-validation on every non-UI write path. (Storing a value as text while validating shape at input time is a legitimate strategy, but only with that server backstop.)
- **Make write/sync operations idempotent.** A sync/upsert that lacks a uniqueness guard or "already-applied" check will duplicate-write on every run. Before shipping a write path, ask: "if this runs twice, does it corrupt data?" If yes, add the guard (unique constraint, dedupe key, conditional insert).
- **Don't silence a type/lint error on a write path without understanding it** — on these paths a suppressed error is disproportionately likely to be a real data-corruption bug (see verification-loop §"Baseline & Net-New").

## Code Smells

| Smell | Fix |
|-------|-----|
| Function > 30 lines | Extract smaller functions |
| Nesting > 3 levels | Early return, extract helpers |
| Magic numbers | Named constants |
| Boolean parameters | Use options object |
| God class/file | Split by responsibility |
| Copy-paste code | Extract shared utility |
| Long parameter list | Use options object or builder |

## File Organization

```
src/
├── components/     # UI components
├── composables/    # Reusable logic
├── stores/         # State management
├── services/       # API/business logic
├── utils/          # Pure utilities
├── types/          # Type definitions
└── pages/          # Route pages
```

## Comments

```typescript
// ✅ Explain WHY, not WHAT
// Retry with exponential backoff because the payment API
// has intermittent 503s during peak hours
await retryWithBackoff(processPayment, { maxRetries: 3 });

// ❌ Restating the code
// Set count to 0
let count = 0;
```
