---
name: iterating-with-look-checkpoints
description: Use when building or polishing anything in a game whose correctness is visible or felt (art, shaders, VFX, lighting, animation, camera, movement feel, UI, audio feedback); before reporting such work done or writing "eyes-on pending"; when comparing before/after a visual fix; or when successive visual fixes stop improving the same defect.
---

# Iterating With Look Checkpoints

## Overview

A **look** is an inspectable checkpoint. It is a build reference, plus the evidence you actually inspected, plus test results, plus the named defects and the next corrections. You work look by look: build, capture real output, inspect it, name concrete defects, fix a small coherent set, then freeze the look. A test that asserts your own constants shows nothing about what is drawn or felt.

## The Loop

1. **Target.** Write in the run record what the subject is, what matters most, and the hardest technical risk.
2. **Blockout first.** Get camera, scale and the central behaviour working in the **running game** before you spend effort on detail. Import assets early.
3. **Capture real output** from the real game boot, driven by input. A staged or extracted scene can silently leave out systems, so if you must stage, assert that the systems under test are present. In Godot, use the godot-scenario-harness skill.
4. **Inspect** against the evidence table below and the review checklist in `passes-and-review.md`. Open every
   image yourself. That file also lists the six passes (Structure → Behavior → Surface → Motion → Stress →
   Finish) that a run moves through and revisits.
5. **Test.** Run the brief's tests. Use the **same test case** before and after a fix.
6. **Name the largest defects** as anchored observations, in this exact form:
   `In <file> (frame/tick N): <what is wrong>. Change <X>. Expect <Y> in the next capture.`
   Fix a small coherent set and keep what already works.
7. **Freeze the look.** Fill `LOOK.md` (template next to this file) under `looks/L###/`, or wherever the project keeps records.
8. **Continue** while major defects remain. Stop on the completion conditions below.

## Evidence Required Per Claim

| Claim | Minimum evidence |
|---|---|
| Composition, material, lighting | stills at presentation scale **and** close up **and** one alternate view or light |
| Anything that moves (animation, VFX, wipers, transitions, camera) | a clip, or ≥ 8 frames spaced over at least one full cycle (a contact sheet of them is fine), plus a measured number where one exists. **One still is never evidence of motion.** |
| Feel (movement, camera, input response) | a per-frame log, with noise measured at two frame rates |
| Performance | p50 / p95 frame ms after warm-up, busiest view, target resolution, capture off |
| "It works" | test ID + evidence file + the **same build** as the captures |

## Rules

- **Never let presentation hide a failure.** Fog, depth of field, camera limits and prerecorded animation can all do it. Capture the honest view too (fog off, the far view, the worst light), and judge from that.
- Captures, QA and the report all name one build: commit hash plus a dirty flag. Evidence from another revision does not count.
- Looks are append-only. A regression gets a new look. An old look is never edited.
- A crash or a failed script is an attempt, not a reason to erase history. Keep its logs, restore the last stable
  checkpoint, and continue.
- Record owner/host feedback verbatim, with a timestamp, separately from your self-review.
- **Stagnation:** if two looks fail to improve the same defect, record the evidence and change approach. Simplify the implementation behind the effect, or isolate it in a minimal repro. Never delete a required feature to get a pass.
- Write "needs owner eyes-on" only for what capture cannot show: feel in the hand, force feedback, the "wow", taste calls. Name which item, and why capture can't show it.

## Completion Conditions

- The required functionality exists and has been exercised.
- The required views and the temporal tests have been inspected.
- Every major defect is either fixed or listed as unresolved. An unresolved major defect means the work is incomplete.
- The saved build launches from the written command in a **fresh process** with no dependence on unsaved editor or DCC state. Verify it from the command line. Never close, reopen or launch an editor that the owner keeps open.
- The final QA (`QA.md`) and the final captures reference the same build.
- Someone else can reproduce the core result from the written instructions.

## Records

Use the project's location if it names one. Otherwise:
- `RUN.md`: intent, launch, look history, current findings.
- `looks/L001/...`: one record per look.
- `final/`: always the best verified build's captures and QA.

If the repo can't hold binaries (LFS full or not allowed), keep the images outside git. Record their paths and hashes in the look.

## Delegating a Pass

Give the helper an **architecture card** containing:
- coordinates and axes;
- autoloads and entry points;
- the determinism rule;
- the files it owns;
- the exact test and capture commands.

When it finishes, integrate the work, then inspect and test **the combined build** yourself. Separate passing reports do not show that the whole works. Respect the project's limits on agent count.

## Red Flags

- "The unit tests pass, so the effect works."
- "The fog hides it at default settings."
- "I checked a screenshot" (when the thing moves).
- "Looks good" with no file or frame named.
- Report says done, and the evidence comes from an earlier build.
