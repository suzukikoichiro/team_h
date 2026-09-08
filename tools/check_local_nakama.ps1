$ErrorActionPreference = "Stop"

$basic = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("defaultkey:"))
$body = @{
    id = "codex-local-healthcheck"
    vars = @{
        role = "local_guest"
        user_id = "999999"
        school_id = "1"
    }
} | ConvertTo-Json -Depth 5

$result = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:7350/v2/account/authenticate/custom?create=true&username=CodexHealthcheck" `
    -Headers @{ Authorization = "Basic $basic"; "Content-Type" = "application/json" } `
    -Body $body

if (-not $result.token) {
    throw "Nakama custom auth did not return a token."
}

Write-Host "Nakama custom auth OK." -ForegroundColor Green
