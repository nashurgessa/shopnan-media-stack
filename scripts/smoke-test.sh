#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Missing .env — run: cp .env.example .env"
  exit 1
fi

# shellcheck disable=SC1091
source .env

CDN_PORT="${CDN_HTTP_PORT:-8088}"
CDN_BASE="${CDN_BASE_URL:-http://localhost:${CDN_PORT}}"
HEALTH_URL="${CDN_BASE%/}/health"

echo "==> Health check: $HEALTH_URL"
HEALTH="$(curl -fsS "$HEALTH_URL")"
if [[ "$HEALTH" != "ok" ]]; then
  echo "Unexpected health response: $HEALTH"
  exit 1
fi
echo "    OK"

ASSET_ID="$(python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || uuidgen | tr '[:upper:]' '[:lower:]')"
TMP_IMAGE="$(mktemp /tmp/shopnan-smoke-XXXXXX.png)"
trap 'rm -f "$TMP_IMAGE"' EXIT

# 1x1 PNG — no extra dependencies
base64 -d > "$TMP_IMAGE" <<'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==
EOF

OBJECT_KEY="originals/${ASSET_ID}"
NETWORK_NAME="$(docker compose ps -q minio | xargs docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || true)"
NETWORK_NAME="${NETWORK_NAME:-media-stack_media-net}"

echo "==> Uploading test object to MinIO: $OBJECT_KEY"
docker run --rm \
  --network "$NETWORK_NAME" \
  -v "$TMP_IMAGE:/tmp/smoke.png:ro" \
  -e "MC_HOST_local=http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@minio:9000" \
  minio/mc:RELEASE.2024-12-18T13-15-44Z \
  cp /tmp/smoke.png "local/${MINIO_BUCKET}/${OBJECT_KEY}"

CARD_URL="${CDN_BASE%/}/i/${ASSET_ID}/card"
echo "==> CDN card preset: $CARD_URL"
HTTP_CODE="$(curl -sS -o /dev/null -w '%{http_code}' "$CARD_URL")"
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Expected HTTP 200, got $HTTP_CODE"
  exit 1
fi

CONTENT_TYPE="$(curl -sS -I "$CARD_URL" | awk -F': ' 'tolower($1)=="content-type"{print $2}' | tr -d '\r')"
echo "    Content-Type: $CONTENT_TYPE"

echo "==> Smoke test passed"
