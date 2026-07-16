#Requires -Version 5.1
<#
.SYNOPSIS
  Prepare this session to use XAI_API_KEY against api.x.ai (not Grok Build free quota).

.DESCRIPTION
  - Ensures XAI_API_KEY is set (from env or -ApiKey).
  - Sets GROK_MODELS_BASE_URL to https://api.x.ai/v1 by default.
  - Warns if ~/.grok/auth.json exists (OAuth session overrides the API key).

.EXAMPLE
  .\script\windows\use-api-key.ps1
  .\script\windows\use-api-key.ps1 -ApiKey 'xai-...'
  .\script\windows\use-api-key.ps1 -Logout
#>
[CmdletBinding()]
param(
    [string]$ApiKey,
    [string]$ModelsBaseUrl = 'https://api.x.ai/v1',
    [switch]$Logout
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

if ($ApiKey) {
    $env:XAI_API_KEY = $ApiKey
}

if (-not $env:XAI_API_KEY -or [string]::IsNullOrWhiteSpace($env:XAI_API_KEY)) {
    throw @'
XAI_API_KEY is not set in this shell.
  $env:XAI_API_KEY = "xai-..."   # from https://console.x.ai
  or: .\script\windows\use-api-key.ps1 -ApiKey "xai-..."
'@
}

$env:GROK_MODELS_BASE_URL = $ModelsBaseUrl
Write-Host "GROK_MODELS_BASE_URL=$env:GROK_MODELS_BASE_URL"
Write-Host ("XAI_API_KEY is set (length={0})" -f $env:XAI_API_KEY.Length)

$authJson = Join-Path $env:USERPROFILE '.grok\auth.json'
if (Test-Path -LiteralPath $authJson) {
    Write-Warning @"
OAuth session file exists: $authJson
A signed-in session takes precedence over XAI_API_KEY and may hit Grok Build free limits.
Logout first, then run again:
  .\target\debug\xai-grok-pager.exe logout
  # or: .\script\windows\use-api-key.ps1 -Logout
  # or: Remove-Item `$env:USERPROFILE\.grok\auth.json
"@
    if ($Logout) {
        $candidates = @(
            (Join-Path $repoRoot 'target\debug\xai-grok-pager.exe'),
            (Join-Path $repoRoot 'target\release\xai-grok-pager.exe')
        )
        $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($exe) {
            Write-Host "Running: $exe logout"
            & $exe logout
        } else {
            Write-Host "Binary not built yet; removing $authJson"
            Remove-Item -LiteralPath $authJson -Force
            Write-Host "Removed $authJson"
        }
    }
} else {
    Write-Host "No ~/.grok/auth.json — API key auth can be used."
}

Write-Host "Next: .\script\windows\run.ps1"
