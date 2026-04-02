---
name: continuous-learning
description: "Extract reusable patterns from sessions, manage session state, and evolve learnings into skills. Use at session end, after completing features, or when patterns emerge during work."
---

# Continuous Learning

Capture, evaluate, and evolve reusable patterns from coding sessions. Three modes: session state tracking, pattern extraction, skill evolution.

## 1. Session State Management

### Writing Session State

During any non-trivial session, maintain `.claude/session-state/current.md`:

```markdown
# Session State — {date}

## Current Task
{what you're working on}

## Progress
- [x] Completed steps
- [ ] Remaining steps

## Verified Approaches
{approach}: {evidence it works}

## Failed Approaches
{approach}: {why it failed}

## Key Decisions
- {decision}: {rationale}

## Discoveries
- {non-obvious findings about the codebase}
```

### When to Update State

| Trigger | Action |
|---------|--------|
| Starting a task | Write initial state with task description |
| Completing a milestone | Update progress, add verified approaches |
| Failed approach | Document what failed and why |
| Before compaction | Full state snapshot (pre-compact hook reminds you) |
| Before session end | Final state with remaining work items |

### State Lifecycle

```
Session start → Load .claude/session-state/last-session.md (if exists)
During session → Write/update .claude/session-state/current.md
Session end → Stop hook archives current.md → last-session.md
Next session → SessionStart hook outputs last-session.md
```

## 2. Pattern Extraction

### What to Extract

Extract patterns that are:
- **Reusable** — Applies beyond the current task
- **Non-obvious** — Not derivable from reading the code
- **Validated** — Actually worked (not theoretical)

### Pattern Categories

| Category | Example |
|----------|---------|
| **Debugging** | "This error always means X, fix with Y" |
| **Architecture** | "This codebase uses pattern X for Y" |
| **Tooling** | "Use X tool with Y flags for best results" |
| **Domain** | "Business rule: X always requires Y" |
| **Performance** | "Query X is slow because Y, use Z instead" |

### Extraction Process

After completing a significant task:

1. **Identify** — What did you learn that wasn't obvious at the start?
2. **Validate** — Does evidence support it? (test results, successful builds)
3. **Generalize** — Strip task-specific details, keep the reusable pattern
4. **Score** — Rate confidence: low (1 session), medium (2-3), high (validated repeatedly)
5. **Store** — Save to `.claude/session-state/learnings/`

### Learning File Format

```markdown
# {Pattern Name}

**Confidence**: low | medium | high
**Category**: debugging | architecture | tooling | domain | performance
**Discovered**: {date}
**Last validated**: {date}

## Pattern
{Concise description of the reusable pattern}

## Evidence
{How this was validated — test results, build success, etc.}

## When to Apply
{Trigger conditions — when should this pattern be used?}

## Anti-patterns
{What NOT to do — common mistakes this pattern prevents}
```

## 3. Skill Evolution

### From Learnings to Skills

When 3+ related learnings cluster around a topic, consider evolving them into a formal skill:

```
Individual learnings → Cluster by topic → Draft skill → Validate → Install as SKILL.md
```

### Evolution Criteria

A cluster is ready for skill evolution when:
- 3+ learnings share a common domain
- At least 2 have "high" confidence
- The combined pattern is broadly applicable (not project-specific)
- It would save significant time in future sessions

### Skill Template (from learnings)

```markdown
---
name: {skill-name}
description: "{when to activate this skill}"
---

# {Skill Name}

## When to Activate
{Conditions that trigger this skill}

## Core Concepts
{Distilled from clustered learnings}

## Practical Examples
{From validated evidence in learnings}

## Anti-Patterns
{From failed approaches across learnings}
```

## 4. Instinct System

### Instinct Lifecycle

```
Observation → Pending instinct (30-day TTL)
                ↓ validated
             Active instinct (confidence scored)
                ↓ 3+ related instincts
             Skill candidate
                ↓ evolved
             SKILL.md installed
```

### Confidence Scoring

| Score | Meaning | Action |
|-------|---------|--------|
| 1 (low) | Single observation | Keep as pending, monitor |
| 2 (medium) | Confirmed across 2-3 sessions | Promote to active |
| 3 (high) | Validated repeatedly, never contradicted | Candidate for skill |

### Pruning

- **Pending instincts**: Auto-expire after 30 days if not validated
- **Contradicted instincts**: Remove immediately when evidence disproves them
- **Superseded instincts**: Remove when a better pattern replaces them

## 5. Integration with Team Workflow

### Phase 3 (Implementation) Learnings
- TDD patterns that work for this codebase
- Common test setup patterns
- Build configuration discoveries

### Phase 4 (Verification) Learnings
- Recurring test failures and their root causes
- Performance bottlenecks discovered during testing
- Flaky test patterns and fixes

### Phase 5 (Security) Learnings
- Vulnerability patterns specific to this stack
- Security configuration requirements

### Post-Workflow
After each team workflow completion:
1. Review escalation log for patterns
2. Extract learnings from each phase
3. Update session state with workflow outcomes

## Quick Reference

```
State file:    .claude/session-state/current.md (update during session)
Learnings:     .claude/session-state/learnings/{topic}.md
Archive:       .claude/session-state/archive/ (auto-managed by hooks)
Extract:       After milestones — identify, validate, generalize, score, store
Evolve:        3+ related high-confidence learnings → new SKILL.md
Prune:         30-day TTL for pending, immediate for contradicted
```
