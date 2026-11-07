# Store rules: Steam and itch.io

Sizes are not repeated here: `node ../designing-app-listing-images/scripts/export.js --list` prints every preset
from `sizes.json`, with its spec link. This file holds the **content rules** and the checks. Valve's pages:
[graphical assets](https://partner.steamgames.com/doc/store/assets),
[library assets](https://partner.steamgames.com/doc/store/assets/libraryassets),
[capsule rules](https://partner.steamgames.com/doc/store/assets/rules),
[trailers](https://partner.steamgames.com/doc/store/trailer),
[content survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey). Re-read them before a release:
Valve changes sizes and rules (old capsule sizes stopped being accepted in 2024).

## Capsules (store: header, small, main, vertical; library: capsule, header)

Rules in effect since 2022-09-01:
- **Allowed:** key art, the game's name (logo), its official subtitle. Nothing else.
- **Banned:** review scores or quotes (press included), award names, laurels or logos, discount or price copy,
  calls to action ("Wishlist now", "Prepurchase"), other products (sequels included), any other text.
- Temporary event text ("DLC now available") only through Steam's Artwork Override, for at most a month,
  localised: out of scope for this skill.
- The logo is **readable at the small capsule**: check it at half size (231 px wide), as list rows show it.
- Artwork is PG-13. It shows the game as it is: its own models, characters and setting.
- Library capsule and library header: logo (+ subtitle) only.

## Library hero and logo

- **Hero: no words at all**, not even the logo: Steam draws the library logo on top of it. Key content sits inside
  the **centred 860×380 safe area** (`capsules.html` draws it as a guide that is removed at export); everything
  outside may be cropped on some screens.
- **Logo:** the logotype (and logomark) only, transparent PNG, scaled to 1280 wide and/or 720 tall
  (`store_tools.py trim`). Its position over the hero is set in Steamworks' logo tool, not in the image.
- Library assets show only once the store page is published.

## Screenshots

- At least 5, 16:9, 1920×1080 or larger (`store_tools.py shots` checks count, size, ratio and alpha).
- **Gameplay only:** frames from the real game with its HUD, as a player sees it. No concept art, no
  pre-rendered cinematic stills, no captions, award or marketing text, no mock-ups. Menus only when the menu itself
  is a feature (a deck builder, a level editor).
- At least four suitable for all ages (Steam asks you to mark them).
- Order: the strongest moment first; the first ones show next to the trailer on the store page.
- Variety: core action, a second mechanic, a different place, a calm or wide shot that shows the world, a
  progression or upgrade moment. No two from the same second of play.

## Trailer

- Up to 1920×1080, 30 or 60 fps, ≥ 5000 kbps, H.264 + AAC in .mp4 (`cut_trailer.py` reads these from
  `sizes.json` → `trailer` and checks the result).
- The first two trailers show **before** the screenshots: the trailer is the first thing a visitor sees.
- Gameplay in the first seconds, HUD visible, readable without sound. The thumbnail is a frame of footage;
  Valve asks to avoid text in it, so pick a frame where the HUD is quiet (or re-capture that tick with the HUD's
  group hidden: `HIDE_GROUP=store_hide,hud`). More in `trailer.md`.

## AI disclosure

Steam's content survey asks whether AI-generated content ships, before review: **pre-generated** (made during
development, e.g. art, models, sound, text) described in detail, and **live-generated** (made at runtime) with its
guardrails. It is about content players consume; efficiency gains from AI tools are not its focus. An tiny-anvil-built
game's levels, script-built models and UI were authored by an AI agent: that is content, so the draft
(`templates/AI-DISCLOSURE.md`) states it in its first section. The owner reads Valve's current wording, decides and
submits; the skill never drops that section on its own.

## itch.io

- Cover: 315:250, at least 315×250; 630×500 recommended (`itch-cover`). It shows in browse grids: same logo
  legibility check as the small capsule.
- Screenshots: any size; 3–5 recommended. Reuse the Steam screenshots.
- Banner: optional, no fixed size, may be a semi-transparent PNG; it replaces the title above the description.
  Export at the width of the page's content column with `--alpha`.
- Video: a YouTube or Vimeo link, not an upload: the trailer goes there first.
- At most 10 uploaded files per page. No AI images that look like photos of real people.

## Kit check (before calling it done)

- [ ] Every required Steam asset exists at its preset size (`export_kit.sh` output, `store_tools.py shots`).
- [ ] No text on any capsule except the logo/name and subtitle; no words at all on the hero.
- [ ] Small capsule logo readable at 231 px wide; header and main logos readable at half size.
- [ ] Screenshots: ≥ 5, gameplay with HUD, no debug overlays, varied, strongest first, ≥ 4 all-ages.
- [ ] Trailer: `trailer_report.md` all PASS (incl. no black or frozen gameplay); a contact sheet of the finished
      trailer looked at (gameplay from the first tile, end card last, no debug overlays).
- [ ] Key art uses the game's own models and renderer, or an AI image the owner approved (logged).
- [ ] `AI-DISCLOSURE.md` drafted from every log, with the "made by an AI agent" section for an tiny-anvil-built game.
- [ ] `STORE-KIT.md` lists every file and where it goes.
