---
topic: jev-checks
kind: plan
status: planning
created: 2026-09-28
updated: 2026-09-28
---

# v1.35.0 backlog — Jev checks and QA feedback

Collected from live QA runs on picblog (Nuxt web) and nivoca (Flutter) after v1.33–v1.34. Not started.
Decision (2026-09-28): ship v1.34.1 first (user is testing it on other machines), then handle everything
below in one v1.35.0. Line numbers refer to v1.34.1.

## Jev

1. **Mobile evidence: a step that never ran on the target is judged `failed`** (high). nivoca C2/C2b:
   `adb shell monkey -p <pkg> -c …LAUNCHER 1` opened Google Calendar; `pidof` empty, the screen showed
   another app, DB unchanged. Input verdict `failed` → Jev agreed (0.90; 0.75 without the conclusion
   sentence). Correct: `blocked` / `insufficient_evidence`. Proposal: a second question, "does the
   observation show the steps were performed on the target app/page?", combined in code (as the stop
   gate does), rather than more criteria wording. Measure on C2/C2b and the earlier 13 cases first.
   The contrasting strength held: C1 (same-process "restart" claimed as an OS restart) → contested 0.65.
2. **Latency**: one nivoca call ≈ 5.3 s (parallel calls, rough) vs 0.3–0.5 s on picblog. Add an
   elapsed field to the tool response and find the cause (MCP spawn, parallel calls).
3. **Missing key noticed too late**: a skipped call has no retry, breaking "one call right after each
   verdict". Check the key once at QA start and warn.
4. Our verdict set has no "insufficient evidence"; only Jev can say it. Decide whether `agentic-testing`
   should gain it or keep mapping it to a contested note.
5. Unverified: the stop gate's `additionalContext` reaching Claude in a live session; key entry through
   `/plugin` → Configure (smokes injected a non-sensitive copy via `--settings`); Windows (`python3`).

## agent-browser-e2e / agentic-testing / e2e-testing

6. **App servers** (P1, picblog): `skills/agent-browser-e2e/SKILL.md:89` makes starting the app server
   the human's job. CLAUDE.md reserves only shared/managed infra (tunnels, cloud DB, redis) for the human.
   Rewrite: the agent may start app servers on a free port with isolated data; shared infra stays human.
7. **Headless file choosers** (P1, picblog): nothing in skills/reference mentions file inputs. When the app
   calls `input.click()` inside a handler and waits for `change`/`cancel`, headless ends in `cancel` and
   `agent-browser upload` does nothing. Verified workaround: eval to neutralise
   `HTMLInputElement.prototype.click` for file inputs → click the button → `upload 'input[type=file]' <files>`.
   Emitter side: Playwright `page.waitForEvent('filechooser')`.
8. **Mobile driver tier** (nivoca): only maestro / patrol / mobile-mcp are listed, so nivoca's profile says
   `Driver: UNAVAILABLE`, yet QA reached DB-level restart persistence with `integration_test` output + adb
   lifecycle (`cmd package resolve-activity --brief` → `am start -W -n` / `am force-stop` / `pidof` /
   `exec-out screencap`) + local DB queries. Add it as a tier, with traps: `monkey -p` can launch another
   app (use `am start -n`); `flutter test` uninstalls the app on exit on Android, so restart persistence
   needs a real app build.
9. Responsive pages with duplicated markup: `find role … click` hit the hidden copy ("covered by header");
   snapshot refs (`@eN`) worked. One line in agent-browser-e2e.
10. File-based DBs (SQLite): "copy the data dir + override its path by env" is the isolated-local
    equivalent of "another schema". One line in `reference/e2e-testing.md` → Preconditions.

## project-analyzer / team-init

11. **Carry-list scan read secret files** (high, nivoca): `resources/profile-templates.md:70`
    (`ls-files --others --ignored`) led an Explore subagent to open `app/dev.local.json` and
    `app/secrets.json`; an HF token entered the model context and the subagent transcript. Rule: record
    names and purpose only; never open gitignored files. (User was told to consider rotating the token.)
12. Profile template §6 E2E Fixtures lacks a "Fixture files" row (paths, how to make them), though Jev's
    `blocked` criterion now names fixture files.
13. `Profile-Generated-At` (`SKILL.md:59`) goes stale after a manual profile edit; the next `--update`
    judges a current profile stale. Bump it on manual edits, or add `Last-Synced-At`.
14. `SKILL.md:45` hard-codes "Vitest 4.x"; current is 5.x. Say "current major".

## session-state

15. Nested `.claude/project-profile/.claude/session-state/` appeared in nivoca. Hooks use absolute paths,
    but `hooks/pre-compact.sh` tells the agent a relative `.claude/session-state/...` path; an agent whose
    cwd is a subfolder creates it there. Give the agent an absolute path.
