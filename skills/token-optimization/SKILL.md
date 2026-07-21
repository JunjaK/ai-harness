---
name: token-optimization
description: "Model routing (incl. per-agent Workflow / ultracode routing), effort levels, context efficiency, compaction strategy, and subagent orchestration (3-cycle retrieval cap + briefing contract). Use when spawning agents, authoring Workflow fan-outs, selecting models, choosing effort levels, or managing context window pressure."
---

# Token Optimization

Minimize token spend while maintaining output quality. Five pillars: model routing, effort level selection, context efficiency, strategic compaction, subagent orchestration.

## 1. Model Routing

Select the cheapest model that meets the task's minimum capability:

| Task Complexity | Model | Use when |
|----------------|-------|----------|
| File search, exploration, simple edits | Haiku | Read-only work, pattern matching, simple string ops |
| Code implementation, review, testing | Sonnet | 90% of coding tasks, default balance |
| Architecture, security audit, multi-file refactor | Opus | 5+ file changes, complex reasoning, critical decisions |

## 2. Effort Level (Opus)

Current Opus provides `xhigh` between `high` and `max`. Claude Code defaults to `xhigh`.

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

### Workflow `agent()` routing (ultracode)

A Workflow `agent()` **inherits the session model** (Opus, in ultracode) when `opts.model` is omitted — so an un-annotated fan-out silently runs *every* stage on Opus. That is the "everything is Opus" waste (e.g. a 5-agent read-only locale-gap audit at ~150k Opus tokens each). MUST route each `agent()` by task class instead:

| Task class (examples) | `opts.model` | `opts.effort` |
|----------------------|-------------|--------------|
| Read-only locate / scan / extract — code-location analysis, grep/read sweep, locale-gap collection, completeness-critic listing | `haiku` | `low` |
| Deterministic transform / verify / review / test / translate / rule-based classify — Phase 4 Tester, `web-reviewer`, adversarial verify/refute, Phase 4.5 generator (crystallize), i18n translation, **Phase 3 Designer (TDD implement against an approved plan)** | `sonnet` | (default) |
| Generative reasoning / architecture / security / judge-synthesis / ambiguous classify — Phase 1 architects, cross-review·judge, security audit, Phase 4.5 explorer (explore-gate) | `opus` | `xhigh` (`max` for hard) |

Rules:
- Omit `opts.model` **only** for the Opus row — inheriting the session model is correct there; every other stage MUST pass an explicit `haiku`/`sonnet`.
- `opts.agentType` does **not** guarantee that agent's frontmatter tier is applied — set `opts.model` explicitly even when passing `agentType` (e.g. `team-tester` → `sonnet`).
- Same upgrade/downgrade triggers below still apply per-stage (a "Sonnet" stage that fails twice or turns cross-cutting → upgrade to Opus).
- **Designer → Opus** specifically when a worktree spans the full types→backend→frontend stack, touches auth/payment/PII, or after a failed Phase 4 cycle; routine single-domain feature implementation stays `sonnet`. (Sonnet 5 covers plan-driven TDD implementation; the design reasoning already happened upstream in Phase 1.)

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
Cycle 1 — Broad retrieval (haiku): initial file/module overview.
  GATE A: files returned match the task scope?
  GATE B: output carries enough context to proceed?
  Both PASS → skip to execution. Either FAILS → Cycle 2.

Cycle 2 — Contextual query (sonnet): ask "given [X], what context do you need?",
  supply the exact files/snippets named, re-check GATE A + GATE B.
  Both PASS → Cycle 3. Either still FAILS → ESCALATE (this subagent lacks the information).

Cycle 3 — Refined execution: agent works with focused context; orchestrator validates
  against the task requirements. Accept, or reject → escalate (reject ≠ retry).
```

Escalate the model along with the context: haiku (broad search) → sonnet (read/analyze specific files) → opus (multi-file changes with architectural impact).

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
Model:        Haiku (search) → Sonnet (code) → Opus (architecture)
Effort:       high (mechanical) → xhigh (default) → max (hard problems)
Context:      <10 MCPs, <80 tools, slim CLAUDE.md
Compaction:   After milestones. NEVER mid-task. Save state first.
Background:   Builds, tests, long searches → run_in_background: true
Parallel:     Independent tasks in single message
Retrieval:    3 cycles max — broad → contextual → refined, then escalate
Briefing:     What, Why, Where, Context, Constraints, Already-tried
```
