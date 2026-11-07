# Trailer: footage, beats, cut

A gameplay trailer shows the game being played. It is cut from recorded play of the real build, by recipe
(`templates/trailer.json` → `scripts/cut_trailer.py`), so it can be rebuilt after every change. Out of scope:
cinematic fly-throughs, music beds, text cards between shots.

## 1. Footage

- **Who plays:** a recording of the owner playing (a LIVE run with an absolute `--record=` path, saved as
  `store/footage/<run>.json`) when there is one: humans play with intent. Otherwise the autopilot
  (godot-scenario-harness → Bots), with a scenario that seeks the moments the trailer needs (fights, jumps, the
  goal). Record input headless, then replay to film; the replay is tick-exact:

```bash
bash scripts/capture.sh record autopilot run1   # -> store/footage/run1.json (fails loudly if not written)
bash scripts/capture.sh film run1               # -> run1.avi, run1-sec/ (a still per second), run1-sheet.jpg
```
- `capture.sh` exists because three things went wrong by hand (measured, Godot 4.8):
  - **Relative paths resolve against the project** (`--path`), not the shell: a relative `--record` was lost
    with exit 0 (the harness now exits 6), a relative `--write-movie` crashed Godot, a relative `--out` wrote
    renders into the project. The script passes absolute paths.
  - **The movie ignores `--resolution`:** the movie writer takes the startup window size (1920×1080 stills, a
    1152×648 movie). The script writes a temporary `override.cfg` (window override 1920×1080) for filming and
    screenshots, removes it afterwards, and checks the movie is 1920×1080.
  - **Movie quality is low by default:** the same `override.cfg` sets `editor/movie_writer/video_quality=0.95`
    (the 4.8 name; `mjpeg_quality` is ignored). Measured on 4 s of 1080p: 0.3 → 11.9 MB, default → 16.2 MB,
    0.95 → 31.1 MB. The AVI is re-encoded to H.264 later, so start from the best.
- A replay stops at the recording's last tick (a longer replay would run on with zero input: a frozen tail).
- Debug overlays in group `store_hide` are hidden in footage and stills (`HIDE_GROUP`, the harness's
  `--hide-group`).
- The AVI carries the game's own audio (PCM); a silent game gives a silent trailer (fine, but say why in RUN.md).
- **Picking moments:** open `run1-sheet.jpg`. Each tile is labelled `t<tick>_s<second>`: the tick for
  screenshots (`store/shots.json`), the second for trailer cuts. Write the in/out seconds of each candidate; for a
  closer look, `store_tools.py frames run1.avi --every 0.5 --out ...` around it.

## 2. Beats (default 30–90 s; a teaser may be 15–30 s)

| Beat | Length | What |
|---|---|---|
| Hook | 0–5 s | the most striking play moment, mid-action, from frame 1. No logo, no studio card, no black lead-in |
| Core loop | ~20 s | what the player does, 3–6 cuts of 2–4 s, each one readable action |
| Variety | ~20 s | places, enemies, mechanics: one cut each, never the same view twice |
| Escalation | ~10 s | the hardest, biggest or best moment the game has |
| End card | 3–5 s | the logo on calm art; optionally one line the owner gave (release window, "Wishlist on Steam") |

- Cut on action (a hit, a jump's take-off, a turn), not on calm frames; 2–4 s per cut, shorter in the escalation.
- Must read **muted**: every cut shows what happens without its sound.
- Only footage of the game as it plays: no slowed or sped-up clips presented as normal play, no hidden HUD.

## 3. Cut and check

- Copy `templates/trailer.json` to `store/trailer.json` (paths in it are relative to `store/`; in a run, where
  `KIT` is `final/store`, write `../final/store/trailer/...` instead of `kit/trailer/...`). Fill the segments in
  trailer order, the end card (`export_kit.sh` writes `KIT/trailer/trailer-end-card.png` from the
  `trailer-end-card` panel of `capsules.html`), and a thumbnail frame with a quiet HUD (Valve: avoid text in it).
- `python3 scripts/cut_trailer.py store/trailer.json` writes the .mp4, the thumbnail and `trailer_report.md`:
  size, fps, codec, bitrate (floor 5000 kbps), AAC 48 kHz stereo, loudness (−14 LUFS), true peak, and **frozen
  gameplay** (ffmpeg `freezedetect`, ≥ 1.2 s still before the end card), each PASS/FAIL. Exit 1 on a failure: fix
  the recipe or the footage, never the threshold. (Measured on the test fixture: the autopilot stuck on a crate
  for 2.7 s passed every format check and was caught only by the freeze check and the contact sheet.)
- **Look at the result:** `store_tools.py frames trailer.mp4 --every 2 --out ...` and a sheet. Gameplay from the
  first tile, no black or frozen stretch, the end card last. A failed look is a defect like a failed check.
