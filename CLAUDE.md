# AI Harness — Claude Code Configuration

> Tuned for the current **Claude Opus 4.x** (the runtime reports the exact model each session — do not hard-code a version). Every directive below is literal: no implicit "use judgment" clauses.
>
> **This file is the always-on router.** Detailed, domain-specific rules live in lazily-loaded files (path-scoped `.claude/rules/`, skills, and agent definitions) so they cost context only when relevant. See **Rule Routing** below.

---

## Operating Principles

Apply to all agents, skills, commands, and direct use.

**1. Literal instruction following** — replace every ambiguous modifier with a specific condition before shipping a prompt:

| Do NOT write | Write instead |
|--------------|--------------|
| "Keep it simple" | "MUST NOT add abstractions without 3+ current callers" |
| "Include tests if needed" | "MUST write tests before implementation for every public function" |
| "Do your best" | "MUST [specific action with success criteria]" |
| "When appropriate" / "As needed" | "[specific trigger condition / explicit list]" |
| "Consider X" | "MUST evaluate X against [criteria] and report decision" |

**2. Effort levels** — `low` (rote) · `high` (mechanical edits) · `xhigh` (default — all coding, planning, review) · `max` (hard debugging, autonomous multi-step, long-horizon architecture). Start at `xhigh`; upgrade to `max` only after `xhigh` fails twice on the same task.

