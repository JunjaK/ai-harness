---
name: parallelization
description: "Git worktree management and instance scaling guidelines. Use when planning parallel agent work, managing worktrees, or deciding when to scale instances."
---

# Parallelization

Scale Claude Code work across multiple agents, worktrees, and instances. Two strategies: worktree isolation, instance scaling.

## 1. Git Worktree Strategy

### Creating Worktrees

Each Designer agent in team workflow gets an isolated worktree:

```bash
# Branch the worktree from the repo's CURRENT active HEAD (see "Base Selection"):
BASE=$(git rev-parse --abbrev-ref HEAD)
git worktree add ../project-feature-a -b feature-a "$BASE"

# Each worktree = independent file system + own context window
```

### Base Selection (default = current HEAD, not an assumed mainline)

Branch every worktree from the **current active HEAD** of the target repo — the branch the user is actually on — not from an arbitrary `main`/`develop`/`master`. The user is usually working on top of a feature branch with stacked, uncommitted-to-mainline work; branching from `develop` silently drops that work and produces conflicts or lost changes at merge time.

- **Default**: `git worktree add <path> -b <new> "$(git rev-parse --abbrev-ref HEAD)"`.
- **Confirm before creating if the base is ambiguous** (detached HEAD, the user mentioned a different base, or you are in a submodule): state the base you will use in one line and proceed only if it matches intent.
- **Exception**: the user explicitly names a different base — then use it.
- **Submodules/monorepos**: derive the base from each target repo's own current HEAD, independently. When the superproject is a thin shell (docs + submodule pointers) and the real code lives in `fe`/`be` submodules, use **`submodule-worktree`** — worktree only the code submodules, keep the superproject as the single `_docs/` anchor, defer pointer bumps.

### Worktree Rules

| Rule | Why |
|------|-----|
| **Base from current HEAD** (not arbitrary main/develop) | Includes the user's stacked in-progress work; arbitrary base = lost work / merge conflicts (see "Base Selection") |
| **No file overlap** between worktrees | Prevents merge conflicts |
| **Merge sequentially** after completion | Ordered conflict resolution |
| **Clean up** after merge | `git worktree remove` to prevent stale trees |
| **Max 5 active worktrees** | Beyond this, merge overhead exceeds parallelism gains |
| **`_docs/` stays in the primary tree** (never in a linked worktree's checkout) | Plans stay readable from main without cd-ing into a worktree; no per-worktree doc copies to diverge (see below) |

### `_docs/` lives in the primary working tree

`_docs/` (plans, specs, handoffs) is a **primary-worktree-only** bucket — it MUST NOT live in a linked worktree's checkout. The problem this avoids: a plan written inside `../project-feature-a/_docs/…` is invisible from the main repo until merged, so reading it means cd-ing into that worktree.

Resolve the primary tree's `_docs/` from ANY worktree (cwd-independent — `--git-common-dir` always resolves to `<main>/.git`, so its parent is the main root):

```bash
MAIN=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
DOCS="$MAIN/_docs"   # canonical location, reachable by absolute path from every worktree
```

Rules:
- **Read** the plan/spec from `"$DOCS/…"` by absolute path — never from your own worktree's `_docs/`. The orchestrator passes this absolute path into each worktree agent's briefing.
- **Write** doc content (impl notes, findings) directly to `"$DOCS/…"` by absolute path, each worktree owning **distinct** doc files — the same no-file-overlap rule that governs code. A doc written this way lands in the main tree immediately: readable without cd, no merge round-trip.
- **`index.md` edits and status-moves** (`git mv` between `planning`/`processing`/`complete`/…) stay **orchestrator-serialized** — `index.md` is the one shared mutable doc, so only the orchestrator touches it after worktrees finish. See `docs-lifecycle` → "Concurrency".

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

## 2. Instance Scaling Guidelines

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

## 3. Agent Parallelization in Team Workflow

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

## 4. Background Process Management

### Long-Running Tasks

Always use `run_in_background: true` for:
- `bun run build` / `bunx vitest run`
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
Worktrees:     Max 5, no file overlap, merge sequentially, _docs/ in primary tree only
Scale up:      Independent tasks, background builds, research forks
Scale down:    Shared state, sequential deps, focused debugging
Background:    Builds, tests, pushes → run_in_background: true
Parallel calls: Independent tool calls in single message
```
