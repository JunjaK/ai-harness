---
description: "Take Over — resume a handed-off work-stream: hydrate the spec, verify the handoff's state against the repo, then graduate the handoff into its durable _docs home (complete/ or a plan)"
---

# Take Over

Pick up work left in a `_docs/handoff/` doc and resume it correctly — the read/resume counterpart to the `handoff` skill. A handoff is a **temp carrier**: this graduates it into a durable `_docs` doc, never leaves it lingering and never bare-deletes it.

## Usage

```
/take-over            # locate the handoff (or the latest if several), take it over
/take-over <topic>    # disambiguate when multiple handoffs exist
```

## What It Does

Invoke the `take-over` skill's intake procedure:

1. **Locate** — find `_docs/handoff/*.md` (0 → stop; 1 → use it; >1 → `<topic>` arg / latest `updated` / ask).
2. **Hydrate** — follow every `related:` and load the linked spec/plan. A dangling `related:` → flag and stop before graduating.
3. **Verify (self-report distrust)** — check each "done (commit X)" claim against evidence: commit reachable from `HEAD`, branch matches, tests/build as cited. Classify confirmed / contradicted / unverifiable. **Any contradiction → escalate, do not graduate.**
4. **Decide destination** — where the handoff graduates: implement-now → `complete/`; needs planning → a `plan` in `active/planning/`; a live `active/**` plan already exists → resume it; already finished → `complete/`; abandoned → `deprecated/`.
5. **Graduate (rename to `_docs` grammar, reference-safe)** — via a `docs-lifecycle` transaction: drop the `-handoff` suffix, set `kind`/`status`/folder, move the `index.md` row out of **Handoffs**, rewrite inbound links. The handoff's content lands in the durable doc — never a bare `git rm`. Verify failed → keep the handoff, escalate.
6. **Resume** — start the first Remaining-work item via *How to resume*, from the graduated doc.

## Boundary

- `/take-over` consumes a **project handoff doc** (`_docs/handoff/`). It is **not** `/checkpoint`, which restores your **own agent session-state** (`.claude/session-state/`). If you meant to resume your interrupted session, use `/checkpoint`.

## On Completion

```
🤝 TAKE-OVER <topic>
Hydrated:  <spec/plan paths>
Verified:  <n> confirmed · <n> contradicted · <n> unverifiable
Graduated: handoff → <complete/… | active/…-plan.md>  (renamed · kind:<x> · status:<y>)
           | KEPT — <specific reason>  (not graduated)
Resuming:  <first remaining item>
```

## Related

- `take-over` skill — full intake rules (hydrate / verify / decide / graduate), boundary table vs `checkpoint`
- `handoff` skill — the producer this consumes
- `docs-lifecycle` skill — the reference-safe move/merge/deprecate transaction + naming grammar graduation delegates to
