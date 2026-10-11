# App builds

Six skills for building a web application autonomously, from an idea to a finished, verified and (optionally)
deployed result: a .NET 10 minimal API with EF Core and Postgres, a Vue 3 single-page app, tests through the real
stack, GitHub Actions gates, a versioned container image and a deploy you can roll back.

The workflow is evidence-driven. Setup questions are asked once and written into a rules file. The brief turns
every requirement into a numbered test with a threshold and an evidence file. The run then works increment by
increment: run the real stack, test, capture every screen at desktop and phone width, open the captures, name the
largest defects and fix them. It stops only when the recorded stop rule holds, and `final/` always holds the best
verified build.

## How the skills fit together

```
running-autonomous-app-builds
  1. Setup (once):   store the request -> setup questions -> environment check -> scaffold.sh -> RULES.md
  2. Brief:          writing-app-briefs -> BRIEF.md (tests with IDs, thresholds, evidence files)
  3. Run (silent):   iterating-with-verified-increments
                       walking skeleton (API + DB + SPA + CI, one real request end to end)
                       -> central user flow
                       -> run -> test -> capture -> inspect -> fix largest defects -> freeze increment I###
                       -> repeat
                          |  API / guard / SPA / e2e tests, captures, load, previews: dotnet-vue-test-harness
                          |  CI gates, image to the registry on a release:             github-cicd-dotnet-vue
                          |  image version to an environment, verified there:         deploying-container-images
                       pause only at the configured review checkpoints and deploy gates
  4. Stop rule:      completion conditions / budget cap / time cap (from RULES.md)
                     -> finish pass (README, configuration and feature docs, fresh clone) -> final/QA.md -> report
```

## The skills

