---
description: "Brain Connect — pair an optional personal brain SSOT (cross-machine persona + auto-memory) with the harness on a machine, or relocate an existing one"
---

# Brain Connect

Wire an optional personal **brain** SSOT — a separate repo holding your cross-machine `persona.md` + harness auto-memory — into this machine's Claude Code environment, or re-point an existing one after it moves.

## Usage

```
/brain-connect <brain-path>   # inspect the brain at <brain-path> and emit the exact connect command
/brain-connect                # explain the brain contract + how to connect / relocate
```

## What It Does

Invoke the `brain-connect` skill:

1. Confirm the brain at `<brain-path>` against the **contract** — `persona.md` → `@import`, `memory/<project>/` → memory junction, optional `sync.ps1` → SessionStart/End sync hooks.
2. Generate the exact `setup.ps1 -ProjectPath <abs> -ProjectName <name> [-RegisterHooks]` command for the user to run. The settings.json / hooks step is **user-run** — agents are blocked from editing settings.json by Claude Code's safety classifier.
3. For a moved or re-homed brain, route to `relocate.ps1` (run from the brain's new location).
4. After the user runs it, verify: `@import` line, junction `Target`, and `settings.json` validity.

Notes:
- Always use **absolute paths** — PowerShell does not expand `~` in `-File` / `-ProjectPath`.
- The harness ships the generic connector scripts as a copyable template (`skills/brain-connect/template/`) and has **zero runtime dependency** on any brain. The reference conforming brain is the private claude-brain SSOT.
