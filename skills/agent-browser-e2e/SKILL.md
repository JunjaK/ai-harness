---
name: agent-browser-e2e
description: "THE DEFAULT browser driver — invoke for ANY task driving a real browser, whether or not the user names it: E2E, QA, smoke, exploration, login-gated verification, resolving live selectors, plus team-workflow Phase 4 driving and Phase 4.5 exploration. Driver precedence: this skill FIRST → Playwright MCP only when its gate fails (say which condition) → claude-in-chrome only for the user's own logged-in Chrome profile. Reaching for a loaded browser MCP without running the gate is the known drift. Playwright still owns the committed `.spec.ts` suite — this drives, it is not a test framework. Headless login uses the encrypted Auth Vault, so the LLM never sees the password. Unattended runs (Phase 4/4.5, /team-run, scheduled) MUST have the dedicated E2E account + seeded test data in place BEFORE the first browser action — never invent credentials."
---

# agent-browser E2E

> **The default browser-driving layer** (CLAUDE.md → "Browser Driving"). Whenever a real browser must be driven — E2E, QA, smoke, exploration, login-gated verification, resolving live selectors — come here FIRST, including inside team-workflow **Phase 4 driving** and **Phase 4.5 exploration**. You do not need the user to name it. agent-browser is a **driver**, not a test framework.

## When to use / not use

- **Use** — any browser-driving task, requested or not: E2E / QA / smoke / exploration of a running app, Phase 4 driving, Phase 4.5 exploration, resolving real selectors for spec generation, and anything blocked by a headless login.
- **Don't use as** — the deterministic Playwright `.spec.ts` regression suite. Driving is this skill's job; a flow that must regress forever still crystallizes to a Playwright spec (see below).
- **Don't reach past it** — picking Playwright MCP or `claude-in-chrome` without first running the gate below is the drift this skill exists to stop. `claude-in-chrome` is for the user's own logged-in Chrome profile only.

## Gate — check ONCE, then trust

Two conditions, evaluated deterministically **at skill entry only**. Cache the result for the rest of the task: do **NOT** re-probe per command, and do **NOT** use `agent-browser doctor` or `agent-browser skills get core` as the probe (those are heavy — that repeated firing is the waste this gate avoids).

1. **CLI present** — `agent-browser --version` exits `0` (prints a version; no browser launch).
2. **Skill available** — `agent-browser` appears in your available-skills list. This is a **free observation** (the harness already surfaces it) — issue no shell command for it.

| Outcome | Action |
|---|---|
| Both pass | agent-browser is the **preferred** driver. Proceed. |
| Either fails | State **which** condition failed in one line, then fall back to `reference/e2e-testing.md` (deterministic) / `agentic-testing` (exploratory) Playwright path. **No silent skip.** Fall back to Playwright, not to `claude-in-chrome`. |

After the gate passes, load the real usage guide **once**: `agent-browser skills get core` (+ `agent-browser skills get dogfood` for exploratory QA / bug-hunts). The guide is version-matched and is the **SSOT for every command** — do not re-load it per command, and do not duplicate its command reference here. Run `agent-browser doctor` **only reactively** — when a command fails unexpectedly — never as a gate.

## Driving (CLI, native mode)

- Command surface (`open` / `snapshot -i` / `click @eN` / `fill` / `wait` / `screenshot` / …) lives in agent-browser's `core` skill — load it and follow it.
- Core loop: `open <url>` → `snapshot -i` → act on `@eN` refs → **re-snapshot after any page change** (refs go stale on navigation / re-render / dialog).
- Isolation / parallel users: derive a stable id — `SESSION="$(agent-browser session id --scope worktree --prefix <task>)"` — and pass `--session "$SESSION"`.

## Headless login (the core problem)

Headless mode cannot type a password interactively, and the LLM must never hold the secret.

> **Invariant — the LLM never receives the password** in its context, command args, or output. The agent triggers a login by *profile name*; the secret is supplied out of band.

### Default — Auth Vault

**One-time save (the human runs this** — it handles a real secret; the agent MUST NOT type the password):

```bash
echo "$PASSWORD" | agent-browser auth save <profile> \
  --url https://app.example.com/login \
  --username user@example.com \
  --password-stdin
# add --username-selector / --password-selector / --submit-selector if the form is not auto-detected
```

**Headless login (the agent runs this** — no secret involved):

```bash
agent-browser auth login <profile>    # waits for the form, fills, submits
```

Credentials are stored AES-256-GCM encrypted under `~/.agent-browser/`. The agent references the profile name only.

### Fallbacks (when the vault doesn't fit)

- **External vault → credential plugin** (team / CI; secret lives in real vault software). Gate the secret read explicitly:
  ```bash
  agent-browser plugin add agent-browser-plugin-vault --name vault
  agent-browser --confirm-actions plugin:vault:credential.read \
    auth login <profile> --credential-provider vault --item "My App"
  ```
- **Import state from a logged-in Chrome** (best for 2FA / SSO — no password step at all). The human starts Chrome with `--remote-debugging-port=9222` and logs in; then:
  ```bash
  agent-browser --auto-connect state save _test/.auth/app.json
  agent-browser --state _test/.auth/app.json open https://app.example.com/dashboard
  ```
- **Persistent profile / session restore** (login survives across runs):
  ```bash
  agent-browser --profile ~/.profiles/app open https://app.example.com           # persists cookies/IndexedDB/SW
  SESSION="$(agent-browser session id --scope worktree --prefix app)"
  agent-browser --session "$SESSION" --restore open https://app.example.com       # auto save/restore state
  ```

### Security

- State / auth files contain live session tokens → keep them under the gitignored `_test/.auth/` and
  screenshots under `_test/<run>/screenshots/` (see `e2e-testing` **Artifact Layout**); delete when done.
- Encrypt at rest: `export AGENT_BROWSER_ENCRYPTION_KEY=$(openssl rand -hex 32)`.
- `--remote-debugging-port` grants full browser control on localhost — trusted machines only; close Chrome when done.
- **Starting the app server / tunnels is the human's job** — surface a one-line "please start X" and don't script around it (harness operational discipline).

## Verification (do not trust 200 / UI)

- A login is "successful" only when `agent-browser get url` is **no longer the login page** and a post-login element/text is present — not because a request returned 200.
- An E2E goal is met only when the **real outcome** is observable (a persisted value survives reload; expected data renders). Apply `verification-loop`'s vacuity guard to any "it works" claim; express goals as **outcomes**, per `agentic-testing`.

## Crystallizing to a regression test (optional)

On-demand exploration is not a permanent test. If a flow should regress forever, hand the verified path to `e2e-testing` and emit a Playwright `.spec.ts` following its conventions (`getByRole` > … > `getByTestId`; `waitForResponse` / `waitFor`, never `waitForTimeout`). agent-browser drives the exploration; Playwright owns the deterministic suite.

## See also (link, do not duplicate)

- agent-browser CLI skills: `core` (command SSOT), `dogfood` (exploratory QA), `references/authentication.md` (full auth patterns)
- `reference/e2e-testing.md` — deterministic Playwright `.spec.ts` conventions (fallback target + crystallization house style)
- `skills/agentic-testing/SKILL.md` — goal-verification concepts; the Phase 4.5 web Explorer drives through agent-browser when this gate passes, Playwright MCP otherwise
- `reference/verification-loop.md` — vacuity guard for "it works" claims
