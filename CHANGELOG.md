# Changelog

All notable changes to the **AI Harness** plugin. Distributed via the `JunjaK/ai-harness` marketplace and **version-cached** — an unchanged version is a no-op even after a marketplace update.

Versions follow `MAJOR.MINOR.PATCH`: **minor** = new skill/agent/command/behavior, **patch** = fix. Pure docs/chore changes (this file, `CLAUDE.md`, `.claude/rules/`) ship without a bump.

## v1.24.0 — 2026-07-30

App UI work had no stated verification surface, so "looks right in the code" could pass as done — and nothing recorded that half of it is impossible to check on a Windows host.

### Added
- **Mobile verification runs on a booted simulator/emulator, with an explicit host-OS gate.** App UI changes are verified on a real device surface, never by inspection: boot/select the device explicitly through the project's version pin (`flutter devices` → `fvm flutter run -d <id>` where `.fvmrc` exists), and name the device in the report.
  - **macOS** — iOS Simulator (Xcode) **and** Android Emulator.
  - **Windows / Linux** — Android Emulator only; the iOS Simulator requires Xcode, which is macOS-only.
  - On Windows an iOS result is therefore **structurally unverifiable**: report it as `미검증 (iOS: host cannot run the simulator)` and leave it for the macOS machine. MUST NOT infer iOS behavior from a green Android run — permissions, safe-area/notch insets, keyboard behavior, deep links, sign-in providers, file pickers, and push are exactly where that inference breaks.
  - No device bootable → `driver unavailable` and stop; falling back to static reasoning and calling it verified is the failure this gate prevents.
  - Wired into the surfaces that ship: `agentic-testing` (Phase 4.5 mobile adapter row + a dedicated section), `team-tester` (Phase 4), and `/debug` Phase 4.
- **`testing.md` gained device rows** — iOS simulator / Android AVD targets, the launch command and its version pin, and the host-OS gate — so each app project records its own device targets at `/team-init` time.

## v1.23.0 — 2026-07-30

A `/doctor` audit of 345 session transcripts found three things this harness asserted that the data does not support: `TeamCreate` was **never called once** while `team-workflow` ran 25 times; six "skills" were cited 60 times without a single dispatch; and `agent-browser` was used only when explicitly named while every other browser task drifted to Playwright MCP or `claude-in-chrome`. All three were caused by this repo's own text, and all three are now aligned with what actually runs.

### Removed
- **The `TeamCreate` / `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` dependency, entirely.** `CLAUDE.md`'s "Required: Agent Teams" section, the README's "required" note and its env-block entry, and the flag line the greenfield scaffolder wrote into every new project's `settings.json` are gone. The flag was never set on the audited machine and the tool never fired, yet `/team-run` shipped 18 runs — the commands have always orchestrated through `Agent()`. Documenting a dependency that never existed made every one of those runs a silent fallback.
- **Six skills demoted to `reference/*.md` documents** — `coding-standards`, `tdd-workflow`, `e2e-testing`, `verification-loop`, `plan-review`, `token-optimization`. Skill count 27 → 21. Not one had ever been dispatched, and every reference was a §-citation ("(`coding-standards` §4)"), never an invocation — ~48,000 chars of body authored and never loaded. They now cost nothing in the always-resident skill listing while staying readable by path.

### Changed
- **Phase 1 cross-review is two parallel objection passes.** Each architect receives the counterpart plan and returns *only* contract mismatches, ordering conflicts, and broken assumptions — no rewrites. The Leader mediates and records any unconceded conflict with its reason. Under ultracode the two passes run as a second `parallel()` barrier before synthesis (the judge-panel pattern). Applies to `/team`, `/team-brainstorm`, and `greenfield-bootstrap` G2.
- **`agent-browser` is the default browser driver, and the precedence lives on a surface that ships.** `agent-browser-e2e` previously described itself as "on-demand, NOT wired into Phase 4/4.5", so an agent reading it correctly concluded "only when asked" — and the fallback row named only Playwright, leaving `claude-in-chrome` unranked anywhere, which is how browser work leaked into it. The rule now rides the skill's own **description** (resident in every project where the plugin is enabled) rather than the harness `CLAUDE.md`, which is never injected into consumer projects: this skill FIRST → Playwright MCP only when its gate fails, stating which condition → `claude-in-chrome` only for the user's own logged-in Chrome profile. It is phase-wired for Phase 4 driving and Phase 4.5 exploration. `agentic-testing`, `team-tester`, `team-agentic-tester`, `scenario-to-e2e`, and `reference/e2e-testing.md` follow the same order.
- **The driver/framework boundary is preserved and stated**: agent-browser drives; Playwright permanently owns the committed `.spec.ts` regression suite, so a flow that must regress forever still crystallizes to a Playwright spec regardless of what explored it.
- **`/debug` Phase 4 spells out its gate inline** instead of naming two skills nobody loaded: failing test watched to fail first, one root-cause fix at the shared caller, verification by running the authoritative commands, `됐다 / 됐는데 미검증 / 안 됨` reported distinctly, DB-level persistence checked where data is touched.
- **`unknown` is a last resort, not the remedy for `any`.** `.claude/rules/typescript.md` prescribed `unknown` + narrowing while the global ruleset banned `unknown` outright — opposite instructions loading together on every `.ts` read. Both now say: `any` prohibited; `unknown` only where the model is outside your control (third-party library types, external API shapes) with no concrete type, narrowed at the boundary.
- **CLAUDE.md Rule Routing gained a reference-document row** stating those six names resolve to `reference/<name>.md` and MUST NOT be passed to the Skill tool. The `Authoritative Documentation` section was compressed; net file size is unchanged from before this release.

