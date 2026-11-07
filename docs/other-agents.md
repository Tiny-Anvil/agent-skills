# Using the skills with other agents and models

The skills are plain Markdown in the open [Agent Skills](https://agentskills.io) format: a folder per skill with a
`SKILL.md` (YAML frontmatter with `name` and `description`, then instructions) and the files it refers to. Many
coding agents read that format, not only Claude Code.

## What is portable and what is not

| Part | Portable? | Notes |
|---|---|---|
| `skills/*/SKILL.md`, templates, checklists | yes | Plain Markdown, shell, YAML, TypeScript, GDScript, Python. |
| Steps that name a Claude Code tool | yes, by intent | Written as "ask the owner (in Claude Code: AskUserQuestion)"; use your agent's equivalent, or plain text. |
| `commands/` (`/tiny-anvil:build-app`, ...) | Claude Code only | Each is a one-liner that invokes a skill; any agent can be told the same thing in words. |
| `.claude-plugin/` (install, updates, namespacing) | Claude Code only | Other agents: copy the skill folders. |
| The detached driver (`kickoff-template.md`) | Claude Code CLI | Uses `claude -p`, `--resume` and `total_cost_usd`. Another CLI needs its own headless start/resume command and cost source; the STOP / FEEDBACK file protocol stays the same. |
| The budget wallet (`wallet-statusline.md`, games) | Claude Code only | Depends on the Claude Code status line. Use a time cap or completion conditions elsewhere. |

## Installing the skills in another agent

Copy (or symlink) the skill folders into the directory your agent loads skills from, keeping each folder intact:

```bash
git clone https://github.com/Tiny-Anvil/agent-skills.git
cp -r agent-skills/plugins/tiny-anvil/skills/* <your agent's skills directory>/
```

Where that directory is, and whether skills load automatically from their description or must be invoked by name,
differs per agent and changes between versions; check your agent's documentation. Agents with SKILL.md support
include OpenAI Codex, Gemini CLI, GitHub Copilot, Cursor, Goose, OpenCode and Kimi Code (`/skill:<name>`).

The skills refer to each other by name (for example "see dotnet-vue-test-harness") and to files next to them
(`templates/...`), so copy all of them, not a selection, unless you only want the game or only the app half.

## Using another model inside Claude Code

Claude Code can talk to any endpoint that implements the Anthropic Messages API, through `ANTHROPIC_BASE_URL` and
`ANTHROPIC_AUTH_TOKEN` (and a model name). Several model providers offer such an endpoint for their own models;
follow the provider's current documentation for the values. The plugin then works unchanged, commands included.

## What to expect

These skills were developed and tested with Claude models in Claude Code. Long unattended runs ask a lot of a
model: following a rules file for hours, opening and judging screenshots, and not stopping early. Other models and
agents may do well or may need a tighter stop rule and more review checkpoints. Start with a small app or game,
a completion stop rule and a review at the walking skeleton, and read the run's `RUN.md` before trusting it with a
bigger one. Reports of what works (and what does not) with other agents are welcome as issues.
