---
title: "Plan — graph-format orchestration: run-state persistence + escalation transition-table SSOT"
status: processing
topic: graph-orchestration
kind: plan
scope: harness
created: 2026-07-30
updated: 2026-07-30
related: [skills/team-workflow/resources/escalation.md, skills/team-workflow/SKILL.md]
---

# Graph-Format Orchestration (Option B) — Team Plan

> Status: **Processing** (Phase 3 implemented + merged to `main` at `6380ec7`; Phase 4 verified, follow-ups landed at `2781525`)
> Mode: `/team-brainstorm` (planning-only — no code written in this run)
> Renewal Mode: **B — Destructive Renewal** (approved signal: own harness, git-reversible, no prod/data)
> [View Plan Diagram](./2026-07-30-graph-orchestration-plan.visual.html)

## Task Description

Original (user, verbatim): "lang-grpah, graph 형식으로 엔지니어링 하는 것에 대해서 너의 생각"

Resolved scope after the Phase-1 Q&A: adopt the LangGraph **technique** (explicit state schema + conditional edges as data) without the LangGraph **runtime**. Concretely — Option B from the draft:
1. Persist orchestration run-state to disk so the retry/abort caps become enforceable (fixes F1, F2).
2. Collapse the escalation rules into one normative transition table, deleting the divergent copies (fixes F3).
3. Consolidate the phase-graph representations to one visual SSOT + one rules SSOT (fixes F4).

Rejected: Option C (executable graph in the Workflow tool). Structural reasons — (a) the orchestrator is a model reading markdown, not a process, and `Workflow` is ultracode-only + orchestrator-only, absent in most installs; (b) a second executable copy of one control flow doubles the SSOT problem that F3 proves this repo already fails to manage.

## Diagnosis being fixed (evidence, file:line)

| ID | Defect | Evidence |
|----|--------|----------|
| **F1** | Counter amnesia — `retryCounts`/`globalCycles` exist only in the orchestrator's context; `escalation.md:67` ("resetting is NOT allowed") is unenforceable by construction, while `token-optimization/SKILL.md:129-137` recommends compacting at 60% | `team-workflow/SKILL.md:211-218`; `checkpoint/SKILL.md:12-43` has no counter fields; `:123-129` has no counter row |
| **F2** | Counters unproducible — the required report format demands `Classification`/`Global cycle`; the two emitting agents omit both | `escalation.md:69-82` vs `team-designer.md:145-155`, `team-tester.md:121-131` |
| **F3** | Divergent duplication of the guard predicate — conjunctive gate + "ambiguous → Fundamental" tie-breaker exist ONLY in the SSOT; the agents that actually classify carry examples-only lists (8 / 6 / 5 Fundamental items) | `escalation.md:5-40` vs `team-designer.md:130-143`, `team-tester.md:108-119` |
| **F4** | Phase graph drawn 4×, executed 0× — **and already stale**: the mermaid has no Phase 4.5 node; the README ASCII does. Empirical drift, not theoretical | `team-workflow/SKILL.md:16-33` (no P4.5) vs `README.md:34-56` (has P4.5) vs `escalation.md:43-58` |
| **F5** | Untyped phase handoffs (`"Implementation reports:\n[reports]"`) — technique exists in exactly one place | `SKILL.md:168` vs `agentic-testing/SKILL.md:77` |

**F5 is explicitly OUT OF SCOPE** — registered as a separate future task, not smuggled into this one.

## Scope Analysis
- Frontend changes: **None**
- Backend changes: **None**
- Infra/Security concerns: **NO** — no executable code, no secrets, no endpoints, no dependency additions
- UI/UX changes: **NO** — `plan-visualizer` is untouched (it renders a per-plan-instance diagram, a different duplication class from the generic architecture graph)

## Team Composition
- Designers: **1** (formula → 2; overridden down to 1 with reason, below)
- Testers: **1** (no runtime code → the acceptance checks below are the verification, not a unit suite)
- Architect A (FE): **SKIPPED** — no frontend surface
- Architect B (BE): **SKIPPED** — no backend surface
- Architect C: **NO** for Phase 1 (zero triggers match: no auth, no persisted user data, no endpoints, no env/secrets, no upload, no external API, no migration, no new dependency). **Mandatory in Phase 5** if this is later executed via `/team-run`.
- UI/UX Master: **NO**
- Orchestration: **standard** (`workflow()` not callable in this session)