### Added
- **Fixtures precondition for unattended E2E.** Before the first browser action of any run a human is not driving (Phase 4, Phase 4.5, `/team-run`, scheduled/looped): the dedicated E2E account and its test data MUST already exist, provisioned through the project's own **idempotent** seed path against a **verified-local** target. MUST NOT invent an account/email/password or commit credentials; prd/stg provisioning stays human-executed; shared local DBs get coordinated before seeding. An unresolved fixture STOPS the run with `E2E fixtures unresolved: [what]` instead of producing failures that are really missing data — and a green run with unverified fixtures reports as `됐는데 미검증`, not `됐다`. Enforced on shipping surfaces: the `agent-browser-e2e` description, `reference/e2e-testing.md` → "Preconditions", `agentic-testing`, and both tester agents.
- **`testing.md` → "E2E Fixtures" profile block** so the account, credential source, idempotent seed command, target env, shared-resource caution, and teardown are captured per project at `/team-init` time — literal passwords banned from the file, unknowns recorded as `[FILL: …]` so they read as a blocker rather than a default.

## v1.22.0 — 2026-07-30

`brain-connect` covered only persona + auto-memory, so anything else kept per-machine — a global `CLAUDE.md`, personal global skills — silently diverged: an edit on one machine simply never reached the other. The contract now spans the whole cross-machine surface.

### Added
- **Brain contract rows for `CLAUDE.md`, `skills/<name>/`, and `settings.recommended.json`** — 7 rows total (was 3), each still optional and skipped when the brain lacks it.
- **`settings.recommended.json` + `apply-settings.sh` / `apply-settings.ps1`** — an enumerated allowlist of machine-neutral keys, merged recursively into the local `settings.json` (manifest wins). Keys absent from the manifest are left untouched, which is what preserves machine-specific `hooks`. The `.sh` uses `jq`; the `.ps1` merges natively (no jq dependency).
- **`template/setup.sh` and `template/sync.sh`** — the macOS/Linux halves of the connector, which previously existed only as prose telling you to port the PowerShell yourself.
- **Asymmetry as a trigger condition** — "fixed on one machine, missing on the other" now routes to this skill, since that asymmetry means the artifact lives outside the brain.

### Changed
- **One link per skill, never the whole `skills/` dir.** `~/.claude/skills/` is shared ground: other tools install skills there as relative symlinks into their own store, so linking the directory hides them and moving it into the brain breaks their targets and auto-commits another tool's files. Same reasoning as the namespaced `commands/brain` link.
- **Persona import is relative** — `@persona.md` inside the brain's `CLAUDE.md`, plus a `persona.md` link beside the linked `CLAUDE.md`. No machine path survives in synced content, and the import resolves whichever base dir Claude Code uses for a symlinked memory file.
- **`relocate.ps1` reduced to one job.** Links re-point themselves via `setup.ps1`'s `Link-Brain`, so relocation is now only about the sync-hook commands in `settings.json` — the one place a stale absolute brain path can survive, since hook commands are never synced.
- **Directory vs file link is explicit.** Directories use junctions (no privilege); files (`CLAUDE.md`, `persona.md`) need symlinks, so Windows needs Developer Mode. Hardlinks are rejected outright: `git pull` replaces the file inode and would silently orphan one while it still looks valid.
- **Verify section demands evidence.** Adds the `grep -r` trap — once skills are symlinks, `-r` traverses **zero** files and reports 0 hits for any pattern, a false green; use `-R` and assert the traversed-file count is non-zero. A clean `git status --porcelain` proves the push happened, not that the content arrived; only diffing the file on the other machine does.

### Fixed
- **`enabledPlugins` without `extraKnownMarketplaces` is vacuous** — toggling a plugin for a marketplace the machine never registered does nothing. The manifest guidance now ships the pair.
- **`~/.claude.json` explicitly banned from any brain** — per-project state, MCP disable lists and `numStartups` are machine-specific startup bookkeeping that conflicts endlessly when shared.
- **Pre-push audit made a MUST** — `sync push` is `git add -A` + auto-commit + auto-push, so content is published unreviewed; credential-scan it and confirm the remote is private *before* moving anything in.

## v1.21.0 — 2026-07-30

Graph-format orchestration (LangGraph *technique*, not runtime): persisted run-state + one normative escalation transition table, replacing four divergent copies of the same rules/graph.

### Added
- **Phase transition table** (`escalation.md`) — the ~20-row normative SSOT (guard / classification / target phase / counter effect / abort threshold) covering every escalation edge across all 5 phases + Phase 4.5, plus explicit counter-semantics rules (`retries.pN` vs `globalCycle` increment/reset behavior).
- **`.claude/session-state/team-run.json` read/write contract** (`team-workflow/SKILL.md` → "State Tracking") — persists `runId`/`phase`/`retries`/`globalCycle`/`escalations[]`/`designerAssignments[]` to disk so retry/abort caps are enforceable across compaction and session boundaries, not just held in orchestrator context. Read on every phase entry, written on every transition; a foreign `runId` still in flight STOPs and surfaces instead of silently overwriting (parallel-session safety).
- `pre-compact.sh` reminds the post-compaction session to re-read `team-run.json` on **auto**-compaction (the hook's existing matcher scope; not triggered by a manual `/compact`) — no new persistence logic, the file already survives compaction via the filesystem.
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
