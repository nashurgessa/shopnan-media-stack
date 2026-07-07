# Upload a local image to MinIO for manual CDN testing.
# Usage: .\scripts\upload-test-asset.ps1 .\sample.jpg [asset-uuid]
param(
    [Parameter(Mandatory = $true)][string]$File,
    [string]$AssetId = "550e8400-e29b-41d4-a716-446655440000"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$resolved = (Resolve-Path $File).Path -replace '\\', '/'
$network = "media-stack_media_backend"

Push-Location $root
try {
    docker run --rm --entrypoint /bin/sh `
        --network $network `
        -v "${resolved}:/upload/source:ro" `
        --env-file .env `
        minio/mc:latest `
        -c "mc alias set local http://minio:9000 `$MINIO_ROOT_USER `$MINIO_ROOT_PASSWORD && mc cp /upload/source local/`$MINIO_BUCKET/originals/${AssetId}"
} finally {
    Pop-Location
}

Write-Host "Uploaded to s3://shopnan-media/originals/${AssetId}"
Write-Host "Test: curl -I http://localhost:8088/i/${AssetId}/card"
