# Project Profile Templates

Detailed templates for each of the 9 profile files. The main `SKILL.md` references this document when filling in each profile.

---

## 1. `stack.md` — Tech Stack

**Scan:**
- `package.json` / `requirements.txt` / `Cargo.toml` / `go.mod` / `build.gradle`
- `tsconfig.json` / `jsconfig.json`
- Framework configs: `nuxt.config.*`, `next.config.*`, `vite.config.*`, `angular.json`
- `.nvmrc` / `.node-version` / `.tool-versions` / `.mise.toml`
- **Package manager lockfile** (detect in priority):
  - `bun.lockb` / `bun.lock` → **Bun** (default)
  - `pnpm-lock.yaml` → **pnpm**
  - `package-lock.json` → **npm**
  - `yarn.lock` → yarn (legacy — document + migration path)
  - No lockfile → default to **Bun**
- `packageManager` field in `package.json` (overrides lockfile detection)

**Template:**
```markdown
# Tech Stack

## Runtime
- Language: [TypeScript/JavaScript/Python/Go/Rust/...]
- Runtime: [Node 22 / Bun / Deno / Python 3.12 / ...]
- Package manager: [Bun / pnpm / npm / yarn / pip / cargo / ...]
- Detection: [lockfile found OR defaulted to Bun]

## Framework
- Framework: [Nuxt 4 / Next.js 15 / Django / Spring Boot / ...]
- UI library: [shadcn/ui / Naive UI / Material UI / ...]
- CSS: [Tailwind / UnoCSS / SCSS / styled-components / ...]

## Key Dependencies
| Package | Version | Purpose |
|---------|---------|---------|

## Build (use detected package manager)
- Dev: `[e.g., bun run dev]`
- Build: `[build command]`
- Test: `[test command]`
- Install: `[install command]`
- Worktree deps fast-path: `[fresh-worktree provisioning + family. A·copy-based (node_modules) — pnpm: `pnpm install --frozen-lockfile --prefer-offline`, bun: `bun install --frozen-lockfile` (store↔worktree must be same-filesystem or it copies). B·reference-cache (deps stay in a global cache, nothing copied) — Flutter: `fvm flutter pub get`, Gradle: `./gradlew <task>`. Other managers: the Context7-resolved recipe. Consumed by `/worktree-deps` + `parallelization`.]`
- Audit: `[audit command]`

## Build & Verify — AUTHORITATIVE commands (verify these are NOT vacuous)
> Every gate and agent uses THESE, never a convenience alias. A `typecheck`/`lint` npm script
> can check nothing (e.g. a solution-style root `tsconfig.json` with `"files": []` makes
> `tsc --noEmit` a no-op that always exits 0). Run each once and confirm it actually exercises
> the code (type-check compiles real sources; test run collects > 0 tests; lint scans > 0 files).
- Type-check (authoritative): `[e.g. tsc --noEmit -p tsconfig.app.json | vue-tsc -p .nuxt/tsconfig.app.json | pyright]`
  - Vacuity-checked: [yes — confirmed it reports errors on real sources / N/A]
  - Pre-existing error baseline: [count, or 0 for greenfield] — gate on net-new vs this
- Lint (authoritative): `[e.g. eslint . | biome check .]` — baseline: [count]
- Test (authoritative): `[e.g. vitest run]` — confirmed collects [N] tests
```

---

## 2. `structure.md` — File Structure

**Scan:**
- Top-level directories (`src/`, `app/`, `pages/`, `components/`)
- Page/route organization pattern
- Module organization (`_modules/`, `lib/`, `utils/`)
- Config file locations
- **Submodules** — if `.gitmodules` exists, run `git submodule status`; record each submodule path + inferred role (FE/BE/shared/…) and whether the superproject is a thin **docs + submodule-pointers shell** (real code lives in submodules). Also record, per code submodule, the **worktree carry-list** — the gitignored runtime files (`.env*`, framework-local config, secrets; detect via `git -C <sub> ls-files --others --ignored --exclude-standard`) a clean worktree checkout would lack — and the **carry-exclude** heavy regenerable dirs. This block is what the `submodule-worktree` skill consumes.

