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

### 4. YAGNI (You Aren't Gonna Need It)
- Don't build features before needed
- No speculative generality
- Start simple, refactor when needed

## TypeScript Standards

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
