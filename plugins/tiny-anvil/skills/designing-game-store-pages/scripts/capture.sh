#!/usr/bin/env bash
# Store-kit captures from the real game, by recipe. Run from the workspace root. Every path handed to Godot is made
# absolute: Godot resolves relative paths against the project (--path), not the shell's directory.
#   bash capture.sh record <scenario> <run>   headless bot run -> $STORE/footage/<run>.json (fails if not written)
#   bash capture.sh film <run>                replay at 1920x1080 -> <run>.avi + a still per second + contact sheet
#   bash capture.sh shots                     replay the runs in $STORE/shots.json -> $KIT/screenshots/NN.png, checked
#   bash capture.sh keyart                    the store_key_art scenario -> $STORE/keyart/*.png
# Env: GAME (Godot project, default game) · STORE (recipes and footage, default store) · KIT (outputs, default
#   $STORE/kit; final/store in a run) · HIDE_GROUP (default store_hide; comma list, e.g. store_hide,hud) · FPS (60)
#   GODOT_WINDOWED: the windowed launch, default the harness's Captures command (x11, vulkan, off-screen). Smoke
#   tests only: GODOT_WINDOWED="xvfb-run -a -s '-screen 0 1920x1080x24' godot --rendering-driver opengl3".
# Filming and shots write a temporary $GAME/override.cfg (1920x1080 window, movie quality 0.95) and remove it.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tools="$here/store_tools.py"
GAME="$(realpath "${GAME:-game}")"
STORE="$(realpath -m "${STORE:-store}")"
KIT="$(realpath -m "${KIT:-$STORE/kit}")"
FPS="${FPS:-60}"
HIDE="${HIDE_GROUP:-store_hide}"
eval "WIN=(${GODOT_WINDOWED:-godot --display-driver x11 --rendering-driver vulkan --position -6000,-6000})"
[[ -f "$GAME/project.godot" ]] || { echo "FAIL no project.godot in $GAME (set GAME)"; exit 2; }
mkdir -p "$STORE/footage"

frames_of() { python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))["frames"]))' "$1"; }

override_on() {
  local o="$GAME/override.cfg"
  if [[ -e "$o" ]] && ! head -1 "$o" | grep -q '^; store-kit capture'; then
    echo "FAIL $o exists and is not this script's: move it away first"; exit 1
  fi
  printf '%s\n' '; store-kit capture: written and removed by capture.sh' '[display]' '' \
    'window/size/window_width_override=1920' 'window/size/window_height_override=1080' '' '[editor]' '' \
    'movie_writer/video_quality=0.95' > "$o"
  trap 'rm -f "$GAME/override.cfg"' EXIT
}

replay() {  # replay <recording.json> <stills.json> <extra godot args...>
  local rec=$1 stills=$2; shift 2
  local n; n="$(frames_of "$rec")"
  "${WIN[@]}" --path "$GAME" --fixed-fps "$FPS" "$@" \
    -- --playback="$rec" --stills="$stills" --quit-ticks="$n" --hide-group="$HIDE"
}

case "${1:-}" in
  record)
    [[ $# -eq 3 ]] || { echo "usage: capture.sh record <scenario> <run>"; exit 2; }
    rec="$STORE/footage/$3.json"
    godot --headless --path "$GAME" --fixed-fps "$FPS" -- --scenario="$2" --record="$rec" --out="$STORE/footage/$3-result"
    [[ -s "$rec" ]] || { echo "FAIL recording not written: $rec"; exit 1; }
    echo "$rec: $(frames_of "$rec") ticks"
    ;;
  film)
    [[ $# -eq 2 ]] || { echo "usage: capture.sh film <run>"; exit 2; }
    rec="$STORE/footage/$2.json"; avi="$STORE/footage/$2.avi"; sec="$STORE/footage/$2-sec"
    [[ -s "$rec" ]] || { echo "FAIL no recording $rec (capture.sh record first)"; exit 1; }
    rm -rf "$sec"; mkdir -p "$sec"
    python3 "$tools" ticks --every "$FPS" --until "$(frames_of "$rec")" --fps "$FPS" --dir "$sec" > "$STORE/footage/$2-ticks.json"
    override_on
    replay "$rec" "$STORE/footage/$2-ticks.json" --write-movie "$avi"
    python3 "$tools" sheet "$sec"/*.png --out "$STORE/footage/$2-sheet.jpg"
    ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0 "$avi" | grep -qx '1920,1080' \
      || { echo "FAIL $avi is not 1920x1080"; exit 1; }
    echo "$avi + $STORE/footage/$2-sheet.jpg (tiles labelled tick and second)"
    ;;
  shots)
    plan="$STORE/shots.json"
    [[ -s "$plan" ]] || { echo 'FAIL no store/shots.json: {"run1": [[tick, "01.png"], ...], ...}'; exit 1; }
    rm -rf "$KIT/screenshots"; mkdir -p "$KIT/screenshots"
    override_on
    for run in $(python3 -c 'import json, sys; print(" ".join(json.load(open(sys.argv[1]))))' "$plan"); do
      python3 - "$plan" "$run" "$KIT/screenshots" > "$STORE/footage/$run-shots.json" <<'PY'
import json, os, sys
plan, run, out = sys.argv[1:]
print(json.dumps(sorted([[int(t), os.path.join(out, name)] for t, name in json.load(open(plan))[run]])))
PY
      replay "$STORE/footage/$run.json" "$STORE/footage/$run-shots.json"
    done
    python3 "$tools" shots "$KIT/screenshots" --fix
    ;;
  keyart)
    "${WIN[@]}" --path "$GAME" -- --scenario=store_key_art --out="$STORE/keyart"
    ;;
  *) sed -n '2,13p' "$0"; exit 2 ;;
esac
