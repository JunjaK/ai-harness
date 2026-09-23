#!/bin/bash
# Informational only. The Claude session hooks mutate .claude/session-state and
# expect Claude tool payloads, so Codex does not reuse them.
active_dir="_docs/active"
[ -d "$active_dir" ] || exit 0

stale_count=$(find "$active_dir" -name '*.md' -mtime +14 2>/dev/null | wc -l | tr -d ' ')
if [ "$stale_count" -gt 0 ]; then
  printf '[ai-harness] %s active document(s) older than 14 days; review them when relevant.\n' "$stale_count"
fi
