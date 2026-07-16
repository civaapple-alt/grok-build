#Requires -Version 5.1
<#
.SYNOPSIS
  Build xai-grok-pager-bin with Windows-friendly linker settings.

.PARAMETER DryRun
  Check that the environment meets build requirements without compiling.
  Alias: -dry-run

.EXAMPLE
  .\script\windows\build.ps1
  .\script\windows\build.ps1 -Release
  .\script\windows\build.ps1 -DryRun
  .\script\windows\build.ps1 -dry-run
  .\script\windows\build.ps1 -- --verbose
#>
[CmdletBinding()]
param(
    [switch]$Release,

    [Alias('dry-run')]
    [switch]$DryRun,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CargoArgs
)

$ErrorActionPreference = 'Stop'

function Test-CommandExists([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-PinnedChannel([string]$RepoRoot) {
    $toml = Join-Path $RepoRoot 'rust-toolchain.toml'
    if (-not (Test-Path -LiteralPath $toml)) { return $null }
    $text = Get-Content -LiteralPath $toml -Raw
    if ($text -match 'channel\s*=\s*"([^"]+)"') { return $Matches[1] }
    return $null
}

function Invoke-BuildPreflight {
    param([string]$RepoRoot)

    $failures = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]

    Write-Host "=== build preflight (DryRun) ==="
    Write-Host "Repo: $RepoRoot"

    # rustup
    Write-Host ""
    Write-Host "[check] rustup"
    if (-not (Test-CommandExists 'rustup')) {
        $failures.Add('rustup not on PATH — run: .\script\windows\install-rust.ps1 -InstallRustup')
        Write-Host "  FAIL"
    } else {
        Write-Host "  OK  $((& rustup --version 2>$null | Select-Object -First 1))"
        $active = (& rustup show active-toolchain 2>$null | Select-Object -First 1)
        if ($active) { Write-Host "  active: $active" }
    }

    # rustc / cargo
    Write-Host ""
    Write-Host "[check] rustc / cargo"
    if (-not (Test-CommandExists 'rustc')) {
        $failures.Add('rustc not on PATH — run: .\script\windows\install-rust.ps1')
        Write-Host "  FAIL rustc"
    } else {
        Write-Host "  OK  $((& rustc --version))"
        $pinned = Get-PinnedChannel -RepoRoot $RepoRoot
        if ($pinned) {
            $verLine = & rustc --version
            if ($verLine -notmatch [regex]::Escape($pinned)) {
                $warnings.Add("rustc version '$verLine' may not match pinned channel $pinned (enter repo so rust-toolchain.toml applies)")
                Write-Host "  WARN pinned channel is $pinned"
            } else {
                Write-Host "  OK  matches rust-toolchain.toml channel $pinned"
            }
        }
    }
    if (-not (Test-CommandExists 'cargo')) {
        $failures.Add('cargo not on PATH — run: .\script\windows\install-rust.ps1')
        Write-Host "  FAIL cargo"
    } else {
        Write-Host "  OK  $((& cargo --version))"
    }

    # rust-lld (required by env.ps1 / RUSTFLAGS)
    Write-Host ""
    Write-Host "[check] rust-lld"
    if (Test-CommandExists 'rustc') {
        try {
            $sysroot = (& rustc --print sysroot).Trim()
            $lld = Join-Path $sysroot 'lib\rustlib\x86_64-pc-windows-msvc\bin\rust-lld.exe'
            if (Test-Path -LiteralPath $lld) {
                Write-Host "  OK  $lld"
            } else {
                $failures.Add("rust-lld missing at $lld")
                Write-Host "  FAIL"
            }
        } catch {
            $failures.Add("rustc --print sysroot failed: $_")
            Write-Host "  FAIL"
        }
    } else {
        Write-Host "  SKIP (no rustc)"
    }

    # protoc (required for codegen crates)
    Write-Host ""
    Write-Host "[check] protoc"
    $protocPath = $null
    if ($env:PROTOC -and (Test-Path -LiteralPath $env:PROTOC)) {
        $protocPath = $env:PROTOC
    } elseif (Test-CommandExists 'protoc') {
        $protocPath = (Get-Command protoc).Source
    }
    if ($protocPath) {
        try {
            $pv = & $protocPath --version 2>&1 | Select-Object -First 1
            # Reject obvious non-Win32 / shell wrappers that fail to execute
            if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
                $failures.Add("protoc failed to run at $protocPath")
                Write-Host "  FAIL $protocPath ($pv)"
            } else {
                Write-Host "  OK  $protocPath ($pv)"
            }
        } catch {
            $failures.Add("protoc not executable at $protocPath — run: .\script\windows\install-protoc.ps1")
            Write-Host "  FAIL $_"
        }
    } else {
        $failures.Add('protoc not found — run: .\script\windows\install-protoc.ps1')
        Write-Host "  FAIL"
    }

    # RUSTFLAGS from env.ps1
    Write-Host ""
    Write-Host "[check] session RUSTFLAGS / PROTOC"
    if ($env:PROTOC) {
        Write-Host "  PROTOC=$env:PROTOC"
    } else {
        $failures.Add('PROTOC not set after env.ps1')
        Write-Host "  FAIL PROTOC unset"
    }
    if ($env:RUSTFLAGS -match 'rust-lld' -and $env:RUSTFLAGS -match 'STACK') {
        Write-Host "  OK  RUSTFLAGS includes rust-lld and /STACK"
        Write-Host "  RUSTFLAGS=$env:RUSTFLAGS"
    } elseif ($env:RUSTFLAGS) {
        $warnings.Add('RUSTFLAGS set but missing rust-lld and/or /STACK — env.ps1 may have failed partially')
        Write-Host "  WARN RUSTFLAGS=$env:RUSTFLAGS"
    } else {
        $failures.Add('RUSTFLAGS not set — env.ps1 did not configure the session')
        Write-Host "  FAIL RUSTFLAGS unset"
    }

    # VS C++ tools (warning only — we link with rust-lld but CRT/headers still matter for some crates)
    Write-Host ""
    Write-Host "[check] MSVC C++ tools (advisory)"
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $install = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($install) {
            Write-Host "  OK  $install"
        } else {
            $warnings.Add('VS C++ tools component not detected via vswhere')
            Write-Host "  WARN VC Tools not detected"
        }
    } else {
        $warnings.Add('vswhere not found — install VS 2022 with Desktop development with C++ if native crates fail')
        Write-Host "  WARN vswhere missing"
    }

    # Planned cargo invocation
    $argsList = @('build', '-p', 'xai-grok-pager-bin')
    if ($Release) { $argsList += '--release' }
    if ($CargoArgs) { $argsList += $CargoArgs }
    Write-Host ""
    Write-Host "[plan] would run: cargo $($argsList -join ' ')"
    if ($Release) {
        Write-Host "[plan] artifact: target\release\xai-grok-pager.exe"
    } else {
        Write-Host "[plan] artifact: target\debug\xai-grok-pager.exe"
    }

    Write-Host ""
    if ($warnings.Count -gt 0) {
        Write-Host "Warnings:" -ForegroundColor Yellow
        foreach ($w in $warnings) { Write-Host "  - $w" -ForegroundColor Yellow }
    }
    if ($failures.Count -gt 0) {
        Write-Host "FAILED - environment not ready for build:" -ForegroundColor Red
        foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
        Write-Host "Fix with: .\script\windows\setup.ps1   (or setup.ps1 -InstallRustup)"
        return 1
    }

    Write-Host "OK - environment looks ready to compile (no cargo build performed)." -ForegroundColor Green
    return 0
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

# Apply the same session env a real build would use.
& (Join-Path $PSScriptRoot 'env.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($DryRun) {
    $code = Invoke-BuildPreflight -RepoRoot $repoRoot
    exit $code
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
