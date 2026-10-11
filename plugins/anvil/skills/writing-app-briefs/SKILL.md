---
name: writing-app-briefs
description: Use when turning a web application, service, milestone or major feature idea (.NET API, Vue.js frontend) into the document another agent or session will build from unattended, when a spec's requirements have no measurable pass criteria, or when "done" would otherwise be decided by "the owner clicks through it later".
---

# Writing App Briefs

## Overview

A brief is the **acceptance contract**: who uses the app and for what, what matters most, what must exist, and the
numbered tests that prove it. Every requirement is provable by a test with a number and an evidence file. Design
and architecture stay the builder's job.

Brief → design/contract → plan. A brief that prescribes classes and tables has become a spec, and it leaves out how
the result will be judged.

## When to Use

- Kicking off a new app, a milestone, or a big feature in an existing app.
- Handing work to an agent or session that cannot ask questions.
- An existing spec says "owner tests it" or has requirements no test can fail.

**Not for:** a bugfix, or the implementation plan itself. Write that afterwards and keep the brief's test IDs in it.

## The Recipe

Fill `brief-template.md` (next to this file) in this order. The brief is a spec: it lives in
`data/run/docs/BRIEF.md` (gitignored), never under the repo's `docs/`.

1. **The idea.** 2-4 sentences: who the users are and what they get done. Then **the real task**: the ambition, and
   what is left for the builder to design.
2. **What matters most.** 1-3 items judged first, in observable terms. Not "fast and easy" but "a member signs up
   for an event in ≤ 3 taps from the home screen, on a phone, and sees confirmation within 1 s".
3. **Required.** Checkable bullets: user roles and what each may do, the core flows, data that must persist,
   integrations, environments and URLs, supported browsers and viewports, offline/PWA behaviour, failure handling
   (API down, token expired, validation errors), observability (logs in Seq with a correlation ID).
4. **Deliverables.** Repo, images, deployed URL(s), README, and the **captures**: Playwright screenshots of every
   main screen and state (empty, loaded, error, unauthorised) at desktop and phone width, from the real stack.
5. **Tests.** IDs `<P>01..`, one row each: procedure, **measured quantity with unit**, threshold, evidence file.
   Always include:
   - the stack starts from a fresh clone with the README command; `/health/ready` is 200 within N s;
   - each core flow end to end through the UI (Playwright), against the real API and database;
   - authorisation: each role allowed and denied where it should be (401/403 measured, not assumed);
   - validation and error states shown to the user;
   - performance: API p95 latency at N concurrent users; frontend bundle size; Lighthouse/first-load on phone width;
   - CI: pipeline green on the final commit, duration;
   - deploy: the test environment's URL serves the final commit's `/version`;
   - one test per custom rule (business logic) with boundary cases;
   - when phones are users: the phone layout **and** an installable PWA (manifest, icons, service worker);
   - when several devices share data: live-update latency to another open device (B sees A's change in ≤ N s);
   - API down: the outage visible in ≤ N s **and** recovery in ≤ N s after it returns — two rows, two numbers
     (one row with both tends to get only one assertion).
6. **Traceability.** Each Required bullet → its test IDs. A bullet with no test is a wish.
7. **How it is judged.** The priority order. "Matters most" goes first.
8. **Updates.** Dated and verbatim, appended under the brief. Never rewrite the original.

## Test Patterns That Transfer

| Requirement | Measured as |
|---|---|
| Fast enough | API p50/p95 ms at N virtual users for M s (k6 JSON summary); error rate % |
| Works on phones | Playwright at 390×844 and 1440×900: no horizontal scroll, tap targets ≥ 44 px, screenshots |
| Secure by role | for every endpoint × role: expected status (200/401/403); each 403 paired with a 200 on the same payload |
| No IDOR | user B requests user A's `:id`, `ids[]`, export: 403 or absent from the result, asserted on content |
| Bypass can't ship | Release assembly contains no dev-bypass type; production build with `VITE_AUTH_BYPASS=true` fails |
| Hardened HTTP | every response carries the security headers and the CSP; unknown `/api/*` is 404 problem+json, not 200 HTML |
| Data integrity | concurrent edits: second writer gets 409; no lost update (count rows) |
| Resilient UI | API stopped mid-session: user sees an error state within N s, no blank screen, recovers on restart |
| Accessible | axe-core violations of impact serious/critical = 0 on each main page |
| Observable | a request's correlation ID appears in API logs; a 500 produces one structured error event |
| Deployable | fresh clone → `docker compose up` → e2e suite green; test env `/version` == final commit |

## Rules

- **Say where a latency is measured.** "Tap → UI updated, measured in the page (pointerdown → DOM state)", not
  around a test-runner action: a runner's own waits (actionability, retries) end up in the number.

- **A test that only asserts your own constants proves nothing.** Drive the real stack: HTTP in, database and UI out.
- Each test names its evidence type: test report (TRX/JUnit), JSON, PNG, Playwright trace, CI run URL.
- Mark the rows that need human judgement (visual taste, copywriting). Everything else gets automated.
- In an existing project, name its runners, environments and conventions instead of generic commands. Read its
  agent instructions (CLAUDE.md / AGENTS.md) first. The security baseline in `running-autonomous-app-builds/house-stack.md` is assumed, not
  re-specified: the brief only adds what is specific to this app.
- When "what matters most" is a UX item, the deliverables must include screenshots the builder inspects. Do not
  leave them to the owner.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Brief lists tables, classes and endpoints | Move those to the contract. The brief keeps outcomes and tests. |
| "User-friendly", "performant", "secure" | Name the observable property and its number. |
| Only happy paths | Add the error, empty and unauthorised states, each with a test. |
| Tests run against mocks only | Require at least one suite against the real stack (Testcontainers / compose). |
| Owner feedback edited into the original text | Append it as a dated update. |
