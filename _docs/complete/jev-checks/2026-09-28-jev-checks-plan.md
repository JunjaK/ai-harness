---
topic: jev-checks
kind: plan
status: complete
created: 2026-09-28
updated: 2026-09-28
---

# v1.35.0 backlog — Jev checks and QA feedback

Collected from live QA runs on picblog (Nuxt web) and nivoca (Flutter) after v1.33–v1.34, all handled in
v1.35.0 (see `## Outcome`). Line numbers refer to v1.34.1.

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

## Outcome (v1.35.0)

| # | Result |
|---|---|
| 1 | Done. `qa-crosscheck.sh` asks a second question, `on_target`; below 0.35 a passed/failed label becomes `insufficient_evidence` with a `note`, shown as `contested`. Probe (jev-1.13.0, 15 cases): C2/C2b 0.10–0.15, every on-target passed/failed 0.55–0.97; live C2b ×2 → contested. Limitation seen: a clean restart case with token rotation (C2-ok) was read as `failed` 0.4 → `uncertain`. |
| 2 | Partly. `qa_crosscheck` returns `elapsed_ms`; one call measured inside the server takes ~250 ms, so nivoca's 5.3 s came from outside it. Suspected, not verified: the stdio server handles one request at a time, so parallel calls queue. |
| 3 | Done. MCP tool `qa_status` (no Jev call); `agentic-testing` calls it once before the first scenario. |
| 4 | Decided: our verdicts stay passed/failed/blocked; `insufficient_evidence` appears only in the Jev column. |
| 5 | Still unverified; carried forward. |
| 6–15 | Done as proposed (agent-browser-e2e, e2e-testing, agentic-testing, project-analyzer and its template, submodule-worktree, checkpoint, pre-compact.sh). |

## Deferred QA

### QA-2026-09-28-jev-checks-plan-01 — Off-target mobile run is contested
- Priority: P1
- Preconditions: plugin ≥1.35.0 with `jev_api_key` set; an Android emulator with a Flutter app
- Actions: launch with a command that brings another app to the front (or none), record `pidof` and the screen, verdict `failed`, call `qa_crosscheck`
- Expected: `jev: insufficient_evidence`, `status: contested`, `note` present
- Source: backlog item 1 (nivoca C2/C2b)
- Status: pending
- Evidence: —

### QA-2026-09-28-jev-checks-plan-02 — Missing key is reported before the first scenario
- Priority: P2
- Preconditions: plugin ≥1.35.0 with `jev_api_key` empty
- Actions: run `agentic-testing` on any goal
- Expected: one message naming `/plugin` → Configure before scenario 1; scenarios continue with `Jev: skipped`
- Source: backlog item 3
- Status: pending
- Evidence: —

### QA-2026-09-28-jev-checks-plan-03 — Headless upload through a JS-opened file picker
- Priority: P1
- Preconditions: a web app whose upload button calls `input.click()` in its handler; a fixture image
- Actions: follow agent-browser-e2e → Driving pitfalls → File choosers
- Expected: the upload completes and the uploaded item persists after reload
- Source: backlog item 7 (picblog `pickPhotos`)
- Status: pending
- Evidence: —

### QA-2026-09-28-jev-checks-plan-04 — `/team-init` never opens gitignored files
- Priority: P0
- Preconditions: a submodule project with gitignored `secrets.json` / `.env`
- Actions: run `/team-init`; inspect the subagent transcript
- Expected: the carry-list names the files and purposes; no file content appears in any transcript
- Source: backlog item 11 (nivoca)
- Status: pending
- Evidence: —

### QA-2026-09-28-jev-checks-plan-05 — Stop gate note reaches Claude in a live session
- Priority: P2
- Preconditions: `jev_stop_gate` on and a key set through `/plugin` → Configure (not `--settings`)
- Actions: in a real session, make a completion claim with no check in the turn
- Expected: one `[jev stop-gate]` note; Claude runs the check or restates the claim as unverified
- Source: backlog item 5
- Status: pending
- Evidence: —

