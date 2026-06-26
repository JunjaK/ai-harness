---
title: "Plan — /docs-sweep: periodic active-doc reaping + orphan lint + SessionStart nudge"
status: complete
topic: docs-sweep
kind: plan
scope: harness
created: 2026-06-25
updated: 2026-06-26
related: [_docs/complete/docs-lifecycle/2026-06-25-docs-lifecycle.md]
---

# Plan — /docs-sweep

> Sub-project **#3 of 3**. Depends on **#2** (`docs-lifecycle` v2 layout + the 6 invariants + reference-safe transaction). Closes the "active piles up + orphans accumulate over time" problem with detection (hook) + action (command).

## Goal

Keep `_docs/active/` from silently accumulating stale docs, and keep the 6 orphan-mode invariants continuously true — without ever silently mis-filing an unfinished doc as complete.

## Two halves

**Detection = a `SessionStart` hook** (cheap, every session → naturally "periodic"). **Action = the `/docs-sweep` command** (reap + lint, interactive).

## REAP (drain `active/`) — signal-gated, never age-gated

For each `_docs/active/**/*.md`:

1. `staleness = today − frontmatter.updated`. Default threshold **14 days**.
2. Gather **signals** (best-effort): linked PR merged? branch gone? recent commits touching the doc's `related:` files / its own path?
3. Classify — **signals decide, age only flags**:
   - Strong "done" signal (PR merged / branch gone) → propose **`→ complete`** (apply docs-lifecycle merge rule).
   - Strong "abandoned" signal (superseded by a newer doc, explicitly dropped) → propose **`→ deprecated`**.
   - **No corroborating signal** (the common local-only / no-remote case — e.g. a freshly `/team-new`-bootstrapped repo has no PR/remote): age can **only FLAG** → propose **`snooze`** (bump `updated`, record a one-line reason) or ask. **NEVER** silent auto-complete.
4. Signal precedence when they conflict: `PR merged` > `branch gone` > `recent commits`.
5. **Every reap action requires a per-doc human/orchestrator decision.** In `/team-run` autonomous mode, act only on strong signals; otherwise flag-and-leave.

## LINT (enforce the 6 invariants)

Static checks over `_docs/**` (+ `.claude/wiki/**`), report + offer auto-fix where safe:

| I# | Check | Auto-fixable? |
|----|-------|---------------|
| I1 | `index.md` ↔ disk bidirectional 1:1 (key `(topic,date,kind)`) | propose row add/remove |
| I2 | no dangling `_docs/` link (`related:` + inline) — resolve each intra-repo path; ignore `<other-repo>/_docs/...` prefixes | no (needs intent) |
| I3 | no `complete/<topic>`/`reference/<topic>` folder absent from the index vocabulary | propose vocab add or rename |
| I4 | no empty date folder under `active/**` | yes — `rmdir` |
| I5 | merge-completeness: no `active/` sidecar left behind sharing `(topic,date)` with a `complete/<topic>` doc | propose merge |
| I6 | no dangling `_docs/` link from `.claude/wiki/**`; list `_note/` refs to moved/missing docs as **warnings** (never edit `_note/`) | wiki: yes; `_note/`: warn-only |

## Components

| File | Change |
|------|--------|
| `skills/docs-lifecycle/SKILL.md` | add `## Sweep & Lint (\`/docs-sweep\`)` section: the reap algorithm + the 6-invariant lint procedure (the rules' owner also owns their enforcement) |
| `commands/docs-sweep.md` | thin command: invoke the docs-lifecycle Sweep & Lint routine; `--lint-only` / `--reap-only` optional args; present per-doc proposals |
| `hooks/session-start.sh` | NEW — mirror `session-stop.sh` style; cheap `find _docs/active -name '*.md'` mtime/`updated` scan; if N>0 stale, `echo` a one-line nudge; exit 0 (non-blocking); **silent when clean**; tolerate missing `_docs/active` (legacy/other repos) by exiting 0 |
| `hooks/hooks.json` | register `SessionStart` block, matcher `"startup\|resume"`, `bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh` |
| `CLAUDE.md` | Commands table → `/docs-sweep` row; Active Hooks table → `Session Start \| SessionStart \| hooks/session-start.sh` row |

## Hook design (the part that must be careful)

- **type:command** (Claude Code rejects prompt/agent hooks for SessionStart).
- **matcher `"startup|resume"`** (matches the harness's non-`*` convention; valid sources startup/resume/clear/compact).
- **Non-blocking nudge** = stdout on **exit 0** (shown in transcript). NEVER exit 2 (that's a blocking error).
- **Cheap + quiet**: scan mtime only (don't parse every frontmatter on the hot path); emit nothing when nothing is stale. Echoed: count + threshold (>14d) + `Run /docs-sweep` (mtime-only; oldest-age omitted to keep the hot path portable/cheap).
- **Graceful on non-bucket repos**: if `_docs/active` is absent, exit 0 silently (the hook ships in the plugin → fires in every repo; must not false-alarm where the layout isn't adopted).

## Verification

1. Fixture `_docs/` with: an off-vocab topic folder, an empty date folder, a dangling `related:`, an index row with no file → lint flags **each** (I1–I6).
2. `session-start.sh` on a clean tree → **no output**; on a tree with a 30-day-old `active/` doc → one nudge line, exit 0.
3. Reap on a no-remote repo with a 20-day-old doc → proposes **snooze only** (never `complete`).
4. `hooks.json` parses (`jq . hooks/hooks.json`).
