#!/usr/bin/env sh
# Generic brain sync helper (macOS/Linux). Mirrors sync.ps1. Fail-open: never blocks a session.
cd "$(dirname "$0")" || exit 0

case "$1" in
  pull)
    git pull --rebase --quiet 2>/dev/null
    ;;
  push)
    git add -A 2>/dev/null
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      git commit -q -m "auto-sync: $(hostname -s) $(date +%Y-%m-%dT%H:%M:%S%z)" 2>/dev/null
      git push -q 2>/dev/null
    fi
    ;;
esac
exit 0
