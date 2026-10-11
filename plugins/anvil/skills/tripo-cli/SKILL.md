---
name: tripo-cli
description: Use when generating, texturing, rigging, retargeting or converting 3D models with Tripo3D (text or image to 3D) through the `tripo` CLI — checking access or credit balance, validating a request before spending credits, or handling a Tripo exit code or error.
---

# Tripo CLI

**The full instructions ship with the CLI, matched to the installed version. Read them first:**

    cat "$(npm root -g)/tripo-cli/skill/SKILL.md"

For details: `tripo docs --topic commands/<generate|process|make|account|task|batch|view>`,
`tripo docs --topic examples/game-asset`, `tripo docs --topic common-errors`. Never invent parameters.

## House rules on top of the CLI's

- **Allowed only as an acknowledged exception** in the run's rules: an asset class, a credit cap, and the texture
  policy (`docs/RULES.md`; running-autonomous-game-builds). Outside a run, ask before the first paid task.
- **The key comes from `TRIPO_API_KEY`.** It lives in a private file outside every repo. Never ask for it in chat,
  and never write it into a project.
- **`tripo doctor` before the first task.** A balance of 0 means Tripo is unavailable: exit code 4 tells the
  owner `tripo topup`.
- **Every paid command gets a `--dry-run --json` first.**
- **Each result JSON becomes a ledger row** (`task_id`, `credits_consumed`, `credits_breakdown`). The cap is hard.
- **The model is a base, never the shipped asset.** Prepare it in Blender by script: building-blender-assets-by-script
  → `generated-models.md` (riggability prompt, reject before rigging, normalisation, bone sides, sidecars).
