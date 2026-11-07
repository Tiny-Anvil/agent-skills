# Tiny Anvil agent skills

The Tiny Anvil marketplace. Its first plugin, **tiny-anvil**, holds agent skills for building **whole apps and games autonomously**, where "done" means proven by evidence and not
"it compiled and the agent felt finished".

You describe what you want. The agent asks you a short round of setup questions once: where it runs, how far it may
deploy, when to stop, where to pause for you. It writes the answers down as the run's rules and turns your idea
into a brief with numbered, measurable tests. Then it builds, quietly, increment by increment: it runs the real
thing, tests it, screenshots every screen, opens those screenshots, names the biggest defects and fixes them,
until the stop rule you chose holds. At any moment there is a best verified build you can look at.

Two tracks share that frame:

- **Apps:** a .NET 10 API + Vue 3 web app with Postgres, Playwright end-to-end tests, GitHub Actions gates, a
  versioned container image, and a deploy you can roll back (GitOps PR, Azure Container Apps, or your own).
- **Games:** a Godot 4 game with script-built Blender assets, optional Tripo3D models and processed game audio,
  judged by captures, bot scenarios and measured feel.

The skills are written for [Claude Code](https://docs.claude.com/en/docs/claude-code) and work as plain
[Agent Skills](https://agentskills.io) in other agents too (see [Other agents](#other-agents-and-models)).

## How it works

```
  you: "/tiny-anvil:build-app <idea>"
        |
  1. Setup (once, interactive)    request stored verbatim -> setup questions -> tools checked
        |                         -> workspace scaffolded -> RULES.md (the run's constitution)
  2. Brief                        idea -> BRIEF.md: what matters most, what is required,
        |                         numbered tests with thresholds and evidence files
  3. The run (long, silent)       walking skeleton end to end first, then the central flow, then:
        |                           run the real stack -> test -> capture -> inspect -> fix -> freeze
        |                           ... decisions recorded, never asked; pauses only at your reviews
  4. Stop                         only when the stop rule holds (completion, budget or time),
                                  after a finish pass: docs, fresh clone, final QA with evidence per test
```

A few ideas carry the whole thing:

- **Ask once, then decide.** Every question that needs you is asked at setup. During the run the agent decides,
  writes down why in `RUN.md`, and builds so the decision is cheap to reverse.
- **Evidence over claims.** Every requirement has a test ID, a measured number and an evidence file from the same
  commit. "Looks good" without a file, screen or test ID does not count.
- **Look at the output.** Screenshots at desktop and phone width (or game captures) are taken from the real build
  and opened, every increment. Automation passes plenty of things a glance catches.
- **The stop rule is yours.** The agent never stops because it feels done, and never invents its own time box.
- **Gates for anything outside the workspace.** Pushing branches is fine; deploying beyond the test environment,
  deleting remote things or touching secrets waits for you.

## Installation

### Claude Code

```
/plugin marketplace add Tiny-Anvil/agent-skills
/plugin install tiny-anvil@tiny-anvil
```

The first line adds the Tiny Anvil marketplace (this repo); the second installs the **tiny-anvil** plugin from it.
Check it worked: `/help` lists the `/tiny-anvil:*` commands. Update later with `/plugin marketplace update tiny-anvil`.

### Other agents and models

Copy `plugins/tiny-anvil/skills/*` into your agent's skills directory; to use another model inside Claude Code, point it at an
Anthropic-compatible endpoint. Details, and what does not carry over: [docs/other-agents.md](docs/other-agents.md).

## Quick start

```
/tiny-anvil:build-app A planner for a sports club: members sign up for training slots, coaches see who is
coming. Phones first. Make it as good as you can.
```

```
/tiny-anvil:build-game A small 3D arena game in Godot: the player dodges and pushes enemies off a floating
platform. Make it as good as you can.
```

You do not need the commands: "build me ... end to end" or "work on this overnight" triggers the right skill from
its description. Answer the setup questions, approve the brief if you asked to, and let it run.

| Command | What it does |
|---|---|
| `/tiny-anvil:build-app <idea>` | Start an autonomous web app build (setup first) |
| `/tiny-anvil:build-game <idea>` | Start an autonomous game build (setup first) |
| `/tiny-anvil:write-brief <idea>` | Only write the brief with measurable tests, no build |
| `/tiny-anvil:resume-run [feedback]` | Continue a run after a pause, a review or a context limit |
| `/tiny-anvil:deploy <app> <env> <version>` | Put a published image version on an environment and verify it there |
| `/tiny-anvil:listing-images <app>` | Make an app's App Store / Google Play screenshots, link preview and PWA install screenshots |
| `/tiny-anvil:store-page <game>` | Make a game's Steam / itch.io kit: capsules, library art, screenshots, gameplay trailer |

**Unattended overnight:** at setup, choose the detached driver as the loop. The kickoff template contains a small
`drive.sh` that keeps re-prompting the session until the stop rule holds, waits at your review checkpoints
(`STOP` / `FEEDBACK.md` files), and tracks spend for a budget cap.

## What's inside

### App track (.NET + Vue) — [docs/app-builds.md](docs/app-builds.md)

| Skill | What it gives you |
|---|---|
| **running-autonomous-app-builds** | The frame: setup questions, rules file, deploy gates, delegation, stop rules, review checkpoints, resuming. Holds `house-stack.md`, the stack defaults. |
| **writing-app-briefs** | The acceptance contract: what matters most, required behaviour, numbered tests with thresholds and evidence, traceability. |
| **iterating-with-verified-increments** | The build loop: increment, run the real stack, test, inspect, name anchored defects, fix, freeze. Plus a review checklist. |
| **dotnet-vue-test-harness** | Testcontainers API tests, real-JWT scope tests, guard tests, Vitest, Playwright flows and captures on a throwaway stack, load numbers, preview links for testers. |
| **github-cicd-dotnet-vue** | PR gates (build, tests, bypass guards), security scan, licence check, Dependabot, multi-arch image to a registry on a GitHub release. |
| **deploying-container-images** | Image version to an environment through a GitOps PR, Azure Container Apps or your own mechanism, and verification on the environment itself. |
| **designing-app-listing-images** | Store and web listing images from the app's real screens: copy first, 18 styles, three directions, exact-size exports without alpha; in a run, web images wired into the app. Based on [aso-shots](https://github.com/ceorkm/aso-shots) (MIT). |

### Game track (Godot + Blender) — [docs/game-builds.md](docs/game-builds.md)

| Skill | What it gives you |
|---|---|
| **running-autonomous-game-builds** | The frame for games: setup questions, rules file, workspace scaffold with a Godot baseline, budget wallet, stop rules, reviews. |
| **writing-game-briefs** | The acceptance contract for a game, including required captures and feel tests. |
| **iterating-with-look-checkpoints** | Look by look: capture the real game, inspect, test, name the largest defects, fix, freeze. |
| **godot-scenario-harness** | Unattended captures, bot scenarios, tick-exact input record/playback, measured jitter, snap, tunnelling, stuck and frame time. |
| **building-blender-assets-by-script** | Assets built by Blender Python with naming contracts for materials, collision and sockets, verified on re-import, with provenance. |
| **sourcing-and-processing-game-audio** | Sounds from free libraries with licence evidence, rebuilt from recipes with measured loudness, peaks and seamless loops. |
| **tripo-cli** | Tripo3D text/image-to-3D through its CLI, under a hard credit cap, with a dry run before every paid task. |
| **designing-game-store-pages** | Steam and itch.io store kit from the real game: capsules and library art from staged renders, gameplay screenshots, a trailer cut by recipe and checked against Valve's spec, the AI-disclosure draft. |

## Safety

The skills are designed for long, unattended runs, so the guard rails are part of the design:

- Secrets are referenced **by name only**; the owner creates every value. A missing secret stops the run.
- Changes to a GitOps repo go through a **pull request**. Higher environments, full releases, deleting anything
  remote and repo settings are **review checkpoints**, never done alone. Device installs are never done.
- The e2e suite and previews run on **their own throwaway copy** of the stack, never on your running data.
- The detached driver uses an **allow-list** of commands in permission mode `auto`, never "bypass permissions".
- **No AI attribution** in commits, PRs or release notes, whatever a harness default says.

Still: an autonomous agent with shell access acts with your credentials. Run it in a project directory you are
happy for it to change, give it tokens scoped to that project, and read the rules file before the run starts.

## Customising

The defaults are opinionated, and meant to be yours after a fork:

- **Stack and conventions:** [`house-stack.md`](plugins/tiny-anvil/skills/running-autonomous-app-builds/house-stack.md) for apps; the
  scaffold and asset contract for games.
- **Setup questions, rules and kickoff:** the templates next to each `running-autonomous-*` skill.
- **Brief and record templates:** next to the brief and iterating skills.
- **A project's own instructions always win:** its `CLAUDE.md` / `AGENTS.md`, `.claude/guidelines/` and
  `docs/features/` override the skills' defaults.

Per-track details: [app builds](docs/app-builds.md#customising), [game builds](docs/game-builds.md#customising).

## Repository layout

```
.claude-plugin/marketplace.json   the Tiny Anvil marketplace: lists the plugins below
plugins/tiny-anvil/
  .claude-plugin/plugin.json      the tiny-anvil plugin
  skills/                         15 skills, one folder each: SKILL.md + templates and record files
  commands/                       5 short commands, each invoking a skill
docs/                             app-builds.md, game-builds.md, other-agents.md
scripts/validate.sh               the checks CI runs
```

More plugins go next to `tiny-anvil` under `plugins/`, each with its own entry in `marketplace.json`.

## Contributing

Issues and pull requests are welcome: a skill that misfires, a template that is out of date, a lesson from a run.

- Keep skills terse and checkable: rules an agent can follow, red flags it can recognise, templates it can copy.
- A change in behaviour comes with the evidence that prompted it (a run record, a failing case).
- Run `bash scripts/validate.sh` before opening a PR; CI runs the same.
- Conventional Commits; no AI attribution lines.

See [RELEASE-NOTES.md](RELEASE-NOTES.md) for what changed.

## License

[MIT](LICENSE). `designing-app-listing-images` builds on [aso-shots](https://github.com/ceorkm/aso-shots) by
ceorkm (MIT); its notice is in `NOTICE-aso-shots` next to the skill.
