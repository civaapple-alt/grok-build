#Requires -Version 5.1
<#
.SYNOPSIS
  Build xai-grok-pager-bin with Windows-friendly linker settings.

.EXAMPLE
  .\script\windows\build.ps1
  .\script\windows\build.ps1 -Release
  .\script\windows\build.ps1 -- --verbose
#>
[CmdletBinding()]
param(
    [switch]$Release,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CargoArgs
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'env.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$argsList = @('build', '-p', 'xai-grok-pager-bin')
if ($Release) {
    $argsList += '--release'
}
if ($CargoArgs) {
    $argsList += $CargoArgs
}

Write-Host "cargo $($argsList -join ' ')"
& cargo @argsList
exit $LASTEXITCODE
