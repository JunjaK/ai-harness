---
name: submodule-worktree
description: "Worktree strategy for a submodule-monorepo where the superproject is a thin shell (doc storage + submodule pointers) and the real code lives in submodules (illustratively `fe`/`be`). TRIGGER when a worktree / parallel-implementation request lands in a repo that has git submodules (`.gitmodules`), or the project profile records a Submodule Layout. Rules: worktree ONLY the code submodules, keep the superproject as the single original checkout (the `_docs/` anchor), CARRY gitignored runtime files (`.env`/secrets/local config) into each new worktree, and defer submodule-pointer bumps. The submodule-specialized companion to `parallelization`."
---

# Submodule Worktree

For a **submodule-monorepo**: the superproject (`integrated`) is a thin shell whose only jobs are **document storage** (`_docs/`) and **submodule pointers**; the real code lives in submodules. This skill specializes `parallelization` for that shape — the general worktree rules (base-from-current-HEAD, max-5, no-file-overlap, merge order, cleanup) still apply and are NOT repeated here; read `parallelization` for them.

> **`fe`/`be`/`integrated` throughout are illustrative — actual submodule names and roles are per-project.** The SSOT is the project profile: `/team-init` (`project-analyzer`) records, in `.claude/project-profile/structure.md`, whether the repo is a submodule-monorepo, which submodules hold code (the ones to worktree), and whether the superproject is a docs+pointers shell. Never hardcode names — read the profile, and enumerate live with `git submodule`.

## When this applies (and when it does NOT)

| Situation | Use |
|-----------|-----|
| Superproject = docs + submodule pointers only; real code in `fe`/`be` submodules; need parallel/isolated work | **this skill** |
| Non-submodule repo, or superproject that itself holds substantial code | plain `parallelization` (premise below breaks) |
| One submodule, no parallelism needed | no worktree — just branch in that submodule in place |

## Core rule: worktree the submodules, NOT the superproject

- **The superproject stays as the single original checkout.** Never `git worktree add` on it. It remains the **`_docs/` anchor** and the place where submodule pointers are bumped.
- **Worktree only the code submodule(s) that need isolated work** (`fe` and/or `be`).
- **Why**: the superproject's whole job is docs + pointers. Pointer bumps are deferrable (§4) — no isolation needed. Docs are single-copy in the original tree and only ever collide on `index.md`, which is non-critical (§2). So a superproject worktree buys nothing and adds a doc copy that must be merged back. Skip it.

## Layout (Q1 = inside superproject, gitignored)

```
parent/
└── integrated/              ← superproject: ORIGINAL, untouched. docs anchor + pointer host
    ├── _docs/               ← the one physical _docs/ every agent writes to (absolute path)
    ├── fe/  be/             ← submodule originals (own git repos)
    └── .worktrees/          ← gitignored; submodule worktrees live here
        ├── fe-featureX/      ← worktree of the `fe` submodule
        └── be-featureX/      ← worktree of the `be` submodule
```

Two caveats that make `.worktrees/` inside the superproject safe:
- **`.worktrees/` MUST be in the superproject `.gitignore`** — else the superproject reports the whole checkout as untracked. (Add it before creating any worktree.)
- **Never run `git clean -fdx` in the superproject** — `-x` deletes gitignored paths and would nuke the live worktrees. Always tear down with `git worktree remove` (§3).

## 1. Setup

```bash
SUPER="$(git -C /abs/path/to/integrated rev-parse --show-toplevel)"   # superproject root, absolute
test -f "$SUPER/.gitmodules" && git -C "$SUPER" submodule status       # confirm it's a submodule-monorepo
git -C "$SUPER" submodule status | awk '{print $2}'                    # enumerate submodule paths (per-project)
grep -qxF '.worktrees/' "$SUPER/.gitignore" || printf '.worktrees/\n' >> "$SUPER/.gitignore"

# Which submodules to worktree = the CODE submodules per .claude/project-profile/structure.md (SSOT),
# NOT a hardcoded fe/be. Create a worktree for a code submodule $SUB, task $TASK —
# base = the submodule's OWN current HEAD:
SUB=<code-submodule-path>; TASK=featureX
git -C "$SUPER/$SUB" worktree add "$SUPER/.worktrees/$SUB-$TASK" -b "$TASK" HEAD
```

