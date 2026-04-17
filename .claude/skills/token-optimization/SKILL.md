---
name: token-optimization
description: "Model routing, effort levels, context efficiency, and compaction strategy for Opus 4.7. Use when spawning agents, selecting models, choosing effort levels, or managing context window pressure."
---

# Token Optimization

Minimize token spend while maintaining output quality. Four pillars: model routing, effort level selection, context efficiency, strategic compaction.

## 1. Model Routing

Select the cheapest model that meets the task's minimum capability:

| Task Complexity | Model | Use when |
|----------------|-------|----------|
| File search, exploration, simple edits | Haiku 4.5 | Read-only work, pattern matching, simple string ops |
| Code implementation, review, testing | Sonnet 4.6 | 90% of coding tasks, default balance |
| Architecture, security audit, multi-file refactor | Opus 4.7 | 5+ file changes, complex reasoning, critical decisions |

## 2. Effort Level (Opus 4.7)

Opus 4.7 introduces `xhigh` between `high` and `max`. Claude Code defaults to `xhigh`.

| Effort | Use when |
|--------|----------|
| `high` | Mechanical edits (rename, import fix, formatting) |
| `xhigh` | Default for coding and agent workflows |
| `max` | Multi-step autonomous tasks, architecture, debugging hard failures |

**Rule**: Start with `xhigh`. Upgrade to `max` only if `xhigh` fails to resolve the task in 2 attempts. Downgrade to `high` only for trivial mechanical work.

### Agent Model Assignment

```
Exploration agents (Glob, Grep, Read only) → Haiku
Implementation agents (code changes) → Sonnet
Architecture/planning agents → Opus
Code review agents → Sonnet
Security review agents → Opus
```

### Upgrade Triggers (MUST upgrade when ANY applies)

- First attempt fails or produces incorrect output
- Task spans 5+ files with cross-dependencies
- Security-critical code (auth, payment, secrets, PII)
- Architectural decisions with long-term impact
- Debugging issue that survived 2 resolution attempts

### Downgrade Triggers (MAY downgrade when ALL apply)

- Task is read-only or a single-file mechanical edit
- No cross-file reasoning required
- Output shape is deterministic (not generative)

## 3. Context Efficiency

### MCP Tool Hygiene

Keep under **10 MCP servers** enabled, under **80 tools** active.
Too many tools shrink the usable context window (~200k → ~70k with tool bloat).

```json
{
  "disabledMcpServers": ["unused-server-1", "unused-server-2"]
}
```

**Audit**: Periodically check which MCP tools are actually used. Disable the rest.

### System Prompt Slimming

- Load only language-specific rules needed (not all 34 guidelines)
- Structure rules as `common/` (language-agnostic) + language-specific
- CLAUDE.md: Keep concise. Move detailed docs to separate files and reference them.

### Subagent Context Isolation

Subagents get their own context window. Use them to:
- Offload research/exploration (prevents main context bloat)
- Run verification loops (output is summarized back)
- Handle independent tasks in parallel

**Anti-pattern**: Don't use subagents for tasks that need the current conversation's full context.

## 4. Strategic Compaction

### When to Compact

| Timing | Why |
|--------|-----|
| After research/exploration, before implementation | Clear exploration noise |
| After completing a milestone | Reset for next phase |
| After debugging, before continuing | Clear debug traces |
| When context window is 60-70% full | Proactive space management |

### When NOT to Compact

- **Mid-implementation** — Loses variable names, partial state
- **During active debugging** — Loses reproduction steps
- **Before saving session state** — Save first, then compact

### Compaction Checklist (MUST execute all steps)

Before compacting:
1. Write current state to `.claude/session-state/current.md` (task progress, verified approaches, decisions, remaining steps)
2. Verify no mid-task variable names or intermediate state will be lost
3. Execute compaction
4. Re-read `.claude/session-state/current.md` to restore context

### Auto-Compact Configuration

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "60"
  }
}
```

Setting to `60` triggers compaction at 60% context usage instead of default 95%.
This preserves more usable space but compacts more frequently.

## 5. Background Processes

### Run Builds/Tests in Background

Long-running commands MUST use `run_in_background: true`:

```
Bash({ command: "npm run build", run_in_background: true })
Bash({ command: "npm test", run_in_background: true })
```

This frees the context for other work while waiting.

### Parallel Agent Execution

When tasks are independent, spawn agents simultaneously:
- Multiple Agent tool calls in a single message
- Each agent gets its own context window
- Results return as they complete

## 6. Opus 4.7 Tokenizer Notes

- Same input now consumes 1.0–1.35× tokens compared to Opus 4.6 (depends on content type)
- Higher effort levels produce more reasoning tokens (especially `max`)
- Overall efficiency improved per Anthropic's internal evals — but budget audits MUST re-measure against the new baseline

## Quick Reference

```
Model:        Haiku (search) → Sonnet (code) → Opus (architecture)
Effort:       high (mechanical) → xhigh (default) → max (hard problems)
Context:      <10 MCPs, <80 tools, slim CLAUDE.md
Compaction:   After milestones. NEVER mid-task. Save state first.
Background:   Builds, tests, long searches → run_in_background: true
Parallel:     Independent tasks in single message
```
