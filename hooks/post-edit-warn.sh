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

# _docs/ collection buckets are append-only: new files are fine, rewriting an existing
# one is not. Warn on ANY write regardless of file type; the agent decides if it was a
# create (fine) or a reorganize (defect).
#
# Matched by INVERSION rather than by listing the collections: only active/, complete/,
# reference/ and deprecated/ are lifecycle buckets, so any OTHER top-level folder under
# _docs/ is a collection. That covers intent/ and handoff/ plus whatever a project
# declares (meetings/, inquiry/, proposal/, …) without the hook having to read the
# project profile — an allowlist here would silently miss every project-declared bucket.
DOCS_REL=${FILE##*/_docs/}
if [ "$DOCS_REL" != "$FILE" ] || case "$FILE" in _docs/*) true ;; *) false ;; esac; then
  [ "$DOCS_REL" = "$FILE" ] && DOCS_REL=${FILE#_docs/}
  BUCKET=${DOCS_REL%%/*}
  case "$BUCKET" in
    active|complete|reference|deprecated|"$DOCS_REL")
      # lifecycle bucket, or a bare file at _docs/ root (index.md) — no warning
      ;;
    *)
      printf '[warn] %s is in the _docs/%s/ collection bucket (append-only). Creating a new record is fine; MUST NOT merge, restructure, rename, or delete an existing one without the human'"'"'s explicit request. Deprecate in place under %s/deprecated/. Exception: handoff/ is prune-to-latest by contract.\n\n' "$FILE" "$BUCKET" "$BUCKET"
      ;;
  esac
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
  WARNINGS="${WARNINGS}[warn] console.* statements detected in ${FILE}:
${MATCHES}

"
fi

# Check for debugger statements
if grep -n "^\s*debugger" "$FILE" 2>/dev/null | grep -q .; then
  MATCHES=$(grep -n "^\s*debugger" "$FILE" 2>/dev/null)
  WARNINGS="${WARNINGS}[warn] debugger statement in ${FILE}:
${MATCHES}

"
fi

# Check for TODO/FIXME/HACK comments (informational)
if grep -n "\(TODO\|FIXME\|HACK\|XXX\)" "$FILE" 2>/dev/null | head -3 | grep -q .; then
  COUNT=$(grep -c "\(TODO\|FIXME\|HACK\|XXX\)" "$FILE" 2>/dev/null)
  WARNINGS="${WARNINGS}[info] ${COUNT} TODO/FIXME markers in ${FILE}

"
fi

if [ -n "$WARNINGS" ]; then
  printf '%s' "$WARNINGS"
fi