**Template:**
```markdown
# Project Structure

## Directory Layout
[actual tree output, depth 3, key directories only]

## Submodule Layout (only if `.gitmodules` present; omit section otherwise)
- Submodule-monorepo: [yes / no]
- Superproject role: [docs + submodule pointers shell / holds code too]
- Code submodules (worktree targets for `submodule-worktree`):
  - `[path]` → [FE / BE / shared / …]
  - `[path]` → [FE / BE / shared / …]
- Worktree carry-list (gitignored runtime files to copy into each new worktree — env/secrets/local config that a clean checkout lacks): [per submodule: e.g. `.env`, `.env.local`, `application-local.yml`, `local.properties`, service-account JSON; "all gitignored except deps/build" if unclear]
- Worktree carry EXCLUDE (regenerable — reinstall, don't copy): [node_modules, .gradle, build/, target/, .next/, … + any project-specific heavy gitignored dir]
- Notes: [nested submodules? submodules pinned detached? default integration branch per submodule if known]

## Routing Pattern
- Type: [file-based / config-based / code-based]
- Pages location: [path]
- Dynamic routes: [pattern, e.g., [id], :id, <slug>]
- Special directories: [excluded from routing]

## Module Organization
- Page logic: [where]
- Shared components: [where]
- Utilities: [where]
- Types: [where]

## Naming Conventions
- Files: [kebab-case / camelCase / PascalCase]
- Components: [PascalCase.vue / kebab-case.tsx]
- Stores: [_store.ts / store.ts / use-xxx-store.ts]
- Tests: [*.test.ts / *.spec.ts / __tests__/]
```

---

## 3. `code-style.md` — Code Style

**Scan:**
- ESLint / Prettier / Biome / Ruff config files
- 5-10 source file samples for patterns
- Import style (alias paths, relative paths)

**Template:**
```markdown
# Code Style

## Formatting
- Tool: [ESLint + Prettier / Biome / IDE-only]
- Semicolons: [yes/no]
- Quotes: [single/double]
- Indent: [2 spaces / 4 spaces / tabs]

## Import Patterns
- Alias: [~/... / @/... / none]
- Style: [named imports / default / barrel exports]
- Ordering: [auto-sorted / manual / grouped]

## Naming
- Variables: [camelCase]
- Functions: [camelCase]
- Types/Interfaces: [PascalCase]
- Constants: [SCREAMING_SNAKE / camelCase]
- Files: [kebab-case / camelCase]

## Code Ordering (if consistent pattern found)
[Document the pattern]
```

---

## 4. `api-layer.md` — API Layer

**Scan:**
- API client setup (axios, fetch, $fetch, generated clients)
- API type definitions (Swagger/OpenAPI generated, manual)
- Request/response interceptors
- Auth middleware

**Template:**
```markdown
# API Layer

## Client
- Type: [generated / manual / framework built-in]
- Base client: [axios / fetch / $fetch / ky]
- Base URL config: [env variable name]

## Generated Code (if any) — REQUIRED for the contract-sync gate
- Generator: [openapi-generator / orval / swagger-typescript-api / GraphQL Code Generator / tRPC / protobuf / Prisma / ...]
- Models location: [path]
- API composables/hooks: [path]
- **Spec source**: [live endpoint e.g. `/v3/api-docs` (requires running backend) OR committed schema file path]
- **Regen command**: [exact command to regenerate the client, e.g. `pnpm api:gen:all`]
- **Hand-maintained overrides inside the generated tree**: [files the generator must NOT clobber — list paths, or "None". These get stripped on every regen and need restore.]
- **Post-regen fixups**: [any deterministic post-process step that patches generator output, e.g. a brand-type/discriminated-union workaround — or "None". Keep these idempotent and in the generation chain, not as manual edits.]
- Editable: [which generated files are safe to hand-edit — usually "none; backend is source of truth"]

## Request Patterns
[Actual pattern from codebase]

## Auth
- Token storage: [httpOnly cookie / localStorage / memory]
- Auth header: [Bearer / custom / cookie]
- Refresh: [interceptor / middleware / manual]

## Error Handling
[Interceptors, global handler, per-call pattern]
```

