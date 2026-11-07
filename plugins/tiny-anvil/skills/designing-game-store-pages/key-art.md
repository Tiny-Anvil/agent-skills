# Key art: staging, rendering, composing

Key art is the picture behind the logo on every capsule. It sells the game in a thumbnail: **one subject, one
situation, one place**, readable at 231 px wide. It is staged, not invented: the game's own models, materials,
lighting and renderer, posed for the camera.

## 1. Pick the moment

Write one line before posing anything: *who* (the player character, or the vehicle, or the hand of cards), *doing
what* (facing the threat, mid-jump, about to win), *where* (the most recognisable place). Take it from the brief's
"what matters most" and the best screenshot moments. Reject: an empty level, a menu, a crowd with no subject.

## 2. Stage it in the real game

- Use `templates/store_key_art.gd` (a harness scenario on the real boot), run by `scripts/capture.sh keyart`. Position the actor and props
  (allowed for captures, as in `look_tour`), hide 3D debug labels and nameplates with the group `store_hide`.
- Lighting may be helped: a rim or key light added in the scenario, a time of day the game has. It may not
  change what the game looks like (no new materials, effects or post-processing the game lacks).
- **Render with the game's own renderer** (the harness's Captures command: Vulkan, Forward+ or Mobile as the game
  ships). The Compatibility renderer (`--rendering-driver opengl3`, e.g. under `xvfb-run`) looks different: use
  it only to smoke-test the pipeline.
- **One view per capsule shape** (the SHOTS comments in the template): a render that covers a panel has slack on
  one axis only, so CSS cannot move the subject sideways later. Frame it in the camera:

| View | Ratio | Serves | Frame |
|---|---|---|---|
| `wide` | 16:9 | main capsule, page background, itch cover | subject centred or slightly right; logo low |
| `banner` | ~2.1:1 | header, small, library header | subject inside the right 40% (centre ~75% of the width); the left 55% stays calm for the logo |
| `hero` | 3.1:1 | library hero | subject inside the centred 860×380 safe area; no logo, no words |
| `tall` | 2:3 | vertical, library capsule | subject between 15% and 65% of the height (the 5:6 vertical capsule crops ~10% top and bottom); logo in the lower third |

- Render about 2× the largest capsule a view serves. Open every render: subject sharp, nothing clipped by the
  near plane, no HUD, no debug labels, shadows settled.

## 3. The logo

- The game's logo file (transparent PNG or SVG) if it has one. Otherwise a **logotype** in `capsules.html`: the
  game's name in one heavy display face, with an outline or shadow for contrast on any art.
- **The font is a file**, at `store/fonts/display.ttf` (the template's `@font-face`): the game's own title or UI
  font when it has one; otherwise a free display font (SIL OFL, e.g. from Google Fonts) chosen for the genre,
  downloaded with its licence and logged in `credits.md`. Never the system fallback: a missing file silently
  renders in whatever sans the machine has, so open the export and check the letterforms.
- One logo for every capsule (`<template id="logo">`): it is the game's mark, not per-capsule lettering.
- Legibility beats size: the small capsule is the test (231 px wide). Shorten nothing; enlarge and simplify the
  outline instead.
- Icons (shortcut 256, app 184): the logomark, or the first letter of the logotype, on a solid shape.

## 4. Compose the capsules

- Copy `templates/capsules.html` to `store/capsules.html` (the renders are in `store/keyart/`); edit only the
  marked parts: the font, the logo, colours, fine framing (`background-position`), logo slot positions.
- The trailer end card uses the `wide` render blurred and darkened, so the logo sits on calm art whatever the
  subject's position.
- The shade behind the logo (`shade-left`, `shade-bottom`) is a gradient, never a text banner or a box.
- Export everything: `bash scripts/export_kit.sh store/capsules.html "$KIT"`. Look at each file at its real size and at
  half size before the kit check (`steam-rules.md` → Kit check).

## 5. AI key art (only with the owner's yes, every time)

Owner rule (2026-10-29): AI key art is allowed, but **the owner is asked first, every time**. Never generate it
because it would look better, and never because RULES.md allowed generation for something else.
- **Propose, don't generate:** what would change (painted look, a scene the renderer can't stage), why it sells
  better, a mock-up made from the renders (`capsules.html` with the render as a stand-in), the provider and the
  cost. On demand: ask in the conversation. In a run: put the proposal in the next review, or in the final report
  when no review is coming; the kit ships with renders meanwhile.
- **After a yes:** generate with `../designing-app-listing-images/scripts/gen_image.py`, passing the renders as
  `--ref`, so characters and setting stay the game's own. Log every image in `store/keyart/prompts.md`: file,
  prompt, provider, model ID, references, date, the owner's yes (quote). It goes into `AI-DISCLOSURE.md`.
- AI art must still show the game as it is: its characters, its setting, no features it lacks.
