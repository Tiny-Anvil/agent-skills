---
name: designing-app-listing-images
description: Use when an app needs the images it is listed with — App Store or Google Play screenshot sets, a Play feature graphic, a link-preview (Open Graph) image, PWA install-dialog screenshots or a landing-page hero — made from its real screens, on demand or in an app run's finish pass; when store screenshots look dated or don't sell; when someone wants to recreate a screenshot style they like; or when a listing image is rejected for size, alpha or claims.
---

# Designing App Listing Images

## Overview

Listing images get installs and clicks when the **words come first and the design second**. Each set is one HTML
page of panels built from the app's real screens, checked side by side at thumbnail size and exported at exact
store size with `scripts/export.js`. Sizes live only in `scripts/sizes.json` (`node scripts/export.js --list`).

Based on aso-shots by ceorkm (MIT, `NOTICE-aso-shots`). Game stores (Steam, itch.io): designing-game-store-pages.

| File | Read it |
|---|---|
| `copywriting.md` | before the storyboard (step 3) |
| `STYLES.md` + `styles/NN-*/design.md` | when picking directions (step 4): 18 styles, used as DNA, never as templates |
| `assets.md` | before getting any image (step 6): what is code, what is generated, provenance |
| `build.md` | while building and exporting (steps 7–8): frames, text fitting, landscape, export, web wiring |

## Two modes

| | On demand | In an app run |
|---|---|---|
| Started by | `/tiny-anvil:listing-images`, or a request | the finish pass of running-autonomous-app-builds |
| Scope | asked at intake | `docs/RULES.md` → Listing images (`web + PWA`, or `+ app stores`) |
| Screens | the user's screenshots, a store URL (`scripts/fetch_listing.py`), or Playwright on a live URL's public pages | the final build's Playwright captures (dotnet-vue-test-harness), fictional seed data; tablet size captured extra when stores are in scope |
| Storyboard, direction | the user approves the storyboard and picks one of three directions | the agent decides both, records them and the reason in `RUN.md`, shows the set at the next review |
| Proof (ratings, users, press) | only what the user gives | none, unless RULES.md gives it |
| Image generation | as `assets.md` → How to generate | only if RULES.md allows it, within its cap; otherwise code-only |
| Output | a folder per target | `data/run/final/listing/<target>/`; web images also wired into the app (`build.md` §11) |

## Steps

1. **Generator check (once).** Find an image provider in the order of `assets.md` → How to generate; say in one
   line which one is used, or that assets will be code-only.
2. **Intake** (on demand; ask in one message, skip what is known; in Claude Code: AskUserQuestion):
   screens (required); what the app does and for whom (1–2 sentences); inspiration (optional); real proof
   (optional); logos to show (optional); brand colours, font and logo, or "use the app's"; targets (App Store,
   Play, web) and how many images (default 6 per store); languages.
3. **Understand the app** from its screens: the core promise, the 3–6 strongest features as benefits, the hero
   screen, the category and audience.
4. **Storyboard** (`copywriting.md`): a table, one row per image: job, headline, small line, screen shown, extra
   visual, proof, alt text (Play) or label (PWA). 1 hooks, 2 explains, 3 proves or gives a second benefit, then one
   benefit each, the last builds trust. Run the copy checklist (`copywriting.md` §9). **On demand: wait for
   approval.**
5. **Directions.** With inspiration: extract its design system the way `styles/*/design.md` were written (panels,
   palette, fonts, layout, decoration) and apply it to this app and copy, never its content. Without: pick the 3
   best-fitting styles from `STYLES.md` that differ in **structure and in what the hero is** (most open without a
   phone). Build **only image 1** in each (for `web + PWA` scope: the `og` image), side by side on one page. On
   demand the user picks or mixes; in a run, pick and record why. Never build three full sets.
6. **Assets** (`assets.md`): the real screens, or a clean HTML redraw when they look rough (same features, fictional
   data, the chosen style around it); generated people, hands, mascots, products and scenery; everything else in
   code. Log every generated file in `assets/prompts.md`.
7. **Build** (`build.md` + the chosen `design.md`): one page per ratio; panels at the target's ratio; headlines
   placed per line with measured widths; real screens in frames; landscape targets per `build.md` §10.
8. **Check, then export.** Run the style's fidelity checklist and the copy checklist. Look at every image at
   thumbnail size (portrait ≈ 230 px wide, `og` 300 px): headline readable, hero clear. Export each target with
   its preset. Deliver a preview page with every image in a row, a folder per target with `01.png`, `02.png`, …,
   `alt-text.txt` for Play, `labels.txt` for PWA.
9. **Wire web images in** (app runs, and on demand when the app's repo is at hand): `build.md` §11.
10. **Revise** what is asked; keep copy, style and assets consistent; re-export after every change.

## Rules

- **Copy before design.** On demand, never design an unapproved storyboard; in a run, the recorded storyboard is
  the contract for the set.
- **Real proof only.** Never invent ratings, reviews, user counts, press or awards.
- **The real UI is never redrawn by AI.** A redraw is HTML/CSS of the same screens with fictional data.
- **Keep the brand colour.** The palette comes from the app (icon, main accent); a style gives layout, type and
  decoration.
- **Frame per image:** none (UI cards on their own), a soft frame (rounded screen, soft bezel, gentle shadow), or a
  real frame PNG only when a physical device is the point (hand-held, tilted hero). Never a hand-drawn "realistic"
  phone.
- **A style is its structure, not its colours.** Take its DNA and compose fresh for each app; when making sets for
  several apps, give each a structurally different style and its own type voice (no shared headline helper).
- **3D only for things that are 3D**; **never invent a mascot** the app doesn't have; people only if the app is
  about people.
- **No prices on store images**, no alpha, every store's rules (`copywriting.md` §7).
- **Generated images match the storyboard** (pose, clothing, colours); regenerate rather than settle.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll design first and write the headlines after" | The words decide installs. Storyboard first. |
| "A 4.8 rating would look great here" | Only proof the user gave. None in a run unless RULES.md has it. |
| "The old screenshots look rough, I'll have the image model redo the UI" | Redraw in HTML/CSS with fictional data, or use the screens as they are. |
| "I'll export the iPhone page at the Play preset too" | Different ratio: ~18% gets cropped. One page per ratio. |
| "I'll just centre the phone in the OG image" | A wide frame needs a wide composition (`build.md` §10). |
| "One more generation won't hurt" (in a run) | Count it against the RULES.md cap; at the cap, code-only. |
| "I'll put the model ID I remember in the command" | List the provider's models and pick the newest; IDs change often. |
| "The images are done, the OG tag can point at localhost" | Absolute URL from the configured public base URL, checked in e2e. |
