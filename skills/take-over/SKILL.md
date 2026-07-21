---
name: take-over
description: "Take over a handed-off work-stream — the read/resume counterpart to the `handoff` skill. A handoff is a temp carrier: locate the `_docs/handoff/` doc, hydrate its linked spec (follow `related:`), verify its state claims against the actual repo (commits, branch, tests), then GRADUATE it into its durable `_docs` home — implement-now → `complete/`, needs-planning → a `plan` in `active/`, etc. — renamed to `_docs` grammar, never a bare delete. Use when picking up handed-off work, resuming a session where a handoff exists, or when told to take over / 인계받아. Distinct from `/checkpoint` (agent session-state restore)."
---

# Take-Over

The **read/resume counterpart** to the `handoff` skill. `handoff` writes the state layer (`_docs/handoff/YYYY-MM-DD-<topic>-handoff.md`); `take-over` **consumes** it.

A handoff is a **temp carrier**, not a durable record: hydrate the real design → verify the claimed state against evidence → **graduate** it into its proper `_docs` home. Its terminal state is always gone-with-content-rehomed, or kept-and-escalated when the state didn't verify.

The failures this prevents: **resuming blind** (reading the handoff but not the spec it links); **trusting a stale report** ("✅ done (commit abc)" when the commit isn't on this branch); **handoff rot / content loss** (leaving a consumed handoff to confuse the next session, or bare-`git rm`-ing one that carried findings).

## When to use

- Picking up work handed off by another agent/session/teammate (a `_docs/handoff/` doc exists).
- Told to "take over" / "인계받아" / "이 핸드오프 받아서 계속해".
- NOT for restoring your **own** interrupted session state — that is `/checkpoint` (agent-owned `.claude/session-state/`, a different bucket). NOT for writing a handoff — that is the `handoff` skill.

### Boundary vs `checkpoint`

| | `take-over` | `checkpoint` |
|---|---|---|
| Consumes | `_docs/handoff/` (project-owned doc) | `.claude/session-state/checkpoints/` (agent session-state) |
| For | cross-agent / cross-session **work intake** | your own **session recovery** across compaction/branch |
| Verifies state claims | **yes — against git/test evidence** | reconciles branch/files only |
| Fate of the source | **graduates** it into a durable `_docs` doc (complete/plan) — never a bare delete | keeps latest + history |

If both exist: a checkpoint restores *your* progress; a handoff transfers *someone else's* work.

## Hard rules

1. **Hydrate, don't skim.** MUST follow every `related:` path and load the linked spec/plan before acting. The handoff is only the state layer — the design lives in the spec. A missing `related:` target is a dangling reference (docs-lifecycle I2): flag it and STOP before graduating.
2. **Verify before trust (self-report distrust).** Every falsifiable "done" claim in **State** MUST be checked against real evidence — the commit exists **and is reachable from the current branch**, tests/build are as claimed, named files/artifacts exist. Reconcile the handoff's as-of state with current `HEAD` (same branch? committed since? new uncommitted changes?).
3. **Never graduate on unverified or contradicted state.** If ANY claimed-done item fails verification, OR a `related:` spec is missing, OR the branch/worktree named in *How to resume* is gone → do NOT touch the handoff; surface the discrepancy and escalate. A handoff whose state was wrong must be reconciled by a human, not archived. Keeping a handoff is cheap; graduating a wrong one buries the error.
4. **Graduate — never bare-delete.** The handoff is a temp carrier; on confirmed intake it MUST become a durable `_docs` doc (destinations in the procedure). Its file disappears only once its content is already in the destination — never via a raw `git rm`.
5. **Reshape the body, don't just relabel it.** A handoff is written in transient state-layer voice — "⚠ read-this-first", done-vs-not-done snapshot, "how to resume". Re-author that prose into the destination's native sections (`complete/` → Spec / Plan / Findings & Metrics / Final Summary; a `plan` → goal / approach / ordered steps / risks) and drop the resolved state chatter. Facts (commits, metrics, gotchas, runbook steps) are preserved; only voice and structure change. **docs-lifecycle's "single doc → body unchanged" exception does NOT apply** — a handoff is never already in the destination format.
6. **Delegate the mechanics to `docs-lifecycle`.** Graduation IS a docs-lifecycle transaction (status-move / merge-on-complete / deprecate); it owns the renaming grammar, frontmatter lockstep, reference-safe rewrite, `index.md` serialization, and primary-tree path resolution. Do not hand-roll the move.

## Procedure

1. **Locate** — enumerate `_docs/handoff/*.md`.
   - 0 → report "no handoff found" and stop (offer `/checkpoint` if the user meant their own session).
   - 1 → use it.
   - >1 → pick by the `[topic]` arg, else the most-recently `updated`; if still ambiguous, list them and ask.
2. **Read + hydrate** — parse the frontmatter + body (State / Remaining work / How to resume / Open questions / Pointers). Follow every `related:` path and load the spec/plan. Any `related:` that doesn't resolve → flag (I2) and STOP before graduating.
3. **Verify state (self-report distrust)** — build a ledger from **State**:
   - commit claims: `git cat-file -e <sha>^{commit}` (exists) **and** `git merge-base --is-ancestor <sha> HEAD` (reachable here);
   - branch: `git branch --show-current` vs the handoff's; `git status --short` for uncommitted drift; "committed since" vs "still open";
   - test/build claims: re-run the exact command the handoff cites, or mark **unverifiable** (never assume green).
   - Classify each item **confirmed / contradicted / unverifiable**. Any **contradicted** → escalate, no graduation (rule 3).
4. **Decide the destination** — from **Remaining work** + the hydrated spec, pick where the handoff graduates:

   | Intake finding | Graduates to | docs-lifecycle transaction |
   |---|---|---|
   | Small enough → implement now | do the work, then → `complete/<topic>/YYYY-MM-DD-<topic>.md` | merge-on-complete (fold handoff + spec/plan into one) |
   | Needs detailed planning first | → `active/planning/<date>/YYYY-MM-DD-<topic>-plan.md` (`kind: plan`), seeded from Remaining work + spec | create / status-move |
   | `related:` already a **live `active/**` plan** | resume THAT (planning→processing if starting impl); the handoff is removed as a superseded sidecar (content already lives in the plan) | status-move + reference-safe removal |
   | Work is already finished (a "done" handoff) | → `complete/<topic>/` (merge its findings) | merge-on-complete |
   | Abandoned / obsoleted | → `deprecated/` (rationale worth keeping) or `git rm` (pure noise) | deprecate |

5. **Graduate** — hand the chosen transaction to `docs-lifecycle`, supplying only what it can't infer: the destination, and the **reshaped body** (rule 5 — never leave handoff voice in a `complete`/`plan` doc). One commit (`docs: take over <topic> — graduate handoff → complete` / `→ plan`). Timing: implement-now / already-done branches graduate **after** the work is confirmed done; the needs-planning branch graduates as soon as the `plan` doc exists (it, not the handoff, now carries the remaining work).
6. **Resume** — begin the first **Remaining work** item via *How to resume* (branch / worktree / commands / env preconditions). Normal execution proceeds from the graduated doc, never the handoff.

## Output

Emit a compact intake report:

```
🤝 TAKE-OVER <topic>
Hydrated:  <spec/plan paths loaded>
Verified:  <n> confirmed · <n> contradicted · <n> unverifiable
Graduated: handoff → <complete/… | active/…-plan.md>  (renamed + body reshaped to <complete|plan> format · kind:<x> · status:<y>)
           | KEPT — <specific contradiction / missing spec>  (not graduated)
Resuming:  <first remaining-work item>
```

If **KEPT**, the report MUST name the specific contradiction or missing reference (never a vague "couldn't verify"), so the human can reconcile it.

## Related

- `handoff` — the producer; writes the temp doc this skill consumes and graduates.
- `docs-lifecycle` — owns `_docs/` layout, the reference-safe move/merge/deprecate transactions, the naming grammar, the topic vocabulary, and the primary-tree concurrency rule that graduation obeys.
- `checkpoint` — the session-state counterpart (agent-owned); see the boundary table above.
