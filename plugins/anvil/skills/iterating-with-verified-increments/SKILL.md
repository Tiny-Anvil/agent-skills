---
name: iterating-with-verified-increments
description: Use when building or polishing a web application (.NET API, Vue.js frontend) whose correctness must be shown by running it — features, UI screens, auth, data flows, performance, deployment; before reporting such work done or writing "needs manual testing"; when comparing before/after a fix; or when successive fixes stop improving the same defect.
---

# Iterating With Verified Increments

## Overview

An **increment** is an inspectable checkpoint: a commit, plus the evidence you actually inspected (test reports, UI
screenshots, logs, CI run, deployed version), plus the named defects and the next corrections. You work increment
by increment: build, run the real stack, test, look at the output, name concrete defects, fix a small coherent set,
then freeze the increment. A test that asserts your own constants shows nothing about what the user gets.

## The Loop

1. **Target.** Write in RUN.md what the increment is for, what matters most, and the hardest technical risk.
2. **Walking skeleton first.** API, database, frontend, CI and (if allowed) a dev deploy, end to end, with one real
   request flowing through all of them. Integration risk is the biggest risk; retire it before detail.
3. **Run the real stack:** `docker compose up` (or the project's equivalent) with the real database and the real
   frontend build. Mocks are for unit tests only; every increment also runs against the real stack.
4. **Test.** Run the brief's tests (dotnet-vue-test-harness). Use the **same test case** before and after a fix.
5. **Inspect** the evidence yourself against the table below and `review-checklist.md`. Open every screenshot.
   Read the API log for the flows you ran.
6. **Name the largest defects** as anchored observations, in this exact form:
   `In <file / screen / endpoint> (<test ID or step>): <what is wrong>. Change <X>. Expect <Y> in the next run.`
   Fix a small coherent set and keep what already works.
7. **Freeze the increment.** Commit, fill `INCREMENT.md` under `increments/I###/`, update `final/` if it is the best
   verified build.
8. **Continue** while major defects remain. Stop on the completion conditions below.

## Evidence Required Per Claim

| Claim | Minimum evidence |
|---|---|
| "The endpoint works" | integration test against the real DB (Testcontainers), including the error and unauthorised cases |
| "The screen works / looks right" | Playwright screenshots at desktop **and** phone width, in each state (empty, loaded, error), from the real stack; opened and inspected |
| "The flow works" | an e2e test driving the UI through the whole flow, with a trace on failure |
| Auth | the endpoint × role matrix result, plus one real login through the identity provider if it is in scope |
| Performance | p50/p95 ms at the stated load after warm-up, from k6 or similar, on a named machine |
| Accessibility | axe-core result per main page |
| "It's deployed" | the deployed `/version` equals the commit, the pods are Ready, and one smoke request succeeds |
| "It works" (anything) | test ID + evidence file + the **same commit** as the other evidence |

## Rules

- **Never let the environment hide a failure.** Seeded demo data, a dev-only auth bypass, a warm cache and a fast
  desktop can all do it. Also run: empty database, real auth path, cold start, phone viewport, slow network.
- Every piece of evidence names one build: commit hash plus a dirty flag. Evidence from another commit does not count.
- **Run the project's own gates before calling an increment verified**, not just yours: its CLAUDE.md build and
  type-check commands (e.g. a `pnpm type-check` and a mobile build when the project has one), lint, both test
  suites, and the bypass assertions (house-stack.md → CI).
- **Every threshold in a brief row gets its own assertion.** Re-read the row while writing the test; a row with two
  numbers needs two asserts.
- **Evidence comes from the final commit.** A docs-only commit after the last run still means rerunning, or saying
  so in QA.md.
- **The capture machine must render what users see.** On headless Linux install a colour emoji font
  (e.g. `fonts-noto-color-emoji`) and the UI fonts before judging screenshots; tofu boxes are a machine defect,
  not an app defect, and hide real ones.
- **Captures are written per increment** (`increments/I###/captures/`); never clean old ones up in place.
- **Dependency audit** every increment (house-stack.md → Repo layout), test projects included.
- Increments are append-only. A regression gets a new increment. An old increment is never edited.
- A failed run is an attempt, not something to erase. Keep its logs, return to the last green commit, continue.
- **Never weaken a test to get a pass.** Changing a threshold or deleting a test needs a recorded decision citing
  the brief, and never for a "what matters most" item.
- Record owner feedback verbatim, with a timestamp, separately from your self-review.
- **Stagnation:** if two increments fail to fix the same defect, record the evidence and change approach: isolate it
  in a minimal repro, simplify the implementation, or read the framework source. Never delete a required feature.
- Write "needs owner eyes-on" only for what automation cannot show: taste, copywriting, a real third-party account.
  Name the item and why.

## Completion Conditions

- The required functionality exists and has been exercised through the real stack.
- Every main screen and state has been captured and inspected at both widths.
- Every major defect is either fixed or listed as unresolved. An unresolved major defect means the work is incomplete.
- A fresh clone builds, tests and starts from the README's commands. Verify it in a clean directory.
- CI is green on the final commit; the deployed environment (if in scope) serves that commit.
- `final/QA.md` and the final evidence reference the same commit.
- Someone else can reproduce the core result from the written instructions.

## Records

Run records are local working docs: they live in **`data/run/`** (gitignored), never under the repo's `docs/`.
- `data/run/RUN.md`: intent, environment, increment history, decisions, current findings.
- `data/run/increments/I001/...`: one record per increment (screenshots, reports, logs).
- `data/run/final/`: always the best verified build's evidence and QA.

What the increment changes in the product is documented in the repo: `docs/features/<feature>.md` in the same
commit as the feature (and any API collection the project keeps, e.g. Bruno or Postman, for every API change).

## Delegating a Pass

Give the helper the **code card** (`docs/ARCHITECTURE.md`) and the contract (`docs/CONTRACT.md`):
- layout and conventions;
- config and env vars;
- the files it owns;
- the exact build, test and capture commands.

When it finishes, integrate the work, then run and test **the combined stack** yourself. Separate passing reports do
not show that the whole works. Respect the project's limits on agent count.

## Red Flags

- "The unit tests pass, so the feature works."
- "It works with the seed data."
- "I checked the desktop screenshot" (and the phone one was never taken).
- "CI is green" offered as proof of a deploy (see deploying-container-images → Verifying a deploy).
- "Looks good" with no file, screen or test ID named.
- Report says done, and the evidence comes from an earlier commit.
