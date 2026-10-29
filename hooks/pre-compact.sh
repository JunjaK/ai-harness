#!/bin/bash
# Pre-Compact Hook — snapshot this session's state before compaction
# Triggered: PreCompact (auto — includes idle compaction)
# Layout (SSOT: checkpoint skill → Storage): .claude/session-state/sessions/<session_id>/
# Silent: Claude Code keeps no PreCompact output for Claude, and Claude gets no turn before
# compacting. The post-compaction pointer is session-compact.sh (SessionStart "compact").

INPUT=$(cat)
SID=${CLAUDE_CODE_SESSION_ID:-}
[ -n "$SID" ] || SID=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$SID" ] || exit 0

# Primary working tree, so a session started inside a linked worktree uses the same state.
PROJECT="${CLAUDE_PROJECT_DIR:-.}"
COMMON=$(git -C "$PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && PROJECT=$(dirname "$COMMON")
SESSION_DIR="$PROJECT/.claude/session-state/sessions/$SID"
CHECKPOINT_DIR="$SESSION_DIR/checkpoints"

if [ -f "$SESSION_DIR/current.md" ]; then
  mkdir -p "$CHECKPOINT_DIR"
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  cp "$SESSION_DIR/current.md" "$CHECKPOINT_DIR/checkpoint-$TIMESTAMP.md"
  cp "$SESSION_DIR/current.md" "$CHECKPOINT_DIR/latest.md"
  ls -1t "$CHECKPOINT_DIR"/checkpoint-*.md 2>/dev/null | tail -n +11 | while IFS= read -r f; do rm -f "$f"; done
fi

exit 0
