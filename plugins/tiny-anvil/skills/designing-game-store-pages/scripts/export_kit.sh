#!/usr/bin/env bash
# Export every store-page image from a capsules page (../templates/capsules.html): one preset per panel class,
# sizes from designing-app-listing-images/scripts/sizes.json. Then trims the library logo and writes the .ico.
# Usage: bash export_kit.sh capsules.html OUT_DIR [--steam] [--itch]     (default: both)
# Needs node + Playwright with Chromium, python3 + Pillow. Writes OUT_DIR/steam/*.png|jpg|ico, OUT_DIR/itch/* and
# OUT_DIR/trailer/trailer-end-card.png (the trailer's last shot).
set -euo pipefail
[[ $# -ge 2 ]] || { sed -n '2,5p' "$0"; exit 2; }
page="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; out="$2"; shift 2
here="$(cd "$(dirname "$0")" && pwd)"
exp="$here/../../designing-app-listing-images/scripts/export.js"
tools="$here/store_tools.py"
steam=1; itch=1
if [[ $# -gt 0 ]]; then steam=0; itch=0; for a in "$@"; do case $a in --steam) steam=1 ;; --itch) itch=1 ;; *) echo "unknown $a"; exit 2 ;; esac; done; fi

# one panel class -> one file named after the preset
one() {  # one <preset> <dest dir> [size] [extra export.js args...]
  local preset=$1 dest=$2 size=${3:-$1} tmp; shift 3 || shift $#
  tmp="$(mktemp -d)"
  node "$exp" "$page#export" "$tmp" "$size" --panel ".$preset" --no-gl --wait 800 "$@" >/dev/null
  local f; f="$(ls "$tmp" | head -1)"
  [[ -n "$f" ]] || { echo "FAIL $preset: nothing exported"; exit 1; }
  mkdir -p "$dest"; mv "$tmp/$f" "$dest/$preset.${f##*.}"; rmdir "$tmp"
  echo "$dest/$preset.${f##*.}"
}

if [[ $steam == 1 ]]; then
  for p in steam-header steam-small steam-main steam-vertical steam-page-bg steam-library-capsule \
           steam-library-header steam-library-hero steam-app-icon steam-shortcut-icon; do
    one "$p" "$out/steam"
  done
  # library logo: render at 2x with transparency, crop to the visible logo, fit 1280 wide and/or 720 tall
  one steam-library-logo "$out/steam/_raw" 2560x1440 --alpha
  python3 "$tools" trim "$out/steam/_raw/steam-library-logo.png" "$out/steam/steam-library-logo.png" --fit 1280x720
  rm -r "$out/steam/_raw"
  python3 "$tools" ico "$out/steam/steam-shortcut-icon.png" "$out/steam/steam-shortcut-icon.ico" 2>/dev/null \
    || echo "note: shortcut icon is 256 px; .ico written only from a square source of at least 256 px"
fi
if [[ $itch == 1 ]]; then
  one itch-cover "$out/itch"
fi
one trailer-end-card "$out/trailer" 1920x1080
