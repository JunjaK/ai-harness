---
name: browser-e2e
description: "The only browser driver (ego lite). Use it for any task that drives a real browser, named or not: E2E, QA, smoke, exploration, login-gated checks, live selectors, team verification, /team-qa. No ego-browser → show the install steps and stop; never switch to another browser tool. Committed .spec.ts suites stay Playwright."
---

# Browser E2E (ego lite)

Every task that drives a real browser comes here first: E2E, QA, smoke, exploration of a running app, login-gated checks, resolving live selectors, focused team verification, and `/team-qa` (through `agentic-testing`). The user does not need to name this skill. ego lite is a **driver**, not a test framework.

ego lite is the **only** driver. agent-browser, Aside, Playwright MCP, and `claude-in-chrome` are not used for testing; the plugin's PreToolUse hook denies `agent-browser`, `aside`, and Playwright MCP calls. Reason: one driver removes the drift of grabbing whichever browser tool is loaded, and a 54-run comparison on a real app (company harness, 2026-11-02~03, mac) had ego 27/27 with 0 hangs vs agent-browser 23/27 with 3 hangs (daemon timeouts), equal time once hangs are excluded, ego ~8% more cost.

## When to use / not use

- **Use** — any browser-driving task, requested or not.
- **Not a replacement for** — the committed Playwright `.spec.ts` regression suite and CI (`@playwright/test` through Bash, unaffected by the hook). A flow worth permanent coverage is crystallized to a spec only on explicit request (below). ego lite does not support Linux or CI.

## Gate — check once at skill entry, then trust the result

1. **CLI present** — `ego-browser --version` exits `0`.
2. **QA profile ready** — `node "<this skill's base directory>/scripts/qa-profile.mjs"` exits `0`. It picks a QA profile (name starts with `harness-qa`) that has no open task space, or creates `harness-qaN` when none is free (up to 10). Every other profile may hold a real account and is never selected.

| Outcome | Action |
|---|---|
| Both pass | Use ego lite |
| 1 fails | Stop with "ego lite required" and show the install steps below. Do not switch to another browser tool. Scenario verdict: `blocked` |
| 2 fails | Stop with "QA profile required", show the script's reason and install step 3. Never substitute a real-account profile. Verdict: `blocked` |

### Install (the human does this)

1. Download from https://lite.ego.app/ (macOS `.dmg`, Windows `.exe`).
2. Open the app and finish onboarding. **Skip "import browser data"** — importing would hand the agent your real logins. Onboarding registers the `ego-browser` command; open a new terminal.
3. QA profiles are created by `scripts/qa-profile.mjs` (needs `node`; ego has no create-profile command, so the script opens `--profile-directory=Profile N` and renames it in `chrome://settings/manageProfile`). If it fails, create a profile in the app and name it `harness-qa1`, `harness-qa2`, ….
4. Check: `ego-browser --version`, then the gate-2 command.

**Windows** (company harness, ego 0.6.2.5, Windows 11, 2026-11-03): the installer adds `%USERPROFILE%\.local\share\ego\active_version_dir` (a junction to the current version) to the user PATH — never put a version folder on PATH. A terminal or Claude Code started before the install keeps the old PATH (`ego-browser: command not found`, exit 127): restart it, or reload PATH in the current shell — PowerShell `$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')`, Git Bash `export PATH="$PATH:$(cygpath -u "$USERPROFILE")/.local/share/ego/active_version_dir"`. Profile creation by script is unconfirmed on Windows.

After the gate passes, read the usage guide **once**: `ego-browser skill` (until the line `[ego-browser:skill] end of guide`). It matches the installed version and is the **source of truth for every command**; do not copy its command list here.

## Before the first action — target, account, data

Read `reference/e2e-testing.md` → "Preconditions" and the project's `testing.md` → "E2E Fixtures". Settle these before the first navigation:

- **Target** — a verified local target. Never run automated writes against production or staging. A missing target URL → stop with "target URL required".
- **Account and data** — the project's dedicated E2E account and idempotent seed path. Never invent credentials or test data; a missing one makes the scenario `blocked`.

## Driving

- **Always name the profile.** Open a new task space with `node "<skill dir>/scripts/qa-profile.mjs" --space-name <task>` and use the printed space number (`--count N` for several accounts → `<task>-1`, …). In a script, create one with `await taskSpace("<task>", { profileId: "<QA profile id>" })`. Without `profileId`, ego opens the default profile, which may be a real account; the hook denies a named `taskSpace(...)` without `profileId`, but it cannot see a script passed as a file (`ego-browser nodejs < a.js`).
- Resume by number: `await taskSpace(12)`. Passing a name and `profileId` together fails on resume.
- One account per profile. Spaces on the same profile share cookies, so they are the same account.
- Core loop: navigate → `page.snapshot()` → act by ref or selector → wait for the expected state → snapshot again (refs go stale when the page changes).
- Scripts do not inherit the shell's working directory or environment: write absolute paths and literal inputs into the script.
- Captures take an absolute path: `_workspace/e2e/<YYYY-MM-DD>-<name>/screenshots/` (`reference/e2e-testing.md` → Artifact Layout).
- **Output may arrive on stderr** (0.6.2.5, measured): `ego-browser nodejs … | tee file` can produce an empty file. Write evidence files from inside the script and check they are non-empty.
- Finish with `await task.finish({ keep: [] })`; hand the browser to the human with `await task.handOff()`.

