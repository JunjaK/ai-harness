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
- Audit: `[audit command]`
```

---

## 2. `structure.md` — File Structure

**Scan:**
- Top-level directories (`src/`, `app/`, `pages/`, `components/`)
- Page/route organization pattern
- Module organization (`_modules/`, `lib/`, `utils/`)
- Config file locations

**Template:**
```markdown
# Project Structure

## Directory Layout
[actual tree output, depth 3, key directories only]

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

## Generated Code (if any)
- Generator: [openapi-generator / orval / ...]
- Models location: [path]
- API composables/hooks: [path]
- Editable: [which are safe to edit]

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
