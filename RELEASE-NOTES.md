# Release notes

## 0.2.0 (unreleased)

- **Listing images** (new skill, designing-app-listing-images): App Store / Google Play screenshot sets, the
  link-preview image and PWA install screenshots from the app's real screens; copy first, 18 styles, three
  directions, exports from one list of sizes (`sizes.json`), no baked-in image model IDs. On demand, or in the app
  run's finish pass when chosen at setup, where web images are wired into the app and checked in e2e. Based on
  aso-shots by ceorkm (MIT).
- **Store pages** (new skill, designing-game-store-pages): the Steam and itch.io kit from the real game. Capsules
  and library art composed from key art staged and rendered in the game (`store_key_art.gd`, any size, no HUD),
  gameplay screenshots from tick-exact replays (`capture.sh`), a gameplay trailer cut by recipe (`cut_trailer.py`:
  Valve's format spec, loudness, black and frozen stretches), icons and the AI-disclosure draft (which states an
  AI-agent-built game as such; the owner decides). Valve's capsule text rules built in; AI key art only after the
  owner's yes, each time. On demand, or in the game run's finish pass when chosen at setup. Steam and itch.io sizes
  join `sizes.json`; `export.js` gains `--panel` and `--alpha`.
- godot-scenario-harness: `--write-movie` ignores `--resolution` and the 4.8 quality key is `video_quality`
  (measured); paths resolve against the project, not the shell; a recording that cannot be written now exits 6
  instead of 0; `--hide-group=a,b` keeps debug overlays out of captures.
- **Commands:** `/anvil:listing-images`, `/anvil:store-page`.

## 0.1.0

First public version.

- **App track** (6 skills): running-autonomous-app-builds, writing-app-briefs, iterating-with-verified-increments,
  dotnet-vue-test-harness, github-cicd-dotnet-vue, and the new deploying-container-images (GitOps PR, Azure
  Container Apps or other, split out of the CI/CD skill).
- **Game track** (7 skills): running-autonomous-game-builds, writing-game-briefs, iterating-with-look-checkpoints,
  godot-scenario-harness, building-blender-assets-by-script, sourcing-and-processing-game-audio, tripo-cli.
- **Commands:** `/anvil:build-app`, `build-game`, `write-brief`, `resume-run`, `deploy`.
- Lessons from the first full app run folded in: e2e on a throwaway compose project, per-copy image tags, SSE with
  a polling fallback for proxies that hold streams back, preview copies through a tunnel, a configuration reference
  kept current, owner messages during a run, local-only runs, Aspire for the dev loop.
- CI in two modes: **shared** (thin callers of the reusable workflows in Tiny-Anvil/workflows, `@v1`) or
  **standalone** (full copies). A `.dockerignore` template; every workflow template passes actionlint in CI.
- Steps that name Claude Code tools state their intent first, so other agents that read SKILL.md can follow them.
- House stack: sign-in in production is a hosted OIDC provider (Logto Cloud, a tenant per product, social
  sign-in only, custom domain); production for real users moves from a home server to a small cloud server.
- Code names: `<Org>` is an optional prefix the owner gives at setup, never derived from the account email or an
  employer; without one the app name is the root (`Rummikub.Api`).
