#!/usr/bin/env sh
# Generic brain connector (macOS/Linux). Mirrors setup.ps1. Copy into your brain repo and run
# from there -- it wires whatever the brain happens to expose, using its own location.
#
# Every layer is OPTIONAL; a layer the brain does not provide is skipped:
#   <brain>/CLAUDE.md      -> ~/.claude/CLAUDE.md
#   <brain>/persona.md     -> ~/.claude/persona.md
#   <brain>/skills/<name>/ -> ~/.claude/skills/<name>        (one link per skill)
#   <brain>/commands/      -> ~/.claude/commands/brain       (namespaced)
#   <brain>/memory/<name>/ -> ~/.claude/projects/<key>/memory
#
# Does NOT touch settings.json. Run ./apply-settings.sh for recommended keys and register the
# sync hooks yourself -- Claude Code blocks agents from self-modifying settings.json.
#
# usage: ./setup.sh [<absolute path of a project to attach memory to> [<project name>]]
set -e
BRAIN="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="$HOME/.claude"
STAMP="$(date +%Y%m%d-%H%M%S)"
echo "brain setup  (brain=$BRAIN)"

# idempotent symlink; moves any real file/dir aside rather than deleting it
link() {
    src="$1"; dst="$2"
    if [ -L "$dst" ]; then
        if [ "$(readlink "$dst")" = "$src" ]; then echo "  = $dst"; return; fi
        rm "$dst"
    elif [ -e "$dst" ]; then
        mv "$dst" "$dst.pre-brain-$STAMP"
        echo "  ~ moved aside -> $dst.pre-brain-$STAMP"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  + $dst -> $src"
}

# 1) global rules + persona. If the brain ships BOTH, keep the import inside its CLAUDE.md
#    RELATIVE ("@persona.md") and link persona.md next to CLAUDE.md: the relative form then
#    resolves under either base dir Claude Code might use, and carries no machine path.
[ -f "$BRAIN/CLAUDE.md" ] && link "$BRAIN/CLAUDE.md" "$CLAUDE/CLAUDE.md" || echo "  - no CLAUDE.md in brain -> skipped"
[ -f "$BRAIN/persona.md" ] && link "$BRAIN/persona.md" "$CLAUDE/persona.md" || echo "  - no persona.md in brain -> skipped"

# 2) brain-owned global skills -- ONE LINK PER SKILL, never the whole skills/ dir: third-party
#    skills live in ~/.claude/skills too, and linking the directory itself would hide them.
if [ -d "$BRAIN/skills" ]; then
    for d in "$BRAIN"/skills/*/; do
        [ -d "$d" ] || continue
        link "${d%/}" "$CLAUDE/skills/$(basename "$d")"
    done
else
    echo "  - no skills/ in brain -> skipped"
fi

# 2b) brain-owned commands, namespaced so it never clobbers user-level commands
[ -d "$BRAIN/commands" ] && link "$BRAIN/commands" "$CLAUDE/commands/brain"

# 3) per-project auto-memory. Claude Code keys per-project state by absolute path, so each
#    machine has a different key -- the link IS the per-machine mapping onto one shared dir.
if [ -n "$1" ]; then
    name="${2:-$(basename "$1")}"
    key="$(printf '%s' "$1" | sed 's/[:\\/]/-/g')"
    mem="$CLAUDE/projects/$key/memory"
    mkdir -p "$BRAIN/memory/$name"
    if [ -d "$mem" ] && [ ! -L "$mem" ]; then
        for f in "$mem"/*; do
            if [ -f "$f" ] && [ ! -e "$BRAIN/memory/$name/$(basename "$f")" ]; then
                cp "$f" "$BRAIN/memory/$name/"
                echo "  ~ migrated memory file: $(basename "$f")"
            fi
        done
    fi
    link "$BRAIN/memory/$name" "$mem"
fi
echo 'done.'
