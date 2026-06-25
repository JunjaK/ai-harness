---
description: "Team New — greenfield project bootstrap: deep-research → architect stack decision → user gate → scaffold → profile"
---

# Team New — Greenfield Bootstrap

Start a brand-new project from an idea: research the stack, scaffold it, generate the project profile, then hand off to `/team-run` for the first feature. This is the entry point `/team-init` and `/team` assume away — they need code to already exist.

## Usage

```
/team-new <one-line idea>     # e.g. /team-new a habit-tracking PWA for couples
/team-new                     # no arg → G0 intake asks for the idea first
```

## When to use

```
Empty / near-empty repo (no package.json, no src/) + want to start a new project?
  YES → /team-new
Existing codebase, not yet analyzed?
  → /team-init
```

`/team-new` **refuses** in a populated repo (real `package.json`/`src/`/`tsconfig`) and points you at `/team-init`. It allows `.git`, `README`, `LICENSE`, `.gitignore`, and its own `_docs/`.

## What it does

Invokes the `greenfield-bootstrap` skill (G0–G5):

1. **G0 intake** — `team-leader` asks: users · platform · must-have first features · constraints · non-goals → brief + a fully-scoped research question.
2. **G1 research** — runs the `deep-research` bundled workflow on that question; captures the returned cited report into `_docs/`. (Unavailable → direct `WebSearch` fallback with a loud warning; nothing to install.)
3. **G2 decision** — `team-architect-fe` + `-be` propose the stack/structure; cross-review; leader consolidates a stack-decision (exact scaffold command + harness layer + forward-looking conventions).
4. **G3 ★ user gate** — presents research + recommended stack + the exact scaffold command. APPROVE / edit / reject. **Nothing is written to the source tree before this** (only the `_docs/` planning artifacts you're reviewing).
5. **G4 scaffold** — runs the official CLI non-interactively + applies the harness layer (strict tsconfig, dirs, Vitest+Playwright, lint, settings.json) + first commit.
6. **G5 profile** — `project-analyzer` in Seeded Mode: scans the scaffold + injects the stack-decision → `.claude/project-profile/` (9 docs).

## Output

```
.claude/project-profile/     # 9 docs (api-layer + state-management 🌱 Seeded from the decision)
_docs/complete/project-bootstrap/<date>-project-bootstrap.md   # merged brief+research+decision
<scaffolded project source>  # framework files + harness layer, committed
```

## On completion

```
✅ PROJECT BOOTSTRAPPED
Stack:   <framework + language + bun>
Profile: .claude/project-profile/  (9 docs)
Next:    /team-run <first feature>   — suggested: <must-haves from the brief>
```

## Related
- `greenfield-bootstrap` skill — the G0–G5 methodology
- `project-analyzer` (Seeded Mode) — G5 profile generation
- `/team-run` — builds the first feature once bootstrapped
- `/team-init` — use this instead when the project already has code
