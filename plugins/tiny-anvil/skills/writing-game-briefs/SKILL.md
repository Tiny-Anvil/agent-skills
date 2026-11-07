---
name: writing-game-briefs
description: Use when turning a game, prototype, milestone or major feature idea into the document another agent or session will build from unattended, when a spec's requirements have no measurable pass criteria or no required captures, or when "done" for visual/feel work would otherwise be decided by "the owner looks at it later".
---

# Writing Game Briefs

## Overview

A brief is the **acceptance contract**: what the experience is, what matters most, what must exist, and the numbered tests that prove it. Every requirement is provable by a test with a number and an evidence file. Design and architecture stay the builder's job.

Brief → design/spec → plan. A brief that prescribes classes and units has become a spec, and it leaves out how the result will be judged.

## When to Use

- Kicking off a new game or prototype, a milestone, or a big feature in an existing game.
- Handing work to an agent or session that cannot ask questions.
- An existing spec only says "eyes-on by owner", or has requirements no test can fail.

**Not for:** a bugfix, or the implementation plan itself. Write that afterwards with a planning skill and keep the brief's test IDs in it.

## The Recipe

Fill `brief-template.md` (next to this file) in this order:

1. **The idea.** 2-4 sentences about the experience the player has, not the mechanism. Then **the real task**: the ambition, and what is left for the builder to design.
2. **What matters most.** 1-3 items that are judged first and weigh the most. Describe each in observable terms. Not "good handling" but "accelerates with weight, no jitter at any frame rate, no snap at transitions".
3. **Required.** Concrete, checkable bullets: engine and version, resolution and FPS floor, multiplayer behaviour, content counts, failure handling, and sound.
4. **Deliverables.** The paths, plus the list of captures, **from the real game driven by recorded or bot input**, not a staged scene. One capture per mechanic, state, transition and enemy type, plus one showcase.
5. **Tests.** IDs `<P>01..`, one row each: procedure, **measured quantity with unit**, threshold, evidence file. Always include:
   - the game launches with no script errors;
   - the core loop completes through input playback;
   - performance in the busiest view;
   - feel noise at two frame rates;
   - repeat and reset;
   - one test per custom mechanic.
6. **Traceability.** Each Required bullet → its test IDs. A bullet with no test is a wish.
7. **How it is judged.** The priority order. "Matters most" goes first.
8. **Updates.** Dated and verbatim, appended under the brief. Never rewrite the original.

## Test Patterns That Transfer

| Requirement | Measured as |
|---|---|
| No snap / smooth transition | largest camera rotation step between two rendered frames (deg) |
| No jitter | camera position second difference per frame, RMS / p99 (mm), at 60 and 144 FPS; rotation step with no input (deg) |
| Solid world | automated sweep into every edge and corner: never outside, 0 tunnelling events, never stuck > 2 s |
| Animation matches movement | ground speed vs the clip's authored speed, within 10 % |
| Performance | p50 / p95 frame ms after warm-up, busiest view, target resolution, capture off |
| Completable | start → win through input playback; duration stated |
| Multiplayer | second peer sees state X within N ticks; late joiner sees in-progress state |

## Rules

- **A test that only asserts your own constants proves nothing.** It must exercise the behaviour: drive input, measure output.
- Each test names its evidence type: log line, JSON, PNG, or clip with timestamps.
- Mark the rows that need human judgement ("the wow", feel in hand). Everything else gets automated.
- In an existing project, name its runners, gates and boot flags (for example its test kit and multiplayer rig) instead of generic commands. Read the project's agent instructions (CLAUDE.md, AGENTS.md or similar) first.
- When the "what matters most" items are visual or feel items, the deliverables must include captures the builder inspects. Do not leave them to the owner.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Brief lists units, classes and file layout | Move those to the spec. The brief keeps the outcomes and tests. |
| "Looks good", "feels responsive" | Name the observable property and its number. |
| No priority | Effort goes to plumbing. State what is judged first. |
| Captures taken from a test scene | Require captures from the real game boot, with the systems under test present. |
| Host feedback edited into the original text | Append it as a dated update. |
