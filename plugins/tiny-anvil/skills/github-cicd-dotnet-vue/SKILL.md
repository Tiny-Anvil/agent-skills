---
name: github-cicd-dotnet-vue
description: Use when setting up or changing GitHub Actions for a .NET API + Vue.js app — PR build/test gates, security scanning, licence checks, Dependabot, and building versioned container images (single or multi-arch) and publishing them to GHCR or another registry from a GitHub release — or when a gate silently stopped running, a pipeline is green but the image is wrong, or a secret might leak into an image or a log.
---

# GitHub CI/CD for .NET + Vue

## Overview

Two stages here, a third in its own skill:

| Stage | Trigger | What it proves or does | Where |
|---|---|---|---|
| **Gates** | `pull_request` → main, `push` main, `workflow_dispatch` (+ weekly for security) | it builds, tests pass, no bypass in the artifact, no known-vulnerable dependency | this skill |
| **Delivery** | GitHub **release** (prerelease or release) | one immutable, versioned image in the registry | this skill |
| **Deployment** | a GitOps PR, a deploy job, or the owner's own mechanism | the environment runs that image, verified on the environment | deploying-container-images |

## Shared or standalone (chosen at setup)

| Mode | The app repo gets | Pick it when |
|---|---|---|
| **Shared** (default) | thin callers (`templates/shared/`) of the reusable workflows in [Tiny-Anvil/workflows](https://github.com/Tiny-Anvil/workflows), pinned `@v1` | several apps should get the same fix at once |
| **Standalone** | the full workflows copied in (`templates/*.yml`) | the app must not depend on another repo, or needs heavy changes to a gate |

Both run the same gates. Shared callers pin a major tag (`@v1`) or a commit SHA, never `@main`, grant each called
workflow exactly the permissions its header lists, and pass secrets explicitly (no `secrets: inherit`).

Templates: `templates/shared/{ci,security,image}.yml` (shared mode); `templates/build-dotnet.yml`,
`build-frontend.yml`, `security.yml`, `license-check.yml`, `build-image.yml` (standalone); in both modes
`templates/dependabot.yml`, `templates/Dockerfile` and `templates/dockerignore` (copy it as `.dockerignore`).
Replace `<App>` / `<Org>` placeholders (`<Org>`: only the prefix the owner gave at setup, else drop it with its dot;
see running-autonomous-app-builds/house-stack.md → Repo layout).

## Gates (every project, from the walking skeleton on)

| Workflow | Steps |
|---|---|
| `build-dotnet.yml` | restore → **Release** build → assert `DevBypassAuthenticationHandler` is **absent** from the Release assembly → `dotnet test` (Debug; Testcontainers uses the runner's Docker) |
| `build-frontend.yml` | `pnpm install --frozen-lockfile` at the root → lint → `test:run` → build (`vue-tsc` included) → assert a production build with `VITE_AUTH_BYPASS=true` **fails on the guard** (check the message, not just the exit code) |
| `security.yml` | NuGet `--vulnerable --include-transitive` per project, test projects included (**parse the output; the exit code is always 0**), `pnpm audit --audit-level=high`, CodeQL (csharp + javascript-typescript, `build-mode: none`), Trivy (filesystem: secrets + misconfig + vulnerabilities); also on a **weekly cron** |
| `license-check.yml` | NuGet and npm licences against an allow-list; report-only until the first report is reviewed, then enforce |
| `dependabot.yml` | nuget (root, for Central Package Management), npm (root), docker, github-actions; weekly; minor/patch grouped with a catch-all group **last**; majors and security updates ungrouped; private-feed packages ignored |

Apps without auth (no bypass to guard) drop the two bypass assertions; record that in RUN.md → Decisions.

Rules:
- **A gate that does not run is worse than none**, because everyone believes it does. Check the `pull_request`
  trigger is on, and see a red run once (below).
- Least-privilege `permissions` per workflow and per job; `contents: read` by default; `packages: write` only in
  delivery; `security-events: write` only for CodeQL; `id-token: write` only where OIDC login happens.
- **Never** `pull_request_target`, `write-all`, secrets in `run:` lines, or `${{ github.event.* }}` expanded inside a
  shell script (pass it through `env:` and quote it).
- Pin GitHub's own actions (`actions/*`, `github/*`) to a major (`actions/checkout@v7`); pin every third-party action
  to a full commit SHA with its version as a comment (`docker/login-action@<40-char sha> # v4.8.0`), since a tag
  can be moved to other code. Dependabot's `github-actions` ecosystem keeps both current.
- **Private NuGet feed:** keep the source key in `nuget.config`; in CI, credit it with
  `dotnet nuget update source <key> --username ... --password "$TOKEN" --store-password-in-clear-text` from a repo
  secret; in Docker, pass the token as a build secret (`--secret id=nuget`) in a discarded stage, never as a
  build-arg of a published layer.
- After writing a gate, **prove it can fail**: push a branch with a deliberate failure (a failing test, the bypass
  type left in) and see the run go red, then revert. Record both run URLs in the increment.

## Delivery

`templates/build-image.yml` (standalone) or `templates/shared/image.yml` (shared):
- Trigger `release: [released, prereleased]` + `workflow_dispatch`.
- Tag `vX.Y.Z[-alpha.N]` for a single-image app; `<component>/vX.Y.Z` when one repo ships several images.
- Prerelease → `:<version>` and `:dev`; release → `:<version>` and `:latest`. **Deployments reference
  `:<version>`**, never `:dev`/`:latest` (a moving tag cannot be rolled back and does not redeploy).
- `--build-arg VERSION=<version>` → the Dockerfile bakes it into the API (`APP_VERSION`) and the SPA
  (`VITE_APP_VERSION`), so the deployed build can be identified.
- **`.dockerignore` must exclude `**/bin` and `**/obj`** (not just `bin/`): otherwise a local restore's
  `project.assets.json` is copied over the image's own restore and the cross-platform publish fails (NETSDK1047).
- **Platforms** from setup (`linux/amd64`, `linux/arm64` or both). The `templates/Dockerfile` build stages run on
  `$BUILDPLATFORM` and cross-compile with `-a $TARGETARCH`, so QEMU only emulates the small final stage.
- **Registry:** GHCR with `GITHUB_TOKEN` (`packages: write`) by default. Another registry (ACR, Docker Hub, ECR):
  log in with OIDC where the registry supports it (`azure/login` + `az acr login`, `aws-actions/configure-aws-credentials`),
  otherwise a scoped token as a repo secret. Never a long-lived admin password.
- **Self-hosted runners** (e.g. a native arm64 box) only for private repos: a self-hosted runner must never run
  fork PRs.
- A new GHCR package is private by default. A cluster then needs a pull secret, or the owner makes the package
  public. Either is the owner's call.

Creating a release is how the run delivers: `gh release create vX.Y.Z-alpha.N --prerelease --generate-notes`
(allowed by default for the test environment). A full release is a review checkpoint. Release notes carry no AI
attribution (house-stack.md → Git).

Then hand over to deploying-container-images.

## Verifying a Delivery

```bash
gh run list --workflow build-image.yml -L 3                 # the run for this release is green
docker manifest inspect ghcr.io/<owner>/<repo>:<version>     # the tag exists, with every requested platform
docker run --rm -e ... ghcr.io/<owner>/<repo>:<version>      # optional: boots, /api/v1/health 200, version == <version>
```

## Red Flags

| Thought | Reality |
|---|---|
| "The workflow file exists, so PRs are gated" | Check the trigger and see a red run once. |
| "`dotnet list package --vulnerable` exited 0, so we're clean" | It always exits 0. Parse the output. |
| "`uses: some-vendor/action@v4` is pinned" | A tag can be moved; pin a third-party action to its commit SHA. |
| "Tag it `:latest`, it's simpler" | Pin the version; a moving tag is neither a deploy nor a rollback. |
| "I'll add the token as a build-arg in the final stage" | Only as a build secret in a discarded stage, never in a published layer. |
| "Pipeline green, image delivered, so it's deployed" | Delivery is not deployment: deploying-container-images → Verifying a deploy. |
| "Self-hosted runner for this public repo" | Never: a fork PR would run code on your machine. |
