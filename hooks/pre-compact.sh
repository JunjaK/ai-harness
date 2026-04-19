#!/bin/bash
# Pre-Compact Hook — Auto-saves checkpoint + reminds Claude to update state
# Triggered: Before compaction (Notification with autocompact matcher)

STATE_DIR=".claude/session-state"
CHECKPOINT_DIR="$STATE_DIR/checkpoints"
mkdir -p "$STATE_DIR" "$CHECKPOINT_DIR"

# --- Auto-save checkpoint if current.md exists ---
if [ -f "$STATE_DIR/current.md" ]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  cp "$STATE_DIR/current.md" "$CHECKPOINT_DIR/checkpoint-$TIMESTAMP.md"
  cp "$STATE_DIR/current.md" "$CHECKPOINT_DIR/latest.md"
  echo "[pre-compact] Auto-checkpoint saved: checkpoint-$TIMESTAMP.md"

  # Clean old checkpoints (keep max 10)
  CKPT_COUNT=$(ls -1 "$CHECKPOINT_DIR"/checkpoint-*.md 2>/dev/null | wc -l)
  if [ "$CKPT_COUNT" -gt 10 ]; then
    ls -1t "$CHECKPOINT_DIR"/checkpoint-*.md | tail -n +11 | xargs rm -f
  fi
fi

echo ""
echo "COMPACTION IMMINENT — Update .claude/session-state/current.md before context is compressed."
echo ""
echo "Ensure the following are captured:"
echo "1. Current task progress and remaining steps"
echo "2. Verified approaches (with evidence)"
echo "3. Failed approaches (with reasons)"
echo "4. Key decisions made during this session"
echo "5. Next steps (concrete, actionable)"
echo ""

# Show existing state for reference
if [ -f "$STATE_DIR/current.md" ]; then
  echo "--- Current session state (update if stale) ---"
  cat "$STATE_DIR/current.md"
  echo "--- End of state ---"
fi