| Skill | Use it when | Key files |
|---|---|---|
| `running-autonomous-app-builds` | Building a whole web app or large feature end to end, unattended, or resuming such a run | `SKILL.md`, `house-stack.md` (the stack defaults), `setup-questions.md`, `rules-template.md`, `kickoff-template.md` (incl. detached driver), `scaffold.sh` |
| `writing-app-briefs` | Turning an idea into the acceptance contract another session builds from, with measurable tests | `SKILL.md`, `brief-template.md` |
| `iterating-with-verified-increments` | Building or polishing anything whose correctness must be shown by running it; before calling it done | `SKILL.md`, `review-checklist.md`, `RUN.md`, `INCREMENT.md`, `QA.md` |
| `dotnet-vue-test-harness` | Tests through the real stack: Testcontainers, real-JWT scope tests, guard tests, Vitest, Playwright flows and captures, load, preview copies | `SKILL.md`, `templates/playwright.config.ts`, `capture.spec.ts`, `e2e.sh`, `load.mjs`, `k6-smoke.js`, `preview.sh`, `preview.compose.yml` |
| `github-cicd-dotnet-vue` | PR gates, security and licence checks, Dependabot, and the release-triggered image build | `SKILL.md`, `templates/shared/` (callers of [Tiny-Anvil/workflows](https://github.com/Tiny-Anvil/workflows)), standalone `build-dotnet.yml`, `build-frontend.yml`, `security.yml`, `license-check.yml`, `build-image.yml`, plus `dependabot.yml`, `Dockerfile`, `dockerignore` |
| `deploying-container-images` | Getting an image version onto an environment (GitOps PR, Azure Container Apps, other) and proving it runs there | `SKILL.md`, `templates/gitops/bump.sh`, `gitops/base-deployment.yaml`, `gitops/overlay-kustomization.yaml`, `azure-container-apps/deploy.yml`, `verify-deploy.sh` |

## The stack it builds

The defaults live in one file, [`house-stack.md`](../plugins/anvil/skills/running-autonomous-app-builds/house-stack.md). In
short:

- **API:** .NET 10 minimal API, one class per endpoint, `TypedResults`, FluentValidation that fails closed,
  ProblemDetails, scope-based authorization with any OIDC provider (or an identity seam when there is no login yet),
  EF Core + Npgsql with snake_case and migrations, security headers, rate limiting, Serilog, OpenAPI + Scalar in
  Development, Server-Sent Events for live updates, .NET Aspire for the local dev loop.
- **SPA:** Vue 3.5, Vite, TypeScript, Tailwind v4, Pinia + Pinia Colada, vue-router, vue-i18n, zod, PWA, runtime
  configuration from the API (one image for every environment).
- **Tests:** xUnit + Shouldly + Testcontainers, guard tests for the safety rails, Vitest + msw, Playwright at
  1440×900 and 390×844 against a throwaway copy of the composed stack, axe-core, load numbers.
- **Delivery:** one container image (SPA in the API's `wwwroot/`) by default, multi-arch, versioned from a GitHub
  release; deployments pin the version.
- **Repo hygiene:** Central Package Management, pnpm workspace, only `appsettings.example.json` committed,
  `docs/configuration.md` for every setting, feature docs per feature, Conventional Commits, no AI attribution.

Want a different stack? Fork and edit `house-stack.md` (see [Customising](#customising)). The skill structure does
not depend on .NET or Vue; the test-harness and CI templates do.

## Requirements

- **.NET 10 SDK**, **Node.js 22** with **pnpm** (via corepack), **Docker** with Compose v2.24+ (Testcontainers,
  the e2e copy and previews need a running daemon) and `buildx` for multi-arch images.
- **Playwright's Chromium** (`pnpm exec playwright install chromium`), or a system Chromium on linux-arm64.
- **git**, **bash**, **python3** (scaffold, scripts, the driver's wallet).
- Only with a GitHub remote: the **`gh` CLI**, authenticated with repo, workflow and packages scopes.
- Only for deploys: `kubectl` (GitOps, read-only checks) or the Azure CLI (Container Apps), and whatever the target
  needs. The owner creates secrets, identities and cloud resources; the run never does.
- Optional: **k6** for load tests (`load.mjs` works without it), **cloudflared** is pulled as a container by
  `preview.sh`, the **Claude Code CLI** for the detached driver.

## Quick start

In an empty directory (or an existing repo), after installing the plugin (see the [README](../README.md#installation)):

```
/anvil:build-app A planner for a sports club: members sign up for training slots, coaches see who is coming.
Phones first. Make it as good as you can.
```

The agent stores the request, asks the setup questions in two rounds (hosting, repo, auth, quality bar; deploy
gates, stop rule, reviews, agents), checks the tools, scaffolds `data/run/`, writes the rules and the brief, and
then runs until the stop rule holds. Resume with `/anvil:resume-run`.

## Where the run writes

`scaffold.sh <project-dir>` creates (never overwriting an existing file):

| Path | Contents | In git? |
|---|---|---|
| `data/run/docs/` | `RULES.md`, `BRIEF.md`, `KICKOFF.md`, `CONTRACT.md` (API contract), `ARCHITECTURE.md` (code card for helpers) | no |
| `data/run/prompts/` | every input as sent, verbatim and append-only | no |
| `data/run/increments/I###/` | one record per increment: evidence inspected, tests, anchored defects, captures | no |
| `data/run/final/` | the best verified build's evidence and `QA.md` | no |
| `data/run/qa/` | raw logs, test reports, load results | no |
| `data/run/RUN.md`, `DELEGATION.md` | run record (intent, decisions, history, feedback, final report); helper spawns | no |
| `docs/features/README.md` | index of the committed feature docs | yes |
| `.gitignore` | `data/`, build output, local settings files, `.env` | yes |

Plans, specs and run records stay out of the repo's `docs/` on purpose: `docs/` is for documentation that
describes the product, kept current in the same commit as the change.

## Customising

- **The stack and conventions:** [`house-stack.md`](../plugins/anvil/skills/running-autonomous-app-builds/house-stack.md). Keep the
  section names; other skills refer to them.
- **Setup questions and their options:** [`setup-questions.md`](../plugins/anvil/skills/running-autonomous-app-builds/setup-questions.md)
  (recommended option first).
- **Deploy gates and the defaults without rules:** the Deploy Gates and Stopping sections of
  [`running-autonomous-app-builds/SKILL.md`](../plugins/anvil/skills/running-autonomous-app-builds/SKILL.md).
- **Workspace layout:** [`scaffold.sh`](../plugins/anvil/skills/running-autonomous-app-builds/scaffold.sh).
- **Brief structure and the standard tests:** [`brief-template.md`](../plugins/anvil/skills/writing-app-briefs/brief-template.md).
- **Increment, run and QA records, the review checklist:** the `.md` files in
  [`iterating-with-verified-increments/`](../plugins/anvil/skills/iterating-with-verified-increments/).
- **CI, image and deploy templates:** the `templates/` folders of the three delivery skills.
- **A project's own rules always win:** its CLAUDE.md / AGENTS.md, `.claude/guidelines/` and `docs/features/`.
