---
name: greenfield-bootstrap
description: "Bootstrap a brand-new project from zero — research the stack, scaffold it, and generate the project profile — when there is no code yet. Use when /team-new is invoked, or when the user wants to start a new project from an idea. Ends by handing off to /team-run for the first feature. Distinct from project-analyzer/team-init (which assume an existing codebase)."
---

# Greenfield Bootstrap

The entry point the rest of the harness assumes away: taking an **empty repo + an idea** to **researched → scaffolded → profiled**, ready for `/team-run`. `/team-init` and `team-workflow` both assume code already exists; this skill is what runs before them.

**Deliverable boundary**: scaffolding + `.claude/project-profile/`. The first feature is NOT built here — it is handed off to `/team-run`.

## Pre-Flight: greenfield guard

Run ONLY in an empty/near-empty repo. **Refuse** (and point at `/team-init`) if real project files exist — `package.json`, `src/`, `tsconfig*`, `node_modules/`. **Allow** `.git`, `README*`, `LICENSE*`, `.gitignore`, and any `_docs/` this bootstrap itself wrote.

**Idempotency**: if a `project-bootstrap` brief already exists with no G4 scaffold commit, an in-flight bootstrap is detected → resume/replace it, never duplicate.

## G0 — Intake → brief + a fully-scoped research question

Spawn `team-leader` interactively. Gather: target users · platform (`web` / `mobile` / `CLI` / `API` / `backend-only`) · must-have first features · hard constraints (deploy target, existing infra, team prefs) · explicit non-goals.

Two outputs:
1. **Brief** → `_docs/active/planning/<today>/<today>-project-bootstrap-brief.md` (topic `project-bootstrap`, kind `brief`).
2. **A FULLY-SCOPED research question** for G1. This is load-bearing: deep-research asks 2–3 clarifying questions only when under-scoped, which would stall an automated handoff. G0 exists to pre-empt that — the question MUST be self-contained: *domain + platform + must-have features + hard constraints + the exact stack/architecture decision being researched.*

## G1 — Deep research (return-then-write)

`deep-research` is a **CLI-bundled WORKFLOW** (not a Skill/plugin). Invoke it with the G0 question as **args** (it decomposes "question from args" into 5 search angles → searches → adversarially verifies → synthesizes). It **RETURNS a cited report as text — no file side-effect.**

- **Capture**: take the returned report text and **write it yourself** to `_docs/active/planning/<today>/<today>-project-bootstrap-research.md` (topic `project-bootstrap`, kind `research`, `related:`→brief). **Never poll for a file deep-research "wrote" — it writes none.**
- **Soft-degrade = capability probe**: if deep-research is absent from this session's roster / WorkflowTool disabled / SIMPLE-mode CLI → fall back to architects running `WebSearch` directly, and warn loudly: *"⚠ deep-research unavailable — research depth reduced, proceeding with direct WebSearch."* **MUST NOT** tell the user to install anything (it ships with the CLI; nothing to install).

## G2 — Architecture & stack decision

Spawn `team-architect-fe` + `team-architect-be` in parallel (consume brief + research). They propose: concrete stack (exact versions from research), project structure, state management, API layer, testing/tooling, deploy target. Cross-review via `TeamCreate` (leader + FE + BE; add `team-architect-infra` if auth/payments/deploy flagged). Leader consolidates →

**stack-decision doc** `_docs/active/planning/<today>/<today>-project-bootstrap-stack-decision.md` (kind `stack-decision`) — MUST contain:
- chosen framework + package manager (bun default)
- the **exact non-interactive scaffold command** (per `resources/scaffold-recipes.md`; consult Context7 for current flags) OR the no-CLI manual-scaffold plan
- harness-layer checklist (strict tsconfig additions, dirs, Vitest4+Playwright, lint, `settings.json` AGENT_TEAMS=1)
- **forward-looking conventions** that seed the profile (the project-analyzer Seeded-Mode INPUT CONTRACT): planned API client + generated-vs-manual + generator/regen command + auth posture + base-URL env; planned state library + intended store patterns; planned UI lib; planned test stack.

