---
name: harness-team
description: Plan, implement, verify, and review a cross-cutting code change in Codex. Use for multi-file features or architecture work; not for a small isolated bug.
---

# Team workflow for Codex

This is an executable Codex counterpart to Claude's `/team` and `/team-run`.
Treat a request to implement as authorization to finish implementation and
verification. Ask the user about a material product decision only when evidence
cannot settle it; an interactive planning request stops after a reviewable plan.

## Prepare and plan

1. Check `git status --short --branch`; preserve all pre-existing changes. Read
   repository instructions, the nearest `package.json` for JS/TS work, relevant
   source, tests, and `.codex/project-profile/index.md` if it exists. If the
   profile is absent or stale, inspect source directly; optionally use
   `$harness-init` when profiling is itself requested.
2. Define the requested behavior, current behavior, affected interfaces, file
   ownership, and verification criteria. For a change touching three or more
   files, crossing API/UI/state boundaries, or affecting auth or payments, record a
   concise plan in `_docs/active/planning/` only if the project already uses the
   AI Harness `_docs/` convention; otherwise use the conversation or the
   project's own plan location. Preserve existing document collections.
3. When Codex exposes subagent tools and two tasks have separate file scopes,
   delegate bounded tasks with explicit file scope and expected
   evidence. Keep one owner for each edited file and synthesize results before
   changing shared interfaces. A missing subagent tool is a serial path, not a
   reason to stop. Do not call Claude `Agent()` or `Workflow()` syntax.

## Implement and verify

4. Implement against observed project patterns, with focused regression tests
   where behavior changed. If a server contract changes and the project uses a
   generated client, regenerate it with the existing project command before
   adapting callers. Add no dependency without the user's authorization.
5. Run the relevant checks declared by the project: focused tests, typecheck,
   lint, build, and UI/E2E checks when a user-facing flow changed and a driver is
   available. Distinguish baseline failures from failures caused by this task.
   Report any unavailable check as `unverified` with the reason.
6. Review the final diff for correctness, security and data handling, interface
   compatibility, and unrequested changes. For auth, authorization, payments,
   secrets, or personal data changes,
   perform a dedicated security review; a Codex subagent may do an independent
   read-only pass when available. Resolve findings and rerun affected checks.

## Handle plan failures

If a one-file correction has a known cause and preserves contracts, fix and
recheck it. If evidence disproves the plan, revise the plan before more edits.
After two failed hypotheses on the same issue, stop guessing and surface the
remaining uncertainty. Never claim checks passed from an agent report alone;
inspect command results. Finish with changed files, behavior, verification
results, and remaining limits.
