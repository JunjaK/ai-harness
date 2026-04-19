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
Follow template §3. Read 5-10 source files to identify patterns. Skip if no consistent pattern emerges and mark N/A.

### Step 4: Analyze API Layer → `api-layer.md`
Follow template §4. Skip for projects without API integration and mark ⏭️ Skipped in index.md.

### Step 5: Analyze State Management → `state-management.md`
Follow template §5. Skip for projects without state library and mark ⏭️ Skipped.

### Step 6: Analyze Testing → `testing.md`
Follow template §6. Default framework expectation: Vitest 4.x for unit, Playwright for E2E.

### Step 7: Analyze UI Components → `ui-components.md`
Follow template §7. Skip for backend-only projects.

### Step 8: Analyze Deployment → `deployment.md`
Follow template §8. Skip if no CI/CD found.

### Step 9: Generate Index → `index.md`
Follow template §9. MUST include relevance + status for every profile file.

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

### Adaptation Rules (agents MUST)

- Read `index.md` first (ONLY required file)
- Load additional profile files on-demand based on `index.md` relevance column
- Skip files marked as `⏭️ Skipped`
- Use the project's patterns (imports, naming, API calls, stores, tests, UI)
- If a profile file does not exist, fall back to general best practices
