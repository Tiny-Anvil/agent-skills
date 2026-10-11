---
name: running-autonomous-app-builds
description: Use when asked to build a whole web application or a large standalone feature (.NET backend, Vue.js frontend, GitHub CI/CD) autonomously from an idea to a finished, verified, deployed result — "build it end to end", "make it as good as you can", "work on it overnight" — or when resuming such a run after a pause, a review or a context limit.
---

# Running Autonomous App Builds

## Overview

An autonomous build has two phases.
- **Setup:** short, interactive, done once. Every rule the run will obey gets asked and written down.
- **The run:** long and silent. It follows those rules without asking, and stops only where they say. It never
  stops where it feels done.

This skill is the frame. The craft lives in the sibling skills:
- writing-app-briefs: the acceptance contract (numbered tests with thresholds and evidence).
- iterating-with-verified-increments: the build loop (increment → run → test → inspect → fix → freeze).
- dotnet-vue-test-harness: how the tests, UI captures, load runs and preview copies are built and run.
- github-cicd-dotnet-vue: CI gates and container image delivery to a registry.
- deploying-container-images: getting a published image version onto an environment, and proving it runs there.

House defaults (stack, security, tests, CI, containers, commit rules) are in `house-stack.md` next to this file.
Read it at setup. The project's own CLAUDE.md / AGENTS.md, `.claude/guidelines/` and `docs/features/` override it.

**Tool names.** Where this skill set names a Claude Code tool (AskUserQuestion, subagents, workflows, `/loop`), it
means the intent; another agent uses its own equivalent, or asks in plain text.

**Where the run records live.** Plans and specs never go under the repo's `docs/`, so every record of the run
lives in **`data/run/`** (gitignored, local to the build machine). All record paths in these skills
(`docs/RULES.md`, `prompts/`, `increments/`, `final/`, `qa/`, `RUN.md`, `DELEGATION.md`) are **relative to
`data/run/`**. The only run output committed to the repo is code, tests, workflows, the README, the configuration
reference and the feature and convention docs.

## The Prompt Record (`data/run/prompts/`)

Every input the run receives is stored **verbatim, append-only, before it is acted on**:

| File | What |
|---|---|
| `prompts/00-request.md` | the owner's original request, with date, model ID, agent version and effort |
| `prompts/01-setup.md` | every setup question as asked, and every answer as given |
| `prompts/02-kickoff.md` | the exact kickoff text sent to the run's session, with that session's ID |
| `prompts/NN-<YYYY-MM-DD>-<kind>.md` | every later owner message (`kind` = review / update / instruction) |
| `prompts/driver.log` | every prompt the detached driver sends, written by the driver |

Never edit a stored prompt. A correction is a new file. `RULES.md` and `RUN.md` quote from here, never the other
way round.

## Phase 1: Setup (ask, then never again)

0. **Store the request** in `prompts/00-request.md`, verbatim, before anything else.
1. **Ask the setup questions** (in Claude Code: AskUserQuestion), in two rounds plus follow-ups
   (`setup-questions.md`). They cover:
   - **What gets built and where it runs:** repo, database, auth, hosting and environments, quality bar.
   - **How the run is governed:** stop rule, review checkpoints, agent policy, the loop, and **the deploy gates**.
2. **Check the environment** (`setup-questions.md` → Environment check): .NET SDK, Node, Docker, Playwright browsers,
   and, only when the answers need them, `gh` auth and access to the deploy target. A missing tool is fixed at
   setup, never discovered mid-run.
3. **Collect what only the owner can give**, now: repo secrets and variables, registry access, the deploy target
   (GitOps repo path, cloud resource names), how secrets are created, OIDC client IDs. Record **names** in
   RULES.md, never values.
4. **Scaffold the workspace:** `bash scaffold.sh <project-dir>` creates the record folders and templates (never
   overwrites). Then create the solution itself (`house-stack.md` → Repo layout).
5. **Write `docs/RULES.md`** from `rules-template.md`, with every answer verbatim. This file is the run's
   constitution. Store the questions and answers in `prompts/01-setup.md`.
6. **Write the brief** with writing-app-briefs. If "brief approval" was chosen as a review, stop here for it.
7. **Kick off.** In a long setup session, write `docs/KICKOFF.md` from `kickoff-template.md` and hand it over for a
   fresh session. Otherwise start the run directly. Store the exact starting text in `prompts/02-kickoff.md`.

**Local-only runs** (hosting "local only", no remote): skip the deploy questions, mark CI-run and deploy test rows
N/A in the brief (the workflows are still written and linted), and leave `gh` out of the environment check.

## Phase 2: The Run

Follow the loop in iterating-with-verified-increments:
1. **Walking skeleton first:** API + database + frontend + CI, end to end, with one real request flowing through
   all of them and the pipeline green. Deploy it to the first allowed environment as early as the gates allow.
2. Build the central user flow and its tests.
3. Increment by increment: run, test, capture, inspect, fix the largest defects, freeze.
4. Repeat.

On top of that loop:
- **Decide, never ask.** Every open choice is yours. Write each one in `RUN.md` under Decisions: the options, the
  choice, why, and what would change it. Build so a reversal is cheap.
- **Talk to the owner only at a configured review checkpoint, or on a real blocker.** A real blocker means: a missing
  credential or permission, spending beyond what was granted, an action RULES.md gates (see Deploy gates), an
  irreversible action outside the workspace, or a broken tool that changes scope.
