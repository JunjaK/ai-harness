# AI Harness — Claude Code Configuration

> Tuned for **Claude Opus 4.7** (released 2026-04-16). Every directive below is literal. There are no implicit "use judgment" clauses.

---

## Opus 4.7 Operating Principles

These apply to all agents, skills, commands, and direct use.

### 1. Literal Instruction Following
Opus 4.7 interprets every directive literally. Previously tolerated ambiguity is now a bug source.

| Do NOT write | Write instead |
|--------------|--------------|
| "Keep it simple" | "MUST NOT add abstractions without 3+ current callers" |
| "Include tests if needed" | "MUST write tests before implementation for every public function" |
| "Do your best" | "MUST [specific action with success criteria]" |
| "When appropriate" | "[specific trigger condition]" |
| "As needed" | "[explicit rule or list]" |
| "Consider X" | "MUST evaluate X against [criteria] and report decision" |

**Rule**: Replace every ambiguous modifier with a specific condition or quantifiable criterion before shipping a prompt.

### 2. Effort Levels

Opus 4.7 adds `xhigh` between `high` and `max`. Claude Code defaults to `xhigh`.

| Effort | Use for |
|--------|---------|
| `high` | Mechanical edits (rename, format, import fix) |
| `xhigh` | Default — all coding, planning, review |
| `max` | Debugging hard failures, autonomous multi-step tasks, architecture with long-term impact |

**Routing rule**: Start with `xhigh`. Upgrade to `max` only after `xhigh` fails twice on the same task.

### 3. Tool Use Improvements
Opus 4.7 has ~33% fewer tool errors and stronger loop resistance. Policy:
- On tool failure: retry once, then proceed with an alternate approach (do not abandon task)
- On suspected loop: pause, summarize progress, re-plan

### 4. File System as Memory
The harness uses the file system as persistent memory (`session-state/`, `checkpoints/`, `_docs/`). This aligns with Opus 4.7's design for multi-session workflows.

### 5. Tokenizer Changes
Same input ≈ 1.0–1.35× Opus 4.6 tokens. Higher effort levels produce more reasoning tokens. Re-measure token budgets against 4.7, not 4.6 baselines.

---

## TypeScript-First

This harness assumes TypeScript as the primary language. All agents and skills operate under the following defaults:

### Type Check (hard gate)

- Primary: `bunx tsc --noEmit` (via verification-loop Phase 2)
- `tsconfig.json` MUST set `"strict": true` and `"noUncheckedIndexedAccess": true`
- Zero type errors required before any phase completes
- `any` types are prohibited — use `unknown` + narrowing, or define explicit types

### LSP Tool (code intelligence)

The LSP tool provides code navigation for TypeScript files. Use it during implementation and debugging — NOT as a replacement for `tsc`.

| Operation | Use when |
|-----------|----------|
| `hover` | Checking a symbol's inferred type before editing |
| `goToDefinition` | Finding where a symbol is declared before modifying |
| `findReferences` | Identifying all callers before refactoring a function's signature |
| `goToImplementation` | Finding concrete implementations of an interface |
| `documentSymbol` | Getting an outline of a file before deep analysis |
| `workspaceSymbol` | Broad codebase search for a symbol by name |
| `incomingCalls` / `outgoingCalls` | Tracing call graphs before refactoring |

**Rule**: Designers MUST use `findReferences` before modifying any exported function's signature. Skipping this risks breaking callers silently.

### IDE Diagnostics (when available)

If `mcp__ide__getDiagnostics` is available (IDE is connected), MAY use it as a faster complement to `tsc` during implementation. It does NOT replace the final `tsc --noEmit` gate.

### Fallback: Non-TypeScript Projects

If the target project is not TypeScript (e.g., pure JavaScript, Python, Go):
- Skip LSP-TypeScript-specific steps
- Use the project's native type checker (`pyright`, `mypy`, `go vet`, etc.) from `stack.md`
- Verification-loop Phase 2 adapts to the project's type check command

---

## Package Manager

### Priority (MUST detect in this order)

