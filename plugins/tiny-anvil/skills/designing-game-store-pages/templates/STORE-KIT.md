# Store kit: <GAME>

Made on <YYYY-MM-DD> from build <commit or version> with designing-game-store-pages. Rebuild from the sources in
git: `store/footage/*.json` (`capture.sh film`), `store/shots.json` (`capture.sh shots`), `store_key_art.gd`
(`capture.sh keyart`), `store/capsules.html` + `store/fonts/` (`export_kit.sh`), `store/trailer.json`
(`cut_trailer.py`). Outputs below are not in git.

## Steam (Steamworks → your app → Store Admin / Library Assets / Community / Trailers)

| File | Upload to | Size | Notes |
|---|---|---|---|
| `steam/steam-header.png` | Store Admin → Graphical Assets → Header Capsule | 920×430 | |
| `steam/steam-small.png` | … → Small Capsule | 462×174 | |
| `steam/steam-main.png` | … → Main Capsule | 1232×706 | |
| `steam/steam-vertical.png` | … → Vertical Capsule | 748×896 | |
| `steam/steam-page-bg.png` | … → Page Background (optional) | 1438×810 | |
| `screenshots/01.png` … | … → Screenshots | 1920×1080 | order as numbered; mark the all-ages ones |
| `steam/steam-library-capsule.png` | Library Assets → Library Capsule | 600×900 | |
| `steam/steam-library-header.png` | Library Assets → Library Header | 920×430 | |
| `steam/steam-library-hero.png` | Library Assets → Library Hero | 3840×1240 | no words |
| `steam/steam-library-logo.png` | Library Assets → Library Logo | ≤ 1280×720 | place it over the hero with the logo tool |
| `steam/steam-app-icon.jpg` | Community → App Icon | 184×184 | |
| `steam/steam-shortcut-icon.ico` | Community → Shortcut Icon | 256×256 | |
| `trailer/trailer.mp4` + `trailer/thumbnail.jpg` | Trailers | 1920×1080 | `trailer/trailer_report.md` all PASS |
| `AI-DISCLOSURE.md` | Content survey → Generative AI | | the owner submits it |

## itch.io (Edit game)

| File | Field | Notes |
|---|---|---|
| `itch/itch-cover.png` | Cover image | 630×500 |
| `screenshots/01.png` … (3–5) | Screenshots | the first five Steam screenshots |
| `trailer/trailer.mp4` | Gameplay video | upload to YouTube or Vimeo first; paste the link |

## Check

The kit check in `steam-rules.md`, with its result per line: <PASS / FAIL + why>.
Decisions (moments, views, logo, beats) and anything left open: RUN.md → Decisions, or below.
