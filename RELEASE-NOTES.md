# Release notes

## 0.2.0 (unreleased)

- **Listing images** (new skill, designing-app-listing-images): App Store / Google Play screenshot sets, the
  link-preview image and PWA install screenshots from the app's real screens; copy first, 18 styles, three
  directions, exports from one list of sizes (`sizes.json`), no baked-in image model IDs. On demand, or in the app
  run's finish pass when chosen at setup, where web images are wired into the app and checked in e2e. Based on
  aso-shots by ceorkm (MIT).
- **Command:** `/anvil:listing-images`.

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
