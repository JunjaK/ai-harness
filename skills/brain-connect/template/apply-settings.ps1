#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Merge settings.recommended.json into the settings.json of every Claude Code config dir (Windows).
  Mirrors apply-settings.sh.
.DESCRIPTION
  Targets: ~/.claude, $env:CLAUDE_CONFIG_DIR when set, and every dir passed in -ConfigDirs (e.g. a
  launcher's per-profile homes). Each config dir keeps its own settings.json, so a key merged into
  one is invisible to sessions started under another.
  Recursive merge, manifest wins. Keys ABSENT from the manifest are left exactly as they are in each
  file -- that is how machine-specific `hooks` (absolute script paths), `statusLine`,
  `permissions.allow` and any skip* flags survive. Backs up each file first; restores the backup if
  the merge would produce invalid JSON. No jq dependency.
.EXAMPLE
  pwsh -NoProfile -File apply-settings.ps1 -ConfigDirs 'C:/Users/me/AppData/Roaming/launcher/profiles/a/home'
#>
[CmdletBinding()]
param([string[]]$ConfigDirs = @())
$ErrorActionPreference = 'Stop'
$brain = $PSScriptRoot
$manifest = Join-Path $brain 'settings.recommended.json'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $manifest)) { throw "no manifest at $manifest" }

# Objects merge key-by-key; scalars and arrays are replaced wholesale (same as jq's `*`).
function Merge-Node($local, $incoming) {
    if ($incoming -isnot [pscustomobject] -or $local -isnot [pscustomobject]) { return $incoming }
    foreach ($p in $incoming.PSObject.Properties) {
        if ($local.PSObject.Properties.Name -contains $p.Name) {
            $local.($p.Name) = Merge-Node $local.($p.Name) $p.Value
        }
        else {
            $local | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
        }
    }
    return $local
}

function Merge-One($dir) {
    $settings = Join-Path $dir 'settings.json'
    if (-not (Test-Path $settings)) { '{}' | Set-Content $settings -Encoding UTF8 }
    Copy-Item $settings "$settings.bak-$stamp"
    $merged = Merge-Node (Get-Content $settings -Raw | ConvertFrom-Json) (Get-Content $manifest -Raw | ConvertFrom-Json)
    $merged | ConvertTo-Json -Depth 100 | Set-Content $settings -Encoding UTF8
    try {
        Get-Content $settings -Raw | ConvertFrom-Json | Out-Null
        Write-Host "merged  $settings  [backup: settings.json.bak-$stamp]"
        return $true
    }
    catch {
        Copy-Item "$settings.bak-$stamp" $settings -Force
        Write-Host "! merge produced invalid JSON -> restored $settings"
        return $false
    }
}

$targets = @((Join-Path $env:USERPROFILE '.claude'))
if ($env:CLAUDE_CONFIG_DIR) { $targets += $env:CLAUDE_CONFIG_DIR }
$targets += $ConfigDirs

$seen = @{}
$failed = $false
foreach ($dir in $targets) {
    if (-not (Test-Path $dir -PathType Container)) {
        if ($dir -eq $targets[0]) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        else { Write-Host "skip    $dir (no such dir)"; continue }
    }
    $real = (Resolve-Path $dir).Path
    if ($seen.ContainsKey($real)) { continue }
    $seen[$real] = $true
    if (-not (Merge-One $real)) { $failed = $true }
}
if ($failed) { exit 1 }
