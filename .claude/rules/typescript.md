---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/tsconfig*.json"
---

# TypeScript — type-check gate · code intelligence · cross-boundary contracts

Loads when TS files are read. The non-TS fallback and the routing pointer live always-on in `CLAUDE.md`.

## Type check (hard gate)
- **Authoritative, non-vacuous command**: use project-profile `stack.md` → "Build & Verify" (the one that actually compiles app sources). A solution-style root `tsconfig.json` (`"files": []`) makes `bunx tsc --noEmit` a no-op that always exits 0; a typed-framework wrapper (`vue-tsc`, `astro check`) may catch what bare `tsc` misses. Confirm the command is not vacuous before trusting green.
- `tsconfig.json` MUST set `"strict": true` and `"noUncheckedIndexedAccess": true`.
- **Zero net-new type errors vs the recorded baseline** before any phase completes. Greenfield = absolute zero; legacy = net-new 0 (compare by error signature with `file:line:col` stripped, per file). See `reference/verification-loop.md`.
- **Do not mask a type error that flags a real bug.** `as any`/`@ts-ignore` to clear red can hide a runtime defect — the test for "safe to ignore" is "runtime stays correct," not "red is gone."
- `any` is prohibited outright. `unknown` is a **last resort**, not the default remedy — use it only where the model is outside your control (third-party library types, external API shapes) and no concrete type exists, and narrow it at the boundary immediately. Everywhere else: an explicit concrete type.

## Code intelligence (LSP)
- LSP is for navigation during implementation/debugging, NOT a `tsc` replacement. **Designers MUST run `findReferences` before changing any exported function's signature** (else callers break silently). Details in `debug` skill.
- If `mcp__ide__getDiagnostics` is available it MAY complement `tsc` during implementation but does NOT replace the final `tsc --noEmit` gate.

## Cross-boundary contracts (generated clients)
When the client consumes a **code-generated** API client/types (OpenAPI, GraphQL codegen, gRPC, tRPC, Prisma — detect from `api-layer.md`):
- **Backend is the single source of truth.** Consume generated types and only **extend** them (interface-extends / `Omit`) for UI-only fields. MUST NOT hand-redefine a domain type to dodge an error, and MUST NOT edit generated output to "match" the backend.
- **Regenerate before you verify.** Any change to a server contract (schema→response, DTO, enum, endpoint shape) MUST run the `contract-sync` skill BEFORE writing or verifying client code — type-checking against a stale generated client passes while being wrong.
- **Verify shape, not existence.** Confirm field names, nullability, nested paths, and 1:1 enum mapping at the call sites. In team workflows this gate runs at the **BE→FE handoff**.
