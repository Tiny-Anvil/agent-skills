---
name: designing-game-store-pages
description: Use when a game needs its store-page kit — Steam capsules (header, small, main, vertical), library art (capsule, header, hero, logo), community icons, gameplay screenshots, a gameplay trailer, an itch.io cover — made from the real game, on demand or in a game run's finish pass; when capsule art breaks Valve's text rules, screenshots aren't gameplay, a Godot movie comes out at the wrong size, a trailer fails Steam's spec, or Steam's AI disclosure needs drafting.
---

# Designing Game Store Pages

## Overview

A store page sells a game with **its own footage and its own models**. Steam allows no marketing text on capsules
and only gameplay in screenshots, so the craft is picking real moments, staging key art in the real game and
cutting play into a trailer. Every output is rebuilt from recipes and checked by measurement:

| Output | Made by | Checked by |
|---|---|---|
| Footage, contact sheets | `scripts/capture.sh record` + `film` (tick-exact replays at 1920×1080) | the movie's size; the sheet, looked at |
| Screenshots | `store/shots.json` → `scripts/capture.sh shots` | `store_tools.py shots` (run by it), a look at each |
| Key art renders | `templates/store_key_art.gd` → `scripts/capture.sh keyart` (SubViewport, any size, no HUD) | opened at size and at thumbnail |
| Capsules, library art, icons, itch cover, end card | `templates/capsules.html` → `scripts/export_kit.sh` | exact preset sizes; kit check |
| Trailer | `templates/trailer.json` → `scripts/cut_trailer.py` | `trailer_report.md` (format, loudness, black and frozen stretches) + a contact sheet of the result |
| AI disclosure | `templates/AI-DISCLOSURE.md` from the logs | every row cites a log |

Sizes live only in `../designing-app-listing-images/scripts/sizes.json` (presets + `trailer`);
`node ../designing-app-listing-images/scripts/export.js --list` prints them. App stores and web images: that skill.

| File | Read it |
|---|---|
| `steam-rules.md` | before choosing anything: what Valve and itch.io allow, and the kit check |
| `key-art.md` | before staging key art: the moment, the four views, the logo, capsules, AI key art |
| `trailer.md` | before recording footage: filming settings, beats, the cut and its checks |

## Three ways in (on demand: ask which, in one message, with the other intake)

| The game is | Then |
|---|---|
| A Godot project with godot-scenario-harness (tiny-anvil-built) | full path: record, film, stills, key-art renders |
| Another Godot project | offer to add the harness (godot-scenario-harness → Existing Projects). It writes into the owner's repo: **only after a yes**. On a no: next row |
| Any game ("bring your own") | a folder of screenshots (≥ 1920×1080) and footage, plus a logo if it has one. Select, crop to 16:9, compose, cut; never invent gameplay, never upscale below-spec images |

Intake (on demand, one message, skip what is known): the game and the way in; targets (Steam, itch.io); the logo
(file, or make a logotype); the one-line promise of the game; moments the owner wants shown; for the trailer an
optional end-card line (release window, "Wishlist on Steam"); whether a recording of the owner playing exists.

## Two modes

| | On demand (`/tiny-anvil:store-page`) | In a game run (finish pass) |
|---|---|---|
| Scope | asked at intake | `docs/RULES.md` → Store page kit (`Steam`, `itch.io`, both) |
| Moments, views, logo, beats | proposed, the owner picks or edits | the agent decides; each decision and why in `RUN.md` → Decisions |
| AI key art | proposed in the conversation; generated only after a yes | `RULES.md` says "may propose" or "never". A proposal goes to the next review or the final report; never a blocker; the kit ships with renders |
| Output (`KIT`) | `store/kit/` | `final/store/` (`KIT=final/store`), shown at the next review |

Layout, from the workspace root: the Godot project in `game/` (`GAME=` otherwise), recipes in `store/`, outputs in
`KIT`. Sources (kept in git): `store/footage/*.json` recordings, `store/shots.json`, `store/capsules.html` (+ the
font file), `store/trailer.json`, `store/keyart/prompts.md`, `game/tests/scenarios/store_key_art.gd`. Large
outputs (`*.avi`, renders, the kit) stay out of git. **Godot resolves relative paths against the project, not the
shell:** run Godot through `capture.sh`, which passes absolute paths and manages the filming `override.cfg`.

