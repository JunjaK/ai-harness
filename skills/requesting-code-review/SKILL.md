---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements. Dispatches a code-reviewer subagent with crafted context.
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

> Complements, does not replace: in a team workflow the Phase 4 `team-tester` and Phase 5 `security-review` are the gated audits, and Claude Code's built-in `/review` + `/security-review` cover the diff. Use this skill for lightweight, on-demand reviews between tasks or before a merge gate.

## When to Request Review

**Mandatory:**
- After each task when running subagent-driven / multi-task implementation
- After completing a major feature
- Before merge to main (the user gates the actual merge)

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing a complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)   # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [resources/code-reviewer.md](resources/code-reviewer.md).

**Placeholders:**
- `{DESCRIPTION}` — brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` — what it should do (plan file path under `_docs/`, task text, or requirements)
- `{BASE_SHA}` — starting commit
- `{HEAD_SHA}` — ending commit

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if the reviewer is wrong, with reasoning — but verify each claim against the actual code/tests before either agreeing or dismissing it (don't perform agreement, and don't wave off valid feedback)

## Example

```
[Just completed Task 2: Add verification function]

Let me request code review before proceeding.

BASE_SHA=$(git rev-parse HEAD~1)
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from _docs/active/planning/<date>/<topic>-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

[Fix progress indicators] → [Continue to Task 3]
```

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If the reviewer is wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [resources/code-reviewer.md](resources/code-reviewer.md)
