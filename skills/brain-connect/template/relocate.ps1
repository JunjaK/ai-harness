#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Re-point ALL brain wiring (persona @import, memory junction, sync hooks) to THIS script's own
  location. Run once from the brain's NEW location after moving/cloning it to a new path or remote.
  Idempotent; backs up CLAUDE.md and settings.json; validates settings.json JSON.
.EXAMPLE
  pwsh -File relocate.ps1 -ProjectPath "C:\Users\me\dev\app" -ProjectName "app"
#>
[CmdletBinding()]
param([string]$ProjectPath = "$env:USERPROFILE\dev\app", [string]$ProjectName = 'app')
$ErrorActionPreference = 'Stop'
$new = $PSScriptRoot
$newFwd = $new -replace '\\', '/'
$claude = Join-Path $env:USERPROFILE '.claude'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Write-Host "relocate brain wiring -> $new"

# 1) persona @import in ~/.claude/CLAUDE.md
$md = Join-Path $claude 'CLAUDE.md'
if (Test-Path $md) {
    Copy-Item $md "$md.bak-$stamp"
    $c = [IO.File]::ReadAllText($md)
    $c2 = [regex]::Replace($c, '@[^\r\n]*?/persona\.md', "@$newFwd/persona.md")
    if ($c2 -ne $c) { [IO.File]::WriteAllText($md, $c2); Write-Host "  + @import -> @$newFwd/persona.md" }
    else { Write-Host "  = @import already correct (or absent)" }
}

# 2) memory junction
$key = ($ProjectPath -replace '[:\\/]', '-')
$link = Join-Path $claude "projects\$key\memory"
$target = Join-Path $new "memory\$ProjectName"
New-Item -ItemType Directory -Path $target -Force | Out-Null
$cur = Get-Item $link -ErrorAction SilentlyContinue
if ($cur -and $cur.LinkType -eq 'Junction') {
    if ($cur.Target -ne $target) {
        $cur.Delete()                                   # removes the junction link only, not target contents
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        Write-Host "  + junction re-pointed -> $target"
    }
    else { Write-Host "  = junction already correct" }
}
elseif ($cur) {
    Get-ChildItem $link -File -EA SilentlyContinue | ForEach-Object {
        $d = Join-Path $target $_.Name; if (-not (Test-Path $d)) { Copy-Item $_.FullName $d }
    }
    Rename-Item $link "memory.pre-brain-$stamp"
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Host "  + junction created (migrated) -> $target"
}
else {
    New-Item -ItemType Directory -Path (Split-Path $link -Parent) -Force | Out-Null
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    Write-Host "  + junction created -> $target"
}

# 3) sync hooks in ~/.claude/settings.json  (matches any prior brain location)
$s = Join-Path $claude 'settings.json'
if (Test-Path $s) {
    Copy-Item $s "$s.bak-$stamp"
    $j = Get-Content $s -Raw | ConvertFrom-Json
    $changed = $false
    foreach ($evt in 'SessionStart', 'SessionEnd') {
        foreach ($m in @($j.hooks.$evt)) {
            foreach ($h in @($m.hooks)) {
                if ($h.command -match '[\\/]sync\.ps1') {
                    $repl = [regex]::Replace($h.command, '(?i)[A-Za-z]:[\\/][^"]*?[\\/]sync\.ps1', ($new + '\sync.ps1'))
                    if ($repl -ne $h.command) { $h.command = $repl; $changed = $true }
                }
            }
        }
    }
    if ($changed) {
        $j | ConvertTo-Json -Depth 100 | Set-Content $s -Encoding UTF8
        try { Get-Content $s -Raw | ConvertFrom-Json | Out-Null; Write-Host "  + sync hooks re-pointed [backup: settings.json.bak-$stamp]" }
        catch { Copy-Item "$s.bak-$stamp" $s -Force; Write-Host "  ! invalid JSON -> restored backup" }
    }
    else { Write-Host "  = sync hooks already correct (or none)" }
}
Write-Host "done. old location is now unreferenced (safe to delete)."
