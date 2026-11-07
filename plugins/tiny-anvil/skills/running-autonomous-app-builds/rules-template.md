# Run rules: <APP>

Written at setup on <YYYY-MM-DD> from the owner's answers (verbatim in quotes). The run obeys this file and nothing
else. A change by the owner is appended under Changes; it never edits the text above it.

## What gets built

- Repo: "<answer>". <Expanded: repo URL, the run's branch, who merges to main.>
- Data: "<answer>". Auth: "<answer>".
- Conventions: house-stack.md, overridden by: <example projects / CLAUDE.md read at setup>.
- Third-party packages: allowed if licence-compatible; each new dependency gets a line in RUN.md → Decisions.

## Quality bar

"<answer>". Two things matter most: <copied from the brief>.

## Deploy gates

"<answer>". Expanded, per action (allowed alone / PR only / review checkpoint / never):
- Push the run's branch, open app-repo PRs: <>
- Merge to the app repo's main: <>
- Create prereleases (images for the test environment): <>
- Deploy changes (GitOps PR / deploy job): <PR only> ; merge the test-environment deploy PR: <>
- Higher environments (acc / prod): review checkpoint, always.
- Never: other apps' deployment files, shared infrastructure, repo settings, secret values, force-pushes,
  deleting remote branches/tags/packages.

## Credentials and secrets

Names only, never values: <repo secrets/vars, registry, how deploy secrets are made (Sealed Secrets, SOPS, External
Secrets, Key Vault, ...), OIDC variable names>.
A missing one is a real blocker.

## Listing images

"<answer>". Generation: "<answer>" <provider allowed, cap in images; "code-only" when not allowed>. Proof that may
appear on images: <only what the owner gave; none by default>.

## Stop rule

"<answer>". <Concrete: "stop when WALLET.json total_cost_usd >= 50", or "stop at 2026-10-12T08:00 local", or
"stop when the brief's tests pass with evidence, the test environment is verified, no major defect is open and the completion
conditions hold">. Until it holds: keep improving.

## Reviews

"<answer>". At each one: freeze an increment, present it, end the turn. Feedback goes into RUN.md → Feedback,
verbatim and numbered.

## Agents and loop

- Agents: "<answer>". <Max concurrent helpers; workflows yes/no; no model override.>
- Loop: "<answer>". <The mechanism and its exact command.>

## Talking to the owner

Only at a review, or on a real blocker: a missing credential or permission, spending beyond the caps, a gated
action above, an irreversible action outside the workspace, or a broken tool that changes scope. Every other choice
is the builder's: decide it and record it in RUN.md → Decisions.

## Workspace

Repo (committed): `src/apps/api` · `src/apps/app` · `src/packages` · `src/tests` · `.github/` · `docs/features/` · README.
Run records (`data/run/`, gitignored, never committed): `docs/` rules, brief, contract, architecture, kickoff ·
`prompts/` every input as sent (append-only) · `increments/I###/` · `final/` best verified evidence + QA.md ·
`qa/` raw logs and reports · `RUN.md` · `DELEGATION.md`.

## Changes

<YYYY-MM-DD, verbatim, who.>
