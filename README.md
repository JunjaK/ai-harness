# AI Harness — Multi-Agent Team Workflow

A reusable Claude Code harness for orchestrating multi-agent team workflows with 5 phases, escalation loops, and TDD enforcement.

## Overview

This harness provides a structured team workflow where specialized AI agents collaborate through defined phases to implement features, fix bugs, or refactor code.

### Team Roles

| Role | Agent | Model | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | opus | Always (Phase 1, Gate, Escalation) |
| Architect A (Frontend) | `team-architect-fe` | opus | Phase 1 (parallel with B) |
| Architect B (Backend) | `team-architect-be` | opus | Phase 1 (parallel with A) |
| Architect C (Infra/Security) | `team-architect-infra` | opus | Phase 1 (on-demand) + Phase 5 (always) |
| UI/UX Master | `team-uiux-master` | sonnet | Phase 2 (conditional) |
| Designer x N | `team-designer` | opus | Phase 3 (parallel, worktree isolated) |
| Tester x N | `team-tester` | sonnet | Phase 4 (parallel) |

### Workflow Phases

```
Phase 1: Planning
  Leader drafts plan → Arch A + B detail (parallel) → Cross-review → File assignment

Phase 2: UI/UX (conditional)
  UI/UX Master reviews and proposes changes

Leader Approval Gate
  Approve → Phase 3 | Reject → Phase 1

Phase 3: Implementation (TDD)
  Designer x N in parallel worktrees (Red-Green-Refactor)

Phase 4: Verification
  Tester x N (unit + E2E, loop until pass)

Phase 5: Final Security Review
  Arch C security & infra audit → SHIP or escalate
```

### Escalation

- Each agent self-judges: simple fix (retry, max 3) vs fundamental issue (escalate up)
- Global re-plan limit: 3 cycles to prevent infinite loops
- Both `/team` and `/team-run` report escalation events to user

## Commands

| Command | Description |
|---------|-------------|
| `/team-init` | Analyze project → generate profile (run first!) |
| `/team` | Interactive mode — user participates in planning phase |
| `/team-run` | Autonomous mode — full auto-execution |
| `/team-brainstorm` | Planning only — Leader + Architects discuss, no implementation |

## Installation (Plugin)

This harness is distributed as a **Claude Code plugin**.

```bash
# 1. Add the marketplace
/plugin marketplace add JunjaK/ai-harness

# 2. Install the plugin
/plugin install junjak-ai-harness@ai-harness
```

### Required User Configuration

The plugin manifest cannot set environment variables or permissions. Add to your **user** or **project** `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"
  },
  "permissions": {
    "allow": [
      "Edit",
      "Write",
      "LSP",
      "Bash(git *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(bun *)",
      "Bash(bunx *)",
      "Bash(pnpm *)",
      "Bash(npx *)"
    ]
  }
}
```

> `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is **required** — `/team`, `/team-run`, `/team-brainstorm` depend on `TeamCreate` for cross-review.

### Dependency

This plugin depends on the `impeccable` skill for UI/UX work (`shape`, `critique`, `audit`, `polish`, etc.). `impeccable` is distributed as a **single personal skill**, not a Claude Code plugin — install it manually to:

```
~/.claude/skills/impeccable/
```

The `impeccable` agents (`team-uiux-master`, `web-architect`, `web-reviewer`) call it via `Skill(skill="impeccable", args="<sub-command> [target]")`. If the skill is missing they will abort with a request to install it.

### First Run

```
/team-init                        # Scan project → generate .claude/project-profile/
/team "Add user authentication"   # Start a workflow
```

`/team-init` generates `.claude/project-profile/` in your project — all agents adapt to your stack and conventions.

## Customization

### Adapting to Your Stack

The agents are framework-agnostic by default. To specialize for your project:

1. **team-architect-fe.md** — Add your frontend conventions (component patterns, state management, styling)
2. **team-architect-be.md** — Add your backend conventions (API patterns, ORM, database)
3. **team-architect-infra.md** — Add your security checklist (auth patterns, env management)
4. **team-designer.md** — Add your test framework and TDD patterns
5. **team-tester.md** — Add your test runner commands and E2E setup

### Plan Storage (`_docs/`)

Team plans are saved to the `_docs/` directory with the following structure:

```
_docs/
├── index.md              # Documentation index (always updated)
├── data-template/        # Category folder
├── data-sheet/           # Category folder
├── infra/                # Category folder
└── {category}/           # Add folders as needed
    └── plan-{feature}.md # Team plan document
```

**Plan lifecycle:**
1. Phase 1 complete → save plan to `_docs/{category}/plan-{feature}.md` (status: Planning)
2. Phase 3 complete → update with implementation notes (status: In Progress)
3. Phase 4 complete → update with test results (status: Verification)
4. Phase 5 complete → update with final summary (status: Complete)

Always update `_docs/index.md` when adding new plans. To customize the path, modify:
- `team-leader.md` (plan output section)
- `SKILL.md` (Phase 1 Step 5, Phase 3/4/5 update steps)

## Supporting Skills

Skills that agents reference during their workflow phases:

| Skill | Phase | Purpose |
|-------|-------|---------|
| `plan-review` | Phase 1 | Critical review of plans before implementation |
| `coding-standards` | Phase 3 | Universal code quality baseline (strict TS) |
| `tdd-workflow` | Phase 3 | Red-Green-Refactor TDD cycle (Vitest 4.x) |
| `debug` | Phase 3-4 | LSP-driven debugging patterns (TS) |
| `e2e-testing` | Phase 4 | Playwright E2E patterns for Testers |
| `verification-loop` | Phase 4-5 | 6-phase quality gate (build, type, lint, test, security, diff) |
| `security-review` | Phase 5 | OWASP Top 10 checklist for Architect C |
| `plan-visualizer` | Phase 1+ | HTML diagram of plan (team, phases, files, deps) |
| `project-analyzer` | Setup | Project structure analysis → profile generation |

Cross-cutting skills (any phase): `token-optimization`, `continuous-learning`, `parallelization`, `subagent-orchestration`, `checkpoint`.

For general API design patterns, use the Claude Code built-in `api-design` skill directly (the harness does not wrap it).

## Plugin Structure

```
junjak-ai-harness/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Marketplace definition (single-repo)
├── agents/                      # 9 specialized agents
│   ├── team-leader.md
│   ├── team-architect-fe.md
│   ├── team-architect-be.md
│   ├── team-architect-infra.md
│   ├── team-uiux-master.md
│   ├── team-designer.md
│   ├── team-tester.md
│   ├── web-architect.md
│   └── web-reviewer.md
├── commands/
│   ├── team-init.md             # /team-init
│   ├── team.md                  # /team
│   ├── team-run.md              # /team-run
│   ├── team-brainstorm.md       # /team-brainstorm
│   └── checkpoint.md            # /checkpoint
├── hooks/
│   ├── hooks.json               # Plugin hook registration
│   ├── session-stop.sh
│   ├── pre-compact.sh
│   └── post-edit-warn.sh
└── skills/                      # 15 workflow skills
    ├── team-workflow/
    ├── project-analyzer/
    ├── tdd-workflow/
    ├── verification-loop/
    ├── security-review/
    └── ... (11 more)
```

### CLAUDE.md Note

Plugins cannot inject `CLAUDE.md` into user projects. The `CLAUDE.md` at this repo root documents the harness's operating principles. Users who want the full ruleset should copy relevant sections into their own project `CLAUDE.md`.

## License

MIT
