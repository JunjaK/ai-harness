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

# Parse the test command ONCE into an executable + fixed args. We invoke via the
# call operator (&) and pass the filename as a separate literal argument, so a
# maliciously-named test file (backticks, $(...), ;) is never re-parsed as code.
# (Do NOT use Invoke-Expression here — it would evaluate the filename as script.)
$cmdTokens = @($TestCommand -split '\s+' | Where-Object { $_ -ne '' })
$exe = $cmdTokens[0]
$exeArgs = @($cmdTokens | Select-Object -Skip 1)

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

  # Run the single test file via the call operator: the path is passed as one
  # literal argument and never re-parsed. Exit status ignored — we only care about pollution.
  try { & $exe @exeArgs $file.FullName *> $null } catch { }

  if (Test-Path $PollutionCheck) {
    Write-Host ""
    Write-Host "🎯 FOUND POLLUTER!"
    Write-Host "   Test: $($file.FullName)"
    Write-Host "   Created: $PollutionCheck"
    Write-Host ""
    Write-Host "Pollution details:"
    Get-Item $PollutionCheck | Format-List
    Write-Host "To investigate, run that one test file with your test runner, e.g.:"
    Write-Host "  & $exe $($exeArgs -join ' ') '$($file.FullName)'"
    exit 1
  }
}

Write-Host ""
Write-Host "✅ No polluter found - all tests clean!"
exit 0
