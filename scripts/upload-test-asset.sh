#!/bin/sh
# Upload a local JPEG/PNG to MinIO for manual CDN testing.
# Usage: ./scripts/upload-test-asset.sh ./sample.jpg [asset-uuid]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${1:-}"
ASSET_ID="${2:-550e8400-e29b-41d4-a716-446655440000}"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "Usage: $0 <image-file> [asset-uuid]"
  exit 1
fi

ABS_FILE="$(cd "$(dirname "$FILE")" && pwd)/$(basename "$FILE")"
NETWORK="${COMPOSE_PROJECT_NAME:-media-stack}_media_backend"

cd "$ROOT"

docker run --rm --entrypoint /bin/sh \
  --network "$NETWORK" \
  -v "${ABS_FILE}:/upload/source:ro" \
  --env-file .env \
  minio/mc:latest \
  -c 'mc alias set local http://minio:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD && mc cp /upload/source local/$MINIO_BUCKET/originals/'"$ASSET_ID"

echo "Uploaded to s3://shopnan-media/originals/${ASSET_ID}"
echo "Test: curl -I http://localhost:8088/i/${ASSET_ID}/card"
