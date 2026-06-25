---
title: "Plan — /team-new: greenfield project bootstrap (deep-research → scaffold → profile)"
status: planning
topic: team-new
kind: plan
scope: harness
created: 2026-06-25
updated: 2026-06-25
related: [_docs/active/planning/2026-06-25/2026-06-25-docs-lifecycle-plan.md]
---

# Plan — /team-new

> Sub-project **#1 of 3**. Depends on **#2** (docs-lifecycle v2 layout + reserved `project-bootstrap` topic + handoff skill + merge-on-complete). Fills the harness's missing entry point: bootstrapping a brand-new project from zero — `/team-init` and `team-workflow` both assume code already exists.

## Goal

`/team-new <one-line idea>` takes an empty/near-empty repo to: **researched + scaffolded + profiled**, then hands off to `/team-run` for the first feature. Deliverable boundary = **scaffolding + `.claude/project-profile/`** (not the first feature).

## Flow (G0–G5)

```
G0 intake      team-leader interactive: target users / platform (web·mobile·CLI·API·backend-only) /
               must-have first features / hard constraints / non-goals
               → brief doc (kind: brief)  AND a FULLY-SCOPED research question (see G1 contract)
G1 research    invoke the deep-research bundled WORKFLOW with the framed question as args;
               capture the RETURNED report text; WE write it to the research doc (kind: research)
G2 decision    team-architect-fe + -be (parallel) consume brief+research → propose stack/structure;
               TeamCreate cross-review (+infra if auth/payments/deploy); leader consolidates
               → stack-decision doc (kind: stack-decision) incl. exact scaffold command + harness-layer + forward-looking conventions
G3 ★USER GATE  present research summary + recommended stack + exact scaffold commands; APPROVE / edit→G2 / reject→rollback
G4 scaffold    run official CLI (non-interactive) + harness layer + git first-commit
G5 profile     project-analyzer in SEEDED MODE: scan the scaffold + inject the stack-decision
               → .claude/project-profile/ (9 docs)
handoff        merge brief+research+decision → complete/project-bootstrap/; "run /team-run <first feature>"
```

## Must-fix groundings (from adversarial review)

### G1 — deep-research is a CLI-bundled WORKFLOW, not a Skill/plugin
- **Invoke** via the framed question as args (it decomposes "question (from args)" into 5 search angles). It RETURNS a cited report as text — **no file side-effect**.
- **Capture = return-then-write-ourselves**: the command writes the returned text to `_docs/active/planning/<date>/<date>-project-bootstrap-research.md` (frontmatter: status planning, topic `project-bootstrap`, kind `research`, `related:`→brief). **Never poll for a workflow-written file.**
- **Soft-degrade = capability probe**, not a disk/plugin check: if deep-research is absent from the session roster / WorkflowTool disabled / SIMPLE-mode CLI → fall back to architects running `WebSearch` directly, with a loud warning: *"research depth reduced — proceeding with direct WebSearch."* **No install instruction** (it ships with the CLI; there is nothing to install).
- **Non-interactive handoff**: deep-research may ask 2–3 clarifying questions only when under-scoped. G0 EXISTS to pre-empt that — it MUST emit a self-contained question (domain + platform + first-features + constraints + the exact stack/architecture decision being researched) so G1 hits the "specific enough" branch and never stalls.

