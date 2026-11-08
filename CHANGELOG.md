# Changelog

All notable changes to the **AI Harness** plugin. Distributed via the `JunjaK/ai-harness` marketplace and **version-cached** — an unchanged version is a no-op even after a marketplace update.

Versions follow `MAJOR.MINOR.PATCH`: **minor** = new skill/agent/command/behavior, **patch** = fix. Pure docs/chore changes (this file, `CLAUDE.md`, `.claude/rules/`) ship without a bump.

## v1.39.0 — 2026-11-08

Verification as a command: item B1 of `_docs/active/planning/2026-11-08-qesg-borrow-plan.md`, ported from the company harness (`qesg verify` v1.5.0 and `verify:plant` v1.7.0). The gate rules already in `reference/verification-loop.md` (baseline & net-new, vacuity guard) are now applied by a script instead of by reading output. The command source and the baseline semantics were decided by the user (A / a). The Codex adapter moves to 1.39.0 with no change.

**Breaking:** the authoritative gate commands move from `stack.md` / `testing.md` prose to `.claude/project-profile/verify.json`. A project without that file gets "gates unconfigured" (unverified) from the Phase 4 tester, Designers, and `/debug` until `/team-init --update` writes it.

### Added
- **`verify` skill.** `scripts/verify.mjs` runs the steps in `verify.json` and judges each one 됨 / 미검증 / 안 됨, writes the evidence block to `_workspace/verify/<branch>.md`, and exits 0 / 3 / 1 (2 for a configuration or usage error). Step kinds: `exit` (exit code), `errors` (type-check / lint / analyze count vs `baseline`), `test` (test count vs `failBaseline`; 0 tests ran is a failure). `--changed <base-ref>` runs a step's `changed` command (`{base}` filled) for affected tests, `--only` re-checks single steps. Test counts are read from node --test, Vitest, Jest, Flutter/Dart, pytest, cargo, and Gradle; another runner's pass is 미검증. A count at or under a non-zero baseline is 미검증, never 됨: a fixed and a new failure cancel out, and names or signatures are not compared. 12 tests; on this repo with a temporary `verify.json` it read 16 and 22 tests from real node --test output.
- `scripts/plant.mjs`: plants one violation (only when `--find` occurs exactly once), runs a test, always restores (also on interrupt) and checks sha256; `됨` when the test caught it. Keeps the company harness's security-review fixes: files outside the repo, under `_workspace/` or `.git` in any case, through a symlink, or ignored by git are refused, and a forged backup is not restored. 4 tests. Planting two violations into `verify.mjs`'s verdict logic made its tests fail both times.
- `verify.json` profile template (`project-analyzer` → `resources/profile-templates.md` §1a). Unknown keys are rejected so a typo cannot drop a baseline; `cwd` keeps one step per sub-project inside the repo.

### Changed
- `stack.md` → Build & Verify keeps only the vacuity evidence, baseline source, and caveats; its Build list and `testing.md`'s Test Commands no longer repeat gate commands (E2E and coverage stay in `testing.md`).
- `project-analyzer` / `/team-init` write `verify.json` with `stack.md` (each command run once on the untouched tree; unknown gates are left out and named, never invented); Seeded Mode writes it with every baseline 0.
- `team-tester` (Phase 4) runs `verify.mjs --changed <base-ref>` on the merged tree and attaches the block; Designers run it in their worktree; `/debug` step 5, the `debug` skill, and `contract-sync` Step 4 use it; `reference/verification-loop.md`, `CLAUDE.md`, and `.claude/rules/typescript.md` point at `verify.json`.

## v1.38.0 — 2026-11-08

A reuse check for existing components (user request, 2026-11-08), and fixes to the v1.37.0 `browser-guard` hook from an automated security review of that release. The same reuse rule was added to the author's personal global `CLAUDE.md` so it also applies outside the harness. The Codex adapter moves to 1.38.0 with no change.

### Added
- **Reuse check** (`reference/coding-standards.md` §4 rung 2). The rung "already in this codebase → reuse it" now asks three questions for each candidate: reusable as-is? → the change needed to make it reusable (signature, branches, callers) → is that change riskier or larger than writing new (many callers to re-verify, behavior shifts for current users, a responsibility it was never shaped for)? Larger → continue down the ladder; otherwise generalize it into a shared component and build on it. The verdict and its reason go in the plan (solo work: before the first edit).
  - `team-architect-fe` / `team-architect-be` / `web-architect` record the verdict in their plans; `team-designer` reports a candidate the plan did not weigh to the Leader instead of writing new beside it or generalizing it alone; `plan-review` flags new code beside a near-match without a verdict, and a generalization that touches more callers than the new code would; `brainstorm` designs carry the verdict.

### Fixed
- **`browser-guard` review findings.** The ego checks (whole-profile clears, a task space without `profileId`) ran only when `ego-browser` sat in the program position, so a quoted or escaped program name skipped them; they now run whenever the command mentions `ego-browser`. `eval`, `xargs`, `bash --login -c`, and backslash-split names (`a\gent-browser`) are caught. `profileId` counts only as an options key (`profileId:` or `{ profileId }`), not inside a string, and `taskSpace (` with a space is checked. Both `browser-guard` entries now have `"onFailure": "block"`, and without `jq` a Bash command that mentions a browser CLI is denied instead of passed. Quoted text is still not read as a program (so `waitForSelector("aside")` in an ego script passes); the threat model — mistakes and tool drift, not deliberate evasion — is stated in the hook and the `browser-e2e` skill. Tests 34 → 47.

## v1.37.0 — 2026-11-08

Techniques borrowed from the company harness (`qesg-harness` v1.6.0–v1.8.5, 2026-10-21~11-03), reviewed against v1.36.0; the items left for later are in `_docs/active/planning/2026-11-08-qesg-borrow-plan.md`. The main change: **ego lite becomes the only browser driver**, following the company harness's 54-run comparison on a real app (ego 27/27 with 0 hangs, agent-browser 23/27 with 3 daemon hangs, equal time once hangs are excluded, ego ~8% more cost). The new hooks were run in a live `claude -p --plugin-dir` session. The Codex adapter moves to 1.37.0 with no change.

**Breaking:** agent-browser, Aside, and Playwright MCP are denied in every project where the plugin is enabled, and there is no fallback driver: without ego lite (or on Linux / CI) browser QA is `blocked`. A project whose `.claude/project-profile/testing.md` names agent-browser as its driver needs `/team-init --update`.

### Added
- **`browser-e2e` skill** (ego lite only). Gate: `ego-browser --version` and a free QA profile. A failed gate stops with the install steps; it never switches to another browser tool. Measured pitfalls ported from the company harness: hidden console, network events only while the process lives, output on stderr (`| tee` gives an empty file), autosave before reload, single-match selectors, shared clipboard and downloads, file choosers, untitled pages that print a token-bearing URL.
- `skills/browser-e2e/scripts/qa-profile.mjs` (needs `node`): picks a `harness-qa*` profile with no open task space or creates the next one (ego has no create-profile command; the script opens `--profile-directory=Profile N` and renames it), up to 10, under a lock, never touching other profiles. Optional `--space-name` opens a task space per profile. 7 tests; on macOS it created `harness-qa1`, a rerun reused it, and no window was left open.
- `hooks/browser-guard.sh` (PreToolUse `Bash` and `mcp__.*playwright.*`): denies running `agent-browser` / `aside`, Playwright MCP tools, ego whole-profile clears (`--clear-existing-profiles`, `Network.clearBrowserCookies` / `clearBrowserCache`, `Storage.clearCookies`), and a named `taskSpace(...)` without `profileId` (the default profile may be a real account). Only the program position counts, so `grep agent-browser` and commit messages pass. 34 tests; in a live session `agent-browser --version` and Playwright `browser_navigate` were both denied.
- **`korean_reply`** (`/plugin` → Configure, default off): a Stop hook (`hooks/reply-language.mjs`) sends a final reply back once when it has 2+ English sentences of 4+ words outnumbering the Korean ones (code, paths, URLs ignored; the second Stop always passes). 9 tests; in a live session an English answer was rewritten in Korean. That run set `CLAUDE_PLUGIN_OPTION_KOREAN_REPLY` through `--settings` env; saving it through Configure was not exercised.
- `mcp/jev.mjs`: the Jev server launcher. It starts the first of `python3` / `python` / `py -3` that answers as Python 3, and on Windows scans PATH itself to skip the WindowsApps alias stubs (the company harness saw its server fail to start on Windows this way). 6 tests, including a real server start.

