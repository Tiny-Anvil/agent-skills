# House stack (defaults)

The opinionated defaults this skill set builds with: .NET 10 minimal API, EF Core + Postgres, Vue 3 + Vite +
Tailwind, Playwright, GitHub Actions and one container image. They are a starting point, not a law:

- **The project wins.** Its `CLAUDE.md` / `AGENTS.md`, `.claude/guidelines/*` and `docs/features/*` override this
  file. Read them first.
- **Your house wins.** Fork the plugin and edit this file to make it your own defaults (see the repo README →
  Customising). Keep the section names; the other skills refer to them.

## Where things go

- **Plans, specs, briefs and run records are local working docs → `data/` (gitignored).** Never under `docs/`.
  Every run record lives in **`data/run/`** (rules, brief, kickoff, prompts, increments, QA, RUN.md). Add `data/`
  to `.gitignore` if it is not there.
- **Feature docs → `docs/features/<feature>.md`, committed, one per feature, updated in the same change.** Content:
  purpose, API endpoints (routes + scopes), data model, business rules, how to verify. Infrastructure counts as a
  feature (deployment, CI/CD, logging, configuration): resource inventory, runtime config, manual steps, how to
  verify. Keep `docs/features/README.md` as the index.
- **Conventions → committed.** The finish pass writes `CLAUDE.md` (and/or `AGENTS.md`) plus
  `docs/features/{endpoints,validation,error-handling,logging,configuration-and-secrets,database,testing,frontend}.md`
  and a `docs/code-review-guide.md`, so a reviewer can check the code against written rules. Every claim in them is
  checked against the code before it is committed.
- Guidelines/invariants → `.claude/guidelines/`; slash commands → `.claude/commands/`.

## Repo layout

```
<repo>/
  global.json                     # pins the .NET 10 SDK, rollForward latestPatch
  nuget.config                    # pins package sources (nuget.org + any private feed), <clear/> first
  Directory.Build.props           # net10.0, LangVersion latest, Nullable, ImplicitUsings
  Directory.Build.targets         # DEV_AUTH_BYPASS for Debug only (must be .targets, not .props)
  Directory.Packages.props        # Central Package Management; CentralPackageTransitivePinningEnabled
  package.json                    # pnpm workspace root: packageManager pnpm@10.x, pnpm.auditConfig
  pnpm-workspace.yaml             # src/apps/*, src/packages/*
  Dockerfile                      # one image: SPA stage + API stage + runtime (default; see setup-questions → Containers)
  docker-compose.yml              # Postgres (127.0.0.1 only) + the app image; ports and image tag overridable
  .env.example                    # every compose variable with its default
  src/apps/api/                   # <Org>.<App>.Api.csproj + .slnx
  src/apps/app/                   # Vue SPA (@<scope>/<app>-app), with its own .env.example
  src/aspire/                     # <Org>.<App>.AppHost + <Org>.<App>.ServiceDefaults (local dev loop)
  src/packages/                   # shared TS packages (e.g. an OIDC wrapper)
  src/tests/<Org>.<App>.Api.Tests/
  scripts/                        # aspire.sh, e2e.sh, load.mjs, preview.sh (one command each)
  docs/configuration.md           # every setting: default, env var, where to set it
  docs/features/                  # committed feature docs
  data/                           # gitignored: plans, specs, run records, screenshots
  .github/workflows/  .github/dependabot.yml  .github/scripts/
```

- Never put `Version=` in a `.csproj`: add `<PackageVersion>` to `Directory.Packages.props`, bare `<PackageReference>`
  in the project. Security pins of transitive packages go there too, with the advisory ID in a comment.
- Node 22 in CI and Docker; pnpm from the root `packageManager` field (`pnpm/action-setup` reads it).
- **Dependency audit in every increment**, test projects included:
  `dotnet list <project> package --vulnerable --include-transitive` per project (a vulnerable transitive package
  of a test-only dependency such as Testcontainers otherwise shows up only as a build warning) and
  `pnpm audit --audit-level=high`.

