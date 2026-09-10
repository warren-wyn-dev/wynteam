#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$SCRIPT_DIR/../migrations_wyn155_beta5_profile_v2.sql"
DB="wyn155_profile_v2_${RANDOM}_$$"
trap 'dropdb --if-exists "$DB" >/dev/null 2>&1 || true' EXIT

createdb "$DB"
psql -d "$DB" -v ON_ERROR_STOP=1 <<'SQL'
create schema auth;
create role authenticated nologin;
create role anon nologin;
create or replace function auth.uid() returns uuid
language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create table public.profiles(
  id uuid primary key,
  username text
);
create table public.drops(
  id uuid primary key,
  author_id uuid not null references public.profiles(id) on delete cascade,
  deleted_at timestamptz
);

insert into public.profiles(id, username) values
 ('11111111-1111-1111-1111-111111111111', 'one'),
 ('22222222-2222-2222-2222-222222222222', 'two');
insert into public.drops(id, author_id) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','11111111-1111-1111-1111-111111111111'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2','11111111-1111-1111-1111-111111111111'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3','11111111-1111-1111-1111-111111111111'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4','11111111-1111-1111-1111-111111111111'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','22222222-2222-2222-2222-222222222222');
SQL
psql -d "$DB" -v ON_ERROR_STOP=1 -f "$MIGRATION" >/dev/null

psql -d "$DB" -Atqc "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='cover_url')" | grep -qx t
psql -d "$DB" -Atqc "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='drops' and column_name='profile_pin_position')" | grep -qx t
psql -d "$DB" -Atqc "select has_function_privilege('authenticated','public.pin_profile_drop(uuid)','execute')" | grep -qx t
psql -d "$DB" -Atqc "select has_function_privilege('anon','public.pin_profile_drop(uuid)','execute')" | grep -qx f

for n in 1 2 3; do
  psql -d "$DB" -v ON_ERROR_STOP=1 -Atqc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.pin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa${n}')" | tail -n1 | grep -qx "$n"
done

if psql -d "$DB" -v ON_ERROR_STOP=1 -qc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.pin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4')" >/dev/null 2>&1; then
  echo "expected fourth pin to fail" >&2
  exit 1
fi

if psql -d "$DB" -v ON_ERROR_STOP=1 -qc "set role authenticated; set request.jwt.claim.sub='22222222-2222-2222-2222-222222222222'; select public.unpin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1')" >/dev/null 2>&1; then
  echo "expected cross-owner unpin to fail" >&2
  exit 1
fi

psql -d "$DB" -v ON_ERROR_STOP=1 -qc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.unpin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2')" >/dev/null
psql -d "$DB" -v ON_ERROR_STOP=1 -Atqc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.pin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4')" | tail -n1 | grep -qx 2

# Soft-delete clears a pin before the unique partial index can become a
# restore-time trap later.
psql -d "$DB" -v ON_ERROR_STOP=1 -qc "update public.drops set deleted_at=now() where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'" >/dev/null
psql -d "$DB" -Atqc "select profile_pin_position is null from public.drops where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'" | grep -qx t

echo "WYN-155 BETA5 PROFILE V2 CHECKS PASSED"
