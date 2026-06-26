---
name: brain-connect
description: "Wire an optional personal 'brain' SSOT (a separate repo holding your cross-machine persona + harness auto-memory) into the Claude Code environment on a machine — persona @import, per-project memory junction, and opt-in auto-sync hooks. Use when setting up the harness on a new machine (work/home), when a user provides a path to their brain repo and wants it connected/referenced, or when relocating an existing brain to a new folder/remote. Dependency-free: the harness ships the generic connector scripts as a copyable template and defines the brain contract; it does NOT import or depend on any specific brain repo. The reference conforming brain is the private claude-brain SSOT."
---

# Brain Connect — pair a personal brain SSOT with the harness

A **brain** is a small, separate git repo that holds the two things you want identical across machines:

- **`persona.md`** — your decision/judgment layer, `@`-imported into `~/.claude/CLAUDE.md` so it applies to **every project, every machine** (path-independent).
- **`memory/<project>/`** — the harness auto-memory for one or more projects, junctioned into each machine's per-project memory dir.

The harness is installed per-machine (marketplace) and is **brain-agnostic**. This skill defines the **contract** a brain must satisfy and ships a **generic connector** (`template/`) that wires any conforming brain to a machine. It introduces **zero runtime dependency**: the harness never imports the brain — the brain plugs into the global `~/.claude` layer, and the harness stays unaware of it at runtime. This is the loosest possible coupling: claude-brain wires *itself* into the global environment, and the harness (like every project) benefits transparently without knowing it exists.

## When this applies (and when it does not)

Applies when ANY hold:
- Setting up the harness + a brain on a **new machine** (e.g., work and home).
- The user **provides a path** to their brain repo and wants it referenced/wired.
- **Relocating** a brain (moved folder or new remote) — re-point all wiring.

Does NOT apply: there is no brain, or the user only wants harness features without a personal SSOT. The harness works fully standalone — a brain is purely optional, never required.

## The brain contract (what makes a repo connectable)

| Brain provides | Wired to | Effect |
|----------------|----------|--------|
| `persona.md` (optional) | an `@import` line in `~/.claude/CLAUDE.md` | persona loaded every session, every project |
| `memory/<ProjectName>/` (optional) | a junction at `~/.claude/projects/<project-key>/memory` | that project's harness auto-memory **is** the synced brain memory |
| `sync.ps1` (optional) | `SessionStart`→pull, `SessionEnd`→push hooks | brain auto-pulls before / auto-pushes after each session |

A brain MAY provide any subset. The minimal useful brain is `persona.md` alone (global, no per-project key needed).

**Why a junction, not a copy:** Claude Code keys per-project state by the project's **absolute path** (`C:\Users\me\dev\app` → `C--Users-me-dev-app`). Different machines use different usernames/paths → **different keys** → the auto-memory would not line up. Junctioning *this machine's* key-path memory dir to the one brain repo makes the junction **the per-environment mapping** while the synced content stays identical.

## Connect procedure (per machine, idempotent)

1. Install the harness (marketplace) — already done if you are reading this.
2. Clone the brain repo to a stable absolute path, e.g. `C:/Users/<you>/dev/personal/<brain>`.
3. Run the connector **from the brain** (copy `template/setup.ps1` into your brain if it lacks one):
   ```powershell
   pwsh -NoProfile -File C:/Users/<you>/dev/personal/<brain>/setup.ps1 `
       -ProjectPath "<absolute path of the project to attach memory to>" `
       -ProjectName "<that project's name>" -RegisterHooks
   ```
   - `setup.ps1` is **idempotent** — re-running is safe; it skips wiring already present and migrates any pre-existing memory (backup `memory.pre-brain-*`).
   - Attach more projects later: rerun with a different `-ProjectPath` / `-ProjectName`.

### MUST: the hooks/settings step is user-run
`-RegisterHooks` edits `~/.claude/settings.json`. An agent **MUST NOT** edit `settings.json` itself — Claude Code's safety classifier blocks agent self-modification of settings. The user **MUST** run the script (via the `!` prefix or a terminal). The agent's role is to generate the exact command and **verify the result afterward**.

### MUST: always use absolute paths
PowerShell `-File ~/...` and `-ProjectPath ~/...` do **NOT** expand `~` — a `~`-prefixed `-ProjectPath` produces a broken project key (`~-dev-...`). Always pass `C:/Users/<you>/...`.

## Relocating an existing brain
If the brain folder moved or its remote changed, run `template/relocate.ps1` **from the brain's new location** — it re-points the `@import`, the memory junction, and the sync hooks to its own `$PSScriptRoot` (backs up `CLAUDE.md`/`settings.json`, validates JSON). It removes only the junction **link** via `(Get-Item).Delete()` — **never** `Remove-Item -Recurse` on a junction (that deletes the link's target).

## Cross-platform note
The template scripts are PowerShell (Windows, where junctions are native). On macOS/Linux the **same contract** holds: substitute a symlink (`ln -s`) for the junction and a shell `setup.sh` equivalent, porting the three steps (append `@import`, link `memory/<project>`, register the two session hooks). The **contract — not the script language — is what the harness standardizes.**

## Reference brain
The canonical conforming brain is the private **claude-brain** SSOT (`persona.md` + `memory/<project>/` + `setup.ps1`/`sync.ps1`/`relocate.ps1`). The scripts under `template/` are the generalized, brain-neutral copies of those.

## Verify after connecting
```powershell
# persona @import points at the brain
Select-String 'persona\.md' "$env:USERPROFILE\.claude\CLAUDE.md"
# memory junction target is the brain
(Get-Item "$env:USERPROFILE\.claude\projects\<project-key>\memory").Target
# sync hooks present + settings.json still valid JSON
Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw | ConvertFrom-Json | Out-Null
```
A green type-check is not enough — confirm the junction `Target` actually resolves to the brain and that a memory file written this session round-trips after a sync.