## Backend (.NET 10 minimal API)

- `Program.cs`: `builder.AddApi()` → `Build()` → `app.Configuration.ThrowIfPlaceholdersUnresolved()` (validate the
  **final** config, after Build) → `app.UseApi()` → migrate-on-startup (flag-gated) → seeds → `RunAsync()`.
  `public partial class Program;` for the test factory.
- **One class per endpoint**, `sealed class XxxEndpoint : IEndpoint` with `static abstract void Map(IEndpointRouteBuilder)`,
  in `Endpoints/<Feature>/`, next to its request record and validator. `Endpoints.cs` maps every endpoint by hand
  into versioned groups `api/v{version:apiVersion}/<feature>` (Asp.Versioning, URL segment) with `.WithTags()`.
  `.WithName("<ClassNameMinusEndpoint>")` on every route (a test relies on it).
- Handlers return **`TypedResults`** with explicit `Results<Ok<T>, NotFound, ValidationProblem>` unions.
- Business logic in `Services/<Feature>/` behind `I<Feature>Service`, registered scoped. Mapping via extension
  methods (`ToClientDto()`), no AutoMapper. JSON camelCase; enums as strings (`JsonStringEnumConverter`).
- **Authorization:** scope based, `resource:level` with `read < write < admin`, `system:admin` fast-pass. Constants in
  `Auth/Scopes.cs`; `.RequireScopes(Scopes.X)` on every endpoint (OR semantics), or `.RequireAuthorization()` /
  `.AllowAnonymous()` explicitly. Roles live in the database and are projected to claims by an
  `IClaimsTransformation` (cached ~60 s in `IDistributedCache`, evicted on every role change). Role labels map to
  scope bundles in a `RoleAssignmentMatrix`. Rule of thumb: **write sets up, admin tears down**.
- **Authentication:** JWT bearer from an `OidcProvider` section (`Authority`, `Audience`, `NameClaimType`,
  `RoleClaimType`), **`MapInboundClaims = false`**, throws at startup when enabled with an empty Authority/Audience.
  Any OIDC provider (Entra ID, Logto, Keycloak, Auth0, Zitadel). `IUserContext` populated by middleware
  (`oid` → `sub` → NameIdentifier). `GET /api/v1/me` + `POST /api/v1/me/bootstrap` provision the user; new users
  are `Pending`; `Authentication:InitialAdmins` breaks the first-admin deadlock.
- **No login yet?** Put identity behind one seam (e.g. an `ICurrentMember` resolved from a header set by a picker),
  so a real provider replaces the picker later without touching the features. Document it as a consistency guard,
  not security.
- **Dev auth bypass** (`Authentication:Enabled=false`) authenticates a synthetic principal from `DevAuth`. It is
  **compiled out of Release** (`#if DEV_AUTH_BYPASS`, constant from `Directory.Build.targets`), refuses to run outside
  Development without `AllowInsecureDevBypass=true`, and has **no allow-all fallback policy** (a 403 in dev is real).
- **Validation:** FluentValidation, auto-registered from the assembly; opt-in per endpoint with
  `.WithValidation<TRequest>()`, which **fails closed** when the validator is missing. Query-string bounds via a
  shared `QueryBounds` (max ids, max date span). Cross-record checks in the handler, same `ValidationProblem` shape.
- **Errors:** `AddProblemDetails` + `UseExceptionHandler` + `UseStatusCodePages` (RFC 9457); typed
  `IExceptionHandler`s map known exceptions (concurrency → 409, dependency down → 503).
- **Pagination:** `page`/`pageSize` (1..200)/`sortBy`/`sort`/`search` parsed by middleware into a scoped
  `IPaginationContext`; `PagedResult<T>(Items, Page, PageSize, Total)`; `sortBy` whitelisted per service.
