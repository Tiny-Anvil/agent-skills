# Passes and the visual review checklist

These are areas of work, not a fixed six-look sequence. Revisit any pass whenever a
test or a capture shows a problem in it.

## Passes, in the order that helps the task

| Pass | Inspect |
|---|---|
| Structure | scale, silhouette, camera, navigation, meaningful composition |
| Behavior | the main interaction, failure handling, repeatability |
| Surface | materials, edges, believable wear, lighting, readable contrast |
| Motion | animation, contact, trails, camera movement, audio feedback |
| Stress | alternate view or light, repeated interaction, reset, runtime performance |
| Finish | final QA, clean capture, portable project, honest limitations |

## Visual review: check every look for

- **Scale:** inspected at the final presentation scale **and** close up.
- **Repetition:** accidental repetition (tiling, cloned props, identical faces in a crowd).
- **Placement:** floating objects, missing contact, hovering feet or wheels.
- **Geometry:** broken normals, inverted faces, seams, z-fighting.
- **Clipping:** through walls, the viewmodel into geometry, characters into each other.
- **Light and atmosphere:** unmotivated glow, fog or bloom (each needs a source in the world).
- **Materials:** unreadable materials (everything the same roughness or value), and anything that reads as
  placeholder.
- **Composition:** a weak focal hierarchy, where nothing leads the eye to the subject or the interaction.

Add detail where it improves the intended view and story, not everywhere.
