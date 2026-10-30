# Game builds

Seven skills for building a game autonomously, from an idea to a finished, verified result, with
Godot 4, Blender (by Python script), optional Tripo3D generation and game audio from real recordings. The workflow is
evidence-driven: setup questions are asked once and written into a rules file, the brief turns every requirement into
a numbered test with an evidence file, and the run then works look by look. Each look captures the real game,
inspects the captures and measurements, names the largest defects and fixes them. The run stops only when the
recorded stop rule holds. Throughout, `final/` holds the best verified build.

Unlike app runs (which keep their records in a gitignored `data/run/`), a game run commits its records with the
project: the looks, captures and prompt record are part of the game's history.

## How the skills fit together

```
running-autonomous-game-builds
  1. Setup (once):   store the request -> setup questions -> scaffold.sh -> docs/RULES.md
  2. Brief:          writing-game-briefs -> docs/BRIEF.md (tests with IDs, thresholds, evidence files)
  3. Run (silent):   iterating-with-look-checkpoints
                       blockout -> central mechanic in the running game
                       -> capture -> inspect -> test -> fix largest defects -> freeze look L###
                       -> repeat
                          |  captures, bots, playback, measurements: godot-scenario-harness
                          |  models, kits, rigs, previews:           building-blender-assets-by-script
                          |                                          (+ tripo-cli for generated bases)
                          |  sound effects, loops, music:            sourcing-and-processing-game-audio
                       pause only at the configured review checkpoints
  4. Stop rule:      completion conditions / budget cap / time cap (from docs/RULES.md)
                     -> finish pass (+ store-page kit if RULES.md asks: designing-game-store-pages)
                     -> final/QA.md -> report
```

## The skills

