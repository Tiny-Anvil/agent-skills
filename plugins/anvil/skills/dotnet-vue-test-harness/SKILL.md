---
name: dotnet-vue-test-harness
description: Use when a .NET minimal API + Vue.js app needs tests that prove behaviour through the real stack — API integration tests against a real Postgres (Testcontainers), real-JWT and scope tests, guard tests, Vue component tests, Playwright end-to-end flows and screenshots, load numbers, or a preview copy testers can reach; when tests pass but the feature is broken, a test hits the wrong database, a scope gate is untested, or captures come out blank, unauthenticated or from the wrong build.
---

# .NET + Vue Test Harness

## Overview

Four layers, each answering a different question. All of them run in CI, except the screenshot captures and load
runs, which run in every increment.

| Layer | Proves | Tooling |
|---|---|---|
| API integration | endpoints, data, auth and rules through HTTP against real Postgres | xUnit, Shouldly, `WebApplicationFactory`, Testcontainers |
| Guard tests | the safety rails cannot silently disappear | xUnit over the built host / assembly |
| SPA unit/component | composables, stores, components, schemas | Vitest, `@vue/test-utils`, Testing Library, msw |
| End to end + captures | the user's flows and screens on the composed stack | Playwright (Chromium, desktop + phone) |
| Load (when the brief has a perf test) | p50/p95 latency and error rate | k6, or `templates/load.mjs` (Node only) |

Templates are in `templates/`. Copy and adapt them; do not reinvent them.

## API Integration Tests

**`ApiWebApplicationFactory : WebApplicationFactory<Program>, IAsyncLifetime`** (one per test class fixture):
- A `PostgreSqlContainer` (`postgres:17-alpine`) started in `InitializeAsync`, disposed in `DisposeAsync`.
- `builder.UseEnvironment("Testing")`, **not** Development: Development loads `appsettings.Development.json` and
  user-secrets *after* the factory, so they would win and the tests would run on the developer's database.
- Every setting via **`builder.UseSetting(key, value)`** (host settings exist from the start).
  `ConfigureAppConfiguration` sources merge during `Build()`, too late for anything read at registration (the auth
  scheme choice is).
- Base settings: the container's connection string, `Database:MigrateOnStartup=true`, `Authentication:Enabled=false`
  + `AllowInsecureDevBypass=true`, every `__SET_AT_RUNTIME__` key filled, rate limits raised to 10000, external
  integrations off.
- `ResetDatabaseAsync()`: `TRUNCATE ... RESTART IDENTITY CASCADE` on every table, then re-seed the dev-auth user.
  Call it from each test class's `InitializeAsync`.
- **Time:** inject `TimeProvider`. `FakeTimeProvider` cannot move backwards; when each test class sets its own
  "now", use a small settable `TimeProvider` instead.

**`AuthenticatedApiWebApplicationFactory : ApiWebApplicationFactory`**: `Authentication:Enabled=true` and the real
JWT bearer path. In `ConfigureTestServices`, point `JwtBearerOptions` at a throwaway `RsaSecurityKey` (no Authority,
no metadata fetch) and mint tokens shaped like the provider's (`oid`/`sub`, `name`, `email`; **no roles** — they
come from the database through the claims transformation, which is what is under test).

Rules:
- **Scope tests assert both sides on the same payload**: the role without the scope gets 403, the role with it gets
  200/201. A privileged-only test cannot show a gate exists. Seed users per role in the test.
- **IDOR tests**: user B against user A's `:id`, `ids[]` and exports; assert on **content** (a unique description),
  with a mirror test that A does see it, so an empty result cannot pass for the wrong reason.
- Validation: at the bound, over it, inverted, open-ended; the 400 has field errors.
- **Races at the API level:** N parallel requests for the same slot → exactly one 2xx, the rest 409, one row. Once
  the UI has live updates, two UI taps no longer race (the push wins); test the UI's conflict message with a stale
  device instead (its event stream cut, see below).
- Concurrency: two writers on the same `xmin` row; the second gets 409.
- **Server-Sent Events:** read `text/event-stream` with `HttpCompletionOption.ResponseHeadersRead` and a line
  reader; TestServer streams fine. Assert the `ready` event, then make a change in another request and assert the
  event arrives.