### Changed
- `agentic-testing`, `team-agentic-tester`, `reference/e2e-testing.md`: the web driver is ego lite through the `browser-e2e` gate; a failed gate marks web scenarios `blocked`. The login is done by the human once per QA profile.
- `project-analyzer` profile template: the web `Driver` is `ego-browser`; `agent-browser` and `playwright-mcp` are gone.
- Jev stop gate counts `ego-browser` commands as checks instead of `agent-browser`.
- The guardrails PreToolUse hook has `"onFailure": "block"`: a timeout, a failed start, or an exit code other than 0/2 now blocks the git command instead of letting it run (the hooks reference lists those as failures). The guardrails evaluator's deliberate exits are 0 and 2 only.
- README requirements: Jev needs `node` + Python 3; ego lite replaces the agent-browser row and install line.

### Fixed
- **Jev MCP protocol negotiation.** `initialize` echoed whatever version the client sent, claiming features the server never implemented. It now answers the requested version only when supported (`2025-11-25`, `2025-06-18`, `2024-11-05`), otherwise the latest of those. Re-planting the echo made the new test cases fail.

### Removed
- `agent-browser-e2e` skill: agent-browser driving, the Auth Vault / session / headless-login procedures, and the Playwright MCP fallback driver.

## v1.36.0 — 2026-10-29

Catch-up with Claude Code 2.1.90–2.1.312 (the harness started on 2.1.90). The changelog range was checked against the harness, and the suspected breaks were run before fixing: an isolated worktree agent's Write to the main checkout was refused, and a PostToolUse hook's warning ran (`exit 0`) but never reached Claude. The fixed hooks were re-run in a live `claude -p --plugin-dir` session. The Codex adapter moves to 1.36.0 with no change.

### Added
- `hooks/session-compact.sh` (SessionStart `compact`): after any compaction (auto, manual, idle) it puts this session's `current.md` and any team run it owns back into Claude's context. SessionStart stdout is one of the few hook outputs Claude sees; a live `/compact` + resume showed the marker in context.
- `release.sh check` runs `claude plugin validate` and fails the release on a validation error.
- `brain-connect` recommended settings: `worktree.baseRef: "head"`.

### Changed
- **Isolated Designers return their notes instead of writing `_docs/`.** Claude Code refuses an `isolation: "worktree"` agent's Write/Edit outside its worktree (observed: `This agent is isolated in the worktree … Edit the worktree copy of this file instead of the shared-checkout path.`). `team-workflow`, `team-designer`, `team-leader`, `docs-lifecycle`, `parallelization`, `CLAUDE.md`, and `.claude/rules/docs.md` now have the orchestrator write the reported notes. An agent in a manually created worktree (`git worktree add`) still writes its own files.
- `team-workflow` states that Designer worktrees branch from local `HEAD` only when `worktree.baseRef` is `"head"`; the default `fresh` (2.1.133) branches from `origin/<default>`.
- `pre-compact.sh` only snapshots `current.md`. Claude Code keeps no PreCompact output for Claude, and Claude gets no turn before compacting, so the "update current.md" prompt never reached it.
- `/team-new` G1: the user runs `/deep-research <question>`; Claude can no longer start it (2.1.218).
- Auto-compact guidance in `README.md` and `reference/token-optimization.md` moves from `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` to the per-model `/autocompact <window>`, and notes that idle compaction also fires PreCompact `auto`.

### Fixed
- **`post-edit-warn.sh` warnings now reach Claude.** PostToolUse plain stdout goes only to the debug log; the console/debugger and append-only collection warnings now go out as `hookSpecificOutput.additionalContext`. A live run quoted the warning back.
- `session-stop.sh`'s stray-artifact warning is shown to the user as `systemMessage`; Stop stdout was also debug-log only.
- `mode="bypassPermissions"` removed from `team-workflow`'s `Agent()` calls and `/team-run`: the parameter has been ignored since 2.1.212, and subagents inherit the session's permission mode.
- `hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` (6 `claude plugin validate` warnings → 0), and SessionStart also matches `fork` (2.1.214).
- Stale statements: `Agent()` has an `effort` parameter (2.1.292; the harness still passes it only on explicit request); greenfield no longer writes the removed `AGENT_TEAMS=1` (2.1.178); `.claude/rules/` load on write as well as read (2.1.288); `/checkpoint` names `session-end.sh`, not `session-stop.sh`, as the end-of-session snapshot.

## v1.35.0 — 2026-09-28

Fixes from live QA on a Nuxt web app (picblog) and a Flutter app (nivoca). Plan and outcome: `_docs/complete/jev-checks/2026-09-28-jev-checks-plan.md`. The Codex adapter moves to 1.35.0 with no change.

### Added
- **Jev `on_target` check.** `qa_crosscheck` also asks whether the evidence shows the steps ran on the target app or page. Below 0.35, a `passed`/`failed` label becomes `insufficient_evidence` with a `note`, shown as `contested`. Before this, a launch that opened another app (Google Calendar in front, empty `pidof`) was read as `failed` (0.75–0.90). On 15 probe cases the two off-target runs scored 0.10–0.15 and every on-target passed/failed run 0.55–0.97.
- MCP tool `qa_status`: whether `qa_crosscheck` can run, without a Jev call. `agentic-testing` calls it once before the first scenario and tells the user a skip reason (for example a missing key) up front.
- `qa_crosscheck` returns `elapsed_ms`. Inside the server a call takes about 250 ms; a 5.3 s wait seen in a QA run came from outside it (parallel calls queue on the one-request-at-a-time stdio server — suspected, not verified).
- `agentic-testing`: a `device-lifecycle` mobile driver for projects without maestro/Patrol/mobile MCP (`integration_test` output + `adb`/`xcrun simctl` launch, stop, `pidof`, screenshot + a data-store check), with its traps: `monkey -p` can open another app, and `flutter test` uninstalls the app on Android exit. `project-analyzer` records it instead of `Driver: UNAVAILABLE` when `adb` or `simctl` exists.
- `agent-browser-e2e` → Driving pitfalls: headless file pickers opened by `input.click()` (neutralise the click, then `upload`), and responsive pages with duplicated markup (click by snapshot ref). `reference/e2e-testing.md` gains the Playwright `filechooser` pattern and a precondition for file-based databases (copy the data directory, point the app at the copy).
- Profile template §6 E2E Fixtures: a "Fixture files" row; a missing file makes its scenario `blocked`.

### Changed
- `agent-browser-e2e`: the agent may start the project's app servers on a free port with isolated data; tunnels, redis, VPNs, and shared or cloud databases stay the human's, matching CLAUDE.md.
- `project-analyzer`: the unit-test expectation is "the current major" rather than Vitest 4.x; a hand edit of the profile must move `Profile-Generated-At` or run `/team-init --update`.
- `pre-compact.sh` prints the absolute session-state path, and the `checkpoint` skill says to write there by absolute path; a relative path from a subfolder had created a stray nested `.claude/session-state/`.

### Fixed
- **`/team-init` and `submodule-worktree` no longer open gitignored files.** The carry-list step listed gitignored files, and an agent read `secrets.json` to learn its purpose, putting a token into the model context and a transcript. Both now record paths and purpose only and copy without reading.
- `agentic-testing` / `agent-browser-e2e`: a run with the server up whose login sent no auth request is `failed` with that evidence, not `blocked`.

