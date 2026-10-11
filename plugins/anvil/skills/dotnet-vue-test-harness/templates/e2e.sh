#!/usr/bin/env bash
# scripts/e2e.sh — end-to-end suite against a throwaway copy of the real stack (image + Postgres), never the
# developer's running copy: its own compose project, other ports, bound to 127.0.0.1, its own image tag, a fresh
# volume, removed afterwards.
#
#   bash scripts/e2e.sh                       # build the image, run desktop + phone, restart check, load, tear down
#   E2E_INCREMENT=I002 bash scripts/e2e.sh    # also write captures to data/run/increments/I002/captures
#   KEEP=1 bash scripts/e2e.sh                # leave the e2e stack running afterwards
#   SKIP_LOAD=1 bash scripts/e2e.sh           # no load run
#
# Assumes docker-compose.yml reads APP_PORT, APP_DB_PORT, APP_BIND, APP_IMAGE_TAG and the rate-limit variables
# (house-stack.md → Containers). Rename them to your app's prefix.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP=myapp                                           # <- your app name
export COMPOSE_PROJECT_NAME="$APP-e2e" APP_PORT=8090 APP_DB_PORT=5434 VERSION=e2e
export APP_BIND=127.0.0.1 APP_IMAGE_TAG=e2e
export APP_READ_LIMIT=1000000 APP_WRITE_LIMIT=1000000   # raised here only; say so in the evidence
export E2E_BASE_URL="http://localhost:$APP_PORT"
mkdir -p data/run/qa

docker compose down -v --remove-orphans >/dev/null 2>&1 || true
docker compose up -d --build --wait
trap '[ "${KEEP:-}" = 1 ] || docker compose down -v --remove-orphans >/dev/null 2>&1' EXIT

(cd src/apps/app && pnpm exec playwright test "$@")

# Data survives a restart of the whole stack: create through the API, restart, read back.
# Replace the two requests with your app's create and read endpoints.
marker="e2e-restart-$(date +%s)"
curl -sf -X POST "$E2E_BASE_URL/api/v1/items" -H 'Content-Type: application/json' -d "{\"name\":\"$marker\"}" >/dev/null
docker compose restart >/dev/null 2>&1 && docker compose up -d --wait >/dev/null 2>&1
if curl -sf "$E2E_BASE_URL/api/v1/items?search=$marker" | grep -q "$marker"; then r=pass; else r=fail; fi
printf '{"marker":"%s","result":"%s"}\n' "$marker" "$r" > data/run/qa/restart.json
echo "data survives restart: $r"
[ "$r" = pass ]

[ "${SKIP_LOAD:-}" = 1 ] || node scripts/load.mjs "$E2E_BASE_URL/api/v1/items?page=1&pageSize=20" data/run/qa/load.json
