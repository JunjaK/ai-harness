---
name: subagent-orchestration
description: "Iterative retrieval pattern, context negotiation, and sequential phase architecture for subagent coordination. Use when spawning agents, designing multi-agent workflows, or debugging subagent quality issues."
---

# Subagent Orchestration

Coordinate subagents effectively by solving the context negotiation problem. Three techniques: iterative retrieval, context briefing, sequential phase architecture.

## 1. The Context Problem

### Why Subagents Fail

Subagents receive a literal prompt but lack the **semantic context** driving the request:
- They don't know what you've already tried
- They don't know WHY this task matters
- They can't make judgment calls without surrounding context
- First-pass results are often shallow or misaligned

### The Fix: Never Accept First Output

Always evaluate subagent responses before accepting. Budget **up to 3 retrieval cycles** per agent.

## 2. Iterative Retrieval Pattern

### LSP-Accelerated Retrieval (TypeScript projects)

For TypeScript codebases, use LSP before grep-based search. It is faster and more accurate:

| Task | Prefer | Fallback |
|------|--------|----------|
| Find all callers of a function | `LSP.findReferences` | `grep` |
| Find where a type is declared | `LSP.goToDefinition` | `grep` + manual read |
| Get file outline (functions, classes, exports) | `LSP.documentSymbol` | `grep` |
| Search symbol across project | `LSP.workspaceSymbol` | `grep` |

Use `grep` when the search target is a string pattern (comments, strings, config keys) — not a TypeScript symbol.

### Three-Cycle Protocol

```
Cycle 1: Broad retrieval
  → Agent does initial file/module overview
  → Orchestrator evaluates output against these gates:
    GATE A: Did the agent return files matching the task scope?
    GATE B: Does the output contain enough context to proceed?
  If both PASS → skip to execution
  If either FAILS → continue to Cycle 2

Cycle 2: Contextual query
  → Orchestrator sends follow-up: "Given [X], what context do you need?"
  → Agent identifies specific gaps
  → Orchestrator provides exact files/snippets requested
  → Evaluate against GATE A and GATE B again
  If both PASS → proceed to Cycle 3
  If either still FAILS → escalate (insufficient information for this subagent)

Cycle 3: Refined execution
  → Agent operates with focused context
  → Orchestrator validates output against task requirements
  → Accept or reject (reject = escalate, not retry)
```

### Implementation

```
# Cycle 1: Initial exploration
Agent({
  prompt: "Find all authentication-related files and summarize the auth flow. 
           List files found and describe the pattern used.",
  model: "haiku"  # Cheap for exploration
})

# Evaluate result → if insufficient:

# Cycle 2: Focused retrieval  
Agent({
  prompt: "Read auth/middleware.ts and auth/session.ts specifically.
           The auth system uses JWT with refresh tokens.
           I need to understand how token rotation works.",
  model: "sonnet"  # Upgrade for deeper analysis
})

# Evaluate result → if ready:

# Cycle 3: Execute with full context
Agent({
  prompt: "Implement token rotation fix in auth/session.ts.
           Current behavior: tokens don't rotate on refresh.
           Expected: new access token + new refresh token per rotation.
           File: auth/session.ts, function: refreshSession (line 45).
           Test: auth/session.test.ts already has rotation test stub.",
  model: "sonnet"
})
```

### Key Principle: Escalate Model with Context

```
Haiku  → broad search, file listing, pattern matching
Sonnet → read and analyze specific files
Opus   → complex multi-file changes with architectural impact
```

## 3. Context Briefing Protocol

### What Every Subagent Needs

Write prompts that include:

| Element | Example |
|---------|---------|
| **What** | "Fix the token rotation in refreshSession()" |
| **Why** | "Users are getting logged out because tokens aren't rotating" |
| **Where** | "auth/session.ts:45, auth/session.test.ts:89" |
| **Context** | "JWT-based auth with access + refresh tokens" |
| **Constraints** | "Must maintain backwards compatibility with v2 API" |
| **Already tried** | "Tried updating expiry — didn't fix root cause" |

### Anti-patterns

