# Kickoff

Paste this into a fresh agent session (e.g. Claude Code) started in the project's repo root. Store it under
`data/run/docs/KICKOFF.md`. Set the session's effort first (Claude Code: `/effort`).

```text
You are building <APP> autonomously in this directory. Use the skill running-autonomous-app-builds.
Read CLAUDE.md, then data/run/docs/RULES.md (the run's rules: deploy gates, quality bar, stop rule,
reviews, agents, loop) and data/run/docs/BRIEF.md (what to build and the tests that prove it) before
anything else. All run records live in data/run/ (gitignored); never write plans or specs under docs/. Setup is done: do not
ask setup questions again. Nobody answers questions during the run; decide and record each decision in
RUN.md. Build a walking skeleton first (API + database + frontend + CI, one real request end to end,
pipeline green), then the central user flow, then iterate increment by increment
(iterating-with-verified-increments; tests and captures via dotnet-vue-test-harness; CI and images via
github-cicd-dotnet-vue; deploys via deploying-container-images). Do not stop after the skeleton or ask permission after each increment. Keep
data/run/final/ at your best verified build at all times. Respect the deploy gates in RULES.md exactly.
Pause only at the reviews in RULES.md. Stop only when its stop rule holds — until then keep
improving. Finish with the run and test commands, the CI run link, the deployed URL and version, test
evidence per test ID, the final increment ID and an honest list of limitations.
```

## Detached driver (when RULES.md's loop is "detached driver")

Written for the Claude Code CLI (`claude -p`, `--resume`, `total_cost_usd`). Another agent CLI needs its own
headless start/resume command and cost source; the STOP/FEEDBACK protocol stays the same.

Run it with `nohup bash drive.sh <new-uuid> & disown`. It re-prompts the lead each time it ends a turn.
Run it from the repo root; it keeps everything under `data/run/`.
- **At a review,** the lead writes `review` into `data/run/docs/STOP` and the driver waits. The owner writes feedback
  into `data/run/docs/FEEDBACK.md` and deletes `STOP`, and the run resumes.
- **When the stop rule holds,** the lead writes `done` into `data/run/docs/STOP` and the driver exits.

```bash
#!/usr/bin/env bash
# drive.sh <new-uuid>: run 1 starts the session with the kickoff, every later run resumes it.
# Keeps data/run/docs/WALLET.json = the session's running cost (a --resume call's total_cost_usd is the running total).
R=data/run
exec 200>"$R/.drive.lock"; flock -n 200 || exit 0       # one driver per project
SID="$1"
mkdir -p "$R/qa" "$R/prompts"
run() {
  printf '\n--- %s session=%s\n%s\n' "$(date -u +%FT%TZ)" "$SID" "${@: -1}" >> "$R/prompts/driver.log"
  claude -p --output-format json --permission-mode auto "$@" > "$R/qa/last_run.json" 2>> "$R/qa/drive.log"
  python3 -c 'import json,sys,datetime; r=json.load(open(sys.argv[1])); json.dump({"total_cost_usd": r.get("total_cost_usd"), "at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "session_id": r.get("session_id")}, open(sys.argv[2],"w"))' "$R/qa/last_run.json" "$R/docs/WALLET.json" 2>> "$R/qa/drive.log"
  cat "$R/qa/last_run.json" >> "$R/qa/drive.log"
}
run --session-id "$SID" "$(sed -n '/^```text$/,/^```$/p' "$R/docs/KICKOFF.md" | sed '1d;$d')"
while :; do
  if [ -f "$R/docs/STOP" ]; then
    grep -q '^done' "$R/docs/STOP" && break      # the stop rule held
    sleep 60; continue                           # a review: wait until the owner deletes STOP
  fi
  run --resume "$SID" "Continue the run per data/run/docs/RULES.md. Resume from data/run/RUN.md, the latest increment and data/run/docs/FEEDBACK.md."
  sleep 5
done
```

**Permissions.** A headless session that stops at a permission prompt makes no progress, and `bypassPermissions`
removes every guard. Use `auto` with a project `.claude/settings.local.json` allowlist written at setup (with the owner's OK): `dotnet`,
`pnpm`, `npx playwright`, `docker compose`, `git` (no `push --force`), `gh run`, `gh pr create`,
`gh release create --prerelease`. Deny device deploys (`adb install`, TV SDK installers) explicitly.
Leave out anything the deploy gates forbid, so the harness enforces them too, not only the rules file.
