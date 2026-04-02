#!/bin/bash
# Session Stop Hook — Archives session state for cross-session memory persistence
# Triggered: When Claude Code session ends (Stop event)

STATE_DIR=".claude/session-state"
ARCHIVE_DIR="$STATE_DIR/archive"

mkdir -p "$ARCHIVE_DIR"

# Rotate current session state → last-session
if [ -f "$STATE_DIR/current.md" ]; then
  # Archive previous last-session (if exists)
  if [ -f "$STATE_DIR/last-session.md" ]; then
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    mv "$STATE_DIR/last-session.md" "$ARCHIVE_DIR/session-$TIMESTAMP.md"
  fi

  # Promote current → last-session
  mv "$STATE_DIR/current.md" "$STATE_DIR/last-session.md"
  echo "[session-stop] Session state archived successfully."
else
  echo "[session-stop] No session state to archive."
fi

# Clean archives older than 7 days (keep recent history)
find "$ARCHIVE_DIR" -name "*.md" -mtime +7 -delete 2>/dev/null

# Keep max 20 archive files
ARCHIVE_COUNT=$(ls -1 "$ARCHIVE_DIR"/*.md 2>/dev/null | wc -l)
if [ "$ARCHIVE_COUNT" -gt 20 ]; then
  ls -1t "$ARCHIVE_DIR"/*.md | tail -n +21 | xargs rm -f
fi
