#!/bin/bash
# Session Stop Hook — Archives session state + auto-saves checkpoint
# Triggered: When Claude Code session ends (Stop event)

STATE_DIR=".claude/session-state"
ARCHIVE_DIR="$STATE_DIR/archive"
CHECKPOINT_DIR="$STATE_DIR/checkpoints"

mkdir -p "$ARCHIVE_DIR" "$CHECKPOINT_DIR"

# --- Auto-save checkpoint from current.md ---
if [ -f "$STATE_DIR/current.md" ]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)

  # Save timestamped checkpoint
  cp "$STATE_DIR/current.md" "$CHECKPOINT_DIR/checkpoint-$TIMESTAMP.md"

  # Update latest checkpoint
  cp "$STATE_DIR/current.md" "$CHECKPOINT_DIR/latest.md"

  echo "[session-stop] Checkpoint saved: checkpoint-$TIMESTAMP.md"

  # Clean old checkpoints (keep max 10)
  CKPT_COUNT=$(ls -1 "$CHECKPOINT_DIR"/checkpoint-*.md 2>/dev/null | wc -l)
  if [ "$CKPT_COUNT" -gt 10 ]; then
    ls -1t "$CHECKPOINT_DIR"/checkpoint-*.md | tail -n +11 | xargs rm -f
  fi
fi

# --- Rotate session state: current → last-session → archive ---
if [ -f "$STATE_DIR/current.md" ]; then
  if [ -f "$STATE_DIR/last-session.md" ]; then
    TIMESTAMP=${TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}
    mv "$STATE_DIR/last-session.md" "$ARCHIVE_DIR/session-$TIMESTAMP.md"
  fi

  mv "$STATE_DIR/current.md" "$STATE_DIR/last-session.md"
  echo "[session-stop] Session state archived successfully."
else
  echo "[session-stop] No session state to archive."
fi

# --- Cleanup: archives older than 7 days, max 20 ---
find "$ARCHIVE_DIR" -name "*.md" -mtime +7 -delete 2>/dev/null

ARCHIVE_COUNT=$(ls -1 "$ARCHIVE_DIR"/*.md 2>/dev/null | wc -l)
if [ "$ARCHIVE_COUNT" -gt 20 ]; then
  ls -1t "$ARCHIVE_DIR"/*.md | tail -n +21 | xargs rm -f
fi

# --- Stray artifact scan: throwaway output belongs in _workspace/<context>/, not the repo root ---
# WARN ONLY. Never moves or deletes — a root file may be someone else's deliberate work, and this
# hook cannot tell. The human decides; the hook only makes the scatter visible before it compounds.
if command -v git >/dev/null 2>&1 && ROOT=$(git rev-parse --show-toplevel 2>/dev/null); then
  STRAY=""

  # Tracked root files are intentional (a logo, a README image) — never flag those.
  while IFS= read -r -d '' F; do
    git -C "$ROOT" ls-files --error-unmatch "$F" >/dev/null 2>&1 || STRAY="${STRAY}  ${F#"$ROOT"/}\n"
  done < <(find "$ROOT" -maxdepth 1 -type f \
    \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.gif' \
       -o -name '*.webm' -o -name '*.mp4' -o -name '*.zip' \) -print0 2>/dev/null)

  for D in test-results playwright-report blob-report; do
    [ -d "$ROOT/$D" ] && STRAY="${STRAY}  $D/\n"
  done

  if [ -n "$STRAY" ]; then
    echo "[session-stop] Stray run artifacts at the repo root — these belong in _workspace/<context>/:"
    echo -e "$STRAY"
    echo "[session-stop] Move or delete them, and pass an explicit _workspace/ path to the next capture call"
    echo "[session-stop] (a bare filename resolves to the repo root). See e2e-testing Artifact Layout."
  fi
fi
