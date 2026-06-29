---
name: agent-browser-e2e
description: "Preferred browser-driving path for on-demand E2E / QA / smoke when the `agent-browser` CLI and its skill are installed. Use when asked to E2E-test, QA, smoke-test, or drive a web app through a real browser — OR when a headless run is blocked at login and you must authenticate without exposing the password to the LLM. Gates on two conditions (agent-browser CLI present + agent-browser skill available) checked ONCE; falls back to Playwright (`e2e-testing` / `agentic-testing`) when either is missing. The headless-login answer is agent-browser's encrypted Auth Vault (default), with credential-plugin / state-import / persistent-profile fallbacks. The LLM never sees the password."
---

# agent-browser E2E

> **On-demand browser-driving layer.** NOT wired into team-workflow Phase 4/4.5 — those stay Playwright (`e2e-testing` deterministic `.spec.ts`; Phase 4.5 Explorer = Playwright MCP). Invoke this when you need to *drive a real browser* (E2E, QA, smoke, login-gated verification) and `agent-browser` is available. agent-browser is a **driver**, not a test framework.

## When to use / not use

- **Use** — on-demand E2E / QA / smoke / exploration of a running app; any task blocked by a headless login.
- **Don't use as** — a replacement for deterministic Playwright `.spec.ts` regression suites (Phase 4) or the Phase 4.5 Explorer pipeline. Those are unchanged. This skill drives; if a flow must regress forever, crystallize it to Playwright (see below).

## Gate — check ONCE, then trust

Two conditions, evaluated deterministically **at skill entry only**. Cache the result for the rest of the task: do **NOT** re-probe per command, and do **NOT** use `agent-browser doctor` or `agent-browser skills get core` as the probe (those are heavy — that repeated firing is the waste this gate avoids).

1. **CLI present** — `agent-browser --version` exits `0` (prints a version; no browser launch).
2. **Skill available** — `agent-browser` appears in your available-skills list. This is a **free observation** (the harness already surfaces it) — issue no shell command for it.

| Outcome | Action |
|---|---|
| Both pass | agent-browser is the **preferred** driver. Proceed. |
| Either fails | State **which** condition failed in one line, then fall back to `e2e-testing` (deterministic) / `agentic-testing` (exploratory) Playwright path. **No silent skip.** |

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
  agent-browser --auto-connect state save ./.auth/app.json
  agent-browser --state ./.auth/app.json open https://app.example.com/dashboard
  ```
- **Persistent profile / session restore** (login survives across runs):
  ```bash
  agent-browser --profile ~/.profiles/app open https://app.example.com           # persists cookies/IndexedDB/SW
  SESSION="$(agent-browser session id --scope worktree --prefix app)"
  agent-browser --session "$SESSION" --restore open https://app.example.com       # auto save/restore state
  ```

### Security

- State / auth files contain live session tokens → add them to `.gitignore`, delete when done.
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
- `skills/e2e-testing/SKILL.md` — deterministic Playwright `.spec.ts` conventions (fallback target + crystallization house style)
- `skills/agentic-testing/SKILL.md` — goal-verification concepts; the Phase 4.5 web Explorer stays Playwright MCP
- `skills/verification-loop/SKILL.md` — vacuity guard for "it works" claims
