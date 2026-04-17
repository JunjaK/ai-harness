---
name: debug
description: "LSP-driven debugging patterns for TypeScript codebases. Complements the general debugging methodology in superpowers:systematic-debugging. Use in Phase 3-4 escalation scenarios or when investigating unexpected behavior."
---

# Debug (LSP Patterns)

This skill covers **LSP-accelerated debugging patterns** specific to this harness. For the full systematic debugging methodology (reproduce → narrow → hypothesize → test), use `superpowers:systematic-debugging`.

## When to Use This Skill

- Investigating TypeScript-specific errors (type mismatches, undefined access, stale refactor artifacts)
- Tracing call paths in unfamiliar code before proposing fixes
- Verifying refactors did not leave orphaned callers

## Workflow (MUST execute in order)

1. **Reproduce** — Use `superpowers:systematic-debugging` for the reproduction step
2. **Locate** — Use LSP to find the failing symbol's definition and callers
3. **Inspect types** — Use `hover` to check inferred types against assumptions
4. **Trace call paths** — Use `incomingCalls` / `outgoingCalls` to map the flow
5. **Propose fix** — Minimal, targeted, with file:line reference
6. **Verify** — Run `bunx tsc --noEmit` + project test command; confirm no regression

## LSP Investigation Patterns

| Symptom | First LSP operation | Second (if needed) |
|---------|--------------------|--------------------|
| `X is not a function` | `goToDefinition` on X — is it exported? | `findReferences` — is everyone importing the same symbol? |
| `Cannot read property Y of undefined` | `hover` on the object — what's the inferred type? | `goToDefinition` on the type — does it declare Y? |
| Type mismatch after refactor | `findReferences` on the changed type | `goToImplementation` on interfaces — any implementer missed? |
| Downstream code broken unexpectedly | `incomingCalls` on the changed function | Check each caller manually |
| Stale cache / wrong data | `findReferences` on store/query key | Confirm every call site uses the same key |
| Unfamiliar function signature | `hover` for signature | `documentSymbol` for neighboring helpers |

## Root Cause Rules

- Fix the root cause, not the symptom (duplicate from `superpowers:systematic-debugging`)
- After any type-related fix, MUST run `bunx tsc --noEmit` before declaring the fix complete
- After any refactor, MUST use `findReferences` to confirm no orphaned callers

## Escalation (when to stop debugging)

- Cannot reproduce after 3 attempts → request reproduction steps
- Root cause spans 3+ modules → request architectural review (Phase 1)
- Fix requires API/backend changes not in plan → escalate to Team Leader
- Bug is timing-dependent → add logging, do not guess

For non-TypeScript investigation patterns, fall back to `superpowers:systematic-debugging`.
