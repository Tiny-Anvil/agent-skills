# AI disclosure draft: <GAME>

For Steam's content survey, section "Generative Artificial Intelligence Content"
(https://partner.steamgames.com/doc/gettingstarted/contentsurvey). Drafted on <YYYY-MM-DD> from the logs below; the
owner reviews and submits it. Every row cites the log it came from. If nothing AI-made ships, say exactly that.

Sources read: the ledger in `credits.md` / `credits/<domain>.md` (generated models with service and task),
`audio_src/*.json` (AI mark), `store/keyart/prompts.md` (AI key art, with the owner's yes), RULES.md (what
generation was allowed).

## Made by an AI agent (tiny-anvil-built games: keep this section, then let the owner decide)

<GAME> was built by an AI coding agent working under the developer's direction and review: its code, its levels or
layouts, its script-built models and textures, and its UI were authored by the agent. <Adjust to what the run's
RULES.md and RUN.md show; name what a human made by hand.>

Why it is here: Valve's survey is about content that ships and is consumed by players, and says efficiency gains
from AI tools during development are not its focus. Levels, models and UI made by an agent are content players
consume, so this draft discloses them; AI-assisted code on its own may fall under the efficiency remark. The
owner reads Valve's current wording and decides what to submit. Do not delete this section silently.

## Pre-generated content (made during development, ships with the game or its store page)

| What | Where it ships | Service / model | How it was used | Human work on it | Log |
|---|---|---|---|---|---|
| <e.g. 3 enemy character meshes> | in game | <Tripo3D, model id> | <image-to-3D from our concept, then retopology/rig> | <cleaned, re-textured by script> | `credits.md` rows <n> |
| <e.g. capsule key art> | store page | <provider, model id> | <painted over our in-game render (--ref)> | <composed with our logo> | `store/keyart/prompts.md` |

## Live-generated content (made while the game runs)

<None. / What, which service, and the guardrails that stop unlawful or infringing output.>

## Not AI-generated

Screenshots and the trailer are captured from the game itself. <List only what no AI made: hand-made assets,
real recordings from libraries, purchased packs. In an tiny-anvil-built game, "procedural" or "made by script" means the
agent wrote the script: that belongs in the first section, not here.>

## Short text for the survey field

<Two or three sentences in plain words, e.g. "The game was developed with an AI coding agent that wrote its code
and built its levels and models by script, under our direction and review. Some enemy models started as
AI-generated meshes (Tripo3D). No AI content is generated while the game runs.">
