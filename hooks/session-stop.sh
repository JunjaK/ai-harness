#!/bin/bash
# Stop Hook — warn about stray run artifacts at the repo root
# Triggered: Stop (after every reply). Session state is snapshotted once, at SessionEnd
# (session-end.sh); rotating it here would move the live state away after each reply.

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