| Bad Prompt | Problem | Good Prompt |
|------------|---------|-------------|
| "Fix the auth bug" | No context | "Fix token rotation in auth/session.ts:45 — tokens don't rotate on refresh" |
| "Based on your findings, implement it" | Pushes synthesis to agent | "The auth uses JWT rotation. Implement new refresh logic in refreshSession()" |
| "Research and implement" | Two tasks in one | Separate into research agent + implementation agent |
| "Look at the codebase and fix things" | No focus | "Read auth/*.ts, identify why refreshSession skips rotation" |

### The "Smart Colleague" Test

Brief subagents like a colleague who just walked in:
- They haven't seen this conversation
- They don't know what you've tried
- They don't understand why this matters
- Give enough context for judgment calls, not just narrow instructions

## 4. Sequential Phase Architecture

### Phase Pipeline

Structure multi-agent workflows as sequential phases:

```
RESEARCH → PLAN → IMPLEMENT → REVIEW → VERIFY
```

Each phase produces **one clear output** that serves as input for the next.

### Phase Rules

| Rule | Details |
|------|---------|
| Never skip phases | Even if "obvious" — the phase catches edge cases |
| One input, one output | Each agent receives focused context, produces distinct result |
| Store intermediate results | Write phase outputs to files for the next agent |
| Clear context between agents | Each agent starts fresh with its input |

### Phase Output Format

```markdown
## Phase: {RESEARCH|PLAN|IMPLEMENT|REVIEW|VERIFY}
## Input: {what this agent received}
## Output: {what this agent produced}
## Confidence: {high|medium|low}
## Next Phase Needs: {facts the next agent MUST receive}
```

### Example Pipeline

```
Phase 1 — RESEARCH (Haiku agents, parallel)
  Input: "Find all payment-related code"
  Output: File list + architecture summary
  
Phase 2 — PLAN (Sonnet agent)
  Input: Research output + task requirements
  Output: Implementation plan with file assignments
  
Phase 3 — IMPLEMENT (Sonnet agents, parallel worktrees)
  Input: Plan + specific file assignments
  Output: Code changes in isolated worktrees
  
Phase 4 — REVIEW (Sonnet agent)
  Input: All code changes (diffs)
  Output: Review comments, approval/rejection
  
Phase 5 — VERIFY (Sonnet agent)
  Input: Merged code
  Output: Test results, coverage report, security scan
```

## 5. Agent Selection Matrix

### Model by Task Type

| Task | Model | Tools | Rationale |
|------|-------|-------|-----------|
| File exploration | Haiku | Read, Grep, Glob | Cheapest for search |
| Architecture analysis | Opus | Read, Glob | Needs deep reasoning |
| Code implementation | Sonnet | Read, Write, Edit, Bash | Balance of speed/quality |
| Code review | Sonnet | Read, Grep | Pattern matching strength |
| Security audit | Opus | Read, Grep, Bash | Critical decisions |
| Test writing | Sonnet | Read, Write, Bash | Implementation-level |
| Documentation | Haiku | Read, Write | Low complexity |

### Subagent Type Selection

| Need | subagent_type | When |
|------|---------------|------|
| Quick file search | `Explore` | Finding files by pattern |
| Architecture design | `Plan` | Designing implementation strategy |
| Code review | `code-reviewer` | Post-implementation quality check |
| Build fix | `build-error-resolver` | When builds fail |
| Security check | `security-reviewer` | Auth, input handling, secrets |

## 6. Loop Prevention

### Guard Against

- **Duplicate task spawning** — Check if an agent is already handling this
- **Re-entrancy** — Agent spawns subagent for same task
- **Feedback cycles** — Agent A asks Agent B, B asks A
- **Infinite retry** — Max 3 retries per agent, then escalate

### Detection Heuristics

```
If agent prompt ≈ parent prompt → BLOCK (re-entrancy)
If same agent spawned 3x in same phase → ESCALATE
If agent output = "I need more context" 2x → PROVIDE context or ABORT
If total agents in session > 15 → PAUSE and assess
```

## Quick Reference

```
Context problem:  Subagents lack semantic context → brief them fully
Iterative:        3 cycles max — broad → contextual → refined
Briefing:         What, Why, Where, Context, Constraints, Already-tried
Phases:           RESEARCH → PLAN → IMPLEMENT → REVIEW → VERIFY
Models:           Haiku (search) → Sonnet (code) → Opus (architecture)
Loop prevention:  Max 3 retries, detect re-entrancy, cap at 15 agents
```
