#!/bin/bash
# Session Compact Hook — re-point Claude at on-disk state right after compaction
# Triggered: SessionStart (source "compact"), which fires after auto, manual and idle compaction
# SessionStart plain stdout is added to Claude's context, so this is where the pointer lands.
# Layout (SSOT: checkpoint skill → Storage): .claude/session-state/sessions/<session_id>/

INPUT=$(cat)
SID=${CLAUDE_CODE_SESSION_ID:-}
[ -n "$SID" ] || SID=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$SID" ] || exit 0

# Primary working tree, so a session started inside a linked worktree uses the same state.
PROJECT="${CLAUDE_PROJECT_DIR:-.}"
COMMON=$(git -C "$PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && PROJECT=$(dirname "$COMMON")
STATE_ROOT="$PROJECT/.claude/session-state"
SESSION_DIR="$STATE_ROOT/sessions/$SID"

# Team runs this session owns survive compaction on disk; point Claude back at them.
if [ -d "$STATE_ROOT/runs" ]; then
  for f in "$STATE_ROOT/runs"/*.json; do
    [ -f "$f" ] || continue
    if grep -q "\"owner_session\"[[:space:]]*:[[:space:]]*\"$SID\"" "$f"; then
      echo "[compact] Team run $f is owned by this session — re-read it (phase/retries/globalCycle) before resuming."
    fi
  done
fi

# Absolute path: an agent whose cwd is a subfolder would create a stray nested folder from a relative one.
if [ -f "$SESSION_DIR/current.md" ]; then
  echo "[compact] Session state before compaction ($SESSION_DIR/current.md). Update it if it is stale:"
  cat "$SESSION_DIR/current.md"
fi

exit 0
