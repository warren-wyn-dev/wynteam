#!/usr/bin/env bash
# Smoke test for the Maps Core gateway. Usage: ./check.sh  (reads .env in this folder)
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
base="https://${MAPS_CORE_DOMAIN}"
auth=(-H "X-WYNOS-Maps-Token: ${WYNOS_MAPS_UPSTREAM_TOKEN}")
fail=0

expect() { # name expected-code curl-args...
  local name=$1 want=$2; shift 2
  local got; got=$(curl -sS -o /dev/null -w '%{http_code}' -m 15 "$@" || echo 000)
  if [[ $got == "$want" ]]; then echo "PASS $name ($got)"; else echo "FAIL $name (got $got, want $want)"; fail=1; fi
}

expect "health" 200 "${auth[@]}" "$base/health"
expect "no token is rejected" 401 "$base/health"
expect "geo search" 200 "${auth[@]}" "$base/geo/search?q=%E0%B8%A1%E0%B8%AB%E0%B8%B2%E0%B8%AA%E0%B8%B2%E0%B8%A3%E0%B8%84%E0%B8%B2%E0%B8%A1&format=jsonv2&countrycodes=th"
expect "geo reverse" 200 "${auth[@]}" "$base/geo/reverse?lat=16.1851&lon=103.3026&format=jsonv2"
expect "routing" 200 "${auth[@]}" -X POST -H 'Content-Type: application/json' \
  -d '{"locations":[{"lat":16.1851,"lon":103.3026},{"lat":16.2457,"lon":103.2526}],"costing":"motorcycle"}' \
  "$base/routing/route"
expect "unknown path is closed" 404 "${auth[@]}" "$base/geo/status"
exit $fail
