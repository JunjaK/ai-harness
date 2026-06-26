# AI Harness — Multi-Agent Team Workflow

A reusable Claude Code harness for Claude Opus: greenfield project bootstrap (research → scaffold → profile) plus a 5-phase multi-agent team workflow (TDD, escalation loops, worktree parallelization), a full testing stack, a lifecycle-managed document-storage system, code-minimalism discipline, and instinct-based learning.

## Overview

Specialized AI agents collaborate through defined phases to implement features, fix bugs, or refactor code. Beyond the core team workflow, the harness adds:

- **Testing stack** — unit (Vitest) → deterministic E2E (Playwright) → **agentic E2E** (Phase 4.5: an agent verifies goals and crystallizes deterministic tests) → **human QA** (`/test-scenario-doc`, an interactive checklist).
- **Document storage (3 buckets)** — `_docs/` (project, lifecycle-managed) · `_note/` (human-owned, agent read-only) · `.claude/wiki/` (an agent-maintained **LLM wiki** that compounds knowledge), classified by a portable ownership discriminator.
- **Code minimalism** — the `ponytail` YAGNI decision ladder, applied at design time and reviewed in Phase 4.
- **Instinct-based learning** — `continuous-learning` captures atomic, confidence-scored, project-scoped instincts that evolve into skills / commands / agents.
- **Ultracode orchestration** — when enabled, fan-out phases run via the Workflow tool.

### Team Roles

| Role | Agent | Model | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | opus | Always (Phase 1, Gate, Escalation) |
| Architect A (Frontend) | `team-architect-fe` | opus | Phase 1 (parallel with B) |
| Architect B (Backend) | `team-architect-be` | opus | Phase 1 (parallel with A) |
| Architect C (Infra/Security) | `team-architect-infra` | opus | Phase 1 (on-demand) + Phase 5 (always) |
| UI/UX Master | `team-uiux-master` | opus | Phase 2 (conditional) |
| Designer x N | `team-designer` | opus | Phase 3 (parallel, worktree isolated) |
| Tester x N | `team-tester` | sonnet | Phase 4 (parallel) |
| Agentic Tester | `team-agentic-tester` | opus | Phase 4.5 (conditional, after Tester PASS) |
| Web Architect | `web-architect` | opus | Web architecture (standalone or complements FE) |
| Web Reviewer | `web-reviewer` | sonnet | Web quality audit (a11y, CWV, SEO, AI-slop) |

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

Phase 4.5: Agentic Testing (conditional)
  Agent explores goals → verifies → crystallizes deterministic tests
  (then human QA via /test-scenario-doc, before final sign-off)

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
| `/team-new` | Greenfield — empty repo → deep-research → scaffold → seeded profile, then hand off to `/team-run` |
| `/team-init` | Analyze an existing project → generate profile (run first on a project with code!) |
| `/team` | Interactive mode — user participates in planning phase |
| `/team-run` | Autonomous mode — full auto-execution |
| `/team-brainstorm` | Planning only — Leader + Architects discuss, no implementation |
| `/checkpoint` | Save / restore work state across sessions, branches, and compactions |
| `/docs-sweep` | Reap stale `_docs/` and re-verify orphan-document invariants |
| `/test-scenario-doc` | On-demand human QA checklist HTML (human acceptance layer) |
| `/brain-connect` | Pair an optional personal **brain** SSOT (cross-machine persona + auto-memory) with the harness, or relocate an existing one |

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
>
> `CLAUDE_HARNESS_ULTRACODE=1` is **optional** — an explicit override that forces ultracode orchestration (Workflow-tool fan-outs) in headless / non-Claude-Code contexts where the runtime ultracode signal is absent. See CLAUDE.md "Ultracode Orchestration".

### Dependencies

