#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

if (-not (Test-Path ".env")) {
    Write-Error "Missing .env — run: Copy-Item .env.example .env"
}

Get-Content .env | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        Set-Item -Path "env:$($matches[1].Trim())" -Value $matches[2].Trim()
    }
}

$CdnPort = if ($env:CDN_HTTP_PORT) { $env:CDN_HTTP_PORT } else { "8088" }
$CdnBase = if ($env:CDN_BASE_URL) { $env:CDN_BASE_URL.TrimEnd("/") } else { "http://localhost:$CdnPort" }
$HealthUrl = "$CdnBase/health"

Write-Host "==> Health check: $HealthUrl"
$Health = (Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing).Content.Trim()
if ($Health -ne "ok") {
    throw "Unexpected health response: $Health"
}
Write-Host "    OK"

$AssetId = [guid]::NewGuid().ToString()
$TmpImage = [System.IO.Path]::GetTempFileName() + ".png"

Add-Type -AssemblyName System.Drawing
$bitmap = New-Object System.Drawing.Bitmap 64, 64
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.Clear([System.Drawing.Color]::FromArgb(220, 40, 40))
$bitmap.Save($TmpImage, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()

$ObjectKey = "originals/$AssetId"
Write-Host "==> Uploading test object to MinIO: $ObjectKey"

$uploadCmd = @(
    "mc alias set local http://minio:9000 `"$($env:MINIO_ROOT_USER)`" `"$($env:MINIO_ROOT_PASSWORD)`" &&",
    "mc cp /tmp/smoke.png local/$($env:MINIO_BUCKET)/$ObjectKey"
) -join " "

docker compose cp $TmpImage minio:/tmp/smoke.png
docker compose exec -T minio sh -c $uploadCmd

$CardUrl = "$CdnBase/i/$AssetId/card"
Write-Host "==> CDN card preset: $CardUrl"
$response = Invoke-WebRequest -Uri $CardUrl -UseBasicParsing
if ($response.StatusCode -ne 200) {
    throw "Expected HTTP 200, got $($response.StatusCode)"
}

Write-Host "    Content-Type: $($response.Headers['Content-Type'])"
Remove-Item -Force $TmpImage
Write-Host "==> Smoke test passed"
