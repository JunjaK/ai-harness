---
name: token-optimization
description: "Model routing, context efficiency, and compaction strategy for minimizing token waste. Use when spawning agents, selecting models for tasks, or managing context window pressure."
---

# Token Optimization

Minimize token spend while maintaining output quality. Three pillars: model routing, context efficiency, strategic compaction.

## 1. Model Routing

Select the cheapest model that can handle the task:

| Task Complexity | Model | When to Use |
|----------------|-------|-------------|
| Exploration, simple edits, reference lookups | **Haiku** | `model: "haiku"` in Agent tool |
| Default coding (90% of tasks) | **Sonnet** | Default for most agents |
| Architecture, security-critical, 5+ files | **Opus** | Complex multi-file reasoning |

### Agent Model Assignment

```
Exploration agents (Glob, Grep, Read only) → Haiku
Implementation agents (code changes) → Sonnet
Architecture/planning agents → Opus
Code review agents → Sonnet
Security review agents → Opus
```

### Upgrade Triggers

Escalate to a higher model when:
- First attempt fails or produces incorrect output
- Task spans 5+ files with cross-dependencies
- Security-critical code (auth, payment, secrets)
- Architectural decisions with long-term impact

### Downgrade Opportunities

Use a cheaper model when:
- Running repetitive file searches
- Simple string replacements
- Test execution and log reading
- Documentation lookups

## 2. Context Efficiency

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

## 3. Strategic Compaction

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

### Compaction Checklist

Before compacting:
1. Save current state to `.claude/session-state/current.md`
2. Ensure all important decisions are documented
3. Verify no mid-task state will be lost
4. Compact
5. Re-read the state file after compaction if needed

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

## 4. Background Processes

### Run Builds/Tests in Background

Long-running commands should use `run_in_background: true`:

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

## Quick Reference

```
Model selection:  Haiku (search) → Sonnet (code) → Opus (architecture)
Context:          <10 MCPs, <80 tools, slim CLAUDE.md
Compaction:       After milestones, NEVER mid-task
Background:       Builds, tests, long searches
Parallel agents:  Independent tasks in single message
```
