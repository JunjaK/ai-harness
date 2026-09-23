#!/bin/bash
# Table-driven tests for hooks/guardrails.sh and the guardrails notice in
# hooks/session-start.sh. Builds throwaway repos under a temp dir; needs git and jq.
# Run: bash hooks/guardrails/tests/run.sh   (exit 1 when any case fails)

HERE=$(cd "$(dirname "$0")" && pwd -P)
ROOT=$(cd "$HERE/../../.." && pwd -P)
HOOK="$ROOT/hooks/guardrails.sh"
START="$ROOT/hooks/session-start.sh"
PRESETS="$ROOT/hooks/guardrails/presets"
BASH_BIN=${BASH:-bash}

T=$(mktemp -d)
T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
PROJ="$T/proj"
WT="$T/wt"
BIN="$T/bin"
NOJQ="$T/nojq"
CFG="$PROJ/.claude/project-profile/guardrails.json"

G() { git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@" >/dev/null 2>&1; }

# Fixture: root repo (main, feature, stage, dev), inner repo be/ (main, stage), one linked worktree.
mkdir -p "$PROJ/.claude/project-profile" "$BIN" "$NOJQ"
G init -q "$PROJ"
G -C "$PROJ" commit -q --allow-empty -m init
for b in feature stage dev; do G -C "$PROJ" branch "$b"; done
G init -q "$PROJ/be"
G -C "$PROJ/be" commit -q --allow-empty -m init
G -C "$PROJ/be" checkout -q -b stage
G -C "$PROJ" worktree add -q "$WT" -b wt-feature

cat >"$BIN/gh" <<'EOF'
#!/bin/bash
case "${GH_FAKE:-main}" in
  main) echo main ;;
  fail) exit 1 ;;
  slow) sleep 6; echo main ;;
esac
EOF
chmod +x "$BIN/gh"
for t in cat grep git; do ln -s "$(command -v "$t")" "$NOJQ/$t"; done

use_default() {
  jq '.repos.be = {branches: [{pattern: "main", merge: "deny"}, {pattern: "stage", commit: "ask", push: "ask"}]}' \
    "$PRESETS/default.json" >"$CFG"
}
on() { G -C "$PROJ" checkout -q "$1"; }

PASS=0
FAIL=0

# hook <cwd> <permission_mode> <command> [PATH] → OUT, CODE, DEC
hook() {
  local json
  json=$(jq -cn --arg c "$3" --arg d "$1" --arg m "$2" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d, permission_mode: $m}')
  OUT=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$PROJ" PATH="${4:-$BIN:$PATH}" GH_FAKE="${GH_FAKE:-main}" \
    "$BASH_BIN" "$HOOK" 2>"$T/err")
  CODE=$?
  DEC=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  [ -n "$DEC" ] || DEC=none
  WHY="$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)$(cat "$T/err")"
}