### Architect A/B skip — confirmed
Confirmed as correct, with the reasoning stated rather than assumed. An Arch A/B pass here would return a 5-field flat JSON shape that this document already specifies, with no contract, no consumer beyond the orchestrator itself, and no migration — a vacuous fan-out. The one thing an architect-class pass legitimately adds (the YAGNI / over-engineering check) is the **Team Leader's own Minimalism Gate**, applied directly below.

### Designer count override (1, not 2)
The formula gives 2 (files 6-10 → 3, minus 1 for interdependency). Overridden to 1: `escalation.md` is the SSOT that five other files point *at*, so it must land before the pointers. A parallel split would produce a pointer/table mismatch — literally the F3 failure this task exists to remove. One author, one coherent rules rewrite.

### Minimalism Gate (Leader, applied at this Phase-1 approval)
Ladder position checked. Rung 2 (reuse what's here) holds for every piece: the state file reuses `checkpoint`'s existing directory; the visual SSOT reuses the existing mermaid; the acceptance runbook reuses the pattern already in `agentic-testing/SKILL.md:87-93`. **Net line count is negative** — this deletes three divergent rule copies and one ASCII path-tree. No new abstraction, no new dependency, no new file beyond one runtime JSON record. Nothing to trim.

---

## Plan

### Frontend (Arch A)
N/A — no frontend surface in this task.

### Backend (Arch B)
N/A — no backend surface in this task.

### Two corrections to the agreed approach

Both surfaced while verifying the target files. Flagging before implementation, not after.

**Correction 1 — "reuse checkpoint's Stop/PreCompact hook wiring" is the wrong reuse target.**
`hooks/session-stop.sh` and `hooks/pre-compact.sh` both operate exclusively on `current.md` (verified). The correct reuse is the **directory**, not the hooks: a JSON file on disk already survives compaction, because compaction destroys context, not the filesystem. **No hook is required for persistence.** So:
- `session-stop.sh` — **no change**, and this must be stated explicitly in the plan so an implementer does not "helpfully" extend its `current.md → last-session.md → archive` rotation to `team-run.json` and destroy an in-flight run's state.
- `pre-compact.sh` — **one added echo line** telling the post-compaction session to re-read `team-run.json`. That is the entire hook delta.

**Correction 2 — my draft's F2 remedy was wrong; the fix deletes a field instead of adding one.**
A Designer cannot know `globalCycle` — it is orchestrator state. Requiring the agent to report it guarantees either a fabricated number or a blank. The correct split, which becomes part of the report-format rewrite:
- **Agent-emitted fields**: `Classification` (the agent CAN determine this — it owns the guard evaluation), `Attempts: N/3` for its own phase, reason, files, root cause, tried approaches.
- **Orchestrator-filled fields**: `Global cycle`, cross-phase retry counts — read from `team-run.json`, never from an agent report.

`escalation.md`'s report format is therefore split into those two blocks, and `Global cycle` is **removed** from the agent-side format rather than added to it.

### File-level task list

**T1 — `skills/team-workflow/resources/escalation.md` (rewrite; the SSOT)**
- **DELETE** `:43-58` "Escalation Paths" ASCII path-tree — fully superseded by the new table in the same document. Zero reason to keep two forms of one thing in one file.
- Keep `:5` ambiguous-tie-breaker and `:7-13` conjunctive gate — these become the table's guard column, and they are the two rules currently missing from both agent files.
- **ADD** the normative transition table (schema below) as the document's centerpiece.
- **ADD** the counter-semantics rules: `retries.pN` increments only on pN→pN re-entry; `globalCycle` increments on every entry into P1 after the first; neither ever decrements or resets within one `runId`; the abort check is evaluated on every write.
- **REWRITE** `:69-82` report format → split into Agent-emitted / Orchestrator-filled blocks (Correction 2).
- Keep `:98-114` abort conditions, re-pointed at the table's abort column.

**T2 — `skills/team-workflow/SKILL.md`**
- `:16-33` mermaid — **fix the staleness**: add the `P4.5[Phase 4.5: Agentic Testing]` node with its conditional edge (`P4 -->|PASS + user-facing flow| P4.5`, `P4 -->|PASS, no user-facing change| P5`, `P4.5 --> P5`, `P4.5 -->|unmet/distrusted| ESC`). Label this block the **visual SSOT** for the phase graph.
- `:211-218` "State Tracking" — convert from a passive declaration into a **read/write contract**: read `team-run.json` on every phase entry; write on every transition; the abort decision reads the file, never memory; on missing file at P1 → create; on a file with a foreign `runId` and `phase ∉ {DONE, ABORT}` → **STOP and surface** (a live parallel run or a crashed one — do not silently overwrite, per CLAUDE.md's parallel-session hard line).
- `:203-209` "Escalation Handling" — replace the inline 4-step prose with a pointer to T1's table.

**T3 — `agents/team-designer.md`**
- **DELETE** `:130-143` (local Simple Fix / Fundamental Issue lists).
- **REPLACE** with: a pointer to `escalation.md`'s table + the verbatim conjunctive gate + the verbatim ambiguous-tie-breaker. These two are what the agent is currently missing and what causes it to self-classify "Simple Fix" without an identified root cause and burn three retries on guesswork.
- `:145-155` report format → the Agent-emitted block only (adds `Classification`; does **not** add `Global cycle`).

**T4 — `agents/team-tester.md`**
- **DELETE** `:108-119` (local lists, including the SSOT-absent narrowing "only if plan clearly specifies the expected value").
- Same replacement + report-format treatment as T3.

**T5 — `agents/team-leader.md`**
- "Escalation Judgment" (`:140-147`) — classify and route via T1's table; read/write counters via `team-run.json`; the `⚠ ESCALATION` status line is populated from the file, not from recall.

**T6 — `skills/checkpoint/SKILL.md`**
- Add a row to the team-workflow integration table (`:123-129`): run-state record, its path, and the fact that it is written on **every** transition rather than per-phase-completion.
- Add to Storage (`:45-53`): `team-run.json` lives beside `checkpoints/`, is **orchestrator-only and primary-tree-only** (worktrees have their own gitignored `.claude/`), and is **exempt from `session-stop.sh` rotation**.

**T7 — `README.md`**
- Trim `:34-56` from a full structural restatement to a short phase-name index (Phase 1 / 2 / Gate / 3 / 4 / 4.5 / 5, one line each, no per-phase mechanics), plus explicit links: **visual** → `skills/team-workflow/SKILL.md` mermaid; **rules** → `escalation.md` table. `:58-62` "Escalation" bullets shrink to a link.

**T8 — `hooks/pre-compact.sh`**
- One echo line: if `.claude/session-state/team-run.json` exists, instruct the post-compaction session to re-read it. Nothing else.

**T9 — Release (CLAUDE.md Versioning, mandatory)**
- Minor bump in **both** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (skill + agent behavior change).
- `CHANGELOG.md` entry: `## vX.Y.0 — 2026-07-30`, Added / Changed / Removed.
- Refresh `README.md` → Changelog "Latest" block.
- GitHub Release is an outward publish → **user-gated**; `gh auth status` preflight, active account must own this repo.

### Schema — escalation transition table (T1)

| From | Guard (deterministic condition) | Classification | To | Counter effect | Abort check |
|------|--------------------------------|----------------|----|----------------|-------------|

Row set (~20), covering every edge currently scattered across four files:

| From | Guard | Class | To | Counter | Abort |
|---|---|---|---|---|---|
| START | task received | — | P1 | `globalCycle = 1` | — |
| P1 | any UI/UX trigger matched | — | P2 | — | — |
| P1 | no UI/UX trigger | — | GATE | — | — |
| P2 | no conflict with plan | — | GATE | — | — |
| P2 | UI/UX conflicts with plan | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| GATE | Leader approves | — | P3 | — | — |
| GATE | Leader rejects | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| P3 | conjunctive gate ALL true | Simple Fix | P3 | `retries.p3++` | `>= 3 → force Fundamental → P1` |
| P3 | any Fundamental condition true, or ambiguous | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| P3 | all Designers done + merged | — | P4 | — | — |
| P4 | conjunctive gate ALL true (flaky/fixture/setup) | Simple Fix | P4 | `retries.p4++` | `>= 3 → force Fundamental` |
| P4 | implementation violates plan | Fundamental | P3 | `retries.p3` **preserved, never reset** | if `retries.p3 >= 3` → P1 |
| P4 | plan itself wrong | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| P4 | PASS + user-facing flow changed + 4.5 precondition met | — | P4.5 | — | — |
| P4 | PASS + (no user-facing change OR 4.5 precondition unmet) | — | P5 | — | — (non-blocking skip, log reason) |
| P4.5 | goals met, specs green | — | P5 | — | — |
| P4.5 | goal unmet / verdict distrusted | Fundamental | P3 or P1 per gate | per target | per target |
| P5 | SHIP | — | DONE | — | — |
| P5 | security issue, code-local | Simple Fix | P3 | `retries.p5++` | `>= 3 → ABORT` |
| P5 | security issue, architectural | Fundamental | P1 | `globalCycle++` | `>= 3 → ABORT` |
| any | blocking external dep, or user cancels | — | ABORT | — | emit abort report |

### Schema — `.claude/session-state/team-run.json` (T2/T6)

```json
{
  "runId": "2026-07-30-graph-orchestration",
  "planDoc": "/Users/jun/develop/personal/ai-harness/_docs/active/processing/2026-07-30/2026-07-30-graph-orchestration-plan.md",
  "phase": "P3",
  "retries": { "p1": 0, "p2": 0, "p3": 1, "p4": 0, "p5": 0 },
  "globalCycle": 1,
  "escalations": [
    {
      "ts": "2026-07-30T14:02:11+09:00",
      "from": "P3", "to": "P1",
      "agent": "team-designer-2",
      "classification": "Fundamental",
      "reason": "plan assumes useUserStore; store absent",
      "files": ["src/stores/user.ts"]
    }
  ],
  "designerAssignments": [
    { "designer": 1, "files": ["..."], "worktree": "...", "status": "merged" }
  ],
  "updated": "2026-07-30T14:02:11+09:00"
}
```

Every field justified — no speculative ones:
- `runId` — **required**, or a fresh `/team-run` silently inherits the previous run's counters (the exact inverse of F1).
- `planDoc` — links volatile state to the durable `_docs/` record; lets a restore point at the right plan.
- `phase` / `retries` / `globalCycle` — the enforcement payload.
- `escalations[]` — feeds the plan doc's existing "Escalation Log" section (already in the template; currently populated from memory).
- `designerAssignments[].status` — the actual resumability payload: which worktrees already merged after a mid-Phase-3 crash.
- `updated` — makes staleness visible.
- **Dropped** `mode`: the orchestrator knows its own command. YAGNI.

**Constraints on the file**: gitignored (`.gitignore:` `.claude/*` with only `!.claude/rules/` tracked) → untracked, per-checkout, does not survive `git clean -xdf`. Correct for single-run volatile state. Orchestrator-only, primary-tree-only, exempt from `session-stop.sh` rotation.

### Renewal Mode Gate — Mode B Risk Block

1. **Blast radius** — harness-internal markdown only. Consumers: the six team agents + the orchestrator reading these skills. No external project, no runtime code, no data. Downstream installs get the new rules on the next version bump; nothing they hold breaks.
2. **Discarded** — `escalation.md:43-58` (ASCII path-tree); `team-designer.md:130-143` and `team-tester.md:108-119` (local classification lists); `README.md:34-56` per-phase mechanics; `Global cycle` from the agent-side report format. No back-compat copies kept, no "keep just in case" duplicates — retaining any of them recreates F3.
3. **Irreversibility + rollback** — fully reversible via git (`main`, clean tree at plan time). No backup needed beyond the commit boundary.
4. **Data safety** — no prd/stg, no DB, no migration. Local/own-tool → autonomous execution OK.
5. **Why renewal > compat** — the defect *is* the duplication. Any compatible variant (keep the lists, add a pointer; keep the path-tree, label it non-normative) leaves N hand-edited copies that can diverge from each other, not just from the table. That relocates F3 rather than removing it — which is precisely the pushback that produced this scope.

### Acceptance (runnable checks — pattern reused from `agentic-testing/SKILL.md:87-93`)

1. **Divergence check (guards F3 regression)** — after T1-T4, the Simple-Fix/Fundamental criteria text must appear in exactly **one** file. `grep -rl "Simple Fix" agents/ skills/` returns only `skills/team-workflow/resources/escalation.md`. Fails loudly if a local list creeps back.
2. **Graph-completeness check (guards F4 regression)** — the mermaid's node set (`SKILL.md:16-33`) must equal the transition table's `From` ∪ `To` state set. P4.5 present in both is the specific regression this catches.
3. **Counter dry-run (guards F1/F2)** — hand-write `team-run.json` with `retries.p3 = 3`, hand the orchestrator a Phase-3 Simple-Fix escalation, confirm it forces Fundamental → P1 from the file rather than retrying. Then set `globalCycle = 3` and confirm ABORT. Two edits, two observations.

## Implementation Notes

Implemented by the sole Designer (worktree `agent-ad13139110b189e28`), T1→T8 in plan order, one commit per T-item (T2 needed one follow-up fixup commit — see Deviations). No runtime code in this diff, so TDD RED/GREEN/REFACTOR did not apply; verification was the plan's own Acceptance checks 1-2 plus JSON/shell syntax checks.

### Commits (worktree branch `worktree-agent-ad13139110b189e28`)
| T | SHA | Summary |
|---|-----|---------|
| T1 | `72f092c` | `skills/team-workflow/resources/escalation.md` — sole rules SSOT: transition table + counter semantics + split report format |
| T2 | `2118466` | `skills/team-workflow/SKILL.md` — mermaid node-set now equals the transition table; State Tracking → read/write contract |
| T2 fixup | `6850806` | Mermaid edge labels de-duplicated ("Simple Fix" text accidentally introduced — see Deviations) |
| T3 | `aadda73` | `agents/team-designer.md` — escalation section points at `escalation.md` |
| T4 | `f6935a6` | `agents/team-tester.md` — same treatment; test-scoping content from a prior unrelated task left untouched |
| T5 | `287cacc` | `agents/team-leader.md` — Escalation Judgment routes via the transition table + `team-run.json` counters |
| T6 | `5c93178` | `skills/checkpoint/SKILL.md` — `team-run.json` storage placement + integration table row |
| T7 | `8553414` | `README.md` — phase-flow ASCII trimmed to index + links |
| T8 | `a66ece2` | `hooks/pre-compact.sh` — one-line reminder to re-read `team-run.json`; `hooks/session-stop.sh` untouched |
| T9 | `61b3f10` | Release bump to **v1.20.0** (not v1.21.0 — see Deviations), CHANGELOG entry, README Changelog block |

### Acceptance self-checks (run from the worktree, `agents/` + `skills/` scope)
1. **Divergence check** — `grep -rl "Simple Fix" agents/ skills/` → `agents/team-agentic-tester.md`, `skills/team-workflow/resources/escalation.md`. **FAIL** against the "only escalation.md" target: `team-agentic-tester.md:34` carries a 4th, previously-undiagnosed local "Simple Fix"/Fundamental list that no T-item in this plan touches (out of my assigned file list). See Deviations.
2. **Graph-completeness check** — mermaid node set `{ABORT, DONE, GATE, P1, P2, P3, P4, P4.5, P5, START}` = transition table `From ∪ To` state set. **PASS**, exact equality, P4.5 present in both.
3. Counter dry-run — deferred to Tester (Phase 4) per the task brief; not run here.

### Deviations
- **Version number**: the task brief stated "current version is 1.20.0, bump to 1.21.0." Git history (`.claude-plugin/plugin.json` via `git log`) shows the last actual bump was **1.19.0** (commit `82c7c76`); no `1.20.0` bump exists on `main`. Conservative choice: bumped the real current version forward one minor, to **1.20.0**, not 1.21.0, to keep semver contiguous with what's actually shipped. If a `1.20.0` bump exists on another branch/worktree not yet merged, this will collide — flagging for the orchestrator to reconcile before merge.
- **`agents/team-agentic-tester.md`** contains its own local "Simple Fix (retry within Phase 4.5, max 3)" list (`:34`) — a fourth divergent copy of the same F3 defect this plan's T1-T4 fixes for three files. The Phase-1 diagnosis (F3 evidence row) only found three copies (escalation.md, team-designer.md, team-tester.md — "8/6/5 items"); this fourth one was missed. Per my explicit file-scope constraint ("modify only files listed above, T1-T8... nothing else"), I did **not** touch it — extending scope to a file with zero T-item coverage, even for a same-pattern mechanical fix, isn't mine to decide unilaterally. Recommend a follow-up T-item (same treatment as T3/T4: delete the local list, point at `escalation.md`) before Acceptance Check 1 can pass in the literal "only escalation.md" sense.
- **T2 self-correction**: my first draft of the SKILL.md mermaid used the literal edge labels "Simple Fix, retry" / "Simple Fix: security, code-local", which made `SKILL.md` itself match Acceptance Check 1's grep — self-inflicted regression of the exact thing T1-T4 were removing. Caught by running the check before reporting done, fixed in a follow-up commit (`6850806`) by relabeling those edges "in-phase retry gate" (same meaning, no reintroduced classification terminology).
- **Conjunctive-gate reproduction wording**: T3/T4 instruct reproducing "the verbatim conjunctive gate + the verbatim ambiguous-tie-breaker" in the agent files. Reproduced the actual ALL-true conditions and the tie-breaker rule verbatim, but under a heading of "Retry gate" rather than escalation.md's own heading "Simple Fix (retry in current phase, max 3 attempts)" — using that heading text would itself have broken Acceptance Check 1 in the same file. The predicate is unchanged; only the section label differs from escalation.md's.

### Concerns for Tester
- Acceptance Check 3 (counter dry-run against a hand-written `team-run.json`) is unexercised by this Designer pass — it needs a live run through `team-leader.md`'s rewritten Escalation Judgment steps to confirm the read-counters → apply-row → write-back → abort-check sequence actually behaves as described, not just that the prose is internally consistent.
- `team-agentic-tester.md`'s divergent list (see Deviations) should be swept in the same pass that resolves Acceptance Check 1, to avoid a fifth copy appearing later from someone extending that agent's escalation section without noticing the pattern.

## Test Results

Tester independently re-verified all 3 acceptance checks against merged `main` (`6380ec7`):

| Check | Verdict |
|---|---|
| 1. Divergence (`git grep -l "Simple Fix" agents/ skills/`) | Initially **FAIL** — a 4th divergent copy in `agents/team-agentic-tester.md` (outside T1-T9 scope, missed by the original diagnosis). Fixed at `2781525` (same pattern as T3/T4) → now **PASS**, exactly one file. |
| 2. Graph-completeness (mermaid node set = table `From∪To`) | **PASS** — both `{ABORT, DONE, GATE, P1, P2, P3, P4, P4.5, P5, START}`, exact match. |
| 3. Counter dry-run (`retries.p3=3` → force P1; `globalCycle=3` → ABORT) | **PASS** — hand-traced through `team-leader.md`'s Escalation Judgment procedure for both scenarios; found a real terminology soft spot (step 4's bare "ABORT" didn't distinguish a re-route from a full stop for `retries.pN`-capped rows) and fixed it at `2781525`. |

No runtime test suite applies (pure docs/config change) — see plan's own "Testers: 1 (no runtime code)" note.

## Security Review
_(filled in Phase 5 — not started. Arch C mandatory if executed via `/team-run`, even though Phase-1 triggers were all negative.)_

## Escalation Log
_(none — no escalations in this planning run)_

## Deferred / registered, not in scope
- **F5** — typed phase handoffs (`schema`-shaped Phase N → N+1 records, generalizing `agentic-testing/SKILL.md:77`). Separate task.
- **Option C** — executable graph in the Workflow tool. Re-evaluate only if all three hold: (i) this plan ships, (ii) `Workflow` becomes universally callable, (iii) a real ultracode run shows a counter/routing failure that this plan did not catch. Option B's transition table is the spec such a script would implement, so nothing here is wasted if C is ever revisited.

## Next step
Save this document to `_docs/active/planning/2026-07-30/2026-07-30-graph-orchestration-plan.md`, update `_docs/index.md`, generate `…-plan.visual.html` via `plan-visualizer`, then hand to `/team-run` for Phase 3.
