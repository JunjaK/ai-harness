#!/bin/bash
# Pre-Compact Hook — Reminds Claude to save critical state before context compression
# Triggered: Before compaction (PreToolUse with compact matcher)

STATE_DIR=".claude/session-state"
mkdir -p "$STATE_DIR"

echo "⚠️ COMPACTION IMMINENT — Save critical state before context is compressed."
echo ""
echo "Before proceeding, write the following to .claude/session-state/current.md:"
echo "1. Current task progress and status"
echo "2. Verified approaches (with evidence)"
echo "3. Failed approaches (with reasons)"
echo "4. Key decisions made during this session"
echo "5. Remaining work items"
echo ""

# Show existing state file if present
if [ -f "$STATE_DIR/current.md" ]; then
  echo "--- Existing session state ---"
  cat "$STATE_DIR/current.md"
  echo "--- End of existing state ---"
fi