- Name tests as sentences (`Bulk_unmark_billed_is_403_for_a_manager`). Comment *why* a gate matters.
- `dotnet test` runs **Debug** (the bypass exists there). To run against Release: `-p:EnableDevAuthBypass=true`.

## Guard Tests (write them once, in the first increment)

| Test | Fails when |
|---|---|
| `EndpointRegistrationTests` | an `IEndpoint` class is not mapped in `Endpoints.cs` (routes are named after the class) |
| `ValidationRegistrationTests` | an endpoint's `WithValidation<T>()` has no registered validator (host built with `ValidateScopes = true`, every endpoint materialised) |
| `ConfigurationWiringTests` | the `DbContext` opens anything but the test container's host/port/database |
| `SecurityHeadersTests` | a response lacks nosniff / frame / referrer headers or the CSP loosens |
| `SpaHostingTests` | unknown `/api/*` answers 200 HTML instead of 404 problem+json; `/api/v1/config` shape changes |
| `DevBypassGuardTests` | the bypass runs outside Development without the opt-in, or exists in Release |
| `OpenApiDocumentTests` | the OpenAPI document no longer matches the contract (`data/run/docs/CONTRACT.md`) |
| `HealthEndpointTests` | the host stops booting |

## SPA Tests

- Vitest with `environment: 'jsdom'`, `globals: true`, `include: ['src/**/*.{test,spec}.ts']`,
  `setupFiles: ['src/tests/setup.ts']` (fresh Pinia per test, minimal i18n returning keys, reset locale and storage).
- Test next to the code (`UserDetailDialog.test.ts`). Mock the module's composables/store with `vi.mock`; use msw
  when the real `http.ts` should run.
- Teleported dialogs render in `document.body`: query there, and `enableAutoUnmount(afterEach)` instead of clearing
  the body by hand.
- Cover: zod schemas (mirror the API validator's cases), `hasScope` hierarchy, route guards (pending / denied /
  load-failed / scope redirect), every composable with logic, and each component's states.
- **Locale key parity** (`messages.test.ts`): every locale file has the same keys. Read the JSON files **raw**
  (`fs.readFileSync`): `@intlify/unplugin-vue-i18n` precompiles JSON *imports* into functions.

## End to End and Captures (Playwright)

Templates: `templates/playwright.config.ts`, `templates/capture.spec.ts`, `templates/e2e.sh`.

**The stack under test is a throwaway copy of the real one, never the developer's running copy.** `scripts/e2e.sh`
starts its own compose project (`-p <app>-e2e`) on other ports, bound to `127.0.0.1`, with its own image tag and a
fresh volume; raises rate limits only there; runs Playwright; then the restart check and the load run; and removes
everything with `down -v`. Seeding and tests therefore never write into real data, and a test build never replaces
the image the developer's copy restarts with.

With auth in scope, the e2e copy runs the API with `Authentication:Enabled=false` (Development) and the SPA built
with `--mode development` + `VITE_AUTH_BYPASS=true`. Production mode refuses the bypass by design: never weaken that
guard for tests.

- **Per role:** restart the API with `DevAuth__Roles=<scopes>` and set `VITE_AUTH_BYPASS_USER_ROLES` to the same, to
  capture what each role sees and to prove hidden actions stay hidden. The API still enforces scopes, so a wrong
  pairing shows as 403s, which the spec must fail on.
- **Projects:** `desktop` (1440×900) and `phone` (390×844, touch). Every capture at both.
- **States:** for each main screen capture empty, loaded, error (API stopped or a route mocked to 500), and
  unauthorised (role without the scope). Seed data through the API, never by SQL in the e2e layer.
- Collect `console` errors and failed requests; the test fails on any 5xx. Browsers log **expected** 4xx answers
  (a 409 the test provokes) as console errors: allow those by URL and status, keep failing on everything else.
- **Latency in the page:** measure "tap → UI updated" inside the page (`pointerdown` timestamp → a
  `MutationObserver` seeing the new state), not around `click()`, whose actionability wait ends up in the number.
- **Live updates (SSE):** two browser contexts; B sees A's change without reload in ≤ N s. Test the proxy
  fallback by routing the event stream to a handler that never answers (`page.route('**/api/v1/events', () => {})`):
  the UI must switch to polling and still show A's change, without an outage banner.
