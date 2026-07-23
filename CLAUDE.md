# AI Harness — Claude Code Configuration

> **Always-on router.** Detail lives in lazily-loaded files (`.claude/rules/`, skills, agent definitions) so it costs context only when relevant.
>
> **Not shipped.** Plugins cannot inject `CLAUDE.md` into user projects (README → "CLAUDE.md Note"). This file governs work *on* the harness and doubles as the copyable ruleset. It MUST NOT restate any registry the runtime already injects — skill/agent/command descriptions arrive from frontmatter automatically, and re-typing them here pays the cost twice.
>
> The runtime reports the exact model each session. MUST NOT hard-code a model version anywhere in this repo.

**Literal instruction following** — every directive here is literal; there are no implicit "use judgment" clauses. When authoring any prompt, replace each ambiguous modifier with a specific condition: "keep it simple" → "MUST NOT add abstractions without 3+ current callers"; "if needed" → the explicit trigger list.

---

## Renewal Mode Gate

Applies to all agents, skills, and direct use at the start of any task that changes EXISTING behavior or structure — refactor, redesign, bugfix-by-rewrite, schema/data/API reshape. A trivial 1-file mechanical edit (typo, config value, one-liner) skips this gate.

**Open with the A/B choice as labeled options and wait for the user to pick.** Choosing a mode silently is the failure this gate exists to prevent.

- **A — Compatible**: preserve existing contracts/callers/data shape; additive or backward-compatible; migrations keep the old shape working.
- **B — Destructive Renewal**: discard the old structure and rebuild clean — drop/recreate, remove back-compat scaffolding, rename freely.

**Recommend B when a destructive signal is present** — local/throwaway/this-harness target, pre-deploy/"clean state", or the user said "파괴적으로 가도 됨" / "호환성 맞출 필요 없어" / "다 바꿔도 됨". Let the signal pick the default, not caution: reaching for A "to be safe" is the known failure mode this gate corrects.

**Mode B requires a Risk Block + explicit approval before any destructive execution:**
1. **Blast radius** — what breaks / what still consumes the old structure.
2. **Discarded** — exactly what is dropped (tables, columns, files, APIs, records).
3. **Irreversibility + rollback** — reversible? backup path taken before executing.
4. **Data safety** — prd/stg data → **STOP, human executes** (assistant writes SQL + local dry-run + verify queries only); local/throwaway → autonomous OK.
5. **Why renewal > compat here** — the structural reason; absent one, use A.

**Once B is approved, commit fully to the new shape.** Build the new structure outright — no back-compat scaffolding, no nullable-for-old-data columns, no "keep just in case" fields; drop invariants with zero current subjects. Stay on B: if genuinely new evidence makes compatibility necessary, STOP and re-surface the A/B choice openly. A deliberate visible switch is fine; quiet drift back is not.

---

## Rule Routing

| Concern | Detail lives in |
|---------|-----------------|
| TS type-check gate · LSP · generated-client contracts | `.claude/rules/typescript.md` |
| Security (secrets, injection, SQL) | `.claude/rules/security.md` |
| `_docs/` plan-storage foldering | `.claude/rules/docs.md` |
| UI/UX design quality | `impeccable` plugin + the uiux/web agent definitions |
| Code minimalism (YAGNI) | `coding-standards` §4 + build-agent defs + Phase 4 `/ponytail-review` |
| Escalation criteria + retry caps | `skills/team-workflow/resources/escalation.md` (per-phase retries max 3; global re-plan cycles max 3 → ABORT) |
| TDD, verification, parallelization, contract-sync, … | the matching skill (loads on invoke) |

`.claude/rules/` is repo-local and path-scoped; it does not travel with the plugin. **Non-TS projects**: use the native checker from `stack.md` (`pyright`/`mypy`/`go vet`…); `verification-loop` Phase 2 adapts.

**Delegated plugins (hard dependencies)** — each reaches subagents via agent/command definitions, not this file. All three ABORT + request install when unregistered. MUST NOT add any of them to `plugin.json` deps: external-marketplace manifest deps break plugin load.

- **`impeccable`** (`pbakaus/impeccable`) — UI/UX quality.
- **`ponytail`** — YAGNI minimalism (`/ponytail-review`, Phase 4).
- **`superpowers`** — general debugging methodology, code-review dispatch, and parallel-agent dispatch decisions. The harness deliberately does NOT fork these; `/debug` and the `debug` skill invoke `superpowers:systematic-debugging` and layer the harness's TS/LSP patterns and escalation boundary on top.

