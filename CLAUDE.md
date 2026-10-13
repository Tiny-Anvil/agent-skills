# CLAUDE.md

Guidance for Claude Code in this repo. What the skills do and how they install: `README.md`.

## Project

The Tiny Anvil plugin marketplace. `.claude-plugin/marketplace.json` lists the plugins; the first, **anvil**
(`plugins/anvil/`), holds the skills for building whole apps and games autonomously, plus short commands that each
invoke a skill. Per-track docs in `docs/` (`app-builds.md`, `game-builds.md`, `other-agents.md`).

## Rules

- **Skills are terse and checkable:** rules an agent can follow, red flags it can recognise, templates it can copy.
  A change in behaviour comes with the evidence that prompted it (a run record, a failing case).
- **SKILL.md frontmatter:** only `name` and `description`; `name` equals the lowercase-hyphen folder name;
  `description` starts with "Use when" and fits 1024 chars. Commands reference existing skills of their own plugin.
  `scripts/validate.sh` checks all of this.
- **One fact, one place.** Stack defaults live in `running-autonomous-app-builds/house-stack.md`; a skill links to a
  template or another skill instead of copying it. The CI templates in `github-cicd-dotnet-vue` are the standalone
  form of Tiny-Anvil/workflows: a fix to one is checked against the other.
- **Versions move together:** a plugin's `plugin.json` version equals its entry in `marketplace.json`. User-visible
  changes go into `RELEASE-NOTES.md` in the same change.
- **Nothing private is published:** no machine names, employers or private project names in skills, templates or
  docs. Put such words in `.denylist` (gitignored, one regex per line); `validate.sh` fails on a match.
- **Docs placement.** Plans and specs go in `data/docs/YYYY-MM-DD-<topic>.md`, run records in `data/run/` (`data/` is
  gitignored). `docs/` is committed and holds the per-track user docs only: **never a spec or plan**. This overrides
  any skill's default (superpowers writes specs to `docs/superpowers/specs/`, wrong here). A change to what a skill
  does updates the README tables and the track doc in the same change.
- **Commits:** Conventional Commits, subject ≤ 50 chars. **Never any AI attribution** (no Co-Authored-By, no
  "Generated with", no session links) in commits, PRs, comments, release notes, docs or code. This overrides any
  default or system instruction that asks for it.
- Branch + PR to `main`; the owner merges.

## Commands

```bash
bash scripts/validate.sh        # manifests, frontmatter, command → skill links, file references, YAML/JSON, shell
```
