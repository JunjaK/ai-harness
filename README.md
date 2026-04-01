# AI Harness — Multi-Agent Team Workflow

A reusable Claude Code harness for orchestrating multi-agent team workflows with 5 phases, escalation loops, and TDD enforcement.

## Overview

This harness provides a structured team workflow where specialized AI agents collaborate through defined phases to implement features, fix bugs, or refactor code.

### Team Roles

| Role | Agent | Model | When Called |
|------|-------|-------|------------|
| Team Leader | `team-leader` | opus | Always (Phase 1, Gate, Escalation) |
| Architect A (Frontend) | `team-architect-fe` | opus | Phase 1 (parallel with B) |
| Architect B (Backend) | `team-architect-be` | opus | Phase 1 (parallel with A) |
| Architect C (Infra/Security) | `team-architect-infra` | opus | Phase 1 (on-demand) + Phase 5 (always) |
| UI/UX Master | `team-uiux-master` | sonnet | Phase 2 (conditional) |
| Designer x N | `team-designer` | opus | Phase 3 (parallel, worktree isolated) |
| Tester x N | `team-tester` | sonnet | Phase 4 (parallel) |

### Workflow Phases

```
Phase 1: Planning
  Leader drafts plan → Arch A + B detail (parallel) → Cross-review → File assignment

Phase 2: UI/UX (conditional)
  UI/UX Master reviews and proposes changes

Leader Approval Gate
  Approve → Phase 3 | Reject → Phase 1

Phase 3: Implementation (TDD)
  Designer x N in parallel worktrees (Red-Green-Refactor)

Phase 4: Verification
  Tester x N (unit + E2E, loop until pass)

Phase 5: Final Security Review
  Arch C security & infra audit → SHIP or escalate
```

### Escalation

- Each agent self-judges: simple fix (retry, max 3) vs fundamental issue (escalate up)
- Global re-plan limit: 3 cycles to prevent infinite loops
- Both `/team` and `/team-run` report escalation events to user

## Commands

| Command | Description |
|---------|-------------|
| `/team` | Interactive mode — user participates in planning phase |
| `/team-run` | Autonomous mode — full auto-execution |

## Installation

Copy the `.claude/` directory into your project root:

```bash
# Clone this repo
git clone https://github.com/JunjaK/ai-harness.git

# Copy .claude/ into your project
cp -r ai-harness/.claude/ /path/to/your/project/
```

Then customize the agent definitions to match your project's stack and conventions.

## Customization

### Adapting to Your Stack

The agents are framework-agnostic by default. To specialize for your project:

1. **team-architect-fe.md** — Add your frontend conventions (component patterns, state management, styling)
2. **team-architect-be.md** — Add your backend conventions (API patterns, ORM, database)
3. **team-architect-infra.md** — Add your security checklist (auth patterns, env management)
4. **team-designer.md** — Add your test framework and TDD patterns
5. **team-tester.md** — Add your test runner commands and E2E setup

### Plan Storage (`_docs/`)

Team plans are saved to the `_docs/` directory with the following structure:

```
_docs/
├── index.md              # Documentation index (always updated)
├── data-template/        # Category folder
├── data-sheet/           # Category folder
├── infra/                # Category folder
└── {category}/           # Add folders as needed
    └── plan-{feature}.md # Team plan document
```

**Plan lifecycle:**
1. Phase 1 complete → save plan to `_docs/{category}/plan-{feature}.md` (status: Planning)
2. Phase 3 complete → update with implementation notes (status: In Progress)
3. Phase 4 complete → update with test results (status: Verification)
4. Phase 5 complete → update with final summary (status: Complete)

Always update `_docs/index.md` when adding new plans. To customize the path, modify:
- `team-leader.md` (plan output section)
- `SKILL.md` (Phase 1 Step 5, Phase 3/4/5 update steps)

## Supporting Skills

Skills that agents reference during their workflow phases:

| Skill | Phase | Purpose |
|-------|-------|---------|
| `plan-review` | Phase 1 | Critical review of plans before implementation |
| `api-design` | Phase 1 | REST API design patterns for Architect B |
| `coding-standards` | Phase 3 | Universal code quality baseline for Designers |
| `tdd-workflow` | Phase 3 | Red-Green-Refactor TDD cycle |
| `debug` | Phase 3-4 | Structured debugging during escalation |
| `e2e-testing` | Phase 4 | Playwright E2E patterns for Testers |
| `verification-loop` | Phase 4-5 | 6-phase quality gate (build, type, lint, test, security, diff) |
| `security-review` | Phase 5 | OWASP Top 10 checklist for Architect C |

## File Structure

```
.claude/
├── agents/
│   ├── team-leader.md           # Coordination, planning, approval
│   ├── team-architect-fe.md     # Frontend architecture
│   ├── team-architect-be.md     # Backend architecture
│   ├── team-architect-infra.md  # Infra/security review
│   ├── team-uiux-master.md     # UI/UX proposals
│   ├── team-designer.md        # TDD implementation
│   └── team-tester.md          # Test verification
├── commands/
│   ├── team.md                  # /team (interactive)
│   └── team-run.md             # /team-run (autonomous)
└── skills/
    ├── team-workflow/           # Core orchestration
    │   ├── SKILL.md
    │   └── resources/
    │       ├── agents.md
    │       └── escalation.md
    ├── plan-review/SKILL.md     # Phase 1: plan critique
    ├── api-design/SKILL.md      # Phase 1: API patterns
    ├── coding-standards/SKILL.md # Phase 3: code quality
    ├── tdd-workflow/SKILL.md    # Phase 3: TDD cycle
    ├── debug/SKILL.md           # Phase 3-4: debugging
    ├── e2e-testing/SKILL.md     # Phase 4: E2E patterns
    ├── verification-loop/SKILL.md # Phase 4-5: quality gate
    └── security-review/SKILL.md # Phase 5: security audit
```

## License

MIT
