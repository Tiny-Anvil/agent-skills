#!/usr/bin/env bash
# scripts/validate.sh — the checks CI runs: marketplace and plugin manifests, skill frontmatter, command → skill
# links, file references inside skills, shell syntax, YAML/JSON templates. Optional: a local deny-list of words that must never be
# published (one regex per line in .denylist, gitignored), e.g. machine names or private project names.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
err() { echo "FAIL $*"; fail=1; }

# Manifests: the marketplace, and every plugin it lists exists with a valid plugin.json of the same name
python3 -m json.tool .claude-plugin/marketplace.json >/dev/null 2>&1 || err "marketplace.json is not valid JSON"
python3 - <<'PY' || fail=1
import json, os, sys
m = json.load(open(".claude-plugin/marketplace.json"))
bad = False
for p in m["plugins"]:
    pj = os.path.join(p["source"], ".claude-plugin", "plugin.json")
    try:
        d = json.load(open(pj))
    except Exception as e:
        print(f"FAIL {pj}: {e}"); bad = True; continue
    if d.get("name") != p["name"]:
        print(f"FAIL {pj}: name '{d.get('name')}' != marketplace entry '{p['name']}'"); bad = True
    if d.get("version") != p.get("version"):
        print(f"FAIL {pj}: version '{d.get('version')}' != marketplace entry '{p.get('version')}'"); bad = True
sys.exit(1 if bad else 0)
PY

# Skills: name == folder, description starts with "Use when" and fits 1024 chars, only name/description keys
for d in plugins/*/skills/*/; do
  s="${d%/}"; n="$(basename "$s")"; f="$s/SKILL.md"
  [[ -f "$f" ]] || { err "$s has no SKILL.md"; continue; }
  python3 - "$f" "$n" <<'PY' || fail=1
import re, sys
path, folder = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
if not m:
    print(f"FAIL {path}: no frontmatter"); sys.exit(1)
fm = dict(line.split(": ", 1) for line in m.group(1).splitlines() if ": " in line)
bad = False
if set(fm) - {"name", "description"}:
    print(f"FAIL {path}: unexpected keys {sorted(set(fm) - {'name', 'description'})}"); bad = True
if fm.get("name") != folder:
    print(f"FAIL {path}: name '{fm.get('name')}' != folder '{folder}'"); bad = True
if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", folder):
    print(f"FAIL {path}: folder is not lowercase-hyphen"); bad = True
desc = fm.get("description", "")
if not desc.startswith("Use when"):
    print(f"FAIL {path}: description must start with 'Use when'"); bad = True
if len(desc) > 1024:
    print(f"FAIL {path}: description is {len(desc)} chars (> 1024)"); bad = True
sys.exit(1 if bad else 0)
PY
done

# Commands point at existing skills
for c in plugins/*/commands/*.md; do
  plugin_dir="${c%/commands/*}"; plugin="$(basename "$plugin_dir")"
  # Every "<something>:<skill>" reference must use this plugin's own name and an existing skill.
  for ref in $(grep -oE '[a-z0-9-]+:[a-z]+(-[a-z0-9]+)+ skill' "$c" | sed 's/ skill$//' | sort -u); do
    [[ "${ref%%:*}" == "$plugin" ]] || err "$c refers to $ref (plugin is '$plugin')"
    [[ -d "$plugin_dir/skills/${ref#*:}" ]] || err "$c refers to missing skill $ref"
  done
done

# Files a skill refers to by relative path (`templates/...`, `*.md` next to SKILL.md) exist
for d in plugins/*/skills/*/; do
  for ref in $(grep -ohE '`templates/[A-Za-z0-9_./-]+`' "$d"*.md | tr -d '`' | sort -u); do
    [[ -e "$d$ref" ]] || err "${d}: referenced $ref does not exist"
  done
done

# Shell and YAML/JSON templates parse
while IFS= read -r f; do bash -n "$f" || err "$f: bash syntax"; done < <(git ls-files '*.sh' 2>/dev/null || find . -name '*.sh')
python3 - <<'PY' || fail=1
import glob, json, sys
try:
    import yaml
except ImportError:
    print("skip YAML check (pip install pyyaml)"); sys.exit(0)
class Loader(yaml.SafeLoader):
    pass
# Compose's !reset / !override tags: parse, don't interpret.
Loader.add_multi_constructor("!", lambda loader, suffix, node: None)
bad = False
for f in glob.glob("plugins/**/*.y*ml", recursive=True) + glob.glob(".github/**/*.y*ml", recursive=True):
    try:
        list(yaml.load_all(open(f), Loader=Loader))
    except Exception as e:
        print(f"FAIL {f}: {e}"); bad = True
sys.exit(1 if bad else 0)
PY

# Local deny-list (never committed)
if [[ -s .denylist ]]; then
  hits="$(grep -rniE -f .denylist --exclude=.denylist --exclude-dir=.git . || true)"
  [[ -z "$hits" ]] || { echo "$hits"; err "deny-listed words found"; }
fi

[[ $fail == 0 ]] && echo "all checks passed"
exit $fail
