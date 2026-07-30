# AI Harness — Multi-Agent Team Workflow

A reusable Claude Code harness for Claude Opus: greenfield project bootstrap (research → scaffold → profile) plus a 5-phase multi-agent team workflow (TDD, escalation loops, worktree parallelization), a full testing stack, a lifecycle-managed document-storage system, code-minimalism discipline, and continuous pattern learning.

## Overview

Specialized AI agents collaborate through defined phases to implement features, fix bugs, or refactor code. Beyond the core team workflow, the harness adds:

- **Testing stack** — unit (Vitest) → deterministic E2E (Playwright) → **agentic E2E** (Phase 4.5: an agent verifies goals and crystallizes deterministic tests) → **human QA** (`/test-scenario-doc`, an interactive checklist). When the [`agent-browser`](https://agent-browser.dev/) CLI + skill are installed, it becomes the **preferred on-demand browser driver** for E2E / QA / smoke — including headless login via its encrypted **Auth Vault** (the password never reaches the LLM) — and otherwise falls back to the Playwright path.
- **Document storage (3 buckets)** — `_docs/` (project, lifecycle-managed) · `_note/` (human-owned, agent read-only) · `.claude/wiki/` (an agent-maintained **LLM wiki** that compounds knowledge), classified by a portable ownership discriminator.
- **Code minimalism** — the `ponytail` YAGNI decision ladder, applied at design time and reviewed in Phase 4.
- **Renewal Mode Gate** — every non-trivial refactor / fix / redesign starts by choosing **A (compatible)** or **B (destructive renewal)**; Mode B requires a risk block + explicit approval, then a full anti-drift commitment so back-compat scaffolding never creeps back in.
- **Continuous learning** — `continuous-learning` extracts reusable, validated, non-obvious patterns from sessions, reuses them at task start, and evolves stable ones into skills / commands / agents.
- **Ultracode orchestration** — when enabled, fan-out phases run via the Workflow tool, with **per-agent model routing** (read-only scan → Haiku, TDD-implement / verify / review / translate → Sonnet, architecture / security → Opus) so a fan-out isn't silently all-Opus.
- **Unknowns-first collaboration** — `brainstorm` opens with a **Blindspot Pass** (surface unknown-unknowns before designing); `verification-loop` closes with an opt-in **human comprehension quiz** (merge only what you can explain); Designers keep a **Deviations log** when implementation departs from the plan.

### Team Roles

| Role | Agent | Model | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | opus | Always (Phase 1, Gate, Escalation) |
| Architect A (Frontend) | `team-architect-fe` | opus | Phase 1 (parallel with B) |
| Architect B (Backend) | `team-architect-be` | opus | Phase 1 (parallel with A) |
| Architect C (Infra/Security) | `team-architect-infra` | opus | Phase 1 (on-demand) + Phase 5 (always) |
| UI/UX Master | `team-uiux-master` | sonnet | Phase 2 (conditional) |
| Designer x N | `team-designer` | sonnet | Phase 3 (parallel, worktree isolated); → opus on full-stack / auth·payment·PII / post-fail |
| Tester x N | `team-tester` | sonnet | Phase 4 (parallel) |
| Agentic Tester | `team-agentic-tester` | opus | Phase 4.5 (conditional, after Tester PASS) |
| Web Architect | `web-architect` | opus | Web architecture (standalone or complements FE) |
| Web Reviewer | `web-reviewer` | sonnet | Web quality audit (a11y, CWV, SEO, AI-slop) |

### Workflow Phases

Phase 1 (Planning) → Phase 2 (UI/UX, conditional) → Leader Approval Gate → Phase 3 (Implementation, TDD) → Phase 4 (Verification) → Phase 4.5 (Agentic Testing, conditional) → Phase 5 (Final Security Review).

- **Visual** (phase graph, mermaid): `skills/team-workflow/SKILL.md` → "Orchestration Flow"
- **Rules** (routing, classification, counters, abort thresholds): `skills/team-workflow/resources/escalation.md` → "Phase Transition Table"

### Escalation

Classification (simple fix vs fundamental issue), routing, retry/global-cycle caps, and report formats are all defined in `skills/team-workflow/resources/escalation.md` — the single source of truth. Both `/team` and `/team-run` report escalation events to the user.

## Commands

| Command | Description |
|---------|-------------|
| `/team-new` | Greenfield — empty repo → deep-research → scaffold → seeded profile, then hand off to `/team-run` |
| `/team-init` | Analyze an existing project → generate profile (run first on a project with code!) |
| `/team` | Interactive mode — user participates in planning phase |
| `/team-run` | Autonomous mode — full auto-execution |
| `/team-brainstorm` | Planning only — Leader + Architects discuss, no implementation |
| `/debug` | Solo systematic debug of a bug / test failure (Iron Law: root cause before fix); layers the TS/LSP `debug` skill, escalates to `/team` when Fundamental |
| `/checkpoint` | Save / restore work state across sessions, branches, and compactions |
| `/meta-prompt` | Compile a raw context dump into an optimized, self-contained prompt to inject into a fresh session, `/team-run` string, subagent, or another tool |
| `/worktree-deps` | Provision a worktree's deps via the package manager's shared store (hard-link, no re-download, parallel-safe); pnpm/bun inline, other managers via Context7 — never symlinks `node_modules` |
| `/take-over` | Resume a handed-off work-stream from `_docs/handoff/` — hydrate the spec, verify state, graduate the handoff into its durable `_docs` home |
| `/docs-sweep` | Reap stale `_docs/` and re-verify orphan-document invariants |
| `/test-scenario-doc` | On-demand human QA checklist HTML (human acceptance layer) |
| `/brain-connect` | Pair an optional personal **brain** SSOT (cross-machine persona, global `CLAUDE.md`, personal global skills, auto-memory, recommended-settings manifest) with the harness, or relocate an existing one |

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
| **superpowers** plugin · [repo](https://github.com/anthropics/claude-plugins-official) | general debugging methodology, code-review dispatch, and parallel-agent dispatch decisions — `/debug` and the `debug` skill invoke `superpowers:systematic-debugging` and layer the harness's TS/LSP patterns + escalation boundary on top | `/debug` aborts and asks you to install it |
| **agent-browser** CLI + skill · [agent-browser.dev](https://agent-browser.dev/) | preferred on-demand browser driver for E2E / QA / smoke + headless Auth-Vault login (the password never reaches the LLM) | falls back to the Playwright `e2e-testing` / `agentic-testing` path |

```bash
/plugin marketplace add pbakaus/impeccable && /plugin install impeccable@impeccable
/plugin install ponytail@ponytail
/plugin install superpowers@claude-plugins-official
npm i -g agent-browser && agent-browser install   # skill ships with the CLI
```

impeccable, ponytail, and superpowers are expected to be installed before running the workflow; agent-browser is optional but recommended for smoother browser work.

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
| `debug` | Phase 3-4 | LSP-driven debugging patterns (TS), layered on `superpowers:systematic-debugging` |
| `e2e-testing` | Phase 4 | Playwright E2E patterns for Testers |
| `agentic-testing` | Phase 4.5 | Adapter-based agentic E2E — explore goal → verify → crystallize deterministic test |
| `agent-browser-e2e` | On-demand | Prefer the `agent-browser` CLI for E2E/QA/smoke + headless login via its encrypted Auth Vault (no password reaches the LLM) when the CLI + skill are installed; one-time gate, else fall back to Playwright. Not phase-wired |
| `test-scenario-doc` | Human acceptance | Interactive human QA checklist HTML — on-demand via `/test-scenario-doc` |
| `scenario-to-e2e` | On-demand | Turn a `test-scenario-doc` into runnable Playwright specs — the doc's `SCENARIOS` config is SSOT; drives the live app for real selectors, runs + green-gates each spec, falls back to a marked-unverified scaffold. No fabricated selectors |
| `verification-loop` | Phase 4-5 | 6-phase quality gate (build, type, lint, test, security, diff) + reliability gates: tests green in ≥ 80% of runs, security 3/3 clean |
| `contract-sync` | Phase 0 / BE→FE handoff | Regenerate a generated API client after a backend contract change, then type-check + cross-check consumption sites against it |
| `security-review` | Phase 5 | OWASP Top 10 checklist for Architect C |
| `plan-visualizer` | Phase 1+ | HTML diagram of plan (team, phases, files, deps) — fills the self-contained skeleton in `skills/plan-visualizer/resources/template.html` |
| `project-analyzer` | Setup | Project structure analysis → profile generation |
| `brain-connect` | Setup (per-machine) | Pair an optional personal **brain** SSOT with the harness — links global `CLAUDE.md`, `persona.md`, per-skill global skills, commands and auto-memory, plus a merged recommended-settings manifest and opt-in sync hooks; dependency-free, ships a generic connector template for both shells |

Cross-cutting skills (any phase): `token-optimization` (model routing, effort levels, compaction — plus §6 **Subagent Orchestration**: the 3-cycle retrieval protocol and the six-element briefing contract), `continuous-learning`, `parallelization`, `submodule-worktree`, `checkpoint`, `docs-lifecycle`, `handoff`, `take-over`, `wiki`.

General debugging methodology, code-review dispatch, and parallel-agent dispatch decisions come from the **superpowers** plugin (`superpowers:systematic-debugging`, `superpowers:requesting-code-review`, `superpowers:dispatching-parallel-agents`) — the harness layers its own TS/LSP patterns and escalation boundary on top instead of forking them.

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
├── commands/                    # 13 slash commands
│   ├── team-new.md              # /team-new
│   ├── team-init.md             # /team-init
│   ├── team.md                  # /team
│   ├── team-run.md              # /team-run
│   ├── team-brainstorm.md       # /team-brainstorm
│   ├── debug.md                 # /debug
│   ├── checkpoint.md            # /checkpoint
│   ├── meta-prompt.md           # /meta-prompt
│   ├── worktree-deps.md         # /worktree-deps
│   ├── take-over.md             # /take-over
│   ├── docs-sweep.md            # /docs-sweep
│   ├── test-scenario-doc.md     # /test-scenario-doc
│   └── brain-connect.md         # /brain-connect
├── hooks/
│   ├── hooks.json               # Plugin hook registration
│   ├── session-start.sh
│   ├── session-stop.sh
│   ├── pre-compact.sh
│   └── post-edit-warn.sh
└── skills/                      # 27 workflow skills
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
    ├── brainstorm/
    └── ... (12 more)
```

### CLAUDE.md Note

Plugins cannot inject `CLAUDE.md` into user projects. The `CLAUDE.md` at this repo root is the harness's always-on **router**: operating principles, the Renewal Mode Gate, routing rules, and hard-rule digests. It deliberately carries no inventory tables of skills / agents / commands — the runtime injects that metadata from each component's frontmatter automatically, so listing it there would only duplicate and drift. Users who want the full ruleset should copy relevant sections into their own project `CLAUDE.md`.

## Changelog

Full history: [CHANGELOG.md](./CHANGELOG.md). Latest:

**v1.22.0** — `brain-connect` now covers the whole cross-machine surface: global `CLAUDE.md`, personal global skills, and a merged settings manifest — not just persona + memory.
- Brain contract grew from 3 rows to 7: `CLAUDE.md`, per-skill `skills/<name>/`, and `settings.recommended.json` join persona, commands, memory and sync.
- **One link per skill, never the whole `skills/` dir** — third-party tools install relative-symlinked skills there, and linking the directory hides them.
- **`settings.json` is merged from an enumerated manifest, never synced whole** — machine-specific `hooks` / `statusLine` / `permissions.allow` and all `skip*` prompt flags stay local; `enabledPlugins` ships paired with `extraKnownMarketplaces` or the toggle is vacuous.
- Persona import goes relative (`@persona.md` + a `persona.md` link beside `CLAUDE.md`), so no machine path survives in synced content.
- Connector template completed for both shells: new `setup.sh`, `sync.sh`, `apply-settings.sh`/`.ps1`, example manifest; `relocate.ps1` reduced to its one remaining job (sync-hook paths) by delegating links to `setup.ps1`.
- Verify section warns that `grep -r` traverses **zero** files once skills are symlinks — a false green; use `-R`.

## License

MIT
