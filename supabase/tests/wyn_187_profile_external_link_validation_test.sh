#!/usr/bin/env bash
# Regression test for WYN-187 (WYNOS Web Beta1, item 11): server-side
# validation on profiles.social_links (the new external-website field).
# Mirrors wyn_130_club_members_ghost_accounts_test.sh's harness: loads
# schema.sql, then this feature's own migration file, then asserts under
# `set role authenticated` + a JWT sub claim.
#
#   1. A valid https:// website URL is accepted.
#   2. A javascript: URI is rejected.
#   3. An unrecognized key is rejected.
#   4. An empty-string value is rejected (omit the key instead).
#   5. A non-string value (a nested object) is rejected.
#   6. Removing the key entirely (back to '{}') is allowed -- the "delete
#      the link" path.
#   7. A profile insert that never touches social_links at all (the
#      default '{}') is unaffected by the trigger.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_130_club_members_ghost_accounts_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_187_profile_external_link_validation_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_wyn187_profile_external_link_validation.sql"
DB_NAME="wyn187_profile_external_link_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "FAIL: schema file not found at $SCHEMA_FILE" >&2
  exit 1
fi
if [ ! -f "$MIGRATION_FILE" ]; then
  echo "FAIL: migration file not found at $MIGRATION_FILE" >&2
  exit 1
fi

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
  if createdb "$db" >/dev/null 2>&1; then
    return 0
  elif command -v sudo >/dev/null 2>&1 && sudo -u postgres createdb "$db" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
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
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual text, expected text);

insert into auth.users (id, email) values
  ('96000000-0000-0000-0000-000000000001', 'alice@test.com');
insert into public.profiles (id, username, display_name, is_private) values
  ('96000000-0000-0000-0000-000000000001', 'alice187', 'alice', false);

-- ------------------------------------------------------------
-- CHECK 1: a valid https:// website URL is accepted.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '96000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    update public.profiles set social_links = '{"website": "https://example.com/alice"}'::jsonb
      where id = '96000000-0000-0000-0000-000000000001';
    insert into results values ('CHECK1_valid_https_website_accepted', 'allowed', 'allowed');
  exception when others then
    insert into results values ('CHECK1_valid_https_website_accepted', 'denied', 'allowed');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 2: a javascript: URI is rejected.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '96000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    update public.profiles set social_links = '{"website": "javascript:alert(1)"}'::jsonb
      where id = '96000000-0000-0000-0000-000000000001';
    insert into results values ('CHECK2_javascript_uri_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK2_javascript_uri_rejected', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: an unrecognized key is rejected.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '96000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    update public.profiles set social_links = '{"evil_key": "https://example.com"}'::jsonb
      where id = '96000000-0000-0000-0000-000000000001';
    insert into results values ('CHECK3_unrecognized_key_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK3_unrecognized_key_rejected', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: an empty-string value is rejected.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '96000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    update public.profiles set social_links = '{"website": ""}'::jsonb
      where id = '96000000-0000-0000-0000-000000000001';
    insert into results values ('CHECK4_empty_string_value_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK4_empty_string_value_rejected', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: a non-string value is rejected.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '96000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    update public.profiles set social_links = '{"website": {"nested": true}}'::jsonb
      where id = '96000000-0000-0000-0000-000000000001';
    insert into results values ('CHECK5_non_string_value_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK5_non_string_value_rejected', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: removing the link (back to '{}') is allowed.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '96000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    update public.profiles set social_links = '{}'::jsonb
      where id = '96000000-0000-0000-0000-000000000001';
    insert into results values ('CHECK6_removing_link_allowed', 'allowed', 'allowed');
  exception when others then
    insert into results values ('CHECK6_removing_link_allowed', 'denied', 'allowed');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7: a profile insert that never touches social_links (default
-- '{}') is unaffected by the trigger.
-- ------------------------------------------------------------
insert into auth.users (id, email) values
  ('96000000-0000-0000-0000-000000000002', 'bob@test.com');
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '96000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.profiles (id, username) values ('96000000-0000-0000-0000-000000000002', 'bob187');
    insert into results values ('CHECK7_default_social_links_unaffected', 'allowed', 'allowed');
  exception when others then
    insert into results values ('CHECK7_default_social_links_unaffected', 'denied', 'allowed');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: schema.sql errored while loading" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$MIGRATION_FILE"; then
  echo "FAIL: migrations_wyn187_profile_external_link_validation.sql errored while loading" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then
  echo "FAIL: seed/assert script errored" >&2
  cat "$WORK_DIR/psql.out" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

cat "$WORK_DIR/psql.out"

FAILURES=0
while IFS='|' read -r name actual expected; do
  name="$(echo "$name" | xargs)"
  actual="$(echo "$actual" | xargs)"
  expected="$(echo "$expected" | xargs)"
  [ -z "$name" ] && continue
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
  echo "FAIL: $FAILURES check(s) failed"
  exit 1
fi

echo "ALL CHECKS PASSED"
