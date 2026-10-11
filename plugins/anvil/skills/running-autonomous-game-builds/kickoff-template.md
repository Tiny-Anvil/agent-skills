# Kickoff

Paste this into a fresh agent session (e.g. Claude Code) started in the project directory.
Set the session's reasoning effort high first (in Claude Code: `/effort`, e.g. xhigh for the lead).

```text
You are building <GAME> autonomously in this directory. Use the skill running-autonomous-game-builds.
Read docs/RULES.md (the run's rules: sources, quality bar, stop rule, reviews, agents, loop) and
docs/BRIEF.md (what to build and the tests that prove it) before anything else. Setup is done: do not
ask setup questions again. There is no starter project and no reference image: build everything
from the brief. Nobody answers questions during the run; decide and record each decision in RUN.md.
Build a complete blockout first and test the central mechanic in the running game before detail,
then iterate look by look — do not stop after a blockout or ask permission after each pass, and there
is no fixed look or capture limit (iterating-with-look-checkpoints; captures and measurements via
godot-scenario-harness; assets via building-blender-assets-by-script; sound via sourcing-and-processing-game-audio). Keep final/ at your best
verified build at all times. Pause only at the reviews in docs/RULES.md. Stop only when its stop rule
holds — until then keep improving. Finish with the launch command, test evidence per test ID, the
final look ID and an honest list of limitations.
```

## Detached driver (when RULES.md's loop is "detached driver")

The driver below is written for the Claude Code CLI (`claude -p`); with another harness, substitute its headless
resume command. Run it with `nohup bash drive.sh <new-uuid> & disown`. It re-prompts the lead each time it ends a turn.
- **At a review,** the lead writes `review` into `docs/STOP` and the driver waits. The owner writes feedback into
  `docs/FEEDBACK.md` and deletes `docs/STOP`, and the run resumes.
- **When the stop rule holds,** the lead writes `done` into `docs/STOP` and the driver exits.

```bash
#!/usr/bin/env bash
# drive.sh <new-uuid>: run 1 starts the session with the kickoff, every later run resumes it.
# Keeps docs/WALLET.json = the session's running cost (a --resume call's total_cost_usd IS the running total).
exec 200>.drive.lock; flock -n 200 || exit 0       # one driver per project
SID="$1"
run() {
  # the prompt record: every prompt sent, verbatim (the last argument is the prompt text)
  printf '\n--- %s session=%s\n%s\n' "$(date -u +%FT%TZ)" "$SID" "${@: -1}" >> prompts/driver.log
  claude -p --output-format json --permission-mode auto "$@" > qa/last_run.json 2>> qa/drive.log
  python3 -c 'import json,datetime; r=json.load(open("qa/last_run.json")); json.dump({"total_cost_usd": r.get("total_cost_usd"), "at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "session_id": r.get("session_id")}, open("docs/WALLET.json","w"))' 2>> qa/drive.log
  cat qa/last_run.json >> qa/drive.log
}
run --session-id "$SID" "$(sed -n '/^```text$/,/^```$/p' docs/KICKOFF.md | sed '1d;$d')"
while :; do
  if [ -f docs/STOP ]; then
    grep -q '^done' docs/STOP && break      # the stop rule held
    sleep 60; continue                      # a review: wait until the owner deletes docs/STOP
  fi
  run --resume "$SID" "Continue the run per docs/RULES.md. Resume from RUN.md, the latest look and docs/FEEDBACK.md."
  sleep 5
done
```
The flags exist in Claude Code 2.1 (`-r/--resume <id>`, `--session-id <uuid>`, `--permission-mode`). Choose the
permission mode at setup: a headless session that stops at a permission prompt makes no progress, and
`bypassPermissions` removes every guard, so prefer `auto` with an allowlist.
