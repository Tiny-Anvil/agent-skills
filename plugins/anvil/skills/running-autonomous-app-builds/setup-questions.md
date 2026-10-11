# Setup questions

Ask them (in Claude Code: AskUserQuestion) in two rounds of up to four questions, then the follow-ups that apply.
Put the recommended option first. Offer only what this session can actually do. Record every answer verbatim in
`data/run/docs/RULES.md`. What `house-stack.md` or the project's CLAUDE.md already decides is not asked: state it
in the setup summary instead ("following house-stack: .NET 10 minimal API, Vue 3 + Tailwind v4, one image...").

## Round 1: what gets built and where it runs

| Header | Question | Options |
|---|---|---|
| Hosting | Where does it run? | **Kubernetes via GitOps** (image to a registry, a PR bumps the tag in a GitOps repo; Argo CD / Flux syncs) · **Azure Container Apps** (registry + a deploy job with OIDC) · **Other / your own** (the owner names the mechanism) · **Local only** (compose; CI written, nothing delivered) |
| Repo | Where does the code live? | **New GitHub repo** (the run creates it; private; needs `gh` auth with repo scope for that owner) · **Existing repo** (owner names it; the run works on a branch) · **Local git only** (no remote; workflows written but not run) |
| Auth | How do users sign in? | **OIDC provider** (Entra ID, Logto, Keycloak, Auth0, ...; the owner registers the app) · **None yet, behind a seam** (a picker now, a provider later) · **None** (public, or only behind an access proxy) |
| Quality | What bar should it aim for? | **Production-ready** (house-stack security posture, every test automated) · **Polished internal tool** · **Working prototype** (happy path; security gates still apply) |

## Round 2: how the run is governed

| Header | Question | Options |
|---|---|---|
| Deploy | How far may it deploy on its own? | **Test env via PR** (it opens the deploy PR; you merge) · **Test env fully** (it may merge its own test deploy PR and verify) · **Images only** (prereleases build images; no deploy change) · **Nothing remote**. Higher environments always stop for you. |
| Stop rule | When does the run end? | **Completion + cap** (the brief's tests pass and the test env is verified, or the cap is reached) · **Completion conditions** · **Budget cap** (keep improving until $X is spent; needs the driver's wallet) · **Time cap** |
| Reviews | Where should it pause for you? (multi-select) | **Brief approval** · **Walking skeleton** (end to end + CI green) · **Midpoint** · **Final candidate** · **None** |
| Agents | How should the work be split? | **Lead + 1-2 helpers** (API / frontend) · **Lead alone** (cheapest) · **Lead + role workers** (API, FRONTEND, INFRA) · **+ workflows** (scripted parallel fan-out; explicit opt-in; costs the most) |

Loop, as a follow-up or a fifth question:

| Loop | What brings the lead back when it ends a turn? | **Detached driver** (`kickoff-template.md`; survives the terminal) · **A loop in this session** (Claude Code: `/loop`) · **None** |

## Follow-ups (only when they apply)

- **Budget or time cap:** "How much?" (dollars, or an end time).
- **Containers** (ask whenever the app has a web frontend): "API and frontend in one container, or separate?"
  Recommend from the shape of the app, recommended option first:
  - **One container** (default): the SPA is built into the API's `wwwroot/` and served from the same origin.
    Pick it when this API serves only this frontend and both ship together. One image, one version, one
    deployment, no CORS, cookies and CSP stay same-origin, half the CI and deploy files.
  - **Separate containers** (SPA in nginx/Caddy, API on its own): pick it when several clients share the API
    (a native/TV app, an admin app, a public API), when the frontend releases on its own cadence, or when
    the frontend should be served from a CDN/static host. Costs: CORS or a path-routing ingress
    (`/api` → API, `/` → SPA), two images and tags to keep compatible, two deployments per environment, and
    release tags per component (`<component>/vX.Y.Z`).
  Record the choice in RULES.md; it decides the Dockerfile(s), the image workflow and the deploy files.
- **CI workflows:** **Shared** (thin callers of the reusable workflows in Tiny-Anvil/workflows, pinned `@v1`; one fix
  reaches every app) · **Standalone** (full workflows copied into the repo; no outside dependency). See
  github-cicd-dotnet-vue → Shared or standalone.
- **Image platforms:** `linux/amd64`, `linux/arm64` (e.g. Raspberry Pi or Graviton nodes), or both.
- **Registry:** GHCR (default, `GITHUB_TOKEN`) or another (ACR, Docker Hub, ECR): name and how CI logs in.
- **New repo:** name, owner (user or org), visibility (private by default).
- **GitOps hosting:** the GitOps repo (URL or local path), its layout (where this app's base and per-environment
  overlays go; Kustomize or Helm values), the environments (e.g. test + prod), hostnames, how secrets are made
  (Sealed Secrets, SOPS, External Secrets, ...), and who creates the database and its credentials. The run
  references names only. Read the GitOps repo's own CLAUDE.md/README first.
- **Azure Container Apps:** resource group, registry, Container App name, GitHub Environment name. The run never
  creates Azure resources or federated credentials; it writes the Bicep/scripts and stops at a review.
- **Auth:** the variable **names** for authority / audience / client id, and where the values live. The owner
  registers the app with the provider.
- **Private package feeds:** which feed, which source key in `nuget.config`, how CI authenticates (a scoped token
  as a repo secret; never committed).
- **Commit identity:** confirm `git config user.name` / `user.email` for this repo.

## Environment check (step 2, before the run)

Record versions in RUN.md → Environment. Anything missing is fixed now or the plan is changed now.

```bash
dotnet --version                 # 10.x (global.json pins the SDK)
node --version; pnpm --version   # node 22, pnpm from packageManager
docker version --format '{{.Server.Version}}'   # Testcontainers and compose need a running daemon
docker buildx ls                 # a builder for the chosen image platforms
npx playwright --version         # or a system Chromium path for e2e captures (see dotnet-vue-test-harness)
gh auth status                   # only with a GitHub remote: repo, workflow, packages scopes
git config user.name; git config user.email
kubectl config get-contexts      # only for GitOps hosting: read-only deploy checks
```

## Not asked: derived or the builder's call

- Framework versions, layout, libraries, security baseline, CI shape: `house-stack.md` and the project's CLAUDE.md.
- The API design, data model, UI design and scope details covered by the brief's "the real task".
