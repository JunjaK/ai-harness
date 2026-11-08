---
topic: qesg-borrow
kind: plan
status: planning
created: 2026-11-08
updated: 2026-11-08
---

# Backlog — techniques worth borrowing from the company harness

Source: `qesg-harness` (`/Users/jun/develop/qesg/qesg-harness`, v0.1.0–v1.8.11, 2026-10-07~11-06, 225 commits),
reviewed 2026-11-08 against this harness at v1.36.0. Paths below are relative to that repo unless they start with
this repo's folders. Borrow the technique, not a dependency.

Done in the same session (2026-11-08, released with the next version): ego lite as the only browser driver
(`skills/browser-e2e`, `hooks/browser-guard.sh`), Jev protocol-version negotiation, the Jev node launcher,
`onFailure: "block"` on the guardrails hook, and the opt-in `korean_reply` Stop hook. The root-artifact warning
was already here (`hooks/session-stop.sh`), so nothing was borrowed for it.

Each item states what this harness has now (checked 2026-11-08), so the gap is the part not already covered.

## B1. Verification as a command, not only a document

- **qesg**: `qesg verify` (`scripts/lib/verify.mjs`, 123 lines) runs the repo's authoritative commands, gates type/lint
  on net-new vs baseline, reads the test count (0 tests → not done, unreadable → unverified), writes an evidence block
  to `_workspace/`, exits 1 on failure. `qesg verify:plant <file> --find --replace -- <test cmd>`
  (`scripts/lib/verify-plant.mjs`, 139 lines) plants one violation, runs the test, always restores, checks sha256.
- **Here**: the same rules exist only as `reference/verification-loop.md` (Baseline & Net-New, Vacuity guard); the
  model applies them by hand. The 2026-11-08 Jev change was verified with a manual plant/restore — the script form
  would have made that one command.
- **Open question**: source of commands is `project-profile/stack.md` → "Build & Verify" (prose), not a JSON policy.
  A machine-readable block would be needed first.

## B2. Skill evals with/without the skill (Δ), then prune

- **qesg**: `evals/` — 10 cases for `claude plugin eval . --scaffold … --runs 2` (with − without ablation). Δ≈0 led
  to removing `testing`, folding `test-scenario-doc` into `qa`, dropping `checkpoint` (native `--continue`/`--resume`),
  making `plan` human-only; descriptions cut from 835 to ≤242 chars ("when to use" only). Cost 10-18: $3.60 / $7.04
  per run (list-price estimate).
- **Here**: no ablation suite (`skills/test-scenario-doc/evals/evals.json` holds 3 skill-creator prompts only).
  Longest descriptions: submodule-worktree 856, brain-connect 811, docs-lifecycle 714, contract-sync 712 chars.

## B3. contract-sync: confirm the running backend is this branch's build

- **qesg**: `skills/contract-sync/SKILL.md` checks that the backend serving the spec belongs to the current branch
  before regenerating.
- **Here**: Step 1 restarts a running backend so the spec is current; Step 3 already isolates whitespace/EOL churn
  and restores hand-maintained files the generator stripped; Step 5 already cross-checks consumption-site shapes.
  **Gap**: nothing checks *which* backend answers on the spec URL. With several backends up at once (main 5090,
  worktrees 4xxx), codegen can read another branch's spec.

## B4. debug: regression bisect, existing fixes, same-pattern sweep

- **qesg**: `skills/debug/SKILL.md` — for a regression, run the same repro read-only at a known-good commit and
  diff to locate when it broke; search other branches for an existing fix; after the fix, sweep the same pattern in
  copied code, other locales, sibling repos (R14).
- **Here**: `commands/debug.md` guards at the shared function and flags "only the call site the report named".
  **Gap**: copies that do not route through a shared function, other locales, sibling repos, other branches'
  fixes, and the known-good-commit repro.

## B5. db-runbook for data-changing SQL

- **qesg**: `skills/db-runbook/SKILL.md`, `templates/db-script.sql` (env guard, target-count gate,
  analyze → dry-run → apply, backup first, post-check, idempotent), `templates/runbook.md` (human-executed
  production runbook: slices, pre-gates, baselines, rollback, execution log). SQL template checked on PostgreSQL 18
  in 7 cases.
- **Here**: none. Matches the persona's migration ritual (backup → change → expected-vs-actual count → commit →
  drop backup; production run by the human). Company-specific parts (`db:psql`, SSM, write ledger) stay out.

## B6. worktree prune

- **qesg**: `qesg worktree:prune` (`scripts/lib/worktree-prune.mjs`, 326 lines) lists worktrees whose PR is merged or
  closed, with no local changes, no unpushed commits, and no open terminal; deletes only after confirmation.
  Motivation: 160+ worktrees on one PC, 100+ already merged (10-22).
- **Here**: `skills/parallelization/SKILL.md` says to `git worktree remove` after merge; no tool lists candidates.

## B7. Relayed approvals between sessions

- **qesg**: R21 — an approval relayed by another session counts only for reversible actions (PR merge, dev/stage
  deploy); irreversible ones (data deletion, production DB, force push, main deploy/push) need approval in that
  session; relays quote the user's original words.
- **Here**: the parallel-session rule covers git staging only. Relevant once SendMessage / Orca relays are used.

## Not borrowed (company-only)

Policy file + `/qesg:init` + managed AGENTS block, issue/PR/Project conventions, `pr:gate`/`pr:merged`,
`db:psql` + write ledger + SSM, `qa-login:fill` / `qa-core:open-link`, `core:up`, qesg-guard + usage reporting,
Hermes adapter, packs, release-notes / deploy-check / bump-shared, Codex role effort, `/qesg:orchestrate`
(revisit if Orca + Codex become part of personal work).
