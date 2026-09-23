#!/bin/bash
# Shared branch evaluator — Claude and Codex PreToolUse Bash payloads use the same fields.
# The Codex wrapper sets CLAUDE_PROJECT_DIR and converts ask to deny.
# Config: $CLAUDE_PROJECT_DIR/.claude/project-profile/guardrails.json
# No config file → no-op. Rules that do not depend on the current branch (forbidden
# commands such as a bare `pnpm test`) belong in Claude Code's own permissions.deny,
# which already splits compound commands; this hook adds only what those rules cannot
# see: which branch a write lands on.
# Design: _docs/complete/guardrails/2026-09-23-guardrails-spec.md (harness repo)
# Tests:  bash hooks/guardrails/tests/run.sh
# Compatible with bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile.

INPUT=$(cat)
WORD_RE='(^|[^A-Za-z0-9_-])(git|gh)([^A-Za-z0-9_-]|$)'
printf '%s' "$INPUT" | grep -Eq "$WORD_RE" || exit 0

PROJECT=${CLAUDE_PROJECT_DIR:-}
[ -n "$PROJECT" ] || exit 0
CONFIG="$PROJECT/.claude/project-profile/guardrails.json"
[ -f "$CONFIG" ] || exit 0

# Exit 2 blocks the tool call without needing jq to build JSON.
if ! command -v jq >/dev/null 2>&1; then
  echo "[guardrails] jq not found — git/gh commands are blocked while $CONFIG exists. Install jq (brew install jq | apt install jq | winget install jqlang.jq), or run the command yourself." >&2
  exit 2
fi

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // "default"')
[ -n "$CWD" ] || CWD=$PROJECT
printf '%s' "$CMD" | grep -Eq "$WORD_RE" || exit 0

TAB=$'\t'
FINAL=0
REASON=""

