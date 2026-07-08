# AI Harness — Multi-Agent Team Workflow

**English** · [한국어](README.ko.md) · [日本語](README.ja.md)

A reusable Claude Code harness for Claude Opus: greenfield project bootstrap (research → scaffold → profile) plus a 5-phase multi-agent team workflow (TDD, escalation loops, worktree parallelization), a full testing stack, a lifecycle-managed document-storage system, code-minimalism discipline, and instinct-based learning.

## Overview

Specialized AI agents collaborate through defined phases to implement features, fix bugs, or refactor code. Beyond the core team workflow, the harness adds:

- **Testing stack** — unit (Vitest) → deterministic E2E (Playwright) → **agentic E2E** (Phase 4.5: an agent verifies goals and crystallizes deterministic tests) → **human QA** (`/test-scenario-doc`, an interactive checklist). When the [`agent-browser`](https://agent-browser.dev/) CLI + skill are installed, it becomes the **preferred on-demand browser driver** for E2E / QA / smoke — including headless login via its encrypted **Auth Vault** (the password never reaches the LLM) — and otherwise falls back to the Playwright path.
- **Document storage (3 buckets)** — `_docs/` (project, lifecycle-managed) · `_note/` (human-owned, agent read-only) · `.claude/wiki/` (an agent-maintained **LLM wiki** that compounds knowledge), classified by a portable ownership discriminator.
- **Code minimalism** — the `ponytail` YAGNI decision ladder, applied at design time and reviewed in Phase 4.
- **Renewal Mode Gate** — every non-trivial refactor / fix / redesign starts by choosing **A (compatible)** or **B (destructive renewal)**; Mode B requires a risk block + explicit approval, then a full anti-drift commitment so back-compat scaffolding never creeps back in.
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

Alongside the env flags above, the harness uses a few external tools. Install them for the full experience — each is described below with what happens when it's absent.

| Tool | Used for | Without it |
|------|----------|-----------|
| **impeccable** plugin · [impeccable.style](https://impeccable.style/) | UI/UX design quality — the `team-uiux-master` / `web-architect` / `web-reviewer` agents call it via `Skill("impeccable:impeccable", "<sub-command> [target]")` | those agents pause and ask you to install it |
| **ponytail** plugin · [repo](https://github.com/DietrichGebert/ponytail) | YAGNI minimalism — Phase 4 runs `/ponytail-review` on the diff | Phase 4 asks you to install it (the decision ladder is also distilled into `coding-standards` §4) |
| **agent-browser** CLI + skill · [agent-browser.dev](https://agent-browser.dev/) | preferred on-demand browser driver for E2E / QA / smoke + headless Auth-Vault login (the password never reaches the LLM) | falls back to the Playwright `e2e-testing` / `agentic-testing` path |

```bash
/plugin marketplace add pbakaus/impeccable && /plugin install impeccable@impeccable
/plugin install ponytail@ponytail
npm i -g agent-browser && agent-browser install   # skill ships with the CLI
```

impeccable and ponytail are expected to be installed before running the workflow; agent-browser is optional but recommended for smoother browser work.

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

Handoffs live in `_docs/handoff/`. `/team-init` bootstraps `_note/README.md` and `.claude/wiki/`. The rules live in the `docs-lifecycle` and `wiki` skills; `_docs/index.md` is updated on every plan change. Under worktree parallelization, `_docs/` stays in the **primary working tree** — worktree agents read and write doc files there by absolute path, and only `index.md` edits + status-moves are orchestrator-serialized, so plans stay readable from main without cd-ing into a worktree.

## Supporting Skills

Skills that agents reference during their workflow phases:

| Skill | Phase | Purpose |
|-------|-------|---------|
| `greenfield-bootstrap` | `/team-new` | G0 intake → G1 deep-research → G2 stack decision → G3 user gate → G4 scaffold → G5 seeded profile |
| `plan-review` | Phase 1 | Critical review of plans before implementation + pre-plan elicitation |
| `brainstorm` | Pre-Phase 1 (solo) | Lightweight solo design dialogue → `_docs/` design (no auto-commit); solo counterpart to `/team-brainstorm` |
| `coding-standards` | Phase 3 | Universal code quality baseline (strict TS) |
| `tdd-workflow` | Phase 3 | Red-Green-Refactor TDD cycle (Vitest 4.x) |
| `systematic-debugging` | Phase 3-4 | General debugging methodology (root cause → pattern → hypothesis → fix); `debug` layers TS/LSP on top |
| `debug` | Phase 3-4 | LSP-driven debugging patterns (TS) |
| `e2e-testing` | Phase 4 | Playwright E2E patterns for Testers |
| `agentic-testing` | Phase 4.5 | Adapter-based agentic E2E — explore goal → verify → crystallize deterministic test |
| `agent-browser-e2e` | On-demand | Prefer the `agent-browser` CLI for E2E/QA/smoke + headless login via its encrypted Auth Vault (no password reaches the LLM) when the CLI + skill are installed; one-time gate, else fall back to Playwright. Not phase-wired |
| `test-scenario-doc` | Human acceptance | Interactive human QA checklist HTML — on-demand via `/test-scenario-doc` |
| `scenario-to-e2e` | On-demand | Turn a `test-scenario-doc` into runnable Playwright specs — the doc's `SCENARIOS` config is SSOT; drives the live app for real selectors, runs + green-gates each spec, falls back to a marked-unverified scaffold. No fabricated selectors |
| `verification-loop` | Phase 4-5 | 6-phase quality gate (build, type, lint, test, security, diff) |
| `contract-sync` | Phase 0 / BE→FE handoff | Regenerate a generated API client after a backend contract change, then type-check + cross-check consumption sites against it |
| `security-review` | Phase 5 | OWASP Top 10 checklist for Architect C |
| `requesting-code-review` | Phase 3-5 / on-demand | Dispatch a code-reviewer subagent (crafted context) between tasks / before a merge gate |
| `plan-visualizer` | Phase 1+ | HTML diagram of plan (team, phases, files, deps) |
| `project-analyzer` | Setup | Project structure analysis → profile generation |
| `brain-connect` | Setup (per-machine) | Pair an optional personal **brain** SSOT (cross-machine persona + auto-memory) with the harness — persona `@import` + memory junction + opt-in sync hooks; dependency-free, ships a generic connector template |

Cross-cutting skills (any phase): `token-optimization`, `continuous-learning`, `parallelization`, `dispatching-parallel-agents`, `subagent-orchestration`, `checkpoint`, `docs-lifecycle`, `handoff`, `take-over`, `wiki`.

- `handoff` / `take-over` are a **write ↔ read pair**: `handoff` writes the state layer into `_docs/handoff/`; `take-over` (`/take-over`) consumes it — hydrates the linked spec, verifies the claimed state against the repo, then **graduates** the temp handoff into its durable `_docs` home (a `complete/` archive, or a `plan` in `active/`) with the name/kind/status corrected to `_docs` grammar — never a bare delete. Distinct from `/checkpoint` (agent session-state restore).

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
├── commands/                    # 10 slash commands
│   ├── team-new.md              # /team-new
│   ├── team-init.md             # /team-init
│   ├── team.md                  # /team
│   ├── team-run.md              # /team-run
│   ├── team-brainstorm.md       # /team-brainstorm
│   ├── checkpoint.md            # /checkpoint
│   ├── take-over.md             # /take-over
│   ├── docs-sweep.md            # /docs-sweep
│   ├── test-scenario-doc.md     # /test-scenario-doc
│   └── brain-connect.md         # /brain-connect
├── hooks/
│   ├── hooks.json               # Plugin hook registration
│   ├── session-stop.sh
│   ├── pre-compact.sh
│   └── post-edit-warn.sh
└── skills/                      # 29 workflow skills
    ├── team-workflow/
    ├── greenfield-bootstrap/
    ├── project-analyzer/
    ├── tdd-workflow/
    ├── verification-loop/
    ├── contract-sync/
    ├── docs-lifecycle/
    ├── handoff/
    ├── take-over/
    ├── wiki/
    ├── agentic-testing/
    ├── test-scenario-doc/
    ├── scenario-to-e2e/
    ├── security-review/
    ├── systematic-debugging/
    ├── dispatching-parallel-agents/
    ├── requesting-code-review/
    ├── brainstorm/
    └── ... (14 more)
```

### CLAUDE.md Note

Plugins cannot inject `CLAUDE.md` into user projects. The `CLAUDE.md` at this repo root documents the harness's operating principles. Users who want the full ruleset should copy relevant sections into their own project `CLAUDE.md`.

## License

MIT
