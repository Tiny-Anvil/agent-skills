# <NAME>: <one-line pitch>

Brief version <n>, <YYYY-MM-DD>. Read with the project's CLAUDE.md / AGENTS.md (or rules file).

## The idea

<2-4 sentences: what the player experiences, from their point of view.>

**Your real task:** <the ambition, e.g. "make this as spectacular as possible">. Everything below
"Required" is yours to design: <list the open design space>.

## What matters most

1. **<Item>.** <observable description: what it feels/looks like when right, what must never happen>.
2. **<Item>.** <...>

## Required

- **Platform:** <engine + version, renderer, resolution, FPS floor, single/multiplayer>.
- **<Core behaviour>:** <concrete, checkable>.
- **<Content>:** <counts, variety>.
- **Failure handling:** <what happens on death/abort/disconnect/reset>.
- **Sound:** <which events need sound; source rules>.
- **Multiplayer:** <who is authoritative; what other peers and late joiners must see>.
- **Custom mechanics:** at least <n> of the builder's own, each described in the run record: what it
  does, why it is fun, how it is tested.

## Deliverables

- `<game path>`: runnable project; the run record gives the exact launch command and controls.
- `<asset source path>`: editable sources and build scripts for every authored asset.
- `credits.md`: every external asset, clip, sound and font, with source, author, license and date.
- Captures (target resolution, from the real game driven by recorded/bot input, not a staged scene):
  - <one per view / mechanic / state / transition / enemy type>;
  - a clean capture of the full loop, start to end;
  - a 30-60 s showcase.

## Tests (pass / fail with evidence)

| ID | Procedure | Measured | Pass when | Evidence |
|---|---|---|---|---|
| <P>01 | launch with the run record's command | script errors in the log | 0 | `logs/<P>01.log` |
| <P>02 | <drive input that exercises X> | <quantity, unit> | <threshold> | `<file>` |
| <P>0n | walk straight 3 s at 60 and 144 FPS | camera pos 2nd diff RMS / p99 (mm); rot step (deg) | <thresholds> | `<json>` |
| <P>0n | busiest view, 6 s after 1.5 s warm-up | p50 / p95 frame ms | p95 < <ms> | `<json>` |
| <P>0n | full loop by input playback | reaches end screen; duration | yes; <min-max> | `<clip>` |

## Traceability

| Required item | Test IDs |
|---|---|
| <item> | <P>02, <P>05 |

## How it is judged

<priority order; "what matters most" first; which rows are human judgement>.

## Updates

<YYYY-MM-DD: verbatim change, who asked. Append only.>
