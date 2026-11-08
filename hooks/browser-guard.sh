#!/bin/bash
# PreToolUse guard — ego lite is the only browser driver (skills/browser-e2e).
#   Bash:  deny running agent-browser or aside; for ego-browser, deny whole-profile clears and a named
#          taskSpace(...) without profileId (the default profile may be a real account).
#   MCP:   deny Playwright MCP tools (hooks.json matcher mcp__.*playwright.*). Committed .spec.ts runs go
#          through Bash and are untouched.
# Only the program position counts for agent-browser / aside: `grep agent-browser`, `echo "… aside …"` and
# commit messages pass. Quoted text is opaque except the script of `sh|bash|zsh [--opt…] -c '…'` and `eval '…'`.
# The ego checks (whole-profile clears, taskSpace without profileId) run whenever the text mentions
# ego-browser anywhere, so quoting the program does not skip them.
# Threat model, same as guardrails: this stops mistakes and tool drift, not deliberate evasion — a quoted or
# escaped program name, an alias, or a script passed as a file (`ego-browser nodejs < a.js`) is not seen.
# hooks.json sets onFailure: block. No jq → a Bash command that mentions a browser CLI is denied
# (cannot be checked); the MCP check needs no jq. Internal parse problems exit 0.

INPUT=$(cat)

deny() {
  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
    exit 0
  fi
  printf '%s\n' "$1" >&2
  exit 2
}

ROOT=${CLAUDE_PLUGIN_ROOT:-<plugin root>}
PROFILE_CMD="node \"$ROOT/skills/browser-e2e/scripts/qa-profile.mjs\""
INSTALL="Browser driving and testing use ego lite only (browser-e2e skill). If ego-browser is missing, install it from https://lite.ego.app/ and skip importing browser data during onboarding. QA profiles (harness-qa1, …) come from $PROFILE_CMD."

if command -v jq >/dev/null 2>&1; then
  TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
else
  TOOL=$(printf '%s' "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
fi

case "$TOOL" in
  mcp__*[Pp]laywright*)
    deny "Playwright MCP is not used. $INSTALL Committed Playwright .spec.ts suites still run through Bash."
    ;;
  Bash) ;;
  *) exit 0 ;;
esac

# Backslashes are dropped before matching names, so `a\gent-browser` is still seen.
PLAIN_INPUT=${INPUT//\\/}
case "$PLAIN_INPUT" in *agent-browser*|*aside*|*ego-browser*) ;; *) exit 0 ;; esac
if ! command -v jq >/dev/null 2>&1; then
  printf '%s' "$PLAIN_INPUT" | grep -Eq 'agent-browser|ego-browser|(^|[^A-Za-z0-9_-])aside([^A-Za-z0-9_-]|$)' || exit 0
  deny "This command mentions a browser CLI, and the browser-guard hook needs jq to check it. Install jq (brew install jq · apt install jq · winget install jqlang.jq) and run it again. $INSTALL"
fi
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -n "$CMD" ] || exit 0
PLAIN=${CMD//\\/}

# Prints "PROG <name>" for every segment whose program is one of the three, and "BADSPACE" when a
# taskSpace(...) call is neither a numeric resume nor given a profileId.
SCAN=$(printf '%s' "$CMD" | awk '
BEGIN { RS = "\001"; q = sprintf("%c", 39) }
function seps(t,   r) { r = t; gsub(/&&|\|\||[;|&(){}`]/, "\n", r); return r }
{
  s = $0; n = length(s); out = ""; i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == "\\") { out = out substr(s, i, 2); i += 2; continue }
    if (c == "\"" || c == q) {
      j = i + 1
      while (j <= n) {
        d = substr(s, j, 1)
        if (c == "\"" && d == "\\") { j += 2; continue }
        if (d == c) break
        j++
      }
      body = substr(s, i + 1, j - i - 1)
      if (out ~ /(^|[ \t\n])((ba|z|da|k)?sh([ \t]+-[-A-Za-z]+)*[ \t]+-[A-Za-z]*c|eval)[ \t]+$/) out = out "\n" seps(body) "\n"
      else out = out "Q"
      i = j + 1
      continue
    }
    if (index(";|&(){}`", c) > 0) c = "\n"
    out = out c
    i++
  }
  m = split(out, seg, "\n")
  for (k = 1; k <= m; k++) {
    line = seg[k]
    sub(/^[ \t]+/, "", line)
    while (line != "") {
      if (match(line, /^[A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+/)) { line = substr(line, RLENGTH + 1); continue }
      if (match(line, /^(sudo|env|command|builtin|exec|eval|xargs|nohup|time|nice|timeout|npx|bunx|pnpx)[ \t]+/)) { line = substr(line, RLENGTH + 1); continue }
      if (match(line, /^(pnpm[ \t]+(dlx|exec)|bun[ \t]+x|yarn[ \t]+dlx)[ \t]+/)) { line = substr(line, RLENGTH + 1); continue }
      if (match(line, /^(-[^ \t]+|[0-9.]+[smhd]?)[ \t]+/)) { line = substr(line, RLENGTH + 1); continue }
      break
    }
    split(line, w, /[ \t]+/)
    prog = w[1]
    gsub(/\\/, "", prog)
    sub(/.*\//, "", prog)
    if (prog == "agent-browser" || prog == "aside" || prog == "ego-browser") print "PROG " prog
  }
  t = s
  while (match(t, /taskSpace[ \t]*\([^)]*\)/)) {
    pre = (RSTART > 1) ? substr(t, RSTART - 1, 1) : ""
    whole = substr(t, RSTART, RLENGTH)
    p = index(whole, "(")
    call = substr(whole, p + 1, length(whole) - p - 1)
    t = substr(t, RSTART + RLENGTH)
    if (pre ~ /[A-Za-z0-9_.$]/) continue
    # a numeric resume, or an options object with a profileId key (`profileId:` or shorthand `{ profileId }`)
    if (call ~ /^[ \t\n]*[0-9]+[ \t\n]*$/ || call ~ /[{,][ \t\n]*profileId[ \t\n]*[:,}]/) continue
    print "BADSPACE"
    break
  }
}' 2>/dev/null) || exit 0

case "$SCAN" in
  *"PROG agent-browser"*) deny "agent-browser is not used. $INSTALL" ;;
  *"PROG aside"*) deny "aside is not used. $INSTALL" ;;
esac
case "$PLAIN" in *ego-browser*) ;; *) exit 0 ;; esac

case "$PLAIN" in
  *--clear-existing-profiles*)
    deny "Blocked: --clear-existing-profiles deletes every ego profile, including the user's real ones." ;;
esac
if printf '%s' "$PLAIN" | grep -Eq 'Network\.clearBrowserCookies|Network\.clearBrowserCache|Storage\.clearCookies'; then
  deny "Blocked: this CDP command clears cookies or cache for the whole profile. Clear one site with Storage.clearDataForOrigin (ego skill references/clearing-state.md)."
fi
case "$SCAN" in
  *BADSPACE*)
    deny "A new ego task space needs { profileId } — without it ego opens the default profile, which may be a real account. Open one on a free QA profile with $PROFILE_CMD --space-name <task> and use the printed number; resume an existing space by number, e.g. taskSpace(12) (browser-e2e skill)." ;;
esac
exit 0
