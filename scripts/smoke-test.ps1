# Smoke test for the media stack (run after: docker compose up -d)
# Run: Set-ExecutionPolicy -Scope Process Bypass; .\scripts\smoke-test.ps1
$ErrorActionPreference = "Stop"
$base = "http://localhost:8088"

function Get-HttpStatusCode {
    param([string]$Uri)
    try {
        $r = Invoke-WebRequest -Uri $Uri -UseBasicParsing
        return [int]$r.StatusCode
    } catch {
        if ($null -ne $_.Exception.Response) {
            return [int]$_.Exception.Response.StatusCode.value__
        }
        throw
    }
}

Write-Host "1. NGINX health..."
$code = Get-HttpStatusCode -Uri "$base/health"
if ($code -ne 200) { throw "Health check failed (status $code)" }
Write-Host "   OK"

$testUuid = [guid]::NewGuid().ToString()

Write-Host "2. Unknown preset should 403..."
$code = Get-HttpStatusCode -Uri "$base/i/$testUuid/invalid"
if ($code -ne 403) { throw "Expected 403, got $code" }
Write-Host "   OK"

Write-Host "3. Valid preset without object should 404/422 from imgproxy..."
$code = Get-HttpStatusCode -Uri "$base/i/$testUuid/card"
if ($code -eq 200) {
    throw "Expected missing object (404/422), got 200"
}
if ($code -notin 404, 422, 500) { throw "Unexpected status: $code" }
Write-Host "   OK (status $code)"

Write-Host "Smoke test passed."
