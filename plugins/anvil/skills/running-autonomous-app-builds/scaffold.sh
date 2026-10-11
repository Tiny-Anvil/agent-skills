#!/usr/bin/env bash
# scaffold.sh <project-dir>: the run records of an autonomous app build, in <project-dir>/data/run/ (gitignored:
# plans, specs and run records never go under the repo's docs/). Never overwrites an existing file. Safe to re-run.
# It does not create the solution itself (see house-stack.md -> Repo layout).
set -euo pipefail
P="${1:?usage: scaffold.sh <project-dir>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SK="$(dirname "$HERE")"
R="$P/data/run"
mkdir -p "$R"/{docs,prompts,increments,final,qa} "$P/docs/features"
put() { [ -e "$2" ] || { cp "$1" "$2"; echo "created $2"; }; }
[ -e "$R/prompts/README.md" ] || { printf '# Prompts\n\nWhat the run was given, as sent: the request, the setup questions and answers, the kickoff, every later\nowner message and every driver prompt. Verbatim and append-only: a correction is a new file, never an edit.\n' > "$R/prompts/README.md"; echo "created $R/prompts/README.md"; }
put "$HERE/rules-template.md" "$R/docs/RULES.md"
put "$HERE/kickoff-template.md" "$R/docs/KICKOFF.md"
put "$SK/writing-app-briefs/brief-template.md" "$R/docs/BRIEF.md"
put "$SK/iterating-with-verified-increments/RUN.md" "$R/RUN.md"
put "$SK/iterating-with-verified-increments/INCREMENT.md" "$R/increments/INCREMENT_TEMPLATE.md"
put "$SK/iterating-with-verified-increments/QA.md" "$R/final/QA.md"
[ -e "$R/DELEGATION.md" ] || { printf '# Delegation\n\n| UTC | Agent | Event | Owned files / scope | Active after |\n|---|---|---|---|---|\n' > "$R/DELEGATION.md"; echo "created $R/DELEGATION.md"; }
[ -e "$R/docs/CONTRACT.md" ] || { printf '# API contract (lead-owned; workers request changes)\n\nEndpoints (route, scope, request, response) · DTOs · error shape (ProblemDetails / ValidationProblem) · paging · versioning.\nThe machine-readable form is the generated OpenAPI document; OpenApiDocumentTests keep them equal.\n' > "$R/docs/CONTRACT.md"; echo "created $R/docs/CONTRACT.md"; }
[ -e "$R/docs/ARCHITECTURE.md" ] || { printf '# Code card for helpers (lead-owned)\n\nLayout · conventions (house-stack.md + the project CLAUDE.md) · config keys and env vars · how to run, test and capture · owned files: only touch yours; the lead does integration.\n' > "$R/docs/ARCHITECTURE.md"; echo "created $R/docs/ARCHITECTURE.md"; }
[ -e "$P/docs/features/README.md" ] || { printf '# Features\n\nOne doc per feature, infrastructure included. Each covers purpose, API endpoints (routes + scopes), data model,\nbusiness rules and how to verify.\n\n| Feature | Doc |\n|---|---|\n' > "$P/docs/features/README.md"; echo "created $P/docs/features/README.md"; }
if [ ! -d "$P/.git" ]; then git -C "$P" init -q -b main && echo "git initialised"; fi
GI="$P/.gitignore"; touch "$GI"
for line in 'data/' 'bin/' 'obj/' 'node_modules/' 'dist/' 'dev-dist/' '*.user' '.vs/' '.idea/' \
            'appsettings*.json' '!appsettings.example.json' 'docker-compose.override.yml' '.env' '.env.*' '!.env.example' 'test-results/' 'playwright-report/' \
            'coverage/' '.drive.lock'; do
  grep -qxF -- "$line" "$GI" || { echo "$line" >> "$GI"; echo "gitignore += $line"; }
done
echo "scaffold ready: $R"
