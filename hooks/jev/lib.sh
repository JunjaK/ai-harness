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

# The primary working tree, so linked worktrees share one allowlist entry and one log.
jev_primary() {
  local common
  common=$(git -C "$JEV_PROJECT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) &&
    { dirname "$common"; return 0; }
  (cd "$JEV_PROJECT" 2>/dev/null && pwd -P) || printf '%s' "$JEV_PROJECT"
}

# jev_enabled <feature key> → 0 when jq and curl exist, the user listed this project (its primary tree)
# in ~/.config/typesafe/allowed-projects (one absolute path per line), and jev.json sets `.<key>.enabled`.
# jev.json is committed with the project, so on its own it must not switch sending on: a cloned repo
# would otherwise ship your transcript out on its say-so. The allowlist is the user's consent.
jev_enabled() {
  command -v jq >/dev/null 2>&1 || return 1
  command -v curl >/dev/null 2>&1 || return 1
  [ -f "$JEV_CONFIG" ] || return 1
  local allow="$HOME/.config/typesafe/allowed-projects" primary
  [ -r "$allow" ] || return 1
  primary=$(jev_primary)
  grep -vx '[[:space:]]*#.*' "$allow" 2>/dev/null | sed 's:/*[[:space:]]*$::' | grep -qxF "$primary" || return 1
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

# Masks common secret shapes in every string of the state before it leaves the machine: private key
# blocks, provider tokens (sk-, ghp_/gho_/github_pat_, AKIA, xox*-), JWTs, Bearer/Basic values,
# credentials in URLs, and values after password/secret/token/api_key-style names. Best effort:
# a secret in an unrecognised shape still goes out, which README states.
JEV_REDACT='walk(if type == "string" then
  gsub("-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----"; "[REDACTED PRIVATE KEY]")
  | gsub("\\b(sk|pk|rk)-[A-Za-z0-9_-]{16,}"; "[REDACTED]")
  | gsub("\\b(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,})"; "[REDACTED]")
  | gsub("\\beyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}"; "[REDACTED JWT]")
  | gsub("(?<k>(Bearer|Basic) )[A-Za-z0-9._~+/=-]{12,}"; "\(.k)[REDACTED]")
  | gsub("(?<k>://[^/\\s:@]+:)[^/\\s@]+@"; "\(.k)[REDACTED]@")
  | gsub("(?<k>(?i:password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|client[_-]?secret)[\"'"'"']?\\s*[:=]\\s*[\"'"'"']?)[^\\s\"'"'"',;[]{4,}"; "\(.k)[REDACTED]")
else . end)'

# jev_call <state JSON> <questions JSON> → response JSON on stdout; non-zero on any failure.
jev_call() {
  local key body resp
  key=$(jev_key) || return 1
  [ -n "$key" ] || return 1
  body=$(jq -cn --arg m "$(jev_conf .model jev-latest)" --argjson s "$1" --argjson q "$2" \
    "{model: \$m, state: (\$s | $JEV_REDACT), questions: \$q}") || return 1
  resp=$(printf '%s' "$body" | curl -sS --proto '=https' --max-time "$(jev_number .timeoutSeconds 5)" \
    -K <(printf 'header = "Authorization: Bearer %s"\n' "$key") -H 'Content-Type: application/json' \
    --data-binary @- --url "$JEV_ENDPOINT" 2>/dev/null) || return 1
  printf '%s' "$resp" | jq -e '.answers' >/dev/null 2>&1 || return 1
  printf '%s' "$resp"
}

# jev_log <check> <fields…> → one TSV line in the primary tree's .claude/session-state/jev.log,
# kept for threshold tuning (the model is never trained on this data; the log is the only feedback loop).
# Callers pass scores and labels only, never prompt, reply, or evidence text: the session id and
# timestamp locate the turn in the transcript when a line needs review.
jev_log() {
  local dir
  dir="$(jev_primary)/.claude/session-state"
  mkdir -p "$dir" 2>/dev/null || return 0
  local line
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ)	${CLAUDE_CODE_SESSION_ID:-?}"
  for f in "$@"; do line="$line	$(printf '%s' "$f" | tr '\n\t' '  ' | cut -c1-120)"; done
  printf '%s\n' "$line" >>"$dir/jev.log" 2>/dev/null
  return 0
}
