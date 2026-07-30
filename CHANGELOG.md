# Changelog

All notable changes to the **AI Harness** plugin. Distributed via the `JunjaK/ai-harness` marketplace and **version-cached** — an unchanged version is a no-op even after a marketplace update.

Versions follow `MAJOR.MINOR.PATCH`: **minor** = new skill/agent/command/behavior, **patch** = fix. Pure docs/chore changes (this file, `CLAUDE.md`, `.claude/rules/`) ship without a bump.

## v1.21.0 — 2026-07-30

Graph-format orchestration (LangGraph *technique*, not runtime): persisted run-state + one normative escalation transition table, replacing four divergent copies of the same rules/graph.

### Added
- **Phase transition table** (`escalation.md`) — the ~20-row normative SSOT (guard / classification / target phase / counter effect / abort threshold) covering every escalation edge across all 5 phases + Phase 4.5, plus explicit counter-semantics rules (`retries.pN` vs `globalCycle` increment/reset behavior).
- **`.claude/session-state/team-run.json` read/write contract** (`team-workflow/SKILL.md` → "State Tracking") — persists `runId`/`phase`/`retries`/`globalCycle`/`escalations[]`/`designerAssignments[]` to disk so retry/abort caps are enforceable across compaction and session boundaries, not just held in orchestrator context. Read on every phase entry, written on every transition; a foreign `runId` still in flight STOPs and surfaces instead of silently overwriting (parallel-session safety).
- `pre-compact.sh` reminds the post-compaction session to re-read `team-run.json` (no new persistence logic — the file already survives compaction via the filesystem).
- `checkpoint` skill documents `team-run.json`'s placement (beside `checkpoints/`), orchestrator-only + primary-tree-only scope, and exemption from `session-stop.sh` rotation.

### Changed
- `team-workflow/SKILL.md`'s mermaid restructured so its node set is provably identical to `escalation.md`'s transition table (`START/P1/P2/GATE/P3/P4/P4.5/P5/DONE/ABORT`) — adds the previously-missing Phase 4.5 node and moves guards onto edge labels instead of separate decision/escalation nodes, so the visual and rules graphs can no longer silently drift apart.
- `team-designer.md` / `team-tester.md` / `team-leader.md` escalation sections now point at `escalation.md` instead of keeping local classification lists that had already drifted (8 vs 6 vs 5 differently-scoped "Fundamental Issue" enumerations across the three files).
- Escalation report format split into an **agent-emitted block** (Classification, Attempts, reason, files, root cause, tried approaches) and an **orchestrator-filled block** (Global cycle, cross-phase retries) — an agent cannot know orchestrator-level state, so it no longer reports it.
- `README.md`'s phase-flow ASCII block trimmed to a one-line phase index + links to the visual SSOT (`SKILL.md` mermaid) and rules SSOT (`escalation.md` table); Escalation bullets collapse to the same link.

### Removed
- `escalation.md`'s ASCII "Escalation Paths" path-tree — superseded by the transition table.
- Local "Simple Fix" / "Fundamental Issue" classification example-lists from `team-designer.md` and `team-tester.md`.
- `Global cycle` from what a Designer/Tester agent can report (moved to orchestrator-filled, read from `team-run.json`).

## v1.20.0 — 2026-07-30

### Changed
- **Test scope default flips to scoped-by-changes** (`verification-loop`, `team-tester`, `team-workflow`): Phase 4 test gates (baseline + final gate) now default to `vitest run --changed` / `playwright test --only-changed` instead of the full suite — on a large repo, running everything on every verification pass was the dominant CPU cost. The full suite runs only when the user explicitly asks for it in the current request ("run the full suite", "전체 테스트"); team-workflow's orchestrator wires the pre-task base ref into the Tester prompt so the scoped diff is computable, and omits the full-run line by default so Tester falls back to scoped.

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
