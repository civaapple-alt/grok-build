#Requires -Version 5.1
<#
.SYNOPSIS
  Configure this PowerShell session for building xai-grok-pager on Windows MSVC.

.DESCRIPTION
  Sets PROTOC, disables incremental/debuginfo for large-binary linking, and
  points the linker at rust-lld with a 16MB stack to avoid LNK1318 / stack overflow.

  Dot-source or run from repo root:
    . .\script\windows\env.ps1
    .\script\windows\env.ps1

.PARAMETER ProtocVersion
  protoc release version installed under %LOCALAPPDATA%\protoc-<ver>.
#>
[CmdletBinding()]
param(
    [string]$ProtocVersion = '29.3'
)

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    $here = $PSScriptRoot
    # script/windows -> repo root
    return (Resolve-Path (Join-Path $here '..\..')).Path
}

function Find-RustLld {
    $sysroot = (& rustc --print sysroot).Trim()
    if (-not $sysroot) {
        throw 'rustc --print sysroot failed; is the Rust toolchain installed?'
    }
    $lld = Join-Path $sysroot 'lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'
    if (-not (Test-Path -LiteralPath $lld)) {
        throw "rust-lld not found at: $lld"
    }
    return $lld
}

$repoRoot = Get-RepoRoot
Set-Location -LiteralPath $repoRoot

$protocExe = Join-Path $env:LOCALAPPDATA "protoc-$ProtocVersion\bin\protoc.exe"
if (Test-Path -LiteralPath $protocExe) {
    $env:PROTOC = $protocExe
    Write-Host "PROTOC=$env:PROTOC"
} elseif ($env:PROTOC -and (Test-Path -LiteralPath $env:PROTOC)) {
    Write-Host "PROTOC=$env:PROTOC (pre-set)"
} else {
    Write-Warning @"
Windows protoc not found at $protocExe
Run: .\script\windows\install-protoc.ps1
Or set `$env:PROTOC to a working protoc.exe
"@
}

$lld = Find-RustLld
$env:CARGO_PROFILE_DEV_DEBUG = '0'
$env:CARGO_INCREMENTAL = '0'
$env:RUSTFLAGS = @(
    "-C linker=$lld"
    '-C force-unwind-tables=yes'
    '-C target-feature=+crt-static'
    '-C debuginfo=0'
    '-C link-arg=/STACK:16777216'
) -join ' '

Write-Host "RUSTFLAGS=$env:RUSTFLAGS"
Write-Host "Windows build env ready (cwd=$repoRoot)."
