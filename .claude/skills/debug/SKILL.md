---
name: debug
description: "Structured debugging workflow for codebase issues. Use when debugging bugs, errors, sync issues, or unexpected behavior. Covers context gathering, root cause analysis, targeted fixes, and verification. Useful in Phase 3-4 escalation scenarios."
---

# Debug Skill

## Workflow (MUST execute in order)

1. **Gather Context** — Get exact symptoms (error message, reproduction steps, environment)
2. **Read Completely** — Read every file in the suspected call path before suggesting changes
3. **Use LSP for Code Intelligence** (TypeScript/supported languages):
   - `hover` on suspicious variables to see inferred types
   - `goToDefinition` on unfamiliar symbols
   - `findReferences` on the failing function to see all call sites
   - `incomingCalls` to trace the call path upward
   - `outgoingCalls` to see what the failing function invokes
4. **Analyze Root Cause** — Check trigger logic, validation, types, side effects
5. **Propose Fix** — Minimal, targeted fix with file:line references and the reason
6. **Verify** — Run tests; run `bunx tsc --noEmit` to confirm no type regression

## LSP Investigation Patterns

| Symptom | First LSP operation |
|---------|--------------------|
| "X is not a function" | `goToDefinition` on X — is it actually exported? |
| "Cannot read property Y of undefined" | `hover` on the object — what's the inferred type? |
| Type mismatch after refactor | `findReferences` on the changed type — any missed updates? |
| Unexpected behavior in downstream code | `incomingCalls` on the function called in the error path |
| Stale cache / wrong data | `findReferences` on the store/query key — all call sites consistent? |

## Common Debug Patterns

### State Management Issues

| Symptom | Common Cause | Fix |
|---------|-------------|-----|
| `ReferenceError: X is not defined` | Self-reference in store definition | Use local variable directly |
| Property is `undefined` | Not in store's `return` statement | Add to return |
| `Maximum call stack exceeded` | Circular dependency | Extract shared state |
| Computed doesn't update | Non-reactive access | Check reactivity rules |

### API Issues

| Symptom | Common Cause | Fix |
|---------|-------------|-----|
| API not called | Missing `execute()` or wrong trigger | Verify call site |
| Stale data after mutation | Not re-fetching after write | Call fetch after mutation |
| Type mismatch on response | Assumed response structure | Read actual API types |
| 401 loop | Token refresh failing | Check auth middleware |
| Params not reactive | Plain object instead of reactive | Wrap in computed/reactive |

### UI Issues

| Symptom | Common Cause | Fix |
|---------|-------------|-----|
| Component not rendering | Wrong import path | Verify file exists at path |
| Modal not opening | Model binding not wired | Check v-model/props |
| i18n key showing raw | Key missing from locale | Add translation |
| Route not matching | Wrong nesting or exclusion | Check router config |

### Performance Issues

| Symptom | Common Cause | Fix |
|---------|-------------|-----|
| Slow rendering | Creating functions in render loop | Hoist functions |
| UI lag on input | Deep watchers on large objects | Use shallow ref + targeted updates |
| Memory growing | Event listeners not cleaned | Add cleanup in unmount |

## Root Cause Analysis Framework

```
1. Reproduce the bug reliably
2. Narrow down: which file/function?
3. Check inputs: are they what you expect?
4. Check outputs: where does it diverge?
5. Binary search: comment out half the code
6. Fix the root cause, not the symptom
```

## Escalation Criteria

When to stop debugging and ask for help:
- Can't reproduce after 3 attempts → ask for reproduction steps
- Root cause spans 3+ modules → may need architectural review
- Fix requires API/backend changes → escalate to relevant team
- Bug is intermittent/timing-dependent → need logging/tracing
