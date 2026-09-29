#!/bin/bash
# ai-harness release helper — the deterministic half of /release.
# The model writes CHANGELOG / README prose; this script owns versions, checks, tag, push, GitHub Release.
#
#   release.sh check   [X.Y.Z]            read-only preflight (exit 1 on any FAIL)
#   release.sh bump    X.Y.Z              set version in the 3 manifests
#   release.sh publish X.Y.Z [--dry-run]  tag + push + gh release + marketplace update
set -u

OWNER=JunjaK
REPO=JunjaK/ai-harness
MANIFESTS=(.claude-plugin/plugin.json .claude-plugin/marketplace.json codex/.codex-plugin/plugin.json)

ROOT=$(git rev-parse --show-toplevel) || exit 1
cd "$ROOT" || exit 1

FAILS=0
ok()   { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAILS=$((FAILS + 1)); }
die()  { printf 'error: %s\n' "$1" >&2; exit 1; }

valid_ver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
manifest_ver() { sed -n 's/^ *"version": "\([0-9.]*\)",*$/\1/p' "$1" | head -1; }
last_tag() { git tag --list 'v*' --sort=-v:refname | head -1; }
owner_token() { gh auth token --user "$OWNER" 2>/dev/null; }

changelog_entry() {  # body of "## vX.Y.Z — …" without its heading, up to the next "## v"
  awk -v h="## v$1 " 'index($0, h) == 1 { on = 1; next } on && /^## v/ { exit } on { print }' CHANGELOG.md
}

cmd_check() {
  local want=${1:-} v first cur tok perm
  echo "preflight ($ROOT)"

  [ "$(git branch --show-current)" = main ] && ok "branch main" || fail "branch is not main"

  cur=$(manifest_ver "${MANIFESTS[0]}")
  for f in "${MANIFESTS[@]}"; do
    v=$(manifest_ver "$f")
    [ "$v" = "$cur" ] && ok "$f = $v" || fail "$f = ${v:-?} (expected $cur)"
  done
  if [ -n "$want" ]; then
    [ "$cur" = "$want" ] && ok "manifests at $want" || fail "manifests at $cur, not $want"
  fi
  want=${want:-$cur}

  first=$(grep -m1 '^## v' CHANGELOG.md)
  case "$first" in
    "## v$want — "*) ok "CHANGELOG top entry: $first" ;;
    *) fail "CHANGELOG top entry is '$first', expected '## v$want — YYYY-MM-DD'" ;;
  esac
  [ -n "$(changelog_entry "$want" | tr -d '[:space:]')" ] && ok "CHANGELOG v$want has a body" || fail "CHANGELOG v$want body is empty"
  grep -q "\*\*Latest: v$want\*\*" README.md && ok "README Latest: v$want" || fail "README has no '**Latest: v$want**'"

  if git rev-parse -q --verify "refs/tags/v$want" >/dev/null; then
    [ "$(git rev-parse "v$want^{commit}")" = "$(git rev-parse HEAD)" ] \
      && ok "tag v$want already at HEAD" || fail "tag v$want exists on another commit"
  else
    ok "tag v$want is free"
  fi

  tok=$(owner_token)
  if [ -z "$tok" ]; then
    fail "no gh token for $OWNER (gh auth login --user $OWNER)"
  else
    perm=$(GH_TOKEN=$tok gh api "repos/$REPO" --jq '.permissions.push' 2>/dev/null)
    [ "$perm" = true ] && ok "$OWNER can push to $REPO" || fail "$OWNER has no push permission on $REPO"
  fi

  echo "unreleased commits since $(last_tag):"
  git log --pretty='    %h %s' "$(last_tag)..HEAD"
  [ -z "$(git status --porcelain)" ] || echo "  note: working tree has uncommitted changes (may belong to another session — do not stage them)"

  [ "$FAILS" -eq 0 ] || { echo "$FAILS check(s) failed"; return 1; }
}

cmd_bump() {
  local new=${1:-} f
  valid_ver "$new" || die "usage: release.sh bump X.Y.Z"
  for f in "${MANIFESTS[@]}"; do
    # each manifest carries exactly one "version" key
    sed -i.bak -E "s/\"version\": \"[0-9]+\.[0-9]+\.[0-9]+\"/\"version\": \"$new\"/" "$f"
    rm -f "$f.bak"
    echo "  $f -> $(manifest_ver "$f")"
  done
}

cmd_publish() {
  local ver=${1:-} dry=${2:-} run notes tok subject
  valid_ver "$ver" || die "usage: release.sh publish X.Y.Z [--dry-run]"
  run() { if [ "$dry" = --dry-run ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi; }
  # the token never enters argv or dry-run output: the credential helper and GH_TOKEN fetch it at call time
  run_gh() { if [ "$dry" = --dry-run ]; then printf '  [dry-run] GH_TOKEN=<%s> gh %s\n' "$OWNER" "$*"; else GH_TOKEN="$tok" gh "$@"; fi; }

  cmd_check "$ver" || die "preflight failed — nothing was pushed"
  subject=$(git log -1 --pretty=%s)
  [ "$subject" = "chore(release): bump plugin + marketplace to v$ver" ] \
    || die "HEAD is '$subject' — the release commit must be HEAD"

  tok=$(owner_token)
  notes=$(mktemp "${TMPDIR:-/tmp}/harness-release-notes.XXXXXX")
  changelog_entry "$ver" | sed '/./,$!d' > "$notes"

  git rev-parse -q --verify "refs/tags/v$ver" >/dev/null || run git tag "v$ver"
  run git -c credential.helper= \
    -c "credential.helper=!f() { test \"\$1\" = get || exit 0; echo username=$OWNER; echo \"password=\$(gh auth token --user $OWNER)\"; }; f" \
    push origin main "v$ver" || die "push failed"
  run_gh release create "v$ver" -R "$REPO" --title "v$ver" --notes-file "$notes" --verify-tag \
    || die "gh release failed (tag is pushed; rerun this step only)"
  run claude plugin marketplace update ai-harness || die "marketplace update failed"
  run claude plugin update junjak-ai-harness@ai-harness || die "plugin update failed"
  rm -f "$notes"
  if [ "$dry" = --dry-run ]; then echo "dry-run only — nothing was tagged, pushed, or released"
  else echo "released v$ver (user scope updated; project-scope installs update per project)"; fi
}

case "${1:-}" in
  check)   shift; cmd_check "$@" ;;
  bump)    shift; cmd_bump "$@" ;;
  publish) shift; cmd_publish "$@" ;;
  *) die "usage: release.sh {check [X.Y.Z] | bump X.Y.Z | publish X.Y.Z [--dry-run]}" ;;
esac
