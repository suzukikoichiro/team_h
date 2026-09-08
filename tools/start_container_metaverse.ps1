param(
    [string]$ExePath = "",
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $Root "docker-compose.yml"

if ([string]::IsNullOrWhiteSpace($ExePath)) {
    $ExePath = Join-Path $Root "build\2Dmetaverse.exe"
}

if (-not (Test-Path -LiteralPath $ComposeFile)) {
    throw "docker-compose.yml not found: $ComposeFile"
}

Write-Host "Starting containerized Django and Nakama..." -ForegroundColor Cyan
Push-Location $Root
try {
    & docker compose up -d --build
    if ($LASTEXITCODE -ne 0) {
        & docker compose down
        throw "docker compose up failed. If ports 7350/7351 are already in use, stop the old local Nakama first: cd `"$Root\nakama`"; docker compose down"
    }

    $nakamaReady = $false
    for ($i = 0; $i -lt 60; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:7350/healthcheck" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                $nakamaReady = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }

    if (-not $nakamaReady) {
        Write-Warning "Nakama did not respond yet. Check logs with: docker compose logs nakama"
    } else {
        Write-Host "Nakama is responding: http://127.0.0.1:7350" -ForegroundColor Green
    }

    $djangoReady = $false
    for ($i = 0; $i -lt 60; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000/" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 500) {
                $djangoReady = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }

    if (-not $djangoReady) {
        Write-Warning "Django did not respond yet. Check logs with: docker compose logs django"
    } else {
        Write-Host "Django is responding: http://127.0.0.1:8000" -ForegroundColor Green
    }

    Write-Host "Nakama Console: http://127.0.0.1:7351  admin / password" -ForegroundColor Cyan
}
finally {
    Pop-Location
}

if ($NoLaunch) {
    exit 0
}

if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Warning "Godot Windows export was not found: $ExePath"
    exit 1
}

Write-Host "Launching Godot desktop app: $ExePath" -ForegroundColor Cyan
Start-Process -FilePath $ExePath -WorkingDirectory (Split-Path -Parent $ExePath)
