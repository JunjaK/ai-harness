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
4. **Score** — Rate confidence 0.3–0.9 (0.3 = one session, 0.7 = confirmed across sessions, 0.9 = validated repeatedly, never contradicted). Same scale as instincts (§4).
5. **Store** — Save to `.claude/session-state/learnings/`

### Learning File Format

```markdown
# {Pattern Name}

**Confidence**: 0.3–0.9 (numeric — see §4)
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

### From Learnings & Instincts to Skills / Commands / Agents

When 3+ related learnings or instincts cluster around a topic, evolve them — and not only into a skill. Pick the target by shape:
- reusable methodology / knowledge → **skill**
- a repeatable invocation the human runs → **command**
- a specialized role / persona → **agent**

```
learnings + instincts → cluster by domain → draft (skill | command | agent) → validate → install
```

### Evolution Criteria (MUST evolve when ALL apply)

- 3+ learnings/instincts share a common domain
- ≥ 2 items at confidence ≥ 0.7
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

## 4. Instinct System (atomic, confidence-scored, project-scoped)

An **instinct** is an atomic learned behavior — **one trigger, one action** — finer-grained than a learning. A learning is a prose pattern; an instinct is a small, evidence-backed rule the agent applies by default.

### Observe via hooks, not skill-firing

Observation that relies on a skill firing is **probabilistic** (~50–80% — it fires on the agent's judgment). Hooks fire **100%** of the time, deterministically. So capture observations through the harness's hooks (Stop / PreCompact / PostToolUse), not by hoping a skill notices — every user correction, error resolution, and repeated workflow is an observation, and none should be missed.

### Instinct file format

Store at `.claude/session-state/instincts/<id>.md` (repo-local = **project-scoped** by nature):

```markdown
---
id: grep-before-edit
trigger: "before editing an unfamiliar file"
action: "grep/Read the file and its callers first"
confidence: 0.6        # 0.3 tentative → 0.9 near-certain
domain: tooling        # code-style | testing | git | debugging | workflow | tooling | domain | security
scope: global          # project (default) | global
evidence: 3            # observation count backing it
discovered: {date}
last-validated: {date}
---
- Action: {exactly what to do}
- Evidence: {the observations that created or raised it}
```

### Confidence (numeric 0.3–0.9)

| Score | Meaning | Behavior |
|-------|---------|----------|
| 0.3 | Tentative | suggested, not enforced |
| 0.5 | Moderate | applied when relevant |
| 0.7 | Strong | auto-applied |
| 0.9 | Near-certain | core behavior |

**Increase** when: repeatedly observed · user does not correct the applied behavior · an instinct from another source agrees.
**Decrease** when: user corrects it · not observed for a long stretch · contradicting evidence appears.

### Scope: project vs global

Default **project** (lives in this repo's `.claude/session-state/instincts/`). Tag **global** only for cross-project-stable behaviors.

| Pattern type | Scope |
|---|---|
| Framework/lang conventions, file structure, code style, error strategy | **project** |
| Security practices, general best practices, tool-workflow, git practices | **global** |

**Promotion (project → global)**: when the same instinct appears in 2+ projects with avg confidence ≥ 0.8, promote it — for this harness that means moving the stable fact into the **project-profile** (§6, where every agent reads it) or evolving it into a **skill** (§3). Project-scoping prevents cross-project contamination (React conventions never leak into a Python repo).

### Lifecycle

```
Observation (hook-captured)
  → instinct @0.3 (atomic, project-scoped)
  → confidence grows with repeat / non-correction
  → 3+ related, ≥0.7 → cluster → evolve (§3: skill | command | agent)
  → cross-project stable → promote to global (profile / skill)
```

### Pruning

- **Tentative (≤0.3) not reinforced in 30 days** → expire.
- **Contradicted** → remove immediately (user corrected it, or evidence disproves it).
- **Superseded** → remove when a better instinct replaces it.

### Observation capture (opt-in, harness-native — no Python/daemon)

To get v2's deterministic 100% capture without a background process: a lean **shell PostToolUse hook** appends a compact line (tool, target, outcome) to `.claude/session-state/observations.jsonl`; the existing **Stop hook**'s session-end step extracts instincts from it. This stays inside the harness's shell-hook + `.claude/session-state/` model — no background observer, no Python. Until that hook is wired, capture observations in `current.md` during work and extract instincts at milestones / Stop.

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

### Relationship to the `wiki` skill

The agent wiki (`.claude/wiki/`) is maintained by the separate `wiki` skill, but continuous-learning **feeds and governs** it — no overlap:
- **Feeds**: `learnings/` is one of the wiki's **ingest sources**. A high-confidence, project-stable learning may be promoted to a wiki page (in parallel with §6 profile promotion — routing, not duplication).
- **Governs**: this §7 maintenance contract IS the wiki's **lint** discipline (link-don't-duplicate, same-change-same-update, self-audit).
- **Boundary**: continuous-learning owns *patterns/instincts* (HOW to work — learnings, confidence, skill evolution); the wiki owns *knowledge/facts* (WHAT is true). Keep each in its own system.

## Quick Reference

```
State file:    .claude/session-state/current.md (update during session)
Learnings:     .claude/session-state/learnings/{topic}.md
Archive:       .claude/session-state/archive/ (auto-managed by hooks)
Extract:       After milestones — identify, validate, generalize, score, store
Reuse:         At task start, load matching learnings; route them into agent briefings; index when >10
Instincts:     .claude/session-state/instincts/<id>.md — atomic (1 trigger/1 action), confidence 0.3–0.9, scope project|global
Promote:       Project-stable learning/instinct → project-profile (read by default); project→global when seen in 2+ projects ≥0.8
Evolve:        3+ related items at ≥0.7 → skill | command | agent
Maintain:      Link don't duplicate; same change updates the doc it invalidates; verify a recalled fact still exists
Prune:         30-day TTL for pending, immediate for contradicted
```
