---
name: contract-sync
description: "Regenerate and re-verify a code-generated API client after any backend/server contract change, BEFORE writing or verifying client code against it. Use whenever a task changes a backend DB schema, request/response DTO, enum, or endpoint shape in a project where the frontend consumes a generated client/types (OpenAPI, GraphQL codegen, gRPC, tRPC, etc.). Trigger this even if the user only says 'I changed the API' or 'update the frontend to match' — the regenerate→typecheck gate is what prevents silent type/runtime desync. Run it at the BE→FE handoff in team workflows, before verification-loop Phase 2, and any time someone reports 'I changed the backend but the frontend doesn't match.'"
---

# Contract Sync

Keep a generated API client in lockstep with the backend contract it was generated from. The failure this prevents: a backend changes a field, an enum, or a nullability, but the frontend keeps compiling against **stale generated types** — so the mismatch surfaces as a runtime error in production instead of a type error at build time.

The fix is a strict, ordered gate: **make the spec current → regenerate the client → isolate the real change → type-check against the new types → cross-check consumption sites.** Skipping any step reintroduces drift.

## When This Applies (and when it does not)

Applies when ALL hold:
- The project has a **code-generated** API client/types (detect from project-profile `api-layer.md` → "Generated Code"). Generators include openapi-generator, orval, swagger-typescript-api, GraphQL Code Generator, tRPC, protobuf/gRPC, Prisma client, etc.
- The current task changed the **server-side contract**: a DB schema/migration that flows into a response, a request/response DTO, an enum, a status code shape, or an endpoint signature.

Does NOT apply (skip, state why):
- No codegen — the client is hand-written. Then the contract is verified by the cross-boundary review in `team-architect-fe`/`team-architect-be` cross-review, not by regeneration.
- The change is backend-internal (refactor, logging, a private helper) and provably does not alter any served shape.

## The Sync Procedure (execute in order — order is load-bearing)

### Step 0 — Read the setup
From `.claude/project-profile/api-layer.md` collect: the **regen command**, the **spec source** (a live server endpoint, e.g. `/v3/api-docs`, or a committed schema file), the list of **hand-maintained files inside the generated tree** (overrides the generator must not clobber), and any **post-regen fixups**. If `api-layer.md` does not record these, that is itself a gap — record them now (see project-analyzer `api-layer.md` template) so the next sync is deterministic.

### Step 1 — Make the spec current BEFORE regenerating
The generator reads a spec; if the spec is stale, you regenerate stale types. So first ensure the spec reflects the change:
- If the change includes a **DB migration**, apply it (locally) first — response shapes often derive from the schema.
- If the spec is served by a **running backend**, rebuild/restart it so the served spec is current. A hot-reload server may serve a half-applied spec mid-edit — restart it, don't trust the watcher.
- If the spec is a **committed file**, regenerate/export that file from the backend before the client step.

> Why first: regenerating against a stale spec produces a client that type-checks green yet is wrong — the most expensive failure mode, because nothing flags it.

### Step 2 — Regenerate the client
Run the regen command from the profile (translate package manager to the project's: Bun → pnpm/npm per lockfile). Do not hand-edit generated files to "match" the backend — the backend is the single source of truth; the generator is how the client learns it.

### Step 3 — Isolate the real change from churn
A regen can rewrite many files with formatting noise and can **strip hand-maintained files** that live inside the generated tree. Separate signal from noise:
- Find the **genuine content change**: stage the regen output and read the diff with your VCS's whitespace/EOL-insensitive view, so reformatting noise doesn't masquerade as a real change.
- If a hand-maintained override (from Step 0's list) shows a **deletions-only** diff, the generator stripped it — restore it from the last commit rather than re-authoring, UNLESS the backend change genuinely requires updating that override (then merge by hand).
- Re-apply any recorded **post-regen fixups** (a deterministic post-process step is better than a manual edit that silently reverts — keep fixups idempotent and in the generation chain).

### Step 4 — Type-check against the new types (authoritative command only)
Run the project's **authoritative** type-check (from project-profile `stack.md` → "Build & Verify", not a convenience alias — a `typecheck` script can be vacuous; see verification-loop §"Vacuity guard"). Judge results as **net-new vs the recorded baseline**, not absolute zero (see verification-loop §"Baseline & Net-New").

New type errors here are the gate working: they are the exact places the client consumed the old contract. Fix them by updating the consumption, or — if a type error reveals the **backend** changed something it should not have — fix it at the source. Never silence with `as any`/`@ts-ignore`; a contract type error often flags a real runtime mismatch.

### Step 5 — Cross-check consumption sites (shape, not existence)
A green type-check proves the new types are internally consistent; it does not prove the **runtime shape** matches. For each endpoint touched, verify at the actual call site:
- field **names** and **nullability** match the new contract (optional vs required),
- nested access paths resolve (`resp.data.items[].field`, not a guessed path),
- enums map **1:1** (no client-side enum that drifted from the server set),
- pagination/error envelopes are the ones the client expects.

Confirming a symbol merely *exists* is insufficient — verify the shape end to end.

## Output (REQUIRED)

```markdown
# Contract Sync Report
**Spec source**: [endpoint or file]   **Regen command**: [command]
**Spec made current via**: [migration applied / server restarted / spec re-exported / N/A]

## Real changes (after churn isolation)
| Generated file | Change | Notes |
|----------------|--------|-------|
| ... | fields added/removed/retyped | ... |

## Overrides restored
- [file]: [restored from HEAD / hand-merged because backend changed it] — or "None"

## Type-check (authoritative command)
- Command: [the real command, e.g. vue-tsc -p .nuxt/tsconfig.app.json]
- Net-new errors vs baseline: [N]  (baseline: [B])
- Resolved by: [updated consumption sites / fixed at backend source]

## Consumption sites verified
- [endpoint]: shape OK (names/nullability/nested/enum) — or [mismatch + fix]

## Gate: GREEN (client matches contract) / BLOCKED ([what is still mismatched])
```

## Team Workflow Integration

- **BE→FE handoff (Phase 1 → Phase 3)**: when Architect B's plan changed the contract and the client is generated, run contract-sync **before** FE Designers implement against it. Designers consuming stale types is a guaranteed escalation.
- **Before verification-loop Phase 2**: contract-sync is Phase 0 of verification when the change touched the contract — type-checking before regenerating verifies the wrong types.
- **On the report "BE changed but FE doesn't match"**: this is the entry point — start at Step 1.

## Invariant

The backend owns types/models/enums; the client **consumes** generated types and only **extends** them (interface-extends / Omit) for UI-only fields. Never hand-redefine a domain type to dodge a type error, and never edit generated output to match — fix the contract at the source and regenerate. (CLAUDE.md §"Cross-Boundary Contracts".)
