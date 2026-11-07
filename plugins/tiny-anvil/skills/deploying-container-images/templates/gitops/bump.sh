#!/usr/bin/env bash
# scripts/bump.sh (in the GitOps repo) — deploy a version of an app to one environment by changing its overlay's
# newTag, through a PR.
#
#   scripts/bump.sh status                              show what runs where
#   scripts/bump.sh <app> <env> <version>               branch + commit + push + PR (someone reviews and merges)
#   scripts/bump.sh <app> <env> <version> --no-pr       only the local commit on a new branch
#   scripts/bump.sh <app> <env> <version> --skip-image-check
#
# <version> may be given with or without the leading v (1.3.0 or v1.3.0); image tags are v-prefixed.
# Layout: OVERLAY='apps/<app>/<env>/kustomization.yaml' by default; set OVERLAY for another layout.
# Needs: git, kubectl (kustomize), docker (image check), gh (PR).
set -euo pipefail

root="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
cd "$root"
default_overlay='apps/<app>/<env>/kustomization.yaml'
OVERLAY="${OVERLAY:-$default_overlay}"
BASE_BRANCH="${BASE_BRANCH:-main}"

die() { echo "error: $*" >&2; exit 1; }
overlay_for() { local p="${OVERLAY//<app>/$1}"; echo "${p//<env>/$2}"; }

# Read the images: block only (a configMapGenerator also has "- name:" entries).
current_tag() { awk '/^images:/{f=1; next} f && /^[^[:space:]]/{f=0} f && /newTag:/{sub(/.*newTag:[[:space:]]*/, ""); sub(/[[:space:]#].*/, ""); print; exit}' "$1"; }
image_name() { awk '/^images:/{f=1; next} f && /^[^[:space:]]/{f=0} f && /-[[:space:]]*name:/{sub(/.*name:[[:space:]]*/, ""); sub(/[[:space:]#].*/, ""); print; exit}' "$1"; }

if [[ "${1:-}" == "status" ]]; then
  printf '%-24s %-8s %s\n' APP ENV VERSION
  pattern="${OVERLAY//<app>/*}"; pattern="${pattern//<env>/*}"
  for k in $pattern; do
    [[ -f "$k" ]] || continue
    tag="$(current_tag "$k")"; [[ -n "$tag" ]] || continue
    env_dir="$(dirname "$k")"
    printf '%-24s %-8s %s\n' "$(basename "$(dirname "$env_dir")")" "$(basename "$env_dir")" "$tag"
  done
  exit 0
fi

[[ $# -ge 3 ]] || { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
app="$1"; env="$2"; version="$3"; shift 3
open_pr=true; check_image=true
for arg in "$@"; do
  case "$arg" in
    --no-pr) open_pr=false ;;
    --skip-image-check) check_image=false ;;
    *) die "unknown option $arg" ;;
  esac
done

[[ "$version" == v* ]] || version="v$version"
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "'$version' is not vX.Y.Z or vX.Y.Z-pre.N"

file="$(overlay_for "$app" "$env")"
[[ -f "$file" ]] || die "$file not found"
old="$(current_tag "$file")"
image="$(image_name "$file")"
[[ -n "$old" && -n "$image" ]] || die "no images/newTag entry in $file"
[[ "$old" != "$version" ]] || die "$app $env already runs $version"

[[ -z "$(git status --porcelain)" ]] || die "working tree not clean; commit or stash first"
git switch -q "$BASE_BRANCH"
git pull -q --ff-only

if $check_image; then
  docker manifest inspect "$image:$version" >/dev/null 2>&1 \
    || die "image $image:$version not found (private registry? log in first, or pass --skip-image-check)"
  echo "image $image:$version exists"
fi

branch="deploy/$app-$env-$version"
git switch -q -c "$branch"
sed -i.bak "s|^\([[:space:]]*newTag:[[:space:]]*\)$old|\1$version|" "$file" && rm -f "$file.bak"
kubectl kustomize "$(dirname "$file")" >/dev/null || {
  git checkout -- "$file"; git switch -q "$BASE_BRANCH"; git branch -q -D "$branch"; die "overlay does not render"; }

git add "$file"
git commit -q -m "deploy($app): $env $old → $version"
echo "committed on $branch: $app $env $old → $version"

if $open_pr; then
  git push -q -u origin "$branch"
  gh pr create --base "$BASE_BRANCH" --head "$branch" \
    --title "deploy($app): $env $old → $version" \
    --body "Deploys \`$image:$version\` to **$env** (was \`$old\`). Merge to roll out. Roll back by reverting this PR."
fi
git switch -q "$BASE_BRANCH"
