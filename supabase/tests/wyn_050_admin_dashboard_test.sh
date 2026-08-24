#!/usr/bin/env bash
# Regression test for WYN-050 (WYN Admin Dashboard -- admin_dashboard_metrics()
# RPC) -- proves the core guarantees at the database layer under the real
# `authenticated` role (not the Postgres superuser, which bypasses RLS
# entirely), mirroring wyn_049-era tests' harness/role-switching convention
# (this task has no equivalent prior test since it's the first Phase 7 SQL
# addition; the harness itself is copied from wyn_048_audit_log_test.sh).
#
#   1. An admin can call the RPC and gets back counts that match a hand
#      count of seeded rows across every table it aggregates.
#   2. A moderator can call it too (not admin-only, per the Product spec).
#   3. An ordinary `user`-role account is rejected.
#   4. A soft-deleted message is excluded from messages_today.
#   5. reports_total and reports_pending are counted independently (a
#      dismissed report doesn't count as pending, but still counts toward
#      the total).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage:
#   bash supabase/tests/wyn_050_admin_dashboard_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn050_admin_dashboard_regression_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "FAIL: schema file not found at $SCHEMA_FILE" >&2
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

create table results (check_name text primary key, actual bigint, expected bigint);

-- admin: platform_role = 'admin', calls the RPC (CHECK1-*).
-- moderator: platform_role = 'moderator', also allowed (CHECK2).
-- bob/carol: ordinary users, generate the activity being counted;
-- carol also calls the RPC herself to prove rejection (CHECK3).
insert into auth.users (id, email) values
  ('70000000-0000-0000-0000-000000000001', 'admin@test.com'),
  ('70000000-0000-0000-0000-000000000002', 'moderator@test.com'),
  ('70000000-0000-0000-0000-000000000003', 'bob@test.com'),
  ('70000000-0000-0000-0000-000000000004', 'carol@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('70000000-0000-0000-0000-000000000001', 'admin', 'admin', 'admin', false),
  ('70000000-0000-0000-0000-000000000002', 'moderator', 'moderator', 'moderator', false),
  ('70000000-0000-0000-0000-000000000003', 'bob', 'bob', 'user', false),
  ('70000000-0000-0000-0000-000000000004', 'carol', 'carol', 'user', false);

-- One Drop (bob), one like + one comment + one ReDrop + one view (all
-- carol), one Club (bob, auto-owns via clubs_add_owner_membership),
-- one conversation with 2 messages (1 live, 1 soft-deleted, both from
-- bob), 2 reports (1 pending, 1 dismissed, both by carol).
do $$
declare
  v_drop_id uuid;
  v_club_id uuid;
  v_conversation_id uuid;
begin
  insert into public.drops (author_id, image_url, caption)
  values ('70000000-0000-0000-0000-000000000003', 'https://example.com/a.jpg', 'bob drop')
  returning id into v_drop_id;

  insert into public.drop_likes (drop_id, user_id)
  values (v_drop_id, '70000000-0000-0000-0000-000000000004');

  insert into public.drop_comments (drop_id, author_id, text_content)
  values (v_drop_id, '70000000-0000-0000-0000-000000000004', 'nice drop');

  insert into public.redrops (drop_id, redropper_id, quote_text)
  values (v_drop_id, '70000000-0000-0000-0000-000000000004', null);

  insert into public.drop_views (drop_id, viewer_id)
  values (v_drop_id, '70000000-0000-0000-0000-000000000004');

  insert into public.clubs (name, description, owner_id, privacy)
  values ('Test Club', 'desc', '70000000-0000-0000-0000-000000000003', 'public')
  returning id into v_club_id;

  insert into public.conversations (user_a_id, user_b_id, status)
  values (
    least('70000000-0000-0000-0000-000000000003'::uuid, '70000000-0000-0000-0000-000000000004'::uuid),
    greatest('70000000-0000-0000-0000-000000000003'::uuid, '70000000-0000-0000-0000-000000000004'::uuid),
    'active'
  )
  returning id into v_conversation_id;

  insert into public.messages (conversation_id, sender_id, text)
  values (v_conversation_id, '70000000-0000-0000-0000-000000000003', 'hello carol');

  -- Soft-deleted -- must NOT count toward messages_today.
  insert into public.messages (conversation_id, sender_id, text, deleted_at)
  values (v_conversation_id, '70000000-0000-0000-0000-000000000003', null, now());

  insert into public.reports (reporter_id, target_type, target_id, category, status)
  values ('70000000-0000-0000-0000-000000000004', 'drop', v_drop_id, 'spam', 'pending');

  insert into public.reports (reporter_id, target_type, target_id, category, status, detail)
  values ('70000000-0000-0000-0000-000000000004', 'user', '70000000-0000-0000-0000-000000000003', 'other', 'dismissed', 'not actually a problem');
end
$$;

-- ------------------------------------------------------------
-- CHECK 1: admin calls the RPC -- every field matches a hand count.
-- ------------------------------------------------------------
do $$
declare
  r record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '70000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select * into r from public.admin_dashboard_metrics();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1a_new_users_today', r.new_users_today, 4;
  -- distinct actors today: bob (drop + message), carol (like/comment/
  -- redrop, still one distinct actor) = 2.
  insert into results select 'CHECK1b_dau', r.dau, 2;
  insert into results select 'CHECK1c_wau', r.wau, 2;
  insert into results select 'CHECK1d_mau', r.mau, 2;
  insert into results select 'CHECK1e_drops_today', r.drops_today, 1;
  insert into results select 'CHECK1f_views_today', r.views_today, 1;
  insert into results select 'CHECK1g_clubs_total', r.clubs_total, 1;
  insert into results select 'CHECK1h_clubs_new_today', r.clubs_new_today, 1;
  insert into results select 'CHECK1i_likes_today', r.likes_today, 1;
  insert into results select 'CHECK1j_comments_today', r.comments_today, 1;
  insert into results select 'CHECK1k_redrops_today', r.redrops_today, 1;
  insert into results select 'CHECK1l_messages_today_excludes_deleted', r.messages_today, 1;
  insert into results select 'CHECK1m_reports_total', r.reports_total, 2;
  insert into results select 'CHECK1n_reports_pending_excludes_dismissed', r.reports_pending, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 2: moderator can call it too (not admin-only).
-- ------------------------------------------------------------
do $$
declare
  v_drops_today bigint;
begin
  set role authenticated;
  set request.jwt.claim.sub = '70000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select drops_today into v_drops_today from public.admin_dashboard_metrics();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK2_moderator_allowed', v_drops_today, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3: an ordinary user-role account is rejected.
-- ------------------------------------------------------------
do $$
declare
  v_rejected bigint := 0;
begin
  set role authenticated;
  set request.jwt.claim.sub = '70000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_dashboard_metrics();
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK3_ordinary_user_rejected', v_rejected, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 4: a caller with an auth.users row but NO profiles row at
-- all must also be rejected -- internal.current_platform_role()
-- returns NULL for them, and a naive `not in (...)` check silently
-- lets NULL through (PL/pgSQL's `if` treats NULL like false). See
-- .wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md.
-- ------------------------------------------------------------
do $$
declare
  v_rejected bigint := 0;
begin
  insert into auth.users (id, email)
  values ('70000000-0000-0000-0000-000000000099', 'noprofile@test.com');

  set role authenticated;
  set request.jwt.claim.sub = '70000000-0000-0000-0000-000000000099';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.admin_dashboard_metrics();
  exception when others then
    v_rejected := 1;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK4_caller_with_no_profile_row_rejected', v_rejected, 1;
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
