#!/bin/bash
# Shared TypeSafe Jev client for the harness's advisory test-side checks
# (stop-gate.sh, qa-crosscheck.sh). Source it; it defines functions only.
# Config: $CLAUDE_PROJECT_DIR/.claude/project-profile/jev.json — no file → every check is a no-op.
# Every failure (no key, no jq/curl, network, bad response) is fail-open: the caller skips.
# Inputs are sent to TypeSafe (fixed endpoint below); see README → "Jev checks".
# Compatible with bash 3.2 (macOS /bin/bash).

JEV_PROJECT=${CLAUDE_PROJECT_DIR:-$PWD}
JEV_CONFIG="$JEV_PROJECT/.claude/project-profile/jev.json"
JEV_ENDPOINT="https://api.typesafe.ai/v1/systemone"

# jev_enabled <feature key> → 0 when jq, curl, the config and `.<key>.enabled == true` are all present.
jev_enabled() {
  command -v jq >/dev/null 2>&1 || return 1
  command -v curl >/dev/null 2>&1 || return 1
  [ -f "$JEV_CONFIG" ] || return 1
  [ "$(jq -r --arg k "$1" '.[$k].enabled // false' "$JEV_CONFIG" 2>/dev/null)" = "true" ]
}

jev_conf() {  # jev_conf <jq path> <default>
  local v
  v=$(jq -r "$1 // empty" "$JEV_CONFIG" 2>/dev/null)
  printf '%s' "${v:-$2}"
}

# Key: only the fixed user file ~/.config/typesafe/api-key (a symlink is fine). jev.json is committed
# with the project and a project's .claude/settings.json can set env vars, so neither may choose the
# key, its location, or the endpoint: a cloned repo could otherwise read another file as the key,
# send the key and transcript to another host, or route your transcript into its own Jev account.
jev_key() {
  local f="$HOME/.config/typesafe/api-key"
  [ -r "$f" ] || return 1
  tr -d '[:space:]' <"$f"
}

jev_number() {  # jev_number <jq path> <default> → the config value when it is a plain number, else the default
  local v
  v=$(jev_conf "$1" "$2")
  case "$v" in '' | *[!0-9.]* | *.*.*) printf '%s' "$2" ;; *) printf '%s' "$v" ;; esac
}

# jev_call <state JSON> <questions JSON> → response JSON on stdout; non-zero on any failure.
jev_call() {
  local key body resp
  key=$(jev_key) || return 1
  [ -n "$key" ] || return 1
  body=$(jq -cn --arg m "$(jev_conf .model jev-latest)" --argjson s "$1" --argjson q "$2" \
    '{model: $m, state: $s, questions: $q}') || return 1
  # The key goes through a curl config on a file descriptor, not argv, so `ps` does not show it.
  resp=$(printf '%s' "$body" | curl -sS --proto '=https' --max-time "$(jev_number .timeoutSeconds 5)" \
    -K <(printf 'header = "Authorization: Bearer %s"\n' "$key") -H 'Content-Type: application/json' \
    --data-binary @- --url "$JEV_ENDPOINT" 2>/dev/null) || return 1
  printf '%s' "$resp" | jq -e '.answers' >/dev/null 2>&1 || return 1
  printf '%s' "$resp"
}

# jev_log <check> <fields…> → one TSV line in the primary tree's .claude/session-state/jev.log,
# kept for threshold tuning (the model is never trained on this data; the log is the only feedback loop).
jev_log() {
  local primary=$JEV_PROJECT common dir
  common=$(git -C "$JEV_PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && primary=$(dirname "$common")
  dir="$primary/.claude/session-state"
  mkdir -p "$dir" 2>/dev/null || return 0
  local line
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ)	${CLAUDE_CODE_SESSION_ID:-?}"
  for f in "$@"; do line="$line	$(printf '%s' "$f" | tr '\n\t' '  ' | cut -c1-300)"; done
  printf '%s\n' "$line" >>"$dir/jev.log" 2>/dev/null
  return 0
}
