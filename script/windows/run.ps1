#Requires -Version 5.1
<#
.SYNOPSIS
  Run xai-grok-pager: default is `cargo run`; optional switches run a prebuilt exe.

.DESCRIPTION
  Default: apply Windows build env, then
    cargo run -p xai-grok-pager-bin [-- <args>]

  -DebugExe    run target\debug\xai-grok-pager.exe (must already exist)
  -ReleaseExe  run target\release\xai-grok-pager.exe (must already exist)

  Build separately with:
    .\script\windows\build.ps1
    .\script\windows\build.ps1 -Release

.EXAMPLE
  .\script\windows\run.ps1
  .\script\windows\run.ps1 -- --help
  .\script\windows\run.ps1 "fix the bug"
  .\script\windows\run.ps1 -DebugExe
  .\script\windows\run.ps1 -ReleaseExe -- --help
#>
[CmdletBinding()]
param(
    [switch]$DebugExe,
    [switch]$ReleaseExe,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AppArgs
)

$ErrorActionPreference = 'Stop'

if ($DebugExe -and $ReleaseExe) {
    throw 'Use only one of -DebugExe or -ReleaseExe.'
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

# Strip a lone leading "--" used to separate script switches from app/cargo args.
if ($AppArgs -and $AppArgs.Count -gt 0 -and $AppArgs[0] -eq '--') {
    $AppArgs = $AppArgs[1..($AppArgs.Count - 1)]
}

function Invoke-PrebuiltExe([string]$ProfileDir) {
    $exe = Join-Path $repoRoot "target\$ProfileDir\xai-grok-pager.exe"
    if (-not (Test-Path -LiteralPath $exe)) {
        $hint = if ($ProfileDir -eq 'release') {
            '.\script\windows\build.ps1 -Release'
        } else {
            '.\script\windows\build.ps1'
        }
        throw "Binary not found: $exe`nBuild first with: $hint"
    }
    Write-Host "Running $exe $($AppArgs -join ' ')"
    & $exe @AppArgs
    exit $LASTEXITCODE
}

if ($DebugExe) {
    Invoke-PrebuiltExe -ProfileDir 'debug'
}

if ($ReleaseExe) {
    Invoke-PrebuiltExe -ProfileDir 'release'
}

# Default: cargo run (compile-as-needed via Cargo)
& (Join-Path $PSScriptRoot 'env.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$cargoArgs = @('run', '-p', 'xai-grok-pager-bin')
if ($AppArgs -and $AppArgs.Count -gt 0) {
    $cargoArgs += '--'
    $cargoArgs += $AppArgs
}

Write-Host "cargo $($cargoArgs -join ' ')"
& cargo @cargoArgs
exit $LASTEXITCODE