| # | Dependency | Required? | Role | Install / Enable |
|---|------------|-----------|------|------------------|
| 1 | **Agent Teams** | **Required** for `/team*` | cross-review dialog (`TeamCreate`) | `settings.json` env `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| 2 | **Ultracode** mode | Optional | when on, the harness uses the Workflow tool for fan-out phases **as much as possible** | runtime ultracode signal, or `settings.json` env `CLAUDE_HARNESS_ULTRACODE=1` |
| 3 | **impeccable** plugin | **Required install** | UI design — <https://impeccable.style/> | `/plugin marketplace add pbakaus/impeccable` → `/plugin install impeccable@impeccable` |
| 4 | **ponytail** plugin | **Required install** | YAGNI-style development — <https://github.com/DietrichGebert/ponytail> | `/plugin install ponytail@ponytail` |

- **impeccable**: the UI/UX agents (`team-uiux-master`, `web-architect`, `web-reviewer`) call it via `Skill(skill="impeccable:impeccable", args="<sub-command> [target]")` — the sub-command goes in `args`, not the namespace.
- **ponytail**: Phase 4 runs `/ponytail-review` on the diff; the YAGNI decision ladder is also distilled into `coding-standards` §4 for the architect/designer agents at design time.
- If either plugin is missing, the relevant agent **aborts with an install request** — install both before running the workflow.

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

### Document Storage (3 buckets)

Documents are classified by **owner**, using a portable discriminator: *"swap the agent CLI — is this still meaningful?"* → yes = project / human (`_` prefix at repo root); no = agent-only (`.claude/`).

| Bucket | Owner | Holds |
|--------|-------|-------|
| `_docs/` | project | plans, specs, ADRs — lifecycle-managed (`planning → processing → complete`), sidecars merged on completion |
| `_note/` | human | personal / research / scratch notes — **agent read-only** (edited only on explicit request), no frontmatter |
| `.claude/wiki/` | agent | an **LLM wiki** — compounding, interlinked knowledge (ingest / query / lint); links to the SSOT, never duplicates |

Handoffs live in `_docs/handoff/`. `/team-init` bootstraps `_note/README.md` and `.claude/wiki/`. The rules live in the `docs-lifecycle` and `wiki` skills; `_docs/index.md` is updated on every plan change.

## Supporting Skills

Skills that agents reference during their workflow phases:

| Skill | Phase | Purpose |
|-------|-------|---------|
| `greenfield-bootstrap` | `/team-new` | G0 intake → G1 deep-research → G2 stack decision → G3 user gate → G4 scaffold → G5 seeded profile |
| `plan-review` | Phase 1 | Critical review of plans before implementation + pre-plan elicitation |
| `coding-standards` | Phase 3 | Universal code quality baseline (strict TS) |
| `tdd-workflow` | Phase 3 | Red-Green-Refactor TDD cycle (Vitest 4.x) |
| `debug` | Phase 3-4 | LSP-driven debugging patterns (TS) |
| `e2e-testing` | Phase 4 | Playwright E2E patterns for Testers |
| `agentic-testing` | Phase 4.5 | Adapter-based agentic E2E — explore goal → verify → crystallize deterministic test |
| `test-scenario-doc` | Human acceptance | Interactive human QA checklist HTML — on-demand via `/test-scenario-doc` |
| `verification-loop` | Phase 4-5 | 6-phase quality gate (build, type, lint, test, security, diff) |
| `contract-sync` | Phase 0 / BE→FE handoff | Regenerate a generated API client after a backend contract change, then type-check + cross-check consumption sites against it |
| `security-review` | Phase 5 | OWASP Top 10 checklist for Architect C |
| `plan-visualizer` | Phase 1+ | HTML diagram of plan (team, phases, files, deps) |
| `project-analyzer` | Setup | Project structure analysis → profile generation |
| `brain-connect` | Setup (per-machine) | Pair an optional personal **brain** SSOT (cross-machine persona + auto-memory) with the harness — persona `@import` + memory junction + opt-in sync hooks; dependency-free, ships a generic connector template |

Cross-cutting skills (any phase): `token-optimization`, `continuous-learning`, `parallelization`, `subagent-orchestration`, `checkpoint`, `docs-lifecycle`, `handoff`, `wiki`.

For general API design patterns, use the Claude Code built-in `api-design` skill directly (the harness does not wrap it).

## Plugin Structure

```
junjak-ai-harness/
├── .claude-plugin/
│   ├── plugin.json              # Plugin manifest
│   └── marketplace.json         # Marketplace definition (single-repo)
├── agents/                      # 10 specialized agents
│   ├── team-leader.md
│   ├── team-architect-fe.md
│   ├── team-architect-be.md
│   ├── team-architect-infra.md
│   ├── team-uiux-master.md
│   ├── team-designer.md
│   ├── team-tester.md
│   ├── team-agentic-tester.md
│   ├── web-architect.md
│   └── web-reviewer.md
├── commands/                    # 8 slash commands
│   ├── team-new.md              # /team-new
│   ├── team-init.md             # /team-init
│   ├── team.md                  # /team
│   ├── team-run.md              # /team-run
│   ├── team-brainstorm.md       # /team-brainstorm
│   ├── checkpoint.md            # /checkpoint
│   ├── docs-sweep.md            # /docs-sweep
│   └── test-scenario-doc.md     # /test-scenario-doc
├── hooks/
│   ├── hooks.json               # Plugin hook registration
│   ├── session-stop.sh
│   ├── pre-compact.sh
│   └── post-edit-warn.sh
└── skills/                      # 22 workflow skills
    ├── team-workflow/
    ├── greenfield-bootstrap/
    ├── project-analyzer/
    ├── tdd-workflow/
    ├── verification-loop/
    ├── contract-sync/
    ├── docs-lifecycle/
    ├── handoff/
    ├── wiki/
    ├── agentic-testing/
    ├── test-scenario-doc/
    ├── security-review/
    └── ... (10 more)
```

### CLAUDE.md Note

Plugins cannot inject `CLAUDE.md` into user projects. The `CLAUDE.md` at this repo root documents the harness's operating principles. Users who want the full ruleset should copy relevant sections into their own project `CLAUDE.md`.

## License

MIT
