---
description: Release ai-harness — bump the 3 manifests, write the CHANGELOG + README Latest entry, commit, then tag, push, publish the GitHub Release, and update the marketplace install
argument-hint: "[X.Y.Z] [--dry-run | --no-publish]"
---

# /release — ai-harness release

Arguments: `$ARGUMENTS`

Invoking `/release` (or the user saying 「배포 ㄱ」「배포 드가자」「푸시·릴리즈·마켓 업데이트까지」) is the go-ahead for the whole chain, push and GitHub Release included. `--dry-run` runs everything up to the commit and prints the publish commands without running them. `--no-publish` stops after the release commit.

The deterministic steps live in `.claude/scripts/release.sh` (`check` / `bump` / `publish`). Run the script for those steps; write only the prose (CHANGELOG entry, README Latest block) yourself.

## 1. Scope

1. Run `.claude/scripts/release.sh check`. It lists the commits since the last tag.
2. If the user named work to finish first (「1.35 이거 다 하고 1.35 배포」), finish and commit that work, then release it under the named number. Releasing the unfinished state under that number is the known failure here.
3. No commits since the last tag, or only docs/chore commits that CLAUDE.md exempts → report that no release is needed and stop.
4. `git status` shows uncommitted changes you did not make (another session, often the Codex `codex-harness` session sharing this tree) → leave them unstaged. If they touch `codex/` or a manifest, STOP and ask: the Claude and Codex versions move together, so a release made in the middle of the other session's work ships a half state.

## 2. Version

- The user gave `X.Y.Z` → use it.
- Otherwise, starting from the last tag: any `feat` commit (including `feat!`) → minor, only `fix` commits → patch.
- The Codex adapter takes the same number even when it has no change; the CHANGELOG entry says so.

Then run `.claude/scripts/release.sh bump X.Y.Z`.

## 3. Notes

Write the notes from `git log <last-tag>..HEAD` and the diffs, not from memory of the session.

- `CHANGELOG.md`: add `## vX.Y.Z — YYYY-MM-DD` on top (today's date). Start with a one-paragraph summary (the source of the changes, the plan path under `_docs/` if one exists, and the Codex adapter status). Follow it with `### Added` / `### Changed` / `### Fixed` / `### Removed`, keeping only the groups that have entries. Match the tone of the previous entries: what changed and the observed reason, with numbers when you have them.
- `README.md` → Changelog: rewrite the `**Latest: vX.Y.Z**` paragraph so it summarizes the new version.
- A skill, agent, or command whose summary changed → update its `description`, and the README row that describes it.

## 4. Verify and commit

1. `.claude/scripts/release.sh check X.Y.Z` must print zero FAIL lines. Fix what it reports and rerun it.
2. Stage only the files you changed by path: the 3 manifests, `CHANGELOG.md`, `README.md`, plus any description edits. Commit on `main` with `chore(release): bump plugin + marketplace to vX.Y.Z` and the attribution trailer.

`--no-publish` → stop here and report the commit hash.

## 5. Publish

Run `.claude/scripts/release.sh publish X.Y.Z` (add `--dry-run` when it was requested). The script re-runs the preflight, requires the release commit at HEAD, tags it (lightweight, as before), pushes `main` and the tag with the JunjaK token, creates the GitHub Release from the CHANGELOG entry, and updates the user-scope marketplace install. The active `gh` account stays untouched.

On failure, the script names the failed step. Rerun only that step. Force-pushing, deleting a pushed tag, or switching the global `gh` account are not allowed; for any of those, STOP and ask.

## 6. Report

Report the version, the release commit hash, the tag, the release URL (`https://github.com/JunjaK/ai-harness/releases/tag/vX.Y.Z`), and the marketplace update output. Keep these separate:
- **Done:** steps the script completed.
- **Not done:** project-scope installs in consumer projects (carbon and others). Each one updates in its own project after any run in progress there has finished.
- **Dry-run:** state plainly that nothing was pushed.
