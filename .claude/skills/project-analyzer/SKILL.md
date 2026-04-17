---
name: project-analyzer
description: "Analyze project structure, conventions, and patterns to generate a project profile. Use when /team-init is invoked or when team agents need to understand the codebase. Scans package.json, config files, source code patterns, and test setup to produce structured profiles in .claude/project-profile/."
---

# Project Analyzer

Scan the codebase and generate a structured project profile that team workflow agents reference to follow project conventions.

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

## Analysis Process

### Step 1: Detect Tech Stack → `stack.md`

**Scan these files:**
- `package.json` / `requirements.txt` / `Cargo.toml` / `go.mod` / `build.gradle`
- `tsconfig.json` / `jsconfig.json`
- Framework configs: `nuxt.config.*`, `next.config.*`, `vite.config.*`, `angular.json`, etc.
- `.nvmrc` / `.node-version` / `.tool-versions` / `.mise.toml`
- **Package manager lockfile** (detect in this priority):
  - `bun.lockb` or `bun.lock` → **Bun** (default)
  - `pnpm-lock.yaml` → **pnpm**
  - `package-lock.json` → **npm**
  - `yarn.lock` → yarn (legacy — document but note migration path)
  - No lockfile → default to **Bun**
- `packageManager` field in `package.json` (overrides lockfile detection)

**Extract:**
```markdown
# Tech Stack

## Runtime
- Language: [TypeScript/JavaScript/Python/Go/Rust/...]
- Runtime: [Node 22 / Bun / Deno / Python 3.12 / ...]
- Package manager: [Bun / pnpm / npm / yarn / pip / cargo / ...]
- Package manager detection: [lockfile found: bun.lockb / pnpm-lock.yaml / package-lock.json / none — defaulted to Bun]

## Framework
- Framework: [Nuxt 4 / Next.js 15 / Django / Spring Boot / ...]
- UI library: [Naive UI / shadcn/ui / Material UI / ...]
- CSS: [UnoCSS / Tailwind / SCSS / styled-components / ...]

## Key Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| [name] | [version] | [what it does] |

## Build (use detected package manager)
- Dev: `[dev command — e.g., bun run dev / pnpm run dev / npm run dev]`
- Build: `[build command]`
- Test: `[test command]`
- Install: `[install command]`
- Audit: `[audit command]`
```

### Step 2: Analyze File Structure → `structure.md`

**Scan:**
- Top-level directories (`src/`, `app/`, `pages/`, `components/`, etc.)
- Page/route organization pattern
- Module organization (`_modules/`, `lib/`, `utils/`, etc.)
- Config file locations

**Extract:**
```markdown
# Project Structure

## Directory Layout
```
[actual tree output, depth 3, key directories only]
```

## Routing Pattern
- Type: [file-based / config-based / code-based]
- Pages location: [path]
- Dynamic routes: [pattern, e.g., [id], :id, <slug>]
- Special directories: [excluded from routing, e.g., _modules/]

## Module Organization
- Page logic: [where, e.g., pages/xxx/_modules/]
- Shared components: [where]
- Utilities: [where]
- Types: [where]

## Naming Conventions
- Files: [kebab-case / camelCase / PascalCase]
- Components: [PascalCase.vue / kebab-case.tsx / ...]
- Stores: [_store.ts / store.ts / use-xxx-store.ts]
- Tests: [*.test.ts / *.spec.ts / __tests__/]
```

### Step 3: Detect Code Style → `code-style.md`

**Scan:**
- ESLint / Prettier / Biome / Ruff config files
- Sample 5-10 source files for patterns
- Import style (alias paths, relative paths)

**Extract:**
```markdown
# Code Style

## Formatting
- Tool: [ESLint + Prettier / Biome / IDE-only / ...]
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
[Document the ordering pattern found in source files]
```

### Step 4: Analyze API Layer → `api-layer.md`

**Scan:**
- API client setup (axios, fetch, $fetch, generated clients)
- API type definitions (Swagger/OpenAPI generated, manual)
- Request/response interceptors
- Auth middleware

