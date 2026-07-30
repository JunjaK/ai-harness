---
name: brain-connect
description: "Wire an optional personal 'brain' SSOT (a separate repo holding your cross-machine persona, global CLAUDE.md, personal global skills, harness auto-memory, and a recommended-settings manifest) into the Claude Code environment on a machine. Use when setting up the harness on a new machine (work/home), when a user provides a path to their brain repo and wants it connected/referenced, when relocating an existing brain to a new folder/remote, or when something is identical on one machine but missing on another (a skill, a global rule, a plugin toggle). Dependency-free: the harness ships the generic connector scripts as a copyable template and defines the brain contract; it does NOT import or depend on any specific brain repo. The reference conforming brain is the private claude-brain SSOT."
---

# Brain Connect — pair a personal brain SSOT with the harness

A **brain** is a small, separate **private** git repo holding everything you want identical across
machines. The harness is installed per-machine (marketplace) and is **brain-agnostic**: this skill
defines the **contract** a brain must satisfy and ships a **generic connector** (`template/`) that
wires any conforming brain to a machine. Zero runtime dependency — the harness never imports the
brain. The brain wires *itself* into the global `~/.claude` layer, and the harness (like every
project) benefits transparently without knowing it exists.

## When this applies (and when it does not)

Applies when ANY hold:
- Setting up the harness + a brain on a **new machine** (e.g., work and home).
- The user **provides a path** to their brain repo and wants it referenced/wired.
- **Relocating** a brain (moved folder or new remote) — re-point all wiring.
- **An asymmetry surfaces**: something fixed on one machine never reached the other (a skill edit,
  a global rule, a plugin toggle). That asymmetry means the artifact lives outside the brain — the
  fix is to move it in and link back, not to re-apply the edit by hand.

Does NOT apply: there is no brain, or the user only wants harness features without a personal SSOT.
The harness works fully standalone — a brain is purely optional, never required.

## The brain contract (what makes a repo connectable)

| Brain provides | Wired to | Effect |
|----------------|----------|--------|
| `persona.md` | link at `~/.claude/persona.md` + `@persona.md` import inside the brain's `CLAUDE.md` | persona loaded every session, every project |
| `CLAUDE.md` | link at `~/.claude/CLAUDE.md` | global rules identical on every machine |
| `skills/<name>/` | link at `~/.claude/skills/<name>` — **one per skill** | personal global skills identical on every machine |
| `commands/` | link at `~/.claude/commands/brain` (namespaced) | personal global commands |
| `memory/<ProjectName>/` | link at `~/.claude/projects/<project-key>/memory` | that project's harness auto-memory **is** the synced brain memory |
| `settings.recommended.json` | **merged** into `~/.claude/settings.json` by `apply-settings` | machine-neutral settings keys, machine-specific keys untouched |
| `sync.ps1` / `sync.sh` | `SessionStart`→pull, `SessionEnd`→push hooks | brain auto-pulls before / auto-pushes after each session |

A brain MAY provide any subset; the connector skips what is absent. The minimal useful brain is
`persona.md` alone.

**Why links, not copies:** Claude Code keys per-project state by the project's **absolute path**
(`C:\Users\me\dev\app` → `C--Users-me-dev-app`). Different machines use different usernames/paths →
**different keys** → the auto-memory would not line up. Linking *this machine's* paths to the one
brain repo makes the link **the per-environment mapping** while the synced content stays identical.

## Three rules that decide whether this actually works

### MUST: one link per skill — never link the whole `skills/` dir
`~/.claude/skills/` is shared ground. Third-party tools install skills there, often as relative
symlinks into their own store (e.g. `agent-browser -> ../../.agents/skills/agent-browser`).
Linking the directory itself **hides every one of them**, and moving the directory into the brain
both breaks those relative targets and puts another tool's files under the brain's auto-commit.
Link each brain-owned skill individually — the same reasoning as the namespaced `commands/brain`.

**Consequence for later work:** a new personal global skill MUST be created under
`<brain>/skills/<name>/` and linked. One created directly in `~/.claude/skills/` as a real
directory lives outside the brain and silently will not sync.

### MUST: keep the persona import relative, and link `persona.md` next to `CLAUDE.md`
Once `CLAUDE.md` itself is synced, an absolute `@C:/Users/me/.../persona.md` import inside it
breaks on every other machine. Use `@persona.md` and link `persona.md` into `~/.claude/` alongside
the linked `CLAUDE.md`. Claude Code's base dir for a relative import inside a **symlinked**
`CLAUDE.md` is not a documented guarantee, so placing `persona.md` in both candidate locations
(it is one link, and the brain dir already has the real file) makes the import resolve either way.

### MUST NOT: sync `settings.json` as a whole file — enumerate a manifest and merge
`~/.claude/settings.json` mixes machine-neutral preferences with machine-specific absolute paths:
`hooks` commands pointing at local scripts, `statusLine` pointing at a local script, and
machine-local `permissions.allow`. Copying it across machines breaks all of them.

So the brain tracks `settings.recommended.json` — an **enumerated allowlist** of machine-neutral
keys — and `apply-settings` merges it recursively (manifest wins). **Any key absent from the
manifest is left exactly as it is on that machine**, which is what preserves the local `hooks`.

- Belongs in the manifest: `permissions.defaultMode`, `model`, `effortLevel`, `skillOverrides`,
  `enabledPlugins`, `extraKnownMarketplaces`, and UI prefs (`theme`, `tui`).