- **Base per submodule independently** — each from its own `HEAD` (see `parallelization` → Base Selection). Do NOT assume a shared mainline across submodules.
- **Detached submodule** — submodules are commonly checked out **detached at the pinned commit**. `-b "$TASK" HEAD` still branches correctly from that commit, but the pinned commit is not a branch tip, so the **merge target is ambiguous**: confirm which branch the work lands on (typically the submodule's own `develop`/`main`) before merging in §3. `git -C "$SUPER/$SUB" symbolic-ref -q HEAD` failing = detached = confirm.

### Provision each new worktree — carry gitignored runtime files (REQUIRED)

`git worktree add` produces a **clean checkout**: gitignored/untracked files are NOT copied. So `.env`, secrets, and local config the submodule needs to build/run are **absent** in the fresh worktree — it will not run until you carry them over. This is mandatory, not optional.

**Carry all gitignored runtime files EXCEPT regenerable heavy artifacts** (deps/build — reinstall those instead):

```bash
SRC="$SUPER/$SUB"; DST="$SUPER/.worktrees/$SUB-$TASK"
# All gitignored files in the source submodule, minus dependency/build dirs → copied into the worktree.
# SSOT for what to carry / what to exclude = the profile's per-submodule carry-list
# (.claude/project-profile/structure.md → Submodule Layout). The grep below is the profile-less fallback.
( cd "$SRC" && git ls-files --others --ignored --exclude-standard ) \
  | grep -Ev '(^|/)(node_modules|\.gradle|\.next|dist|build|target|out|\.turbo|coverage|\.venv|__pycache__)(/|$)' \
  | while IFS= read -r f; do mkdir -p "$DST/$(dirname "$f")"; cp -p "$SRC/$f" "$DST/$f"; done
```

- **Env/secrets/local config** (`.env`, `.env.*`, `application-local.yml`, `local.properties`, service-account JSON, …) → **copied** by the above (isolated copy, not a symlink, so parallel worktrees don't share mutable state).
- **Dependencies / build output** (`node_modules`, `.gradle`, `build/`, `target/`, `.next/`) → **NOT** copied; **reinstall/rebuild** in the worktree (`bun install`, `./gradlew …`). Artifacts built against the source path or a different lockfile go stale; symlinking `node_modules` across worktrees is fragile.
- Carried files **stay gitignored** in the worktree (same repo, same `.gitignore`) — never commit them.
- The profile's carry-list refines this: it can pin exact paths to copy and extra paths to exclude (e.g. a large gitignored fixtures dir), making the step deterministic instead of heuristic.

## 2. `_docs/` anchor = the superproject original (single physical copy)

All submodule-worktree agents read AND write `_docs/` at the **superproject original's** absolute path — there is no per-worktree `_docs/` copy, so there is no doc merge round-trip.

**Resolution — orchestrator-injected absolute path (REQUIRED):**
```bash
DOCS="$SUPER/_docs"   # $SUPER (§1) is the superproject toplevel; computed ONCE, from the superproject
```
The orchestrator computes `$DOCS` once and injects the literal absolute path into every submodule-worktree agent's briefing.

⚠️ The generic `parallelization` resolution `$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/_docs` **does NOT work here**: run inside a submodule worktree it resolves to the *submodule's* git-dir (`integrated/.git/modules/fe`), not the superproject's `_docs/`. `--show-superproject-working-tree` is also unreliable from a worktree placed off the registered submodule path. Use the injected absolute path.

- **Read** plans/specs from `"$DOCS/…"` by absolute path.
- **Write** doc content (impl notes, findings) to `"$DOCS/…"` by absolute path, each agent owning **distinct** files — lands in the superproject tree instantly, readable from the original with no cd, no merge.
- **`index.md` is the one shared mutable doc** → orchestrator-serialized (only the orchestrator edits it + does status-moves after agents finish). Because every agent writes the SAME physical `_docs/`, an index.md collision is a filesystem race, not a git merge — **non-critical and trivially fixable** (last-writer / manual reconcile). Never let it block code work. (See `docs-lifecycle` → Concurrency.)

## 3. Merge & cleanup (per submodule)

Each submodule merges independently into its own integration branch — this is a per-submodule merge, not a superproject merge.

```bash
# merge order across submodules: backend (be) before frontend (fe) when a contract couples them; else independent
git -C "$SUPER/$SUB" checkout <integration-branch>   # the branch confirmed in §1 (esp. if it was detached)
git -C "$SUPER/$SUB" merge "$TASK"
git -C "$SUPER/$SUB" worktree remove "$SUPER/.worktrees/$SUB-$TASK"
git -C "$SUPER/$SUB" worktree prune
```

## 4. Submodule pointer bump — deferred, low priority

The superproject only needs its pointers updated to the submodules' new commits. This is **not urgent** — batch it at an appropriate checkpoint after the submodule integration branches have advanced, and it MUST NOT block or gate the code work.

```bash
cd "$SUPER" && git add <code-submodule-paths> && git commit -m "chore: bump submodule pointers"  # paths e.g. fe be
```

## Quick reference

```
Worktree:   ONLY code submodules (fe/be). NEVER the superproject.
Superproject: single original checkout = _docs/ anchor + pointer host.
Location:   $SUPER/.worktrees/<sub>-<task>/  (gitignore .worktrees/; never `git clean -fdx` the super)
Provision:  worktree = clean checkout → CARRY gitignored env/secrets/local-config in; reinstall deps (don't copy node_modules/build).
_docs/:     one physical copy in the superproject original; agents R/W by INJECTED absolute path.
            --git-common-dir / --show-superproject-working-tree DON'T resolve it here — inject it.
index.md:   orchestrator-serialized; collisions are non-critical FS races, fix casually, never block.
Base:       each submodule's own HEAD; detached pin → confirm the merge-target branch.
Merge:      per submodule into its integration branch (be→fe if coupled); then worktree remove + prune.
Pointers:   deferred — batch `git add fe be && commit` in the super later; never gates code work.
General worktree rules (max-5, no-overlap, order, cleanup): see `parallelization`.
```