---

## 5. `state-management.md` — State Management

**Scan:**
- Store library (Pinia, Vuex, Redux, Zustand, Jotai)
- Store file patterns
- Reactivity patterns

**Template:**
```markdown
# State Management

## Library
- Name: [Pinia / Redux / Zustand / ...]
- Store types: [list distinct patterns]

## Store Patterns
### Pattern 1: [name]
- Scope: [page / app-wide]
- Lifecycle: [auto-disposed / persistent]
- File location: [pattern]
- Example: [reference file path]

## Reactivity Rules
[Framework-specific rules found]

## Cross-Store Dependencies
[Patterns and anti-patterns]
```

---

## 6. `testing.md` — Testing

**Scan:**
- Test config files (vitest.config, jest.config, playwright.config)
- Test directory structure
- Test file naming patterns
- Mock patterns

**Template:**
```markdown
# Testing

## Frameworks
| Type | Framework | Config | Location |
|------|-----------|--------|----------|
| Unit | [Vitest/Jest/...] | [config path] | [test dir] |
| Integration | [same/different] | [config path] | [test dir] |
| E2E | [Playwright/Cypress/...] | [config path] | [test dir] |

## Test Commands
- All: `[command]`
- Unit: `[command]`
- E2E: `[command]`
- Coverage: `[command]`

## Patterns
- File naming: [*.test.ts / *.spec.ts]
- Mock location: [__mocks__ / inline / fixtures/]
- Test data: [factories / fixtures / inline]

## Coverage
- Target: [percentage if configured]
- Report: [format and location]

## Agentic Testing Adapter
- Surface: <web | backend | mobile>
- Driver: <playwright-mcp | http | maestro | patrol | mobile-mcp | UNAVAILABLE>
- Emitter house-style: <e2e-testing | springboot-tdd + kotlin-testing | integration_test>
- Concurrency: <serial-shared-browser | parallel-stateless | serial-per-device>
- Generated spec dir: <tests/e2e/ | src/test/ | integration_test/>
```

---

## 7. `ui-components.md` — UI Components

**Scan:**
- Component library imports
- Icon usage patterns
- Design token files (CSS variables, theme config)
- Common component patterns

**Template:**
```markdown
# UI Components

## Component Library
- Name: [shadcn/ui / Naive UI / Material UI / custom]
- Import pattern: [auto-import / manual import]

## Icons
- Library: [lucide / heroicons / material-symbols / ...]
- Usage: [<Icon name="..." /> / SVG import]

## Design Tokens
- Colors: [CSS variables / Tailwind config / theme file]
- Spacing: [4px/8px increments]
- Typography: [font families, scale]

## Common Patterns
[Modal / form / list patterns — whatever is consistent]
```

---

## 8. `deployment.md` — Deployment

**Scan:**
- CI/CD files (`.github/workflows/`, `Jenkinsfile`)
- Docker files
- Environment config patterns
- Build output

**Template:**
```markdown
# Deployment

## CI/CD
- Platform: [GitHub Actions / GitLab CI / Jenkins]
- Workflows: [list with purpose]

## Environments
| Env | Branch | URL/Config |
|-----|--------|------------|
| Development | [branch] | [info] |
| Staging | [branch] | [info] |
| Production | [branch] | [info] |

## Environment Variables
- Access pattern: [useEnvManager() / process.env / import.meta.env]
- Config file: [.env / .env.local]

## Build Output
- Command: [build command]
- Output dir: [dist / .output / build]
- Type: [SSR / SSG / SPA]
```

---

## 9. `index.md` — Index

