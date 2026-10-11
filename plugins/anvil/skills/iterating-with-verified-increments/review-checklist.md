# Review checklist (step 5 of the loop)

Go through it for every increment. Name each failure as an anchored defect.

## Passes

A run moves through these and revisits them: **Skeleton** (end to end, CI green) → **Core flows** (the brief's
"matters most") → **States** (empty, loading, error, unauthorised, offline) → **Edges** (validation, concurrency,
limits, time zones) → **Hardening** (auth matrix, performance, accessibility, observability) → **Finish** (README,
fresh clone, deploy verified).

Security review: run the four dimensions of house-stack.md → Git → Code review (DRY/SOLID, dependencies,
vulnerabilities, security posture) on the increment's diff at Hardening and at Finish, and the project's own
`docs/code-review-guide.md` when it has one.

## API

- Every endpoint has `RequireScopes` (or an explicit `RequireAuthorization` / `AllowAnonymous`), and a scope test
  shows **both** the 403 and the 200 for it.
- No IDOR: a non-privileged user cannot read, export or change another user's rows (`:id` routes, `ids[]`, exports).
- `.WithValidation<T>()` on every body; query bounds on ids and date ranges; mass-assignment impossible (request
  records, not entities).
- New endpoint mapped in `Endpoints.cs` with `.WithName(...)`; feature doc updated.
- Errors are ProblemDetails with a useful title; no stack traces or SQL in responses.
- Validation returns 400 with field errors, not 500.
- Queries: no N+1 on list endpoints (check the EF log), paging on anything unbounded, `CancellationToken` passed.
- Migrations: one per schema change, they apply on an empty database and on the previous version's database.
- Logs: structured properties, no secrets or tokens, a correlation ID per request.
- Config: new keys in `appsettings.example.json` (`__SET_AT_RUNTIME__` if required), never read during registration.
- Enums stored as text; migrations reviewed; soft-delete filters on new join entities.

## Frontend (open each screenshot)

- Phone width: no horizontal scroll, nothing cut off, tap targets large enough, keyboard does not cover inputs.
- Every async action shows loading, success and failure; no blank screen on an API error.
- Text: no placeholder copy, no raw keys, no `undefined`/`null`/`NaN`, dates in the user's locale.
- Navigation: deep links and refresh work (SPA fallback), back button does the expected thing.
- Auth: expired token leads to re-login, not a broken page; role-hidden actions are also blocked by the API.
- XSS: no `v-html` on user data; no dynamic `:href`/`:src` with unchecked schemes.
- New routes carry `meta.requiresScopes` matching the menu entry; actions wrapped in `v-can`.
- Strings in every locale file (keys equal across them); no hard-coded copy.
- Console: no errors or warnings during the e2e run (collect them in Playwright).

## Delivery

- Image builds for every target platform; container runs as `$APP_UID`; health endpoint reflects the database.
- Release assembly has no `DevBypassAuthenticationHandler`; production build refuses `VITE_AUTH_BYPASS=true`.
- CSP still matches the identity provider's origins (watch the browser console on the first deploy).
- No environment URLs baked into the frontend build; runtime config only.
- The deploy change touches only this app's files and renders (`kubectl kustomize` / `helm template`) for every
  changed environment.
- Config: a new setting is in `appsettings.example.json` / `.env.example` **and** `docs/configuration.md`.
- Live updates: a held-back stream (proxy) falls back to polling without an outage banner.