`backend-only` is a first-class outcome → no UI scaffolder, Phase-2 UI/UX and `ui-components.md` skipped.

## G3 — ★ USER GATE (the only irreversible-prep boundary)

Present: research summary + recommended stack + structure + **the exact scaffold command(s) that will run**. Verify the CLI's flags BEFORE presenting, so the approved command is the one that runs.

- **"Nothing written before G3" = SOURCE tree only.** The brief/research/decision are in `_docs/` (the artifacts under review) — that is correct and required. No scaffold / `package.json` / `src/` exists yet.
- **APPROVE** → G4. **Edit** → loop to G2 (escalation cap 3). **Reject / Ctrl-C** → rollback: move brief/research/decision → `deprecated/` with a `g3-rejected` note (preserves the research cost); offer to delete if the repo is otherwise empty.

## G4 — Scaffold (official CLI + harness layer)

1. **Run the official CLI non-interactively** (recipe-pinned flags + bounded **timeout**). The dir is already non-empty (G0–G2 wrote `_docs/`) → use the CLI's "into current/non-empty dir" flag, or scaffold into a temp subdir then move. On timeout / non-zero exit → **ABORT**, capture stderr, leave no half-scaffold (`git clean`/`reset` to the pre-G4 state).
2. **No official CLI** for the chosen stack → the recipe's **manual-scaffold** path (dirs + package.json + tsconfig + entry, from the framework's minimal layout via Context7).
3. **Harness layer = edit-not-overwrite**: ADD `strict` + `noUncheckedIndexedAccess` to the scaffold's tsconfig (preserve framework `jsx`/`paths`/`moduleResolution`); add dirs, Vitest 4 + Playwright, lint/format, `settings.json` (AGENT_TEAMS=1).
4. **Git**: if the scaffolder ran its own `git init`/commit, do NOT double-init — add the harness layer as a **second** commit. The **final** bootstrap commit SHA is what G5 records as `Profile-Generated-At`.
5. **Last step**: confirm the strict-tsconfig change still type-checks (absolute-zero baseline gate). Do not start a dev server.

## G5 — Profile (project-analyzer Seeded Mode)

Invoke `project-analyzer` in **Seeded Mode** (see its `## Seeded Mode` section), passing the stack-decision doc:
- **SCAN-fill** from the real scaffold: stack.md, structure.md, code-style.md (formatter-config fallback if <5 files), testing.md (frameworks + agentic adapter), ui-components.md (if a UI lib was scaffolded), index.md.
- **INJECT-fill** the forward-looking docs scan can't infer — **api-layer.md** and **state-management.md** — from the stack-decision doc, marked **`🌱 Seeded`** with a provenance line. (Without this they'd be wrongly `⏭️ Skipped` and the first `/team-run` would lose its API/state guidance.)

## Handoff

Merge brief + research + stack-decision via the docs-lifecycle **merge rule** → `_docs/complete/project-bootstrap/<date>-project-bootstrap.md`. Then:

```
✅ PROJECT BOOTSTRAPPED
Stack: <framework + language + package manager>
Profile: .claude/project-profile/ (9 docs; api-layer + state-management 🌱 Seeded)
Next: /team-run <first feature>   — suggested first features: <from the brief's must-haves>
```

## Escalation
Per `team-workflow/resources/escalation.md`: per-phase retries ≤ 3; G3 edit loops ≤ 3 then ABORT; report every escalation to the user.

## Related
- `resources/scaffold-recipes.md` — per-stack non-interactive scaffold commands + harness layer + no-CLI fallback
- `project-analyzer` (Seeded Mode) — G5 profile generation
- `docs-lifecycle` — bootstrap docs live under the reserved `project-bootstrap` topic; merge-on-complete
- `handoff` — final handoff; `/team-run` — builds the first feature
