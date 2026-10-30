# Run rules: <GAME>

Written at setup on <YYYY-MM-DD> from the owner's answers (verbatim in quotes). The run obeys this file and nothing
else. A change by the owner is appended under Changes; it never edits the text above it.

## Asset and sound sources

- Models/textures: "<answer>". <Expanded: what is allowed, and that every external item gets a row in credits.md.>
- Generative services: "<answer>". As acknowledged exceptions: <service> for <asset classes>, at most <N> credits,
  own textures kept: yes/no. Every task goes in the ledger (building-blender-assets-by-script → `generated-models.md`),
  and the cap is hard. The service's output is a base: the shipped asset is prepared by script in Blender.
- Audio: "<answer>".
- Engine primitives left unchanged are a blockout, never a final asset.

## Store page kit

"<answer>". AI key art: "<may propose it / never>"; generated only after the owner's yes, each time, logged in
`store/keyart/prompts.md`. Kit in `final/store/`, made with designing-game-store-pages.

## Quality bar

"<answer>". Two things matter most: <copied from the brief>.

## Stop rule

"<answer>". <Concrete: "stop when WALLET.json total_cost_usd >= 200", or "stop at 2026-10-09T08:00 local", or
"stop when the brief's tests pass with evidence, no major defect is open and the completion conditions hold">.
Until it holds: keep improving (the next-largest defect; then raise the bar).

## Reviews

"<answer>". At each one: freeze a look, present it, end the turn. Feedback goes into RUN.md → Feedback, verbatim and
numbered.

## Agents and loop

- Agents: "<answer>". <Expanded: the maximum concurrent helpers; workflows allowed yes/no; helpers spawned without a
  model override>.
- Loop: "<answer>". <The mechanism and its exact command, if it is a driver.>

## Talking to the owner

Only at a review, or on a real blocker: credentials, spending beyond the caps above, an irreversible action outside
the workspace, or a broken tool that changes scope. Every other choice is the builder's: decide it, and record it in
RUN.md → Decisions.

## Workspace

`game/` Godot project · `blender/` build scripts + .blend · `qa/` tests + raw logs · `looks/L###/` look records ·
`final/` the best verified build's captures + QA.md · `docs/` brief, these rules, kickoff · `prompts/` every input
as sent (append-only) · `credits.md` ·
`RUN.md` · `DELEGATION.md` (when helpers are used).

## Changes

<YYYY-MM-DD, verbatim, who.>
