---
description: "Docs Sweep — drain stale active docs (reap) + enforce the 6 orphan-mode invariants (lint) in _docs/"
---

# Docs Sweep

Keep `_docs/` honest as it grows: drain `active/` of stale docs and re-verify the orphan-mode invariants. Invoked manually, or when the `SessionStart` hook nudges that `active/` is overdue.

## Usage

```
/docs-sweep              # reap + lint
/docs-sweep --lint-only  # invariant check only (no reaping)
/docs-sweep --reap-only  # staleness reaping only (no lint)
```

## What It Does

Invoke the `docs-lifecycle` skill's **Sweep & Lint** routine.

### REAP (drain `active/`) — signal-gated, never age-gated

For each `_docs/active/**/*.md`:
1. `staleness = today − frontmatter.updated` (threshold **14 days**).
2. Gather signals: linked PR merged? branch gone? recent commits touching its `related:`/own path?
3. **Signals decide; age only flags**:
   - done signal (PR merged / branch gone) → propose **`→ complete`** (docs-lifecycle Merge rule)
   - abandoned signal (superseded / dropped) → propose **`→ deprecated`**
   - **no signal** (local-only / no-remote repo) → age **FLAGS only** → propose **`snooze`** (bump `updated` + reason). NEVER silent auto-complete.
4. Present per-doc proposals; **each needs a decision** (human, or orchestrator on strong signals only in autonomous mode).

### LINT (the 6 invariants)

Static pass over `_docs/**` + `.claude/wiki/**`; report + auto-fix where safe:

| I# | Check | Auto-fix |
|----|-------|----------|
| I1 | `index.md` ↔ disk 1:1 (key `(topic,date,kind)`) | propose row add/remove |
| I2 | no dangling `_docs/` link (ignore `<other-repo>/_docs/…`) | no (needs intent) |
| I3 | no off-vocabulary `complete/`/`reference/` topic folder | propose vocab-add / topic-rename |
| I4 | no empty `active/**` date folder | `rmdir` |
| I5 | no `active/` sidecar sharing `(topic,date)` with a `complete/<topic>` doc | propose merge |
| I6 | no dangling `_docs/` link from `.claude/wiki/`; `_note/` refs surfaced as warnings | wiki: yes; `_note/`: warn-only |

## On Completion

```
🧹 DOCS SWEEP
Reaped:   <n> → complete, <n> → deprecated, <n> snoozed, <n> flagged (no signal)
Lint:     I1 ✓  I2 ✓  I3 ✓  I4 ✓ (rmdir <n>)  I5 ✓  I6 ✓
Warnings: <_note/ references to moved docs, if any>
```

## Related
- `docs-lifecycle` skill — owns the layout, the 6 invariants, and this Sweep & Lint routine
- `hooks/session-start.sh` — detection nudge that points here
- `handoff` skill — handoffs are reaped under the keep-latest-per-stream rule