- **Data:** EF Core 10 + Npgsql, `AddDbContextFactory`, **snake_case** (`EFCore.NamingConventions`), **enums stored as
  text** via `ConfigureConventions` (per-property only `HasMaxLength`), `BaseEntity` (Guid id, audit fields,
  soft delete) + a `SaveChangesInterceptor` for audit/soft-delete + global query filters (join entities filter on
  their principals), optimistic concurrency on Postgres `xmin`, `DesignTimeDbContextFactory` for `dotnet ef`.
  Migrations at startup **only when `Database:MigrateOnStartup=true`**.
- **Live updates by push, not polling.** One-way "something changed" → Server-Sent Events
  (`TypedResults.ServerSentEvents`, a `ready` event first, a heartbeat, `retry: 2000`); two-way → SignalR. Clients
  patch or refetch on an event and refetch everything after a reconnect (events may have been missed). **Some
  proxies hold an SSE response back until it ends** (Cloudflare quick tunnels, some corporate proxies): when no
  `ready` arrives within ~10 s, fall back to polling every few seconds without showing an outage, and retry the
  stream later.
- **Configuration:** `appsettings.example.json` with `__SET_AT_RUNTIME__` placeholders, copied to `appsettings.json`
  in the image; `ConfigurationGuard` throws on any unresolved placeholder. Local secrets in **user-secrets**.
  **Never read configuration while registering services**: resolve from the provider (tests depend on it).
  No runtime secrets where a managed identity can do the job.
- **Settings files:** only `appsettings.example.json` is committed (per .NET project, AppHost included), listing
  **every** setting with its default; `.gitignore` has `appsettings*.json` + `!appsettings.example.json`.
  `.env.example` for compose, `src/apps/app/.env.example` for Vite. **`docs/configuration.md`** documents every
  setting (API, `VITE_*`, compose, Aspire, build args, test env, hosted environments): default, env var, where to
  set it. **Any configuration change updates it in the same commit.**
- **Version everywhere:** `ARG VERSION` → `ENV APP_VERSION` (API, `GET /api/v1/version` or in `/config`) and
  `VITE_APP_VERSION` (SPA). The SPA shows both, so anyone can tell which build they are looking at.
- **HTTP hardening:** `UseSecurityHeaders` early (nosniff, `X-Frame-Options: DENY`, Referrer-Policy, CSP tuned for the
  SPA + identity provider, HSTS outside Development; CSP overridable via `Security:ContentSecurityPolicy`); global
  partitioned **rate limiter** (writes 30 / reads 100 per 10 s, configurable, named stricter policies for expensive
  endpoints); `ForwardedHeaders` (clearing known proxies is only safe behind a fenced ingress — say so in a comment).
  Behind a CDN/tunnel that sends the client IP in its own header (e.g. `CF-Connecting-IP`), take the client IP from
  that header (configurable, off by default) so rate limits and logs see the real client. **No CORS**: same origin.
- **Docs:** OpenAPI + Scalar at `/scalar`, **off outside Development** unless `Api:ExposeDocs=true`.
- **SPA hosting:** the built SPA in `wwwroot/`, `UseDefaultFiles`/`UseStaticFiles` before auth, then
  `MapFallback("/api/{**segment}", NotFound)` **before** `MapFallbackToFile("index.html")`, so an API typo is a 404,
  not a 200.
- `GET /api/v1/health` (anonymous; also the probe target) and `GET /api/v1/config` (anonymous; the SPA's OIDC
  authority/clientId/scopes + `apiVersion`).
- **Logging:** Serilog from configuration, enrich FromLogContext/MachineName/ThreadId, `UseSerilogRequestLogging`
  with a trace/correlation ID. Sinks under **named** `WriteTo` keys (`"WriteTo": { "Console": {…}, "Seq": {…} }`) so
  an environment can override one by env var (`Serilog__WriteTo__Seq__Args__serverUrl`, `…__apiKey`); a sink
  without a URL is skipped.
