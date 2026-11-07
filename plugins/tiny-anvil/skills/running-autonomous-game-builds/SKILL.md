---
name: running-autonomous-game-builds
description: Use when asked to build a whole game (or a large standalone feature) autonomously from an idea to a finished, verified result — "build it end to end", "make it as good as you can", "work on it overnight" — or when resuming such a run after a pause, a review or a context limit.
---

# Running Autonomous Game Builds

## Overview

An autonomous build has two phases.
- **Setup:** short, interactive, done once. Every rule the run will obey gets asked and written down.
- **The run:** long and silent. It follows those rules without asking, and stops only where they say. It never stops where it feels done.

This skill is the frame. The craft lives in the sibling skills: writing-game-briefs, godot-scenario-harness, iterating-with-look-checkpoints, building-blender-assets-by-script,
sourcing-and-processing-game-audio.

## The Prompt Record (`prompts/`, committed with the project)

Every input the run receives ("what the model was given, as sent") is stored
**verbatim, append-only, before it is acted on**:

| File | What |
|---|---|
| `prompts/00-request.md` | the owner's original request, with date, model ID, harness version (e.g. `claude --version`) and effort |
| `prompts/01-setup.md` | every setup question as asked, and every answer as given |
| `prompts/02-kickoff.md` | the exact kickoff text sent to the run's session, with that session's ID |
| `prompts/NN-<YYYY-MM-DD>-<kind>.md` | every later owner message: review feedback, change requests, mid-run updates (`kind` = review / update / instruction) |
| `prompts/driver.log` | every prompt the detached driver sends (timestamp, session, text), written by the driver |

Never edit a stored prompt. A correction is a new file. `RULES.md` and `RUN.md` quote from here, never the other
way round.

## Phase 1: Setup (ask, then never again)

0. **Store the request** in `prompts/00-request.md`, verbatim, before anything else.
1. **Ask the setup questions** (in Claude Code: AskUserQuestion), in two rounds. Questions and options are in `setup-questions.md`. They cover:
   - **What gets built:** asset sources, generative services (offer only the MCPs this session actually has), audio sources, quality bar.
   - **How the run is governed:** stop rule, review checkpoints, agent policy (lead alone, a few helpers, or
     unrestricted parallel workflows), and the loop that brings the lead back when it ends a turn.
   - **Follow-ups:** the cap amount when a budget or time cap is chosen, and the wallet install when a budget is chosen.
2. **Check the environment:** engine and DCC versions, a renderer that can capture, git.
3. **Scaffold the workspace:** `bash scaffold.sh <project-dir>` (next to this file) creates `game/ blender/ qa/ looks/ final/ docs/ prompts/` and the record templates.
4. **Write `docs/RULES.md`** from `rules-template.md`, with every answer verbatim. This file is the run's constitution.
   Store the questions and answers in `prompts/01-setup.md`.
5. **Write the brief** with writing-game-briefs. If "brief approval" was chosen as a review, stop here for it.
6. **Kick off.** In a long setup session, write `docs/KICKOFF.md` from `kickoff-template.md` and hand it over for a fresh session. Otherwise start the run directly.
   Either way, store the exact text the run starts from in `prompts/02-kickoff.md`.

## Phase 2: The Run

Follow the build loop in iterating-with-look-checkpoints:
1. Complete blockout.
2. Test the central mechanic in the running game.
3. Capture, inspect, test, fix the largest defects, freeze a look.
4. Repeat.

On top of that loop:
- **Decide, never ask.** Every open choice is yours. Write each one in `RUN.md` under Decisions: the options, the choice, why, and what would change it. Build so a reversal is cheap (data, not code).
- **Talk to the owner only at a configured review checkpoint, or on a real blocker.** A real blocker means: credentials, spending beyond what was granted, an irreversible action outside the workspace, or a broken tool that changes scope.
- **`final/` is always shippable:** the best verified build, its captures and `QA.md`. Update it after every verified improvement, so the run can be stopped at any moment.
- **Agents follow RULES.md.** Spawn workflows or many agents (subagents; in Claude Code: the Agent tool) only if RULES.md records the owner's opt-in.

## Delegation