# check <name> <none|ask|deny|exit2> [reason substring]
check() {
  local got=$DEC
  [ "$CODE" -eq 2 ] && got=exit2
  if [ "$got" = "$2" ] && { [ -z "${3:-}" ] || printf '%s' "$WHY" | grep -qF -- "$3"; }; then
    PASS=$((PASS + 1)); echo "ok   $1"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $1 — expected $2${3:+ with \"$3\"}, got $got (exit $CODE)"
    [ -n "$OUT" ] && echo "     out: $OUT"
    [ -s "$T/err" ] && echo "     err: $(cat "$T/err")"
  fi
}

use_default
on main;    hook "$PROJ" default 'git commit -m x';                        check "c01 commit on main" deny 'branch "main"'
on feature; hook "$PROJ" default 'git commit -m x';                        check "c02 commit on a feature branch" none
            hook "$PROJ" default 'cd be && git commit -m x';               check "c03 cd be && commit on be:stage" ask 'repo "be"'
            hook "$PROJ" default 'git -C be push origin HEAD:stage';       check "c04 git -C be push HEAD:stage" ask
            hook "$PROJ" default 'git checkout main && git commit -m x';   check "c05 switch to main inside the chain" deny
            hook "$PROJ" default 'git push origin +feature:main';          check "c06 forced refspec to main" deny
            hook "$PROJ" default 'git push --tags';                        check "c07 tags only" none
            hook "$PROJ" default 'git push origin --all';                  check "c08 push --all" deny '--all'
            hook "$PROJ" default 'echo $(git push)';                       check "c09 command substitution" deny 'nested'
            hook "$PROJ" default 'bash -c "git push"';                     check "c10 bash -c wrapper" deny 'nested'
            hook "$PROJ" default 'cd "$DIR" && git commit -m x';           check "c11 cd to a variable" deny 'cannot be resolved'
GH_FAKE=main hook "$PROJ" default 'gh pr merge 12';                         check "c12 gh pr merge, base main" deny 'branch "main"'
GH_FAKE=fail hook "$PROJ" default 'gh pr merge 12';                         check "c13 gh base lookup fails" deny 'within 5 s'
S=$(date +%s)
GH_FAKE=slow hook "$PROJ" default 'gh pr merge 12'
E=$(( $(date +%s) - S ))
check "c14 gh base lookup times out" deny 'within 5 s'
if [ "$E" -le 8 ]; then PASS=$((PASS + 1)); echo "ok   c14b timeout returned in ${E}s"; else FAIL=$((FAIL + 1)); echo "FAIL c14b timeout took ${E}s (> 8s)"; fi
            hook "$PROJ" bypassPermissions 'cd be && git commit -m x';     check "c15 ask escalates under bypassPermissions" deny 'permission_mode=bypassPermissions'
            hook "$PROJ" dontAsk 'cd be && git commit -m x';               check "c16 ask escalates under dontAsk" deny 'permission_mode=dontAsk'
            hook "$WT" default 'git switch main && git commit -m x';       check "c17 worktree switches to main" deny 'repo "."'
            hook "$WT" default 'git commit -m x';                          check "c18 worktree feature commit" none
G -C "$PROJ/be" checkout -q --detach
            hook "$PROJ" default 'git -C be commit -m x';                  check "c19 detached HEAD" ask 'branch unknown'
G -C "$PROJ/be" checkout -q stage
printf '%s' '{"version":1,"repos":{".":{"branches":[{"pattern":"*","commit":"allow"},{"pattern":"main","commit":"deny"}]}}}' >"$CFG"
on main;    hook "$PROJ" default 'git commit -m x';                        check "c20 overlapping patterns take the strictest" deny 'pattern "main"'
use_default
            hook "$PROJ" default 'git merge --abort';                      check "c21 merge --abort" none
            hook "$PROJ" default 'git status && git log --oneline -3';     check "c22 read-only chain" none
            hook "$PROJ" default 'GIT_AUTHOR_NAME=x git commit -m y';      check "c23 env assignment prefix" deny
            hook "$PROJ" default 'git -c core.editor=true commit -m y';    check "c24 git -c option" deny
            hook "$PROJ" default 'git push 2>&1 | tail -1';                check "c25 redirection is not a separator" deny
            hook "$PROJ" default 'ls -la';                                 check "c26 non-git command" none
on feature; hook "$PROJ" default 'git commit -m "fix && git push origin main"'; check "c27 separators inside quotes" none
            hook "$PROJ" default 'git commit -m "(fix) a"';                check "c28 parentheses inside quotes" none
cp "$PRESETS/light.json" "$CFG"
on main;    hook "$PROJ" default 'git commit -m x';                        check "c29 light preset asks" ask
printf '%s' '{"version":2,"repos":{}}' >"$CFG"
on feature; hook "$PROJ" default 'git commit -m x';                        check "c30 invalid config" deny 'invalid'
use_default
            hook "$PROJ" default 'git commit -m x' "$NOJQ";                check "c31 jq missing" exit2 'jq not found'
rm -f "$CFG"
on main;    hook "$PROJ" default 'git commit -m x';                        check "c32 no config" none

# session-start.sh notice
notice() {  # <project dir> <yes|no> <name>
  local out
  out=$(cd "$1" && CLAUDE_PROJECT_DIR="$1" CLAUDE_PLUGIN_ROOT="$ROOT" "$BASH_BIN" "$START" 2>/dev/null)
  if printf '%s' "$out" | grep -qF '[guardrails]'; then got=yes; else got=no; fi
  if [ "$got" = "$2" ]; then PASS=$((PASS + 1)); echo "ok   $3"; else FAIL=$((FAIL + 1)); echo "FAIL $3 — expected notice=$2, got $got"; fi
}
notice "$PROJ" yes "s01 profile without guardrails.json shows the notice"
cp "$PRESETS/toy.json" "$CFG"
notice "$PROJ" no "s02 toy preset silences the notice"
mkdir -p "$T/plain"
notice "$T/plain" no "s03 project without a profile stays silent"

echo "---"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
