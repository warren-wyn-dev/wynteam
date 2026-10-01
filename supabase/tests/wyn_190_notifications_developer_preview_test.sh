#!/usr/bin/env bash
# WYN-190 Notifications Developer Preview regression.
# Creates a throwaway PostgreSQL database only; never touches production.
#
# Proves:
#  1) all advanced Push/Quiet Hours columns exist with safe defaults
#  2) an authenticated user can persist their own advanced preferences
#  3) notification_push_deliveries exists with RLS enabled
#  4) anon/authenticated cannot read delivery telemetry
#  5) WYN-125 developer_accounts keeps its established RLS contract
#  6) notifications joins supabase_realtime when that publication exists

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn190_notifications_preview_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

run_psql() {
  local db="$1"
  local file="$2"
  if psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  elif command -v sudo >/dev/null 2>&1 && sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  else
    cat "$WORK_DIR/psql.out" >&2
    return 1
  fi
}

createdb_any() {
  local db="$1"
  createdb "$db" >/dev/null 2>&1 \
    || { command -v sudo >/dev/null 2>&1 && sudo -u postgres createdb "$db" >/dev/null 2>&1; }
}

dropdb_any() {
  local db="$1"
  dropdb --if-exists "$db" >/dev/null 2>&1 \
    || { command -v sudo >/dev/null 2>&1 && sudo -u postgres dropdb --if-exists "$db" >/dev/null 2>&1; } \
    || true
}

cat > "$WORK_DIR/00_stub.sql" <<'EOF'
create extension if not exists pgcrypto;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;

create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner uuid
);

create or replace function storage.foldername(name text) returns text[]
language sql immutable as $$
  select string_to_array(name, '/')
$$;

alter table storage.objects enable row level security;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
end
$$;

grant usage on schema public to authenticated, anon;
grant usage on schema storage to authenticated, anon;
alter default privileges in schema public grant select, insert, update, delete on tables to authenticated;
grant select, insert on storage.objects to authenticated;
grant select on storage.buckets to authenticated;

-- Supabase owns this publication in production. Creating an empty one here
-- lets schema.sql prove WYN-190 adds notifications membership idempotently.
create publication supabase_realtime;
EOF

cat > "$WORK_DIR/10_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual int, expected int);

insert into auth.users (id, email) values
  ('99000000-0000-0000-0000-000000000001', 'dev@test.com'),
  ('99000000-0000-0000-0000-000000000002', 'regular@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('99000000-0000-0000-0000-000000000001', 'dev190', 'Dev 190', 'user'),
  ('99000000-0000-0000-0000-000000000002', 'regular190', 'Regular 190', 'user');

insert into public.developer_accounts (user_id, label)
values ('99000000-0000-0000-0000-000000000001', 'WYN-190 fixture');

insert into results
select 'CHECK1_all_preview_columns_exist',
  count(*)::int,
  11
from information_schema.columns
where table_schema='public'
  and table_name='notification_settings'
  and column_name in (
    'push_likes','push_comments','push_follows','push_messages',
    'push_club','push_trending','push_system',
    'push_quiet_enabled','push_quiet_start','push_quiet_end','push_timezone'
  );

insert into public.notification_settings (user_id)
values ('99000000-0000-0000-0000-000000000001');

insert into results
select 'CHECK2_safe_defaults',
  case when
    push_likes and push_comments and push_follows and push_messages and
    push_club and push_trending and push_system and
    push_quiet_enabled = false and
    push_quiet_start = time '22:00' and
    push_quiet_end = time '08:00' and
    push_timezone = 'UTC'
  then 1 else 0 end,
  1
from public.notification_settings
where user_id='99000000-0000-0000-0000-000000000001';

do $$
declare
  v_ok boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';

  update public.notification_settings
  set push_likes=false,
      push_quiet_enabled=true,
      push_quiet_start=time '21:30',
      push_quiet_end=time '07:15',
      push_timezone='Asia/Bangkok'
  where user_id='99000000-0000-0000-0000-000000000001';

  select
    push_likes=false and push_quiet_enabled=true and
    push_quiet_start=time '21:30' and push_quiet_end=time '07:15' and
    push_timezone='Asia/Bangkok'
  into v_ok
  from public.notification_settings
  where user_id='99000000-0000-0000-0000-000000000001';

  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK3_owner_can_save_preview_preferences', case when v_ok then 1 else 0 end, 1);
end
$$;

insert into results
select 'CHECK4_delivery_table_rls_enabled',
  case when c.relrowsecurity then 1 else 0 end,
  1
from pg_class c
where c.oid='public.notification_push_deliveries'::regclass;

insert into results
select 'CHECK5_delivery_table_hidden_from_clients',
  case when
    not has_table_privilege('anon','public.notification_push_deliveries','SELECT')
    and not has_table_privilege('authenticated','public.notification_push_deliveries','SELECT')
  then 1 else 0 end,
  1;

-- WYN-125 compatibility: authenticated retains table privilege so SELECT
-- reaches RLS and returns zero rows instead of failing with permission denied.
insert into results
select 'CHECK6_developer_allowlist_select_privilege_preserved',
  case when has_table_privilege('authenticated','public.developer_accounts','SELECT') then 1 else 0 end,
  1;

do $$
declare
  v_count int := -1;
begin
  set role authenticated;
  set request.jwt.claim.sub = '99000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.developer_accounts;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK7_regular_user_sees_zero_allowlist_rows', v_count, 0);
end
$$;

insert into results
select 'CHECK8_notifications_realtime_publication_enabled',
  case when exists (
    select 1
    from pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public'
      and tablename='notifications'
  ) then 1 else 0 end,
  1;

insert into results
select 'CHECK9_developer_rpc_still_works',
  case when public.is_developer_account() = false then 1 else 0 end,
  1;
-- The owner session has no auth.uid(); fail-closed false is expected here.
-- Per-caller true/false behavior is exhaustively covered by WYN-125.

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create $DB_NAME" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub setup errored" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: schema.sql errored while loading" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/10_assert.sql"; then
  echo "FAIL: WYN-190 assertions errored" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

cat "$WORK_DIR/psql.out"

FAILURES=0
while IFS='|' read -r name actual expected; do
  name="$(echo "$name" | xargs)"
  actual="$(echo "$actual" | xargs)"
  expected="$(echo "$expected" | xargs)"
  case "$name" in
    CHECK*)
      if [ "$actual" != "$expected" ]; then
        echo "FAIL: $name -- expected $expected, got $actual"
        FAILURES=$((FAILURES + 1))
      else
        echo "PASS: $name (expected $expected, got $actual)"
      fi
      ;;
  esac
done < "$WORK_DIR/psql.out"

dropdb_any "$DB_NAME"

if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES WYN-190 check(s) failed"
  exit 1
fi

echo "ALL CHECKS PASSED"