**Extract:**
```markdown
# API Layer

## Client
- Type: [generated from OpenAPI / manual / framework built-in]
- Base client: [axios / fetch / $fetch / ky / ...]
- Base URL config: [env variable name]

## Generated Code (if any)
- Generator: [openapi-generator / swagger-codegen / orval / ...]
- Models location: [path]
- API composables: [path]
- Editable: [yes/no — list which are safe to edit]

## Request Patterns
[How API calls are made — show actual pattern from codebase]

## Auth
- Token storage: [cookie / localStorage / memory]
- Auth header: [Bearer token / custom header / cookie-based]
- Refresh mechanism: [interceptor / middleware / manual]

## Error Handling
[How API errors are handled — interceptors, global handler, per-call]
```

### Step 5: Analyze State Management → `state-management.md`

**Scan:**
- Store library (Pinia, Vuex, Redux, Zustand, Jotai, etc.)
- Store file patterns
- Reactivity patterns

**Extract:**
```markdown
# State Management

## Library
- Name: [Pinia / Redux / Zustand / ...]
- Store types: [list distinct patterns, e.g., defineLocalStore, defineManualStore]

## Store Patterns
### Pattern 1: [name]
- Scope: [page / app-wide]
- Lifecycle: [auto-disposed / persistent]
- File location: [pattern]
- Example: [reference file path]

## Reactivity Rules
[Framework-specific reactivity rules found in codebase]

## Cross-Store Dependencies
[How stores reference each other — patterns and anti-patterns]
```

### Step 6: Analyze Testing → `testing.md`

**Scan:**
- Test config files (vitest.config, jest.config, playwright.config, etc.)
- Test directory structure
- Test file naming patterns
- Mock patterns

**Extract:**
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
```

### Step 7: Analyze UI Components → `ui-components.md`

**Scan:**
- Component library imports
- Icon usage patterns
- Design token files (CSS variables, theme config)
- Common component patterns

**Extract:**
```markdown
# UI Components

## Component Library
- Name: [Naive UI / shadcn/ui / Material UI / Ant Design / custom / ...]
- Import pattern: [auto-import / manual import]

## Icons
- Library: [material-symbols / lucide / heroicons / ...]
- Usage: [<Icon name="..." /> / <LucideIcon /> / SVG import]

## Design Tokens
- Colors: [CSS variables / Tailwind config / theme file]
- Spacing: [system, e.g., 4px/8px increments]
- Typography: [font families, scale]

## Common Patterns
[Modal pattern, form pattern, list pattern — whatever is consistent]
```

### Step 8: Analyze Deployment → `deployment.md`

**Scan:**
- CI/CD files (`.github/workflows/`, `Jenkinsfile`, etc.)
- Docker files
- Environment config patterns
- Build output

**Extract:**
```markdown
# Deployment

## CI/CD
- Platform: [GitHub Actions / GitLab CI / Jenkins / ...]
- Workflows: [list with purpose]

## Environments
| Env | Branch | URL/Config |
|-----|--------|------------|
| Development | [branch] | [info] |
| Staging | [branch] | [info] |
| Production | [branch] | [info] |

## Environment Variables
- Access pattern: [useEnvManager() / process.env / import.meta.env]
- Config file: [.env / .env.local / ...]

## Build Output
- Command: [build command]
- Output dir: [dist / .output / build / ...]
- Type: [SSR / SSG / SPA]
```

### Step 9: Generate Index → `index.md`

Compile a summary referencing all profile files:

```markdown
# Project Profile

> Generated: [timestamp]
> Last updated: [timestamp]

## Quick Summary
- **Stack**: [Framework] + [Language] + [UI Library]
- **Package manager**: [name]
- **Test framework**: [name]
- **State management**: [name]
- **API layer**: [generated/manual]
- **CI/CD**: [platform]

## Profile Files