- **Role workers by domain**, e.g. CITY, LANDMARKS, SURFACE, ENEMIES and FPS rig (asset domains), AUDIO, FX. Each
  owns a folder (`blender/<domain>/`, `game/assets/<domain>/`), its own README and its own credits file.
  Record every spawn and finish in `DELEGATION.md`.
- **Two contracts written by the lead before any worker starts:**
  - `docs/SPEC.md`: asset conventions (axes, naming, material roles, sockets, tri budgets); see
    building-blender-assets-by-script.
  - `docs/ARCHITECTURE.md`: the code card (coordinates, autoloads, the determinism rule, how to test, "only touch
    the files you own").
  Workers ask the lead for contract changes; they never edit the contracts themselves.
- **One integrator runs the game.** Workers build and verify in their own tool (Blender, audio pipeline) and
  never run the game. The lead integrates, runs the game, and inspects and tests **the combined build**. Separate
  passing worker reports prove nothing about the whole.
- **Workers inherit the lead's model.** Never pass a model alias: it can resolve to an older model. Use the
  explicit ID only when the owner's setup demands one.
- **How workers run:** spawned agents (one per role, continued by message for follow-up work; in Claude Code: the
  Agent tool and SendMessage) for long-lived domains, or workflow scripts for parallel fan-out (variants, verification sweeps). Use workflows only with the
  owner's opt-in in RULES.md.

## Stopping

| `docs/RULES.md` says | Stop when |
|---|---|
| completion conditions | the brief's tests pass with evidence, no major defect is open, and the completion conditions in iterating-with-look-checkpoints hold |
| budget $X | the wallet reads ≥ X: `docs/WALLET.json` under a detached driver, `~/.claude/wallets/<session>.json` in an interactive self-paced loop (Claude Code `/loop`; `wallet-statusline.md`). **Until then, keep improving.** |
| time cap | `date` passes the recorded end time. Until then, keep improving. |
| completion + cap | whichever comes first |

**Finish pass** (before any stop, and kept true from the first verified build onwards):
- `README.md`: what it is, how to open and play, controls, a credits summary, the license.
- `LICENSE.txt`.
- The editable sources next to the game (`blender/`).
- No absolute paths; tools found through env vars.
- A fresh-process launch from the README's own command.
- The store-page kit per RULES.md (if any), made with designing-game-store-pages from the final build: `final/store/`
  with `STORE-KIT.md`, `trailer_report.md` all PASS, and the AI-disclosure draft.

When the stop rule holds: finish `final/QA.md`, write the final report in `RUN.md`, write `done` into `docs/STOP`
(it ends a detached driver or a self-paced loop), then report.

- **If `docs/RULES.md` is missing** (setup was skipped), apply these defaults: stop on completion conditions, no budget, review at the final candidate only. Write in `RUN.md` that the defaults were applied. **Never invent a time box or a "stretch" of your own.**
- **"Keep improving" means:** take the next-largest defect from the latest look, or the weakest item in "what matters most", and run another look. When everything required passes, raise the quality bar.

## Review Checkpoints

When a configured checkpoint arrives:
1. Freeze a look.
2. Present the look ID, the captures, the test table and the open defects.
3. With a detached driver, write `review` into `docs/STOP` so the driver waits. The owner answers in
   `docs/FEEDBACK.md` and deletes `docs/STOP`.
4. **End the turn.**

When the owner replies (in the chat, or in `docs/FEEDBACK.md` under a driver):
- Store it first, verbatim, as `prompts/NN-<date>-review.md`.
- Record the feedback in `RUN.md` → Feedback, as numbered change requests quoting that file.
- Append any requirement changes to the brief's Updates.
- Continue the run.

## Resuming

Read these, in order: `docs/RULES.md`, `RUN.md` (current state, decisions, feedback), the latest `looks/L###`, `final/QA.md`. Then continue the loop where it stopped. Never restart from scratch.

## Red Flags

| Thought | Reality |
|---|---|
| "The MVP works, good place to stop" | Check the stop rule. Not met: next defect. |
| "I'll ask which option they prefer" | Decide, record it, build so it's reversible. |
| "I'll set myself a five-hour limit" | Limits come from RULES.md, never from you. |
| "Tests pass, so it's done" | Looks and the completion conditions decide that. |
| "I'll just check in quickly" | Only at configured checkpoints, or on a real blocker. |