## Steps

1. **Read `steam-rules.md`**, then the intake (on demand) or RULES.md (in a run).
2. **Footage** (`trailer.md` §1): `capture.sh record <scenario> <run>` for one or more runs that reach the game's
   best moments (owner play if recorded, else the autopilot), then `capture.sh film <run>`: the movie at
   1920×1080 with the game's own renderer, a still per second and a contact sheet labelled with tick and second.
   Debug overlays in group `store_hide` are hidden (`HIDE_GROUP`).
3. **Screenshots:** pick 5–8 moments from the sheets (strongest first, varied, HUD on, the bot visibly playing,
   not stuck) into `store/shots.json` (`{"run1": [[tick, "01.png"], ...]}`), then `capture.sh shots`: exact-tick
   re-captures at 1920×1080 in `KIT/screenshots/`, flattened to RGB and checked. Open every one.
4. **Key art** (`key-art.md`): write the one-line moment; stage the four views in `store_key_art.gd`;
   `capture.sh keyart` with the game's renderer; open every render.
5. **Logo and capsules:** the logo or a logotype, then `store/capsules.html` → `export_kit.sh store/capsules.html
   "$KIT"`. Look at each file at full and half size; the small capsule's logo must read at 231 px wide.
6. **Trailer** (`trailer.md` §2–3): beats → `trailer.json` → `cut_trailer.py` → all PASS → contact sheet of the
   result, looked at.
7. **AI disclosure:** fill `templates/AI-DISCLOSURE.md` from the generated-asset ledger (`credits.md` or
   `credits/<domain>.md`, building-blender-assets-by-script → `generated-models.md`), `audio_src/*.json`,
   `store/keyart/prompts.md` and RULES.md. **A game built by an AI agent says so** (its code, levels, script-built
   models, UI): the template's first section. Whether to submit that part is the owner's call, made knowingly.
8. **Kit:** `templates/STORE-KIT.md` with every file, where it goes and the kit check (`steam-rules.md`) result per
   line.
9. **Revise** what is asked; rebuild from the recipes, never by hand-editing an output.

## Rules

- **Only the real game.** Screenshots and trailer are captured from it; key art is staged in it with its own
  models, materials and renderer. Nothing shows a feature, place or look the game lacks.
- **No text on capsules** beyond the logo/name and subtitle; **no words at all** on the library hero; no review
  quotes, awards, prices or calls to action on any Steam image.
- **The game's own renderer** for anything published. The Compatibility renderer (opengl3, e.g. under `xvfb-run`)
  only smoke-tests the pipeline.
- **AI key art only after the owner's yes, every time** (owner rule, 2026-10-29), and always logged and disclosed.
  Screenshots and trailer are never AI-made.
- **One recipe per output**, kept in git; an output is rebuilt, not retouched.
- **Look at every output** (images at size and thumbnail, the trailer as a contact sheet). A failed look is a
  defect, like a failed check.

## Red Flags

| Thought | Reality |
|---|---|
| "'Overwhelmingly Positive' on the header capsule would sell it" | Banned on capsules since 2022. Steam's accolades section is the place. |
| "A screenshot with a caption explains the mechanic" | Screenshots are gameplay only; the description explains. |
| "I'll slide the subject right with background-position" | A cover-fitted render has no sideways slack: frame it in the camera (the `banner` view). |
| "`--resolution 1920x1080` is set, so the movie is 1080p" | The movie writer takes the startup window size: `capture.sh` writes the `override.cfg`. |
| "`--record=store/footage/run1.json` is fine, the shell is in the workspace" | Godot resolves it against the project: lost, or written into `game/`. Absolute paths (`capture.sh`). |
| "The xvfb renders look fine, ship them" | Compatibility renderer: not how the game looks. Re-render with its own renderer. |
| "A painted key art would look so much better, I'll just generate it" | Propose it; generate only after the owner's yes; log it for the disclosure. |
| "The bitrate check fails, lower the floor" | Fix the footage or the recipe; the spec comes from Valve. |
| "No time to look at the trailer, the report passed" | The report measures format, not content: make the contact sheet and look. |
