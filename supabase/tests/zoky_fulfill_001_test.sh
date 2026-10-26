#!/usr/bin/env bash
# Local disposable PostgreSQL only. Never accepts remote connection strings.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTAINER="zoky-fulfillment-test-$$"
cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT
docker run -d --name "$CONTAINER" -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17 >/dev/null
for attempt in $(seq 1 30); do
  if docker logs "$CONTAINER" 2>&1 | grep -q "PostgreSQL init process complete" && docker exec "$CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
run() { docker exec -i "$CONTAINER" psql -X -q -U postgres -v ON_ERROR_STOP=1 "$@"; }
run < "$ROOT/supabase/tests/fixtures/zoky_fulfill_001_baseline.sql"
run < "$ROOT/supabase/migrations/20261026115927_zoky_fulfillment_v1.sql"
run < "$ROOT/supabase/tests/fixtures/zoky_fulfill_001_behavior.sql"
# Rollback must refuse to destroy pickup/refund evidence.
if run < "$ROOT/supabase/rollbacks/20261026115927_zoky_fulfillment_v1_rollback.sql" > /tmp/zoky-rollback-refusal-$$.log 2>&1; then
  echo 'FAIL: rollback destroyed fulfillment data' >&2; exit 1
fi
grep -q 'fulfillment data exists' /tmp/zoky-rollback-refusal-$$.log
rm -f /tmp/zoky-rollback-refusal-$$.log
echo 'ok - rollback refuses existing fulfillment/evidence data'
run -c 'create database rollback_check'
run -d rollback_check < "$ROOT/supabase/tests/fixtures/zoky_fulfill_001_baseline.sql"
run -d rollback_check < "$ROOT/supabase/migrations/20261026115927_zoky_fulfillment_v1.sql"
run -d rollback_check < "$ROOT/supabase/rollbacks/20261026115927_zoky_fulfillment_v1_rollback.sql"
echo 'ok - rollback succeeds on empty additive migration'
restored=$(run -d rollback_check -Atc "select md5(pg_get_functiondef('public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision)'::regprocedure))")
[ "$restored" = cfe2a645c82ffc1d17867032f00e7ea1 ] || { echo 'FAIL: original core definition not restored' >&2; exit 1; }
echo 'ok - rollback restores exact production core definition'
run -d rollback_check -c "alter function public.food_cancel_order(uuid,text) set work_mem='8MB'"
if run -d rollback_check < "$ROOT/supabase/migrations/20261026115927_zoky_fulfillment_v1.sql" > /tmp/zoky-drift-$$.log 2>&1; then
  echo 'FAIL: migration accepted unreviewed baseline drift' >&2; exit 1
fi
grep -q 'fulfillment baseline drift' /tmp/zoky-drift-$$.log
rm -f /tmp/zoky-drift-$$.log
echo 'ok - changed production definition blocks migration atomically' 
echo 'PASS: ZOKY fulfillment SQL behavior suite' 
