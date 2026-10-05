#!/usr/bin/env bash
# Food short share links: every store gets a fixed 6-character code that no
# API caller can set or change; anon resolves a code to an id only for a
# published, non-suspended store.
# Runs on a throwaway local PostgreSQL database with minimal Supabase stubs.
# Usage: PSQL="sudo -u postgres psql" supabase/tests/wynos_food_share_code_test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_share_code_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
val() { $PSQL -q -X -t -A -v ON_ERROR_STOP=1 -d "$DB" -c "$1"; }
fail() { echo "FAIL: $1" >&2; exit 1; }

LIVE=00000000-0000-4000-8000-0000000000a1
DRAFT=00000000-0000-4000-8000-0000000000a2
SUSPENDED=00000000-0000-4000-8000-0000000000a3
NEW=00000000-0000-4000-8000-0000000000a4

run >/dev/null <<SQL
do \$\$ begin create role anon; exception when duplicate_object then null; end \$\$;
do \$\$ begin create role authenticated; exception when duplicate_object then null; end \$\$;
create schema internal;
create table public.food_stores(id uuid primary key, name text, description text, logo_path text, cover_path text,
  phone text default '0800000000', is_published boolean not null default false, admin_suspended_at timestamptz);
grant usage on schema public, internal to anon, authenticated;
grant select, insert, update on public.food_stores to authenticated;
insert into public.food_stores(id, name, is_published, admin_suspended_at) values
  ('$LIVE', 'มะละป๊อกป๊อก', true, null), ('$DRAFT', 'ร้านร่าง', false, null), ('$SUSPENDED', 'ร้านถูกระงับ', true, now());
SQL
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_share_preview_v1.sql"
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_share_code_v1.sql"
CODE=$(val "select share_code from public.food_stores where id = '$LIVE'")
# The apply workflow can be dispatched again; codes stay the same.
run >/dev/null < "$ROOT/supabase/migrations_wynos_food_share_code_v1.sql"
[ "$(val "select share_code from public.food_stores where id = '$LIVE'")" = "$CODE" ] || fail "code stable across re-apply"

[[ "$CODE" =~ ^[a-hjkmnp-z2-9]{6}$ ]] || fail "code format: $CODE"
[ "$(val "select count(distinct share_code) from public.food_stores")" = "3" ] || fail "existing stores backfilled with unique codes"

# Callers cannot pick or change a code.
run >/dev/null -c "set role authenticated; insert into public.food_stores(id, name, share_code) values ('$NEW', 'ใหม่', 'aaaaaa');"
NEWCODE=$(val "select share_code from public.food_stores where id = '$NEW'")
[ "$NEWCODE" != "aaaaaa" ] && [[ "$NEWCODE" =~ ^[a-hjkmnp-z2-9]{6}$ ]] || fail "insert ignores a supplied code"
run >/dev/null -c "set role authenticated; update public.food_stores set share_code = 'bbbbbb', name = 'เปลี่ยนชื่อ' where id = '$LIVE';"
[ "$(val "select share_code from public.food_stores where id = '$LIVE'")" = "$CODE" ] || fail "update cannot change the code"
[ "$(val "select name from public.food_stores where id = '$LIVE'")" = "เปลี่ยนชื่อ" ] || fail "other columns still update"

as_anon() { val "set role anon; $1"; }
[ "$(as_anon "select public.food_store_id_by_share_code('$CODE')")" = "$LIVE" ] || fail "anon resolves a published store"
[ "$(as_anon "select public.food_store_id_by_share_code(' ${CODE^^} ')")" = "$LIVE" ] || fail "code is case and space tolerant"
DCODE=$(val "select share_code from public.food_stores where id = '$DRAFT'")
SCODE=$(val "select share_code from public.food_stores where id = '$SUSPENDED'")
[ -z "$(as_anon "select public.food_store_id_by_share_code('$DCODE')")" ] || fail "draft store hidden"
[ -z "$(as_anon "select public.food_store_id_by_share_code('$SCODE')")" ] || fail "suspended store hidden"
[ -z "$(as_anon "select public.food_store_id_by_share_code('zzzzzz')")" ] || fail "unknown code"
[ "$(as_anon "select share_code from public.food_store_share_preview('$LIVE')")" = "$CODE" ] || fail "preview returns the code"
if as_anon "select internal.food_new_share_code()" >/dev/null 2>&1; then fail "anon calls the generator"; fi
echo "PASS: food share code"
