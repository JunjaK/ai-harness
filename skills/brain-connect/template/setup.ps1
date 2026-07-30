#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Wire this machine to a personal "brain" repo: global CLAUDE.md + persona + skills + commands +
  memory links, and (opt) auto-sync hooks.
.DESCRIPTION
  Generic connector — copy into your brain repo and run from there (it uses its own location,
  $PSScriptRoot). Idempotent. Computes THIS machine's project key automatically, so work/home
  (different usernames/paths) each map their own key -> the same shared brain.

  Every layer is OPTIONAL; a layer the brain does not provide is skipped:
    <brain>\CLAUDE.md       -> ~\.claude\CLAUDE.md
    <brain>\persona.md      -> ~\.claude\persona.md
    <brain>\skills\<name>\  -> ~\.claude\skills\<name>          (one link per skill)
    <brain>\commands\       -> ~\.claude\commands\brain         (namespaced)
    <brain>\memory\<name>\  -> ~\.claude\projects\<key>\memory
    <brain>\sync.ps1        -> SessionStart/SessionEnd hooks    (needs -RegisterHooks)
  See ..\SKILL.md for the brain contract.

  File links are SymbolicLinks, which on Windows require Developer Mode (Settings > System >
  For developers) or one elevated run. Hardlinks are deliberately NOT used: `git pull` replaces
  the file inode, which would silently orphan a hardlink.

  Recommended settings.json keys are NOT applied here — run apply-settings.ps1 for that.
.EXAMPLE
  pwsh -File setup.ps1 -ProjectPath "C:\Users\me\dev\app" -ProjectName "app" -RegisterHooks
#>
[CmdletBinding()]
param(
    [string]$ProjectPath = "$env:USERPROFILE\dev\app",
    [string]$ProjectName = 'app',
    [switch]$RegisterHooks
)
$ErrorActionPreference = 'Stop'
$brain = $PSScriptRoot
$claude = Join-Path $env:USERPROFILE '.claude'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Write-Host "brain setup  (brain=$brain)"

# Idempotent junction (directories) / symlink (files). Moves any real item aside, never deletes it.
function Link-Brain($src, $dst) {
    $type = if (Test-Path $src -PathType Container) { 'Junction' } else { 'SymbolicLink' }
    $cur = Get-Item $dst -Force -ErrorAction SilentlyContinue
    if ($cur -and $cur.LinkType) {
        if ($cur.Target -eq $src) { Write-Host "  = $dst"; return }
        $cur.Delete()   # removes the link only, never the target's contents
    }
    elseif ($cur) {
        Rename-Item $dst "$($cur.Name).pre-brain-$stamp"
        Write-Host "  ~ moved aside -> $($cur.Name).pre-brain-$stamp"
    }
    New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
    try { New-Item -ItemType $type -Path $dst -Target $src -ErrorAction Stop | Out-Null }
    catch {
        throw ("cannot create $type at $dst -- file symlinks need Developer Mode " +
            "(Settings > System > For developers) or one elevated run. Original: $_")
    }
    Write-Host "  + $dst -> $src"
}

# 1) Global rules + persona. If the brain ships BOTH, keep the import inside its CLAUDE.md
#    RELATIVE ("@persona.md") and link persona.md next to CLAUDE.md: the relative form then
#    resolves under either base dir Claude Code might use, and carries no machine path.
if (Test-Path (Join-Path $brain 'CLAUDE.md')) { Link-Brain (Join-Path $brain 'CLAUDE.md') (Join-Path $claude 'CLAUDE.md') }
else { Write-Host '  - no CLAUDE.md in brain -> skipped' }
if (Test-Path (Join-Path $brain 'persona.md')) { Link-Brain (Join-Path $brain 'persona.md') (Join-Path $claude 'persona.md') }
else { Write-Host '  - no persona.md in brain -> skipped' }

# 2) Brain-owned global skills -- ONE LINK PER SKILL, never the whole skills\ dir: third-party
#    skills live in ~\.claude\skills too, and linking the directory itself would hide them.
if (Test-Path (Join-Path $brain 'skills')) {
    Get-ChildItem (Join-Path $brain 'skills') -Directory | ForEach-Object {
        Link-Brain $_.FullName (Join-Path $claude "skills\$($_.Name)")
    }
}
else { Write-Host '  - no skills\ in brain -> skipped' }

# 2b) Brain-owned commands, namespaced so it never clobbers user-level commands
$cmdSrc = Join-Path $brain 'commands'
if (Test-Path $cmdSrc) { Link-Brain $cmdSrc (Join-Path $claude 'commands\brain') }

# 3) Per-project auto-memory. Claude Code keys per-project state by absolute path, so each machine
#    has a different key -- the junction IS the per-machine mapping onto one shared dir.
$key = ($ProjectPath -replace '[:\\/]', '-')
$memLink = Join-Path $claude "projects\$key\memory"
$memTarget = Join-Path $brain "memory\$ProjectName"
New-Item -ItemType Directory -Path $memTarget -Force | Out-Null
$memCur = Get-Item $memLink -Force -ErrorAction SilentlyContinue
if ($memCur -and -not $memCur.LinkType) {
    Get-ChildItem $memLink -File -ErrorAction SilentlyContinue | ForEach-Object {
        $dst = Join-Path $memTarget $_.Name
        if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst; Write-Host "  ~ migrated memory file: $($_.Name)" }
    }
}
Link-Brain $memTarget $memLink

# 4) Auto-sync hooks (opt-in; backs up + validates settings.json). Requires brain\sync.ps1.
if ($RegisterHooks) {
    if (-not (Test-Path (Join-Path $brain 'sync.ps1'))) {
        Write-Host '  ! -RegisterHooks given but brain has no sync.ps1 -> skipping hooks'
    }
    else {
        $settings = Join-Path $claude 'settings.json'
        if (-not (Test-Path $settings)) { '{}' | Set-Content $settings -Encoding UTF8 }
        Copy-Item $settings "$settings.bak-$stamp"
        $cfg = Get-Content $settings -Raw | ConvertFrom-Json
        if (-not $cfg.hooks) { $cfg | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) }
        $pull = "pwsh -NoProfile -File `"$brain\sync.ps1`" pull"
        $push = "pwsh -NoProfile -File `"$brain\sync.ps1`" push"
        function Add-SyncHook($evt, $cmd, $to) {
            if (-not $cfg.hooks.PSObject.Properties.Name.Contains($evt)) {
                $cfg.hooks | Add-Member -NotePropertyName $evt -NotePropertyValue @()
            }
            foreach ($m in $cfg.hooks.$evt) { foreach ($h in $m.hooks) { if ($h.command -eq $cmd) { return } } }
            $cfg.hooks.$evt = @($cfg.hooks.$evt) + [pscustomobject]@{
                matcher = ''; hooks = @([pscustomobject]@{ type = 'command'; command = $cmd; timeout = $to })
            }
        }
        Add-SyncHook 'SessionStart' $pull 20
        Add-SyncHook 'SessionEnd' $push 60
        $cfg | ConvertTo-Json -Depth 100 | Set-Content $settings -Encoding UTF8
        try {
            Get-Content $settings -Raw | ConvertFrom-Json | Out-Null
            Write-Host "  + sync hooks registered  [backup: settings.json.bak-$stamp]"
        }
        catch {
            Copy-Item "$settings.bak-$stamp" $settings -Force
            Write-Host '  ! hook registration produced invalid JSON -> restored backup'
        }
    }
}
Write-Host 'done.  next: pwsh -File apply-settings.ps1   (recommended settings.json keys)'
