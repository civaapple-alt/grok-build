#Requires -Version 5.1
<#
.SYNOPSIS
  Print status of Rust / protoc / linker tools needed for Windows builds.

.DESCRIPTION
  Idempotent read-only check (does not install). Safe to re-run anytime.

.EXAMPLE
  .\script\windows\check-tools.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

function Show-Tool([string]$Label, [scriptblock]$Action) {
    Write-Host ""
    Write-Host "=== $Label ==="
    try {
        & $Action
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
    }
}

function Test-CommandExists([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

Write-Host "Repo: $repoRoot"

Show-Tool 'rustup' {
    if (-not (Test-CommandExists 'rustup')) {
        Write-Host 'MISSING — run: .\script\windows\install-rust.ps1 -InstallRustup'
        return
    }
    & rustup --version
    & rustup show active-toolchain
    & rustup toolchain list
}

Show-Tool 'rustc / cargo' {
    if (-not (Test-CommandExists 'rustc')) {
        Write-Host 'MISSING rustc'
        return
    }
    & rustc --version
    & rustc --print host-tuple
    & cargo --version
    $sysroot = (& rustc --print sysroot).Trim()
    Write-Host "sysroot: $sysroot"
    $lld = Join-Path $sysroot 'lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'
    if (Test-Path -LiteralPath $lld) {
        Write-Host "rust-lld: OK ($lld)"
    } else {
        Write-Host "rust-lld: MISSING ($lld)"
    }
}

Show-Tool 'protoc' {
    $candidates = @()
    if ($env:PROTOC) { $candidates += $env:PROTOC }
    $candidates += (Join-Path $env:LOCALAPPDATA 'protoc-29.3\bin\protoc.exe')
    if (Test-CommandExists 'protoc') {
        $cmd = Get-Command protoc
        $candidates += $cmd.Source
    }
    $found = $false
    foreach ($p in ($candidates | Select-Object -Unique)) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            Write-Host "PROTOC path: $p"
            & $p --version
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Host 'MISSING — run: .\script\windows\install-protoc.ps1'
    }
}

Show-Tool 'MSVC / link.exe (optional probe)' {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $install = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($install) {
            Write-Host "VS C++ tools: $install"
        } else {
            Write-Host 'vswhere found, but VC Tools component not detected'
        }
    } else {
        Write-Host 'vswhere not found — install VS 2022 Build Tools with "Desktop development with C++"'
    }
    if (Test-CommandExists 'link') {
        & link 2>&1 | Select-Object -First 1
    } else {
        Write-Host 'link.exe not on PATH (normal outside a VS Developer shell; rust-lld is used instead)'
    }
}

Show-Tool 'session env (build-related)' {
    Write-Host "PROTOC=$env:PROTOC"
    Write-Host "CARGO_INCREMENTAL=$env:CARGO_INCREMENTAL"
    Write-Host "CARGO_PROFILE_DEV_DEBUG=$env:CARGO_PROFILE_DEV_DEBUG"
    if ($env:RUSTFLAGS) {
        Write-Host "RUSTFLAGS=$env:RUSTFLAGS"
    } else {
        Write-Host 'RUSTFLAGS=(unset) — run .\script\windows\env.ps1 or build.ps1'
    }
}

Write-Host ""
Write-Host "Done. Install/fix with: .\script\windows\setup.ps1"
