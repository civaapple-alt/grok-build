#Requires -Version 5.1
<#
.SYNOPSIS
  Run xai-grok-pager.exe (optionally build first).

.EXAMPLE
  .\script\windows\run.ps1
  .\script\windows\run.ps1 -Release
  .\script\windows\run.ps1 -Build -- --help
  .\script\windows\run.ps1 "fix the bug"
#>
[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$Release,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AppArgs
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

$profileDir = if ($Release) { 'release' } else { 'debug' }
$exe = Join-Path $repoRoot "target\$profileDir\xai-grok-pager.exe"

if ($Build -or -not (Test-Path -LiteralPath $exe)) {
    $buildScript = Join-Path $PSScriptRoot 'build.ps1'
    if ($Release) {
        & $buildScript -Release
    } else {
        & $buildScript
    }
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if (-not (Test-Path -LiteralPath $exe)) {
    throw "Binary not found: $exe (pass -Build to compile)"
}

# Strip a lone leading "--" used to separate script switches from app args.
if ($AppArgs -and $AppArgs.Count -gt 0 -and $AppArgs[0] -eq '--') {
    $AppArgs = $AppArgs[1..($AppArgs.Count - 1)]
}

Write-Host "Running $exe $($AppArgs -join ' ')"
& $exe @AppArgs
exit $LASTEXITCODE
