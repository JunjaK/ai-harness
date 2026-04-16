#!/bin/bash
# Post-Edit Warning Hook — Detects debug statements and unsafe patterns in edited files
# Triggered: PostToolUse for Edit/Write operations
# Source: gstack console-warn + ECC design-quality-check patterns

# Get the file path from the tool result (passed as argument)
FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

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
