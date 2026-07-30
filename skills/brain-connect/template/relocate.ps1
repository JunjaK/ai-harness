#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Re-point ALL brain wiring to THIS script's own location. Run once from the brain's NEW location
  after moving/cloning it to a new path or remote.
.DESCRIPTION
  Two parts:
    1. Links (CLAUDE.md, persona.md, skills, commands, memory) — delegated to setup.ps1, whose
       Link-Brain already deletes a link whose target has moved and recreates it at $PSScriptRoot.
    2. The sync hooks in ~/.claude/settings.json — the ONLY place a stale absolute brain path can
       survive, because hook commands are machine-specific and never synced. Re-pointed in place
       (setup.ps1 -RegisterHooks would append a second hook rather than fix the old one).

  A brain whose CLAUDE.md still uses an ABSOLUTE persona @import (the pre-link shape) needs that
  line changed to the relative "@persona.md" once — after that no machine path lives in synced
  content, and relocation is purely a link + hook operation.
.EXAMPLE
  pwsh -File relocate.ps1 -ProjectPath "C:\Users\me\dev\app" -ProjectName "app"
#>
[CmdletBinding()]
param([string]$ProjectPath = "$env:USERPROFILE\dev\app", [string]$ProjectName = 'app')
$ErrorActionPreference = 'Stop'
$new = $PSScriptRoot
$claude = Join-Path $env:USERPROFILE '.claude'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Write-Host "relocate brain wiring -> $new"

# 1) all links
& (Join-Path $new 'setup.ps1') -ProjectPath $ProjectPath -ProjectName $ProjectName

# 2) sync hook paths in settings.json
$s = Join-Path $claude 'settings.json'
if (Test-Path $s) {
    Copy-Item $s "$s.bak-$stamp"
    $j = Get-Content $s -Raw | ConvertFrom-Json
    $changed = $false
    foreach ($evt in 'SessionStart', 'SessionEnd') {
        foreach ($m in @($j.hooks.$evt)) {
            foreach ($h in @($m.hooks)) {
                if ($h.command -match 'sync\.ps1') {
                    $repl = [regex]::Replace($h.command, '(?i)[A-Za-z]:[\\/][^"]*?[\\/]sync\.ps1', ($new + '\sync.ps1'))
                    if ($repl -ne $h.command) { $h.command = $repl; $changed = $true }
                }
            }
        }
    }
    if ($changed) {
        $j | ConvertTo-Json -Depth 100 | Set-Content $s -Encoding UTF8
        try { Get-Content $s -Raw | ConvertFrom-Json | Out-Null; Write-Host "  + sync hooks re-pointed [backup: settings.json.bak-$stamp]" }
        catch { Copy-Item "$s.bak-$stamp" $s -Force; Write-Host '  ! invalid JSON -> restored backup' }
    }
    else { Write-Host '  = sync hooks already correct (or none)' }
}
Write-Host 'done. old location is now unreferenced (safe to delete).'
