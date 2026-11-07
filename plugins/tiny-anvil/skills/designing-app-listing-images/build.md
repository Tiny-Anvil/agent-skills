# Build recipes

Everything is one HTML file: a fixed-size **stage** that holds the panels side by side, built with HTML/CSS/SVG (plus Three.js only for real 3D). Export screenshots each panel separately.

## 1. Stage & panels

```html
<div id="stage" style="position:relative;width:{W}px;height:{H}px;background:{canvas}">
  <div class="panel" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px;border-radius:{r}px;background:{bg}"></div>
</div>
```
```css
.panel{position:absolute;overflow:hidden}
.abs{position:absolute}
```
- Take the geometry from the chosen `design.md`.
- Place every element in **stage coordinates** with a helper `box(panel, x, y, w, h, html, css)` that subtracts the panel's origin. Elements that cross a panel seam are added to each panel at the same stage position; each panel clips its own part.
- Keep each panel at its target's ratio (`scripts/sizes.json`; App Store iPhone ≈ 0.46). Design at the canvas size and scale up at export.

## 2. Text that fits exactly

Place each headline line, or each word when words are styled differently, with SVG `textLength`, so the width is exact whatever the font metrics are:
```js
// x, baseline, cap height in px, weight, text, target ink width
function T(parent, x, base, cap, weight, txt, w, fill, fam='Inter') {
  const fs = cap / CAP[fam];                 // CAP = measured cap-height ratio of the font
  const h = fs * 1.4;
  parent.insertAdjacentHTML('beforeend',
    `<svg class="abs" style="left:${x-4}px;top:${base-fs*1.05}px" width="${w+8}" height="${h}">
       <text x="4" y="${fs*1.05}" font-family="${fam}" font-weight="${weight}" font-size="${fs}" fill="${fill}"
             textLength="${w}" lengthAdjust="spacingAndGlyphs">${txt}</text></svg>`);
}
// measure CAP once fonts load: ctx.font = '700 100px Inter'; CAP.Inter = ctx.measureText('H').actualBoundingBoxAscent / 100
```
- Wait for `document.fonts.load(...)` before laying out any text.
- Load Google Fonts with only the weights you use.
- Tricks used by the styles:
  - **Mixed weights or fonts:** one `T()` per word.
  - **Gradient text:** an SVG `linearGradient` fill.
  - **Softer rounded type:** a same-colour stroke with `stroke-linejoin="round"`.
  - **Narrowed type:** `transform="scale(0.92 1)"`.
  - **Glow:** `filter: drop-shadow(0 0 6px rgba(255,255,255,.5))`. Keep it tight.

## 3. Device frames

Choose per screenshot (see SKILL.md Rules): **no frame**, **soft frame**, or **realistic frame**.

**Soft frame** (the default when a device helps): the screen with large rounded corners, a soft light bezel and a gentle shadow, with no metal edges, buttons or glare.
```css
.soft{border-radius:56px;padding:10px;background:#fff;box-shadow:0 0 0 1px rgba(0,0,0,.06),0 30px 60px rgba(0,0,0,.10)}
.soft .screen{border-radius:46px;overflow:hidden}
```
**Realistic frame** (only when a physical device makes sense):

Use **real device-frame PNGs** with a transparent screen hole. The free set is fastlane frameit-frames:
`https://raw.githubusercontent.com/fastlane/frameit-frames/gh-pages/latest/<Device Name>.png`, with screen offsets in `latest/offsets.json`.

Useful frames:
- `Apple iPhone 16 Pro Black Titanium` (also White / Natural / Desert);
- `Apple iPhone 16 Pro Max Black Titanium`;
- `Apple iPhone 13 Midnight` (notch style).

Measure the screen hole (the first transparent pixel run in the middle row and middle column), then:
```html
<div class="abs" style="left:..;top:..;width:{frameW*k}px;height:{frameH*k}px">
  <img src="screen.png" style="position:absolute;left:{sx*k}px;top:{sy*k}px;width:{sw*k}px;height:{sh*k}px;border-radius:{sw*k*.13}px">
  <img src="frame.png" style="position:absolute;inset:0;width:100%;height:100%">
</div>
```
- **Frame colour:** recolour only the coloured rim pixels (keep the luminance, swap the hue) to match a brand.
- **White outline** (a common style touch): stacked `drop-shadow(±1.5px 0 0 #fff) drop-shadow(0 ±1.5px 0 #fff)`.
- **The user's real screenshot is the screen.** Crop away the status bar only if it's ugly.

## 4. Tilted phones

| Look | Method |
|---|---|
| Rotated flat in the image plane | Rotate the whole frame + screen group with `transform:rotate(deg)` |
| Leaning back (wider at the bottom) | Compose frame + screen on a canvas, then keystone-warp it row by row from a homography solved from the target corners. Sharper than CSS 3D at small sizes. |
| A real 3D angle | Three.js with a real phone model (the free iPhone 15 Pro GLB from github.com/YUZU-Hub/appscreen, MIT). Put the screen on an overlay plane; pose it with OpenCV `solvePnP` against 4 target corners, or set angles by eye. |

When matching the user's inspiration: pick 3 landmarks on the screen (the time, the notch or island, the battery), solve scale, rotation and offset, and draw the screen content through the inverse transform.

## 5. Screen on a generated phone (AI hand or phone image)

1. Generate the phone with a flat `#00FF00` screen (`assets.md`).
2. Find the green quad: mask `g > 180 & r < 90 & b < 90`, then take the 4 corners of the largest blob (`cv2.approxPolyDP`).
3. Warp the app screenshot into that quad (`cv2.getPerspectiveTransform` + `warpPerspective`), with rounded-corner masking; or use a CSS `matrix3d` built from the homography.
4. Composite: hand image, then the warped screen inside the green area, then edge despill (`scripts/chroma_key.py`).

