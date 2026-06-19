# TypeScript Structural-Typing & DI Traps

Load this when a bug looks like a **type-system or dependency-injection** failure rather than ordinary logic — especially cascading "property does not exist" floods, intermittent context errors, or opaque deserialization failures. These are non-obvious, recur across projects, and waste hours when diagnosed as logic bugs.

## 1. Inference-cycle collapse → annotate the consumed variable (not the return type)

**Symptom**: a sudden flood of "property X does not exist" across many files, when no individual change looks wrong. Two large modules (e.g. two stores, a service + its consumer) whose **inferred return types depend on each other** form an inference cycle; TypeScript gives up and collapses both to an empty/`any`-like type, and every property access downstream errors.

**Fix**: break the cycle by annotating the **consumed variable with an explicit interface** (the public surface you actually use) at the call site:

```typescript
// ❌ does NOT break the cycle — annotating the function's return type
export function useCoordinator(): CoordinatorApi { ... } // still cycles via internal use of the store

// ✅ breaks the cycle — annotate the variable that holds the cross-referenced module
const store: SiteStoreSurface = useSiteStore() // explicit interface severs the inference edge
```

Define `SiteStoreSurface` as the minimal interface of what this consumer reads. This is a **type-only wedge** — zero runtime change. Annotating the producer's return type usually fails; annotate at the **consumption** point.

**Generalizes to**: any two modules with mutually-dependent inferred types (Pinia/Vuex stores, NgRx selectors, large builder chains).

## 2. Context-bound singleton: first instantiation MUST be in a synchronous setup context

**Symptom**: intermittent, role/route-dependent runtime crashes like "X is not iterable", "Y is undefined", or an i18n/inject error — and once it happens, everything downstream breaks (a partial/broken instance got cached).

**Cause**: a store/singleton/composable that internally calls a **context-dependent API** (i18n, `inject`, a lifecycle hook, a DI scope) must have its **first** instantiation happen inside a synchronous component-setup context. If the first touch comes from an **async or watcher/effect callback**, the context API throws, and a partial instance is cached and then reused everywhere.

**Fix**: for circular or lazily-created singletons, **eagerly instantiate at the top of the parent's synchronous setup**, before any async/effect path can touch it first.

```typescript
// ✅ force first-init in setup context
const siteStore = useSiteStore() // eager, at setup top — NOT first-touched inside a watcher/computed later
```

**Invariant**: the first instantiation of any context-scoped singleton (uses i18n / inject / hooks) must occur in a synchronous setup context. **Generalizes to**: Vue `useI18n`/`inject`, Angular DI scopes, React context-reading singletons, any framework with a "must run during render/setup" rule.

## 3. Deserialization-layer caps surface as opaque parse errors → chunk to the cap

**Symptom**: a bulk request fails with a confusing low-level error ("cannot construct instance of …", a serializer/Jackson/zod error) that does **not** name the real problem. The backend enforces a **cap** (e.g. max N IDs per batch) in the request DTO's constructor/validation, so it throws during **deserialization** — before any controller logic — and the client sees an opaque message, sometimes even mislabeled by an unrelated layer.

**Fix**: chunk bulk requests to the documented cap and merge results. Record the cap in project-profile `api-layer.md` so every bulk-search caller respects it. **Generalizes to**: any request DTO with size/length validation in its constructor (Jackson, class-validator, zod `.max()`), GraphQL batch limits, URL-length caps on GET.

## 4. LSP / editor diagnostics go stale mid-edit

Editor diagnostics reflect a prior edit state and emit false positives mid-edit (notably the false cascades in trap #1). The standalone compiler run is the authority — re-run it before asserting a diagnosis. (See verification-loop §"Vacuity guard" / §"Baseline & Net-New".)

---

**How to use these**: when the symptom matches, suspect the structural cause BEFORE rewriting logic. Each of these is a near-zero-runtime-change fix (a type annotation, an init-order change, a chunking loop) that resolves what looks like a deep logic bug.
