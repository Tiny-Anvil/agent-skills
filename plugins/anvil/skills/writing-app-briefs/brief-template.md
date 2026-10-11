# Brief: <APP>

- Version / date:
- Owner:
- Repo / environments:

## The idea

<2-4 sentences: who uses it and what they get done.>

**The real task:** <the ambition, and what the builder designs: data model, API shape, UI design, ...>

## What matters most

1. <observable, measurable>
2. <...>

## Required

- Roles and permissions:
- Core flows:
- Data that must persist:
- Integrations (auth, email, external APIs):
- Environments and URLs:
- Browsers and viewports:
- Failure handling:
- Observability:
- Constraints (stack, CPU architecture, resource limits):

## Deliverables

- Repo and branch, images (`ghcr.io/...`), deployed URL(s), README, LICENSE.
- Captures (Playwright, real stack, desktop 1440×900 and phone 390×844): <screen × state list>.
- `final/QA.md` with every test ID, its evidence file and the commit it ran on.

## Tests

| ID | Procedure | Measured | Threshold | Evidence | Human? |
|---|---|---|---|---|---|
| A01 | fresh clone → README command → poll /health/ready | seconds to 200 | ≤ 60 s | qa/A01.log | |
| A02 | <core flow> via Playwright on the compose stack | pass/fail per step | all pass | trace + PNGs | |
| A03 | endpoint × role matrix | status codes | 100 % as specified | TRX | |
| A04 | k6, <N> VUs, <M> s, busiest endpoint | p95 ms, error % | ≤ <> ms, 0 % | qa/k6.json | |
| A05 | CI on final commit | status, duration | green | run URL | |
| A06 | test env /version after deploy | commit sha | == final commit | qa/A06.json | |

## Traceability

| Required bullet | Test IDs |
|---|---|

## How it is judged

1. What matters most.
2. Required, by test.
3. Quality bar from RULES.md.

## Updates

<YYYY-MM-DD, verbatim, who.>