## 6. Glass, cards, pills, stickers

```css
.glass{background:linear-gradient(180deg,rgba(255,255,255,.34),rgba(255,255,255,.1) 60%,rgba(255,255,255,.2));
  border:1.5px solid rgba(255,255,255,.72);backdrop-filter:blur(8px);
  box-shadow:inset 0 2px 6px rgba(255,255,255,.55),0 8px 22px rgba(0,60,140,.14)}
.card{background:#fff;border-radius:22px;box-shadow:0 14px 34px rgba(0,0,0,.10)}
.sticker{filter:drop-shadow(3px 0 0 #fff) drop-shadow(-3px 0 0 #fff) drop-shadow(0 3px 0 #fff) drop-shadow(0 -3px 0 #fff) drop-shadow(0 6px 10px rgba(0,0,0,.18))}
```
- Pull important UI out of the phone: the card is wider than the screen and overlaps the frame.
- Blurred colour meshes for backgrounds: sample a small colour grid, upscale it on canvas, then blur by about 25 px.

## 7. Real 3D (only for things that are 3D)

- Three.js `r149` from `https://cdn.jsdelivr.net/npm/three@0.149.0/build/three.min.js`.
- Render offscreen at 2×, copy into a canvas, then convert to an `<img>` (`toDataURL`) so it downsamples cleanly.
- Studio environment: a PMREM-generated texture from a dark sphere with 3–4 bright plane "softboxes".
- Chrome: `metalness:1, roughness:.13, clearcoat:.6`. Matte plastic: `roughness:.4, metalness:.05`.
- Organic characters, fur and plush: use AI generation instead (`assets.md`).

## 8. Check against the user's inspiration (when they ask to match one)

- Make the compare page (side by side / slider / overlay) and crop each panel next to the inspiration at 2×.
- Fix the biggest difference first. Repeat until every element is within a few px.
- Judge at thumbnail size too: shrink the whole set to about 1400 px wide.

## 9. Export

Sizes live in one place, `scripts/sizes.json`; `node scripts/export.js --list` prints the presets with their spec
links. Export with a preset (or `WxH`):
```bash
node scripts/export.js listing.html out/ios-6.9 ios-6.9
node scripts/export.js listing-play.html out/play-phone play-phone
node scripts/export.js listing-web.html out/og og
```
- It screenshots every `.panel` separately at high resolution, centre-crops to the exact ratio (warns if more than
  1% gets cropped) and resamples to the exact size. Output is RGB PNG, **no alpha**; `--jpeg` writes quality-95
  JPEG. Corners come out square; `--keep-radius` keeps the design's rounding.
- **One layout per ratio.** Both iPhone presets share ≈ 0.46, so one page exports to both. Play (9:16), iPad, and
  every landscape target get their own page: exporting a 0.46 panel at 9:16 crops ~18% off top and bottom.
- Needs Playwright with Chromium. If `chromium.launch()` fails (e.g. linux-arm64), see dotnet-vue-test-harness →
  Browsers.

**App Store:** JPEG or PNG, no alpha, 1–10 per size class. `ios-6.3` is required; `ios-6.9` recommended (without
it, `ios-6.5` is required); `ipad-13` if the app runs on iPad. Smaller classes are scaled from these.

**Google Play:** JPEG or 24-bit PNG, no alpha; short side 320–3840 px, long side ≤ 2× short; 2–8 per device type;
**alt text** ≤ 140 characters each. Phone 9:16 (at least 4 at ≥ 1080 px for promotion eligibility); tablets at
least 4; the `play-feature` graphic is required (key content centred, no device imagery). Google prefers real UI
without frames or added text: offer a "clean" variant (screen, minimal headline, no frame).

**Web:** `og` is one image per site (or per shared page), readable at 600 px wide, title text inside the centre
1000 × 530. `pwa-narrow` and `pwa-wide` are the install-dialog screenshots: the real UI, full-bleed, a short
caption at most, 1–5 of each. `hero` is on demand only.

## 10. Landscape images from a portrait style

The 18 styles describe portrait store panels. For `og`, `pwa-wide`, `play-feature` and `hero`, take the style's
**type pairing, palette logic, decoration vocabulary and device treatment**, and compose fresh for the wide frame:
- headline on the left third or two-fifths, the hero (screen, card stack, object) on the right; never centre a
  phone in a wide frame with empty sides;
- one headline, no small line on `og` and `play-feature`; the app name or logo is visible;
- devices: a desktop or laptop viewport of the web app (the `desktop` capture) for web targets; a phone only when
  the app is used on phones;
- check at thumbnail size: `og` at 300 px wide, `play-feature` at 512 px wide.

## 11. Wiring web images into the app (app runs)

Store sets stay files. Web images ship with the app (rule: `running-autonomous-app-builds/house-stack.md` → PWA):
- copy `og.png` and `pwa-narrow-NN.png` / `pwa-wide-NN.png` into the SPA's `public/listing/`;
- vite-plugin-pwa manifest: a `screenshots` entry per file with `src`, `sizes`, `type: "image/png"`,
  `form_factor` (`narrow` / `wide`) and a `label` (the caption, also the alt text);
- `index.html`: `og:title`, `og:description`, `og:image` (+ `og:image:width`/`height`), `og:url`,
  `twitter:card` = `summary_large_image`. `og:image` and `og:url` are **absolute**: build them from the app's
  configured public base URL, never a hard-coded host, so each environment points at its own origin;
- check (dotnet-vue-test-harness → e2e): every manifest screenshot and the `og:image` URL return 200 with an image
  content type on the running stack.
