#!/usr/bin/env bash
# scripts/preview.sh — a preview copy of the current checkout, reachable from outside your network through a
# Cloudflare tunnel. Docker only; opens no port on the machine: the copy and its own throwaway database live inside
# Docker, and the tunnel is the only way in. Never touches your normal local copy (own project name, own image tag).
#
#   scripts/preview.sh up            build, start, print a quick-tunnel link
#                                    (https://<random>.trycloudflare.com: anyone with the link, until you stop it)
#   scripts/preview.sh up --named    the same, through your named tunnel: a fixed hostname behind an access policy
#   scripts/preview.sh url           print the link again
#   scripts/preview.sh logs          follow the app's logs
#   scripts/preview.sh down          stop it and delete its data
#
# Named tunnel, once per machine: Cloudflare Zero Trust → Networks → Tunnels → Create (cloudflared), public
# hostname e.g. myapp-preview.example.com → http://app:8080, an Access policy for your testers, then save the
# token:  install -m 600 /dev/stdin ~/.config/myapp/preview-tunnel-token
set -euo pipefail
cd "$(dirname "$0")/.."

APP=myapp                                           # <- your app name
export COMPOSE_PROJECT_NAME="${PREVIEW_NAME:-$APP-preview}"
export APP_IMAGE_TAG=preview
token_file="${PREVIEW_TOKEN_FILE:-$HOME/.config/$APP/preview-tunnel-token}"
compose() { docker compose -f docker-compose.yml -f deploy/preview.compose.yml "$@"; }

quick_url() {
  compose --profile quick logs tunnel-quick 2>/dev/null | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1
}

case "${1:-}" in
  up)
    mode=quick
    [[ "${2:-}" == "--named" ]] && mode=named
    if [[ $mode == named ]]; then
      [[ -s "$token_file" ]] || { echo "no tunnel token in $token_file (see the header of this script)" >&2; exit 1; }
      PREVIEW_TUNNEL_TOKEN="$(cat "$token_file")"
      export PREVIEW_TUNNEL_TOKEN
    fi
    sha="$(git rev-parse --short HEAD)"
    [[ -z "$(git status --porcelain)" ]] || sha="$sha-dirty"
    export VERSION="preview-$(git rev-parse --abbrev-ref HEAD | tr '/' '-')-$sha"

    echo "building $VERSION ..."
    compose --profile "$mode" up -d --build --wait --remove-orphans app db
    compose --profile "$mode" up -d "tunnel-$mode"
    if [[ $mode == quick ]]; then
      for _ in $(seq 1 30); do url="$(quick_url)"; [[ -n "$url" ]] && break; sleep 1; done
      [[ -n "${url:-}" ]] || { echo "the tunnel did not report its address; see: scripts/preview.sh logs" >&2; exit 1; }
      echo
      echo "Preview $VERSION is live at:"
      echo "  $url"
      echo "Anyone with this link can use it until 'scripts/preview.sh down'. Its data is throwaway."
    else
      echo
      echo "Preview $VERSION is live on your named tunnel's hostname (behind its access policy)."
    fi
    ;;
  url)
    url="$(quick_url)"
    [[ -n "$url" ]] && echo "$url" || echo "no quick tunnel running (a named tunnel uses its fixed hostname)"
    ;;
  logs) compose logs -f app ;;
  down)
    compose --profile quick --profile named down -v --remove-orphans
    echo "preview stopped, its data deleted"
    ;;
  *)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
