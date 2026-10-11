---
name: godot-scenario-harness
description: Use when a Godot 4 project needs unattended screenshots or clips from the real game, scripted bot scenarios, input record/playback, or measured feel/solidity/performance tests (camera jitter, snap, tunnelling, stuck, frame time); when capture runs hang, come out blank or show the wrong pose; or when a project has accumulated many one-off screenshot scenes.
---

# Godot Scenario Harness

## Overview

There is one harness, and the real game boot runs under it:
- **`Harness` autoload.** CLI args after `--` choose a scenario, captures, recording, playback, a per-frame log and a wall-clock guard.
- **`InputFrame` autoload.** Game state reads input **only** from one frame per physics tick. The sources are LIVE, BOT and PLAYBACK, and every frame is recordable.
- **`Bot` scenarios.** They produce only input, so whatever a bot does can be recorded and replayed.
- **`Measures`.** Pure metric functions.

The working templates are in `templates/`, verified on Godot 4.8 (Linux, NVIDIA): headless scenario, record → tick-exact playback, off-screen windowed capture, stills at ticks during playback, and a jitter negative control.

## Setup

1. Copy `templates/*.gd` into the project. Register the autoloads **in this order**: `InputFrame`, then `Harness`. Put the scenarios in `res://tests/scenarios/`. The `Bot` and `Measures` class names need one `godot --headless --import` before first use.
2. Route game input through `InputFrame` (edit its three `_sample_live_*` functions). In an existing project, see "Existing projects" below.
3. Call `Harness.world_ready(self)` once the world exists.
4. **Determinism rule:** game state changes only in `_physics_process`. Timers, tweens and animations that drive gameplay run in physics mode. Render-rate code may read state, never write it. Seed RNGs from `Harness.seed_value`.

## Launch

| Run | Command |
|---|---|
| Logic / measurement | `godot --headless --path P --fixed-fps 60 -- --scenario=t_x --out=D` (jitter: `--fixed-fps 144`) |
| Captures | `prime-run godot --path P --display-driver x11 --rendering-driver vulkan --position -6000,-6000 -- --scenario=look_tour --out=D` |
| Record | add `--record=run.json` to any run, human (LIVE) or bot |
| Replay + stills | `... -- --playback=run.json --stills=ticks.json --quit-ticks=N` (`ticks.json` = `[[tick, "x.png"], ...]`) |
| Clip | windowed + `--write-movie out.avi --fixed-fps 30 --quit-after N` |

`prime-run` is only needed on hybrid-GPU laptops. Run with `stdbuf -oL` so a timeout can't swallow the verdict line. Exit codes: 1 = scenario failed, 3 = scenario missing, 4 = wall-clock limit, 5 = capture impossible.

## Gotchas (measured)

- **`--headless` renders nothing and still "saves" frames.** `Harness.capture` refuses with exit 5.
- **Never `await RenderingServer.frame_post_draw`.** An unfocused or off-screen window stops presenting and the await hangs silently. Capture is `camera_set_transform(cam_rid, cam.get_camera_transform())`, then `force_draw()` twice, then `get_image()`. A forced draw doesn't flush transform notifications, so without that first call it draws the previous pose.
- **Parse args in `_init`, not `_ready`.** The main scene's `_enter_tree` ran *before* the Harness autoload's `_ready`, and read an empty args dict.
- **Sample `cam.get_camera_transform()`. It is what gets drawn.** With physics interpolation on, `global_position` steps once per tick: 83 mm steps at 144 FPS while walking 5 m/s.
- After a teleport, call `reset_physics_interpolation()`, or the first frames smear across the map.
- Save recordings with `JSON.stringify(d, "", false, true)`. The default rounds floats, so the look deltas drift on replay.
- A staged or extracted capture scene can silently drop a system: it renders "empty" and reads as a bug. Capture the real boot. If you must stage, assert that the systems under test exist.

## Measurement Recipes (`Measures`)

| Property | Metric | Note |
|---|---|---|
| Jitter | `second_diff_mm(positions)` RMS / p99 per **rendered** frame | catches lateral jitter, which a speed-magnitude metric misses. Measure at `--fixed-fps` ≠ the physics rate (144): at 60/60 every frame gets one tick and the test cannot fail |
| Jitter, real time | `velocity_jump_mm(positions, dts)` | divides out frame-pacing variation (≈ speed × Δdt) |
| Rotation noise / snap | `rot_steps_deg(quats)`, max | uses an atan2-based angle; `acos(dot)` reads tiny snaps as 0 |
| Tunnelling | `tunnelled(space, prev, now, [rid])` every tick | a ray from last tick's position |
| Stuck | `max_stuck_s(track, hz)` < 2.0 | < 0.3 m net progress in any 2 s window while pushing |
| Performance | `frame_time_stats(ms)` p50 / p95 | after warm-up, busiest view, no capture running |

**Run a negative control for every metric:** break the property on purpose and confirm the test FAILS. Measured: jitter p99 = 0.002 mm with interpolation on, and 83.3 mm (FAIL) with it off at 144 FPS. A test that cannot fail proves nothing. Neither does a test that asserts your own constants.

## Bots

- Bots drive closed-loop **through input**: `walk_to`, `look_delta_toward`. Spawning or posing the actor before a test is fine. Writing state during the measured part is not.
- **One look scenario per system** (HUD, FX, weapon, hands, dressing), each with its fixed viewpoints. A look
  pass on one system then re-runs only its own captures.
- An **autopilot** that plays the whole loop through input survives level edits better than a human recording. Record its run, then replay it with `--stills` and `--write-movie` for the final captures.

## Existing Projects

Map onto what is already there. Don't build a second copy of it:
- **An input recorder or layer already exists** (an input journal, a playback source, a custom input manager): implement BOT and PLAYBACK as sources on its polling seam, and keep the `InputFrame` contract.
- **A test runner, kit or gate exists:** register scenarios there, keep its boot flags (for example a `--no-server` user arg) and its isolation rules (scratch user-data directory).
- **Many `*_shot` scenes:** move them into `look_tour` views on the real boot, one at a time. Each move needs a capture comparison.
