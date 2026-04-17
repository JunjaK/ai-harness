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

All agents live in `.claude/agents/` and are invoked by the `team-workflow` skill.

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
| api-design | Phase 1 | REST API patterns |
| plan-visualizer | Phase 1+ | HTML plan diagram |
| coding-standards | Phase 3 | Code quality baseline |
| tdd-workflow | Phase 3 | Red-Green-Refactor cycle |
| debug | Phase 3-4 | Structured debugging |
| e2e-testing | Phase 4 | Playwright E2E |
| verification-loop | Phase 4-5 | 6-phase quality gate + checkpoints + pass@k |
| security-review | Phase 5 | OWASP checklist |
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

- Each agent classifies issues as **Simple Fix** or **Fundamental Issue** using deterministic criteria in `.claude/skills/team-workflow/resources/escalation.md`
- Per-phase retries: max 3
- Global re-plan cycles: max 3 → ABORT on exceed
- Every escalation MUST be reported to the user in the required format
- Ambiguous cases default to Fundamental Issue (escalate up)

---

## Token Optimization

Settings (`settings.json`):
```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"
  }
}
```

### Model Selection (required for every Agent spawn)

| Task | Model | Rationale |
|------|-------|-----------|
| File search, exploration | Haiku 4.5 | Cheapest for read-only work |
| Code implementation, review | Sonnet 4.6 | Balance of speed and quality |
| Architecture, security, 5+ files | Opus 4.7 | Deep multi-file reasoning |

### Context Efficiency (hard rules)

- MUST keep enabled MCP servers under 10
- MUST keep active tools under 80
- MUST NOT compact mid-implementation (lose variable state)
- MUST use `run_in_background: true` for commands expected to run > 30 seconds

See skill: `token-optimization`.

---

## Memory Persistence & Session State

### Active Hooks

| Hook | Event | Script | Purpose |
|------|-------|--------|---------|
| Session Stop | `Stop` | `.claude/hooks/session-stop.sh` | Auto-checkpoint + archive session state |
| Pre-Compact | `Notification` (autocompact) | `.claude/hooks/pre-compact.sh` | Auto-checkpoint + remind to save state |
| Post-Edit Warn | `PostToolUse` (Edit, Write) | `.claude/hooks/post-edit-warn.sh` | Detect console.log, debugger, TODO markers |

### Session State Files

```
.claude/session-state/
├── current.md              # Active session state (write during session)
├── last-session.md         # Previous session (auto-rotated by Stop hook)
├── archive/                # Older sessions (max 20, 7-day TTL)
├── checkpoints/            # Verification snapshots at milestones
│   ├── latest.md           # Always most recent
│   └── checkpoint-*.md     # Timestamped (max 10)
└── learnings/              # Extracted reusable patterns
```

### Lifecycle

```
Session start → Stop hook injects last-session.md into context
During session → Write/update current.md
Before compact → pre-compact.sh auto-saves checkpoint
Session end → Stop hook: save checkpoint → archive current.md
```

---

## Continuous Learning

Extract reusable patterns via skill: `continuous-learning`.

| Trigger | Action |
|---------|--------|
| Milestone completed | Extract patterns to `.claude/session-state/learnings/{topic}.md` |
| Before compacting | Save verified approaches + key decisions to `current.md` |
| Session ends | Stop hook saves checkpoint + archives state |
| 3+ related learnings (all 4 criteria met) | Evolve into new SKILL.md |

### Confidence Scoring

- **Low** (1 session): Keep as pending, monitor
- **Medium** (2–3 sessions): Promote to active
- **High** (validated repeatedly): Candidate for skill evolution

---

## Verification Checkpoints & Metrics

Enhanced `verification-loop` supports checkpoints and pass@k metrics.

### Checkpoint Triggers (MUST save when ANY applies)

| Trigger | Checkpoint Name |
|---------|----------------|
| Phase 1 plan finalized | `phase1-baseline` |
| Designer completes TDD cycle | `phase3-worktree-{name}` |
| All worktrees merged | `phase3-integration` |
| Phase 4 verification passes | `phase4-verified` |
| Before PR (Phase 5) | `phase5-final-gate` |

### Pass@k Targets (hard gates)

| Metric | Target | Scope |
|--------|--------|-------|
| pass@1 ≥ 90% | Build, type check, lint | MUST almost never fail |
| pass@1 ≥ 80% | Tests | Allows documented flaky tests |
| pass@3 ≥ 95% | Full verification loop | ≥ 1 of 3 runs MUST be clean |
| pass^3 = 100% | Security scan | Every run MUST pass |

---

## Parallelization

### Worktree Rules (hard caps)

- Max 5 active worktrees
- Zero file overlap between worktrees (hard rule)
- Merge order: shared types → backend → frontend → tests
- Clean up worktrees after merge: `git worktree remove`

### Cascade Method (Multiple Claude Code Instances)

- Max 3–4 concurrent instances
- Each instance owns a disjoint file set
- Sweep left → right for oversight
- Use separate instances for research; MUST NOT overlap edits

See skill: `parallelization`.

---

## Subagent Orchestration

### Iterative Retrieval (hard cap: 3 cycles)

```
Cycle 1: Broad retrieval (Haiku)     → evaluate gates
Cycle 2: Contextual query (Sonnet)   → evaluate gates
Cycle 3: Refined execution (Sonnet/Opus)
```

Gates are explicit (see `subagent-orchestration` skill). An agent that fails both gates after Cycle 2 is escalated, not retried a fourth time.

### Context Briefing (MUST include in every subagent prompt)

- **What**: Specific task
- **Why**: Motivation and downstream impact
- **Where**: Files and line ranges
- **Context**: Relevant surrounding system info
- **Constraints**: Hard rules the subagent MUST follow
- **Already-tried**: What didn't work

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
