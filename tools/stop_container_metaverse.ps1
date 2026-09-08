$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot

Write-Host "Stopping containerized Django and Nakama..." -ForegroundColor Cyan
Push-Location $Root
try {
    docker compose down
}
finally {
    Pop-Location
}
