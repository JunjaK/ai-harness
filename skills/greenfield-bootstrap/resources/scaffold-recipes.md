# Scaffold Recipes

Per-stack **non-interactive** scaffold invocations for G4. Scaffolder flags drift per version — **verify the current flag set via Context7 at G2** before pinning the command into the stack-decision doc (the G3-approved command MUST be the one that runs).

## Hard rules (every recipe)

- **Fully non-interactive**: every prompt answered by a flag. A missing flag makes the CLI block forever in an agent shell. When unsure a combo still prompts, prefer the CLI's blanket `--yes`/`--no-*` and pass an explicit value for each known prompt.
- **Bounded timeout** around the scaffold call; on timeout / non-zero exit → ABORT G4, capture stderr, `git clean`/`reset` to the pre-G4 state (no half-scaffold).
- **Non-empty target dir**: G0–G2 already wrote `_docs/`, so the dir is non-empty. Use the CLI's "scaffold into current dir" behavior, or scaffold into a temp subdir (`.scaffold-tmp/`) then move contents up and remove it.
- **Package manager = bun** by default (`--use-bun` / `--package-manager bun` where supported; else scaffold then `bun install`).
- **Edit-not-overwrite** for the harness layer (below) — never blind-overwrite the scaffold's tsconfig/eslint.

## Known-good baselines (verify flags via Context7)

| Stack | Non-interactive baseline (confirm flags first) |
|-------|------------------------------------------------|
| **Vite** (React/Vue/Svelte/Solid) | `bunx create-vite@latest <dir> --template <react-ts\|vue-ts\|svelte-ts\|solid-ts>` (template = non-interactive) |
| **Next.js** | `bunx create-next-app@latest <dir> --ts --eslint --app --src-dir --use-bun --import-alias "@/*" --no-tailwind --yes` (pass EVERY prompt as a flag) |
| **Nuxt** | `bunx nuxi@latest init <dir> --packageManager bun --no-install` then `bun install` (no-prompt) |
| **Astro** | `bunx create-astro@latest <dir> --template minimal --no-install --git --skip-houston --yes` |
| **SvelteKit** | `bunx sv create <dir> --template minimal --types ts --no-add-ons --install bun` |
| **backend-only** (Hono/Elysia/Bun-native) | usually **no official scaffolder** → manual fallback below |

## Manual-scaffold fallback (no official non-interactive CLI)

When the chosen stack has no non-interactive scaffolder (backend-only, or a CLI that can't be fully flag-driven), build the minimal layout yourself from the framework's documented "manual setup" (fetch via Context7):

1. `bun init -y` (or write `package.json` directly) — name, type module, scripts.
2. Add the framework + its peer deps at the versions from the research doc (`bun add ...`).
3. Write `tsconfig.json` with `strict: true`, `noUncheckedIndexedAccess: true`, plus the framework's required `compilerOptions` (jsx/paths/moduleResolution/lib).
4. Create the entry file + the directory structure from the stack-decision doc.
5. `bun install`, then the type-check gate (below).

## Harness layer (applied AFTER scaffold, edit-not-overwrite)

1. **tsconfig** — DETECT the scaffold's `tsconfig.json` and ADD `"strict": true`, `"noUncheckedIndexedAccess": true`; preserve framework options (`jsx`, `paths`, `moduleResolution`, `lib`). Never replace the file.
2. **Directories** — the structure from the stack-decision doc (e.g. `_modules/` for page logic per the harness page-structure rule).
3. **Testing** — Vitest 4.x (unit) + Playwright (E2E) config + scripts.
4. **Lint/format** — extend, don't clobber, the scaffold's eslint/prettier/biome config.
5. **`settings.json`** — `{"env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"}}` (required for the team commands).
6. **Git** — if the scaffolder ran `git init`/committed, add the harness layer as a **second** commit (don't double-init). The **final** commit SHA = G5 `Profile-Generated-At`.
7. **Type-check gate (last)** — run the authoritative type-check (from the would-be `stack.md` "Build & Verify"); the strict additions MUST still pass on the fresh scaffold (absolute-zero baseline). If they don't, fix the tsconfig merge before G5 — do not mask with `any`/`@ts-ignore`.

> Do NOT start a watch-mode dev server during G4 (operational-discipline rule).
