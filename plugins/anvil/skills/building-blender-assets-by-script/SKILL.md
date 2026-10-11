---
name: building-blender-assets-by-script
description: Use when creating game assets in Blender by Python script for a Godot game (modular kits, props, physics props, first-person rigs, characters, baked textures), when preparing generated, purchased or mocap models for the game, or when Blender exports reach Godot with wrong axes, missing collision, lost attach points, materials the game should replace, or no record of where the source came from.
---

# Building Blender Assets by Script

## Overview

**The scripts are the source.** `.blend` and `.glb` files are build outputs, rebuilt from nothing with one command. Names carry the contract to Godot: roles for materials, `-colonly` for collision, `SOCKET_` for attach points. Every export is **re-imported in an empty scene** and reported. Every asset gets a preview render **that you open yourself**.

Working templates live in `templates/`, verified with Blender 4.2 → Godot 4.8:
- `kitlib_min.py`: module builder, metre UVs, AO to COLOR_0, sockets, export with explicit options.
- `build_example.py`: a kerb tile, a lamp with a light socket, and a bench physics prop.
- `verify_glb.py`: the re-import report, with a non-zero exit on rule violations.
- `check_kit.gd`: the Godot-side check of what the importer actually built.

## Layout

```
blender/<group>/  build_<group>.py → <group>.blend + game/assets/<group>/*.glb
                  build_all.py  (every build, then verify)   lib/  preview_*.py → previews/
                  README.md     (conventions + the generated verify table)
```

Run: `blender --background --factory-startup --python-exit-code 1 --python build_all.py`. Use one fresh Blender per step, and never a hand edit in a `.blend`. A Blender MCP is fine for looking and inspecting. Whatever you change has to go back into a script.

## The Contract

| Thing | Convention |
|---|---|
| Units / axes | metres; Blender Z-up; module front = Blender −Y = Godot +Z; Godot (x, y, z) = Blender (x, z, −y). **Check the project's forward axis**: some games use +Z forward, others −Z. |
| One GLB | **one** render mesh, named after the file, holding all its materials as surfaces; collision and sockets are its children |
| Collision | `<module>_<tag>-colonly` (trimesh, static) / `-convcolonly` (convex). Physics props use box or convex only. Godot imports them as **StaticBody3D**, so the game builds its RigidBody from those shapes. |
| Attach points | `SOCKET_<KIND>_<n>` empties. Identity rotation = faces the module front. Document every rotated socket's axis. |
| Materials | slot name = **role** (`ASPHALT`, `METAL_PAINT_TEAL` = prefix + variant). The game swaps each role for its own shader. An unknown role fails verify. |
| Extras | custom properties (`mass`, `kind`) arrive in Godot as `get_meta("extras")` |
| Origin | on the ground plane: footprint centre, or the tile edge for tiles |
| Texture sets | `<family>_albedo` (sRGB) / `_normal` (OpenGL +Y) / `_orm` (R = AO, G = roughness, B = metallic). The game maps a role to its set, and falls back to a procedural shader when a set is missing. |
| Portability | scripts resolve every path relative to themselves (`__file__`), and find tools through env vars (`GODOT`, `BLENDER`, else PATH). No absolute paths. |

## Quality Layer (what separates a kit from primitives)

- Bevel 0.2-2.5 cm with hardened normals. **Never bevel tile seam edges.** Leave tile ends uncapped: open boundary edges never bevel.
- UV0 is a box projection in metres. Screens, posters and decals use 0..1 per quad.
- Bake AO and cavity into COLOR_0 (`bake_ao`) so the game shader can put grime and wetness in corners.
- Real geometry for silhouette detail: ribs, lips, cables, greebles. Cull faces hidden by construction.
- A triangle budget per name prefix, enforced by verify (`--budgets`).
- Unchanged engine primitives or a plain box are a blockout, not a finished asset.

## Metadata Sidecars: Facts the Game Reads

Export a JSON next to each animated asset with what was **measured** in Blender, so the game never guesses:
- **Locomotion clips:** `speed_mps`, the root speed over one cycle. The game scales playback to the actual ground
  speed, so feet don't slide or run in place.
- **Attacks:** `hit_times`, the second the strike lands. Damage, sound and effects fire there.
- **Event timelines:** fire / eject / reload / equip. Effects and sound sync to the animation.
- **Sockets, height, facing, bone list.**

A clip whose `speed_mps` and gameplay speed differ by more than 10 % is a defect.

## Verify and Look

1. `verify_glb.py --dir … --roles … --budgets …`. It reports tris, materials, collision count, sockets **in Godot coordinates with their forward axis**, COLOR_0, extras, bones and action durations. Read the table and compare every socket's position and axis against intent.
2. `godot --headless --import`, then `check_kit.gd`. verify_glb shows how *Blender* reads the GLB. This shows what *Godot* built: one MeshInstance3D, StaticBody3D shapes (box/convex on `phys_`), known role names, `extras.mass`, socket position and forward.
3. For tiling pieces, add a numeric seam check on the **re-imported** mesh: matching vertices on both ends, within 1e-5. `kitlib_min.bake_ao` bakes a module alone. For a tile, add neighbour copies to its BVH first, or skip AO there; otherwise the AO steps at the seam.
4. Render previews (studio + game lighting, plus close up) and open each one. For animation, render **contact
   sheets from the re-imported GLB** (6 evenly spaced frames per clip, front and side): motion in one image, and
   it checks the exported data rather than the source scene. Then import into the game and capture it in context. Use iterating-with-look-checkpoints for both.
5. Test the negative path once: a wrong role must fail both checks.

## Models You Did Not Build (generated, purchased, mocap)

For text/image-to-3D services (Tripo3D, Meshy and others), allowed only as an exception the run's rules
acknowledge, follow `generated-models.md`. It covers the riggability prompt, rejecting before spending on a rig,
the hard credit cap and the task ledger.


- Normalise scale (to a real height), facing (module front) and origin (on the feet or ground). Delete stray objects. Imports often carry helper meshes.
- **Never trust bone side names.** Assign left/right from geometry after normalising, then rename through an explicit map.
- Retarget motion onto the project's rig. Check foot contact, and check speed against movement (within 10 %).
- Reject a bad generation **before** spending more on it: render it, inspect it, re-prompt.

## Provenance Ledger

Every external input gets one row in `credits.md`: file(s), source URL or task ID and prompt, author, license, download date, processing applied. Keep the originals beside it, outside the build. Fonts keep their license files next to them.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Tweaked in the GUI, never back-ported | The next rebuild loses it. Change the script. |
| Exporter defaults trusted | Pass every option. `export_glb` drops optional ones this Blender lacks, and **stops** when a critical one (axis, apply, extras, vertex colours) is missing: a renamed option silently drops COLOR_0. |
| Two modules in one `.blend` both own `SOCKET_LIGHT_0` | Blender renames one to `.001`. Park them as `name@module`, then restore at export (as `kitlib_min` does). |
| "Exported fine" judged from the export log | Re-import and read the report. Then look at it in the game. |
