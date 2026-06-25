#!/bin/bash
# Session Start Hook — Nudge when _docs/active/ has docs overdue for a sweep
# Triggered: At session start (SessionStart event; sources startup|resume)
# Non-blocking: one-line nudge on stdout (exit 0). Silent when clean OR when the
# bucket layout isn't adopted in this repo (so it never false-alarms elsewhere).

ACTIVE_DIR="_docs/active"
THRESHOLD_DAYS=14

# Silent no-op if this repo hasn't adopted the docs-lifecycle v2 bucket layout.
[ -d "$ACTIVE_DIR" ] || exit 0

# Cheap, portable mtime scan (BSD/GNU): docs untouched for > threshold days.
STALE_COUNT=$(find "$ACTIVE_DIR" -name '*.md' -mtime +"$THRESHOLD_DAYS" 2>/dev/null | wc -l | tr -d ' ')

if [ "$STALE_COUNT" -gt 0 ]; then
  echo "[docs-sweep] ⚠ $STALE_COUNT stale active doc(s) untouched >${THRESHOLD_DAYS}d in _docs/active/ — run /docs-sweep to reap + lint."
fi

exit 0
