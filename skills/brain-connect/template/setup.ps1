#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Wire this machine to a personal "brain" repo: persona @-import + memory junction + (opt) auto-sync hooks.
.DESCRIPTION
  Generic connector — copy into your brain repo and run from there (it uses its own location, $PSScriptRoot).
  Idempotent. Run once per machine. Computes THIS machine's project key automatically,
  so work/home (different usernames/paths) each map their own key -> the same shared brain.
  The brain may expose: persona.md (optional), memory/<ProjectName>/ (optional),
  sync.ps1 (optional, required only for -RegisterHooks). See ../SKILL.md for the brain contract.
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

# 1) Persona @-import into ~/.claude/CLAUDE.md  (skip if the brain has no persona.md)
$claudeMd = Join-Path $claude 'CLAUDE.md'
$personaPath = Join-Path $brain 'persona.md'
if (Test-Path $personaPath) {
    $importLine = "@$($brain -replace '\\','/')/persona.md"
    if (-not (Test-Path $claudeMd)) { New-Item -ItemType File -Path $claudeMd -Force | Out-Null }
    $md = (Get-Content $claudeMd -Raw -ErrorAction SilentlyContinue)
    if ($null -eq $md -or $md -notmatch [regex]::Escape($importLine)) {
        Add-Content -Path $claudeMd -Value "`n$importLine`n"
        Write-Host "  + persona import added to CLAUDE.md"
    }
    else { Write-Host "  = persona import already present" }
}
else { Write-Host "  - no persona.md in brain -> skipping @import" }

# 2) Memory junction (per-environment mapping: local key -> shared repo)
$key = ($ProjectPath -replace '[:\\/]', '-')
$memLink = Join-Path $claude "projects\$key\memory"
$memTarget = Join-Path $brain "memory\$ProjectName"
New-Item -ItemType Directory -Path $memTarget -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $memLink -Parent) -Force | Out-Null

$existing = Get-Item $memLink -ErrorAction SilentlyContinue
if ($existing -and $existing.LinkType -eq 'Junction') {
    Write-Host "  = memory already junctioned ($key)"
}
elseif ($existing) {
    Get-ChildItem $memLink -File -ErrorAction SilentlyContinue | ForEach-Object {
        $dst = Join-Path $memTarget $_.Name
        if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst }
    }
    Rename-Item $memLink "memory.pre-brain-$stamp"
    New-Item -ItemType Junction -Path $memLink -Target $memTarget | Out-Null
    Write-Host "  + migrated + junctioned memory ($key)  [backup: memory.pre-brain-$stamp]"
}
else {
    New-Item -ItemType Junction -Path $memLink -Target $memTarget | Out-Null
    Write-Host "  + junctioned memory ($key)"
}

# 3) Auto-sync hooks (opt-in; backs up + validates settings.json). Requires brain/sync.ps1.
if ($RegisterHooks) {
    if (-not (Test-Path (Join-Path $brain 'sync.ps1'))) {
        Write-Host "  ! -RegisterHooks given but brain has no sync.ps1 -> skipping hooks"
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
            Write-Host "  ! hook registration produced invalid JSON -> restored backup"
        }
    }
}
Write-Host 'done.'
