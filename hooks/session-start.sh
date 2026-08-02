#!/bin/bash
# Session Start Hook — Nudge when _docs/active/ has docs overdue for a sweep
# Triggered: At session start (SessionStart event; sources startup|resume)
# Non-blocking: one-line nudge on stdout (exit 0). Silent when clean OR when the
# bucket layout isn't adopted in this repo (so it never false-alarms elsewhere).

ACTIVE_DIR="_docs/active"
THRESHOLD_DAYS=14

# jq gate — the PostToolUse hook (post-edit-warn.sh) reads its file path from the
# hook's stdin JSON via jq. Without jq that hook silently no-ops on every
# Edit/Write, so say it ONCE here rather than never.
command -v jq >/dev/null 2>&1 || \
  echo "[ai-harness] ⚠ jq not found — the post-edit warning hook (console.*/debugger/_note/ checks) is disabled. Install: brew install jq | apt install jq | winget install jqlang.jq"

# Silent no-op if this repo hasn't adopted the docs-lifecycle v2 bucket layout.
[ -d "$ACTIVE_DIR" ] || exit 0

# Cheap, portable mtime scan (BSD/GNU): docs untouched for > threshold days.
STALE_COUNT=$(find "$ACTIVE_DIR" -name '*.md' -mtime +"$THRESHOLD_DAYS" 2>/dev/null | wc -l | tr -d ' ')

if [ "$STALE_COUNT" -gt 0 ]; then
  echo "[docs-sweep] ⚠ $STALE_COUNT stale active doc(s) untouched >${THRESHOLD_DAYS}d in _docs/active/ — run /docs-sweep to reap + lint."
fi

exit 0
