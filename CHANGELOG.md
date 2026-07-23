# Changelog

All notable changes to the **AI Harness** plugin. Distributed via the `JunjaK/ai-harness` marketplace and **version-cached** — an unchanged version is a no-op even after a marketplace update.

Versions follow `MAJOR.MINOR.PATCH`: **minor** = new skill/agent/command/behavior, **patch** = fix. Pure docs/chore changes (this file, `CLAUDE.md`, `.claude/rules/`) ship without a bump.

## v1.19.0 — 2026-07-23

### Added — Operational Discipline (from cross-machine usage insights)
- **Windows shell fallback** (`CLAUDE.md`): when `Bash` fails repeatedly from a broken Git-for-Windows bash, switch to the PowerShell tool instead of retrying the same shell; never probe for a CLI with a call that spawns its GUI (e.g. a non-headless `soffice`).
- **Server / background-process vacuity guard** (`verification-loop`): a "running" claim must re-verify the process/port is alive **at claim time** (`curl` / `lsof` / `ps`) — a start command's exit-0 or "listening on :PORT" output is not proof it stayed up.
- **Parallel-session commit safety** (`CLAUDE.md`): parallel sessions share the working tree — commit only what you changed and never revert another session's uncommitted work (no blanket `git add -A` / `reset --hard` / `clean`); committing another session's work is allowed only on explicit request.
- **Destruction scope** (`CLAUDE.md`): destructive ops act only on the exact target the user requested — never a whole datadir, system/shared DBs, or unrelated state when only specific data was asked.

## v1.18.0 — 2026-07-21

### Added
- **`/meta-prompt`** — compile a raw context dump into an optimized, self-contained prompt to inject into a fresh session, `/team-run` string, subagent, or another tool. Borrows `brainstorm`'s questioning discipline; output is a portable prompt, not a design doc.
- **`/worktree-deps`** — provision a fresh worktree's dependencies via the package manager's shared cache (no re-download, parallel-safe). Two families: **A** copy-based (`node_modules` → shared-store hard-link + same-filesystem check) and **B** reference-cache (Dart pub / Gradle / Go / Cargo → native resolve, nothing copied); pnpm/bun handled inline, other managers resolved via Context7; `node_modules` symlinking excluded. Verified on a real Flutter + Spring monorepo (`fvm flutter pub get` = 7s / +68K / 0 copied).

### Changed
- `parallelization`, `submodule-worktree`, and `project-analyzer` document the worktree deps fast-path; the profile records it per code submodule.

## v1.16.0 — 2026-07-21

### Removed
- Deleted superpowers-duplicated fork skills the harness delegates instead of forking: `dispatching-parallel-agents`, `requesting-code-review`, `subagent-orchestration`, `systematic-debugging`. Removed multilingual READMEs (`README.ja.md`, `README.ko.md`).

### Changed
- Relocated agent-only resources (uiux, web-reviewer) under `skills/team-workflow/resources/`.

---

_For versions before v1.16.0, see the git history (`git log`)._
