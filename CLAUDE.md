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

- **Authoritative command, not an alias**: use the command recorded in project-profile `stack.md` → "Build & Verify" — the one that actually compiles app sources. A solution-style root `tsconfig.json` (`"files": []`) makes `bunx tsc --noEmit` a no-op that always exits 0; a typed-framework wrapper (`vue-tsc`, `astro check`) may catch what bare `tsc` misses. Confirm the command is not vacuous before trusting a green result.
- `tsconfig.json` MUST set `"strict": true` and `"noUncheckedIndexedAccess": true`
- **Zero net-new type errors vs the recorded baseline** before any phase completes. Greenfield (no baseline) = absolute zero. Legacy = net-new 0, compared by error signature (strip `file:line:col`), verified per file. (verification-loop §"Baseline & Net-New".)
- **Do not mask a type error that flags a real bug.** A type error can be correctly blocking an incomplete/wrong path; suppressing it with `as any`/`@ts-ignore` hides a runtime defect. The test for "safe to ignore" is "runtime stays correct," not "the red is gone."
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

## Cross-Boundary Contracts (generated clients)

When the frontend consumes a **code-generated** API client/types (OpenAPI, GraphQL codegen, gRPC, tRPC, Prisma — detect from project-profile `api-layer.md`):

- **Backend is the single source of truth** for types, models, and enums. The client **consumes** generated types and only **extends** them (interface-extends / `Omit`) for UI-only fields. MUST NOT hand-redefine a domain type to dodge a type error, and MUST NOT edit generated output to "match" the backend.
- **Regenerate before you verify.** Any task that changes a server contract (DB schema → response, request/response DTO, enum, endpoint shape) MUST run the `contract-sync` skill — make the spec current → regenerate → isolate churn → authoritative type-check → cross-check consumption sites — BEFORE writing or verifying client code. Type-checking against a stale generated client passes while being wrong, which is the most expensive failure mode.
- **Verify shape, not existence.** A green type-check proves internal consistency, not runtime shape. Confirm field names, nullability, nested access paths, and 1:1 enum mapping at the actual call sites.
- In team workflows this gate runs at the **BE→FE handoff** (Architect B's contract change → before Designers consume). See `skills/contract-sync/SKILL.md`.

---

## Authoritative Documentation (MCP)

Do not rely on training knowledge for version-sensitive or external-API facts — your knowledge has a cutoff and these drift. When the relevant MCP server is connected, consult it before implementing; if it is not connected, proceed but note the unverified assumption.

| Source | Consult for | Tools (if connected) |
|--------|-------------|----------------------|
| **Context7** | Library/framework/SDK APIs, config, version-migration, CLI usage | `mcp__context7__resolve-library-id` → `query-docs` |
| **MDN** | Web-platform facts: browser compatibility, Baseline status, Web API behavior, CSS/JS feature support, Core Web Vitals semantics | `mcp__mdn__search` / `get-doc` / `get-compat` |

Notes:
- Prefer these over web search for the domains above; prefer them over memory even for "well-known" APIs.
- If your environment defers MCP tool schemas, load the tool first (e.g. a tool-search step) before calling it.
- This is advisory, not a hard gate — it informs correctness, it does not block a phase. (Mirrors the user's global principle: consult official docs before implementing against SDKs/frameworks/APIs.)

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

## Document Storage (3 buckets)

Every document lives in one of three buckets, chosen by **owner** (not by name). Classify with the discriminator: *"If you swapped this agent CLI for another, would this doc still be meaningful?"* — Yes → project/human (repo root, `_` prefix); No, agent-only → `.claude/`.

| Bucket | Owner | Automation |
|--------|-------|-----------|
| `_docs/` | project | `docs-lifecycle` (auto-move, merge-on-complete, `git rm`) |
| `_note/` | human | **none — agent read-only** |
| `.claude/wiki/` | agent | `wiki` skill (ingest/query/lint) |

- **`_note/` is human-owned and agent read-only.** MUST NOT create, move, merge, reorganize, or delete under `_note/` on your own initiative — modify it ONLY on the human's explicit request; otherwise read for context and leave it untouched. It is exempt from `_docs/` lifecycle and frontmatter.
- The discriminator and `_note/` governance detail live in `skills/docs-lifecycle/SKILL.md` (Three-bucket section).

## Plan Storage

`_docs/` is the **project** bucket (above). Layout:

```
_docs/
├── index.md                        # MUST update when adding any plan
├── {category}/
│   ├── plan-{feature}.md           # Plan document
│   └── plan-{feature}.visual.html  # Auto-generated visual diagram
```

Documents follow a lifecycle (`planning → processing → complete → reference`, or `→ deprecated`) with `status` in frontmatter kept in **lockstep with the folder**, and a task's sidecar docs (spec + plan + metrics + findings) **merged into one document on completion**. See `skills/docs-lifecycle/SKILL.md` — apply it at every phase transition and before marking work complete.

**Handoff documents** (state layer for passing work to another agent/session) live in `_docs/handoff/` (flat, dated `YYYY-MM-DD-<topic>-handoff.md`), link to their spec via `related:`, and keep only the latest per work-stream (`git rm` superseded ones). See `skills/docs-lifecycle/SKILL.md` §"Handoff documents".

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
| team-agentic-tester | Opus 4.7 | Phase 4.5 agentic testing (explore-gate + deterministic test generator) |
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
| docs-lifecycle | All | `_docs/` status↔folder lifecycle + 3-bucket model + merge sidecar docs into one on completion |
| wiki | All | Agent wiki (`.claude/wiki/`) — compounding knowledge base: ingest/query/lint, link-don't-duplicate |
| coding-standards | Phase 3 | Code quality baseline (strict TS) |
| tdd-workflow | Phase 3 | Red-Green-Refactor cycle (Vitest 4.x) |
| debug | Phase 3-4 | LSP-driven debugging patterns (TS) |
| e2e-testing | Phase 4 | Playwright E2E |
| agentic-testing | Phase 4.5 | Adapter-based agentic E2E: explore goal → verify → crystallize deterministic test |
| verification-loop | Phase 4-5 | 6-phase quality gate + checkpoints + pass@k + baseline/net-new + vacuity guard |
| contract-sync | Phase 0 / BE→FE handoff | Regenerate generated API client after a contract change → isolate churn → authoritative type-check → cross-check consumption sites |
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
| `continuous-learning` | Write `current.md` during session; extract patterns after milestones; **reuse** them at task start (load + route into agent briefings, promote project-stable ones to the profile); evolve to skill after 3+ high-confidence learnings; maintain the knowledge base (link don't duplicate, same change updates the doc) |
| `checkpoint` | Auto-save on Stop hook + Pre-Compact hook; manual `/checkpoint save [title]` at any time |
| `verification-loop` | 6-phase gate (build/type/lint/test/security/diff); authoritative (non-vacuous) commands; gate type/lint on net-new vs baseline; pass@1 ≥ 80% for tests, pass^3 = 100% for security |
| `contract-sync` | When a contract change meets a generated client: regenerate → isolate churn → authoritative type-check (net-new) → verify consumption shape, BEFORE verifying client code; backend is SSOT, never edit generated output |
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

`impeccable` is distributed as a **Claude Code plugin** (`pbakaus/impeccable`) exposing a single skill. The skill handle is `impeccable:impeccable` (plugin:skill); sub-commands are passed in the `args` parameter:

```
Skill(skill="impeccable:impeccable", args="<sub-command> [target]")
```

The sub-command goes in `args`, NOT in the namespace — MUST NOT call `Skill(skill="impeccable:shape", ...)` (that conflates sub-command with skill name and will fail). Legacy installs as a personal skill at `~/.claude/skills/impeccable/` use the bare handle `skill="impeccable"`. If impeccable is not registered, abort and request the user install the `pbakaus/impeccable` plugin.

| Harness agent | Sub-commands used (passed as `args`) |
|---------------|------------------------------------|
| `team-uiux-master` | `shape`, `craft`, `extract`, `critique`, `audit`, `typeset`/`layout`/`colorize`/`animate`/`adapt`/`clarify`/`optimize`, `bolder`/`quieter`/`distill`/`delight`/`polish`/`overdrive` |
| `web-architect` | `shape` (when planning visual elements) |
| `web-reviewer` | `audit` (a11y + perf + theming + responsive), `critique` (UX), `polish` (final pass) |

Harness-specific supplements that are NOT in impeccable:
- AI Slop Detection (9 patterns) — in `web-reviewer-resources/checklists.md`
- Harness output format + team-workflow Phase integration
- Pre-delivery checklist tuned for Opus 4.7 literal evaluation

### Code minimalism via `ponytail` plugin

Code-bloat avoidance is delegated to the **ponytail** Claude Code plugin (YAGNI decision ladder — "the best code is the code you never wrote"). The harness does NOT reimplement it.

- **Disposition (design-time)**: the YAGNI Decision Ladder is distilled into `coding-standards` §4 and applied by the build-deciding agents (`team-architect-fe/be/infra`, `team-designer`, `web-architect`). It lives in their definitions + a referenced skill so it reaches spawned subagents — plugin auto-inject alone does not.
- **Review (code-time)**: Phase 4 Tester runs `/ponytail-review` on the diff; `team-leader` synthesizes the result at its approval gate (Phase 1 `plan-review` YAGNI dimension + Phase 4 `/ponytail-review`).
- **Strong runtime dependency** (same pattern as impeccable): if a `/ponytail-review` invocation fails, ABORT and request `/plugin install ponytail@ponytail`. NOT declared in `plugin.json` dependencies — external-marketplace manifest deps break plugin load (commit 5522155).
- **Guard**: minimalism applies to *solution complexity only*. Tests, validation, security, and accessibility are gated hard elsewhere (TDD, verification-loop, Phase 5) and are never trimmed ("lazy, not negligent").

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

## Operational Discipline

- **Shared/external infra is the human's to start.** Do NOT auto-open tunnels to, or start, shared/managed infrastructure (cloud DB, managed cache, bastion, VPN). If such a dependency is down, surface a one-line "please start X" and proceed where you can — do not script around it or repeatedly probe it. Starting shared infra is scope escalation an agent should not self-authorize.
- **Watch-mode dev servers: stop them during edit sessions.** A hot-reloading dev server recompiles on every file save, spiking CPU/memory while you edit. Stop the watched server during an editing session; restart it only when a step (codegen, smoke test, manual verify) actually needs it.
- **Shell exit-code hygiene for quiet commands.** A command with no stdout piped into a filter (`… | grep …`) can exit non-zero on empty input — a false failure. Capture the exit code directly (`cmd > out 2>&1; rc=$?`) instead of inferring success through a masking pipe. (PowerShell: `-ErrorAction SilentlyContinue` suppresses error *output* but the cmdlet failure still sets exit 1 — wrap in `try { … -ErrorAction Stop } catch {}` to truly ignore.)
- **Local-vs-production is the gate for destructive ops**, not the operation type: a destructive command against a verified-local target (localhost) may run without per-command confirmation; any command naming a production/remote endpoint always requires explicit confirmation.

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