**Template:**
```markdown
# Project Profile

> Generated: [timestamp]
> Last updated: [timestamp]
> Profile-Generated-At: [current git HEAD short sha]

## Quick Summary
- **Stack**: [Framework] + [Language] + [UI Library]
- **Package manager**: [name]
- **Test framework**: [name]
- **State management**: [name]
- **API layer**: [generated/manual]
- **CI/CD**: [platform]

## Profile Files

Relevance: REQUIRED (always read) > HIGH (read if related) > MEDIUM (optional) > SKIPPED (not applicable)

Status tokens: `✅` scanned-from-code · `⏭️` Skipped (not applicable) · `🌱` Seeded (planned + injected from a stack-decision doc, not yet in code — greenfield `/team-new`; upgrades to `✅` on the next `--update`).

| File | Relevance | Status | Contents |
|------|-----------|--------|----------|
| [stack.md](./stack.md) | REQUIRED | ✅/⏭️ | Runtime, framework, dependencies, build |
| [structure.md](./structure.md) | REQUIRED | ✅/⏭️ | Directory layout, routing, naming |
| [code-style.md](./code-style.md) | HIGH | ✅/⏭️ | Formatting, imports, naming patterns |
| [api-layer.md](./api-layer.md) | HIGH | ✅/🌱/⏭️ | API client, auth, error handling |
| [state-management.md](./state-management.md) | MEDIUM | ✅/🌱/⏭️ | Store patterns, reactivity rules |
| [testing.md](./testing.md) | HIGH | ✅/⏭️ | Test frameworks, commands, patterns |
| [ui-components.md](./ui-components.md) | MEDIUM | ✅/⏭️ | Component library, icons, tokens |
| [deployment.md](./deployment.md) | MEDIUM | ✅/⏭️ | CI/CD, environments, build output |

## Key Conventions for Agents
[Top 5-10 conventions. Minimum context an agent needs to produce
 correct code. Extracted from detail files above.]

1. [convention]
2. [convention]

## Agent Loading Guide
- **All agents**: Read this `index.md` (REQUIRED)
- **Read additional files when**:
  - File relevance is REQUIRED or HIGH for your role
  - Your task touches that domain
  - File status is ✅ (not ⏭️ Skipped)
```

---

## 10. Document bucket scaffolds (bootstrap)

Created by Step 10 only when absent. Establishes the `_note/` (human) and `.claude/wiki/` (agent) buckets alongside `_docs/`. Never overwrite existing files. Never create files under `_note/` other than `README.md`, and never modify an existing `_note/` afterward (agent read-only).

**`_note/README.md`** (only if `_note/` does not exist):
```markdown
# _note/ — owner's personal notes (agent read-only)

This bucket is **yours**. The agent treats it as **read-only**: it reads `_note/` for
context but will NOT create, move, merge, reorganize, or delete anything here unless you
explicitly ask. Dump notes freely — no frontmatter, no lifecycle, no structure required.

- Owner: you (human). Tool-agnostic — lives at repo root, not under `.claude/`.
- Exempt from `_docs/` automation (lifecycle, status frontmatter, merge-on-completion).
- Keep one central `_note/` at the repo root; preserve provenance with subfolders (`_note/<source>/`).
- Graduation: when a note becomes project-canonical, you (not the agent) promote it `_note/ → _docs/`.

Governance detail: `skills/docs-lifecycle/SKILL.md` (Three-bucket section).
```

**`.claude/wiki/index.md`** (only if absent — empty catalog):
```markdown
# Wiki Index

Content catalog of the agent wiki. The `wiki` skill updates this on every ingest.
Query reads this first, then drills into pages.

## Entities
## Concepts
## Sources
```

**`.claude/wiki/log.md`** (only if absent — empty chronicle):
```markdown
# Wiki Log

Append-only. One entry per operation, consistent prefix so `grep "^## \[" log.md | tail` works.

<!-- ## [YYYY-MM-DD] ingest|query|lint | <title> -->
```

**`.claude/wiki/schema.md`** (only if absent — conventions stub, filled by the `wiki` skill):
```markdown
# Wiki Schema

How this wiki is structured and maintained (Karpathy "schema" layer). The `wiki` skill
reads this before ingest/query/lint.

## Conventions
- Pages link to the SSOT (code / `_docs/` / `_note/`); they route and synthesize, they do NOT duplicate facts.
- Page types: entity / concept / overview / comparison.
- `index.md` = catalog; `log.md` = chronicle.

## Maintenance
- Governed by `continuous-learning` §7 (Knowledge-Base Maintenance Contract): link-don't-duplicate, same-change-same-update, periodic self-audit.
```
