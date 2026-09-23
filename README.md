# AI Harness — Multi-Agent Team Workflow

A reusable Claude Code harness for Claude Opus, with a focused Codex adapter for project analysis, implementation, and debugging. The Claude workflow includes greenfield bootstrap (research → scaffold → profile), a 5-phase multi-agent team workflow, testing layers, document lifecycle, and continuous learning.

## Overview

The following overview and slash commands describe the Claude Code workflow.

Specialized AI agents collaborate through defined phases to implement features, fix bugs, or refactor code. Beyond the core team workflow, the harness adds:

- **Testing stack** — `/team` runs changed unit/integration tests and at most one existing smoke E2E per affected user-facing flow, then reports implementation completion. It records up to five pending scenarios in the completed plan. Later, `/team-qa` collects those items across tasks and runs a bounded batch; `--crystallize` also turns verified paths into deterministic tests. `/test-scenario-doc` remains the on-demand HTML checklist for human QA. When [`agent-browser`](https://agent-browser.dev/) CLI + skill are installed, it is the default browser driver for any browser-driving task, including smoke and deferred QA.
- **Separate QA budget** — Phase 4 is one merged-tree verification pass. A failed or blocked required quick check ends that run with evidence and a fix/unblock list; it does not start an automatic QA→implementation loop. Deferred QA verdicts live with their scenario entries and do not rewrite the implementation-complete status.
- **Document storage (3 buckets)** — `_docs/` (project) · `.claude/wiki/` (an agent-maintained **LLM wiki** that compounds knowledge) · `_workspace/` (throwaway run output, gitignored but for its layout `README.md`), classified by a portable ownership discriminator. Inside `_docs/`, **lifecycle** buckets ride `planning → processing → complete`; **collection** buckets (`intent/`, `handoff/`, plus whatever a project declares) are append-only records the agent may add to but never reorganize.
- **Code minimalism** — a harness-owned YAGNI decision ladder (`coding-standards` §4), applied by the architect agents at design time and gated once, at the Phase 1 plan approval.
- **Renewal Mode Gate** — every non-trivial refactor / fix / redesign starts by choosing **A (compatible)** or **B (destructive renewal)**; Mode B requires a risk block + explicit approval, then a full anti-drift commitment so back-compat scaffolding never creeps back in.
- **Continuous learning** — `continuous-learning` extracts reusable, validated, non-obvious patterns from sessions, reuses them at task start, and evolves stable ones into skills / commands / agents.
- **Two-tier model routing** — the Leader assigns every dispatch `sonnet` (read-only or ≤2 files in one domain, no auth/payment/PII or contract change, deterministic) or `opus` (everything else), and the orchestrator applies it per call in standard and ultracode modes. The Leader follows your session model; every agent inherits the session effort.
- **Ultracode orchestration** — when enabled, fan-out phases run via the Workflow tool, with the same per-stage model routing.
- **Unknowns-first collaboration** — `brainstorm` opens with a **Blindspot Pass** (surface unknown-unknowns before designing); `verification-loop` closes with an opt-in **human comprehension quiz** (merge only what you can explain); Designers keep a **Deviations log** when implementation departs from the plan.

### Team Roles

| Role | Agent | Model (default) | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | session model (`inherit`) | Always (Phase 1, Gate, Escalation) |
| Architect A (Frontend) | `team-architect-fe` | opus | Phase 1 (parallel with B) |
| Architect B (Backend) | `team-architect-be` | opus | Phase 1 (parallel with A) |
| Architect C (Infra/Security) | `team-architect-infra` | opus | Phase 1 (on-demand) + Phase 5 (always) |
| UI/UX Master | `team-uiux-master` | opus | Phase 2 (conditional) |
| Designer x N | `team-designer` | opus | Phase 3 (parallel, worktree isolated) |
| Tester | `team-tester` | opus | Phase 4 (one lightweight merged-tree pass) |
| Agentic Tester | `team-agentic-tester` | opus | `/team-qa` (deferred, on demand) |
| Web Architect | `web-architect` | opus | Web architecture (standalone or complements FE) |
| Web Reviewer | `web-reviewer` | opus | Web quality audit (a11y, CWV, SEO, AI-slop) |

### Workflow Phases

Phase 1 (Planning) → Phase 2 (UI/UX, conditional) → Leader Approval Gate → Phase 3 (Implementation, TDD) → Phase 4 (Lightweight Verification) → Phase 5 (Final Security Review + deferred QA item capture). Run accumulated QA later with `/team-qa`.

- **Visual** (phase graph, mermaid): `skills/team-workflow/SKILL.md` → "Orchestration Flow"
- **Rules** (routing, classification, counters, abort thresholds): `skills/team-workflow/resources/escalation.md` → "Phase Transition Table"

### Escalation

Classification (simple fix vs fundamental issue), routing, retry/global-cycle caps, and report formats are all defined in `skills/team-workflow/resources/escalation.md` — the single source of truth. Both `/team` and `/team-run` report escalation events to the user.

Phase 4 records `VERIFY_PASS`, `VERIFY_FAIL`, or `VERIFY_BLOCKED` with the exact quick-check evidence. Only `VERIFY_PASS` reaches Phase 5. A failed or blocked run reports incomplete implementation and stops; later QA scenarios are generated only for completed work. Phase 5 reconciles the active plan and `_docs/index.md` with final code and quick-check evidence, refreshes affected wiki links, and archives the pending QA items with the implementation record.

## Commands

| Command | Description |
|---------|-------------|
| `/team-new` | Greenfield — empty repo → deep-research → scaffold → seeded profile, then hand off to `/team-run` |
| `/team-init` | Analyze an existing project → generate profile (run first on a project with code!) |
| `/team` | Interactive mode — user participates in planning phase |
| `/team-run` | Autonomous mode — full auto-execution |
| `/team-qa` | Later, collect pending scenarios from completed plans and run a bounded QA batch (`--all` for every pending item, `--crystallize` to generate deterministic tests) |
| `/team-brainstorm` | Planning only — Leader + Architects discuss, no implementation |
| `/debug` | Solo systematic debug of a bug / test failure (Iron Law: root cause before fix); layers the TS/LSP `debug` skill, escalates to `/team` when Fundamental |
| `/checkpoint` | Save / restore work state across sessions, branches, and compactions |
| `/meta-prompt` | Compile a raw context dump into an optimized, self-contained prompt to inject into a fresh session, `/team-run` string, subagent, or another tool |
| `/worktree-deps` | Provision a worktree's deps via the package manager's shared store (hard-link, no re-download, parallel-safe); pnpm/bun inline, other managers via Context7 — never symlinks `node_modules` |
| `/take-over` | Resume a handed-off work-stream from `_docs/handoff/` — hydrate the spec, verify state, graduate the handoff into its durable `_docs` home |
| `/docs-sweep` | Reap stale `_docs/` and re-verify orphan-document invariants |
| `/test-scenario-doc` | On-demand human QA checklist HTML (human acceptance layer) |
| `/plan-visualizer` | On-demand HTML diagram of a plan (team, phases, files, deps) — no workflow phase generates one |
| `/brain-connect` | Pair an optional personal **brain** SSOT (cross-machine persona, global `CLAUDE.md`, personal global skills, auto-memory, recommended-settings manifest) with the harness, or relocate an existing one |

## Claude Code installation (Plugin)

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

> No experimental flag is required. `/team`, `/team-run`, `/team-brainstorm` orchestrate entirely
> through `Agent()` subagents; cross-review runs as two parallel objection passes, not a team dialog.
>
> `CLAUDE_HARNESS_ULTRACODE=1` is **optional** — an explicit override that forces ultracode orchestration (Workflow-tool fan-outs) in headless / non-Claude-Code contexts where the runtime ultracode signal is absent. See CLAUDE.md "Ultracode Orchestration".

### Dependencies

Alongside the env flags above, the harness uses a few external tools. Each row states what happens when it's absent — **one aborts, the rest degrade**.

**Hard (a workflow step stops and asks you to install):**

| Tool | Used for | Without it |
|------|----------|-----------|
| **impeccable** plugin · [impeccable.style](https://impeccable.style/) | UI/UX design quality — the `team-uiux-master` / `web-architect` / `web-reviewer` agents call it via `Skill("impeccable:impeccable", "<sub-command> [target]")`, or `Skill("impeccable", …)` when it is installed as a personal skill — they read which name is listed before the first call | those agents pause and ask you to install it |

**Soft (the harness keeps working, with a named fallback or a reduced feature):**

| Tool | Used for | Without it |
|------|----------|-----------|
| **agent-browser** CLI + skill · [agent-browser.dev](https://agent-browser.dev/) | **default** browser driver for E2E / QA / smoke / exploration (requested or not) + headless Auth-Vault login (the password never reaches the LLM) | falls back to the Playwright `reference/e2e-testing.md` / `agentic-testing` path — never to `claude-in-chrome` |
| **Playwright** (`@playwright/test`, or the Playwright MCP) | the committed `.spec.ts` E2E suite, and the fallback driver when `agent-browser` is absent | with neither Playwright nor `agent-browser`, an optional Phase 4 smoke is recorded as unverified and queued for later QA; `/team-qa` marks browser-dependent scenarios blocked |
| **`jq`** | the `PostToolUse` hook reads its file path from the hook's stdin JSON; the guardrails hook parses its config | the post-edit warning hook (`console.*` / `debugger` / collection-bucket write checks) silently no-ops. `session-start.sh` prints one "jq not found" line per session so it fails loudly once instead of quietly forever. In a project with `guardrails.json`, git/gh commands are blocked (exit 2) until jq is installed |
| **`gh` CLI** | GitHub releases per version bump, and the `git-handler` agent's PR/issue work | do those steps by hand; nothing else is affected |

```bash
/plugin marketplace add pbakaus/impeccable && /plugin install impeccable@impeccable
npm i -g agent-browser && agent-browser install   # skill ships with the CLI
brew install jq                                   # apt install jq · winget install jqlang.jq
```

impeccable is expected to be installed before running the workflow. `jq` is worth installing on any machine that edits code — it is the only soft dependency whose absence has no in-session symptom other than the session-start line.

### First Run

```
/team-init                        # Scan project → generate .claude/project-profile/
/team "Add user authentication"   # Start a workflow
```

`/team-init` generates `.claude/project-profile/` in your project — all agents adapt to your stack and conventions.

## Codex support

Codex automatically discovers this repository's three `.agents/skills/` links
to the self-contained skills in `codex/skills/` when opened here. Invoke
`$harness-init` to profile an existing project, `$harness-team` for a
cross-cutting implementation, or `$harness-debug` for a bounded bug. Give the
target repository path in the request when it differs from the current working
directory. These are Codex skill names, not Claude slash commands. `AGENTS.md`
governs Codex work **on this repository**; a different project uses its own
`AGENTS.md` if present.

To use the skills in another repository, add this repository as a Codex plugin
marketplace source (`codex plugin marketplace add JunjaK/ai-harness`), install
`junjak-ai-harness` from `/plugins`, and start a new Codex session in the target
repository. The legacy marketplace file remains for Claude; the Codex marketplace
entry points to `codex/`, whose manifest selects only Codex skills and whose
hook is discovered inside that package. For local development, use
`codex plugin marketplace add /absolute/path/to/ai-harness`. Installation changes
the user's Codex plugin configuration; this repository does not write user-level
settings itself. See [OpenAI's plugin packaging and local marketplace guide](https://developers.openai.com/plugins/build/plugins).

| Codex entry point | Supported behavior |
|---|---|
| `$harness-init` | Scans an existing project and writes `.codex/project-profile/index.md` from observed files. |
| `$harness-team` | Implements a cross-cutting change, runs one lightweight verification pass (`VERIFY_PASS` / `VERIFY_FAIL` / `VERIFY_BLOCKED`), records up to five Deferred QA scenarios, and sweeps only the run's changed documents. It routes independent subagents by task complexity when available. |
| `$harness-debug` | Reproduces, traces, fixes, and verifies a bounded bug; escalates broad contract changes to the team skill. |
| Codex plugin `SessionStart` hook | Read-only reminder about stale `_docs/active/` documents, after Codex hook trust review. |
| Codex plugin `PreToolUse(Bash)` hook | Opt-in project guardrails: protected branch writes and configured forbidden command prefixes are denied. Claude `ask` rules also deny in Codex. |

The Codex adapter is at v1.32.0. `$harness-team` now follows Claude's
lightweight Phase 4 verdict and Phase 5 deferred QA/document contract, but
Codex does not have a separate `/team-qa` command; request execution of the
archived QA scenarios later. Codex does not write Claude session-state files.
If reading an existing Claude handoff, the current layout is
`.claude/session-state/sessions/<session_id>/` and
`.claude/session-state/runs/<plan-id>.json` (`owner_session`, `startedAt`,
`baseRef`); the old root files are retired.

The Codex adapter does not promise parity with Claude's `/team-new`,
`/team-brainstorm`, `/checkpoint`, personal `brain-connect`, 14 slash commands,
10 named agents, ultracode `Workflow()`, or the complete 5-phase state machine.
Claude `skills/` are intentionally not exposed to Codex as a set: several call
`Agent()`, `Skill()`, `Workflow()`, or Claude-only plugins. Codex subagents use
the runtime's own delegation tools rather than the Claude agent definitions.
Codex does not run Claude's `Stop`, `PreCompact`, or `PostToolUse` handlers,
which use Claude session state and tool input. Codex requires the user to
review and trust a plugin hook before it runs; the three skills work without
hook trust, but the guardrail is active only after hook trust. The branch
evaluator uses `bash` and `jq`; the Codex wrapper uses Python 3 standard
library. No package dependency is added.
Direct repository discovery requires Git symlink support; the plugin package
contains regular skill files.

## Customization

### Adapting to Your Stack

The agents are framework-agnostic by default. To specialize for your project:

1. **team-architect-fe.md** — Add your frontend conventions (component patterns, state management, styling)
2. **team-architect-be.md** — Add your backend conventions (API patterns, ORM, database)
3. **team-architect-infra.md** — Add your security checklist (auth patterns, env management)
4. **team-designer.md** — Add your test framework and TDD patterns
5. **team-tester.md** — Add your test runner commands and E2E setup

### Guardrails (optional)

A `PreToolUse(Bash)` hook blocks or confirms git writes on protected branches, including in `/team-run` subagents. It does nothing until the project has `.claude/project-profile/guardrails.json`; while a harness project has none, each session starts with a one-line suggestion.

```bash
cp "<plugin>/hooks/guardrails/presets/default.json" .claude/project-profile/guardrails.json
```

| Preset | Rules (root repo `"."`) |
|--------|-------------------------|
| `default.json` (recommended) | `main` `master` `prod` `prd` `production` → commit / push / merge **deny**; `stage` `staging` `dev` `develop` → **ask**; other branches allowed |
| `light.json` | production branches → **ask** |
| `toy.json` | no rules; copying it is an explicit opt-out and silences the session notice |

```json
{
  "version": 1,
  "repos": {
    ".":  { "branches": [ { "pattern": "main", "commit": "deny", "push": "deny", "merge": "deny" } ] },
    "be": { "branches": [ { "pattern": "stage", "commit": "ask", "push": "ask" } ] }
  }
}
```

- `repos` keys are repository paths relative to the project root, so each submodule can have its own rules. Linked worktrees of a repo use that repo's rules.
- `pattern` is a bash glob; when several rows match a branch, the strictest value wins. An omitted action is `allow`.
- **commit** covers `commit`, `merge`, `rebase`, `cherry-pick`, `revert`, `am`, `pull` on the current branch; **push** uses the refspec's destination (the current branch when omitted); **merge** is `gh pr merge`, judged by the PR's base branch (looked up with a 5 s limit).
- `cd dir && …`, `git -C dir`, and `git checkout/switch` earlier in the same command are followed. Anything the hook cannot resolve — `$(…)`, backticks, `sh -c`, `eval`, `xargs`, subshells, `cd "$VAR"`, detached HEAD, a failed PR lookup — gets the strictest rule for that action.
- In Claude, `ask` becomes `deny` under `bypassPermissions` or `dontAsk`, where no prompt can be shown. In Codex, every `ask` becomes `deny` because its `PreToolUse` hook does not support a confirmation decision.
- An invalid config blocks git/gh commands until it is fixed.

Forbidden commands that do not depend on the branch belong in Claude Code's own rules, which already split compound commands and subshells — for example in `.claude/settings.json`:

```json
{ "permissions": { "deny": ["Bash(pnpm test)", "Bash(pnpm test -- *)"] } }
```

For Codex, put branch-independent bans in the same project's
`.claude/project-profile/guardrails.json` as `"forbiddenCommands"`, an array of
literal command prefixes (the prefix covers any following arguments). For
example, add `"forbiddenCommands": ["pnpm test"]` beside `"repos"`. The
Codex hook checks compound commands, launch wrappers (`timeout`, `nice`,
`stdbuf` and others), shell `-c`, substitutions including backticks, variable
program names, and `xargs` for these prefixes. Unrecognized programs with a
visible forbidden command are denied; quoted literal text is ignored. Codex
`.rules` alone cannot cover commands that
stay inside its sandbox. To install a preset from the Codex plugin, copy
`<codex-plugin>/hooks/presets/default.json` (or `light.json` / `toy.json`) to
the project config path; the Claude plugin uses
`<claude-plugin>/hooks/guardrails/presets/`. If no config exists, neither hook
changes command behavior. Run `python3 codex/hooks/tests/run.py` and
`bash hooks/guardrails/tests/run.sh` to check both adapters.

Limits: the hook targets mistakes, not deliberate evasion (a script file or alias that runs `git push` is not seen). Codex tool hooks are not a complete enforcement boundary, and most subagent tool calls do not run this hook; keep server-side branch protection. Windows Git Bash and Codex Windows hook invocation are not yet verified. A generator command is still planned.

### Document Storage (3 buckets)

Documents are classified by **owner**, using a portable discriminator: *"swap the agent CLI — is this still meaningful?"* → yes = the project (`_` prefix at repo root); no = agent-only (`.claude/`). Byproducts that keep nothing go to `_workspace/`.

| Bucket | Owner | Holds |
|--------|-------|-------|
| `_docs/` | project | intent, plans, specs, ADRs — see the two-axis split below |
| `.claude/wiki/` | agent | an **LLM wiki** — compounding, interlinked knowledge (ingest / query / lint); links to the SSOT, never duplicates |
| `_workspace/` | throwaway | run output grouped by context — screenshots, Playwright traces/videos/reports, anything awkward to commit. Gitignored except `README.md`, which declares that project's layout |

`_docs/` top level carries **two kinds of bucket**, and only the first is lifecycle-managed:

| | Lifecycle | Collection |
|---|---|---|
| Base set | `active/{planning,processing}/` · `complete/` · `reference/` · `deprecated/` | `intent/` · `handoff/` |
| status↔folder lockstep | enforced | exempt |
| Sidecars merged on completion | yes | **never** |
| Agent may reorganize | yes | **no — append only** |

Collection buckets hold durable records whose value is being unaltered: `intent/` is the head of the `intent → spec → plan → impl` chain and the one artifact that survives rejection (rejected intents go to `intent/deprecated/`, in place). A project adds its own — `meetings/`, `inquiry/`, `proposal/` — by declaring them in its project profile, never ad hoc; the declaration also states what, if anything, the agent may rewrite there.

`_workspace/` exists because run artifacts kept landing at the repo root: a bare `page.screenshot({ path: 'shot.png' })` resolves to the project root, not to wherever the suite lives. Every throwaway file goes in `_workspace/<context>/` (E2E → `_workspace/e2e/<run>/`), never at the repo root or bare at `_workspace/` root. Auth/session state is **not** a byproduct and stays at the tool's own published path — for Playwright that is [`playwright/.auth/`](https://playwright.dev/docs/auth), also gitignored. The `session-stop` hook scans the repo root at session end and names any stray artifact it finds; it only warns — it never moves or deletes, since a root file may be deliberate.

Handoffs live in `_docs/handoff/` — the one collection the agent may prune, since keep-latest-per-stream is its defining contract. `/team-init` bootstraps `_workspace/README.md` and `.claude/wiki/`, and records the project's declared collection buckets in its profile. The rules live in the `docs-lifecycle` and `wiki` skills; `_docs/index.md` is updated on every plan change. Under worktree parallelization, `_docs/` stays in the **primary working tree** — worktree agents read and write doc files there by absolute path, and only `index.md` edits + status-moves are orchestrator-serialized, so plans stay readable from main without cd-ing into a worktree.

During a team run, quick-verification failures and blockers remain in the active `processing` plan with commands, outcomes, and the next fix/unblock action. A completed plan may contain pending `## Deferred QA` entries; `complete` records implementation completion, while each item has its own QA verdict. `/team-qa` updates those entries later with evidence. The wiki links to the record and changed code without copying their facts.

## Supporting Skills

Skills that agents reference during their workflow phases:

| Skill | Phase | Purpose |
|-------|-------|---------|
| `greenfield-bootstrap` | `/team-new` | G0 intake → G1 deep-research → G2 stack decision → G3 user gate → G4 scaffold → G5 seeded profile |
| `brainstorm` | Pre-Phase 1 (solo) | Lightweight solo design dialogue → `_docs/` design (no auto-commit); solo counterpart to `/team-brainstorm` |
| `debug` | Phase 3-4 | LSP-driven debugging patterns (TS) under the harness root-cause-first method; `/debug` carries the full method and red flags |
| `agentic-testing` | `/team-qa` | Adapter-based deferred QA: verify goals; generate deterministic tests when `--crystallize` is requested |
| `agent-browser-e2e` | **Default driver — any browser-driving task** | `agent-browser` is the first choice for E2E/QA/smoke/exploration/selector resolution, requested or not, plus headless login via its encrypted Auth Vault (no password reaches the LLM). One-time gate (CLI present + skill available), else fall back to Playwright — never silently, and never to `claude-in-chrome`. Playwright still owns the committed `.spec.ts` suite |
| `test-scenario-doc` | Human acceptance | Interactive human QA checklist HTML — on-demand via `/test-scenario-doc` |
| `contract-sync` | Phase 0 / BE→FE handoff | Regenerate a generated API client after a backend contract change, then type-check + cross-check consumption sites against it |
| `plan-visualizer` | **On-demand only** (`/plan-visualizer`) | HTML diagram of a plan (team, phases, files, deps) — fills the self-contained skeleton in `skills/plan-visualizer/resources/template.html`. No workflow phase generates one |
| `project-analyzer` | Setup | Project structure analysis → profile generation |
| `brain-connect` | Setup (per-machine) | Pair an optional personal **brain** SSOT with the harness — links global `CLAUDE.md`, `persona.md`, per-skill global skills, commands and auto-memory, plus a merged recommended-settings manifest and opt-in sync hooks; dependency-free, ships a generic connector template for both shells |

Cross-cutting skills (any phase): `continuous-learning`, `parallelization`, `checkpoint`, `docs-lifecycle`, `handoff`, `take-over`, `wiki`. Plus `submodule-worktree`, which fires only where the project profile records a Submodule Layout (`/team-init` writes it; a bare `.gitmodules` is not enough).

### Reference documents (`reference/*.md`) — read, don't invoke

Methodology bodies that agents cite by section rather than dispatch. They carry no skill frontmatter cost and are **not** invocable with the Skill tool: a citation like "(`verification-loop` §Baseline & Net-New)" means read `reference/verification-loop.md`. Rules that must fire unconditionally are inlined at their call sites instead.

| Document | Used by | Contents |
|----------|---------|----------|
| `reference/coding-standards.md` | Architects, Designers (Phase 1/3) | Universal code quality baseline (strict TS); §4 = YAGNI decision ladder |
| `reference/e2e-testing.md` | Tester (Phase 4) | Playwright E2E patterns, Page Object Model, flaky-test strategy |
| `reference/verification-loop.md` | Tester, Leader (Phase 4-5) | Changed-code quality gate (build, type, lint, unit/integration, one existing smoke E2E per affected flow, security, diff) + baseline-vs-net-new rules and explicit unavailable checks |
| `reference/plan-review.md` | Leader (Phase 1) | Critical plan review + pre-plan elicitation |
| `reference/token-optimization.md` | Any orchestrator | Model routing (incl. per-`agent()` Workflow routing), effort levels, compaction; §6 = 3-cycle retrieval protocol + six-element briefing contract |

Debugging methodology is harness-owned: `/debug` carries the root-cause-first method (Iron Law, red flags, escalation boundary) and the `debug` skill adds TS/LSP patterns. Parallel-agent decisions use the `parallelization` skill, and code review uses Claude Code's built-in `/code-review`. Neither needs an extra plugin.

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
├── commands/                    # 15 slash commands
│   ├── team-new.md              # /team-new
│   ├── team-init.md             # /team-init
│   ├── team.md                  # /team
│   ├── team-run.md              # /team-run
│   ├── team-qa.md               # /team-qa
│   ├── team-brainstorm.md       # /team-brainstorm
│   ├── debug.md                 # /debug
│   ├── checkpoint.md            # /checkpoint
│   ├── meta-prompt.md           # /meta-prompt
│   ├── worktree-deps.md         # /worktree-deps
│   ├── take-over.md             # /take-over
│   ├── docs-sweep.md            # /docs-sweep
│   ├── test-scenario-doc.md     # /test-scenario-doc
│   ├── plan-visualizer.md       # /plan-visualizer
│   └── brain-connect.md         # /brain-connect
├── hooks/
│   ├── hooks.json               # Plugin hook registration
│   ├── session-start.sh
│   ├── session-stop.sh          # Stop: stray-artifact warning only
│   ├── session-end.sh           # SessionEnd: snapshot this session's state, prune old sessions
│   ├── pre-compact.sh
│   ├── post-edit-warn.sh
│   ├── guardrails.sh            # PreToolUse(Bash) branch rules (opt-in)
│   └── guardrails/
│       ├── presets/             # default.json · light.json · toy.json
│       └── tests/run.sh         # table-driven hook tests
├── reference/                   # 5 methodology documents — read, never invoked
│   ├── coding-standards.md
│   ├── e2e-testing.md
│   ├── verification-loop.md
│   ├── plan-review.md
│   └── token-optimization.md
└── skills/                      # 19 workflow skills
    ├── team-workflow/
    ├── greenfield-bootstrap/
    ├── project-analyzer/
    ├── contract-sync/
    ├── docs-lifecycle/
    ├── handoff/
    ├── take-over/
    ├── wiki/
    ├── agentic-testing/
    ├── test-scenario-doc/
    ├── brainstorm/
    └── ... (8 more)
```

### CLAUDE.md Note

Plugins cannot inject `CLAUDE.md` into user projects. The `CLAUDE.md` at this repo root is the harness's always-on **router**: operating principles, the Renewal Mode Gate, routing rules, and hard-rule digests. It deliberately carries no inventory tables of skills / agents / commands — the runtime injects that metadata from each component's frontmatter automatically, so listing it there would only duplicate and drift. Users who want the full ruleset should copy relevant sections into their own project `CLAUDE.md`.

## Changelog

Full history: [CHANGELOG.md](./CHANGELOG.md). **Latest: v1.32.0** — no more
`superpowers` dependency: `/debug` carries its own root-cause-first method and
red flags, and the guardrails log slow or timed-out checks for diagnosis.
v1.31.2: the UI/UX agents accept a personal-skill `impeccable` install instead of stalling on the
plugin name. v1.31.1: the Codex
`forbiddenCommands` guardrail now catches launch wrappers, backticks, variable
program names, and visible forbidden commands inside programs it cannot
follow, while leaving quoted literal text alone. v1.31.0 aligned the Codex
adapter with Claude's lightweight verification and deferred QA workflow and
fixed protected-branch checks through launch wrappers.

## License

MIT
