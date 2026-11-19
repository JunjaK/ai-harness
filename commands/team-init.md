---
description: "Team Init — 프로젝트 구조 분석 및 프로필 생성/갱신"
---

# Team Init — Project Analysis

Analyze the current project and generate a structured profile that all team agents reference.

## Usage

```
/team-init              # Full analysis (first run or regenerate)
/team-init --update     # Update changed sections only
```

## What It Does

1. **Load skill**: Invoke the `project-analyzer` skill
2. **Scan project** following the 10-step analysis process
3. **Generate profile** files in `.claude/project-profile/`
4. **Bootstrap document buckets** (if absent): `_workspace/README.md` (throwaway-layout SSOT) and `.claude/wiki/{index.md, log.md, schema.md}` (agent wiki), plus the profile's **Document buckets** table declaring this project's `_docs/` collections. Never overwrites existing files.
5. **Guardrails preset** (both modes, only when `.claude/project-profile/guardrails.json` is absent): ask once with `AskUserQuestion` — **default** (production branches deny commit/push/merge; stage/dev ask), **light** (production branches ask), **toy** (no rules; an explicit opt-out). Recommend `default` when the repo has a `main`/`master`/`prod*` branch, `toy` for a throwaway repo. State in the question that under `bypassPermissions` or `dontAsk` every `ask` becomes `deny`, because no prompt can be shown. Copy the chosen file from `${CLAUDE_PLUGIN_ROOT}/hooks/guardrails/presets/<name>.json` to `.claude/project-profile/guardrails.json`. Any existing `guardrails.json` is left untouched and nothing is asked.
6. **Report** what was found, any notable conventions, and the guardrails preset in effect

## Output

```
.claude/project-profile/
├── index.md              # Summary (always loaded by agents)
├── stack.md              # Tech stack, dependencies, build
├── verify.json           # Authoritative gates + baselines (verify skill)
├── structure.md          # File/directory conventions
├── code-style.md         # Naming, imports, formatting
├── api-layer.md          # API patterns, type generation
├── state-management.md   # Store patterns, reactivity
├── testing.md            # Test framework, patterns
├── ui-components.md      # Component library, design system
├── deployment.md         # Build, CI/CD, env management
└── guardrails.json       # Branch rules preset chosen in step 5 (only when it was absent)
```

Plus the document buckets (created only when absent):
```
_workspace/README.md      # throwaway-output layout (the only tracked file there)
.claude/wiki/
├── index.md              # agent wiki — content catalog
├── log.md                # agent wiki — chronological log
└── schema.md             # agent wiki — conventions
```

## Full Analysis Mode (default)

Scans everything from scratch. Use when:
- First time running in a project
- Major refactoring happened
- Want a clean regeneration

```
/team-init
```

## Update Mode

Only rescans and rewrites sections that changed. Use when:
- New dependencies added
- Small structural changes
- Periodic refresh

```
/team-init --update
```

Compares current codebase against existing profile, updates only changed files, appends to changelog in `index.md`.

### Staleness Detection (MUST)
On `--update`, before rescanning:
1. Read `Profile-Generated-At` from `index.md`. Compare to current `git rev-parse --short HEAD`.
2. If the profile is missing the "Agentic Testing Adapter" section (older profile), force a `testing.md` rescan.
3. Report drift: "Profile generated at `<old-sha>`, HEAD now `<new-sha>`". Regenerate changed sections and rewrite `Profile-Generated-At`.

## After Running

The profile is automatically used by team workflow commands:
- `/team`, `/team-run`, `/team-brainstorm` all reference `.claude/project-profile/index.md`
- Each agent loads relevant profile sections based on their role
- Agents adapt their output to match project conventions

## On Completion

```
✅ PROJECT PROFILE GENERATED
Location: .claude/project-profile/
Files: 9 profile documents

Summary:
- Stack: [Framework + Language]
- UI: [Component library]
- Tests: [Framework]
- API: [Pattern]
- State: [Pattern]

Key conventions detected:
1. [convention]
2. [convention]
3. [convention]

Guardrails: [default | light | toy | existing file kept]

Team agents will now follow these conventions.
Run /team or /team-run to start a team workflow.
```

## Related
- `project-analyzer` skill — Analysis methodology
- `/team` — Full team workflow (uses profile)
- `/team-run` — Autonomous workflow (uses profile)
- `/team-brainstorm` — Planning only (uses profile)
