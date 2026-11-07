# Generated models (Tripo3D and similar) inside a self-authored project

A text/image-to-3D service may be used **only when the run's rules acknowledge it** as an exception to
"self-authored". A typical rule: "enemy characters from Tripo, at most 300 credits, every task listed".
The model is a **base**, never the asset: it is checked, fixed and prepared by script in Blender like everything
else, and the game ships the prepared result.

## Before the first task

- **The tool:** Tripo's CLI, `npm install -g tripo-cli` (the `tripo` binary, which also has an agent skill:
  `tripo-cli`, with every flag documented in `tripo docs --topic commands/<name>`). Never invent parameters.
- **Access works.** The API key is in the environment as `TRIPO_API_KEY`, loaded from a private file outside every
  repo (`chmod 600`), never written into the project. `tripo doctor` checks key, region and reachability, and
  `tripo balance --json` returns `{"balance","frozen"}`. Without the CLI the REST equivalent is
  `curl -s -H "Authorization: Bearer $TRIPO_API_KEY" https://api.tripo3d.ai/v2/openapi/user/balance`
  (verified 2026-10-08). Record the balance in the ledger.
- **Two wallets** (observed 2026-10-08: the website showed 200 free-plan credits while the API key read 0):
  - the **API platform** wallet: the key, `tripo balance`, bought with `tripo topup` (apiplatform.tripo3d.ai);
  - the **Studio** (website) plan's credits, which the API cannot spend.

  Zero API balance means the API path is unavailable, whatever the rules allow. Say so at setup.
- **The Studio path (manual):** the owner generates on the website with Studio credits and drops the GLB (+ preview)
  into `generated/<name>/`. Log one ledger row per model with source `Studio (manual)`, the page or task URL, the
  credits shown, and the plan. From there the pipeline is the same.
- **License follows the plan.** Free-plan Studio output is public and CC BY 4.0 (commercial use allowed **with
  attribution**: the credits must name Tripo). Paid plans give private models with no attribution needed. Record
  the plan in the ledger and in credits.md.
- **The scope comes from RULES.md:** which asset classes (e.g. characters only), the credit cap, and whether the
  service's own textures may be kept. Keeping them works well when grime and emissive masks are derived from
  them by script.
- **Plan the spend.** Tripo API prices (developers.tripo3d.com/en/pricing, 2026-10-08):
  - 1 credit = $0.01;
  - text-to-3D 10, or 20 textured;
  - image-to-3D 20, or 30 textured;
  - texture 10-30;
  - auto-rig 25;
  - retarget 10 per animation;
  - the riggability check is free.

  A rigged textured character costs about 45 credits. In one run, three enemies plus two rejects came to 175.

## The task loop (one character)

1. **Prompt for riggability:** "full body game character, `<what it is, its silhouette feature>`, standing in a
   strict T-pose, arms straight out horizontally to the sides, fingers open, legs straight, plain background".
   Name the defining feature explicitly ("right forearm is a thick cylindrical cannon instead of a hand").
2. **Validate, then generate:** run `tripo make "<prompt>" --for game-pc --json --dry-run` (no credits, shows the
   model and every planned call), then the same command without `--dry-run`, with `--yes`. Keep the result JSON
   (`task_id`, `credits_consumed`, `credits_breakdown`, `output_dir`, `files`, `preview`). Store the raw outputs in
   `generated/<name>/` (model, `preview.png`, `task.json`). Never overwrite.
   - **Exit 4** (insufficient credits): stop generating, and record that the asset class falls back to
     self-authored.
   - **Exit 6** (task failed, auto-refunded): log it and retry once.
3. **Look at `preview.png`, then render the imported GLB in Blender** to inspect it **before spending on rigging**. Missing the defining feature means re-prompt
   (log the reject; keep the file, unused). A small missing part (a blade) can be added as your own geometry
   instead.
4. **Riggability check** (free), then **auto-rig** (biped). With the CLI: `tripo make @last --then rig-check,rig --json --yes`,
   or pipe it: `tripo make ... --json | tripo anim rig --json`.
5. **Normalise in Blender by script:**
   - delete stray objects (Tripo's rig GLB carried an `Icosphere`);
   - rotate to the module front (raw files faced +X);
   - scale to the real height (raw files were 1 m tall);
   - put the feet on the origin.
6. **Bones:** never trust side names. A Tripo rig named a LEFT leg `Right_Limb`, and many bones were bare `bone_N`.
   Assign sides from geometry after normalising, then rename through an explicit per-model map.
7. **Motion** (Tripo's own retarget presets, `tripo anim retarget --param animation=preset:<walk|…>`; or Mixamo or
   mocap, when the rules allow it):
   - use a standard skeleton (Y Bot), FBX, 30 fps, no skin;
   - for locomotion, download the in-place clip **and** its root-motion twin, using the twin only to measure
     `speed_mps` for the sidecar;
   - retarget onto the model's rig, with leg IK and a ground clamp;
   - export the hit times;
   - render contact sheets from the re-imported GLB.

## The ledger (in `credits.md` / `credits/<domain>.md`)

| # | UTC | Task ID | Type (model version, options) | Prompt / input | Credits | Running total | Note (USED / rejected: why) |
|---|---|---|---|---|---|---|---|

- Fill the rows from each run's result JSON (`task_id`, `type`, `credits_consumed`; one row per
  `credits_breakdown` entry). Record the balance before the first task and after each batch (`tripo balance`), and
  check the sum against `tripo usage`.
- **The cap is hard.** At the cap, no more tasks: re-use, fix in Blender, or build the part yourself.
- Under the motion table, list every clip: name, description, product ID, in-place or root-motion, local file,
  used as.
