---
name: sourcing-and-processing-game-audio
description: Use when a game needs sound effects, ambience loops or music from real recordings or free libraries (Pixabay, Freesound and similar) — choosing and downloading them, recording their licences, editing and levelling them, making seamless loops, wiring them into Godot — or when a loop clicks, levels are inconsistent, or a sound's licence or origin is unclear.
---

# Sourcing and Processing Game Audio

## Overview

Originals are evidence: kept untouched, with their page as it looked at download time. Every game sound is
**rebuilt by script** from those originals and a recipe, the way models are rebuilt from Blender scripts. Every
output is measured, never just listened to. That matters because you cannot listen.

`templates/build_audio.py` turns a JSON recipe into game sounds and writes `audio_report.md`. It was verified with
ffmpeg 9 on a deliberately bad loop: layers, trims, speed, filters, LUFS levelling, a peak limiter, crossfaded loop
seams, WAV/OGG chosen by length, and a measured click at the seam.

## Sourcing

- **Use an official API where one exists.** Freesound's API gives licence filters (CC0 / CC-BY), metadata and the
  original files. On sites without one, download through a normal browser session the way a person would.
  **Never defeat bot protection** (Cloudflare challenges, scraping around a login). If a source blocks you, use the
  next source or ask at setup, never a synthesized stand-in.
- **Respect the run's rules** on what counts as allowed (real recordings only, or synthesized too). Reject
  anything a library marks as AI-generated when the rules say real recordings.
- **Music:** reject tracks registered with **Content ID**. A Content ID track gets every gameplay video claimed.
- **Store each download in `audio_src/<group>/`, with three things:**
  - the original file, untouched;
  - `<id>.json`: page URL, title, author and author URL, licence and licence URL, download time (UTC), AI mark,
    Content ID status;
  - `<id>.page.html`: the page snapshot, the evidence if the page or the licence changes later.
- `audio_src/` is **never shipped and never pushed public**. Pixabay-style licences allow use inside a game but
  forbid redistributing the sound files. The release README says so.

## Processing (`build_audio.py` + `audio_recipes.json`, both kept in git)

| Convention | Value |
|---|---|
| Names | `<category>_<event>[_<variant>]_NN`, e.g. `footstep_concrete_01..08`, `wpn_fire_01..04`, `enemy_alert_brute_01..03` |
| Variants | 3-8 per frequent event (footsteps, impacts, shots), so repetition doesn't show |
| Layers | build a sound from several originals: body + transient + tail |
| Format | one-shots: 48 kHz 16-bit WAV, mono for 3D; over 2 s or looping: OGG Vorbis q6 |
| Level | a LUFS target per category (e.g. shots −14, music −20, ambience −28); too short to gate → peak-normalise; a peak limiter at −1 dBTP **with latency compensation** |
| Loops | a crossfaded seam (the audio past the end fades into the start); length kept exact |

## Verify (numbers, because you can't listen)

- `audio_report.md` after every build gives each sound's duration, rate, channels, LUFS and true peak, plus for
  loops the **click ratio** at the seam (> 5 = audible click). A level comparison alone misses clicks: measured, a
  clicking loop showed a 0.0 dB jump.
- **Onset:** a transient must start within 5 ms. A limiter without latency compensation delays every sound.
- **In the engine:**
  - every sound ID the code uses exists in the folder, and every file in it is used;
  - loop flags are set on import;
  - a bot scenario fires each event, and Movie Maker's recorded audio shows sound within 50 ms of each event and
    no clipping.
- **No sound on the speakers from test runs:** use `--audio-driver Dummy` for windowed captures that aren't
  recording audio.

## Wiring (Godot)

- Buses: Master → SFX / UI / Music / Ambience.
- A sound ID plays a random variant (`AudioStreamRandomizer` or the `_NN` set) with a small random pitch and
  volume.
- Rate-limit each ID, cap voices per source, and use 3D attenuation suited to the sound.
- Say "needs owner's ears" only for taste: mix balance and character. Name what was measured instead.

## Credits

Each processed file gets one row in `credits.md`: game file(s), source page, title, author, licence, download UTC,
and the processing recipe name. Generate the rows from `audio_src/*.json` and the recipe, never by hand.
