<#
.SYNOPSIS
  Bisection helper to find which test creates unwanted files/state (pollution).

.DESCRIPTION
  Runs matching test files one-by-one and stops at the first that creates the
  pollution artifact. PowerShell port of the systematic-debugging bisection
  technique (Windows-first; the harness default shell).

.PARAMETER PollutionCheck
  Path that should NOT exist after a clean test run (e.g. '.git', 'tmp-output').

.PARAMETER TestPattern
  Glob for the test files to bisect (e.g. 'src/**/*.test.ts').

.PARAMETER TestCommand
  Command used to run a single test file. Default 'bun test'. Use the project's
  detected runner ('pnpm test', 'npm test', 'npx vitest run', ...).

.EXAMPLE
  ./find-polluter.ps1 -PollutionCheck '.git' -TestPattern 'src/**/*.test.ts'

.EXAMPLE
  ./find-polluter.ps1 -PollutionCheck 'tmp' -TestPattern 'test/**/*.spec.ts' -TestCommand 'pnpm test'
#>
param(
  [Parameter(Mandatory = $true)] [string] $PollutionCheck,
  [Parameter(Mandatory = $true)] [string] $TestPattern,
  [string] $TestCommand = 'bun test'
)

$ErrorActionPreference = 'Stop'

Write-Host "🔍 Searching for test that creates: $PollutionCheck"
Write-Host "Test pattern: $TestPattern"
Write-Host ""

$testFiles = Get-ChildItem -Path . -Recurse -File |
  Where-Object { $_.FullName.Replace('\', '/') -like "*$TestPattern" } |
  Sort-Object FullName

$total = @($testFiles).Count
Write-Host "Found $total test files"
Write-Host ""

$count = 0
foreach ($file in $testFiles) {
  $count++

  if (Test-Path $PollutionCheck) {
    Write-Host "⚠️  Pollution already exists before test $count/$total"
    Write-Host "   Skipping: $($file.FullName)"
    continue
  }

  Write-Host "[$count/$total] Testing: $($file.FullName)"

  # Run the single test file; ignore its exit status, we only care about pollution.
  try { Invoke-Expression "$TestCommand `"$($file.FullName)`"" *> $null } catch { }

  if (Test-Path $PollutionCheck) {
    Write-Host ""
    Write-Host "🎯 FOUND POLLUTER!"
    Write-Host "   Test: $($file.FullName)"
    Write-Host "   Created: $PollutionCheck"
    Write-Host ""
    Write-Host "Pollution details:"
    Get-Item $PollutionCheck | Format-List
    Write-Host "To investigate:"
    Write-Host "  $TestCommand `"$($file.FullName)`"   # Run just this test"
    exit 1
  }
}

Write-Host ""
Write-Host "✅ No polluter found - all tests clean!"
exit 0
