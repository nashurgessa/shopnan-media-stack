#!/bin/sh
set -eu

BUCKET="${MINIO_BUCKET:-shopnan-media}"
ALIAS="local"
ENDPOINT="http://minio:9000"

echo "[minio-init] Waiting for MinIO..."
until mc alias set "$ALIAS" "$ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; do
  sleep 2
done

echo "[minio-init] Creating bucket: $BUCKET"
mc mb --ignore-existing "$ALIAS/$BUCKET"

echo "[minio-init] Applying bucket policy (private — no anonymous access)"
mc anonymous set none "$ALIAS/$BUCKET"

echo "[minio-init] Creating IAM policies"
mc admin policy create "$ALIAS" flask-upload-policy /policies/flask-upload-policy.json 2>/dev/null || \
  mc admin policy update "$ALIAS" flask-upload-policy /policies/flask-upload-policy.json

mc admin policy create "$ALIAS" imgproxy-read-policy /policies/imgproxy-read-policy.json 2>/dev/null || \
  mc admin policy update "$ALIAS" imgproxy-read-policy /policies/imgproxy-read-policy.json

echo "[minio-init] Creating service users"
mc admin user add "$ALIAS" "$FLASK_S3_ACCESS_KEY" "$FLASK_S3_SECRET_KEY" 2>/dev/null || true
mc admin user add "$ALIAS" "$IMGPROXY_S3_ACCESS_KEY" "$IMGPROXY_S3_SECRET_KEY" 2>/dev/null || true

mc admin policy attach "$ALIAS" flask-upload-policy --user "$FLASK_S3_ACCESS_KEY"
mc admin policy attach "$ALIAS" imgproxy-read-policy --user "$IMGPROXY_S3_ACCESS_KEY"

echo "[minio-init] Done. Bucket: $BUCKET, prefix: originals/{asset_uuid}"
