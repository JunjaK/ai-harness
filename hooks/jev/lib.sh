#!/bin/bash
# Shared TypeSafe Jev client for the harness's advisory test-side checks
# (stop-gate.sh, qa-crosscheck.sh). Source it; it defines functions only.
# Switches and key come from the plugin's userConfig (README → "Jev checks"). Both checks run only
# under mcp/jev_server.py, whose MCP `env` Claude Code fills from user or managed settings and the OS
# credential store. That env replaces anything a project's settings.json `env` sets. Command hooks
# are not used here: when an option is unset, a project's env can supply CLAUDE_PLUGIN_OPTION_* to
# them (seen in a live run), which would let a cloned repository switch a check on.
# Every failure (no key, no jq/curl, network, bad response) is fail-open: the caller skips.
# Inputs are sent to TypeSafe (fixed endpoint below).
# Compatible with bash 3.2 (macOS /bin/bash).

# Hooks get CLAUDE_PROJECT_DIR; fall back to the enclosing superproject, then the git top level,
# then the cwd, so a caller whose cwd drifted into a subfolder still finds the project.
JEV_PROJECT=${CLAUDE_PROJECT_DIR:-}
[ -n "$JEV_PROJECT" ] || JEV_PROJECT=$(git rev-parse --show-superproject-working-tree 2>/dev/null)
[ -n "$JEV_PROJECT" ] || JEV_PROJECT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$JEV_PROJECT" ] || JEV_PROJECT=$PWD
JEV_CONFIG="$JEV_PROJECT/.claude/project-profile/jev.json"
JEV_ENDPOINT="https://api.typesafe.ai/v1/systemone"
JEV_SKIP=""

# jev_enabled <userConfig switch> → 0 when the check may run; otherwise 1 with the reason in JEV_SKIP.
# Runs when the user turned the switch on and entered a key. A project can only opt out,
# with `"disabled": true` in its jev.json; a committed file never switches sending on.
jev_enabled() {
  local var
  var="CLAUDE_PLUGIN_OPTION_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  if [ "$(printenv "$var")" != "true" ]; then
    JEV_SKIP="$1 is off in the plugin settings (/plugin → junjak-ai-harness → Configure)"
    return 1
  fi
  if [ -z "${CLAUDE_PLUGIN_OPTION_JEV_API_KEY:-}" ]; then
    JEV_SKIP="no Jev API key in the plugin settings (/plugin → junjak-ai-harness → Configure)"
    return 1
  fi
  # The key is written into a curl config line; a quote or newline could add directives (another url).
  case "$CLAUDE_PLUGIN_OPTION_JEV_API_KEY" in
    *[!A-Za-z0-9._~+/=-]*)
      JEV_SKIP="the Jev API key has characters outside A-Z a-z 0-9 . _ ~ + / = -"
      return 1
      ;;
  esac
  if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    JEV_SKIP="jq or curl is missing"
    return 1
  fi
  if [ "$(jq -r '.disabled // false' "$JEV_CONFIG" 2>/dev/null)" = "true" ]; then
    JEV_SKIP="this project opted out (\"disabled\": true in .claude/project-profile/jev.json)"
    return 1
  fi
  return 0
}

jev_conf() {  # jev_conf <jq path> <default> — tuning values from the project's optional jev.json
  local v
  v=$(jq -r "$1 // empty" "$JEV_CONFIG" 2>/dev/null)
  printf '%s' "${v:-$2}"
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
  local body resp
  body=$(jq -cn --arg m "$(jev_conf .model jev-latest)" --argjson s "$1" --argjson q "$2" \
    "{model: \$m, state: (\$s | $JEV_REDACT), questions: \$q}") || return 1
  # The key goes through a curl config on a file descriptor, not argv, so `ps` does not show it.
  resp=$(printf '%s' "$body" | curl -sS --proto '=https' --max-time "$(jev_number .timeoutSeconds 5)" \
    -K <(printf 'header = "Authorization: Bearer %s"\n' "$CLAUDE_PLUGIN_OPTION_JEV_API_KEY") \
    -H 'Content-Type: application/json' --data-binary @- --url "$JEV_ENDPOINT" 2>/dev/null) || return 1
  printf '%s' "$resp" | jq -e '.answers' >/dev/null 2>&1 || return 1
  printf '%s' "$resp"
}

# jev_log <check> <fields…> → one TSV line in $CLAUDE_PLUGIN_DATA/jev.log (outside every project, so
# nothing lands in a repository's working tree), kept for threshold tuning: Jev never trains on your
# requests, so this log is the only feedback loop. Callers pass scores and labels only, never prompt,
# reply, or evidence text; the session id and time locate the turn when a line needs review.
jev_log() {
  [ -n "${CLAUDE_PLUGIN_DATA:-}" ] || return 0
  mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || return 0
  local line f
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ)	${CLAUDE_CODE_SESSION_ID:-?}	$JEV_PROJECT"
  for f in "$@"; do line="$line	$(printf '%s' "$f" | tr '\n\t' '  ' | cut -c1-120)"; done
  printf '%s\n' "$line" >>"$CLAUDE_PLUGIN_DATA/jev.log" 2>/dev/null
  return 0
}
