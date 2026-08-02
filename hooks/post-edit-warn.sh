#!/bin/bash
# Post-Edit Warning Hook — Detects debug statements and unsafe patterns in edited files
# Triggered: PostToolUse for Edit/Write operations
# Source: gstack console-warn + ECC design-quality-check patterns

# File path comes either as an argument or from the hook's stdin JSON.
# jq is the only external tool this hook needs; when it is absent we no-op
# SILENTLY here (a warning on every Edit/Write would be spam) — session-start.sh
# emits the one visible "jq not found" line, once per session.
FILE="$1"

if [ -z "$FILE" ]; then
  command -v jq >/dev/null 2>&1 || exit 0
  FILE=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
fi

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

# _note/ is human-owned (agent read-only). Warn on ANY write, regardless of file type.
case "$FILE" in
  */_note/*|_note/*)
    echo -e "[warn] $FILE is under _note/ — human-owned (agent read-only). Edit ONLY on the human's explicit request; never reorganize, merge, or delete _note/ on your own.\n"
    ;;
esac

# Only check JS/TS/JSX/TSX files
case "$FILE" in
  *.js|*.ts|*.jsx|*.tsx|*.mjs|*.mts)
    ;;
  *)
    exit 0
    ;;
esac

WARNINGS=""

# Check for console.log/debug statements
if grep -n "console\.\(log\|debug\|warn\|error\|info\|trace\)" "$FILE" 2>/dev/null | head -5 | grep -q .; then
  MATCHES=$(grep -n "console\.\(log\|debug\|warn\|error\|info\|trace\)" "$FILE" 2>/dev/null | head -5)
  WARNINGS="${WARNINGS}[warn] console.* statements detected in $FILE:\n$MATCHES\n\n"
fi

# Check for debugger statements
if grep -n "^\s*debugger" "$FILE" 2>/dev/null | grep -q .; then
  MATCHES=$(grep -n "^\s*debugger" "$FILE" 2>/dev/null)
  WARNINGS="${WARNINGS}[warn] debugger statement in $FILE:\n$MATCHES\n\n"
fi

# Check for TODO/FIXME/HACK comments (informational)
if grep -n "\(TODO\|FIXME\|HACK\|XXX\)" "$FILE" 2>/dev/null | head -3 | grep -q .; then
  COUNT=$(grep -c "\(TODO\|FIXME\|HACK\|XXX\)" "$FILE" 2>/dev/null)
  WARNINGS="${WARNINGS}[info] $COUNT TODO/FIXME markers in $FILE\n\n"
fi

if [ -n "$WARNINGS" ]; then
  echo -e "$WARNINGS"
fi
