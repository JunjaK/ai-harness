---
name: parallelization
description: "Git worktree management, cascade method for multiple instances, and scaling guidelines. Use when planning parallel agent work, managing worktrees, or deciding when to scale instances."
---

# Parallelization

Scale Claude Code work across multiple agents, worktrees, and instances. Three strategies: worktree isolation, cascade method, instance scaling.

## 1. Git Worktree Strategy

### Creating Worktrees

Each Designer agent in team workflow gets an isolated worktree:

```bash
# Create worktree for feature branch
git worktree add ../project-feature-a -b feature-a

# Each worktree = independent file system + own context window
```

### Worktree Rules

| Rule | Why |
|------|-----|
| **No file overlap** between worktrees | Prevents merge conflicts |
| **Merge sequentially** after completion | Ordered conflict resolution |
| **Clean up** after merge | `git worktree remove` to prevent stale trees |
| **Max 5 active worktrees** | Beyond this, merge overhead exceeds parallelism gains |

### File Assignment Strategy

When splitting work across worktrees:

```
1. Identify file dependencies (imports, shared types)
2. Group tightly-coupled files into same worktree
3. Shared interfaces/types → define FIRST in main, then branch
4. Each worktree gets a complete, independent unit of work
```

**Anti-pattern**: Splitting a single component across worktrees. Keep related files together.

### Worktree Merge Order

```
1. Core/shared types first (foundation)
2. Backend/API changes second (data layer)
3. Frontend/UI changes third (depends on API)
4. Tests last (depends on implementation)
```

## 2. Cascade Method

### Overview

Run multiple Claude Code instances in parallel, each focused on a different task. Sweep through them sequentially to maintain oversight.

### Setup

```
Instance 1 (leftmost) ── Main implementation
Instance 2             ── Code review / testing
Instance 3             ── Research / documentation
Instance 4 (rightmost) ── Independent feature / debugging
```

### Cascade Rules

| Rule | Details |
|------|---------|
| **Max 3-4 concurrent** | Beyond this, context-switching overhead dominates |
| **No overlapping file edits** | Each instance owns its files exclusively |
| **Sweep left→right** | Check oldest → newest, handle blocks |
| **Fork for research** | Questions about codebase → separate instance |
| **Scope clearly** | Each instance has ONE clear objective |

### Task Distribution

```
Main instance:     Code changes (owns the implementation)
Fork 1:            Codebase questions / exploration
Fork 2:            External API research / documentation
Fork 3:            Test writing / verification (separate from implementation)
```

### When Cascade Works

- Truly independent modules
- Code review alongside feature implementation
- E2E tests while implementing features
- Independent data/API integrations

### When Cascade Fails

- Sequential work (Phase B depends on Phase A output)
- Tightly coupled modules (shared state)
- Single complex file requiring focused attention

## 3. Instance Scaling Guidelines

### When to Scale Up

| Signal | Action |
|--------|--------|
| 2+ independent tasks in queue | Spawn parallel agents |
| Build/test takes >2 min | Background + continue other work |
| Research needed alongside implementation | Fork for research |
| Code review bottleneck | Dedicated review instance |

### When NOT to Scale

| Signal | Why |
|--------|-----|
| Tasks share mutable state | Race conditions, conflicts |
| Sequential dependency chain | Can't parallelize |
| Complex debugging session | Needs focused context |
| Context window is critical | Don't fragment it |

### Scaling Configurations

**Minimal (1-2 agents)**:
```
Solo developer → 1 main + 1 background (tests/build)
```

**Standard (3-4 agents)**:
```
Team workflow → Leader + 2-3 Designers in worktrees
```

**Maximum (5+ agents)**:
```
Large feature → Leader + Architects + Designers + Testers
Only when tasks are truly independent with no shared files
```

## 4. Agent Parallelization in Team Workflow

### Phase 1: Parallel Architecture

```
Team Leader spawns:
├── Architect FE ──→ Frontend plan    ─┐
├── Architect BE ──→ Backend plan     ─┤── Cross-review → Merged plan
└── Architect Infra ──→ (on-demand)   ─┘
```

### Phase 3: Parallel Implementation

```
Team Leader assigns files:
├── Designer A (worktree-a) ──→ Files: [auth.ts, auth.test.ts]
├── Designer B (worktree-b) ──→ Files: [api.ts, api.test.ts]
└── Designer C (worktree-c) ──→ Files: [ui.tsx, ui.test.tsx]
```

### Phase 4: Parallel Verification

```
├── Tester A ──→ Unit tests for Designer A's work
├── Tester B ──→ Unit tests for Designer B's work
└── Tester C ──→ E2E tests for integrated flow
```

## 5. Background Process Management

### Long-Running Tasks

Always use `run_in_background: true` for:
- `npm run build` / `npx vitest run`
- `git push` / `git pull`
- Database migrations
- Large file searches

### Notification Pattern

```
1. Launch background task
2. Continue with other work (don't poll or sleep)
3. System notifies when task completes
4. Handle result when notified
```

### Parallel Tool Calls

Independent tool calls in a single message execute simultaneously:

```
# These run in parallel (single message, multiple tool calls):
Agent({ prompt: "search auth patterns", model: "haiku" })
Agent({ prompt: "search API endpoints", model: "haiku" })
Agent({ prompt: "search test utilities", model: "haiku" })
```

## Quick Reference

```
Worktrees:     Max 5, no file overlap, merge sequentially
Cascade:       3-4 instances max, sweep left→right, clear scope each
Scale up:      Independent tasks, background builds, research forks
Scale down:    Shared state, sequential deps, focused debugging
Background:    Builds, tests, pushes → run_in_background: true
Parallel calls: Independent tool calls in single message
```