| Skill | Use it when | Key files |
|---|---|---|
| `running-autonomous-game-builds` | Building a whole game or large feature end to end, unattended, or resuming such a run | `SKILL.md`, `setup-questions.md`, `rules-template.md`, `kickoff-template.md` (incl. detached driver), `wallet-statusline.md`, `scaffold.sh` |
| `writing-game-briefs` | Turning an idea into the acceptance contract another session builds from, with measurable tests and required captures | `SKILL.md`, `brief-template.md` |
| `iterating-with-look-checkpoints` | Building or polishing anything visible or felt (art, VFX, lighting, animation, camera, feel, UI, audio feedback); before calling it done | `SKILL.md`, `LOOK.md`, `RUN.md`, `QA.md`, `passes-and-review.md` |
| `godot-scenario-harness` | Unattended screenshots or clips from the real Godot 4 game, bot scenarios, input record/playback, measured jitter/snap/tunnelling/stuck/frame-time tests | `SKILL.md`, `templates/harness.gd`, `input_frame.gd`, `bot.gd`, `measures.gd`, `scenarios/t_jitter.gd`, `scenarios/look_tour.gd` |
| `building-blender-assets-by-script` | Creating game assets in Blender by Python script for Godot, preparing generated/purchased/mocap models, or fixing export problems (axes, collision, sockets, materials, provenance) | `SKILL.md`, `generated-models.md`, `templates/kitlib_min.py`, `build_example.py`, `verify_glb.py`, `check_kit.gd` |
| `sourcing-and-processing-game-audio` | Sourcing sound from free libraries with licences recorded, then editing, levelling, looping and wiring it into Godot by script | `SKILL.md`, `templates/build_audio.py` |
| `tripo-cli` | Generating, texturing, rigging or retargeting models with Tripo3D through the `tripo` CLI, within a credit cap | `SKILL.md` (points to the CLI's own bundled instructions) |
| `designing-game-store-pages` | The store-page kit from the real game: Steam capsules, library art, icons, gameplay screenshots, a gameplay trailer, the itch.io cover, the AI-disclosure draft; on demand (`/anvil:store-page`) or in the finish pass | `SKILL.md`, `steam-rules.md`, `key-art.md`, `trailer.md`, `templates/store_key_art.gd`, `capsules.html`, `trailer.json`, `AI-DISCLOSURE.md`, `STORE-KIT.md`, `scripts/capture.sh`, `export_kit.sh`, `cut_trailer.py`, `store_tools.py` (sizes from designing-app-listing-images → `sizes.json`) |

## Requirements

- **Godot 4.x** on the command line (`godot`). The harness templates were verified on Godot 4.8. Captures need a real
  renderer (windowed, Vulkan); `--headless` cannot capture.
- **Blender with its bundled Python**, run in background mode (`blender --background --python ...`). The templates
  target Blender 4.2+ (verified 4.2 to Godot 4.8).
- **Python 3**, for `build_audio.py` and the detached driver's wallet writer.
- **ffmpeg and ffprobe**, for the audio pipeline (`FFMPEG` env var to override the binary) and the trailer.
- Only for the store-page kit: **Node.js with Playwright's Chromium** (capsule export) and **Pillow** (`store_tools.py`).
- **git** and **bash** (`scaffold.sh` initialises a git repo in the project).
- **Optional, paid: Tripo3D.** The `tripo` CLI (`npm install -g tripo-cli`, so Node.js/npm), an API key in
  `TRIPO_API_KEY`, and a non-zero API balance (`tripo doctor`, `tripo balance`). Used only when the run's rules allow
  it as an exception, under a hard credit cap.
- **Optional: Claude Code CLI** for the detached driver (`claude -p --resume`, `flock`), and Node.js for the status
  line wallet writer, when a budget stop rule is used.

## Quick start

In an empty project directory, after installing the plugin (see the [README](../README.md#installation)):

```
/anvil:build-game Build a small 3D arena game in Godot end to end: the player dodges and pushes enemies off a floating platform.
Make it as good as you can.
```

The agent stores the request, asks the setup questions (asset and audio sources, generative services, quality bar,
stop rule, review checkpoints, agent policy, loop), scaffolds the workspace, writes `docs/RULES.md` and the brief,
and then runs until the stop rule holds. To resume after a pause or a context limit, run `/anvil:resume-run` (or ask it to continue the run); it
reads `docs/RULES.md`, `RUN.md`, the latest look and `final/QA.md` first.

## Where the run writes

`scaffold.sh <project-dir>` creates (never overwriting an existing file):

| Path | Contents |
|---|---|
| `game/` | Godot project: `project.godot` (Jolt, physics interpolation, 1920x1080 viewport stretch), `main.tscn`/`main.gd`, harness in `core/`, bot and scenarios in `tests/` |
| `blender/` | Blender build scripts and `.blend` outputs |
| `qa/` | tests and raw logs |
| `looks/` | one record per look (`L###/`), plus `LOOK_TEMPLATE.md` |
| `final/` | the best verified build's captures and `QA.md`; `final/store/` the store-page kit when RULES.md asks |
| `docs/` | `RULES.md`, `BRIEF.md`, `KICKOFF.md`, `SPEC.md` (asset contract), `ARCHITECTURE.md` (code card for helpers) |
| `prompts/` | every input as sent, verbatim and append-only |
| `RUN.md` | run record: intent, decisions, look history, feedback, findings, final report |
| `credits.md` | provenance of every external item and generated task |
| `store/` | store-kit recipes: footage recordings, `capsules.html`, `trailer.json`, key-art prompts (the large renders and movies are gitignored) |
| `DELEGATION.md` | helper spawns and finishes |
| `.gitignore` | `.godot/`, `*.blend1`, `qa/raw/`, `.drive.lock` |

During the run the skills also use `audio_src/` (untouched audio originals with licence metadata, never shipped),
`generated/<name>/` (raw Tripo outputs), `docs/STOP` and `docs/FEEDBACK.md` (detached driver reviews), and
`docs/WALLET.json` (spend, under the driver).

## Customising

- **Setup questions and their options:** [`setup-questions.md`](../plugins/anvil/skills/running-autonomous-game-builds/setup-questions.md). The recommended
  option is listed first.
- **Run rules layout and the defaults when no rules exist:** `rules-template.md` and the Stopping section of
  `running-autonomous-game-builds/SKILL.md`.
- **Workspace layout and the Godot baseline:** [`scaffold.sh`](../plugins/anvil/skills/running-autonomous-game-builds/scaffold.sh).
- **Kickoff prompt and detached driver:** `kickoff-template.md`.
- **Brief structure and standard tests:** [`brief-template.md`](../plugins/anvil/skills/writing-game-briefs/brief-template.md).
- **Look, run and QA records, passes and the visual review checklist:** the `.md` files in
  [`iterating-with-look-checkpoints/`](../plugins/anvil/skills/iterating-with-look-checkpoints/).
- **Harness input mapping:** the three `_sample_live_*` functions in `templates/input_frame.gd`; capture viewpoints
  in `templates/scenarios/look_tour.gd`; jitter thresholds in `templates/scenarios/t_jitter.gd`.
- **Asset contract** (axes, material roles, collision and socket naming, triangle budgets): the Contract table in
  `building-blender-assets-by-script/SKILL.md`, and `docs/SPEC.md` in each project.
- **Audio levels and formats:** the defaults in `build_audio.py` and each project's `audio_recipes.json`.
