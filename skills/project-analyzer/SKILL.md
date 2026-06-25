---
name: project-analyzer
description: "Analyze project structure, conventions, and patterns to generate a project profile. Use when /team-init is invoked or when team agents need to understand the codebase. Scans package.json, config files, source code patterns, and test setup to produce structured profiles in .claude/project-profile/."
---

# Project Analyzer

Scan the codebase and generate a structured project profile. Team workflow agents reference this profile to follow project conventions.

## Output Location

```
.claude/project-profile/
├── index.md              # Summary — always loaded by agents
├── stack.md              # Tech stack, dependencies, build
├── structure.md          # File/directory conventions
├── code-style.md         # Naming, imports, formatting
├── api-layer.md          # API patterns, type generation
├── state-management.md   # Store patterns, reactivity
├── testing.md            # Test framework, patterns
├── ui-components.md      # Component library, design system
└── deployment.md         # Build, CI/CD, env management
```

## Workflow (MUST execute in order)

Templates for every file below live in `resources/profile-templates.md`. Read that file before filling any profile.

### Step 1: Detect Tech Stack → `stack.md`
Follow template §1. Detect package manager via lockfile priority (bun.lockb → pnpm-lock.yaml → package-lock.json → default Bun).

### Step 2: Analyze File Structure → `structure.md`
Follow template §2. Capture directory layout, routing pattern, module organization, naming conventions.