- **`enabledPlugins` without `extraKnownMarketplaces` is vacuous** — a plugin toggle for a
  marketplace the new machine has never registered does nothing. Ship the pair.
- Stays out: `hooks`, `statusLine`, `permissions.allow`, and any `skip*` permission-prompt flag —
  quietly relaxing another machine's prompts should be an explicit per-machine choice.
- **Never** put `~/.claude.json` in a brain: per-project state, MCP disable lists, `numStartups` —
  machine-specific startup bookkeeping that conflicts endlessly when shared.

## Connect procedure (per machine, idempotent)

1. Install the harness (marketplace) — already done if you are reading this.
2. Clone the brain repo to a stable absolute path, e.g. `C:/Users/<you>/dev/personal/<brain>`.
3. Run the connector **from the brain** (copy the matching `template/` script in if it lacks one):

   ```powershell
   # Windows — file symlinks need Developer Mode (Settings > System > For developers)
   pwsh -NoProfile -File C:/Users/<you>/dev/personal/<brain>/setup.ps1 `
       -ProjectPath "<absolute path of the project to attach memory to>" `
       -ProjectName "<that project's name>" -RegisterHooks
   pwsh -NoProfile -File C:/Users/<you>/dev/personal/<brain>/apply-settings.ps1
   ```
   ```bash
   # macOS / Linux
   /Users/<you>/dev/personal/<brain>/setup.sh "<absolute project path>" "<project name>"
   /Users/<you>/dev/personal/<brain>/apply-settings.sh      # needs jq
   ```
   Both setup scripts are **idempotent** — they skip links already correct, re-point moved ones,
   and move any pre-existing real file/dir aside as `*.pre-brain-<stamp>` instead of deleting it.
   Attach more projects later by rerunning with a different project path / name.

### MUST: the settings steps are user-run
`-RegisterHooks` and `apply-settings.*` edit `~/.claude/settings.json`. An agent **MUST NOT** edit
`settings.json` itself — Claude Code's safety classifier blocks agent self-modification of
settings. The user **MUST** run those (via the `!` prefix or a terminal). The agent generates the
exact command and **verifies the result afterward**.

### MUST: always use absolute paths
PowerShell `-File ~/...` and `-ProjectPath ~/...` do **NOT** expand `~` — a `~`-prefixed
`-ProjectPath` produces a broken project key (`~-dev-...`). Always pass `C:/Users/<you>/...`.

### MUST: audit before the first push, because push is unreviewed
`sync push` is `git add -A` + auto-commit + auto-push on `SessionEnd`. Anything placed in the brain
is published without review, and discovering it afterward is too late. Before moving content in:
scan it for credentials, and confirm the remote is **private**
(`gh repo view <owner>/<repo> --json visibility`).

## Relocating an existing brain
Run `relocate.ps1` from the brain's **new** location (Windows), or rerun `setup.sh` (macOS/Linux)
and fix the two sync-hook paths by hand. Links re-point themselves; the sync hook commands in
`settings.json` are the one place a stale absolute brain path survives, since hook commands are
machine-specific and never synced. `relocate.ps1` removes only the junction **link** via
`(Get-Item).Delete()` — **never** `Remove-Item -Recurse` on a junction (that deletes the target).

## Cross-platform note
Directories link as **junctions** on Windows (no privilege needed) and symlinks on macOS/Linux.
Files (`CLAUDE.md`, `persona.md`) need **symlinks** on Windows too, which require Developer Mode or
one elevated run. Do **not** substitute a hardlink: `git pull` replaces the file inode, silently
orphaning the link while it still looks valid. The **contract — not the script language — is what
the harness standardizes.**

## Verify after connecting

Evidence, not "it synced". Every link must resolve to brain content, and one edit must survive a
real round-trip.

```bash
# 1. links resolve into the brain (macOS/Linux; use (Get-Item x).Target on Windows)
readlink ~/.claude/CLAUDE.md ~/.claude/persona.md
for s in ~/.claude/skills/*/; do printf '%s -> %s\n' "$s" "$(readlink "${s%/}")"; done

# 2. content is byte-identical through the link
md5 -q ~/.claude/skills/<name>/SKILL.md; md5 -q <brain>/skills/<name>/SKILL.md

# 3. grep across linked skills needs -R, NOT -r.
#    `grep -r` does not follow symlinks found during recursion, so once skills are links it
#    traverses ZERO files and reports 0 hits for anything — a false green.
grep -Rn '<pattern>' ~/.claude/skills/ ; grep -Rl '' ~/.claude/skills/ | wc -l   # 2nd cmd must be > 0

# 4. the merge left machine-specific keys alone
jq '.hooks' ~/.claude/settings.json      # before and after apply-settings -> identical

# 5. round-trip: edit one SKILL.md on machine A -> end session -> start session on machine B
#    -> diff that exact file. A clean `git status --porcelain` proves the push, not the content.
```

## Reference brain
The canonical conforming brain is the private **claude-brain** SSOT (`persona.md`, `CLAUDE.md`,
`skills/`, `commands/`, `memory/<project>/`, `settings.recommended.json`, plus
`setup`/`sync`/`relocate`/`apply-settings` in both shells). The scripts under `template/` are the
generalized, brain-neutral copies of those.
