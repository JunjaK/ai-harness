---
title: "Findings — /debug command build + whole-brain memory analysis (session 2026-07-10)"
status: complete
topic: debug-command
kind: findings
scope: harness
created: 2026-07-10
updated: 2026-07-10
related: []
---

# Findings — `/debug` command + brain-memory analysis

> One session, two threads: **(A)** built the `/debug` command (v1.13.0), **(B)** scanned the whole `claude-brain` memory for what's worth adding. Part A is a completed deliverable (commit gated). Part B's candidates are **deferred — user chose "D" (analyze only, write nothing)**; they're recorded here so they aren't lost.

---

## Part A — `/debug` command (deliverable, commit-pending)

### Trigger
User wanted a **debugging-only command** for general/solo cases (explicitly *not* the team-workflow), and asked to first check whether it already exists.

### Check finding (reuse-first)
Debugging **skills already exist as a 2-layer stack** — a new skill would be redundant:

| skill | role |
|-------|------|
| `systematic-debugging` | language-agnostic methodology — Iron Law (no fix before root cause), 4 phases, red flags, 3-fail→question-architecture |
| `debug` | TS/LSP-accelerated layer on top (`goToDefinition`/`findReferences`/`incomingCalls`, structural traps) |

`commands/` had **no `/debug`** (10 commands, none for debugging). So the only real gap was a **command**, not a skill.

### Decision — Option A: command only, reuse skills
Confirmed via AskUserQuestion. No new skill (would violate reuse-first / uniformity). `/debug` is a **deterministic entry point** that fires the existing skills — fixing the "undertriggering" failure where the description-triggered skill silently doesn't fire and the model starts guessing.

Fits the harness's existing **solo↔team split**: `brainstorm` skill (solo) ↔ `/team-brainstorm` (team); now debug skills (solo methodology) ↔ `/debug` (solo entry, escalates to `/team`).

### What was built (5 files, v1.12.0 → v1.13.0)
- **NEW** `commands/debug.md` — mirrors take-over/docs-sweep house style.
- `.claude-plugin/plugin.json` + `marketplace.json` — version bump (feature = minor).
- `CLAUDE.md` — Commands table row + Routing clause (solo↔team boundary).
- `README.md` — Commands table + file tree (10→11 commands).

### `/debug` design highlights
- **Iron Law**: no fix before root-cause investigation; not reproducible after 3 tries → ask for repro.
- **Stack routing**: TS/JS → auto-layers the `debug` (LSP) skill; non-TS → native checker from `stack.md`.
- **Solo↔team boundary** (= the "non-team-workflow" meaning): STOP and escalate to `/team` when **Fundamental** — 3+ fixes failed / root cause spans 3+ modules / needs unplanned BE contract change / cross-cutting (API+UI+state). prd/stg data → human executes.
- **3-way honesty in On Completion**: `fixed · fixed-unverified(smoke 미실시) · escalated→/team · not-reproduced` — never collapse the three states.
- Effort: start `xhigh`, `/effort max` only after `xhigh` fails twice on the same bug.

### Verification (done)
- 4 referenced skills all exist (systematic-debugging, debug, tdd-workflow, verification-loop).
- Format mirrors canonical `take-over.md`/`docs-sweep.md`.
- Versions consistent (both files 1.13.0).
- Commands auto-discovered from `commands/` — no registration array needed.

### Status
Code **complete + verified**. **Commit pending** (user gate — `chore(release): bump plugin + marketplace to v1.13.0`). Not pushed.

---

## Part B — Whole-brain memory analysis (deferred, nothing written)

Scanned **193 memory files across 14 namespaces** in `C:\Users\harin\dev\personal\claude-brain\memory\` (astro-irregular-ice, claude-brain = 0 files). Question: what's worth *adding*?

### §1 — Session-derived addition candidate (1, the only groundable one)
**`harness-capability-command-over-skill`** → **ai-harness namespace**, type `project`.

> When adding a capability/entry-point to ai-harness, first check if the capability exists as skill(s); if so, **don't add a redundant skill — add a thin command that deterministically fires the existing skill(s)**, and mirror the solo↔team split. **Why:** skills are description-triggered (prone to *undertriggering*); commands are deterministic user-invoked entry points that bypass that. **How:** capability = one skill set (no dup skills); entry point = command in `commands/` (auto-discovered, no registration; still needs version bump + docs per [[ai-harness-version-bump]]).

**Dedup check (whole brain):** NOT a duplicate. The `ert-dms` namespace has 3 harness-related memories (`ai_harness_tier1_drift_gates`, `harness_plugin_dedup`, `harness_audit_2026_06`) but all are about plugin audit/dedup — none capture the skill-vs-command decision rule. Net-new. Correct home = ai-harness ns (it's about this plugin's architecture).

### §2 — Cross-cutting promotion (persona.md target, not a new per-project memory)
Most recurring rules across namespaces are **already promoted to persona.md** → brain is well-maintained:

| recurring rule | seen in | persona status |
|----------------|---------|----------------|
| watch 지양 / event-driven | ert-dms, ert-dms-frontend | ✅ §2 watch/effect 기피 |
| server-side pagination 강제 | ert-dms-frontend | ✅ §2 성능 1급 |
| 3-5줄 접근법 후 승인 | ert-dms-frontend | ✅ global CLAUDE.md |
| i18n ko/en/zh parity | multiple | ✅ §2 |

**One not-clearly-covered candidate:** front-legacy's **"막히기 전에 결함·엣지케이스를 선제적으로 제기"** (User-Enforced, TOP PRIORITY) differs from persona §4 (mostly *reactive* pushback). If still a standing preference → one-line persona promotion. **Needs user confirmation** (legacy origin — do not self-edit persona).

### §3 — Structural observations (housekeeping, not additions)
- **`claude-brain` ns is empty**, and `claude-brain-ssot.md` itself notes brain-meta memory "still lives under ai-harness ns, not claude-brain — consolidate later" → a self-recorded pending move.
- **`astro-irregular-ice` ns** uses the old monolithic MEMORY.md style (all content inline, not one-file-per-fact + index) → inconsistent with the other 13.

### Decision
Initially **D** (analyze only), then reversed in the same session — user chose to do **A + B + C**. Applied; see Follow-ups.

---

## Follow-ups
1. **Commit `/debug` v1.13.0** (Part A) — still awaiting explicit go.
2. ✅ **§1 memory written** (2026-07-10) — `harness-capability-command-over-skill` (type `feedback`) added to ai-harness ns + MEMORY.md index updated.
3. ✅ **§3 brain-meta consolidation** (2026-07-10) — `claude-brain-ssot` moved ai-harness ns → **claude-brain ns** via `git mv` (history preserved), its ai-harness-local `Related:` wikilinks dropped, new `claude-brain/MEMORY.md` created. Auto-syncs via the brain's SessionEnd push hook. **Tradeoff:** brain-meta no longer auto-loads in ai-harness sessions (only when working in the claude-brain repo) — reversible via git if undesired.
4. ✅ **§2 persona promotion** (2026-07-10) — **Bounded** 승격 chosen. Added a `persona.md` §4 bullet: proactively flag correctness/data/hallucination/wrong-assumption/edge-case risks *unprompted*, but **flag-in-words only, no scope expansion** — reconciled with §4 scope-discipline (과잉수정 거부 / 묻는 말에 정확히).
5. (deferred) §3 remainder — `astro-irregular-ice` ns monolithic MEMORY.md → normalize to one-file-per-fact + index.
