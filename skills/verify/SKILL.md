---
name: verify
description: "Run the project's authoritative gates from project-profile verify.json and produce a 됨 / 미검증 / 안 됨 evidence block — before reporting any change done or fixed, in team Phase 4, and after a /debug fix. Also plants a violation to prove a new check catches it."
argument-hint: "[--changed <base-ref>] [--only <step,…>]"
---

# Verify

Turns `reference/verification-loop.md`'s gate rules into commands, so "it passes" is a script's verdict rather than a reading of output. Two scripts live beside this file (`scripts/`, run with `node`):

- `verify.mjs` — runs the gates in `.claude/project-profile/verify.json` and judges each one.
- `plant.mjs` — plants one violation, runs a test, always restores, and says whether the test caught it.

## When to use

- Before reporting any implementation, fix, or refactor as done — the final message cites the block.
- Team Phase 4: the `team-tester` runs it on the merged HEAD with `--changed <base-ref>`.
- `/debug` step 5, after the failing test turns green.
- After adding a check, gate, or test that is meant to catch something: `plant.mjs`.

## 1. Run the gates — `verify.mjs`

```sh
node "<this skill's base directory>/scripts/verify.mjs" [--changed <base-ref>] [--only <step,…>] [--json]
```

- Run from anywhere inside the repo; it finds the repo root and reads `verify.json` there (in a linked worktree without one, the primary tree's).
- `--changed <base-ref>`: test steps that define a `changed` command run it with `{base}` filled in; the others run in full, and the block says so. Use the base ref the run started from.
- `--only`: a comma list of step names, for a quick re-check of one gate.
- Output: the block on stdout and in `_workspace/verify/<branch>.md`. Exit `0` 됨 · `1` 안 됨 · `3` 미검증 · `2` configuration or usage error (no or invalid `verify.json`, unknown step, a `--changed` ref that is not a commit).

| Step kind | 됨 | 미검증 | 안 됨 |
|---|---|---|---|
| `exit` | exit 0 | — | any other exit, timeout |
| `errors` | exit 0 | errors at or under a non-zero `baseline` (counts only, signatures not compared) | errors above baseline, a count it cannot read, a failing exit with 0 errors |
| `test` | tests ran, none failed, exit 0 | passed but no readable count; failures at or under a non-zero `failBaseline` (names not compared) | 0 tests ran, failures above baseline, a failing exit with an unreadable count |

The overall result is the worst step. Test counts are read from node --test, Vitest, Jest, Flutter/Dart, pytest, cargo, and Gradle output; any other runner passes as 미검증 — add its summary format to `countTests` rather than calling it 됨.

**Rules**
- No `verify.json` → stop with "run `/team-init --update`". Do not substitute commands from memory or a convenience alias; the file is the single source of the gates (schema: `project-analyzer` → `resources/profile-templates.md` §1a).
- A baseline changes only when it is re-counted on the untouched base, with the reason in `stack.md` → Build & Verify. Raising a baseline to make a run pass is masking.
- A 미검증 step stays 미검증 in the report. Comparing failure names or error signatures by hand can settle it: state what was compared.

## 2. Fill in the rest of the block

`verify.mjs` lists three lines it cannot judge. Replace each with the observed result or "not applicable":

- **Contract** — the backend contract changed and the client is generated → the `contract-sync` result (Step 5 consumption-site check included).
- **Planted violation** — the change adds a check, gate, or test meant to catch something → the `plant.mjs` line (below).
- **Persistence** — the change saves data → the DB value and the value after reload. A 200 response or a toast is not this.

After merging several worktrees, run `verify.mjs` once more on the merged tree.

## 3. Prove a check catches something — `plant.mjs`

```sh
node "<this skill's base directory>/scripts/plant.mjs" <file> --find <text> --replace <text> -- <test command…>
node "<this skill's base directory>/scripts/plant.mjs" --restore
```

- Replaces `--find` only when it occurs exactly once in the file; otherwise nothing changes.
- Prints one line: `됨` when the test command failed (caught the violation), `안 됨` when it passed or did not run. Exit `0` caught · `1` missed · `2` error. Paste the line into the block.
- The original is restored afterwards — also on interrupt — and its sha256 is checked. A backup left by a killed run (`_workspace/verify/plant/`) blocks the next plant until `--restore`.
- Refuses files outside the repo, under `_workspace/` or `.git` (any case), reached through a symlink, or ignored by git.
- Do not plant by hand with `sed` and a backup copy: a forgotten restore commits broken code.

## Result

Report the block as is: the automatic steps plus the filled lines. 됨 only when every line is 됨 or not applicable; any 미검증 line makes the report 미검증; any 안 됨 makes it 안 됨. Keep the failing tail lines the block attaches — do not summarize them away.
