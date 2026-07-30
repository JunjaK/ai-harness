---
description: "Brain Connect — pair an optional personal brain SSOT (cross-machine persona, global CLAUDE.md, personal global skills, auto-memory, recommended-settings manifest) with the harness on a machine, or relocate an existing one"
---

# Brain Connect

Wire an optional personal **brain** SSOT — a separate private repo holding everything you want identical across machines — into this machine's Claude Code environment, or re-point an existing one after it moves.

## Usage

```
/brain-connect <brain-path>   # inspect the brain at <brain-path> and emit the exact connect command
/brain-connect                # explain the brain contract + how to connect / relocate
```

## What It Does

Invoke the `brain-connect` skill:

1. Confirm the brain at `<brain-path>` against the **contract** — `persona.md` + `CLAUDE.md` + `skills/<name>/` + `commands/` + `memory/<project>/` → links, `settings.recommended.json` → merged settings, optional `sync.{ps1,sh}` → SessionStart/End sync hooks. Every layer is optional; report which are present.
2. Generate the exact command for the user to run — `setup.ps1 -ProjectPath <abs> -ProjectName <name> [-RegisterHooks]` (Windows) or `setup.sh <abs> <name>` (macOS/Linux), then `apply-settings.*`. The settings.json / hooks step is **user-run** — agents are blocked from editing settings.json by Claude Code's safety classifier.
3. For a moved or re-homed brain, route to `relocate.ps1` (run from the brain's new location) or rerun `setup.sh`.
4. After the user runs it, verify with evidence: every link target resolves into the brain, content is byte-identical through the link, `jq '.hooks'` is unchanged by the merge, and one edit survives a real cross-machine round-trip.

Notes:
- Always use **absolute paths** — PowerShell does not expand `~` in `-File` / `-ProjectPath`.
- **Never link the whole `skills/` dir** — one link per brain-owned skill, or third-party skills installed there get hidden.
- **Never sync `settings.json` whole** — it holds machine-specific absolute paths; merge the enumerated manifest instead.
- **Files need symlinks, directories can use junctions** — never a hardlink for a file: `git pull` replaces the inode and silently orphans it.
- `sync push` is `git add -A` + auto-push: credential-scan content and confirm the remote is private **before** moving it into the brain.
- The harness ships the generic connector scripts as a copyable template (`skills/brain-connect/template/`) and has **zero runtime dependency** on any brain. The reference conforming brain is the private claude-brain SSOT.
