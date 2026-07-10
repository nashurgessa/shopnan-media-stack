#!/usr/bin/env bash
# Smoke test for the media stack (run after: docker compose up -d)
# Usage: ./scripts/smoke-test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

BASE="${CDN_BASE_URL:-http://localhost:${CDN_HTTP_PORT:-8088}}"
BASE="${BASE%/}"

get_status() {
  curl -sS -o /dev/null -w '%{http_code}' "$1" || echo "000"
}

echo "1. NGINX health..."
CODE="$(get_status "${BASE}/health")"
if [[ "$CODE" != "200" ]]; then
  echo "Health check failed (status ${CODE})"
  exit 1
fi
echo "   OK"

TEST_UUID="$(python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || uuidgen | tr '[:upper:]' '[:lower:]')"

echo "2. Unknown preset should 403..."
CODE="$(get_status "${BASE}/i/${TEST_UUID}/invalid")"
if [[ "$CODE" != "403" ]]; then
  echo "Expected 403, got ${CODE}"
  exit 1
fi
echo "   OK"

echo "3. Valid preset without object should 404/422/500 from imgproxy..."
CODE="$(get_status "${BASE}/i/${TEST_UUID}/card")"
if [[ "$CODE" == "200" ]]; then
  echo "Expected missing object (404/422/500), got 200"
  exit 1
fi
if [[ "$CODE" != "404" && "$CODE" != "422" && "$CODE" != "500" ]]; then
  echo "Unexpected status: ${CODE}"
  exit 1
fi
echo "   OK (status ${CODE})"

echo "Smoke test passed."
