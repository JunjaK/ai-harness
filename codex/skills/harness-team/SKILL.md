---
name: harness-team
description: Plan, implement, lightly verify, and document a cross-cutting change in Codex; defer deeper QA to a later explicit request.
---

# Team workflow for Codex

This self-contained workflow covers implementation through a single quick
verification pass. Treat an implementation request as authorization to finish
the work. Ask about a material product decision only when evidence cannot
settle it. An interactive planning-only request ends with a reviewable plan.
Codex does not invoke Claude slash commands, named agents, or `Workflow()`.

## Phase 1 — prepare and plan

1. Check `git status --short --branch` and preserve existing work. Record
   `baseRef` as `git rev-parse HEAD` before editing and `startedAt` as the UTC
   start time. Read repository instructions, the nearest `package.json` for
   JS/TS work, relevant code/tests, and the existing project profile if any.
2. Define behavior, boundaries, affected interfaces, file ownership, and
   acceptance checks. For a cross-cutting task in a project already using
   `_docs/`, write or update its indexed plan under `_docs/active/planning/`;
   otherwise use the project's own plan location or the conversation. Do not
   create a new document system in a project that lacks one.
3. If Codex exposes subagent tools and tasks have separate file scopes,
   delegate bounded tasks with one editor per file and explicit evidence.
   Use a smaller available model only when the subtask is read-only **or**
   changes at most two files in one domain, and it has no auth, payment,
   secrets, personal-data, or contract change and follows a deterministic
   checklist. Use the strongest available model for every other or ambiguous
   subtask. Do not hard-code a model version; inherit the session's effort.
   Work serially if delegation is unavailable.

## Phase 2 — design gate when needed

For UI or contract changes, inspect the affected flow and settle the smallest
compatible design before editing. If the design changes a required public
interface, use the user's existing authorization or ask before breaking it.
For `_docs/` intents, specs, plans, handoffs, and findings, draw branching
flows as inline Mermaid `flowchart`, state changes as `stateDiagram-v2`, and
component interactions as `sequenceDiagram`; keep linear steps as a list.

## Phase 3 — implement

Follow observed project patterns and add focused regression coverage for
changed behavior. If a server contract changes and the project has a generated
client, regenerate it with the existing command before adapting callers. Add
no new dependency. Review the integrated diff for correctness, data handling,
security, interface compatibility, and unrelated edits. For auth, payments,
secrets, or personal data, perform a dedicated security review.

## Phase 4 — one lightweight verification pass

Run the affected unit/integration tests and relevant authoritative build,
type, and lint gates once on the integrated tree. Run at most one existing
smoke E2E per affected flow when its prerequisites are already available.
Reuse checks already run on the same integrated tree. Compare failures with a reliable
pre-task baseline (`baseRef`), recording proven pre-existing failures, command,
exit/count, scope, and unavailable checks. Do not launch broad agentic QA or
automatically loop back to implementation from this phase.

- `VERIFY_PASS`: every required quick check ran, with no net-new failure
  against a reliable baseline. Continue to Phase 5.
- `VERIFY_FAIL`: a required check or executed smoke has a new failure, or a
  changed behavior lacks a relevant test. Record reproduction, baseline,
  likely owner, and next check; end this run as incomplete.
- `VERIFY_BLOCKED`: a required check could not run or its failure cannot be
  attributed because a prerequisite or reliable baseline is missing. Name
  the missing item and owner; end this run as unverified. An optional smoke
  that is not runnable becomes a Deferred QA candidate instead.

On `VERIFY_FAIL` or `VERIFY_BLOCKED`, keep a lifecycle plan in
`active/processing/`; report the verdict, active plan path, and a concrete
fix/unblock step. Do not claim implementation complete or generate final QA
entries from an incomplete run. A later `$harness-debug` or new team task can
address the result.

## Phase 5 — reconcile, archive, and defer QA

Only after `VERIFY_PASS`:

1. Compare the plan, tests, security review, affected wiki pages, and final
   code. Correct stale claims and links. Check documentation freshness.
2. Derive **up to five** risk-ordered scenarios from acceptance criteria not
   covered by quick checks. In a project using `_docs/`, write `## Deferred QA`
   in the completed implementation archive. Each entry has a stable
   `<archive-stem>-01` through `-05` ID, Priority, Preconditions, Actions,
   observable Expected, Source, `Status: pending`, and `Evidence: —`. For a
   non-behavioral task with none, write `- No scenarios: <specific reason>`.
   Do not execute these scenarios in this run. Later QA requires an explicit
   user request; update verdict/evidence in the same archive then.
3. Apply the project's document lifecycle merge/move rule and update its
   index. Promote project-valid learnings captured since `startedAt` from
   temporary session state into `_docs/reference/<topic>/` (or the topic's
   existing reference doc), with evidence. Move operational facts to the
   project profile; leave agent-only know-how in session state. Delete a
   learning only after its durable destination is recorded.
4. Perform the equivalent of `/docs-sweep --since <baseRef>`: compute changed
   `_docs/` paths from `git diff --name-only <baseRef> -- _docs` plus
   `git status --porcelain -- _docs`. Reap only this run's active lifecycle
   docs, based on completion/abandonment signals rather than age alone. Check
   all six document invariants across `_docs/` and linked wiki pages, but
   fix only in-scope files and their own index rows. Report out-of-scope
   findings without editing them. Do not reap collection buckets.
5. Report the Phase 4 verdict and evidence, unverified checks, completed plan
   path, pending QA count, and that deeper QA awaits a separate request.
   `status: complete` means implementation complete; pending QA has its own
   verdict.

Codex does not write Claude's session checkpoint or team-run files. If a
handoff requires reading Claude state, use the current
`.claude/session-state/sessions/<session_id>/` and
`.claude/session-state/runs/<plan-id>.json` layout; a run file records
`owner_session`, `startedAt`, and `baseRef`. Do not use the removed root
`current.md` or `team-run.json` paths. Keep `.claude/session-state/` ignored
by Git.
