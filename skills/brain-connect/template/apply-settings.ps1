#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Merge settings.recommended.json into ~/.claude/settings.json (Windows). Mirrors apply-settings.sh.
.DESCRIPTION
  Recursive merge, manifest wins. Keys ABSENT from the manifest are left exactly as they are
  on this machine -- that is how machine-specific `hooks` (absolute script paths), `statusLine`,
  `permissions.allow` and any skip* flags survive. Backs up first; restores the backup if the
  merge would produce invalid JSON. No jq dependency.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$brain = $PSScriptRoot
$manifest = Join-Path $brain 'settings.recommended.json'
$settings = Join-Path $env:USERPROFILE '.claude\settings.json'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $manifest)) { throw "no manifest at $manifest" }
if (-not (Test-Path $settings)) {
    New-Item -ItemType Directory -Path (Split-Path $settings -Parent) -Force | Out-Null
    '{}' | Set-Content $settings -Encoding UTF8
}
Copy-Item $settings "$settings.bak-$stamp"

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

$merged = Merge-Node (Get-Content $settings -Raw | ConvertFrom-Json) (Get-Content $manifest -Raw | ConvertFrom-Json)
$merged | ConvertTo-Json -Depth 100 | Set-Content $settings -Encoding UTF8
try {
    Get-Content $settings -Raw | ConvertFrom-Json | Out-Null
    Write-Host "settings merged  [backup: $settings.bak-$stamp]"
}
catch {
    Copy-Item "$settings.bak-$stamp" $settings -Force
    Write-Host '! merge produced invalid JSON -> restored backup'
}
