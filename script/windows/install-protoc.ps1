#Requires -Version 5.1
<#
.SYNOPSIS
  Download and install Windows protoc under %LOCALAPPDATA%.

.EXAMPLE
  .\script\windows\install-protoc.ps1
  .\script\windows\install-protoc.ps1 -Version 29.3 -Force
#>
[CmdletBinding()]
param(
    [string]$Version = '29.3',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$protocDir = Join-Path $env:LOCALAPPDATA "protoc-$Version"
$protocExe = Join-Path $protocDir 'bin\protoc.exe'

if ((Test-Path -LiteralPath $protocExe) -and -not $Force) {
    $ver = & $protocExe --version
    Write-Host "Already installed: $protocExe ($ver)"
    $env:PROTOC = $protocExe
    Write-Host "PROTOC=$env:PROTOC"
    exit 0
}

$zipName = "protoc-$Version-win64.zip"
$url = "https://github.com/protocolbuffers/protobuf/releases/download/v$Version/$zipName"
$zip = Join-Path $env:TEMP $zipName

Write-Host "Downloading $url ..."
Invoke-WebRequest -Uri $url -OutFile $zip

if (Test-Path -LiteralPath $protocDir) {
    Remove-Item -LiteralPath $protocDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $protocDir | Out-Null
Expand-Archive -Path $zip -DestinationPath $protocDir -Force

if (-not (Test-Path -LiteralPath $protocExe)) {
    throw "protoc.exe missing after extract: $protocExe"
}

$ver = & $protocExe --version
$env:PROTOC = $protocExe
Write-Host "Installed: $protocExe ($ver)"
Write-Host "PROTOC=$env:PROTOC"
