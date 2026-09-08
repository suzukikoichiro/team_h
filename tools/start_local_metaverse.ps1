param(
    [string]$ExePath = "",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$NakamaDir = Join-Path $Root "nakama"
if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $ExePath = Join-Path $Root "build\2Dmetaverse.exe"
}

Write-Host "Starting Nakama..." -ForegroundColor Cyan
Push-Location $NakamaDir
try {
    docker compose up -d | Out-Host
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        $status = docker compose ps --format json 2>$null | ConvertFrom-Json
        $nakama = $status | Where-Object { $_.Service -eq "nakama" }
        if ($nakama -and $nakama.Health -eq "healthy") {
            $ready = $true
            break
        }
        Start-Sleep -Seconds 1
    }

    if (-not $ready) {
        Write-Warning "Nakama health is not healthy yet. Check with: docker compose logs nakama"
    } else {
        Write-Host "Nakama is healthy." -ForegroundColor Green
    }
}
finally {
    Pop-Location
}

Write-Host "Nakama Console: http://127.0.0.1:7351" -ForegroundColor Cyan
Write-Host "Nakama API:     http://127.0.0.1:7350" -ForegroundColor Cyan
$GodotLogDir = Join-Path $env:APPDATA "Godot\app_userdata\2Dmetaverse"
$LatestGodotLog = Join-Path $GodotLogDir "latest_log_path.txt"
Write-Host "Godot app logs: $GodotLogDir\local_metaverse_*.log" -ForegroundColor Cyan
Write-Host "Latest log ref: $LatestGodotLog" -ForegroundColor Cyan

$ChatCheck = Join-Path $PSScriptRoot "check_nakama_realtime_chat.js"
if (Test-Path -LiteralPath $ChatCheck) {
    node $ChatCheck | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Nakama realtime chat check failed. Run manually: node $ChatCheck"
    }
}

if ($NoLaunch) {
    exit 0
}

if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Warning "Godot Windows export was not found: $ExePath"
    Write-Host "Export from Godot: Project > Export > Windows Desktop" -ForegroundColor Yellow
    exit 1
}

Write-Host "Launching Godot desktop app: $ExePath" -ForegroundColor Cyan
Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath)