## Login

> **Invariant — the LLM never receives a password**: not in context, command arguments, or output.

The human logs in. The agent opens the login page in the QA profile, calls `await task.handOff()`, and stops with "log in to <app> on harness-qaN with the project's E2E account". The session stays in the profile, so later task spaces on that profile start logged in. An unattended run needs this login done beforehand; if the profile is logged out, the scenario is `blocked` (login required), not `failed`. The agent never types a password with `fill()`.

### Security

- QA profiles hold live sessions. Never log a real personal account into one.
- No whole-profile clears: `--clear-existing-profiles`, `Network.clearBrowserCookies`, `Network.clearBrowserCache`, `Storage.clearCookies` (the hook denies them). Clear one site with `Storage.clearDataForOrigin`; read the ego skill's `references/clearing-state.md` first.
- **App servers: the agent may start them; shared infra stays the human's.** Start the project's own dev or production server when the run needs it, on a free port (check it first) and against isolated local data (a separate schema, or a copied data directory with its path overridden by env). Stop it when the run ends. Tunnels, redis, VPNs, and cloud or shared databases are the human's to start (CLAUDE.md → Operational Discipline): surface a one-line "please start X" for those. A destructive step on shared local data (migration, seed, reset) is announced to the human first.

## Driving pitfalls (measured)

- **Console is hidden by default.** Call `await page.cdp("egoAutomated.disable")`, then `await page.cdp("Runtime.enable")`, and read `await page.events()`. Every run is a new Node process, so re-enable per run; console errors from an earlier run can be replayed.
- **Network events accumulate only while the process lives.** `Network.enable` persists across processes, but events from when no process ran are gone. Put the triggering action and the collection in one script.
- **Wait for autosave.** Reloading right after input can drop the value before the app saves it. Wait for the save indicator or the save response, then reload.
- **Selectors must match exactly one element.** Quote text for an exact match (`text="Save changes"`) or use a snapshot ref. Pages that render markup twice (one copy per breakpoint) are ambiguous by selector — click the visible copy by ref.
- **Shared across parallel tasks:** `keyboard.paste()` uses the system clipboard and download waits use the browser's single download setting. In parallel work use `keyboard.insertText()` and run one download at a time.
- **File choosers:** arm `page.waitForFileChooser()` before the click and upload with `chooser.setFiles()`. Fixture files come from `testing.md` → "E2E Fixtures"; a missing one makes the scenario `blocked`.
- **One key at a time.** Send a key, look at the result, then decide the next. Close dialogs with their on-screen button when possible.
- **Untitled pages leak the URL.** A page without `<title>` shows its URL in the snapshot's first line and in tab names. When the URL carries a token (invite, verify-email, reset links), read that page with `page.evaluate` only — no `snapshot()`, `screenshot()`, `tabs()`, `pages()`, `page.url()` — and navigate away before observing again.

## Verification (do not trust 200 / UI)

- Filling and submitting a form is not evidence. A login succeeded only when an element or text that exists **only after login** is present (a user menu, a list the gate hides) — not because a request returned 200. Also check that `page.url()` left the login page when the login page has its own URL; when the gate and the content share one URL, the post-login element is the only check.
- If that element is missing, collect network events (above) for the app's auth endpoint. No auth request at all means the submit happened before the page could handle it (for example before hydration, when a native form POST replaces the JS handler). With the server up and the steps run, that is a reproducible mismatch, so the verdict is `failed` (not `blocked`) with this evidence, even when a slower manual login works; `blocked` is for a missing server, account, fixture, driver, or access. Do not retry until it passes or report the session as logged in.
- An E2E goal is met only when the **real outcome** is observable (a persisted value survives reload; expected data renders). Apply `reference/verification-loop.md`'s vacuity guard to any "it works" claim; express goals as **outcomes**, per `agentic-testing`.

## Crystallizing to a regression test (optional)

Exploration is not a permanent test. If `--crystallize` is explicitly requested after `/team-qa` passes, hand the verified path to `reference/e2e-testing.md` and emit a Playwright `.spec.ts` following its conventions (`getByRole` > … > `getByTestId`; `waitForResponse` / `waitFor`, never `waitForTimeout`). ego lite drives the exploration; Playwright owns the deterministic suite.

## See also (link, do not duplicate)

- `ego-browser skill` — command source of truth; its `references/clearing-state.md` for what a clear reaches
- `scripts/qa-profile.mjs` — gate 2 and new task spaces (`node --test` beside it for its tests)
- `reference/e2e-testing.md` — preconditions, artifact layout, Playwright conventions (crystallization target)
- `skills/agentic-testing/SKILL.md` — goal verification and verdicts; `/team-qa` drives the web through this skill
- `reference/verification-loop.md` — vacuity guard for "it works" claims
