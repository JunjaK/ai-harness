#!/bin/bash
# Claude entry point for the branch evaluator shared with the Codex adapter.
# It also leaves evidence of rare hook timeouts (a timed-out hook lets the command run):
# - a check that takes 3 s or longer is appended to .claude/session-state/guardrails-slow.log
#   (primary tree, gitignored runtime state) with elapsed time, exit code, index.lock, load;
# - a check the hook timeout kills never reaches that line, so every check first writes a marker
#   under guardrails-inflight/ and removes it when done; the next check moves markers older than
#   a minute into the same log as "unfinished".
HERE=${BASH_SOURCE[0]%/*}
[ "$HERE" = "${BASH_SOURCE[0]}" ] && HERE=.
HERE=$(cd "$HERE" && pwd -P) || exit 2
EVALUATOR="$HERE/../codex/hooks/branch-evaluator.sh"

INPUT=$(cat)

# Same no-op conditions as the evaluator; skip the bookkeeping for them.
case "$INPUT" in *git*|*gh*) ;; *) exit 0 ;; esac
PROJECT=${CLAUDE_PROJECT_DIR:-}
{ [ -n "$PROJECT" ] && [ -f "$PROJECT/.claude/project-profile/guardrails.json" ]; } || exit 0

PRIMARY=$PROJECT
COMMON=$(git -C "$PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && PRIMARY=$(dirname "$COMMON")
STATE="$PRIMARY/.claude/session-state"
INFLIGHT="$STATE/guardrails-inflight"
LOG="$STATE/guardrails-slow.log"
mkdir -p "$INFLIGHT" 2>/dev/null

# Parse command and cwd only when a line is actually written (keeps fast checks cheap).
describe() {  # $1 raw hook input → "<cwd>\t<command, one line, 200 chars>"
  local cmd cwd
  if command -v jq >/dev/null 2>&1; then
    cmd=$(printf '%s' "$1" | jq -r '.tool_input.command // empty' 2>/dev/null)
    cwd=$(printf '%s' "$1" | jq -r '.cwd // empty' 2>/dev/null)
  else
    cmd=$1
  fi
  printf '%s\t%s' "${cwd:-$PROJECT}" "$(printf '%s' "$cmd" | tr '\n\t' '  ' | cut -c1-200)"
}

find "$INFLIGHT" -type f -mmin +1 2>/dev/null | while IFS= read -r m; do
  { IFS= read -r started; IFS= read -r sid; IFS= read -r raw; } <"$m"
  printf 'unfinished\t%s\t%s\t%s\n' "$started" "$sid" "$(describe "$raw")" >>"$LOG"
  rm -f "$m"
done

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
MARK="$INFLIGHT/$$"
printf '%s\n%s\n%s\n' "$NOW" "${CLAUDE_CODE_SESSION_ID:-?}" "$(printf '%s' "$INPUT" | tr '\n' ' ')" >"$MARK" 2>/dev/null

START=$SECONDS
OUT=$(printf '%s' "$INPUT" | "${BASH:-/bin/bash}" "$EVALUATOR")
CODE=$?
ELAPSED=$((SECONDS - START))
rm -f "$MARK"

if [ "$ELAPSED" -ge 3 ]; then
  DESC=$(describe "$INPUT")
  LOCK=no
  GITDIR=$(git -C "${DESC%%	*}" rev-parse --path-format=absolute --git-dir 2>/dev/null) && [ -e "$GITDIR/index.lock" ] && LOCK=yes
  LOAD=$(uptime 2>/dev/null | sed 's/.*load averages*: *//')
  printf 'slow\t%s\t%ss\texit=%s\t%s\tindex.lock=%s\tload=%s\t%s\n' \
    "$NOW" "$ELAPSED" "$CODE" "${CLAUDE_CODE_SESSION_ID:-?}" "$LOCK" "$LOAD" "$DESC" >>"$LOG"
fi

[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit "$CODE"
