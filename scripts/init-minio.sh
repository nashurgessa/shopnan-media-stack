#!/bin/sh
set -eu

MINIO_ALIAS="local"
MINIO_URL="http://minio:9000"

echo "==> Waiting for MinIO"
until mc alias set "$MINIO_ALIAS" "$MINIO_URL" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; do
  sleep 2
done
echo "==> MinIO is ready"

echo "==> Creating bucket: $MINIO_BUCKET"
mc mb --ignore-existing "$MINIO_ALIAS/$MINIO_BUCKET"

echo "==> Creating upload user: $FLASK_S3_ACCESS_KEY"
if ! mc admin user info "$MINIO_ALIAS" "$FLASK_S3_ACCESS_KEY" >/dev/null 2>&1; then
  mc admin user add "$MINIO_ALIAS" "$FLASK_S3_ACCESS_KEY" "$FLASK_S3_SECRET_KEY"
fi
mc admin policy attach "$MINIO_ALIAS" readwrite --user "$FLASK_S3_ACCESS_KEY" 2>/dev/null || \
  mc admin policy attach "$MINIO_ALIAS" readwrite --user "$FLASK_S3_ACCESS_KEY"

echo "==> Creating imgproxy read-only user: $IMGPROXY_S3_ACCESS_KEY"
if ! mc admin user info "$MINIO_ALIAS" "$IMGPROXY_S3_ACCESS_KEY" >/dev/null 2>&1; then
  mc admin user add "$MINIO_ALIAS" "$IMGPROXY_S3_ACCESS_KEY" "$IMGPROXY_S3_SECRET_KEY"
fi

POLICY_NAME="imgproxy-readonly-${MINIO_BUCKET}"
POLICY_FILE="/tmp/imgproxy-readonly.json"
sed "s/\${MINIO_BUCKET}/$MINIO_BUCKET/g" /scripts/policies/imgproxy-readonly.json > "$POLICY_FILE"

if ! mc admin policy info "$MINIO_ALIAS" "$POLICY_NAME" >/dev/null 2>&1; then
  mc admin policy create "$MINIO_ALIAS" "$POLICY_NAME" "$POLICY_FILE"
fi
mc admin policy attach "$MINIO_ALIAS" "$POLICY_NAME" --user "$IMGPROXY_S3_ACCESS_KEY"

echo "==> MinIO init complete"
mc ls "$MINIO_ALIAS/$MINIO_BUCKET" || true