1. **Bun** (default) — detect via `bun.lockb` or `bun.lock`
2. **pnpm** (first fallback) — detect via `pnpm-lock.yaml`
3. **npm** (final fallback) — detect via `package-lock.json`

If no lockfile exists, default to Bun.

### Command Translation Table

| Action | Bun (default) | pnpm | npm |
|--------|--------------|------|-----|
| Install deps | `bun install` | `pnpm install` | `npm install` |
| Run package.json script | `bun run <script>` | `pnpm run <script>` | `npm run <script>` |
| Execute package binary | `bunx <cmd>` | `pnpm exec <cmd>` | `npx <cmd>` |
| Add dependency | `bun add <pkg>` | `pnpm add <pkg>` | `npm install <pkg>` |
| Add dev dependency | `bun add -d <pkg>` | `pnpm add -D <pkg>` | `npm install -D <pkg>` |
| Audit | `bun audit` | `pnpm audit` | `npm audit` |

### Rule

- Every shell command in agent outputs, skills, and docs MUST use Bun by default
- If the target project uses pnpm or npm (detected via lockfile in project-profile), translate commands to that manager
- MUST NOT mix managers within a single project (never `npm install` in a Bun project)

---

## Required: Agent Teams Feature

This harness requires Claude Code Agent Teams. Enabled via `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

If not set, `/team`, `/team-run`, and `/team-brainstorm` will not function (they depend on `TeamCreate`, cross-review dialog, and multi-agent orchestration).

---

## First Run: Project Analysis

Before using any team command:

```
/team-init          # Analyze project → generate .claude/project-profile/
/team-init --update # Refresh after major changes
```

Generates `.claude/project-profile/` with 9 profile documents that every agent reads.

---

## Commands

| Command | Use when |
|---------|---------|
| `/team-init` | Project not yet analyzed (no `.claude/project-profile/`) |
| `/team-brainstorm <task>` | Plan-only discussion, no code changes |
| `/team <task>` | Full workflow with user involvement in planning |
| `/team-run <task>` | Full autonomous workflow |
| `/checkpoint` | Save/restore work state (NOT Claude Code's built-in `/resume`) |

### Decision Guide

```
Resuming previous work?
  YES → /checkpoint

First time in this project?
  YES → /team-init (MUST run before any /team* command)

Task matches ANY of:
  - Modifies 3+ files
  - Touches cross-cutting concerns (API + UI + state)
  - Involves auth, payments, or sensitive data
  - Is user-facing feature
  YES → /team or /team-run

Task has architectural uncertainty (multiple valid approaches)?
  YES → /team-brainstorm first, then /team-run

Task is single-file trivial (typo, config, one-line fix)?
  YES → Direct implementation allowed
  NO  → MUST use /team, /team-run, or /team-brainstorm