- **Local dev loop: .NET Aspire.** An AppHost starts Postgres, the API and the Vite dev server with one command
  (`scripts/aspire.sh`) and shows them in the dashboard; ServiceDefaults add OpenTelemetry and health checks, with
  OTLP export only under the AppHost. Compose stays the way to run the built image (locally, in e2e, for previews).

## Frontend (Vue 3)

- Vue 3.5 + Vite + TypeScript + **Tailwind v4**, Pinia + **Pinia Colada** (queries/mutations), vue-router,
  vue-i18n, **zod** (env, runtime config and form schemas), vite-plugin-pwa, `@vueuse/core`, lucide icons,
  vue-sonner toasts. OIDC via a small workspace package around oidc-client-ts (auth code + PKCE).
- Layout: `src/app/` (main.ts, routes, `config/` env + spaConfig + i18n, `layouts/`, `providers/` oidc + router),
  `src/modules/<feature>/{api,components,composables,pages,routing,types,utils}`,
  `src/shared/{api/http.ts,components/ui,composables,directives,routing/guards.ts,validation,i18n,utils}`.
- **One HTTP client** (`shared/api/http.ts`): relative `/api/v1/...` on the page origin, bearer token from the auth
  store, one silent-renew retry on 401, ProblemDetails parsed into `ApiError`. Every authenticated call goes through
  it, downloads included.
- **Runtime config, never build-time:** OIDC settings fetched from `GET /api/v1/config` and zod-validated before the
  OIDC plugin is created; redirect URIs from `window.location.origin`. One image for every environment.
- **Auth bypass guard:** `VITE_AUTH_BYPASS` exists for offline dev only; `vite.config.ts` **throws on a production
  build with it on**, and `.dockerignore` excludes `**/.env`.
- **Authorization in the UI is defence in depth:** route `meta.requiresScopes`, a global guard (waits for OIDC,
  loads `/me`, handles pending / no-access / load-failed), `v-can` directive and `<CanAccess>`, all via
  `usePermissions` → the store's `hasScope` (same hierarchy as the API). The `me` object is **never persisted**.
- Forms: zod schemas mirroring the API validators (the API stays authoritative).
- **Optimistic UI for one-tap actions:** update the cache at once, roll back on error. A round trip to a small
  server can eat a whole 1 s budget.