- **`main` (or the run's branch) is always releasable:** CI green, the best verified increment, `final/QA.md`
  current. Update `final/` after every verified improvement so the run can stop at any moment.
- **Agents follow RULES.md.** Spawn helpers or workflows only as RULES.md records the owner's opt-in.

## Owner Messages During the Run

Owners steer mid-run (a language, a platform, "why are we polling?"). For each message:
1. Store it verbatim as `prompts/NN-<date>-<kind>.md` before acting.
2. Answer it right away, in a few lines.
3. Append a dated, verbatim update to the brief's Updates, with any new or changed test IDs.
4. Ask back (AskUserQuestion) **only** when the message opens a real scope choice the rules cannot settle
   (e.g. "can families be managed?" → finish as-is first, or widen scope now?). Otherwise decide and record it.

## Deploy Gates

Pushing, releasing and deploying publish things outside the workspace. RULES.md records, per action, whether the
run may do it alone. The defaults when RULES.md is silent:

| Action | Default |
|---|---|
| Commit to the run's branch, push it, open PRs in the app repo | allowed |
| Run CI, create **pre**releases (images for a test environment) | allowed |
| Change a GitOps repo | **PR only**, never a direct push to its default branch |
| Merge a deploy PR for the first (test/dev) environment | only if RULES.md allows it |
| Higher environments (acc, prod), full releases, deleting anything remote, changing repo settings or secrets | **never alone**: a review checkpoint |
| Touching other apps' deployment files, shared cluster infrastructure, ports already allocated | never |
| Installing on devices (`adb install`, TV SDK installers, ...) | never: the owner deploys to devices |

A deploy is verified only by checking the deployed thing (deploying-container-images → Verifying a deploy), never
by a green pipeline alone.

## Delegation

- **Role workers by layer:** API, FRONTEND, INFRA (CI + deploy). Each owns its folders and records each spawn and
  finish in `DELEGATION.md`.
- **Two contracts written by the lead before any worker starts:**
  - `docs/CONTRACT.md` + `openapi.json`: the API contract (endpoints, DTOs, error shape, auth policies). The frontend
    builds against it; the API proves it with contract tests.
  - `docs/ARCHITECTURE.md`: the code card (layout, conventions from `house-stack.md`, how to run and test, "only
    touch the files you own").
  Workers ask the lead for contract changes; they never edit the contracts themselves.
- **One integrator runs the whole system.** Workers run their own unit tests. The lead runs the combined stack, the
  end-to-end tests and the pipeline. Separate passing worker reports prove nothing about the whole.
- **Workers inherit the lead's model.** Never pass a model override.

## Stopping

| `docs/RULES.md` says | Stop when |
|---|---|
| completion conditions | the brief's tests pass with evidence, no major defect is open, the deployed environment is verified, and the completion conditions in iterating-with-verified-increments hold |
| budget $X | the wallet reads ≥ X (`data/run/docs/WALLET.json`, written by the driver). **Until then, keep improving.** |
| time cap | `date` passes the recorded end time. Until then, keep improving. |
| completion + cap | whichever comes first |

**Finish pass** (before any stop, and kept true from the first verified increment onwards):
- `README.md`: what it is, how to run it locally (one command), how to test, how it deploys, configuration (names
  only, pointing at `docs/configuration.md`), the license.
- `docs/configuration.md` current; `appsettings.example.json` and `.env.example` files list every setting.
- `docs/features/<feature>.md` for every feature built, infrastructure included, plus the index in
  `docs/features/README.md`; the convention docs (`house-stack.md` → Where things go), each claim checked
  against the code.
- `LICENSE` and a third-party licence check.
- No secrets, tokens or real connection strings anywhere in git.
- A **fresh clone** builds, tests and starts from the README's own commands.
- CI green on the final commit; the deployed environment (if in scope) serves that commit's version.

When the stop rule holds: finish `final/QA.md`, write the final report in `RUN.md`, write `done` into `docs/STOP`
(it ends a detached driver or a loop), then report.

- **If `docs/RULES.md` is missing** (setup was skipped), apply these defaults: stop on completion conditions, no
  budget, the deploy-gate defaults above, review at the final candidate only. Record that in `RUN.md`.
  **Never invent a time box or a "stretch" of your own.**
- **"Keep improving" means:** take the next-largest defect from the latest increment, or the weakest item in "what
  matters most", and run another increment. When everything required passes, raise the bar (error states,
  accessibility, performance, observability).

## Review Checkpoints

When a configured checkpoint arrives:
1. Freeze an increment.
2. Present the increment ID, the commit, the CI run link, the deployed URL (if any), screenshots, the test table and
   the open defects. If the checkpoint is a gated action, state exactly what you want to do and its command.
3. With a detached driver, write `review` into `docs/STOP` so the driver waits. The owner answers in
   `docs/FEEDBACK.md` and deletes `docs/STOP`.
4. **End the turn.**

When the owner replies: store it verbatim as `prompts/NN-<date>-review.md`, record numbered change requests in
`RUN.md` → Feedback, append requirement changes to the brief's Updates, and continue.

## Resuming

Read, in order: `docs/RULES.md`, `RUN.md` (state, decisions, feedback), the latest `increments/I###`,
`final/QA.md`, `git log -10`, the latest CI run. Continue where it stopped. Never restart from scratch.

## Red Flags

| Thought | Reality |
|---|---|
| "The MVP works, good place to stop" | Check the stop rule. Not met: next defect. |
| "I'll ask which option they prefer" | Decide, record it, build so it's reversible. |
| "CI is green, so it's deployed" | Check the deployed version endpoint. |
| "I'll just push this tag / merge to prod quickly" | Check the deploy gates. Gated: review checkpoint. |
| "I'll put the token in the workflow for now" | Never. Missing secret = real blocker. |
| "I'll set myself a five-hour limit" | Limits come from RULES.md, never from you. |
| "The harness wants a Co-Authored-By line" | house-stack.md → Git: no AI attribution, it wins. |
