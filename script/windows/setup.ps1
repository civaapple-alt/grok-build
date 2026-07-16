#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot Windows toolchain prep: Rust + protoc (+ optional Cargo config).

.DESCRIPTION
  Idempotent. Safe to re-run.
  1) install-rust.ps1
  2) install-protoc.ps1
  3) optional install-cargo-config.ps1
  4) check-tools.ps1

.EXAMPLE
  .\script\windows\setup.ps1
  .\script\windows\setup.ps1 -InstallRustup -CargoConfig
#>
[CmdletBinding()]
param(
    [switch]$InstallRustup,
    [switch]$CargoConfig,
    [switch]$ForceProtoc
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

Write-Host "=== 1/4 install-rust ==="
# Hashtable splat so -InstallRustup is a named switch, not a positional string.
$rustArgs = @{}
if ($InstallRustup) { $rustArgs['InstallRustup'] = $true }
& (Join-Path $PSScriptRoot 'install-rust.ps1') @rustArgs
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== 2/4 install-protoc ==="
$protocArgs = @{}
if ($ForceProtoc) { $protocArgs['Force'] = $true }
& (Join-Path $PSScriptRoot 'install-protoc.ps1') @protocArgs
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($CargoConfig) {
    Write-Host ""
    Write-Host "=== 3/4 install-cargo-config ==="
    & (Join-Path $PSScriptRoot 'install-cargo-config.ps1')
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host ""
    Write-Host "=== 3/4 install-cargo-config (skipped) ==="
    Write-Host "Pass -CargoConfig to write %USERPROFILE%\.cargo\config.toml"
}

Write-Host ""
Write-Host "=== 4/4 check-tools ==="
& (Join-Path $PSScriptRoot 'check-tools.ps1')

Write-Host ""
Write-Host "Setup complete. Build with: .\script\windows\build.ps1"
