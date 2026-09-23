#!/bin/bash
# Claude entry point for the branch evaluator shared with the Codex adapter.
HERE=${BASH_SOURCE[0]%/*}
[ "$HERE" = "${BASH_SOURCE[0]}" ] && HERE=.
HERE=$(cd "$HERE" && pwd -P) || exit 2
exec "${BASH:-/bin/bash}" "$HERE/../codex/hooks/branch-evaluator.sh"
