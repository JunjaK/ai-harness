#!/bin/bash
# Pre-Compact Hook — snapshot this session's state and remind Claude to update it
# Triggered: PreCompact (auto)
# Layout (SSOT: checkpoint skill → Storage): .claude/session-state/sessions/<session_id>/

INPUT=$(cat)
SID=${CLAUDE_CODE_SESSION_ID:-}
[ -n "$SID" ] || SID=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# Primary working tree, so a session started inside a linked worktree uses the same state.
PROJECT="${CLAUDE_PROJECT_DIR:-.}"
COMMON=$(git -C "$PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && PROJECT=$(dirname "$COMMON")
STATE_ROOT="$PROJECT/.claude/session-state"
REL_DIR=".claude/session-state/sessions/${SID:-<session_id>}"
SESSION_DIR="$STATE_ROOT/sessions/${SID:-unknown}"
CHECKPOINT_DIR="$SESSION_DIR/checkpoints"

if [ -n "$SID" ] && [ -f "$SESSION_DIR/current.md" ]; then
  mkdir -p "$CHECKPOINT_DIR"
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  cp "$SESSION_DIR/current.md" "$CHECKPOINT_DIR/checkpoint-$TIMESTAMP.md"
  cp "$SESSION_DIR/current.md" "$CHECKPOINT_DIR/latest.md"
  echo "[pre-compact] Auto-checkpoint saved: $REL_DIR/checkpoints/checkpoint-$TIMESTAMP.md"
  ls -1t "$CHECKPOINT_DIR"/checkpoint-*.md 2>/dev/null | tail -n +11 | while IFS= read -r f; do rm -f "$f"; done
fi

# Team runs this session owns survive compaction on disk; point Claude back at them.
if [ -n "$SID" ] && [ -d "$STATE_ROOT/runs" ]; then
  for f in "$STATE_ROOT/runs"/*.json; do
    [ -f "$f" ] || continue
    if grep -q "\"owner_session\"[[:space:]]*:[[:space:]]*\"$SID\"" "$f"; then
      echo "[pre-compact] Team run .claude/session-state/runs/$(basename "$f") is owned by this session — re-read it after compaction (phase/retries/globalCycle) before resuming."
    fi
  done
fi

echo ""
echo "COMPACTION IMMINENT — Update $REL_DIR/current.md before context is compressed."
echo "(In Bash: .claude/session-state/sessions/\$CLAUDE_CODE_SESSION_ID/current.md)"
echo ""
echo "Ensure the following are captured:"
echo "1. Current task progress and remaining steps"
echo "2. Verified approaches (with evidence)"
echo "3. Failed approaches (with reasons)"
echo "4. Key decisions made during this session"
echo "5. Next steps (concrete, actionable)"
echo ""

if [ -n "$SID" ] && [ -f "$SESSION_DIR/current.md" ]; then
  echo "--- Current session state (update if stale) ---"
  cat "$SESSION_DIR/current.md"
  echo "--- End of state ---"
fi