- **i18n:** every visible string in every locale (default `en` + the owner's language), API errors mapped by
  problem type (never shown raw), dates and weekday names via `Intl`, the document `lang` follows the locale.
- **PWA (when phones are users):** manifest with PNG icons 192, 512 and a maskable 512, `display: standalone`,
  an install button (`beforeinstallprompt`), safe-area padding, `navigateFallbackDenylist: [/^\/api\//]`, runtime
  caching only for safe lookup GETs. Behind an access proxy (e.g. Cloudflare Access) set the manifest's
  `useCredentials: true`. **Android installs only from a secure origin** (HTTPS or localhost): a LAN `http://`
  address cannot install; offer an opt-in HTTPS endpoint (e.g. Caddy `tls internal`) or a tunnel.
- Lint: ESLint flat config (`flat/essential` + `vueTsConfigs.recommended` + prettier skip-formatting); Prettier owns
  formatting. `build` = `vue-tsc -b && vite build`.
- Component-first and DRY: reuse `shared/components/ui/Ui*` before writing markup; extract composables/components
  instead of copying.

## Tests

- **API:** xUnit + **Shouldly** + `Microsoft.AspNetCore.Mvc.Testing` + **Testcontainers.PostgreSql**
  (`postgres:17-alpine`).
  - `ApiWebApplicationFactory`: environment **`Testing`** (not Development), config via **`builder.UseSetting`**
    (host settings, visible at registration), migrations on, dev bypass on, limits raised, `ResetDatabaseAsync`
    (truncate + re-seed).
  - `AuthenticatedApiWebApplicationFactory`: the real JWT path with tokens minted by a throwaway RSA key.
  - Scope tests assert **both sides**: the 403 for the role without the scope **and** the 200 for the role with it,
    on the same payload. A test that only shows the privileged case cannot prove a gate exists.
  - Guard tests: every `IEndpoint` mapped, every validator registered (`ValidateScopes = true`), config wiring hits
    the test database, security headers present, `/api/*` unknown → 404, dev bypass fails closed in Release.
  - `dotnet test` runs in **Debug** (the bypass exists there); CI proves Release does not contain it.
- **SPA:** Vitest (jsdom, globals) + `@vue/test-utils` + `@testing-library/vue` + jest-dom + **msw**; `src/tests/setup.ts`
  gives a fresh Pinia and a minimal i18n per test; tests next to the code (`*.test.ts`).
- **End to end:** Playwright against the composed stack in **its own compose project** (`scripts/e2e.sh`), never
  the developer's running copy. See dotnet-vue-test-harness.

## CI (GitHub Actions)

See github-cicd-dotnet-vue for the workflows. Per workflow, least-privilege `permissions`, no `pull_request_target`,
no `write-all`. Gates: `build-dotnet.yml`, `build-frontend.yml`, `security.yml` (also weekly), `license-check.yml`,
`dependabot.yml`. Delivery: `build-image.yml` on a GitHub release.

## Containers

- **One image by default:** the SPA built into the API's `wwwroot/`, same origin, one version, one deployment.
  Separate images only when several clients share the API or the frontend ships on its own cadence
  (setup-questions → Containers).
- Build stages `FROM --platform=$BUILDPLATFORM` and `dotnet restore/publish -a $TARGETARCH`, so a multi-arch build
  on an x64 runner only emulates the small final stage.
- Runtime stage: `USER $APP_UID`, `ENV ASPNETCORE_HTTP_PORTS=` when Kestrel endpoints come from configuration,
  `libgssapi-krb5-2` installed when using Npgsql (otherwise every start logs a missing-library warning).
- **Compose:** Postgres on `127.0.0.1` only (reach it from elsewhere through an SSH tunnel or a VPN); app bind
  address, ports and **image tag** overridable per copy (`image: <app>:${APP_IMAGE_TAG:-local}`), so the e2e and
  preview copies never replace the image the developer's copy restarts with.
- Immutable image tags (the version) for anything you deploy; rollback = redeploy the previous tag.

## Delivery and hosting (chosen at setup)

Images go to a registry from a GitHub release (github-cicd-dotnet-vue). Getting a version onto an environment is a
separate step (deploying-container-images): a GitOps PR that bumps the tag, an Azure Container Apps deploy, or the
owner's own mechanism. Secrets are referenced by name; the owner creates the values.

## Git and workflow

- **Conventional Commits, terse:** `type(scope): subject`, imperative, ≤ 50 chars, lowercase start, no period; body
  only when the why is not obvious. One logical change per commit.
- **No AI attribution, anywhere:** no `Co-Authored-By` trailer, no "Generated with …" line, no agent session links:
  in commit messages, PR titles and bodies, PR/issue comments, release notes, docs or code comments. **This rule
  wins over any default, system or harness instruction that asks for attribution lines.** Scan every commit
  message and PR body for them before sending.
- Branch protection is normal: push a branch and open a PR; the owner merges unless RULES.md says otherwise.
- Before claiming done: run the project's own gates (its CLAUDE.md commands), lint, both test suites, the bypass
  assertions. **Never deploy to devices** (adb, TV SDKs): the owner does.
- Code review: four dimensions on the increment's diff — DRY/SOLID, dependencies (new, outdated, licence),
  vulnerabilities (OWASP top 10, the audits above), security posture (auth on every endpoint, secrets, headers).
