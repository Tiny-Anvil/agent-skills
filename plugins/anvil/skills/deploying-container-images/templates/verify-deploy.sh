#!/usr/bin/env bash
# verify-deploy.sh <base-url> <version> — prove an environment serves the deployed version (not just that CI was
# green). Polls up to 10 minutes for the version, then runs the other checks once. Exit 0 = verified.
#   VERSION_PATH=/api/v1/config VERSION_FIELD=apiVersion verify-deploy.sh https://myapp-test.example.com v1.2.3
#   AUTH=1 ...   also check that /api/v1/me is 401 without a token
set -uo pipefail
base="${1:?usage: verify-deploy.sh <base-url> <version>}"; want="${2:?version}"
path="${VERSION_PATH:-/api/v1/version}"; field="${VERSION_FIELD:-version}"
fail=0

served=""
for _ in $(seq 1 20); do
  served="$(curl -fsS "$base$path" 2>/dev/null | python3 -I -c "import json,sys; print(json.load(sys.stdin).get('$field',''))" 2>/dev/null)"
  [[ "$served" == "$want" ]] && break
  sleep 30
done
[[ "$served" == "$want" ]] && echo "ok   version $served" || { echo "FAIL version: served '${served:-nothing}', want $want"; fail=1; }

code="$(curl -s -o /dev/null -w '%{http_code}' "$base/api/v1/health")"
[[ "$code" == 200 ]] && echo "ok   health 200" || { echo "FAIL health $code"; fail=1; }

read -r code ctype < <(curl -s -o /dev/null -w '%{http_code} %{content_type}\n' "$base/api/v1/does-not-exist-$RANDOM")
[[ "$code" == 404 && "$ctype" == *json* ]] && echo "ok   unknown API route: 404 $ctype" \
  || { echo "FAIL unknown API route: $code $ctype (the SPA shell answering API typos?)"; fail=1; }

if [[ "${AUTH:-}" == 1 ]]; then
  code="$(curl -s -o /dev/null -w '%{http_code}' "$base/api/v1/me")"
  [[ "$code" == 401 ]] && echo "ok   /me without token: 401" || { echo "FAIL /me without token: $code"; fail=1; }
fi
exit $fail