Relevance: REQUIRED (always read) > HIGH (read if related) > MEDIUM (optional) > SKIPPED (not applicable)

| File | Relevance | Status | Contents |
|------|-----------|--------|----------|
| [stack.md](./stack.md) | REQUIRED | ✅/⏭️ | Runtime, framework, dependencies, build |
| [structure.md](./structure.md) | REQUIRED | ✅/⏭️ | Directory layout, routing, naming |
| [code-style.md](./code-style.md) | HIGH | ✅/⏭️ | Formatting, imports, naming patterns |
| [api-layer.md](./api-layer.md) | HIGH | ✅/⏭️ | API client, auth, error handling |
| [state-management.md](./state-management.md) | MEDIUM | ✅/⏭️ | Store patterns, reactivity rules |
| [testing.md](./testing.md) | HIGH | ✅/⏭️ | Test frameworks, commands, patterns |
| [ui-components.md](./ui-components.md) | MEDIUM | ✅/⏭️ | Component library, icons, tokens |
| [deployment.md](./deployment.md) | MEDIUM | ✅/⏭️ | CI/CD, environments, build output |

## Key Conventions for Agents
[Top 5-10 most important conventions that agents MUST follow.
 This section is the minimum context an agent needs to produce
 correct code for this project. Extracted from detail files above.]

1. [convention]
2. [convention]
...

## Agent Loading Guide
- **All agents**: Read this `index.md` (REQUIRED)
- **Read additional files only when**:
  - File relevance is REQUIRED or HIGH for your role
  - Your task touches that domain
  - File status is ✅ (not ⏭️ Skipped)
```

## Update Mode (`/team-init --update`)

When updating an existing profile:
1. Read existing `index.md` to get current state
2. Scan for changes (new dependencies, new directories, config changes)
3. Only rewrite files that have changed
4. Add `> Last updated: [timestamp]` to `index.md`
5. Append changelog entry:
```markdown
## Changelog
- [date]: [what changed]
```

## How Agents Use the Profile

### Loading Strategy (Progressive)
1. **Always load**: `index.md` (summary + key conventions)
2. **Load on demand**: specific profile files based on agent role:
   - Leader → `index.md` + `structure.md`
   - Architect FE → `structure.md` + `code-style.md` + `ui-components.md` + `state-management.md`
   - Architect BE → `api-layer.md` + `structure.md`
   - Architect Infra → `deployment.md` + `api-layer.md`
   - UI/UX Master → `ui-components.md` + `code-style.md`
   - Designer → `code-style.md` + `state-management.md` + `testing.md`
   - Tester → `testing.md` + `structure.md`

### Important: Profile Files Are Best-Practice Defaults

The 8 profile files (stack, structure, code-style, api-layer, state-management, testing, ui-components, deployment) represent a **best-practice template**. Not all projects will have all sections:

- A pure frontend SPA may have no `deployment.md`
- A utility library may skip `ui-components.md` and `state-management.md`
- A backend-only project may skip `ui-components.md`

During analysis, **only generate files that are relevant** to the project. Mark skipped files in `index.md`:

```markdown
## Profile Files
| File | Relevance | Status |
|------|-----------|--------|
| stack.md | REQUIRED | ✅ Generated |
| structure.md | REQUIRED | ✅ Generated |
| code-style.md | HIGH | ✅ Generated |
| api-layer.md | HIGH | ✅ Generated |
| state-management.md | MEDIUM | ⏭️ Skipped (no state library detected) |
| testing.md | HIGH | ✅ Generated |
| ui-components.md | LOW | ⏭️ Skipped (backend-only project) |
| deployment.md | MEDIUM | ✅ Generated |
```

### Adaptation Rules
Agents MUST:
- **Read `index.md` first** — this is the ONLY required file
- Load additional profile files **on-demand** based on `index.md` relevance column
- Skip files marked as "Skipped" — don't assume they should exist
- Use the project's patterns (imports, naming, API calls, stores, tests, UI)
- If a profile file doesn't exist, fall back to general best practices
