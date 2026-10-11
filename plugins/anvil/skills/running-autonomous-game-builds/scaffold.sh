#!/usr/bin/env bash
# scaffold.sh <project-dir>: the workspace layout and record templates of an autonomous build.
# Never overwrites an existing file. Safe to re-run.
set -euo pipefail
P="${1:?usage: scaffold.sh <project-dir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SK="$(dirname "$HERE")"
mkdir -p "$P"/{game,blender,qa,looks,final,docs,prompts}
[ -e "$P/prompts/README.md" ] || { printf '# Prompts\n\nWhat the run was given, as sent: the request, the setup questions and answers, the kickoff, every later\nowner message and every driver prompt. Verbatim and append-only: a correction is a new file, never an edit.\n' > "$P/prompts/README.md"; echo "created $P/prompts/README.md"; }
put() { [ -e "$2" ] || { cp "$1" "$2"; echo "created $2"; }; }
put "$HERE/rules-template.md" "$P/docs/RULES.md"
put "$HERE/kickoff-template.md" "$P/docs/KICKOFF.md"
put "$SK/writing-game-briefs/brief-template.md" "$P/docs/BRIEF.md"
put "$SK/iterating-with-look-checkpoints/RUN.md" "$P/RUN.md"
put "$SK/iterating-with-look-checkpoints/LOOK.md" "$P/looks/LOOK_TEMPLATE.md"
put "$SK/iterating-with-look-checkpoints/QA.md" "$P/final/QA.md"
[ -e "$P/credits.md" ] || { printf '# Credits\n\nEvery external item: file(s) | source URL or task ID + prompt | author | license | date | processing.\n\n| File(s) | Source | Author | License | Date | Processing |\n|---|---|---|---|---|---|\n' > "$P/credits.md"; echo "created $P/credits.md"; }
[ -e "$P/DELEGATION.md" ] || { printf '# Delegation\n\n| UTC | Agent | Event | Owned files / scope | Active after |\n|---|---|---|---|---|\n' > "$P/DELEGATION.md"; echo "created $P/DELEGATION.md"; }
[ -e "$P/docs/SPEC.md" ] || { printf '# Asset contract (lead-owned; workers request changes)\n\nAxes and units · module naming · material roles · collision + socket naming · tri budgets per prefix · texture rules.\n' > "$P/docs/SPEC.md"; echo "created $P/docs/SPEC.md"; }
[ -e "$P/docs/ARCHITECTURE.md" ] || { printf '# Code card for helpers (lead-owned)\n\nCoordinates · autoloads and entry points · determinism rule (state only in _physics_process) · how to test and capture · owned files: only touch yours; the lead does integration hooks.\n' > "$P/docs/ARCHITECTURE.md"; echo "created $P/docs/ARCHITECTURE.md"; }
# The Godot baseline: Jolt, physics interpolation, 1920x1080 viewport stretch (captures
# at presentation size), and the scenario harness installed from day one.
if [ ! -e "$P/game/project.godot" ]; then
  T="$SK/godot-scenario-harness/templates"
  mkdir -p "$P/game/core" "$P/game/tests/scenarios"
  for f in harness.gd input_frame.gd measures.gd; do put "$T/$f" "$P/game/core/$f"; done
  put "$T/bot.gd" "$P/game/tests/bot.gd"
  for f in "$T"/scenarios/*.gd; do put "$f" "$P/game/tests/scenarios/$(basename "$f")"; done
  NAME="$(basename "$(cd "$P" && pwd)")"
  cat > "$P/game/project.godot" <<GD
config_version=5

[application]
config/name="$NAME"
run/main_scene="res://main.tscn"

[autoload]
InputFrame="*res://core/input_frame.gd"
Harness="*res://core/harness.gd"

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="viewport"

[physics]
3d/physics_engine="Jolt Physics"
common/physics_interpolation=true
GD
  [ -e "$P/game/main.gd" ] || printf 'extends Node3D\n## The game root. Build the world, then hand it to the harness.\n\nfunc _ready() -> void:\n\tHarness.world_ready(self)\n' > "$P/game/main.gd"
  [ -e "$P/game/main.tscn" ] || printf '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://main.gd" id="1"]\n\n[node name="Main" type="Node3D"]\nscript = ExtResource("1")\n' > "$P/game/main.tscn"
  echo "created $P/game (Godot baseline + harness)"
fi
if [ ! -d "$P/.git" ]; then git -C "$P" init -q && echo "git initialised"; fi
[ -e "$P/.gitignore" ] || { printf '.godot/\n*.blend1\nqa/raw/\n.drive.lock\n' > "$P/.gitignore"; echo "created $P/.gitignore"; }
echo "scaffold ready: $P"
