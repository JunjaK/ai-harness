#!/usr/bin/env sh
# Merge settings.recommended.json into ~/.claude/settings.json (macOS/Linux).
# Recursive merge, manifest wins. Keys ABSENT from the manifest are left exactly as
# they are on this machine -- that is how machine-specific `hooks` (absolute script
# paths), `statusLine`, `permissions.allow` and any skip* flags survive.
# Backs up first; restores the backup if the merge would produce invalid JSON.
set -e
BRAIN="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$BRAIN/settings.recommended.json"
SETTINGS="$HOME/.claude/settings.json"
STAMP="$(date +%Y%m%d-%H%M%S)"

command -v jq >/dev/null 2>&1 || { echo "jq is required (brew install jq)"; exit 1; }
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST"; exit 1; }
[ -f "$SETTINGS" ] || printf '{}' > "$SETTINGS"

cp "$SETTINGS" "$SETTINGS.bak-$STAMP"
if jq -s '.[0] * .[1]' "$SETTINGS" "$MANIFEST" > "$SETTINGS.merged" \
   && jq -e 'type == "object"' "$SETTINGS.merged" >/dev/null; then
    mv "$SETTINGS.merged" "$SETTINGS"
    echo "settings merged  [backup: $SETTINGS.bak-$STAMP]"
else
    rm -f "$SETTINGS.merged"
    echo "! merge failed -> settings.json left untouched"
    exit 1
fi
