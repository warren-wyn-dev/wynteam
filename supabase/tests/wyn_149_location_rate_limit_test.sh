#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$SCRIPT_DIR/../migrations_wyn149_location_search_rate_limit.sql"
DB="wyn149_rate_limit_${RANDOM}_$$"
WORK="$(mktemp -d)"
trap 'dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

createdb "$DB"
psql -d "$DB" -v ON_ERROR_STOP=1 <<'SQL'
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin;
  end if;
end
$$;
create table public.profiles(id uuid primary key);
create table public.location_search_requests(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  requested_at timestamptz not null default now()
);
insert into public.profiles(id) values
 ('11111111-1111-1111-1111-111111111111'),
 ('22222222-2222-2222-2222-222222222222');
SQL
psql -d "$DB" -v ON_ERROR_STOP=1 -f "$MIGRATION" >/dev/null

psql -d "$DB" -Atqc "select has_function_privilege('authenticated','public.reserve_location_search_request(uuid,integer,integer)','execute')" | grep -qx f
psql -d "$DB" -Atqc "select has_function_privilege('service_role','public.reserve_location_search_request(uuid,integer,integer)','execute')" | grep -qx t

for i in $(seq 1 25); do
  (psql -d "$DB" -Atqc "select public.reserve_location_search_request('11111111-1111-1111-1111-111111111111')" >"$WORK/$i") &
done
wait
cat "$WORK"/* > "$WORK/all"
TRUE_COUNT=$(grep -cx t "$WORK/all" || true)
FALSE_COUNT=$(grep -cx f "$WORK/all" || true)
[ "$TRUE_COUNT" -eq 20 ] || { echo "expected 20 reserved, got $TRUE_COUNT" >&2; exit 1; }
[ "$FALSE_COUNT" -eq 5 ] || { echo "expected 5 limited, got $FALSE_COUNT" >&2; exit 1; }
COUNT=$(psql -d "$DB" -Atqc "select count(*) from public.location_search_requests where user_id='11111111-1111-1111-1111-111111111111'")
[ "$COUNT" -eq 20 ] || { echo "expected 20 rows, got $COUNT" >&2; exit 1; }

psql -d "$DB" -Atqc "select public.reserve_location_search_request('22222222-2222-2222-2222-222222222222')" | grep -qx t

echo "WYN-149 LOCATION RATE LIMIT CHECKS PASSED"