### G3 — invariant scoped + rollback + idempotency
- "Nothing written before G3" applies to the **project SOURCE tree only** (no scaffold/package.json/src/). The brief/research/decision ARE written to `_docs/` pre-G3 (they're what the user reviews at G3).
- **Reject/Ctrl-C rollback**: on G3 reject, move brief/research/decision → `deprecated/` with a `g3-rejected` note (preserves research cost); if the repo is otherwise empty, offer to delete them.
- **Re-run idempotency guard**: a second `/team-new` detects an in-flight bootstrap (brief doc present, no G4 commit) → resume/replace, never duplicate.

### G4 — scaffold robustness
- **Non-empty guard precision**: refuse only if real project files exist (`package.json`, `src/`, `tsconfig`, `node_modules`). ALLOW `.git`, `README*`, `LICENSE*`, `.gitignore`, and the `_docs/` the bootstrap itself wrote. If real project → "use `/team-init`, not `/team-new`."
- **Scaffolder sees a non-empty dir** (because G0–G2 wrote `_docs/`): use each CLI's "scaffold into current/non-empty dir" flag, or scaffold into a temp subdir then move. `scaffold-recipes.md` pins this per CLI.
- **Pin exact non-interactive invocation per CLI** (consult Context7 at G2 for current flags) + a bounded **timeout**; on timeout/non-zero exit → ABORT G4, capture stderr, leave no half-scaffold. The G3-approved command MUST be the one that runs (verify flags before G3).
- **No-official-CLI fallback**: if the chosen stack has no non-interactive scaffolder (SolidStart/Astro/SvelteKit/Bun-native/backend-only Hono/Elysia) → documented "manual scaffold" (dirs + package.json + tsconfig + entry from the framework's minimal layout via Context7). G3 shows which path runs. `backend-only` is a first-class G2 outcome (no UI scaffolder; ui-components.md + Phase-2 UI/UX skipped).
- **Layer = edit-not-overwrite**: detect the scaffold's tsconfig and ADD `strict`/`noUncheckedIndexedAccess` (preserve framework `jsx`/`paths`/`moduleResolution`); if the scaffolder ran its own `git init`/commit, skip ours or add the harness layer as a **second** commit. **Define G5's `Profile-Generated-At` = the FINAL bootstrap commit SHA.** Last G4 step: confirm the strict-tsconfig change still type-checks (absolute-zero baseline gate).

### G5 — project-analyzer SEEDED MODE (more than a new section)
- New `## Seeded Mode` in `project-analyzer/SKILL.md` (mode-overlay parallel to Update Mode), called by G5.
- **Third status token `🌱 Seeded`** added to `profile-templates.md` legend + index Status column (distinct from `✅` scanned and `⏭️ Skipped`).
- **Override Step 4/5 skip rules** under the seeded flag: do NOT skip api-layer.md / state-management.md — **inject** from the stack-decision doc (planned client + generated-vs-manual + generator/regen command + auth + base-URL env; planned state library + store patterns).
- **Provenance line** on each seeded doc: *"Source: injected from `<stack-decision path>`, not yet observed in code — re-verify on `/team-init --update`."* Next `--update` re-scans and upgrades `🌱 → ✅`.
- Step 3 fallback: <5 source files → derive style from formatter config, mark provisional.
- **INPUT CONTRACT** (shared verbatim by G5 + Seeded Mode): the stack-decision doc fields listed above.

## docs-lifecycle integration (uses #2)
- Bootstrap docs live in `active/planning/<date>/` as `project-bootstrap` sidecars (`-brief`/`-research`/`-stack-decision`), the **reserved** topic (feature work MUST NOT reuse). `/team-new` writes the first vocabulary entries (resolves the empty-vocab chicken/egg).
- On successful G5, merge-on-complete → `complete/project-bootstrap/<date>-project-bootstrap.md`; final handoff via the `handoff` skill.

## Components

| File | Change |
|------|--------|
| `commands/team-new.md` | NEW — `/team-new <idea>` entry point |
| `skills/greenfield-bootstrap/SKILL.md` | NEW — G0–G5 orchestration (sibling to team-workflow) |
| `skills/greenfield-bootstrap/resources/scaffold-recipes.md` | NEW — per-stack non-interactive CLI invocation + harness-layer checklist + no-CLI fallback |
| `skills/project-analyzer/SKILL.md` | add `## Seeded Mode` + Step 4/5 override pointers + Step 3 fallback |
| `skills/project-analyzer/resources/profile-templates.md` | add `🌱 Seeded` to legend + Status column |
| `skills/team-workflow/SKILL.md` | Pre-Flight: greenfield (no source tree) → `/team-new`; existing tree, no profile → `/team-init` |
| `CLAUDE.md` | Commands row `/team-new`; Decision Guide greenfield split; First Run section; Skills row greenfield-bootstrap |
| `.claude-plugin/plugin.json` + `marketplace.json` | description mentions greenfield bootstrap |

## Verification
1. Dry-run on a throwaway idea in a temp dir → brief→research→decision→scaffold→profile, no error, **non-vacuous** profile (api-layer + state-management are `🌱 Seeded`, not `⏭️ Skipped`).
2. deep-research absent → loud WebSearch-fallback warning, no install instruction, flow still completes.
3. Non-empty guard: repo with only README+.git → proceeds; repo with package.json → refuses, points to `/team-init`.
4. G3 reject → brief/research/decision moved to `deprecated/`, no scaffold written.
5. `jq` parses plugin.json + marketplace.json; team-workflow Pre-Flight routes greenfield→/team-new.
