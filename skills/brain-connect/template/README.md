# Brain connector template

Generic, brain-neutral scripts that wire a personal **brain** SSOT repo into a machine's
Claude Code environment. Copy the ones you need into your brain repo and run them **from there**
(each uses its own location via `$PSScriptRoot`). The full brain contract is in [`../SKILL.md`](../SKILL.md).

| Script | Purpose |
|--------|---------|
| `setup.ps1` | First-time per-machine wiring: persona `@import` (if the brain has `persona.md`) + memory junction + (`-RegisterHooks`) auto-sync hooks. Idempotent; migrates any pre-existing memory. |
| `sync.ps1`  | `pull` / `push` helper invoked by the session hooks. Fail-open — never blocks a session. |
| `relocate.ps1` | Re-point all wiring after the brain folder moves or its remote changes. Run from the brain's **new** location. |

## Quick start

```powershell
# in your brain repo, on a new machine:
pwsh -NoProfile -File ./setup.ps1 `
    -ProjectPath "C:/Users/<you>/dev/<project>" -ProjectName "<project>" -RegisterHooks
```

## Notes

- **`-RegisterHooks` edits `~/.claude/settings.json`** — run it yourself (an agent is blocked from editing settings by Claude Code's safety classifier).
- **Always use absolute paths** — PowerShell does not expand `~` in `-File` / `-ProjectPath` (a `~`-prefixed path yields a broken project key).
- **Windows uses junctions.** On macOS/Linux substitute a symlink (`ln -s`) and port the three steps; the contract is the same.
- `relocate.ps1` removes only the junction **link** (`(Get-Item).Delete()`). Never run `Remove-Item -Recurse` on a junction — it deletes the link's target.