---

## Package Manager

Detect in order: **Bun** (`bun.lockb`/`bun.lock`) → **pnpm** (`pnpm-lock.yaml`) → **npm** (`package-lock.json`); no lockfile → default Bun. Every shell command MUST use the detected manager. MUST NOT mix managers within a project.

## Authoritative Documentation (MCP)

Advisory — informs correctness, doesn't block a phase. MUST NOT trust training memory for version-sensitive or external-API facts: consult the MCP if connected, else mark the assumption unverified. Prefer these over web search and over memory even for "well-known" APIs. Tool namespaces vary by install method — resolve the registered name at call time rather than hard-coding it.

- **Context7** (`resolve-library-id` → `query-docs`) — library/framework/SDK APIs, config, version-migration, CLI.
- **MDN** (`search`/`get-doc`/`get-compat`) — browser compat, Baseline, Web APIs, CSS/JS support, CWV.

## Required: Agent Teams

`/team`, `/team-run`, `/team-brainstorm` depend on `TeamCreate`. Enable in `settings.json` → `"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }`; unset = those commands won't function.

## Ultracode Orchestration

When the runtime signals **ultracode** (or `CLAUDE_HARNESS_ULTRACODE=1`) AND `workflow()` is callable, every process with 2+ independent units, a fan-out-then-barrier shape, or a per-item multi-stage flow MUST run via the Workflow tool — `parallel()`, `pipeline()`, `workflow()` — with `schema` whenever a downstream gate consumes a structured field.

- **Model routing per `agent()`**: an omitted `opts.model` inherits the session model (Opus), so leaving every stage on Opus is the default failure. Set `opts.model` + `opts.effort` by task class. Routing table + named fan-out points: `token-optimization` §1.
- Harness's **max-5-worktree cap** + **types→backend→frontend→tests merge order** OVERRIDE the looser `min(16, cores-2)` Workflow cap for code-writers.
- **MUST NOT** use Workflow for: a single-agent task; a strictly sequential chain with no per-item streaming benefit; work sharing mutable state; parallel use of the single shared Playwright browser; deterministic state-file bookkeeping.
- **Outside ultracode**, all of the above MUST use the lightweight `Agent()`/`TeamCreate` path — do NOT introduce a Workflow layer. Ultracode is a **topology** signal, separate from **effort**.

---

## Command Routing

Empty repo → `/team-new`. First time in an existing project → `/team-init` (MUST precede any `/team*`; running it on an empty repo yields a vacuous profile).

A bug / test-failure / unexpected behavior you'd otherwise start guessing at, and it's solo-scope (not cross-cutting, root cause within <3 modules, no unplanned BE change) → `/debug`, which escalates to `/team` itself when it turns Fundamental. Resuming your own interrupted session → `/checkpoint`. Taking over a handed-off work-stream (a `_docs/handoff/` doc exists) → `/take-over`.

Task that modifies 3+ files / is cross-cutting (API+UI+state) / touches auth·payments·sensitive data / is user-facing → `/team` or `/team-run`. Architectural uncertainty → `/team-brainstorm` first.

**Brainstorm routing** — any "brainstorm" / ideation / "let's design X" request routes by blast radius. Do NOT auto-invoke an externally auto-fired brainstorming skill; this instruction takes precedence over any plugin or hook that would.
- Multi-file / cross-cutting / product feature / auth·payments·sensitive data / genuine architectural uncertainty → **`/team-brainstorm`**.
- Solo / local / throwaway / this harness / a single bounded change → the **`brainstorm`** skill.

---

## Document Storage (3 buckets)

Classify by **owner**, discriminator: *"swap this agent CLI for another — still meaningful?"* Yes → project/human (repo root, `_` prefix); No, agent-only → `.claude/`.

| Bucket | Owner | Automation |
|--------|-------|-----------|
| `_docs/` | project | `docs-lifecycle` (auto-move, merge-on-complete, `git rm`) |
| `_note/` | human | **none — agent read-only** |
| `.claude/wiki/` | agent | `wiki` skill |

**`_note/` is human-owned, agent read-only**: MUST NOT create/move/merge/reorganize/delete there on your own initiative — modify ONLY on explicit request. Exempt from `_docs/` lifecycle and frontmatter rules.

**`_docs/` is primary-worktree-only**: every `_docs/` file lives in the repo's primary working tree, never in a linked worktree's checkout. Worktree agents read/write doc content by the primary tree's absolute path, each owning distinct files; only `index.md` edits and status-moves stay orchestrator-serialized. Path resolution and the concurrency protocol: `.claude/rules/docs.md` + `docs-lifecycle`.