## v1.34.1 — 2026-09-28

Security fixes for v1.34.0, from a review of that release and a live check. The Codex adapter moves to 1.34.1 with no change.

### Fixed
- **A cloned repository could switch the stop gate on.** The stop gate was a command hook reading `CLAUDE_PLUGIN_OPTION_*` from its environment. When the user had left the options unset, a project's `.claude/settings.json` `env` could supply the key and the switch; a live run with no user settings made a Jev call this way. The `Stop` hook is now `type: "mcp_tool"` and calls the new MCP tool `stop_gate` on the plugin's `jev` server, whose `env` Claude Code fills from user settings and the credential store only. The same live check now makes no call, and a run with user settings still does. `qa_crosscheck` already ran there and was unaffected.
- **A Jev key could add curl directives.** The key is written into a curl config line, so a quote or newline in it could add another `url`. A key with any character outside `A-Z a-z 0-9 . _ ~ + / = -` now skips the check.
- **The model could make `stop_gate` read any file.** MCP tools are model-callable, and `stop_gate` reads the transcript path it is given and sends that turn's tool output to TypeSafe. It now accepts only this project's Claude Code transcript for the given session (`<config>/projects/<project dir, non-alphanumerics as "-">/<session_id>.jsonl` after resolving symlinks) and returns nothing for any other path. A live run's real transcript passes the check.
- Tests: `hooks/jev/tests/run.sh` 34 cases (adds the key-format case); `mcp/tests/test_jev_server.py` adds `stop_gate` (hook output, session id in the log, `stop_hook_active`, unset switch, and refusal of an outside file, another project's transcript, a mismatched session id, and a symlink in the transcript folder).

## v1.34.0 — 2026-09-28

The Jev checks move to the plugin's own settings. Enter the TypeSafe key once in **`/plugin` → junjak-ai-harness → Configure**; it is kept in the OS credential store. The QA cross-check becomes an MCP tool, because the Bash tool never receives plugin settings. The Codex adapter moves to 1.34.0 with no change; it runs neither Claude `Stop` hooks nor plugin MCP servers.

### Added
- `userConfig` in the plugin manifest: `jev_api_key` (sensitive), `jev_qa_crosscheck` (default on), `jev_stop_gate` (default off). Claude Code reads these only from user or managed settings, so a cloned repository cannot switch a check on or supply a key. A live run confirmed that a project's `settings.json` `env` setting `CLAUDE_PLUGIN_OPTION_JEV_API_KEY` does not replace the key the hook receives.
- MCP server `jev` (`mcp/jev_server.py`, Python 3 standard library) with the tool `qa_crosscheck` (`scenario`, `observation`, `verdict`). It runs `hooks/jev/qa-crosscheck.sh` with the settings from its MCP `env`, so the check logic stays in one script and the key never enters the agent's context. `python3 mcp/tests/test_jev_server.py` covers the stdio protocol, key hand-off, and unset or placeholder settings.

### Changed
- `agentic-testing` calls the MCP tool instead of running a script through Bash; the report's Jev column says `not available` when the tool is not listed, or the skip reason.
- `jev.json` only opts a project out (`"disabled": true`) and tunes `model`, `stopGate.threshold`, and `timeoutSeconds`. It no longer switches anything on.
- Skip reasons name their cause (switch off, no key, project opted out, jq or curl missing) instead of always pointing at `jev.json`.
- `jev.log` moves to `~/.claude/plugins/data/<plugin id>/jev.log`, outside every project, so it no longer appears as an untracked file; each line adds the project path, and cross-check lines add `confidence`.
- Jev's `blocked` criterion names a missing test fixture file, so a missing upload fixture reads as blocked rather than insufficient evidence.
- `agent-browser-e2e`: with the server up, the steps run, and no auth request sent, the verdict is `failed` with that evidence, not `blocked`.

### Removed
- `~/.config/typesafe/api-key` and `~/.config/typesafe/allowed-projects`. Delete them after entering the key in the plugin settings; nothing reads them any more.
- `stopGate.enabled` and `qaCrossCheck.enabled` in `jev.json`.

## v1.33.1 — 2026-09-28

Security fixes for the v1.33.0 Jev checks, from a review of that release, plus fixes from the first live use of `qaCrossCheck`: 9 calls, 7 agree and 2 contested, where both disagreements were cases the tester's verdict was the weaker one. The Codex adapter moves to 1.33.1 with no change.

### Fixed
- **A cloned repository could switch sending on by itself.** A committed `jev.json` was enough to send that project's transcript to TypeSafe. Both checks now also require the project's primary working tree to be listed in the user's `~/.config/typesafe/allowed-projects`; without that entry they skip without a request.
- **Secrets in tool output were sent as is.** Every string in the request is now masked for common secret shapes (private key blocks, `sk-`/`ghp_`/`gho_`/`github_pat_`/`AKIA`/`xox*-` tokens, JWTs, Bearer/Basic values, URL credentials, values after password/secret/token/api_key-style names). Masking is best effort; README says so.
- **`jev.log` stored reply and scenario text.** It now keeps only model id, scores, labels, and decisions with the session id and time.
- **`qaCrossCheck` skipped silently when the agent's cwd was a subfolder.** Hooks get `CLAUDE_PROJECT_DIR`, the Bash tool does not, so the script looked for `jev.json` under the cwd. It now falls back to the enclosing superproject, then the git top level, then the cwd. Found in a live `/team-qa`-style run on a web project.
- **Jev's `blocked` criterion now names a missing test driver or tool**, matching `agentic-testing` ("Driver unavailable is `blocked`"). A driver that is present but gets a different result stays `failed`. On 13 probe cases (11 earlier ones, one missing driver, one present driver whose login request never left) every label matched.
- **`agent-browser-e2e`: `auth login`'s `✓ Logged in` is not evidence.** A login counts only when an element that exists only after login is present; the URL check applies only when the login page has its own URL, because an app that serves the gate and the content at one URL passed the old URL check without logging in. With no post-login element, check whether any auth request left (a pre-hydration submit can fall back to a native form POST and send none) and record that evidence instead of retrying or reporting the session as logged in.
- `hooks/jev/tests/run.sh` grows to 31 cases (allowlist missing or not matching, including a prefix-sibling path; masking; content-free log; project lookup from a subfolder without `CLAUDE_PROJECT_DIR`).

## v1.33.0 — 2026-09-28

Opt-in checks backed by TypeSafe Jev, a model that answers typed questions with probabilities. Both are advisory, fail open, and do nothing until a project adds `.claude/project-profile/jev.json` (README → "Jev checks"). The Codex adapter moves to 1.33.0 with no change; it does not run Claude `Stop` hooks.

### Added
- **`stopGate` (Stop hook, `hooks/jev/stop-gate.sh`).** After a reply that uses completion words (완료, 통과, fixed, verified, passing…), Jev scores whether the reply states verified or working results and whether this turn's tool output contains a check for them. Score = P(claims verified) × (1 − P(evidence supports)); at 0.6 or above Claude gets one `additionalContext` note per turn asking it to run the check, restate the claim as unverified, or name earlier evidence. On 9 probe cases with `jev-1.13.0` the cases that should get a note scored 0.63–0.90 and the rest 0.09–0.42; a single combined question had put an honest "unverified" reply (0.83) next to a false "E2E verified" claim (0.89), so the check asks two questions.
- **`qaCrossCheck` (`hooks/jev/qa-crosscheck.sh`).** `agentic-testing` sends each scenario's raw evidence for a `passed` / `failed` / `blocked` / `insufficient_evidence` label and reports `agree`, `contested`, or `uncertain` beside its own verdict. The tester's verdict never changes; `/team-qa` writes a contested or uncertain result into the scenario's Evidence and lists contested IDs. `team-agentic-tester`'s report gains a Jev column.
- The key is read only from `~/.config/typesafe/api-key`, requests go only to `https://api.typesafe.ai/v1/systemone` over HTTPS, and the key reaches `curl` through a file descriptor rather than argv. A committed `jev.json` or a project's `settings.json` environment cannot choose the key, its file, or the endpoint, so a cloned repo cannot read another file as the key, send the key and transcript elsewhere, or route your transcript into its own Jev account. Numeric settings (`threshold`, `timeoutSeconds`) fall back to defaults when they are not plain numbers.
- Every Jev call is logged to `.claude/session-state/jev.log` (model id, scores, decision) for threshold tuning and model pinning.
- `hooks/jev/tests/run.sh`: 25 table-driven cases against a fake endpoint (no config, disabled, `stop_hook_active`, no completion words, thresholds, pinned model, network or malformed-response fail-open, key only from the user file with env, `keyFile`, and `endpoint` overrides ignored, key kept off argv, current-turn evidence only, test output kept ahead of long non-check output). It also runs under macOS `/bin/bash` 3.2.

## v1.32.0 — 2026-09-24

The harness no longer depends on the `superpowers` plugin, which was uninstalled on this machine and left `/debug` aborting. The Claude plugin and the Codex adapter ship together at 1.32.0.

### Added
- The guardrails Claude entry point records rare slow checks: a check that takes 3 s or longer is appended to `.claude/session-state/guardrails-slow.log` (elapsed time, exit code, `index.lock`, load average, session, cwd, command), and a check the hook timeout kills leaves an in-flight marker that the next check logs as `unfinished`. A timed-out hook lets its command run, so these lines are the only trace; they exist to find the cause before fixing it. Fast checks pay about 35 ms extra, and only for git/gh commands in a project with `guardrails.json`.

### Changed
- `/debug` carries the whole root-cause-first method itself — frame and reproduce, investigate, one stated hypothesis at a time, failing test first, verify by running — plus a red-flags list for guessing, and no longer calls `superpowers:systematic-debugging` or aborts when it is missing. The `debug` skill states the Iron Law and its reproduce step in its own words. The Codex `$harness-debug` skill is self-contained the same way.
- `CLAUDE.md` names `impeccable` as the only delegated plugin; parallel-agent decisions point to the `parallelization` skill and code review to Claude Code's built-in `/code-review`. README dependencies, the brain-connect settings template, and the recommended settings no longer enable `superpowers`.

### Removed
- The `superpowers` hard dependency (debugging methodology, code-review dispatch, parallel-agent dispatch).

## v1.31.2 — 2026-09-23

### Fixed
- **UI/UX agents no longer stall on a personal-skill `impeccable` install.** `team-uiux-master`, `web-architect`, and `web-reviewer` called `impeccable:impeccable` and were told to ABORT when that name was missing, so a bare `impeccable` install (a personal skill) either stopped the run or cost a failed call first — observed in a live `/team-run`. Each agent now reads its available-skills list once, uses `impeccable:impeccable` if listed and `impeccable` otherwise, and aborts only when neither is present. `CLAUDE.md` and the README dependency row say the same. The Codex adapter is unchanged; its version moves with the release number.

## v1.31.1 — 2026-09-23

### Fixed
- Codex `forbiddenCommands` now blocks a forbidden command after launch wrappers such as `timeout`, `nice`, and `stdbuf`, inside backticks, or when the program name comes from a variable or command substitution. It also fails closed when an unrecognized program contains a visible forbidden command. Quoted literal text remains allowed. The Codex regression suite covers these cases; Claude's shared branch evaluator is unchanged.

## v1.31.0 — 2026-09-23

The Claude plugin and the Codex adapter ship together at 1.31.0: Codex gains the v1.30.0 workflow and guardrails, and both share one branch evaluator.

### Added
- Opt-in Codex `PreToolUse(Bash)` guardrail hook. It shares the Claude branch evaluator, denies protected writes, converts every branch `ask` to `deny`, and checks `forbiddenCommands` prefixes in the project guardrails config. Codex-packaged copies of the three presets and focused adapter tests are included.

### Changed
- `$harness-team` uses a single Phase 4 `VERIFY_PASS` / `VERIFY_FAIL` / `VERIFY_BLOCKED` pass, then records up to five Deferred QA cases and a scoped document sweep after a pass. It promotes project-valid learnings and uses Mermaid for branching flows, state changes, and interactions. Optional subagent routing chooses a smaller model only for simple deterministic work and otherwise the strongest available model, without a version pin.
- The Claude guardrail entry point now calls the same branch evaluator packaged inside `codex/`; its policy and output are unchanged apart from the fix below, as checked by the Claude suite (now 43 cases). Codex reads the current Claude session-state layout for handoffs without writing Claude run files.

### Fixed
- **Guardrail bypass through launch wrappers (security).** The evaluator only recognised `git`/`gh` as the first word after `command`/`exec`/`nohup`/`time`/`sudo`/`env`, so `timeout 60 git push origin main`, `nice git commit`, `stdbuf -oL git push`, `ssh host git push`, or `G=git; $G push` were allowed on protected branches. Known wrappers (`timeout`, `nice`, `ionice`, `stdbuf`, `setsid`, `doas`, `chronic`, `caffeinate`, plus the old set) are now followed to the git/gh they launch and judged normally; a program name from a variable, or a git/gh write inside a program the hook does not follow, gets the strictest rule. Quoted text stays literal. Applies to both Claude and Codex hooks.

## v1.30.0 — 2026-09-23

Folds in the unpublished v1.29.0 work (lightweight team verification + batched `/team-qa`). The Codex adapter stays at v1.28.0; this release changes the Claude workflow only.

### Added
- `/team-qa` collects pending scenarios from completed team plans and runs a bounded batch later. Its default is verification only; `--crystallize` opts into deterministic test generation.
- Completed plan archives hold up to five deferred QA scenarios with independent pending/passed/failed/blocked verdicts and evidence.
- Opt-in branch guardrails: a `PreToolUse(Bash)` hook reads `.claude/project-profile/guardrails.json` and denies or asks for `git commit`-class writes, `git push` destinations, and `gh pr merge` base branches that match protected patterns, per repository (submodules and linked worktrees included). Unresolvable forms get the strictest rule; `ask` becomes `deny` under `bypassPermissions`/`dontAsk`. Presets: `default` (production deny, stage/dev ask), `light`, `toy`. No config file means no change.
- Harness projects without a guardrails config get a one-line preset suggestion at session start; any config file, including `toy`, silences it.
- `hooks/guardrails/tests/run.sh`: table-driven hook tests (bash 3.2 compatible).

### Changed
- `/team` and `/team-run` use one lightweight merged-tree pass for affected unit/integration tests, relevant build/type/lint gates, and a limited existing smoke E2E. Failure or a required blocked check ends the run with evidence; no automatic QA-to-implementation loop or Phase 4.5 agentic pass.
- Phase 5 reconciles the completed implementation record with final code, quick-verification and security evidence, document index, and affected wiki links. Pending QA remains visible without preventing implementation completion.
- Completion reports state the Phase 4 verdict and any pre-existing failures instead of a fixed `0 fail`; a Phase 4 `VERIFY_FAIL`/`VERIFY_BLOCKED` emits `WORKFLOW ABORTED` with the verdict, the active plan path, and a next step. `/team-qa` ends with a fixed `TEAM QA COMPLETE` report. `/team` now states the same "up to five, or a `No scenarios` reason" QA count as the workflow skill. The Leader's team-sizing rules plan exactly one Phase 4 Tester instead of the old 1–3 Tester formula.
- `docs-lifecycle` gains a **Diagrams in docs** rule: intents, specs, plans, handoffs, and findings draw branching flows (`flowchart`), state changes (`stateDiagram-v2`), and component interactions (`sequenceDiagram`) as inline Mermaid; linear steps stay a list. `brainstorm` and `/team-brainstorm` follow it instead of forbidding diagrams; `/plan-visualizer` stays the on-request HTML view.
- A live intent's `status` is defined as `reference` (`deprecated` once rejected or superseded).
- `docs-lifecycle` states its two state machines as diagrams: document status transitions (replacing the trigger/action table and the one-line lifecycle summary) and Deferred QA verdicts (`pending → passed | failed | blocked`, named recheck from any verdict). Only what a diagram cannot carry — folder paths, the merge rule, append-only evidence — stays in text; `/team-qa` points to the QA diagram.
- **Two-tier model routing.** The Leader records `sonnet` or `opus` for every dispatch in Team Composition, and the orchestrator passes it as `model` (`opts.model` under ultracode). `sonnet` requires all of: read-only or ≤2 files in one domain; no auth/payment/secrets/PII or contract change; deterministic plan/checklist work. Everything else — including any doubt about a condition — is `opus`, and a failed `sonnet` dispatch is re-sent on `opus`. `team-leader` now uses `model: inherit` (your session model); every other agent defaults to `opus` (Designer, Tester, UI/UX Master, Web Reviewer were `sonnet`). Haiku is no longer routed. Effort is never set per agent; all inherit the session effort, and the unenforceable per-agent "Effort level" notes are removed. `token-optimization` §1–§2 and the ultracode note in `CLAUDE.md` describe the rule without model versions.
- **Per-session state (breaking layout change).** `.claude/session-state/` is now `sessions/<session_id>/{current.md, checkpoints/}` plus `runs/<plan-id>.json` and shared `learnings/`, keyed by `$CLAUDE_CODE_SESSION_ID` (kept across `--resume`/`--continue`, new after `/clear`). Concurrent sessions in one tree no longer overwrite each other's state, and parallel team runs on different plans use different run files. A run file carries `owner_session`; a non-owner session stops and asks before writing, and ownership changes only when the user takes the run over. The old root `current.md`, `last-session.md`, `archive/`, `checkpoints/`, and `team-run.json` are no longer read — finish any in-flight `/team-run` before updating.
- **Team runs sweep the documents they touched.** The orchestrator records `baseRef` (`HEAD` before Phase 1) in the run file, and Phase 5 runs `/docs-sweep --since <baseRef>` — reap + all six invariants — instead of `--lint-only`. The new `--since <ref>` scope limits reap decisions and auto-fixes to `_docs` files changed since `<ref>`; findings about other documents are reported, never fixed, so a run cannot reorganize another session's docs. Phase 4 uses the same `baseRef` as its pre-task base.
- **Project-valid learnings leave session-state.** `.claude/session-state/learnings/` is temporary, so team Phase 5 (and milestone close outside a team run) moves learnings touched in that run: project knowledge with evidence → `_docs/reference/<topic>/<date>-<topic>-findings.md` (or a dated section in the topic's existing reference doc), operational facts every agent needs → project-profile, agent-only know-how stays. The learning file is deleted after the move so the fact lives in one place; wiki pages link to the destination. Run files gain `startedAt` to scope this.

### Fixed
- The `Stop` hook ran after **every reply** and moved `current.md` to `last-session.md` each time, so the live state disappeared between turns. State is now snapshotted once by a new `SessionEnd` hook (which also prunes session folders untouched for 14 days); `Stop` keeps only the stray-artifact warning. `PreCompact` snapshots the session's own folder and names the team runs it owns.
- The consumer project's `.gitignore` now always carries `.claude/session-state/`: `/team-init` adds it, and a team run or `/checkpoint` save appends it before its first write when an older profile left it out.

### Removed
- Phase 4.5 automatic agentic QA and the QA→implementation loop inside `/team` and `/team-run` (deferred scenarios now run later through `/team-qa`).
- The Haiku tier from harness model routing, and the per-agent "Effort level" notes an agent could not act on.
- The old `.claude/session-state/` root files (`current.md`, `last-session.md`, `archive/`, `checkpoints/`, `team-run.json`) — no longer read or written.

## v1.28.0 — 2026-09-23

### Added
- Codex repository entry points: `AGENTS.md` and three self-contained `.agents/skills/` workflows for project analysis, team implementation, and debugging.
- A `codex/` plugin package and repo marketplace entry for distributing those skills, with a separate, informational Codex `SessionStart` hook.

### Changed
- Documented Codex installation, invocation, supported scope, and parity limits. Claude commands, agent definitions, skill bodies, and hooks retain their existing behavior.

## v1.27.0 — 2026-09-11

`_note/` existed so the human had a bucket the agent could not touch. In practice the pattern went the other way: the raw material arrives (a transcript, a dump, a half-formed idea) and the agent is the one who turns it into something readable. A read-only bucket blocked exactly the work it was meant to hold, so it is gone — one place for documents now, with the protection moved from *who owns the folder* to *what the folder is for*.

That split is the real change. `_docs/` top level now carries **lifecycle** buckets, which the agent moves and merges, and **collection** buckets, which it may append to but never reorganize. `intent/` — the request record, head of the `intent → spec → plan → impl` chain — is the first collection, and the one artifact that survives its idea being rejected.

### Added
- **`_docs/intent/`** — durable request records, `YYYY-MM-DD-<topic>-intent.md`. Written from a `brainstorm` / `/team-brainstorm` result: the settled *what/why/constraints* goes to the intent, the *how* to the paired spec in `active/planning/`. Most intents never become specs, and a rejected one still records the decision — it moves to `intent/deprecated/` **in place**, never to the global `deprecated/`.
- **Collection buckets, as a declared contract.** A project adds `meetings/`, `inquiry/`, `proposal/` — whatever it needs — by declaring it in its project profile's new **Document buckets** table, never by inventing a folder mid-task. The declaration's `Curated` column is the only thing that authorizes an agent to rewrite anything in there; the default is `no — append only`. A folder on disk but absent from `index.md` §④ is an I3 defect.
- **`index.md` §④** — the SSOT list of declared collection buckets, alongside the existing status list, handoffs, and topic vocabulary.
- **`REVIEW.md`** — repo-root review policy: four passes (consistency, literalness, release discipline, contradiction), what counts as Important in a rules repo, a nit cap, and an exclusion list. Historical `_docs/complete/**` records are explicitly out of scope.
- **`_workspace/README.md`** — the only tracked file in that bucket, and the per-project layout SSOT. Read it before the first write of a session; add a row when introducing a new context folder. It is also how the `_workspace/` convention reaches consumer projects at all, since plugins cannot inject a `CLAUDE.md`.

### Changed
- **Document storage: 4 buckets → 3.** `_docs/` (project) · `.claude/wiki/` (agent) · `_workspace/` (throwaway). The discriminator is unchanged; the human/project split inside the repo root is gone.
- **`kind: brief` → `kind: intent`.** `/team-new` G0 now writes `_docs/intent/<date>-project-bootstrap-intent.md` instead of a `planning/` brief, and G4 merges **research + stack-decision only** — the intent is linked from the archive, never merged into it. G3 rejection sends the intent to `intent/deprecated/` and the rest to `deprecated/`.
- **The reference-safe move transaction lost its `_note/` warning step** (steps renumbered 7 → 6) and now names collection buckets explicitly in the cross-bucket rewrite. Rewriting a link inside a collection doc is the one edit allowed there without asking.
- **`/docs-sweep` REAP is lifecycle-only.** Collection buckets are never reaped; I3 additionally flags undeclared collections, and I6 replaces its `_note/` clause with "no collection doc reorganized or removed outside its bucket".
- **The post-edit hook warns on `_docs/intent/` writes** instead of `_note/` writes — creating a record is fine, reshaping one is not.
- **`/team-init` bootstraps `_workspace/README.md`** (was `_note/README.md`) and records the Document buckets table in the profile.
- **`wiki` sources** are now `_docs/` (lifecycle docs on completion, collections append-only), `learnings/`, and external docs.

### Fixed
- **`.gitignore` could never have tracked `_workspace/README.md`.** The bare directory form `_workspace/` makes git skip the tree entirely, so a `!_workspace/README.md` negation is unreachable — verified empirically, not assumed. The pattern is now `_workspace/*` + the negation, and the trap is documented inline and in the project-profile template.
- **No hard-coded model version in an active file.** `reference/token-optimization.md` said "Sonnet 5" where it meant the Sonnet tier, against CLAUDE.md's own rule.
- **The collection-bucket hook guard covers every collection, not just `intent/`.** It matches by **inversion** — `active|complete|reference|deprecated` are the lifecycle buckets, so any other top-level folder under `_docs/` is a collection. An allowlist would have silently missed every project-declared bucket (`meetings/`, `inquiry/`, …), which is exactly the case the declaration mechanism exists to support.
- **`post-edit-warn.sh` no longer interprets backslash escapes in its own output.** It emitted warnings via `echo -e "$WARNINGS"`, and `$WARNINGS` embeds `$MATCHES` — grep'd lines **from the edited file**. A source line containing a literal `\n[warn] …` was expanded into extra agent-visible lines, letting file content forge hook output. Warnings are now assembled with real newlines and emitted with `printf '%s'`; verified by a source file whose content tries to forge a warning line (pre-fix: 1 forged line, post-fix: 0).

### Removed
- **`_note/` entirely** — bucket, governance section, `/team-init` scaffold, hook warning, I6 clause, and all references across `CLAUDE.md`, `.claude/rules/docs.md`, `docs-lifecycle`, `project-analyzer`, `wiki`, `team-init`, `docs-sweep`, `e2e-testing`, and `README.md`. Existing `_note/` directories in consumer projects are left on disk and simply stop being governed; a project that still wants one can declare it as a collection bucket.

## v1.26.0 — 2026-08-08

Playwright runs kept dumping screenshots into the project root. The rule against that already existed — `_test/` §Artifact Layout in `reference/e2e-testing.md` — but it lived only in a lazily-loaded reference, so nothing guaranteed an agent read it before calling `page.screenshot()`. Renaming the folder alone would have reproduced the same failure under a new name, so this release adds the enforcement the old rule never had: the bucket is named in the always-on router, and the session-stop hook reports what still leaks.

### Added
- **`_workspace/` — one gitignored bucket for every throwaway output**, grouped by **context**: one folder per purpose, named for that purpose. E2E owns `_workspace/e2e/<YYYY-MM-DD>-<test-name>/{screenshots,artifacts,report}`. A bare file at the repo root — or at `_workspace/` root — is now a named defect rather than an unstated preference.
- **Stray-artifact scan in `session-stop.sh`.** At session end it scans the repo root (depth 1) for untracked `*.png|jpg|jpeg|gif|webm|mp4|zip` plus `test-results/`, `playwright-report/`, `blob-report/`, and lists what it finds. **Warn only** — tracked root files (a logo, a README image) are never flagged, and the hook never moves or deletes, because it cannot tell a deliberate root file from a leaked one. Silent on a clean root, and a no-op outside a git repo.
- **CLAUDE.md routing row + a fourth bucket-table entry** for `_workspace/`, so the layout loads every session instead of only when someone happens to open `e2e-testing`.

### Changed
- **`_test/` → `_workspace/e2e/` everywhere** — `reference/e2e-testing.md` §Artifact Layout and its `playwright.config.ts` example (`outputDir`, both reporters), `skills/agent-browser-e2e/SKILL.md`, `skills/agentic-testing/SKILL.md`, and this repo's `.gitignore`. No `_test/` reference remains.
- **Capture calls must pass an explicit path.** The layout rules now say why: a relative filename resolves to the repo root, which is the exact scatter the bucket exists to prevent.

### Fixed
- **Auth state no longer deviates from Playwright's published convention.** The harness told agents to keep session tokens in `_test/.auth/`; Playwright's own docs specify `playwright/.auth/` with `playwright/.auth` in `.gitignore` ([auth.md](https://playwright.dev/docs/auth)). `agent-browser-e2e` and the artifact layout now use the vendor path, and the rule generalizes: a tool's published state path wins over `_workspace/`, which is for byproducts only.

## v1.25.1 — 2026-08-03

The dependency list named three tools; the harness actually reaches for six. The undocumented one that mattered was `jq` — without it the post-edit hook failed on every single Edit/Write and said nothing.

### Fixed
- **The `PostToolUse` hook no longer depends on `jq` being present to fail safely.** `hooks.json` previously ran `jq -r '.tool_input.file_path' | xargs … post-edit-warn.sh`; with no `jq` on PATH the pipeline produced nothing and the hook's `console.*` / `debugger` / `_note/`-write checks were disabled silently, forever. The hook command now calls the script directly, and the script reads its path from stdin JSON behind a `command -v jq` guard — no output when `jq` is missing (a warning per keystroke-level edit would be spam), and the argument form still works. `session-start.sh` prints the one visible `jq not found` line per session, so the degradation is announced exactly once instead of never.

### Changed
- **`README` → Dependencies is split into Hard and Soft, and lists all six tools.** Hard (a step aborts): `impeccable`, `superpowers`. Soft (named fallback or reduced feature): `agent-browser`, **Playwright**, **`jq`**, **`gh` CLI** — the last three were load-bearing but undocumented. Each row states the actual degradation; the Playwright row records that with neither it nor `agent-browser` present, Phase 4 reports E2E as `미검증` rather than inferring green.

## v1.25.0 — 2026-08-02

One less hard dependency, and a pass over the harness's own bulk. A structural audit — inbound references and actual invocation paths, not usage counters — found two components that nothing routes to and two that fire without being asked. Skills 21 → 19, reference docs 6 → 5, commands 13 → 14.

### Removed
- **The `ponytail` plugin dependency, entirely.** `team-tester` Step 6 ("Over-Engineering Audit"), which ran `/ponytail-review` on the diff and ABORTed when the plugin was missing, is gone; so are the delegated-plugin entry in `CLAUDE.md`, the README dependency row and its install line, and the pointer in `coding-standards` §4. Hard dependencies now number two: `impeccable` and `superpowers`.
- **The Team Leader's Phase 4 minimalism checkpoint.** Its only input was the ponytail result. Phase 4 no longer re-opens Phase 3 over solution complexity — only a failing test, type, or security gate does.
- **The `security-review` skill.** Nothing invoked it. Phase 5 spawns `Agent(team-architect-infra)`, and that agent carries the Security Checklist, Infrastructure Checklist, and audit output format in its own definition — so the skill was a second, silently diverging copy of the OWASP list. `.claude/rules/security.md` claimed the skill ran the audit; it now names the agent that actually does. The Phase 5 audit itself is unchanged and still mandatory.
- **The `scenario-to-e2e` skill.** Zero entry points: no command, no agent, no other skill referenced it — reachable only if its own description happened to auto-fire.
- **`reference/tdd-workflow.md`.** The agent that performs TDD (`team-designer`) never cited it; it carries its own RED→GREEN→REFACTOR cycle inline. The doc's only live citation was `/debug`.

### Changed
- **Minimalism is a design-time gate with one decision point.** The YAGNI ladder still lives in `coding-standards` §4 and in every architect agent's own definition (`team-architect-be` / `-fe` / `-infra`, `web-architect`); `plan-review` surfaces violations as "Over-Engineering / YAGNI" findings; the Team Leader decides at the **Phase 1 approval gate**, before anything is built. `team-tester` is now explicitly told not to substitute its own diff-level minimalism heuristic in place of the removed step.
- **Plan diagrams are opt-in, via the new `/plan-visualizer` command.** `/team` and `/team-run` previously generated an HTML diagram unconditionally after Phase 1, and `/team-brainstorm` had a whole Visualization step — a render nobody asked for, in the hot path. Those steps are gone; the `plan-visualizer` skill now fires only from the command (no argument → newest plan in `_docs/active/planning/`; path argument → that plan).
- **`submodule-worktree` triggers on the project profile, not on `.gitmodules`.** It now requires `.claude/project-profile/structure.md` → **Submodule Layout** with `Submodule-monorepo: yes`, and STOPs with "run `/team-init` first" otherwise, falling back to plain `parallelization`. A bare `.gitmodules` says submodules exist but not which hold code, which are worktree targets, or which gitignored runtime files a clean checkout would lack — guessing those is how a worktree comes up missing its `.env`.

## v1.24.0 — 2026-07-30

App UI work had no stated verification surface, so "looks right in the code" could pass as done — and nothing recorded that half of it is impossible to check on a Windows host.

### Added
- **Mobile verification runs on a booted simulator/emulator, with an explicit host-OS gate.** App UI changes are verified on a real device surface, never by inspection: boot/select the device explicitly through the project's version pin (`flutter devices` → `fvm flutter run -d <id>` where `.fvmrc` exists), and name the device in the report.
  - **macOS** — iOS Simulator (Xcode) **and** Android Emulator.
  - **Windows / Linux** — Android Emulator only; the iOS Simulator requires Xcode, which is macOS-only.
  - On Windows an iOS result is therefore **structurally unverifiable**: report it as `미검증 (iOS: host cannot run the simulator)` and leave it for the macOS machine. MUST NOT infer iOS behavior from a green Android run — permissions, safe-area/notch insets, keyboard behavior, deep links, sign-in providers, file pickers, and push are exactly where that inference breaks.
  - No device bootable → `driver unavailable` and stop; falling back to static reasoning and calling it verified is the failure this gate prevents.
  - Wired into the surfaces that ship: `agentic-testing` (Phase 4.5 mobile adapter row + a dedicated section), `team-tester` (Phase 4), and `/debug` Phase 4.
- **`testing.md` gained device rows** — iOS simulator / Android AVD targets, the launch command and its version pin, and the host-OS gate — so each app project records its own device targets at `/team-init` time.

## v1.23.0 — 2026-07-30

A `/doctor` audit of 345 session transcripts found three things this harness asserted that the data does not support: `TeamCreate` was **never called once** while `team-workflow` ran 25 times; six "skills" were cited 60 times without a single dispatch; and `agent-browser` was used only when explicitly named while every other browser task drifted to Playwright MCP or `claude-in-chrome`. All three were caused by this repo's own text, and all three are now aligned with what actually runs.

### Removed
- **The `TeamCreate` / `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` dependency, entirely.** `CLAUDE.md`'s "Required: Agent Teams" section, the README's "required" note and its env-block entry, and the flag line the greenfield scaffolder wrote into every new project's `settings.json` are gone. The flag was never set on the audited machine and the tool never fired, yet `/team-run` shipped 18 runs — the commands have always orchestrated through `Agent()`. Documenting a dependency that never existed made every one of those runs a silent fallback.
- **Six skills demoted to `reference/*.md` documents** — `coding-standards`, `tdd-workflow`, `e2e-testing`, `verification-loop`, `plan-review`, `token-optimization`. Skill count 27 → 21. Not one had ever been dispatched, and every reference was a §-citation ("(`coding-standards` §4)"), never an invocation — ~48,000 chars of body authored and never loaded. They now cost nothing in the always-resident skill listing while staying readable by path.

### Changed
- **Phase 1 cross-review is two parallel objection passes.** Each architect receives the counterpart plan and returns *only* contract mismatches, ordering conflicts, and broken assumptions — no rewrites. The Leader mediates and records any unconceded conflict with its reason. Under ultracode the two passes run as a second `parallel()` barrier before synthesis (the judge-panel pattern). Applies to `/team`, `/team-brainstorm`, and `greenfield-bootstrap` G2.
- **`agent-browser` is the default browser driver, and the precedence lives on a surface that ships.** `agent-browser-e2e` previously described itself as "on-demand, NOT wired into Phase 4/4.5", so an agent reading it correctly concluded "only when asked" — and the fallback row named only Playwright, leaving `claude-in-chrome` unranked anywhere, which is how browser work leaked into it. The rule now rides the skill's own **description** (resident in every project where the plugin is enabled) rather than the harness `CLAUDE.md`, which is never injected into consumer projects: this skill FIRST → Playwright MCP only when its gate fails, stating which condition → `claude-in-chrome` only for the user's own logged-in Chrome profile. It is phase-wired for Phase 4 driving and Phase 4.5 exploration. `agentic-testing`, `team-tester`, `team-agentic-tester`, `scenario-to-e2e`, and `reference/e2e-testing.md` follow the same order.
- **The driver/framework boundary is preserved and stated**: agent-browser drives; Playwright permanently owns the committed `.spec.ts` regression suite, so a flow that must regress forever still crystallizes to a Playwright spec regardless of what explored it.
- **`/debug` Phase 4 spells out its gate inline** instead of naming two skills nobody loaded: failing test watched to fail first, one root-cause fix at the shared caller, verification by running the authoritative commands, `됐다 / 됐는데 미검증 / 안 됨` reported distinctly, DB-level persistence checked where data is touched.
- **`unknown` is a last resort, not the remedy for `any`.** `.claude/rules/typescript.md` prescribed `unknown` + narrowing while the global ruleset banned `unknown` outright — opposite instructions loading together on every `.ts` read. Both now say: `any` prohibited; `unknown` only where the model is outside your control (third-party library types, external API shapes) with no concrete type, narrowed at the boundary.
- **CLAUDE.md Rule Routing gained a reference-document row** stating those six names resolve to `reference/<name>.md` and MUST NOT be passed to the Skill tool. The `Authoritative Documentation` section was compressed; net file size is unchanged from before this release.

### Added
- **Fixtures precondition for unattended E2E.** Before the first browser action of any run a human is not driving (Phase 4, Phase 4.5, `/team-run`, scheduled/looped): the dedicated E2E account and its test data MUST already exist, provisioned through the project's own **idempotent** seed path against a **verified-local** target. MUST NOT invent an account/email/password or commit credentials; prd/stg provisioning stays human-executed; shared local DBs get coordinated before seeding. An unresolved fixture STOPS the run with `E2E fixtures unresolved: [what]` instead of producing failures that are really missing data — and a green run with unverified fixtures reports as `됐는데 미검증`, not `됐다`. Enforced on shipping surfaces: the `agent-browser-e2e` description, `reference/e2e-testing.md` → "Preconditions", `agentic-testing`, and both tester agents.
- **`testing.md` → "E2E Fixtures" profile block** so the account, credential source, idempotent seed command, target env, shared-resource caution, and teardown are captured per project at `/team-init` time — literal passwords banned from the file, unknowns recorded as `[FILL: …]` so they read as a blocker rather than a default.

## v1.22.0 — 2026-07-30

`brain-connect` covered only persona + auto-memory, so anything else kept per-machine — a global `CLAUDE.md`, personal global skills — silently diverged: an edit on one machine simply never reached the other. The contract now spans the whole cross-machine surface.

### Added
- **Brain contract rows for `CLAUDE.md`, `skills/<name>/`, and `settings.recommended.json`** — 7 rows total (was 3), each still optional and skipped when the brain lacks it.
- **`settings.recommended.json` + `apply-settings.sh` / `apply-settings.ps1`** — an enumerated allowlist of machine-neutral keys, merged recursively into the local `settings.json` (manifest wins). Keys absent from the manifest are left untouched, which is what preserves machine-specific `hooks`. The `.sh` uses `jq`; the `.ps1` merges natively (no jq dependency).
- **`template/setup.sh` and `template/sync.sh`** — the macOS/Linux halves of the connector, which previously existed only as prose telling you to port the PowerShell yourself.
- **Asymmetry as a trigger condition** — "fixed on one machine, missing on the other" now routes to this skill, since that asymmetry means the artifact lives outside the brain.

### Changed
- **One link per skill, never the whole `skills/` dir.** `~/.claude/skills/` is shared ground: other tools install skills there as relative symlinks into their own store, so linking the directory hides them and moving it into the brain breaks their targets and auto-commits another tool's files. Same reasoning as the namespaced `commands/brain` link.
- **Persona import is relative** — `@persona.md` inside the brain's `CLAUDE.md`, plus a `persona.md` link beside the linked `CLAUDE.md`. No machine path survives in synced content, and the import resolves whichever base dir Claude Code uses for a symlinked memory file.
- **`relocate.ps1` reduced to one job.** Links re-point themselves via `setup.ps1`'s `Link-Brain`, so relocation is now only about the sync-hook commands in `settings.json` — the one place a stale absolute brain path can survive, since hook commands are never synced.
- **Directory vs file link is explicit.** Directories use junctions (no privilege); files (`CLAUDE.md`, `persona.md`) need symlinks, so Windows needs Developer Mode. Hardlinks are rejected outright: `git pull` replaces the file inode and would silently orphan one while it still looks valid.
- **Verify section demands evidence.** Adds the `grep -r` trap — once skills are symlinks, `-r` traverses **zero** files and reports 0 hits for any pattern, a false green; use `-R` and assert the traversed-file count is non-zero. A clean `git status --porcelain` proves the push happened, not that the content arrived; only diffing the file on the other machine does.

### Fixed
- **`enabledPlugins` without `extraKnownMarketplaces` is vacuous** — toggling a plugin for a marketplace the machine never registered does nothing. The manifest guidance now ships the pair.
- **`~/.claude.json` explicitly banned from any brain** — per-project state, MCP disable lists and `numStartups` are machine-specific startup bookkeeping that conflicts endlessly when shared.
- **Pre-push audit made a MUST** — `sync push` is `git add -A` + auto-commit + auto-push, so content is published unreviewed; credential-scan it and confirm the remote is private *before* moving anything in.

## v1.21.0 — 2026-07-30

Graph-format orchestration (LangGraph *technique*, not runtime): persisted run-state + one normative escalation transition table, replacing four divergent copies of the same rules/graph.

### Added
- **Phase transition table** (`escalation.md`) — the ~20-row normative SSOT (guard / classification / target phase / counter effect / abort threshold) covering every escalation edge across all 5 phases + Phase 4.5, plus explicit counter-semantics rules (`retries.pN` vs `globalCycle` increment/reset behavior).
- **`.claude/session-state/team-run.json` read/write contract** (`team-workflow/SKILL.md` → "State Tracking") — persists `runId`/`phase`/`retries`/`globalCycle`/`escalations[]`/`designerAssignments[]` to disk so retry/abort caps are enforceable across compaction and session boundaries, not just held in orchestrator context. Read on every phase entry, written on every transition; a foreign `runId` still in flight STOPs and surfaces instead of silently overwriting (parallel-session safety).
- `pre-compact.sh` reminds the post-compaction session to re-read `team-run.json` on **auto**-compaction (the hook's existing matcher scope; not triggered by a manual `/compact`) — no new persistence logic, the file already survives compaction via the filesystem.
- `checkpoint` skill documents `team-run.json`'s placement (beside `checkpoints/`), orchestrator-only + primary-tree-only scope, and exemption from `session-stop.sh` rotation.

### Changed
- `team-workflow/SKILL.md`'s mermaid restructured so its node set is provably identical to `escalation.md`'s transition table (`START/P1/P2/GATE/P3/P4/P4.5/P5/DONE/ABORT`) — adds the previously-missing Phase 4.5 node and moves guards onto edge labels instead of separate decision/escalation nodes, so the visual and rules graphs can no longer silently drift apart.
- `team-designer.md` / `team-tester.md` / `team-leader.md` escalation sections now point at `escalation.md` instead of keeping local classification lists that had already drifted (8 vs 6 vs 5 differently-scoped "Fundamental Issue" enumerations across the three files).
- Escalation report format split into an **agent-emitted block** (Classification, Attempts, reason, files, root cause, tried approaches) and an **orchestrator-filled block** (Global cycle, cross-phase retries) — an agent cannot know orchestrator-level state, so it no longer reports it.
- `README.md`'s phase-flow ASCII block trimmed to a one-line phase index + links to the visual SSOT (`SKILL.md` mermaid) and rules SSOT (`escalation.md` table); Escalation bullets collapse to the same link.

### Removed
- `escalation.md`'s ASCII "Escalation Paths" path-tree — superseded by the transition table.
- Local "Simple Fix" / "Fundamental Issue" classification example-lists from `team-designer.md` and `team-tester.md`.
- `Global cycle` from what a Designer/Tester agent can report (moved to orchestrator-filled, read from `team-run.json`).

## v1.20.0 — 2026-07-30

### Changed
- **Test scope default flips to scoped-by-changes** (`verification-loop`, `team-tester`, `team-workflow`): Phase 4 test gates (baseline + final gate) now default to `vitest run --changed` / `playwright test --only-changed` instead of the full suite — on a large repo, running everything on every verification pass was the dominant CPU cost. The full suite runs only when the user explicitly asks for it in the current request ("run the full suite", "전체 테스트"); team-workflow's orchestrator wires the pre-task base ref into the Tester prompt so the scoped diff is computable, and omits the full-run line by default so Tester falls back to scoped.

## v1.19.0 — 2026-07-23

### Added — Operational Discipline (from cross-machine usage insights)
- **Windows shell fallback** (`CLAUDE.md`): when `Bash` fails repeatedly from a broken Git-for-Windows bash, switch to the PowerShell tool instead of retrying the same shell; never probe for a CLI with a call that spawns its GUI (e.g. a non-headless `soffice`).
- **Server / background-process vacuity guard** (`verification-loop`): a "running" claim must re-verify the process/port is alive **at claim time** (`curl` / `lsof` / `ps`) — a start command's exit-0 or "listening on :PORT" output is not proof it stayed up.
- **Parallel-session commit safety** (`CLAUDE.md`): parallel sessions share the working tree — commit only what you changed and never revert another session's uncommitted work (no blanket `git add -A` / `reset --hard` / `clean`); committing another session's work is allowed only on explicit request.
- **Destruction scope** (`CLAUDE.md`): destructive ops act only on the exact target the user requested — never a whole datadir, system/shared DBs, or unrelated state when only specific data was asked.

## v1.18.0 — 2026-07-21

### Added
- **`/meta-prompt`** — compile a raw context dump into an optimized, self-contained prompt to inject into a fresh session, `/team-run` string, subagent, or another tool. Borrows `brainstorm`'s questioning discipline; output is a portable prompt, not a design doc.
- **`/worktree-deps`** — provision a fresh worktree's dependencies via the package manager's shared cache (no re-download, parallel-safe). Two families: **A** copy-based (`node_modules` → shared-store hard-link + same-filesystem check) and **B** reference-cache (Dart pub / Gradle / Go / Cargo → native resolve, nothing copied); pnpm/bun handled inline, other managers resolved via Context7; `node_modules` symlinking excluded. Verified on a real Flutter + Spring monorepo (`fvm flutter pub get` = 7s / +68K / 0 copied).

### Changed
- `parallelization`, `submodule-worktree`, and `project-analyzer` document the worktree deps fast-path; the profile records it per code submodule.

## v1.16.0 — 2026-07-21

### Removed
- Deleted superpowers-duplicated fork skills the harness delegates instead of forking: `dispatching-parallel-agents`, `requesting-code-review`, `subagent-orchestration`, `systematic-debugging`. Removed multilingual READMEs (`README.ja.md`, `README.ko.md`).

### Changed
- Relocated agent-only resources (uiux, web-reviewer) under `skills/team-workflow/resources/`.

---

_For versions before v1.16.0, see the git history (`git log`)._
