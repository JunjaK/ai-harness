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

When 3+ related learnings cluster around a topic, evaluate skill evolution using the criteria below.

```
Individual learnings → Cluster by topic → Draft skill → Validate → Install as SKILL.md
```

### Evolution Criteria (MUST evolve when ALL apply)

- 3+ learnings share a common domain
- ≥ 2 learnings have "high" confidence
- Pattern is broadly applicable (not tied to a specific project file/component)
- Applying the pattern would save ≥ 15 minutes per future occurrence

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

## 6. Learning Reuse (closing the loop)

Capturing learnings is worthless if nothing ever reads them back. Extraction (§2) is only half the loop — this is the consumption half. Without it, the same mistake recurs every session despite being "learned."

### Consume at task start

Before starting non-trivial work, **route the relevant learnings into the task**:
1. Skim `.claude/session-state/learnings/` for entries whose "When to Apply" matches the current task's domain/area.
2. Load the matching ones and treat their **Anti-patterns** as constraints and their **Pattern** as the default approach.
3. If a learning names a specific gotcha for this area (a known trap, a required sequence, a non-obvious command), apply it instead of rediscovering it.

### Route learnings into agent prompts

When spawning an agent for a task that a learning covers, **include the relevant learning in the agent's briefing** (the `subagent-orchestration` Context section). An agent that never sees the learning cannot apply it. Prefer pasting the one matching learning over hoping the agent re-derives it.

### Build a lightweight index

When `learnings/` grows past ~10 entries, maintain a one-line index (`learnings/index.md`: area → file → hook) so "which learnings apply to area X" is a single read, not a folder scan. This is the router that makes reuse cheap enough to actually happen.

### Promote project-stable learnings into the profile

A high-confidence learning that is a **stable fact about this project** (not a transient finding) belongs in the project-profile (`.claude/project-profile/`) where every agent already reads it — e.g. "the authoritative typecheck command is X", "bulk search caps at N", "store Y must be eagerly initialized." Move it there so it is consumed by default, and leave a pointer in the learning.

## 7. Knowledge-Base Maintenance Contract

For projects that maintain a curated knowledge base (a wiki, a profile, an index, an ADR set), the base **drifts** the moment code changes without a matching doc update. A living knowledge base needs an explicit maintenance contract, or it rots into a misleading liability.

### Two invariants

1. **Link, don't duplicate.** The knowledge base holds routing + stable overview and **links** to the single source of truth (code, a skill, a reference doc). Duplicating a fact guarantees the copy goes stale. If a fact lives in two places, one is already wrong.
2. **Same change, same update.** The commit that changes code/structure also updates the doc it invalidates. A "docs later" backlog never clears; treat the doc edit as part of the change, not a follow-up.

### Trigger → update table (adapt per project)

| When this changes | Update this |
|-------------------|-------------|
| API contract / endpoint / DTO | api-layer profile + any contract doc |
| Authoritative verify command / baseline | `stack.md` "Build & Verify" |
| A new recurring gotcha is confirmed | a learning (§2), promoted to profile if project-stable (§6) |
| Architecture / module boundary | the architecture overview/wiki page (link to the code, don't restate it) |
| A documented file/command/flag is renamed or removed | every doc that named it (grep the knowledge base for the old name) |

### Self-audit routine

Periodically (e.g. at workflow completion, or when a doc feels stale): pick a knowledge-base page, follow its claims to the code, and flag any that no longer hold. A recalled learning or wiki line that names a file/function/flag is only valid as of when it was written — **verify it still exists before acting on it.**

## Quick Reference

```
State file:    .claude/session-state/current.md (update during session)
Learnings:     .claude/session-state/learnings/{topic}.md
Archive:       .claude/session-state/archive/ (auto-managed by hooks)
Extract:       After milestones — identify, validate, generalize, score, store
Reuse:         At task start, load matching learnings; route them into agent briefings; index when >10
Promote:       Project-stable learning → project-profile (read by default)
Evolve:        3+ related high-confidence learnings → new SKILL.md
Maintain:      Link don't duplicate; same change updates the doc it invalidates; verify a recalled fact still exists
Prune:         30-day TTL for pending, immediate for contradicted
```
