#!/usr/bin/env sh
# Merge settings.recommended.json into the settings.json of every Claude Code config dir (macOS/Linux).
# Targets: ~/.claude, $CLAUDE_CONFIG_DIR when set, and every config dir given as an argument
# (e.g. a launcher's per-profile homes). Each config dir keeps its own settings.json, so a key
# merged into one is invisible to sessions started under another.
# Recursive merge, manifest wins. Keys ABSENT from the manifest are left exactly as
# they are in each file -- that is how machine-specific `hooks` (absolute script
# paths), `statusLine`, `permissions.allow` and any skip* flags survive.
# Backs up each file first; leaves a file untouched if its merge would produce invalid JSON.
#   usage: apply-settings.sh ["<config dir>" ...]
set -e
BRAIN="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$BRAIN/settings.recommended.json"
STAMP="$(date +%Y%m%d-%H%M%S)"

command -v jq >/dev/null 2>&1 || { echo "jq is required (brew install jq)"; exit 1; }
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST"; exit 1; }

FAILED=0
merge_one() {
    SETTINGS="$1/settings.json"
    [ -f "$SETTINGS" ] || printf '{}' > "$SETTINGS"
    cp "$SETTINGS" "$SETTINGS.bak-$STAMP"
    if jq -s '.[0] * .[1]' "$SETTINGS" "$MANIFEST" > "$SETTINGS.merged" \
       && jq -e 'type == "object"' "$SETTINGS.merged" >/dev/null; then
        mv "$SETTINGS.merged" "$SETTINGS"
        echo "merged  $SETTINGS  [backup: settings.json.bak-$STAMP]"
    else
        rm -f "$SETTINGS.merged"
        echo "! merge failed -> $SETTINGS left untouched"
        FAILED=1
    fi
}

SEEN="|"
for DIR in "$HOME/.claude" ${CLAUDE_CONFIG_DIR:+"$CLAUDE_CONFIG_DIR"} "$@"; do
    REAL="$(cd "$DIR" 2>/dev/null && pwd -P)" || { echo "skip    $DIR (no such dir)"; continue; }
    case "$SEEN" in *"|$REAL|"*) continue ;; esac
    SEEN="$SEEN$REAL|"
    merge_one "$REAL"
done
[ "$FAILED" -eq 0 ]
