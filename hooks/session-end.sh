#!/bin/bash
# Session End Hook — snapshot this session's state once, and prune old session folders
# Triggered: SessionEnd (the session terminates — not every reply; that is Stop)
# Layout (SSOT: checkpoint skill → Storage): .claude/session-state/sessions/<session_id>/
# session-state is gitignored, throwaway runtime data; durable lessons are promoted to _docs/reference/.

INPUT=$(cat)
SID=${CLAUDE_CODE_SESSION_ID:-}
[ -n "$SID" ] || SID=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$SID" ] || exit 0

# Primary working tree, so a session started inside a linked worktree uses the same state.
PROJECT="${CLAUDE_PROJECT_DIR:-.}"
COMMON=$(git -C "$PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && PROJECT=$(dirname "$COMMON")
STATE_ROOT="$PROJECT/.claude/session-state"
SESSION_DIR="$STATE_ROOT/sessions/$SID"
CHECKPOINT_DIR="$SESSION_DIR/checkpoints"

if [ -f "$SESSION_DIR/current.md" ]; then
  mkdir -p "$CHECKPOINT_DIR"
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  cp "$SESSION_DIR/current.md" "$CHECKPOINT_DIR/checkpoint-$TIMESTAMP.md"
  cp "$SESSION_DIR/current.md" "$CHECKPOINT_DIR/latest.md"
  # Keep the 10 newest timestamped checkpoints.
  ls -1t "$CHECKPOINT_DIR"/checkpoint-*.md 2>/dev/null | tail -n +11 | while IFS= read -r f; do rm -f "$f"; done
fi

# Session folders nobody touched for 14 days are gone for good; runs/ is left alone
# because an unfinished team run must survive until a human closes it.
# Judge by the newest file inside: editing current.md in place does not bump the folder's mtime.
if [ -d "$STATE_ROOT/sessions" ]; then
  for d in "$STATE_ROOT/sessions"/*/; do
    [ -d "$d" ] || continue
    [ "$(basename "$d")" = "$SID" ] && continue
    [ -n "$(find "$d" -type f -mtime -14 2>/dev/null | head -1)" ] || rm -rf "$d"
  done
fi

exit 0