```

---

## Plan Storage

```
_docs/
├── index.md                        # MUST update when adding any plan
├── {category}/
│   ├── plan-{feature}.md           # Plan document
│   └── plan-{feature}.visual.html  # Auto-generated visual diagram
```

---

## Agents

All agents live in the plugin's `agents/` directory and are invoked by the `team-workflow` skill via the Agent tool (`subagent_type: <agent-name>`).

| Agent | Model | Role |
|-------|-------|------|
| team-leader | Opus 4.7 | Coordination, planning, approval gates |
| team-architect-fe | Opus 4.7 | Frontend architecture |
| team-architect-be | Opus 4.7 | Backend architecture |
| team-architect-infra | Opus 4.7 | Infra/security (on-demand + final review) |
| team-uiux-master | Opus 4.7 | UI/UX design intelligence |
| team-designer | Opus 4.7 | TDD implementation (Red-Green-Refactor) |
| team-tester | Sonnet 4.6 | Unit + E2E test verification |
| web-architect | Opus 4.7 | Web architecture design (components, state, API, perf) |
| web-reviewer | Sonnet 4.6 | Web quality audit (A11y, CWV, SEO, design, AI Slop) |

All Opus agents default to `xhigh` effort. Sonnet agents use their model's default.

---

## Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| team-workflow | Core | 5-phase orchestration |
| plan-review | Phase 1 | Adversarial plan evaluation |
| plan-visualizer | Phase 1+ | HTML plan diagram |
| coding-standards | Phase 3 | Code quality baseline (strict TS) |
| tdd-workflow | Phase 3 | Red-Green-Refactor cycle (Vitest 4.x) |
| debug | Phase 3-4 | LSP-driven debugging patterns (TS) |
| e2e-testing | Phase 4 | Playwright E2E |
| verification-loop | Phase 4-5 | 6-phase quality gate + checkpoints + pass@k |
| security-review | Phase 5 | OWASP checklist + Phase 5 audit format |
| token-optimization | All | Model routing, effort levels, compaction (Opus 4.7 aware) |
| continuous-learning | All | Pattern extraction, session state, skill evolution |
| parallelization | Phase 3+ | Worktree management, cascade method, scaling |
| subagent-orchestration | All | Iterative retrieval, context briefing, phase pipeline |
| checkpoint | All | Save/restore work state across sessions |
| project-analyzer | /team-init | Generate project profile (9 files) |

---

## Agent Execution Mode

Agents spawned by the team workflow MUST use:
- `mode: "bypassPermissions"` (agents work in isolated worktrees)
- `isolation: "worktree"` for Designers (parallel-safe work)
- `TeamCreate` for cross-review dialog (not separate Agent calls)

---

## Escalation Rules

- Each agent classifies issues as **Simple Fix** or **Fundamental Issue** using deterministic criteria in `skills/team-workflow/resources/escalation.md`
- Per-phase retries: max 3
- Global re-plan cycles: max 3 → ABORT on exceed
- Every escalation MUST be reported to the user in the required format
- Ambiguous cases default to Fundamental Issue (escalate up)

---

## Operational Skills (load on demand)

These skills carry the full details; this file only lists hard rules.

| Skill | Hard rule summary |
|-------|------------------|
| `token-optimization` | Model routing by task class; `xhigh` default effort; MCPs <10, tools <80; compact after milestones only |
| `continuous-learning` | Write `current.md` during session; extract patterns after milestones; evolve to skill after 3+ high-confidence learnings |
| `checkpoint` | Auto-save on Stop hook + Pre-Compact hook; manual `/checkpoint save [title]` at any time |
| `verification-loop` | 6-phase gate (build/type/lint/test/security/diff); pass@1 ≥ 80% for tests, pass^3 = 100% for security |
| `parallelization` | Max 5 worktrees, zero file overlap, merge order: types → backend → frontend → tests |
| `subagent-orchestration` | 3-cycle retrieval cap; every prompt MUST include What/Why/Where/Context/Constraints/Already-tried |

### Active Hooks

| Hook | Event | Script |
|------|-------|--------|
| Session Stop | `Stop` | `hooks/session-stop.sh` |
| Pre-Compact | `PreCompact` (auto) | `hooks/pre-compact.sh` |
| Post-Edit Warn | `PostToolUse` (Edit\|Write) | `hooks/post-edit-warn.sh` |

Registered via `hooks/hooks.json` using `${CLAUDE_PLUGIN_ROOT}` for absolute paths.

### Session State Layout

```
.claude/session-state/
├── current.md              # Active session (write during work)
├── last-session.md         # Previous (auto-rotated by Stop)
├── archive/                # Older (max 20, 7-day TTL)
├── checkpoints/            # Milestone snapshots (max 10 + latest.md)
└── learnings/              # Extracted patterns
```

---

## Claude Code Built-in Commands (rely on, don't duplicate)

These built-ins are the canonical tools for their domain. The harness does NOT wrap them.

| Built-in | Use for | Notes |
|----------|---------|-------|
| `/effort <level>` | Set effort: `low` / `high` / `xhigh` / `max` | Default for coding work is `xhigh`. Use `max` for hard debugging or architecture. |
| `/model <name>` | Switch model | Use Opus 4.7 for Phase 1/3, Sonnet 4.6 for Phase 4 Tester, Haiku for broad search. |
| `/fast` | Toggle fast mode | Opus 4.6 only. Opus 4.7 already runs `xhigh` by default. |
| `/compact [focus]` | Manual context compaction | `pre-compact.sh` hook auto-saves checkpoint before running. MUST NOT run mid-implementation. |
| `/resume <id>` | Resume a previous conversation | Distinct from our `/checkpoint` (work-state), which is session-independent. |
| `/branch` | Fork conversation | Use for research forks while main work continues. |
| `/memory` | Edit memory files | Our `.claude/session-state/` is separate; do not mix. |
| `/review` | Local PR review | Complementary to team workflow Phase 5. |
| `/security-review` | Scan diff for vulns | Runs alongside our `security-review` skill in Phase 5. |
| `/simplify` | 3-agent code review | Invoke after Phase 3 for an independent second look. |
| `/cost`, `/context` | Token usage + context grid | Check before deciding to compact. |
| `/rewind` | Roll back conversation or code | Use when an agent's output is structurally wrong and targeted editing will not recover. |

### UI/UX delegation to `impeccable` skill

UI/UX quality is delegated to the `impeccable` skill. The harness does NOT reimplement its design guidance.

`impeccable` is a **single personal skill** (installed at `~/.claude/skills/impeccable/`), NOT a Claude Code plugin with namespaced sub-skills. Sub-commands are passed as the `args` parameter:

```
Skill(skill="impeccable", args="<sub-command> [target]")
```

MUST NOT call `Skill(skill="impeccable:shape", ...)` — that namespace does not exist and will fail. If the skill is not registered, abort and request the user install it.

| Harness agent | Sub-commands used (passed as `args`) |
|---------------|------------------------------------|
| `team-uiux-master` | `shape`, `craft`, `extract`, `critique`, `audit`, `typeset`/`layout`/`colorize`/`animate`/`adapt`/`clarify`/`optimize`, `bolder`/`quieter`/`distill`/`delight`/`polish`/`overdrive` |
| `web-architect` | `shape` (when planning visual elements) |
| `web-reviewer` | `audit` (a11y + perf + theming + responsive), `critique` (UX), `polish` (final pass) |

Harness-specific supplements that are NOT in impeccable:
- AI Slop Detection (9 patterns) — in `web-reviewer-resources/checklists.md`
- Harness output format + team-workflow Phase integration
- Pre-delivery checklist tuned for Opus 4.7 literal evaluation

### Built-in skills we rely on (do NOT duplicate)

| Built-in skill | Use for | Our equivalent or complement |
|---------------|---------|-----------------------------|
| `superpowers:systematic-debugging` | General reproduce → narrow → hypothesize → test methodology | Our `debug` skill covers LSP-specific TS patterns on top |
| `superpowers:verification-before-completion` | "evidence before claims" discipline | Invoked by Designers before reporting completion |
| `superpowers:using-git-worktrees` | Worktree creation details | Our `parallelization` skill covers scaling + cascade on top |
| `superpowers:dispatching-parallel-agents` | When to parallelize 2+ independent tasks | Complementary to our `subagent-orchestration` |
| `superpowers:test-driven-development` | General TDD discipline | Our `tdd-workflow` adds Vitest 4.x specifics |
| `superpowers:requesting-code-review` | Pre-merge review checklist | Complementary to Phase 5 |

Agents MAY invoke these built-ins directly when a task matches their trigger. Do NOT reimplement their content in our skills.

---

## Safety & Security

- MUST NOT commit secrets (API keys, tokens, passwords) — use env vars via config module
- MUST NOT use `eval`, `new Function`, `innerHTML` with unsanitized input
- MUST sanitize user input before rendering or DB insert
- MUST parameterize every SQL query
- Phase 5 security audit is MANDATORY for every team workflow

---

## Scope Discipline

Direct implementation is allowed ONLY when ALL apply:
- Task touches 1 file
- Fix is obvious and mechanical
- No test/type/lint regression expected
- No security or data integrity impact

Everything else MUST go through the team workflow.