**3. Tool use** — on failure: retry once, then take an alternate approach (don't abandon the task). On suspected loop: pause, summarize, re-plan.

**4. File system is memory** — persistent state on disk (`session-state/`, `checkpoints/`, `_docs/`); see Session State Layout + `checkpoint` skill.

---

## Renewal Mode Gate

Applies to **all agents, skills, and direct use** at the start of any task that changes EXISTING behavior or structure — refactor, redesign, bugfix-by-rewrite, schema/data/API reshape — EXCEPT a trivial 1-file mechanical edit (typo, config value, one-liner), which skips this gate.

**MUST present both modes as labeled options (A/B) and wait for a choice — MUST NOT silently assume Mode A.**

- **A — Compatible**: preserve existing contracts/callers/data shape; additive or backward-compatible changes; migrations keep the old shape working.
- **B — Destructive Renewal**: discard the old structure and rebuild clean — drop/recreate, remove back-compat scaffolding, rename freely.

When a **destructive signal** is present — local/throwaway/this-harness target, pre-deploy/"clean state", or the user said any of "파괴적으로 가도 됨" / "호환성 맞출 필요 없어" / "다 바꿔도 됨" — MUST recommend **B**. MUST NOT default to A "to be safe": that default is the known failure mode this gate exists to correct.

**Mode B requires an approval gate.** Before ANY destructive execution, MUST present a **Risk Block** and get explicit user approval:
1. **Blast radius** — concrete list of what breaks / what still consumes the old structure.
2. **Discarded** — exactly what is dropped or lost (tables, columns, files, APIs, records).
3. **Irreversibility + rollback** — is it reversible? backup/restore path taken before executing.
4. **Data safety** — prd/stg data → STOP, human executes (assistant writes SQL + local dry-run + verify queries only); local/throwaway → autonomous OK.
5. **Why renewal > compat here** — the structural reason; absent one, B is not justified → use A.

**After B is approved, MUST fully commit (anti-drift):**
- MUST NOT re-introduce back-compat scaffolding, nullable-for-old-data columns, additive-only migrations, or "keep just in case" fields.
- MUST NOT defend an invariant that has zero current subjects (e.g. preserving sealed/frozen records when the count is 0).
- MUST NOT silently downgrade to A. If new evidence makes compatibility genuinely necessary, STOP and re-surface the A/B choice — MUST NOT quietly switch back.

---

## Rule Routing (where each concern's detail lives)

| Concern | Detail lives in | Loads when |
|---------|-----------------|-----------|
| TS type-check gate · LSP · generated-client contracts | `.claude/rules/typescript.md` | TS files read |
| Security (secrets, injection, SQL) | `.claude/rules/security.md` | source files read |
| `_docs/` plan-storage foldering | `.claude/rules/docs.md` | `_docs/`/`_note/` touched |
| UI/UX design quality | `impeccable` plugin + `team-uiux-master`/`web-architect`/`web-reviewer` defs | those agents run |
| Code minimalism (YAGNI) | `coding-standards` §4 + build-agent defs + Phase 4 `/ponytail-review` | per agent / phase |
| TDD, verification, parallelization, contract-sync, … | the matching skill (loads on invoke) | on invoke |

**Non-TS projects**: use the native checker from `stack.md` (`pyright`/`mypy`/`go vet`…); `verification-loop` Phase 2 adapts.

**Delegated plugins (hard dependencies)** — both reach subagents via the agent definitions, not this file:
- **`impeccable`** (`pbakaus/impeccable`) owns UI/UX quality — the uiux agents call `Skill(skill="impeccable:impeccable", args="<sub-command> [target]")` and ABORT + request install if it's unregistered.
- **`ponytail`** owns YAGNI minimalism — Phase 4 Tester runs `/ponytail-review` and ABORTs + requests install if missing. MUST NOT add ponytail to `plugin.json` deps (external-marketplace manifest deps break plugin load).

---

## Package Manager

Detect in order: **Bun** (`bun.lockb`/`bun.lock`) → **pnpm** (`pnpm-lock.yaml`) → **npm** (`package-lock.json`); no lockfile → default Bun. Every shell command (outputs, skills, docs) MUST use the detected manager — **Bun by default**, translated when the lockfile says otherwise. MUST NOT mix managers within a project.

## Authoritative Documentation (MCP)

Advisory (informs correctness, doesn't block a phase). Don't trust training memory for version-sensitive/external-API facts — consult the MCP if connected, else note the unverified assumption.

| Source | Consult for |
|--------|-------------|
| **Context7** (`resolve-library-id`→`query-docs`) | Library/framework/SDK APIs, config, version-migration, CLI |
| **MDN** (`search`/`get-doc`/`get-compat`) | Web-platform facts: browser compat, Baseline, Web APIs, CSS/JS support, CWV |

Prefer these over web search and over memory even for "well-known" APIs. If MCP schemas are deferred, load the tool first.

---

## Required: Agent Teams

`/team`, `/team-run`, `/team-brainstorm` depend on `TeamCreate`/cross-review/multi-agent orchestration. Enable in `settings.json` → `"env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }`; unset = those commands won't function.

## Ultracode Orchestration

When the runtime signals **ultracode** (or `CLAUDE_HARNESS_ULTRACODE=1` override) AND `workflow()` is callable, every process with 2+ independent units, a fan-out-then-barrier shape, or a per-item multi-stage flow MUST run via the Workflow tool — `parallel()` (barriered fan-out), `pipeline()` (per-item), `workflow()` (nest one level) — using the matching pattern (adversarial-verify, perspective-diverse verify, judge-panel, completeness-critic, self-repair) and `schema` whenever a downstream gate consumes a structured field.

- **Named fan-out points**: Phase 1 architecture (FE/BE parallel; cross-review stays `TeamCreate`), Phase 3 Designer-and-merge (worktree-isolated), Phase 4 Tester-per-designer, Phase 4.5 Explorer→Generator pipeline.
- Harness's **max-5-worktree cap** + **types→backend→frontend→tests merge order** OVERRIDE the looser `min(16, cores-2)` Workflow cap for code-writers.
- **MUST NOT** use Workflow for: a single-agent task; a strictly sequential chain with no per-item streaming benefit; work sharing mutable state; parallel use of the single shared Playwright browser; deterministic state-file bookkeeping.
- **Outside ultracode**, all of the above MUST use the lightweight `Agent()`/`TeamCreate` path — do NOT introduce a Workflow layer. (Ultracode is a **topology** signal, separate from **effort**.)

---

## First Run: Project Analysis

```
/team-new <idea>    # GREENFIELD (empty repo): research → scaffold → profile, then /team-run
/team-init          # EXISTING tree: analyze → generate .claude/project-profile/ (9 docs)
/team-init --update # Refresh after major changes
```

Do NOT run `/team-init` on an empty repo (vacuous profile) — `/team-new` bootstraps via `greenfield-bootstrap` then runs `project-analyzer` (Seeded Mode). The 9-doc profile is read by every agent.

## Commands

| Command | Use when |
|---------|---------|
| `/team-new <idea>` | **Greenfield** — empty repo, start from scratch (research → scaffold → profile) |
| `/team-init` | **Existing** project not yet analyzed (has code, no `.claude/project-profile/`) |
| `/team-brainstorm <task>` | Plan-only discussion, no code changes |
| `/team <task>` | Full workflow with user in planning |
| `/team-run <task>` | Full autonomous workflow |
| `/checkpoint` | Save/restore work state (NOT built-in `/resume`) |
| `/take-over [topic]` | Resume a handed-off work-stream from `_docs/handoff/` (hydrate spec → verify state → graduate the temp handoff → complete/ or a plan, renamed); NOT `/checkpoint` |
| `/test-scenario-doc` | On-demand manual QA checklist HTML (human acceptance layer) |
| `/docs-sweep` | Reap stale `_docs/active/` + re-verify orphan invariants |
| `/brain-connect [path]` | Pair an optional personal **brain** SSOT (cross-machine persona + auto-memory), or relocate one |

**Routing**: resuming your own interrupted session → `/checkpoint`; taking over a handed-off work-stream (a `_docs/handoff/` doc exists) → `/take-over`. Empty repo → `/team-new`. First time in an existing project → `/team-init` (MUST precede any `/team*`). Task that modifies 3+ files / is cross-cutting (API+UI+state) / touches auth·payments·sensitive data / is user-facing → `/team` or `/team-run`. Architectural uncertainty → `/team-brainstorm` first. Single-file trivial (typo, config, one-liner) → direct implementation allowed; everything else MUST use the team workflow.

**Brainstorm routing** (any "brainstorm" / ideation / "let's design X" / pre-creative request — route by blast radius, do NOT auto-invoke any auto-fired external brainstorming skill):
- Multi-file / cross-cutting (API+UI+state) / product feature / auth·payments·sensitive data / genuine architectural uncertainty → **`/team-brainstorm`** (Leader + Architects, cross-review, visual plan).
- Solo / local / throwaway / this harness / a single bounded change → the **`brainstorm`** skill (lightweight dialogue → `_docs/active/planning/` design, no auto-commit, hands off to the harness pipeline).
- This is a user instruction and takes precedence over any plugin/hook that would auto-fire a different brainstorming skill.

---

## Document Storage (3 buckets)

Classify by **owner** with the discriminator: *"swap this agent CLI for another — still meaningful?"* Yes → project/human (repo root, `_` prefix); No, agent-only → `.claude/`.

| Bucket | Owner | Automation |
|--------|-------|-----------|
| `_docs/` | project | `docs-lifecycle` (auto-move, merge-on-complete, `git rm`) — foldering detail in `.claude/rules/docs.md` |
| `_note/` | human | **none — agent read-only** |
| `.claude/wiki/` | agent | `wiki` skill (ingest/query/lint) |

**`_note/` is human-owned, agent read-only** (always-on rule): MUST NOT create/move/merge/reorganize/delete there on your own initiative — modify ONLY on explicit request; otherwise read and leave untouched (exempt from `_docs/` lifecycle/frontmatter).

**`_docs/` is primary-worktree-only** (always-on rule): every `_docs/` file lives in the repo's **primary working tree**, never in a linked worktree's checkout. Worktree agents read/write doc **content** files by the primary tree's absolute path (`$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/_docs`), each owning distinct files; only `index.md` edits + status-moves stay orchestrator-serialized. This keeps plans readable from main without cd-ing into a worktree. (Detail: `docs-lifecycle` → Concurrency; `parallelization`.)

---

## Agents

Live in `agents/`, invoked by `team-workflow` via the Agent tool (`subagent_type: <name>`). Model = tier (exact version resolved per agent frontmatter + runtime); all Opus agents default to `xhigh`, Sonnet agents use their default.

| Agent | Model | Role |
|-------|-------|------|
| team-leader | Opus | Coordination, planning, approval gates |
| team-architect-fe | Opus | Frontend architecture |
| team-architect-be | Opus | Backend architecture |
| team-architect-infra | Opus | Infra/security (on-demand + final review) |
| team-uiux-master | Opus | UI/UX design intelligence |
| team-designer | Opus | TDD implementation (Red-Green-Refactor) |
| team-tester | Sonnet | Unit + E2E test verification |
| team-agentic-tester | Opus | Phase 4.5 agentic testing (explore-gate + deterministic generator) |
| web-architect | Opus | Web architecture (components, state, API, perf) |
| web-reviewer | Sonnet | Web quality audit (A11y, CWV, SEO, design, AI Slop) |

## Skills

| Skill | Phase | Purpose |
|-------|-------|---------|
| team-workflow | Core | 5-phase orchestration |
| greenfield-bootstrap | /team-new | G0 intake → G1 research → G2 stack decision → G3 gate → G4 scaffold → G5 seeded profile |
| plan-review | Phase 1 | Adversarial plan evaluation + pre-plan elicitation |
| plan-visualizer | Phase 1+ | HTML plan diagram |
| brainstorm | Pre-Phase 1 (solo) | Lightweight solo design dialogue → `_docs/` design, no auto-commit; solo counterpart to `/team-brainstorm` |
| docs-lifecycle | All | `_docs/` status↔folder lifecycle, date/topic foldering, reference-safe moves, 3-bucket model, merge-on-complete |
| handoff | All | Write a handoff (state layer) into `_docs/handoff/` — links spec, keep-latest-per-stream |
| take-over | On-demand | Read/resume counterpart to `handoff` — locate handoff → hydrate spec → verify state vs repo → **graduate** the temp handoff into its durable `_docs` home (complete/ or a plan), renamed; never bare-deleted |
| wiki | All | Agent wiki (`.claude/wiki/`) — compounding KB: ingest/query/lint, link-don't-duplicate |
| coding-standards | Phase 3 | Code quality baseline (strict TS) + §4 YAGNI ladder |
| tdd-workflow | Phase 3 | Red-Green-Refactor cycle (Vitest 4.x) |
| systematic-debugging | Phase 3-4 | General debugging methodology (root cause → pattern → hypothesis → fix); `debug` layers TS/LSP on top |
| debug | Phase 3-4 | LSP-driven debugging patterns (TS) |
| e2e-testing | Phase 4 | Playwright E2E |
| agentic-testing | Phase 4.5 | Adapter-based agentic E2E: explore → verify → crystallize deterministic test |
| agent-browser-e2e | On-demand | Prefer `agent-browser` CLI for E2E/QA/smoke + headless Auth Vault login when CLI+skill installed (1-time gate); else fall back to Playwright. Not phase-wired |
| test-scenario-doc | Human acceptance | Interactive human QA checklist HTML (`/test-scenario-doc`) |
| scenario-to-e2e | On-demand | Turn a `test-scenario-doc` (`SCENARIOS` config = SSOT) into Playwright specs — drive live app → real selectors → run + green-gate; scaffold fallback marked unverified. No fabricated selectors, no unverified "done" |
| verification-loop | Phase 4-5 | 6-phase quality gate + checkpoints + pass@k + baseline/net-new + vacuity guard |
| contract-sync | Phase 0 / BE→FE | Regenerate generated client → isolate churn → authoritative type-check → cross-check consumption |
| security-review | Phase 5 | OWASP checklist + Phase 5 audit format |
| requesting-code-review | Phase 3-5 / on-demand | Dispatch a code-reviewer subagent (crafted context) between tasks / before merge |
| token-optimization | All | Model routing, effort levels, compaction |
| continuous-learning | All | Pattern extraction, session state, skill evolution |
| parallelization | Phase 3+ | Worktree management, cascade method, scaling |
| dispatching-parallel-agents | Phase 3+ | When to split work into concurrent agents vs keep sequential (independent-domain dispatch) |
| subagent-orchestration | All | Iterative retrieval, context briefing, phase pipeline |
| checkpoint | All | Save/restore work state across sessions |
| project-analyzer | /team-init | Generate project profile (9 files) |
| brain-connect | Setup (per-machine) | Pair an optional personal **brain** SSOT — `@import` + memory junction + opt-in sync hooks; dependency-free, ships generic connector template |

---

## Agent Execution Mode

Team-spawned agents MUST use `mode: "bypassPermissions"`, `isolation: "worktree"` for Designers (parallel-safe), and `TeamCreate` for cross-review dialog (not separate Agent calls).

## Escalation Rules

- Each agent classifies issues **Simple Fix** vs **Fundamental Issue** (criteria in `skills/team-workflow/resources/escalation.md`); ambiguous → Fundamental (escalate up).
- Per-phase retries max 3; global re-plan cycles max 3 → ABORT on exceed.
- Every escalation MUST be reported to the user in the required format.

## Operational Skills (hard-rule digest; detail in each skill)

| Skill | Hard rule summary |
|-------|------------------|
| `token-optimization` | Route model by task class; `xhigh` default; MCPs <10, tools <80; compact after milestones only |
| `continuous-learning` | Write `current.md` during work; extract patterns after milestones; **reuse** at task start (load → route into briefings, promote stable to profile); evolve to skill after 3+ high-confidence learnings |
| `checkpoint` | Auto-save on Stop + Pre-Compact hooks; manual `/checkpoint save [title]` anytime |
| `verification-loop` | 6-phase gate (build/type/lint/test/security/diff); non-vacuous commands; gate type/lint on net-new vs baseline; pass@1 ≥ 80% tests, pass^3 = 100% security |
| `contract-sync` | On contract change w/ generated client: regenerate → isolate churn → type-check (net-new) → verify consumption shape, BEFORE verifying client code; backend SSOT, never edit generated |
| `parallelization` | Max 5 worktrees, zero file overlap, merge order types → backend → frontend → tests; `_docs/` in primary tree only (worktrees read/write by absolute path) |
| `subagent-orchestration` | 3-cycle retrieval cap; every prompt MUST include What/Why/Where/Context/Constraints/Already-tried |

### Active Hooks (`hooks/hooks.json`, `${CLAUDE_PLUGIN_ROOT}` paths)

| Hook | Event | Script |
|------|-------|--------|
| Session Start | `SessionStart` (startup\|resume) | `hooks/session-start.sh` |
| Session Stop | `Stop` | `hooks/session-stop.sh` |
| Pre-Compact | `PreCompact` (auto) | `hooks/pre-compact.sh` |
| Post-Edit Warn | `PostToolUse` (Edit\|Write) | `hooks/post-edit-warn.sh` |

### Session State Layout
`.claude/session-state/`: `current.md` (active, write during work) · `last-session.md` (auto-rotated by Stop) · `archive/` (max 20, 7-day TTL) · `checkpoints/` (max 10 + `latest.md`) · `learnings/`.

### Claude Code Built-ins (rely on, don't duplicate)
`/effort` (`xhigh` default, `max` for hard debugging) · `/model` (Opus for Phase 1/3, Sonnet for Phase 4 Tester, Haiku for broad search) · `/fast` (faster Opus output, same model) · `/compact` (pre-compact hook auto-checkpoints; MUST NOT run mid-implementation) · `/resume` (≠ our `/checkpoint`) · `/review`+`/security-review` (complement Phase 5) · `/simplify` (after Phase 3) · `/rewind` (when output is structurally wrong) · `/branch`·`/memory`·`/cost`·`/context`. Harness-owned methodology skills (do NOT reimplement; invoke directly when a task matches): `systematic-debugging` (general debugging) · `tdd-workflow` (TDD) · `verification-loop` (verify-before-claim) · `parallelization` + `dispatching-parallel-agents` (worktrees + when to split) · `requesting-code-review` · `brainstorm` (solo design).

---

## Operational Discipline

- **Shared/external infra is the human's to start.** Do NOT auto-open tunnels to or start shared/managed infra (cloud DB, managed cache, bastion, VPN). If a dependency is down, surface a one-line "please start X" and proceed where you can — don't script around it or repeatedly probe.
- **Stop watch-mode dev servers during edit sessions** (a hot-reloader recompiles on every save); restart only when a step (codegen, smoke, manual verify) needs it.
- **Shell exit-code hygiene**: a command with no stdout piped into a filter (`… | grep …`) can exit non-zero on empty input — capture the code directly (`cmd > out 2>&1; rc=$?`). PowerShell: `-ErrorAction SilentlyContinue` suppresses output but the failure still sets exit 1 — wrap in `try { … -ErrorAction Stop } catch {}`.
- **Local-vs-production gates destructive ops**, not operation type: a destructive command against a verified-local target may run without per-command confirmation; any command naming a production/remote endpoint always requires explicit confirmation.

## Versioning & Release

Distributed via the `JunjaK/ai-harness` marketplace and **version-cached** — an unchanged version is a no-op even after a marketplace "update."
- **MUST bump version on every feature add/change**: any change to a skill, agent, command, or hook behavior bumps `version` in BOTH `.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` (feature = minor, fix = patch), same change.
- **MUST update docs in the same change**: `README.md`, the skills/agents/commands tables here, and `description` fields when the summary changes.
- Release commit style: `chore(release): bump plugin + marketplace to vX.Y.Z`. Pure docs/chore changes (no behavior change — incl. CLAUDE.md and `.claude/rules/` edits) are exempt.

## Scope Discipline

Direct implementation is allowed ONLY when ALL hold: touches 1 file · obvious & mechanical · no test/type/lint regression · no security/data-integrity impact. Everything else MUST go through the team workflow.

(Security gate: see `.claude/rules/security.md`; the **Phase 5 security audit is MANDATORY for every team workflow** regardless.)
