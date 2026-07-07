---
name: take-over
description: "Take over a handed-off work-stream — the read/resume counterpart to the `handoff` skill. A handoff is a temp carrier: locate the `_docs/handoff/` doc, hydrate its linked spec (follow `related:`), verify its state claims against the actual repo (commits, branch, tests), then GRADUATE it into its durable `_docs` home — implement-now → `complete/`, needs-planning → a `plan` in `active/`, etc. — renamed to `_docs` grammar, never a bare delete. Use when picking up handed-off work, resuming a session where a handoff exists, or when told to take over / 인계받아. Distinct from `/checkpoint` (agent session-state restore)."
---

# Take-Over

The **read/resume counterpart** to the `handoff` skill. `handoff` writes the state layer (`_docs/handoff/YYYY-MM-DD-<topic>-handoff.md`); `take-over` **consumes** it.

A handoff is a **temp carrier** — an ephemeral bridge, not a durable record. So take-over never just reads it and never just deletes it: it hydrates the real design, verifies the claimed state against evidence, then **graduates the handoff into its proper `_docs` home** (a `complete/` archive, a `plan` in `active/`, …) with the name/`kind`/`status`/folder corrected to `_docs` grammar. A handoff's terminal state is always **gone, its content living in the right durable doc** — or kept-and-escalated when its state didn't verify.

The failures this prevents:
- **Resuming blind** — reading the handoff but not the spec it links, so you re-derive (or misread) the design the handoff deliberately did *not* duplicate.
- **Trusting a stale report** — taking "✅ done (commit abc)" at face value when the commit isn't on this branch or the tests don't pass. (Self-report distrust is a hard line.)
- **Handoff rot / content loss** — leaving a consumed handoff in `handoff/` to confuse the next session, OR bare-`git rm`-ing one that carried findings. Both lose the durable record. Graduation is the fix: the content lands in a properly-named `_docs` doc.

## When to use

- Picking up work handed off by another agent/session/teammate (a `_docs/handoff/` doc exists).
- Resuming a session and a handoff is present for the stream you're continuing.
- Told to "take over" / "인계받아" / "이 핸드오프 받아서 계속해".
- NOT for restoring your **own** interrupted session state — that is `/checkpoint` (agent-owned `.claude/session-state/`, a different bucket). NOT for writing a handoff — that is the `handoff` skill.

### Boundary vs `checkpoint`

| | `take-over` | `checkpoint` |
|---|---|---|
| Consumes | `_docs/handoff/` (project-owned doc) | `.claude/session-state/checkpoints/` (agent session-state) |
| For | cross-agent / cross-session **work intake** | your own **session recovery** across compaction/branch |
| Verifies state claims | **yes — against git/test evidence** | reconciles branch/files only |
| Fate of the source | **graduates** it into a durable `_docs` doc (complete/plan) — never a bare delete | keeps latest + history |

Do not conflate them. If both exist, a checkpoint restores *your* progress; a handoff transfers *someone else's* work — which you then graduate.

## Hard rules

1. **Hydrate, don't skim.** MUST follow every `related:` path and load the linked spec/plan before acting. The handoff is only the state layer — the design lives in the spec. A missing `related:` target is a dangling reference (docs-lifecycle I2): flag it and STOP before graduating.
2. **Verify before trust (self-report distrust).** Every falsifiable "done" claim in **State** MUST be checked against real evidence — the commit exists **and is reachable from the current branch**, tests/build are as claimed, named files/artifacts exist. Reconcile the handoff's as-of state with current `HEAD` (same branch? committed since? new uncommitted changes?).
3. **Never graduate on unverified or contradicted state.** If ANY claimed-done item fails verification, OR a `related:` spec is missing, OR the branch/worktree named in *How to resume* is gone → do NOT touch the handoff; surface the discrepancy and escalate. A handoff whose state was wrong must be reconciled by a human, not archived. Keeping a handoff is cheap; graduating a wrong one buries the error.
4. **Graduate — never bare-delete.** The handoff is a temp carrier; on confirmed intake it MUST become a durable `_docs` doc (destinations in the procedure). The `-handoff.md` file is removed only as the **tail of a docs-lifecycle move/merge transaction that has already placed its content in the destination**. Content never vanishes from the tree via a raw `git rm` (git history is a fallback, not the plan).
5. **Rename AND reshape to the destination format — graduation is not a relabel.** It re-homes both the name and the body:
   - **Name/frontmatter**: drop the `-handoff` suffix; set `kind`/`status`/folder to the destination's — e.g. `YYYY-MM-DD-<topic>-handoff.md` (`kind: handoff`, in `handoff/`) → `complete/<topic>/YYYY-MM-DD-<topic>.md` (`kind: impl|findings`, `status: complete`) or `active/planning/<date>/YYYY-MM-DD-<topic>-plan.md` (`kind: plan`, `status: planning`). Frontmatter `status`/`kind`/`topic`/`updated` move in lockstep; the `index.md` **Handoffs** row moves into the status list.
   - **Body**: re-author the prose into the destination bucket's native format. A handoff is written in state-layer voice — addressed to an incoming agent, a "⚠ read-this-first / TL;DR done-vs-not-done" state snapshot, a "how to resume" — and that framing is *transient*. Fold the durable content into the destination's sections (`complete/` → docs-lifecycle merge sections: Spec / Plan / Findings & Metrics / Final Summary; a `plan` → goal / approach / ordered steps / risks) and drop the now-resolved state chatter. **docs-lifecycle's "single doc → body unchanged" exception does NOT apply to a graduation** — a handoff is never already in the destination format, so its body always needs reshaping. Facts (commits, metrics, gotchas, runbook steps) are preserved; only the voice/structure changes.
6. **Delegate the mechanics to `docs-lifecycle`.** Graduation IS a docs-lifecycle transaction (status-move / merge-on-complete / deprecate): reference-safe (rewrite every inbound link, warn on `_note/`), `index.md`-serialized, primary-tree-only (resolve `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/_docs`). Do not hand-roll the move.

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

5. **Graduate** — run the chosen transaction: rename to `_docs` grammar, set frontmatter (`status`/`kind`/`topic`, bump `updated`), **reshape the body into the destination format (rule 5 — never leave handoff voice in a `complete`/`plan` doc)**, move to the destination folder, rewrite inbound links, move the `index.md` row from **Handoffs** into the status list, one commit (`docs: take over <topic> — graduate handoff → complete` / `→ plan`). Timing: for the implement-now / already-done branches graduate **after** the work is confirmed done; for the needs-planning branch, as soon as the `plan` doc exists (it, not the handoff, now carries the remaining work).
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
- `parallelization` — worktree path resolution + `_docs/` serialization when taking over inside a worktree.
