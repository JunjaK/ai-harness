# AI Harness — Claude Code Configuration

## Required: Agent Teams Feature

**This harness requires Claude Code Agent Teams.** The feature is enabled via `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

If this env variable is not set, `/team`, `/team-run`, and `/team-brainstorm` commands will NOT work properly (TeamCreate, cross-review dialog, and multi-agent orchestration depend on it).

---

## First Run: Project Analysis

**Before using any team command, run `/team-init` once** to analyze the project:

```
/team-init          # Full analysis → generates .claude/project-profile/
/team-init --update # Refresh after major changes
```

This generates `.claude/project-profile/` with 9 profile documents that all agents reference to follow your project's conventions.

---

## Team Workflow Commands (MUST USE)

**All feature implementation, bug fixes, and refactoring MUST go through the team workflow.**

| Command | When to Use |
|---------|-------------|
| `/team-init` | First run — analyze project structure |
| `/team-brainstorm` | Planning/discussion only — no code changes |
| `/team` | Full workflow with user involvement in planning |
| `/team-run "description"` | Full autonomous workflow |
| `/checkpoint` | Save/restore work state (custom command — does NOT conflict with built-in `/resume`) |

### Decision Guide

```
Resuming previous work?
  YES → /checkpoint (loads latest work state — distinct from Claude Code's built-in /resume)

First time in this project?
  YES → /team-init first

Is this a complex feature (3+ files, cross-cutting)?
  YES → /team or /team-run
  NO  → Is there architectural uncertainty?
    YES → /team-brainstorm first, then /team-run
    NO  → Direct implementation is OK for trivial changes (typo, config)
```

**Trivial changes** (single file, obvious fix) do NOT require team workflow.
**Everything else** MUST use `/team`, `/team-run`, or `/team-brainstorm`.

---

## Plan Storage

All plans are saved to `_docs/` with visual HTML alongside:

```
_docs/
├── index.md                        # Always update when adding plans
├── {category}/
│   ├── plan-{feature}.md           # Plan document
│   └── plan-{feature}.visual.html  # Visual diagram (auto-generated)
```

---

## Agents

All agents are defined in `.claude/agents/` and invoked by the team-workflow skill.

| Agent | Model | Role |
|-------|-------|------|
| team-leader | opus | Coordination, planning, approval gates |
| team-architect-fe | opus | Frontend architecture |
| team-architect-be | opus | Backend architecture |
| team-architect-infra | opus | Infra/security (on-demand + final review) |
| team-uiux-master | opus | UI/UX design intelligence |
| team-designer | opus | TDD implementation (Red-Green-Refactor) |
| team-tester | sonnet | Unit + E2E test verification |
| **web-architect** | **opus** | **Web architecture design (components, state, API, perf)** |
| **web-reviewer** | **sonnet** | **Web quality audit (A11y, CWV, SEO, design, AI Slop)** |

---

## Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| team-workflow | Core | 5-phase orchestration |
| plan-review | Phase 1 | Critical plan evaluation |
| api-design | Phase 1 | REST API patterns |
| plan-visualizer | Phase 1+ | HTML plan diagram |
| coding-standards | Phase 3 | Code quality baseline |
| tdd-workflow | Phase 3 | TDD cycle |
| debug | Phase 3-4 | Structured debugging |
| e2e-testing | Phase 4 | Playwright E2E |
| verification-loop | Phase 4-5 | 6-phase quality gate |
| security-review | Phase 5 | OWASP checklist |

---

## Agent Execution Mode

When spawning agents via Team workflow:
- **Always use `mode: "bypassPermissions"`** — agents work in isolated worktrees
- **Designers use `isolation: "worktree"`** for parallel work
- **Cross-review uses `TeamCreate`** for multi-agent dialog

---

## Escalation Rules

- Each agent self-judges: simple fix (retry, max 3) vs fundamental (escalate)
- Global re-plan limit: 3 cycles
- Both `/team` and `/team-run` report escalation events to user
- See `.claude/skills/team-workflow/resources/escalation.md` for details

---

## Token Optimization

Model routing and context efficiency settings are active via `settings.json`:

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"
  }
}
```

### Model Selection Guide

| Task | Model | Rationale |
|------|-------|-----------|
| File search, exploration | Haiku | Cheapest for read-only work |
| Code implementation, review | Sonnet | Balance of speed/quality |
| Architecture, security, 5+ files | Opus | Deep multi-file reasoning |

### Context Efficiency

- Keep under 10 MCP servers enabled, under 80 tools active
- Compact after milestones, NEVER mid-implementation
- Use `run_in_background: true` for builds/tests
- See skill: `token-optimization` for full guide

---

## Memory Persistence & Session State

### Hooks (Active)

| Hook | Event | Script | Purpose |
|------|-------|--------|---------|
| Session Stop | `Stop` | `.claude/hooks/session-stop.sh` | Auto-checkpoint + archive session state |
| Pre-Compact | `Notification` | `.claude/hooks/pre-compact.sh` | Auto-checkpoint + remind to save state |
| Post-Edit Warn | `PostToolUse` | `.claude/hooks/post-edit-warn.sh` | Detect console.log, debugger, TODO markers |

### Session State Files

```
.claude/session-state/
├── current.md              # Active session state (write during session)
├── last-session.md         # Previous session (auto-rotated by Stop hook)
├── archive/                # Older sessions (auto-cleaned, max 20, 7-day TTL)
├── checkpoints/            # Verification snapshots at milestones
└── learnings/              # Extracted reusable patterns
```

### Lifecycle

```
Session start → Load last-session.md (if exists)
During session → Write/update current.md
Before compact → Save critical state to current.md
Session end → Stop hook: current.md → last-session.md → archive
```

---

## Continuous Learning

Extract and evolve reusable patterns from sessions. See skill: `continuous-learning`.

### Key Actions

| When | Action |
|------|--------|
| After completing a milestone | Extract patterns to `.claude/session-state/learnings/` |
| Before compacting | Save verified approaches + key decisions |
| At session end | Final state snapshot (auto-handled by Stop hook) |
| 3+ related learnings | Consider evolving into a new SKILL.md |

### Confidence Scoring

- **Low** (1 session): Keep as pending, monitor
- **Medium** (2-3 sessions): Promote to active
- **High** (validated repeatedly): Candidate for skill evolution

---

## Verification Checkpoints & Metrics

Enhanced verification-loop now supports checkpoints and pass@k metrics.

### Checkpoint Triggers

| Trigger | Checkpoint Name |
|---------|----------------|
| Plan finalized | `baseline` |
| Designer completes TDD | `worktree-{name}` |
| All worktrees merged | `integration` |
| Before PR | `final-gate` |

### Pass@k Targets

| Metric | Target | Scope |
|--------|--------|-------|
| pass@1 >= 90% | Build, type check, lint | Should almost never fail |
| pass@1 >= 80% | Tests | Allows some flaky tests |
| pass@3 >= 95% | Full verification loop | At least 1 of 3 runs clean |
| pass^3 = 100% | Security scan | Every run must pass |

---

## Parallelization

### Worktree Strategy

- Max 5 active worktrees
- No file overlap between worktrees
- Merge order: shared types → backend → frontend → tests
- See skill: `parallelization` for cascade method and scaling guide

### Cascade Method (Multiple Instances)

- Max 3-4 concurrent instances
- Each instance owns its files exclusively
- Sweep left→right for oversight
- Fork for research, don't overlap edits

---

## Subagent Orchestration

### Iterative Retrieval (3-Cycle Max)

```
Cycle 1: Broad retrieval (Haiku) — overview + file listing
Cycle 2: Contextual query (Sonnet) — targeted analysis
Cycle 3: Refined execution (Sonnet/Opus) — implementation with full context
```

### Context Briefing Checklist

Every subagent prompt must include: **What, Why, Where, Context, Constraints, Already-tried**.

See skill: `subagent-orchestration` for full protocol.

---

## Skills (Updated)

| Skill | Phase | Purpose |
|-------|-------|---------|
| team-workflow | Core | 5-phase orchestration |
| plan-review | Phase 1 | Critical plan evaluation |
| api-design | Phase 1 | REST API patterns |
| plan-visualizer | Phase 1+ | HTML plan diagram |
| coding-standards | Phase 3 | Code quality baseline |
| tdd-workflow | Phase 3 | TDD cycle |
| debug | Phase 3-4 | Structured debugging |
| e2e-testing | Phase 4 | Playwright E2E |
| verification-loop | Phase 4-5 | 6-phase quality gate + checkpoints + pass@k |
| security-review | Phase 5 | OWASP checklist |
| **token-optimization** | **All** | **Model routing, context efficiency, compaction** |
| **continuous-learning** | **All** | **Pattern extraction, session state, skill evolution** |
| **parallelization** | **Phase 3+** | **Worktree management, cascade method, scaling** |
| **subagent-orchestration** | **All** | **Iterative retrieval, context briefing, phase pipeline** |
| **checkpoint** | **All** | **Save/restore work state across sessions (/checkpoint command)** |
