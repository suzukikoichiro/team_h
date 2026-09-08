$ErrorActionPreference = "Stop"

$LogDir = Join-Path $env:APPDATA "Godot\app_userdata\2Dmetaverse"
$LatestPath = Join-Path $LogDir "latest_log_path.txt"
$LogPath = $null

if (Test-Path -LiteralPath $LatestPath) {
    $candidate = (Get-Content -LiteralPath $LatestPath -Raw).Trim()
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
        $LogPath = $candidate
    }
}

if (-not $LogPath) {
    $latestLog = Get-ChildItem -LiteralPath $LogDir -Filter "local_metaverse_*.log" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($latestLog) {
        $LogPath = $latestLog.FullName
    }
}

if (-not $LogPath) {
    Write-Warning "Log file does not exist yet. Start the Godot desktop app first. Log dir: $LogDir"
    exit 1
}

Write-Host "Godot app log: $LogPath" -ForegroundColor Cyan
Get-Content -LiteralPath $LogPath -Wait -Tail 80