### Step 3: Detect Code Style → `code-style.md`
Follow template §3. Read 5-10 source files to identify patterns. Skip if no consistent pattern emerges and mark N/A. *(Seeded Mode: on a scaffold with <5 source files, derive style from the CLI's formatter config (eslint/prettier/biome) and mark provisional.)*

### Step 4: Analyze API Layer → `api-layer.md`
Follow template §4. Skip for projects without API integration and mark ⏭️ Skipped in index.md. *(Seeded Mode: do NOT skip — inject the stack-decision doc's planned client/contract and mark `🌱 Seeded`. See Seeded Mode.)*

### Step 5: Analyze State Management → `state-management.md`
Follow template §5. Skip for projects without state library and mark ⏭️ Skipped. *(Seeded Mode: do NOT skip — inject the planned state library + store patterns and mark `🌱 Seeded`. See Seeded Mode.)*

### Step 6: Analyze Testing → `testing.md`
Follow template §6. Default framework expectation: Vitest 4.x for unit, Playwright for E2E.

Also derive the **Agentic Testing Adapter** (template §6 block):
- Surface: `web` if a browser UI (React/Vue/Svelte/Angular/Next…); `backend` if API-only (Spring/Express/FastAPI…); `mobile` if Flutter/React-Native.
- Driver / Emitter house-style / Concurrency / spec dir: fill per the Adapter table in the `agentic-testing` skill.
- If Surface=mobile and no mobile driver (maestro/Patrol/mobile-MCP) is detectable, set `Driver: UNAVAILABLE` and note it.

### Step 7: Analyze UI Components → `ui-components.md`
Follow template §7. Skip for backend-only projects.

### Step 8: Analyze Deployment → `deployment.md`
Follow template §8. Skip if no CI/CD found.

### Step 9: Generate Index → `index.md`
Follow template §9. MUST include relevance + status for every profile file. Record `Profile-Generated-At: <git rev-parse --short HEAD>` so staleness can be detected later (`/team-init --update`).

### Step 10: Bootstrap document buckets (if absent)
Follow template §10. Establish the three document buckets alongside `_docs/`:
- `_note/README.md` — only if `_note/` does not exist. MUST NOT create any other file under `_note/`, and MUST NOT modify an existing `_note/` (agent read-only).
- `.claude/wiki/{index.md, log.md, schema.md}` — only the files that are absent (empty catalog / empty chronicle / conventions stub).

Never overwrite an existing file. On `--update`, re-run this step but only create what is missing.

## Seeded Mode (greenfield — G5 of `/team-new`)

Called by the `greenfield-bootstrap` skill (G5) on a freshly-scaffolded project. A bare official-CLI scaffold has no API/state code yet, so Steps 4 & 5 would normally mark `api-layer.md` and `state-management.md` as `⏭️ Skipped` — the OPPOSITE of what the first `/team-run` needs. Seeded Mode SCANS what exists and INJECTS the forward-looking decisions from the stack-decision doc.

**Trigger**: invoked with a path to the G2 **stack-decision doc** (`_docs/.../project-bootstrap-stack-decision.md`). Precondition: G4 scaffold + git first-commit already ran, so Step 9 `Profile-Generated-At` resolves to that SHA.

**Two passes:**
- **SCAN-fill** (real source on the scaffold): `stack.md` (baseline = absolute 0 for greenfield), `structure.md`, `code-style.md` (formatter-config fallback if <5 files), `testing.md` (frameworks + agentic adapter, table-derived), `ui-components.md` (only if a UI lib was scaffolded), `index.md`. `deployment.md` → `⏭️ Skipped` (no CI/CD in a scaffold) is correct.
- **INJECT-fill** (no scan source → from the decision doc), marked **`🌱 Seeded`**:
  - `api-layer.md` — planned client + generated-vs-manual + generator/regen command + spec source + auth posture + base-URL env. *(The single most valuable injected doc — Architect-BE and Designers read it on the first `/team-run`.)*
  - `state-management.md` — planned library + intended store-scope patterns.

**INPUT CONTRACT** — the stack-decision doc MUST carry: chosen framework + package manager; planned API client (generated-vs-manual, generator, regen command, auth, base-URL env); planned state library + store patterns; planned UI lib; planned test stack. *(Same contract the greenfield-bootstrap G2 step produces.)*

**Provenance**: every `🌱 Seeded` doc gets the line `> Source: injected from <stack-decision path>, not yet observed in code — re-verify on /team-init --update`. The next `--update` re-scans seeded docs against now-real code and upgrades `🌱 → ✅`.

Seeded Mode is purely additive override rules; the skill never hard-errors on an empty tree.

## Update Mode (`/team-init --update`)

1. Read existing `index.md` to get current state
2. Scan for changes (new dependencies, new directories, config changes)
3. Only rewrite files that have changed
4. Update `Last updated: [timestamp]` in `index.md`
5. Append changelog entry:
   ```markdown
   ## Changelog
   - [date]: [what changed]
   ```

## How Agents Use the Profile

### Loading Strategy (progressive)

1. **Always load**: `index.md` (summary + key conventions)
2. **Load on demand** based on agent role:

| Agent | Files to load |
|-------|--------------|
| Leader | `index.md` + `structure.md` |
| Architect FE | `structure.md` + `code-style.md` + `ui-components.md` + `state-management.md` |
| Architect BE | `api-layer.md` + `structure.md` |
| Architect Infra | `deployment.md` + `api-layer.md` |
| UI/UX Master | `ui-components.md` + `code-style.md` |
| Designer | `code-style.md` + `state-management.md` + `testing.md` |
| Tester | `testing.md` + `structure.md` |

### Profile Files Are Best-Practice Defaults

The 8 profile files represent a best-practice template. Not every project has all sections:
- Pure frontend SPA may skip `deployment.md`
- Utility library may skip `ui-components.md` + `state-management.md`
- Backend-only project may skip `ui-components.md`

Mark skipped files in `index.md` as `⏭️ Skipped (reason)`. Do not assume skipped files exist.

Status tokens (index.md): `✅` scanned-from-code · `⏭️ Skipped (reason)` not applicable · `🌱 Seeded` planned-and-injected-from-stack-decision-doc, not yet in code (greenfield Seeded Mode; upgrades to `✅` on the next `--update` re-scan).

### Adaptation Rules (agents MUST)

- Read `index.md` first (ONLY required file)
- Load additional profile files on-demand based on `index.md` relevance column
- Skip files marked as `⏭️ Skipped`
- Use the project's patterns (imports, naming, API calls, stores, tests, UI)
- If a profile file does not exist, fall back to general best practices