emit() {
  jq -cn --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

VALID='.version == 1
  and (.repos | type == "object")
  and ([.repos[] | (.branches // []) | type == "array"] | all)
  and ([.repos[] | (.branches // [])[] | (.pattern | type == "string")] | all)
  and ([.repos[] | (.branches // [])[] | (.commit, .push, .merge) | select(. != null)]
       | all(. == "allow" or . == "ask" or . == "deny"))'
if ! jq -e "$VALID" "$CONFIG" >/dev/null 2>&1; then
  emit deny "[guardrails] deny — $CONFIG is invalid (expected {\"version\": 1, \"repos\": {\"<path>\": {\"branches\": [{\"pattern\": \"<glob>\", \"commit|push|merge\": \"allow|ask|deny\"}]}}}). Fix the file, or ask the user to run the command."
fi

sev() { case "$1" in deny) echo 2 ;; ask) echo 1 ;; *) echo 0 ;; esac; }

# Keep the strictest decision seen so far and the reason that produced it.
record() {
  local s
  s=$(sev "$1")
  if [ "$s" -gt "$FINAL" ]; then FINAL=$s; REASON=$2; fi
}

# Strictest value of <action> over one repo's rows, or over every repo's rows.
strictest_repo() {
  jq -r --arg k "$1" --arg a "$2" \
    '[(.repos[$k].branches // [])[] | .[$a] // "allow"]
     | if any(. == "deny") then "deny" elif any(. == "ask") then "ask" else "allow" end' "$CONFIG"
}
strictest_all() {
  jq -r --arg a "$1" \
    '[.repos[] | (.branches // [])[] | .[$a] // "allow"]
     | if any(. == "deny") then "deny" elif any(. == "ask") then "ask" else "allow" end' "$CONFIG"
}

# Sets RV (strictest value among rows whose glob matches the branch) and RP (that row's pattern).
lookup() {
  local key=$1 action=$2 br=$3 pat val s best=0 rows
  RV=allow
  RP=""
  rows=$(jq -r --arg k "$key" --arg a "$action" \
    '(.repos[$k].branches // [])[] | [.pattern, (.[$a] // "allow")] | @tsv' "$CONFIG")
  while IFS="$TAB" read -r pat val; do
    [ -n "$pat" ] || continue
    # shellcheck disable=SC2053 # glob match is intended
    if [[ $br == $pat ]]; then
      s=$(sev "$val")
      if [ -z "$RP" ] || [ "$s" -gt "$best" ]; then best=$s; RV=$val; RP=$pat; fi
    fi
  done <<EOF
$rows
EOF
}

canon_dir() { (cd "$1" 2>/dev/null && pwd -P); }
common_of() {
  local c
  c=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  canon_dir "$c"
}
toplevel_of() {
  local t
  t=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
  canon_dir "$t"
}

# Map each configured repo key to its git common dir, so linked worktrees of a repo
# (e.g. /team-run Designer worktrees) resolve to the same key.
KEYMAP=""
while IFS= read -r k; do
  [ -n "$k" ] || continue
  c=$(common_of "$PROJECT/$k") || continue
  KEYMAP="$KEYMAP$c$TAB$k
"
done <<EOF
$(jq -r '.repos | keys[]' "$CONFIG")
EOF

key_of() {
  local c line
  c=$(common_of "$1") || return 1
  while IFS= read -r line; do
    case "$line" in "$c$TAB"*) printf '%s\n' "${line#*"$TAB"}"; return 0 ;; esac
  done <<EOF
$KEYMAP
EOF
  return 1
}

# Branch switches earlier in the same command, keyed by worktree top level.
OVR=""
set_override() { OVR="$OVR$1$TAB$2
"; }
get_override() {
  local line val="" found=1
  while IFS= read -r line; do
    case "$line" in "$1$TAB"*) val=${line#*"$TAB"}; found=0 ;; esac
  done <<EOF
$OVR
EOF
  [ $found -eq 0 ] && printf '%s\n' "$val"
  return $found
}

# judge <dir> <action> <branch or "" for the effective branch> <label>
judge() {
  local dir=$1 action=$2 br=$3 label=$4 key top v
  key=$(key_of "$dir") || return 0
  if [ -z "$br" ]; then
    top=$(toplevel_of "$dir")
    br=$(get_override "$top") || br=$(git -C "$dir" branch --show-current 2>/dev/null)
  fi
  if [ -z "$br" ] || [ "$br" = "__unknown__" ]; then
    v=$(strictest_repo "$key" "$action")
    [ "$v" = allow ] && return 0
    record "$v" "[guardrails] $v — $label in repo \"$key\": branch unknown (detached HEAD or unresolved switch), so the strictest $action rule applies."
    return 0
  fi
  lookup "$key" "$action" "$br"
  [ "$RV" = allow ] && return 0
  record "$RV" "[guardrails] $RV — $label → repo \"$key\" branch \"$br\" (pattern \"$RP\", $action=$RV)."
}

strict_all() {
  local v
  v=$(strictest_all "$1")
  [ "$v" = allow ] && return 0
  record "$v" "[guardrails] $v — $2: the target repository or branch cannot be resolved statically, so the strictest $1 rule applies."
}

# Quote-aware split on ; && || | & and newlines. Redirections (2>&1, &>) are not separators.
split_cmd() {
  local s=$1 n=${#1} i=0 c q="" cur="" nxt prv
  SEGS=()
  while [ $i -lt $n ]; do
    c=${s:i:1}
    if [ -n "$q" ]; then
      cur="$cur$c"
      if [ "$q" = '"' ] && [ "$c" = '\' ]; then cur="$cur${s:i+1:1}"; i=$((i + 2)); continue; fi
      [ "$c" = "$q" ] && q=""
      i=$((i + 1))
      continue
    fi
    nxt=${s:i+1:1}
    prv=${s:i-1:1}
    [ $i -eq 0 ] && prv=""
    case "$c" in
      "'" | '"') q=$c; cur="$cur$c" ;;
      '\') cur="$cur$c$nxt"; i=$((i + 2)); continue ;;
      ';' | $'\n') SEGS+=("$cur"); cur="" ;;
      '&')
        if [ "$prv" = '>' ] || [ "$prv" = '<' ] || [ "$nxt" = '>' ]; then
          cur="$cur$c"
        else
          SEGS+=("$cur"); cur=""
          [ "$nxt" = '&' ] && i=$((i + 1))
        fi
        ;;
      '|')
        SEGS+=("$cur"); cur=""
        if [ "$nxt" = '|' ] || [ "$nxt" = '&' ]; then i=$((i + 1)); fi
        ;;
      *) cur="$cur$c" ;;
    esac
    i=$((i + 1))
  done
  SEGS+=("$cur")
}

# Split one segment into words, removing quotes.
tokenize() {
  local s=$1 n=${#1} i=0 c q="" cur="" have=0
  TOK=()
  while [ $i -lt $n ]; do
    c=${s:i:1}
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then
        q=""
      elif [ "$q" = '"' ] && [ "$c" = '\' ]; then
        i=$((i + 1)); cur="$cur${s:i:1}"
      else
        cur="$cur$c"
      fi
      i=$((i + 1))
      continue
    fi
    case "$c" in
      "'" | '"') q=$c; have=1 ;;
      '\') i=$((i + 1)); cur="$cur${s:i:1}"; have=1 ;;
      ' ' | "$TAB") if [ $have -eq 1 ]; then TOK+=("$cur"); cur=""; have=0; fi ;;
      *) cur="$cur$c"; have=1 ;;
    esac
    i=$((i + 1))
  done
  [ $have -eq 1 ] && TOK+=("$cur")
}

# Remove quoted text: NOSQ drops single-quoted spans (their $(...) never runs);
# NOQ drops both kinds (parentheses inside any quotes are literal).
strip_quotes() {
  local s=$1 n=${#1} i=0 c q="" keep_dq=$2 out=""
  while [ $i -lt $n ]; do
    c=${s:i:1}
    if [ -n "$q" ]; then
      if [ "$c" = "$q" ]; then q=""
      elif [ "$q" = '"' ] && [ "$keep_dq" = 1 ]; then out="$out$c"
      fi
      i=$((i + 1))
      continue
    fi
    case "$c" in
      "'" | '"') q=$c; out="$out " ;;
      '\') i=$((i + 1)) ;;
      *) out="$out$c" ;;
    esac
    i=$((i + 1))
  done
  printf '%s' "$out"
}

COMMIT_RE='(^|[^A-Za-z0-9_-])(commit|merge|rebase|cherry-pick|revert|am|pull)([^A-Za-z0-9_-]|$)'
PUSH_RE='(^|[^A-Za-z0-9_-])push([^A-Za-z0-9_-]|$)'
has() { printf '%s' "$1" | grep -Eq "$2"; }
has_gh_merge() {
  has "$1" '(^|[^A-Za-z0-9_-])gh([^A-Za-z0-9_-]|$)' \
    && has "$1" '(^|[^A-Za-z0-9_-])pr([^A-Za-z0-9_-]|$)' \
    && has "$1" '(^|[^A-Za-z0-9_-])merge([^A-Za-z0-9_-]|$)'
}

# Nested or wrapped commands cannot be followed statically: if any write verb appears,
# apply the strictest rule for that action.
NOSQ=$(strip_quotes "$CMD" 1)
NOQ=$(strip_quotes "$CMD" 0)
NESTED=0
has "$NOSQ" '\$\(|`|<\(' && NESTED=1
has "$NOQ" '(^|[;&|[:space:]])(bash|sh|zsh|dash|ksh)[[:space:]]+-[A-Za-z]*c' && NESTED=1
has "$NOQ" '(^|[;&|[:space:]])(eval|xargs)([[:space:]]|$)' && NESTED=1
has "$NOQ" '(^|[;&|[:space:]])[({]' && NESTED=1
if [ $NESTED -eq 1 ]; then
  WHY='nested or wrapped command ($(...), backticks, sh -c, eval, xargs, or a subshell)'
  has "$NOSQ" "$COMMIT_RE" && strict_all commit "$WHY"
  has "$NOSQ" "$PUSH_RE" && strict_all push "$WHY"
  has_gh_merge "$NOSQ" && strict_all merge "$WHY"
fi

# gh pr view with a 5 s limit (macOS has no GNU timeout).
gh_base() {
  local dir=$1 sel=$2 repo=$3 tmp pid w base
  command -v gh >/dev/null 2>&1 || return 1
  tmp=$(mktemp 2>/dev/null) || return 1
  set -- pr view
  [ -n "$sel" ] && set -- "$@" "$sel"
  [ -n "$repo" ] && set -- "$@" -R "$repo"
  (cd "$dir" && exec gh "$@" --json baseRefName -q .baseRefName) >"$tmp" 2>/dev/null &
  pid=$!
  (sleep 5; kill "$pid" 2>/dev/null) >/dev/null 2>&1 &
  w=$!
  if wait "$pid"; then
    kill "$w" 2>/dev/null
    base=$(cat "$tmp")
    rm -f "$tmp"
    [ -n "$base" ] || return 1
    printf '%s\n' "$base"
    return 0
  fi
  kill "$w" 2>/dev/null
  rm -f "$tmp"
  return 1
}

do_switch() {  # $1 dir, then args after the subcommand
  local dir=$1 newb="" first="" dd=0 top
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --) dd=1 ;;
      -b | -B | -c | -C | --orphan) newb=${2:-__unknown__}; shift ;;
      -d | --detach) newb=__unknown__ ;;
      -*) ;;
      *) [ -z "$first" ] && first=$1 ;;
    esac
    shift
  done
  if [ -z "$newb" ]; then
    [ $dd -eq 1 ] && return 0
    if [ "$first" = "-" ]; then
      newb=__unknown__
    elif [ -n "$first" ] && git -C "$dir" show-ref --verify --quiet "refs/heads/$first"; then
      newb=$first
    else
      return 0
    fi
  fi
  top=$(toplevel_of "$dir") || return 0
  set_override "$top" "$newb"
}

