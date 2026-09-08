param(
    [string]$ExePath = "",
    [int]$DelaySeconds = 2
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $ExePath = Join-Path $Root "build\2Dmetaverse.exe"
}

if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Warning "Godot Windows export was not found: $ExePath"
    Write-Host "Export from Godot: Project > Export > Windows Desktop" -ForegroundColor Yellow
    exit 1
}

powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "start_local_metaverse.ps1") -NoLaunch

Write-Host "Launching first client..." -ForegroundColor Cyan
Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath)

Start-Sleep -Seconds $DelaySeconds

Write-Host "Launching second client..." -ForegroundColor Cyan
Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath)

Write-Host "Use this command to watch logs:" -ForegroundColor Cyan
Write-Host "powershell -ExecutionPolicy Bypass -File $PSScriptRoot\tail_godot_log.ps1"