---

## Operational Discipline

- **Shared/external infra is the human's to start.** Do NOT auto-open tunnels to or start shared/managed infra (cloud DB, managed cache, bastion, VPN). If a dependency is down, surface a one-line "please start X" and proceed where you can.
- **Stop watch-mode dev servers during edit sessions**; restart only when a step (codegen, smoke, manual verify) needs it.
- **Shell exit-code hygiene**: keep stdout and stderr on separate streams by default. When capturing an exit code, capture it directly rather than inferring it from a filter — a command with no stdout piped into `grep` exits non-zero on empty input. PowerShell: `-ErrorAction SilentlyContinue` suppresses output but still sets exit 1 — wrap in `try { … -ErrorAction Stop } catch {}`.
- **Windows shell fallback**: when `Bash` fails *repeatedly from a broken Git-for-Windows bash* (not a genuine command error), stop retrying the same shell — switch to the PowerShell tool. And never test a CLI's existence with a call that spawns its GUI (e.g. a non-headless `soffice`) — use a headless / `--version` / `Get-Command` probe instead.
- **Local-vs-production gates destructive ops**, not operation type: a destructive command against a verified-local target may run without per-command confirmation; any command naming a production/remote endpoint always requires explicit confirmation.
- **Destruction acts only on the exact target the user requested.** Local autonomy gates *whether* a destructive op needs confirmation, not *how much* it may destroy: asked to drop specific data (company rows, one database), touch exactly that — never the whole datadir, system/shared databases, or unrelated state. If the requested scope can't be isolated from a broader wipe, STOP and confirm before executing.
- **This repo commits directly to `main`** — do NOT branch first here. Merge/deploy/push to other repos stays user-gated.
- **Parallel sessions share the working tree — commit only what you changed, never revert what you didn't.** Multiple sessions/agents commonly develop in one tree at once, so others' uncommitted work is present. HARD LINE (no exception): never discard or overwrite changes you did not make — no blanket `git add -A` / `reset --hard` / `checkout -- .` / `restore` / `stash` / `clean` that touches another session's files. Default to staging only the specific paths/hunks you changed (`git status` first); **committing another session's uncommitted work is allowed only when the user explicitly asks** (e.g. a requested split-commit — stage those paths deliberately into their own commit). Confirm the target branch before commit/push. If your change can't be isolated from someone else's uncommitted work and you weren't told to commit it → STOP and surface it.

## Scope Discipline

Ceremony scales with blast radius, not with operation type.

- **This harness, local, and throwaway targets** — implement directly; spec/plan optional; destructive cleanup allowed once the Renewal Gate is settled.
- **Product, shared, or production targets** — direct implementation is allowed ONLY when ALL hold: touches 1 file · obvious & mechanical · no test/type/lint regression · no security/data-integrity impact. Everything else MUST use the team workflow.

Security gate: `.claude/rules/security.md`. The **Phase 5 security audit is MANDATORY for every team workflow** regardless of scope.

## Versioning & Release

Distributed via the `JunjaK/ai-harness` marketplace and **version-cached** — an unchanged version is a no-op even after a marketplace "update".

- Any change to a skill, agent, command, or hook behavior MUST bump `version` in BOTH `.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` in the same change (feature = minor, fix = patch), and MUST update `README.md` plus any `description` field whose summary changed.
- **Every bump MUST add a `CHANGELOG.md` entry** in the same change: `## vX.Y.Z — YYYY-MM-DD` with user-visible changes grouped Added/Changed/Fixed/Removed, and refresh the "Latest" block in `README.md` → Changelog. `CHANGELOG.md` is the release-note source of truth; the README block mirrors only the newest version. A CLAUDE.md-only or `.claude/rules/`-only change that carries no version bump needs no entry.
- **Publish a GitHub Release per bump** — the CHANGELOG entry is the release-note body. After the release commit is pushed: tag `vX.Y.Z` and `gh release create vX.Y.Z --title vX.Y.Z --notes-file <that entry>`. This is an **outward publish → user-gated like push**. PREFLIGHT `gh auth status` first: the active account MUST own this repo — releasing under a wrong/work identity is a known failure; if the active account is wrong, STOP and surface it, do not silently switch the global gh identity.
- Release commit style: `chore(release): bump plugin + marketplace to vX.Y.Z`. Pure docs/chore changes with no behavior change — including edits to this file and `.claude/rules/` — are exempt.
