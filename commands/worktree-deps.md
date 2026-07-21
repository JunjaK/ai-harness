---
description: "Worktree Deps — provision a worktree's node_modules via the package manager's shared content-addressable store (hard-link, no re-download, parallel-safe). pnpm/bun handled inline; any other manager resolved via Context7. Never symlinks node_modules across worktrees."
---

# Worktree Deps — fast-path dependency provisioning

A fresh `git worktree add` checkout has **no `node_modules`** (gitignored, not tracked). This provisions it the cheap, parallel-safe way: hard-link from the package manager's **shared store**, giving a per-worktree `node_modules` with no re-download and isolated build caches. On-demand entry point for the procedure in the `parallelization` skill → "Provision worktree deps (fast path)".

## Usage

```
/worktree-deps            # provision deps into the CURRENT worktree (cwd)
/worktree-deps <path>     # provision deps into the worktree at <path>
```

## What It Does

Route to `parallelization` → **Provision worktree deps (fast path)**:

1. **Detect the manager + family.** Prefer the recorded value in `.claude/project-profile/stack.md` (manager + fast-path recipe). Otherwise: lockfile priority (`bun.lockb`/`bun.lock` → bun, `pnpm-lock.yaml` → pnpm, `package-lock.json` → npm), `packageManager` in `package.json`, or the ecosystem's build file (`pubspec.yaml` → Dart/Flutter, `build.gradle*`/`pom.xml` → Gradle/Maven, `go.mod` → Go, `Cargo.toml` → Cargo). Classify the **family**: **A · copy-based** (node_modules) vs **B · reference-cache** (pub/gradle/maven/go/cargo).
2. **Provision** (cwd = the target worktree):
   - **A · pnpm**: `pnpm install --frozen-lockfile --prefer-offline` (drop `--frozen-lockfile` if this branch changed the lockfile). **A · bun**: `bun install --frozen-lockfile`. Family A also needs the **same-filesystem check** — store and worktree must share a filesystem or the manager **copies** instead of hard-linking (`df "$(pnpm store path)" .`); relocate the store if they differ.
   - **B · Flutter/Dart**: `fvm flutter pub get` (or `dart pub get` / `flutter pub get` if not FVM-pinned) — resolves from the warm global cache, nothing copied. **B · Gradle**: `./gradlew <task>` resolves from `~/.gradle/caches`; no separate install step. Family B has **no** hard-link / store-dir / same-filesystem concern.
   - **any other manager** (yarn-classic, pip/uv, poetry, …): do **NOT** guess. Resolve its family + recipe via **Context7** (`resolve-library-id` → `query-docs`), apply it, and record it in `stack.md`. Context7 unavailable → STOP and say so; do not fall back to a guessed command.
3. **Never symlink deps** across worktrees (either family) — parallel builds race on shared caches (`node_modules/.vite`, `.cache`, …) and a dep change in one worktree corrupts the others. Family A's store hard-link and Family B's cache reference both give "no re-download" safely; symlinking stays excluded.

## On Completion

Report: manager + family · mechanism (`hard-link` A / `cache-referenced` B / `copied — different filesystem` A-degraded) · resolve wall-time · deps present. A same-filesystem degrade, or an unknown manager with Context7 unavailable → report it explicitly rather than claiming success.

## Related

- `parallelization` skill → "Provision worktree deps (fast path)" — the canonical procedure this command fires.
- `project-analyzer` / `/team-init` — records the manager + resolved fast-path recipe in `stack.md` so this command and Designers-in-worktrees don't re-resolve it.
- `submodule-worktree` skill — same fast path, applied per code submodule.
- CLAUDE.md "Authoritative Documentation (MCP)" — why non-pnpm/bun recipes come from Context7, not memory.

ARGUMENTS: $ARGUMENTS
