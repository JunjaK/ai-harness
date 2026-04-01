# AI Harness — Claude Code Configuration

## Required: Agent Teams Feature

**This harness requires Claude Code Agent Teams.** The feature is enabled via `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

If this env variable is not set, `/team`, `/team-run`, and `/team-brainstorm` commands will NOT work properly (TeamCreate, cross-review dialog, and multi-agent orchestration depend on it).

---

## Team Workflow Commands (MUST USE)

**All feature implementation, bug fixes, and refactoring MUST go through the team workflow.**

| Command | When to Use |
|---------|-------------|
| `/team-brainstorm` | Planning/discussion only — no code changes |
| `/team` | Full workflow with user involvement in planning |
| `/team-run "description"` | Full autonomous workflow |

### Decision Guide

```
Is this a complex feature (3+ files, cross-cutting)?
  YES → /team or /team-run
  NO  → Is there architectural uncertainty?
    YES → /team-brainstorm first, then /team-run
    NO  → Direct implementation is OK for trivial changes (typo, config)
```

**Trivial changes** (single file, obvious fix) do NOT require team workflow.
**Everything else** MUST use `/team`, `/team-run`, or `/team-brainstorm`.

---

## Plan Storage

All plans are saved to `_docs/` with visual HTML alongside:

```
_docs/
├── index.md                        # Always update when adding plans
├── {category}/
│   ├── plan-{feature}.md           # Plan document
│   └── plan-{feature}.visual.html  # Visual diagram (auto-generated)
```

---

## Agents

All agents are defined in `.claude/agents/` and invoked by the team-workflow skill.

| Agent | Model | Role |
|-------|-------|------|
| team-leader | opus | Coordination, planning, approval gates |
| team-architect-fe | opus | Frontend architecture |
| team-architect-be | opus | Backend architecture |
| team-architect-infra | opus | Infra/security (on-demand + final review) |
| team-uiux-master | opus | UI/UX design intelligence |
| team-designer | opus | TDD implementation (Red-Green-Refactor) |
| team-tester | sonnet | Unit + E2E test verification |

---

## Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| team-workflow | Core | 5-phase orchestration |
| plan-review | Phase 1 | Critical plan evaluation |
| api-design | Phase 1 | REST API patterns |
| plan-visualizer | Phase 1+ | HTML plan diagram |
| coding-standards | Phase 3 | Code quality baseline |
| tdd-workflow | Phase 3 | TDD cycle |
| debug | Phase 3-4 | Structured debugging |
| e2e-testing | Phase 4 | Playwright E2E |
| verification-loop | Phase 4-5 | 6-phase quality gate |
| security-review | Phase 5 | OWASP checklist |

---

## Agent Execution Mode

When spawning agents via Team workflow:
- **Always use `mode: "bypassPermissions"`** — agents work in isolated worktrees
- **Designers use `isolation: "worktree"`** for parallel work
- **Cross-review uses `TeamCreate`** for multi-agent dialog

---

## Escalation Rules

- Each agent self-judges: simple fix (retry, max 3) vs fundamental (escalate)
- Global re-plan limit: 3 cycles
- Both `/team` and `/team-run` report escalation events to user
- See `.claude/skills/team-workflow/resources/escalation.md` for details