do_push() {  # $1 dir, then args after the subcommand
  local dir=$1 remote_set=0 all=0 tags=0 r dst key v n
  local -a refs=()
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --all | --mirror) all=1 ;;
      --tags) tags=1 ;;
      -o | --push-option | --repo | --receive-pack | --exec) shift ;;
      -*) ;;
      *'>' | *'<') shift ;;
      *'>'* | *'<'*) ;;
      *)
        if [ $remote_set -eq 0 ]; then remote_set=1; else refs+=("$1"); fi
        ;;
    esac
    shift
  done
  if [ $all -eq 1 ]; then
    key=$(key_of "$dir") || return 0
    v=$(strictest_repo "$key" push)
    [ "$v" = allow ] || record "$v" "[guardrails] $v — git push --all/--mirror in repo \"$key\" pushes every branch, so the strictest push rule applies."
    return 0
  fi
  n=${#refs[@]}
  if [ "$n" -eq 0 ]; then
    [ $tags -eq 1 ] && return 0
    judge "$dir" push "" "git push"
    return 0
  fi
  for r in "${refs[@]}"; do
    r=${r#+}
    case "$r" in *:*) dst=${r#*:} ;; *) dst=$r ;; esac
    [ -n "$dst" ] || continue
    [ "$dst" = HEAD ] && dst=""
    dst=${dst#refs/heads/}
    case "$dst" in refs/*) continue ;; esac
    judge "$dir" push "$dst" "git push $r"
  done
}

handle_git() {  # args after the program name
  local dir=$LOC unresolved=0 sub nd
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        nd=${2:-}
        case "$nd" in *'$'* | '') unresolved=1 ;; /*) dir=$nd ;; *) dir="$dir/$nd" ;; esac
        shift 2
        continue
        ;;
      -c) shift 2; continue ;;
      --git-dir | --work-tree | --namespace) unresolved=1; shift 2; continue ;;
      --git-dir=* | --work-tree=*) unresolved=1 ;;
      -*) ;;
      *) break ;;
    esac
    shift
  done
  sub=${1:-}
  [ $# -gt 0 ] && shift
  if [ $unresolved -eq 0 ]; then
    nd=$(canon_dir "$dir") && dir=$nd || unresolved=1
  fi
  case "$sub" in
    checkout | switch)
      [ $unresolved -eq 0 ] && [ $LOC_KNOWN -eq 1 ] && do_switch "$dir" "$@"
      ;;
    commit | merge | rebase | cherry-pick | revert | am | pull)
      case " $* " in *" --abort "* | *" --quit "*) return 0 ;; esac
      if [ $unresolved -eq 1 ] || [ $LOC_KNOWN -eq 0 ]; then
        strict_all commit "git $sub"
      else
        judge "$dir" commit "" "git $sub"
      fi
      ;;
    push)
      if [ $unresolved -eq 1 ] || [ $LOC_KNOWN -eq 0 ]; then
        strict_all push "git push"
      else
        do_push "$dir" "$@"
      fi
      ;;
  esac
}

handle_gh() {  # args after the program name
  local repo="" base key v sel
  local -a words=()
  while [ $# -gt 0 ]; do
    case "$1" in
      -R | --repo) repo=${2:-}; shift ;;
      --repo=*) repo=${1#--repo=} ;;
      -t | --subject | -b | --body | -F | --body-file | -A | --author-email | --match-head-commit) shift ;;
      -*) ;;
      *) words+=("$1") ;;
    esac
    shift
  done
  [ "${words[0]:-}" = pr ] && [ "${words[1]:-}" = merge ] || return 0
  sel=${words[2]:-}
  if [ $LOC_KNOWN -eq 0 ]; then
    strict_all merge "gh pr merge"
    return 0
  fi
  if [ -n "$repo" ]; then
    strict_all merge "gh pr merge -R $repo (repository outside the configured paths)"
    return 0
  fi
  key=$(key_of "$LOC") || return 0
  if base=$(gh_base "$LOC" "$sel" ""); then
    judge "$LOC" merge "$base" "gh pr merge${sel:+ $sel}"
  else
    v=$(strictest_repo "$key" merge)
    [ "$v" = allow ] || record "$v" "[guardrails] $v — gh pr merge${sel:+ $sel} in repo \"$key\": could not read the PR's base branch within 5 s, so the strictest merge rule applies."
  fi
}

LOC=$(canon_dir "$CWD") || LOC=$CWD
LOC_KNOWN=1
split_cmd "$CMD"
for seg in "${SEGS[@]}"; do
  tokenize "$seg"
  [ ${#TOK[@]} -gt 0 ] || continue
  j=0
  while [ $j -lt ${#TOK[@]} ]; do
    case "${TOK[j]}" in
      [A-Za-z_]*=*) j=$((j + 1)) ;;
      command | exec | nohup | time | sudo | env) j=$((j + 1)) ;;
      *) break ;;
    esac
  done
  [ $j -lt ${#TOK[@]} ] || continue
  prog=${TOK[j]}
  case "${prog##*/}" in
    cd | pushd)
      arg=${TOK[j + 1]:-}
      case "$arg" in
        '' | - | *'$'*) LOC_KNOWN=0 ;;
        *)
          case "$arg" in '~') arg=$HOME ;; '~/'*) arg="$HOME/${arg#'~/'}" ;; esac
          case "$arg" in /*) nd=$arg ;; *) nd="$LOC/$arg" ;; esac
          if nd=$(canon_dir "$nd"); then LOC=$nd; else LOC_KNOWN=0; fi
          ;;
      esac
      ;;
    popd) LOC_KNOWN=0 ;;
    git) handle_git "${TOK[@]:j+1}" ;;
    gh) handle_gh "${TOK[@]:j+1}" ;;
  esac
done

case $FINAL in
  0) exit 0 ;;
  2) emit deny "$REASON Ask the user to run it, or change .claude/project-profile/guardrails.json." ;;
  *)
    case "$MODE" in
      bypassPermissions | dontAsk)
        emit deny "$REASON This needs human confirmation, but permission_mode=$MODE cannot show a prompt — ask the user to run it."
        ;;
      *) emit ask "$REASON" ;;
    esac
    ;;
esac
