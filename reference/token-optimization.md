---
name: token-optimization
description: "Two-tier model routing (sonnet only when a dispatch is read-only or small, contract-free, and deterministic; opus otherwise), session-inherited effort, context efficiency, compaction strategy, and subagent orchestration (3-cycle retrieval cap + briefing contract). Use when spawning agents, authoring Workflow fan-outs, selecting models, choosing effort levels, or managing context window pressure."
---

# Token Optimization

Keep agent runs fast and focused without losing output quality. Pillars: model routing, effort, context efficiency, strategic compaction, background processes, subagent orchestration.

## 1. Model Routing

Two tiers, chosen per dispatch. In the team workflow the Leader writes the choice for every role into the plan's **Team Composition**, and the orchestrator applies it. Name tiers by alias only (`sonnet`, `opus`) — never a model version, so a model release changes nothing here.

Use **`sonnet`** only when **all three** hold; otherwise use **`opus`**:

1. Read-only work, or edits to at most 2 files within one domain.
2. No auth / payment / secrets / PII, and no contract change (API shape, DB schema, generated client).
3. Deterministic work that follows an approved plan or checklist without design judgment — running given checks, a mechanical edit, rename/format, string translation, a locate/scan sweep.

When you are not sure a condition holds, use `opus`. Re-dispatch on `opus` when a `sonnet` dispatch fails once, or when the work turns out to break any condition above.

Applying it:

- **Standard `Agent()`**: pass `model` on every call; it overrides the agent's frontmatter. Frontmatter defaults: `team-leader` is `inherit` (it follows the session model the user chose); every other agent is `opus`, so a call without `model` lands on the "otherwise" tier.
- **Ultracode `agent()`**: pass `opts.model` the same way. `opts.agentType` does not apply the agent's frontmatter tier, so always pass `opts.model`.
- The `opus` alias resolves to the session's own model when the session already runs on Opus (including a `[1m]` context suffix).

## 2. Effort

Every subagent inherits the session effort that the user set (`/effort`, or `effortLevel` / `modelSettings` in settings). A standard `Agent()` call has no per-call effort parameter, and an agent's frontmatter `effort` is fixed per definition, so the harness does not keep per-effort variant agents. Under ultracode, omit `opts.effort` so stages inherit the session effort too.

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
1. Write current state to `.claude/session-state/sessions/$CLAUDE_CODE_SESSION_ID/current.md` (task progress, verified approaches, decisions, remaining steps)
2. Verify no mid-task variable names or intermediate state will be lost
3. Execute compaction
4. Re-read that `current.md` to restore context

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
Bash({ command: "bun run build", run_in_background: true })
Bash({ command: "bunx vitest run", run_in_background: true })
```

This frees the context for other work while waiting.

### Parallel Agent Execution

When tasks are independent, spawn agents simultaneously:
- Multiple Agent tool calls in a single message
- Each agent gets its own context window
- Results return as they complete

## 6. Subagent Orchestration

A subagent receives a literal prompt but none of the semantic context driving it — it doesn't know what you already tried or why the task matters. Two hard rules fix that.

### Iterative Retrieval — 3-cycle cap

Never accept first output. Budget **at most 3 retrieval cycles** per agent, then escalate (do NOT retry a 4th time).

```
Cycle 1 — Broad retrieval: initial file/module overview.
  GATE A: files returned match the task scope?
  GATE B: output carries enough context to proceed?
  Both PASS → skip to execution. Either FAILS → Cycle 2.

Cycle 2 — Contextual query: ask "given [X], what context do you need?",
  supply the exact files/snippets named, re-check GATE A + GATE B.
  Both PASS → Cycle 3. Either still FAILS → ESCALATE (this subagent lacks the information).

Cycle 3 — Refined execution: agent works with focused context; orchestrator validates
  against the task requirements. Accept, or reject → escalate (reject ≠ retry).
```

Pick each cycle's model by §1: a read-only sweep qualifies for `sonnet`; move to `opus` once the work needs cross-file reasoning or design judgment.

For TypeScript targets, prefer LSP over grep in Cycle 1-2 (`findReferences`, `goToDefinition`, `documentSymbol`, `workspaceSymbol`); use grep only when the target is a string pattern (comment, string literal, config key), not a symbol.

### Context Briefing Protocol

Every subagent prompt MUST include all six elements:

| Element | Example |
|---------|---------|
| **What** | "Fix the token rotation in refreshSession()" |
| **Why** | "Users are getting logged out because tokens aren't rotating" |
| **Where** | "auth/session.ts:45, auth/session.test.ts:89" |
| **Context** | "JWT-based auth with access + refresh tokens" |
| **Constraints** | "Must maintain backwards compatibility with v2 API" |
| **Already tried** | "Tried updating expiry — didn't fix root cause" |

Brief like a smart colleague who just walked in: they haven't seen this conversation and can't make judgment calls without it. Banned prompt shapes: "Fix the auth bug" (no context) · "Based on your findings, implement it" (pushes synthesis onto the agent) · "Research and implement" (two tasks — split into two agents) · "Look at the codebase and fix things" (no focus).

## Quick Reference

```
Model:        sonnet only if read-only/≤2 files + no contract/sensitive + deterministic; else opus
Effort:       inherited from the session (no per-call effort)
Context:      <10 MCPs, <80 tools, slim CLAUDE.md
Compaction:   After milestones. NEVER mid-task. Save state first.
Background:   Builds, tests, long searches → run_in_background: true
Parallel:     Independent tasks in single message
Retrieval:    3 cycles max — broad → contextual → refined, then escalate
Briefing:     What, Why, Where, Context, Constraints, Already-tried
```
