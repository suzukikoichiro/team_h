param(
    [string]$GodotPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ProjectDir = Join-Path $Root "2-dmetaverse"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $Root "build\2Dmetaverse.exe"
}

$OutputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

function Resolve-Godot {
    param([string]$ExplicitPath)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "Godot executable not found: $ExplicitPath"
        }
        return $ExplicitPath
    }

    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $commonDirs = @(
        (Join-Path $env:USERPROFILE "Desktop"),
        (Join-Path $env:USERPROFILE "Downloads"),
        "C:\Program Files",
        "C:\Program Files (x86)"
    )

    foreach ($dir in $commonDirs) {
        if (-not (Test-Path -LiteralPath $dir)) {
            continue
        }
        $found = Get-ChildItem -LiteralPath $dir -Filter "Godot*.exe" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        if ($found) {
            return $found
        }
    }

    throw "Godot executable was not found. Pass -GodotPath with the full path to Godot.exe."
}

$GodotExe = Resolve-Godot $GodotPath

Write-Host "Godot: $GodotExe" -ForegroundColor Cyan
Write-Host "Project: $ProjectDir" -ForegroundColor Cyan
Write-Host "Output: $OutputPath" -ForegroundColor Cyan

Push-Location $ProjectDir
try {
    & $GodotExe --headless --export-release "Windows Desktop" $OutputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path -LiteralPath $OutputPath)) {
    throw "Export finished but output exe was not found: $OutputPath"
}

Write-Host "Windows Desktop export OK: $OutputPath" -ForegroundColor Green
