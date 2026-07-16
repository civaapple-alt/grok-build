#Requires -Version 5.1
<#
.SYNOPSIS
  Install/verify rustup and the toolchain pinned by rust-toolchain.toml.

.DESCRIPTION
  Idempotent. Safe to re-run.
  - Ensures rustup is on PATH (offers to download rustup-init if missing)
  - Installs the channel from repo rust-toolchain.toml (e.g. 1.92.0)
  - Ensures rustfmt + clippy components
  - Prints rustup toolchain list / rustc --version / cargo --version

.EXAMPLE
  .\script\windows\install-rust.ps1
  .\script\windows\install-rust.ps1 -InstallRustup
#>
[CmdletBinding()]
param(
    # If rustup is missing, download and run rustup-init.exe -y
    [switch]$InstallRustup
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

function Test-CommandExists([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-PinnedChannel {
    $toml = Join-Path $repoRoot 'rust-toolchain.toml'
    if (-not (Test-Path -LiteralPath $toml)) {
        throw "rust-toolchain.toml not found at $toml"
    }
    $text = Get-Content -LiteralPath $toml -Raw
    if ($text -match 'channel\s*=\s*"([^"]+)"') {
        return $Matches[1]
    }
    throw "Could not parse channel from rust-toolchain.toml"
}

function Ensure-Rustup {
    if (Test-CommandExists 'rustup') {
        return
    }

    # rustup often lands here before PATH is refreshed in the same session
    $cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
    $rustupExe = Join-Path $cargoBin 'rustup.exe'
    if (Test-Path -LiteralPath $rustupExe) {
        $env:Path = "$cargoBin;$env:Path"
        if (Test-CommandExists 'rustup') {
            return
        }
    }

    if (-not $InstallRustup) {
        throw @"
rustup not found on PATH.
Install Rust from https://rustup.rs/ or re-run:
  .\script\windows\install-rust.ps1 -InstallRustup
"@
    }

    $init = Join-Path $env:TEMP 'rustup-init.exe'
    Write-Host "Downloading rustup-init ..."
    Invoke-WebRequest -Uri 'https://win.rustup.rs/x86_64' -OutFile $init
    Write-Host "Running rustup-init -y (default host toolchain) ..."
    & $init -y
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "rustup-init failed with exit code $LASTEXITCODE"
    }
    $env:Path = "$cargoBin;$env:Path"
    if (-not (Test-CommandExists 'rustup')) {
        throw "rustup still not on PATH after install; open a new PowerShell and retry."
    }
}

$channel = Get-PinnedChannel
Write-Host "Pinned toolchain (rust-toolchain.toml): $channel"

Ensure-Rustup

Write-Host ""
Write-Host "=== rustup show ==="
& rustup show
Write-Host ""

Write-Host "Installing toolchain $channel (no-op if already present) ..."
& rustup toolchain install $channel
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "rustup toolchain install $channel failed"
}

Write-Host "Ensuring components rustfmt, clippy on $channel ..."
& rustup component add rustfmt clippy --toolchain $channel
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "rustup component add failed"
}

# Entering the repo makes rustup respect rust-toolchain.toml
Write-Host "Resolving active toolchain in repo ..."
& rustup show active-toolchain

Write-Host ""
Write-Host "=== rustup toolchain list ==="
& rustup toolchain list

Write-Host ""
Write-Host "=== versions ==="
& rustc --version
& cargo --version
& rustup --version

$sysroot = (& rustc --print sysroot).Trim()
$lld = Join-Path $sysroot 'lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'
if (Test-Path -LiteralPath $lld) {
    Write-Host "rust-lld: $lld"
} else {
    Write-Warning "rust-lld not found at $lld (needed by env.ps1 / build.ps1)"
}

Write-Host ""
Write-Host "Rust toolchain ready. Next: .\script\windows\install-protoc.ps1"
