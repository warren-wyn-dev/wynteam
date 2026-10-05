#!/usr/bin/env bash
# Food share preview: anon sees only the public profile of a published,
# non-suspended store -- never contact or payment details, never drafts.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_share_preview_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_share_preview_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { $PSQL -q -X -t -A -v ON_ERROR_STOP=1 -d "$DB" -c "$1"; }

LIVE=00000000-0000-4000-8000-0000000000a1
DRAFT=00000000-0000-4000-8000-0000000000a2
SUSPENDED=00000000-0000-4000-8000-0000000000a3

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create table public.food_stores(id uuid primary key, name text, description text, logo_path text, cover_path text,
  phone text default '0800000000', address text default 'ที่อยู่', promptpay_id text default '0800000000',
  is_published boolean not null default false, admin_suspended_at timestamptz);
revoke all on table public.food_stores from public, anon, authenticated;
grant usage on schema public to anon, authenticated;
insert into public.food_stores(id, name, description, logo_path, cover_path, is_published, admin_suspended_at) values
  ('$LIVE', 'มะละป๊อกป๊อก', '  ส้มตำรสเด็ด $(printf 'ก%.0s' {1..300})  ', 's/$LIVE/logo.jpg', 's/$LIVE/cover.jpg', true, null),
  ('$DRAFT', 'ร้านร่าง', null, null, null, false, null),
  ('$SUSPENDED', 'ร้านถูกระงับ', null, null, null, true, now());
SQL
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_share_preview_v1.sql"
# The apply workflow can be dispatched again.
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_share_preview_v1.sql"

fail() { echo "FAIL: $1" >&2; exit 1; }
as_anon() { val "set role anon; $1"; }

[ "$(as_anon "select name from public.food_store_share_preview('$LIVE')")" = "มะละป๊อกป๊อก" ] || fail "published store preview"
[ "$(as_anon "select cover_path from public.food_store_share_preview('$LIVE')")" = "s/$LIVE/cover.jpg" ] || fail "cover path"
[ "$(as_anon "select char_length(description) from public.food_store_share_preview('$LIVE')")" = "160" ] || fail "description trimmed to 160"
[ "$(as_anon "select count(*) from public.food_store_share_preview('$DRAFT')")" = "0" ] || fail "draft store hidden"
[ "$(as_anon "select count(*) from public.food_store_share_preview('$SUSPENDED')")" = "0" ] || fail "suspended store hidden"
[ "$(as_anon "select count(*) from public.food_store_share_preview('00000000-0000-4000-8000-0000000000ff')")" = "0" ] || fail "unknown store"
# Only the five public columns come back.
[ "$(val "select string_agg(a, ',' order by o) from unnest((select proargnames from pg_proc where proname = 'food_store_share_preview')) with ordinality as t(a, o) where o > 1")" = "id,name,description,logo_path,cover_path" ] || fail "returned columns"
# anon still cannot read the table directly.
if as_anon "select phone from public.food_stores limit 1" >/dev/null 2>&1; then fail "anon reads food_stores"; fi
echo "PASS: food share preview"