- **Accessibility:** axe-core on every main screen, light and dark; 0 serious/critical. Decorative SVGs get
  `aria-hidden="true"` (an `role="img"` SVG with an empty label is flagged).
- **Animations:** a `TransitionGroup` keyed on changing data leaves two elements with the same test id during the
  leave transition; key by identity and use `mode="out-in"` where one element replaces another.
- Name files `<screen>-<state>-<project>.png` under `data/run/increments/I###/captures/`. Open every one before
  writing a verdict (iterating-with-verified-increments).
- `trace: 'retain-on-failure'`; attach the trace to the increment record when a flow fails.
- The real login (Entra/Logto/...) cannot be automated without a test account. Unless RULES.md provides one, mark
  the "real sign-in on the deployed environment" check as owner eyes-on and say why.
- **Browsers:** `pnpm exec playwright install chromium` once at setup (it downloads a browser: needs the owner's
  OK). On linux-arm64, where Playwright's own build may be missing, point `launchOptions.executablePath` at the
  system Chromium; that works inside the test runner. A plain Node script that calls `chromium.launch()` and
  screenshots can still fail there; for one-off renders (icons) use `chromium --headless --screenshot` with a
  taller window, then crop.

## Load (only when the brief asks)

- **k6** (`templates/k6-smoke.js`): N virtual users for M seconds against the busiest read endpoint, thresholds
  from the brief (`http_req_duration{p(95)}`, `http_req_failed`), `--summary-export qa/k6-<id>.json`.
- **No k6 on the machine?** `templates/load.mjs` (Node only, ~60 lines): N concurrent clients, a warm-up, then
  p50/p95/p99, requests/s and error rate as JSON, exit code from the thresholds.
- Run it against the e2e copy with rate limits raised for the run, on a named machine; record both in the evidence.

## Preview Copies (testers outside your network)

`templates/preview.sh` + `templates/preview.compose.yml`: build the current checkout, run it as its own compose
project with **no ports on the machine** (`ports: !reset []`), and publish it through a Cloudflare tunnel container.
- **Quick tunnel** (default): a random `https://<words>.trycloudflare.com` link, no account, public to anyone with
  the link, gone on `preview.sh down`. **Quick tunnels do not pass Server-Sent Events** (the response is held
  back), which is why the SPA needs the polling fallback.
- **Named tunnel** (`--named`): a fixed hostname behind an access policy (Cloudflare Access), token in a file under
  `~/.config/<app>/` (mode 600), never in git.
- Data in a preview is throwaway; it never points at a real environment's database.

## Commands

```bash
# API
dotnet build src/apps/api/<App>.Api.csproj -c Release
dotnet test  src/tests/<App>.Api.Tests/<App>.Api.Tests.csproj --logger "trx;LogFileName=api.trx"   # Docker required

# SPA
pnpm install --frozen-lockfile
cd src/apps/app && pnpm lint && pnpm test:run && pnpm build

# E2E on a throwaway copy (build, test desktop + phone, restart check, load, tear down)
bash scripts/e2e.sh
E2E_INCREMENT=I003 bash scripts/e2e.sh     # also write captures for increment I003

# Preview for testers
scripts/preview.sh up      # prints the link
scripts/preview.sh down
```

## Red Flags

| Thought | Reality |
|---|---|
| "I'll use `UseEnvironment(\"Development\")` in the factory" | User-secrets win; you are testing (and truncating) the developer's database. |
| "I'll point Playwright at the stack that is already running" | That is someone's data. Use `scripts/e2e.sh`'s own compose project. |
| "The admin call returns 200, the gate works" | Only the 403 for the role without the scope proves a gate. |
| "I'll turn off the production-build bypass guard so e2e can log in" | Never. Use a development-mode build for e2e. |
| "The export test passes: the result is empty" | Assert on content and add the mirror test. |
| "One desktop screenshot of the list" | Every main screen, every state, both widths, opened and inspected. |
| "Mocked API in the e2e" | The e2e layer runs the real API and database; mocks belong in unit tests. |
| "`pkill -f <pattern>` to stop the test server" | It also matches (and kills) the shell running the command. Kill by PID. |
