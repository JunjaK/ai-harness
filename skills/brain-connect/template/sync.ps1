#!/usr/bin/env pwsh
# brain sync helper. Fail-open: never blocks/breaks a session.
# Used by the SessionStart (pull) / SessionEnd (push) hooks that setup.ps1 -RegisterHooks installs.
param([Parameter(Mandatory)][ValidateSet('pull', 'push')]$Action)

$ErrorActionPreference = 'SilentlyContinue'
Set-Location $PSScriptRoot

if ($Action -eq 'pull') {
    git pull --rebase --quiet 2>$null
}
else {
    git add -A 2>$null
    if (git status --porcelain 2>$null) {
        git commit -q -m "auto-sync: $env:COMPUTERNAME $(Get-Date -Format o)" 2>$null
        git push -q 2>$null
    }
}
exit 0
