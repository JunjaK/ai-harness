# Brain connector template

Generic, brain-neutral scripts that wire a personal **brain** SSOT repo into a machine's
Claude Code environment. Copy the ones you need into your brain repo and run them **from there**
(each uses its own location via `$PSScriptRoot` / `dirname $0`). The full brain contract is in
[`../SKILL.md`](../SKILL.md).

| Script | Purpose |
|--------|---------|
| `setup.ps1` / `setup.sh` | First-time per-machine wiring: links `CLAUDE.md`, `persona.md`, each `skills/<name>`, `commands/`, and `memory/<project>`. Every layer optional — a layer the brain lacks is skipped. Idempotent; migrates pre-existing memory. `-RegisterHooks` (ps1) adds the sync hooks. |
| `apply-settings.ps1` / `apply-settings.sh` | Merge `settings.recommended.json` into `~/.claude/settings.json`. Recursive, manifest wins, **keys absent from the manifest untouched**. |
| `settings.recommended.json` | Example manifest — the enumerated machine-neutral keys. Replace with your own. |
| `sync.ps1` / `sync.sh` | `pull` / `push` helper invoked by the session hooks. Fail-open — never blocks a session. |
| `relocate.ps1` | Re-point all wiring after the brain folder moves. Delegates links to `setup.ps1`, re-points the sync hooks. Run from the brain's **new** location. |

## Quick start

```powershell
# Windows — file symlinks need Developer Mode (Settings > System > For developers)
pwsh -NoProfile -File ./setup.ps1 `
    -ProjectPath "C:/Users/<you>/dev/<project>" -ProjectName "<project>" -RegisterHooks
pwsh -NoProfile -File ./apply-settings.ps1
```

```bash
# macOS / Linux
./setup.sh "/Users/<you>/dev/<project>" "<project>"
./apply-settings.sh          # needs jq
```

## Notes

- **`-RegisterHooks` and `apply-settings.*` edit `~/.claude/settings.json`** — run them yourself
  (an agent is blocked from editing settings by Claude Code's safety classifier).
- **Always use absolute paths** — PowerShell does not expand `~` in `-File` / `-ProjectPath`
  (a `~`-prefixed path yields a broken project key).
- **One link per skill, never the whole `skills/` dir.** Third-party skills live in
  `~/.claude/skills/` too (often as relative symlinks into another tool's store); linking the
  directory would hide them, and committing them into the brain would break their relative
  targets and auto-commit another tool's files.
- **Keep the persona import relative.** With `CLAUDE.md` linked from the brain, use `@persona.md`
  inside it and link `persona.md` next to it — that resolves under either base dir and keeps every
  machine path out of synced content.
- **Directories link as junctions; files must be symlinks.** Do not substitute a hardlink for a
  file link: `git pull` replaces the file inode and would silently orphan it.
- `relocate.ps1` removes only the junction **link** (`(Get-Item).Delete()`). Never run
  `Remove-Item -Recurse` on a junction — it deletes the link's target.
- **`sync push` is `git add -A` + auto-push.** Anything placed in the brain is published
  unreviewed — keep secrets out, and keep the brain repo private.
