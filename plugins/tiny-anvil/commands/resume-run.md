---
description: Resume an autonomous app or game run in this directory after a pause, a review or a context limit.
argument-hint: [owner feedback, optional]
disable-model-invocation: true
---

Find the run in this directory: `data/run/docs/RULES.md` is an app run (invoke the tiny-anvil:running-autonomous-app-builds skill); `docs/RULES.md` with a `looks/` folder is a game run (invoke the tiny-anvil:running-autonomous-game-builds skill). Follow the skill's Resuming section exactly. If there is no run, say so and stop.

If text follows, it is an owner message: store it verbatim in the run's prompt record before acting on it.

$ARGUMENTS
