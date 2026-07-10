# Shopnan Media Stack

Docker Compose stack for the Shopnan image CDN:

```
Apps (S3 upload) → MinIO → imgproxy → NGINX CDN → /i/{uuid}/{preset}
```

| Service | Port (local) | Role |
|---------|--------------|------|
| **minio** | 9000, 9001 | S3-compatible object storage (`shopnan-media` bucket) |
| **imgproxy** | internal | On-demand resize + WebP |
| **cdn** (nginx) | 8088 | Public CDN edge + `/health` |

Production CDN URL: `https://cdn.shopnan.com`  
Local dev CDN URL: `http://localhost:8088`

Full deployment guide: see `cdn/DEPLOYMENT.md` in the main Shopnan monorepo.

---

## Quick start (local)

```bash
cp .env.example .env
# Edit .env if needed (defaults work for local dev)
docker compose up -d
curl http://127.0.0.1:8088/health   # → ok
```

Smoke test (uploads a 1×1 PNG and fetches the `card` preset):

```bash
chmod +x scripts/smoke-test.sh scripts/init-minio.sh
./scripts/smoke-test.sh
```

---

## Production (DigitalOcean)

1. Provision a Linux droplet with Docker + Docker Compose v2 (2–4 GB RAM).
2. Clone this repo on the server.
3. Copy and edit `.env` with strong secrets:

| Variable | Production value |
|----------|------------------|
| `CDN_HTTP_PORT` | `80` |
| `CDN_SERVER_NAME` | `cdn.shopnan.com` |
| `CDN_BASE_URL` | `https://cdn.shopnan.com` |
| `MINIO_*` | Strong passwords |
| `FLASK_S3_*` | Must match backend `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` |
| `IMGPROXY_S3_*` | Read-only credentials for imgproxy |

4. Start the stack: `docker compose up -d`
5. Point DNS `cdn.shopnan.com` → droplet IP (Cloudflare recommended).
6. **Firewall:** allow port 80/443; **block** public access to MinIO port 9000.

---

## Backend env vars

Copy these into each Flask/Node backend that uploads images:

```env
MEDIA_STORAGE_BACKEND=s3
S3_ENDPOINT_URL=http://<minio-host>:9000
S3_ACCESS_KEY_ID=<FLASK_S3_ACCESS_KEY>
S3_SECRET_ACCESS_KEY=<FLASK_S3_SECRET_KEY>
S3_BUCKET_NAME=shopnan-media
S3_ORIGINALS_PREFIX=originals
S3_REGION=us-east-1
CDN_BASE_URL=https://cdn.shopnan.com
```

See `.env.media.example` in each backend repo for the full template.

---

## CDN presets

| Preset | Typical use |
|--------|-------------|
| `thumb`, `card`, `card-2x`, `gallery`, `gallery-2x`, `hero` | Products |
| `avatar`, `avatar-2x` | Profiles |
| `evidence` | Reviews, complaints, receipts |
| `banner`, `banner-2x` | Advertisements |
| `chat-thumb` | Chat (future) |

URL pattern: `{CDN_BASE_URL}/i/{asset_uuid}/{preset}`

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `/health` fails | `docker compose ps` — wait for all services healthy |
| CDN 404 on valid asset | Confirm object exists at `originals/{uuid}` in MinIO |
| Backend upload fails | Check `S3_ENDPOINT_URL` and credentials match `.env` |
| imgproxy 500 | Check imgproxy logs: `docker compose logs imgproxy` |

---

*Shopnan media CDN — July 2026*
