#!/usr/bin/env bash
# Regression test for WYN-117 (Club Owner Insights) -- proves the
# aggregate RPC's authorization and counting logic at the database
# layer under the real `authenticated` role (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_116_club_reengagement_notifications_test.sh's exact harness.
#
#   1. Owner can call club_insights() and gets correct 7-day counts.
#   2. Admin can also call it (2-tier owner/admin gate, same as
#      canManageClub in Flutter).
#   3. Moderator is denied (wider 3-tier gate elsewhere in the app does
#      NOT apply here -- Insights is owner/admin only).
#   4. Plain member is denied.
#   5. Non-member is denied.
#   6. An invalid p_days value (not 7 or 30) is rejected.
#   7. 30-day window includes activity the 7-day window correctly
#      excludes (proves the cutoff actually filters, not just returns
#      all-time totals) -- new_members/new_posts/likes_and_comments/
#      active_members are all asserted for both windows.
#   8. A brand-new Club with no posts/likes/comments returns 0 for
#      those fields (and exactly 1 for new_members -- its own owner),
#      no error/crash.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_116_club_reengagement_notifications_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_117_club_owner_insights_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn117_club_owner_insights_regression_test"
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
-- Stub of Supabase platform pieces that schema.sql assumes already exist.
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

-- alice: club owner. bob: admin, joined 2 days ago. carol: moderator,
-- joined 40 days ago (outside both windows -- but still acts, to prove
-- active_members counting isn't role-gated, only *viewing* insights is).
-- dave: plain member, joined 20 days ago. frank: plain member, joined
-- 40 days ago. erin: non-member.
insert into auth.users (id, email) values
  ('88000000-0000-0000-0000-000000000001', 'alice@test.com'),
  ('88000000-0000-0000-0000-000000000002', 'bob@test.com'),
  ('88000000-0000-0000-0000-000000000003', 'carol@test.com'),
  ('88000000-0000-0000-0000-000000000004', 'dave@test.com'),
  ('88000000-0000-0000-0000-000000000005', 'frank@test.com'),
  ('88000000-0000-0000-0000-000000000006', 'erin@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('88000000-0000-0000-0000-000000000001', 'alice117', 'alice', 'user', false),
  ('88000000-0000-0000-0000-000000000002', 'bob117', 'bob', 'user', false),
  ('88000000-0000-0000-0000-000000000003', 'carol117', 'carol', 'user', false),
  ('88000000-0000-0000-0000-000000000004', 'dave117', 'dave', 'user', false),
  ('88000000-0000-0000-0000-000000000005', 'frank117', 'frank', 'user', false),
  ('88000000-0000-0000-0000-000000000006', 'erin117', 'erin', 'user', false);

insert into public.clubs (id, name, privacy, owner_id) values
  ('88000000-0000-0000-0000-0000000000c1', 'Alice Club', 'public', '88000000-0000-0000-0000-000000000001');

-- alice's own (owner, approved) row is inserted automatically by the
-- clubs_add_owner_membership trigger above, created_at = now() --
-- within both the 7-day and 30-day windows.
insert into public.club_members (club_id, user_id, role, status, created_at) values
  ('88000000-0000-0000-0000-0000000000c1', '88000000-0000-0000-0000-000000000002', 'admin', 'approved', now() - interval '2 days'),
  ('88000000-0000-0000-0000-0000000000c1', '88000000-0000-0000-0000-000000000003', 'moderator', 'approved', now() - interval '40 days'),
  ('88000000-0000-0000-0000-0000000000c1', '88000000-0000-0000-0000-000000000004', 'member', 'approved', now() - interval '20 days'),
  ('88000000-0000-0000-0000-0000000000c1', '88000000-0000-0000-0000-000000000005', 'member', 'approved', now() - interval '40 days');

-- P1 (alice, 3 days ago -- within both windows), P2 (bob, 20 days ago
-- -- within 30d only), P3 (dave, 40 days ago -- outside both).
insert into public.club_posts (id, club_id, author_id, content, created_at, channel_id) values
  ('88000000-0000-0000-0000-0000000000d1', '88000000-0000-0000-0000-0000000000c1', '88000000-0000-0000-0000-000000000001', 'P1', now() - interval '3 days',
   (select id from public.club_channels where club_id = '88000000-0000-0000-0000-0000000000c1' order by created_at limit 1)),
  ('88000000-0000-0000-0000-0000000000d2', '88000000-0000-0000-0000-0000000000c1', '88000000-0000-0000-0000-000000000002', 'P2', now() - interval '20 days',
   (select id from public.club_channels where club_id = '88000000-0000-0000-0000-0000000000c1' order by created_at limit 1)),
  ('88000000-0000-0000-0000-0000000000d3', '88000000-0000-0000-0000-0000000000c1', '88000000-0000-0000-0000-000000000004', 'P3', now() - interval '40 days',
   (select id from public.club_channels where club_id = '88000000-0000-0000-0000-0000000000c1' order by created_at limit 1));

-- carol (moderator, otherwise outside both windows by join date) likes
-- P1 2 days ago -- within both windows; proves active_members counts
-- the action's own created_at, not the actor's club_members.created_at.
insert into public.club_post_likes (club_post_id, user_id, created_at) values
  ('88000000-0000-0000-0000-0000000000d1', '88000000-0000-0000-0000-000000000003', now() - interval '2 days');

-- frank likes P2 20 days ago -- within 30d only.
insert into public.club_post_likes (club_post_id, user_id, created_at) values
  ('88000000-0000-0000-0000-0000000000d2', '88000000-0000-0000-0000-000000000005', now() - interval '20 days');

-- dave comments on P1 1 day ago -- within both windows.
insert into public.club_post_comments (club_post_id, author_id, text_content, created_at) values
  ('88000000-0000-0000-0000-0000000000d1', '88000000-0000-0000-0000-000000000004', 'nice post', now() - interval '1 day');

-- A second, brand-new, empty Club for CHECK15 -- alice is again the
-- owner (auto-approved by the same trigger), nothing else ever happens
-- in it.
insert into public.clubs (id, name, privacy, owner_id) values
  ('88000000-0000-0000-0000-0000000000c2', 'Empty Club', 'public', '88000000-0000-0000-0000-000000000001');

-- ------------------------------------------------------------
-- CHECK 1-4: 7-day window counts for the Owner.
-- ------------------------------------------------------------
do $$
declare
  v_row record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select * into v_row from public.club_insights('88000000-0000-0000-0000-0000000000c1', 7);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1_7d_new_members', v_row.new_members::text, '2';
  insert into results select 'CHECK2_7d_new_posts', v_row.new_posts::text, '1';
  insert into results select 'CHECK3_7d_likes_and_comments', v_row.likes_and_comments::text, '2';
  insert into results select 'CHECK4_7d_active_members', v_row.active_members::text, '3';
end
$$;

-- ------------------------------------------------------------
-- CHECK 5-8: 30-day window counts -- proves the cutoff actually
-- widens/narrows results, not a fixed all-time total.
-- ------------------------------------------------------------
do $$
declare
  v_row record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select * into v_row from public.club_insights('88000000-0000-0000-0000-0000000000c1', 30);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK5_30d_new_members', v_row.new_members::text, '3';
  insert into results select 'CHECK6_30d_new_posts', v_row.new_posts::text, '2';
  insert into results select 'CHECK7_30d_likes_and_comments', v_row.likes_and_comments::text, '3';
  insert into results select 'CHECK8_30d_active_members', v_row.active_members::text, '5';
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: Admin (bob) can also call club_insights() successfully.
-- ------------------------------------------------------------
do $$
declare
  v_row record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000002';
  set request.jwt.claim.role = 'authenticated';
  select * into v_row from public.club_insights('88000000-0000-0000-0000-0000000000c1', 7);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9_admin_can_call', v_row.new_posts::text, '1';
end
$$;

-- ------------------------------------------------------------
-- CHECK 10-12: Moderator/Member/Non-member are all denied -- the
-- 2-tier owner/admin gate, not the wider 3-tier moderation gate.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000003';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_insights('88000000-0000-0000-0000-0000000000c1', 7);
    insert into results values ('CHECK10_moderator_denied', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK10_moderator_denied', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000004';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_insights('88000000-0000-0000-0000-0000000000c1', 7);
    insert into results values ('CHECK11_member_denied', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK11_member_denied', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000006';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_insights('88000000-0000-0000-0000-0000000000c1', 7);
    insert into results values ('CHECK12_non_member_denied', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK12_non_member_denied', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 13: an invalid p_days value is rejected, even for the owner.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform * from public.club_insights('88000000-0000-0000-0000-0000000000c1', 14);
    insert into results values ('CHECK13_invalid_days_rejected', 'allowed', 'denied');
  exception when others then
    insert into results values ('CHECK13_invalid_days_rejected', 'denied', 'denied');
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 14-15: a brand-new, empty Club shows 0 everywhere except
-- new_members (its own owner, exactly 1) -- no error/crash.
-- ------------------------------------------------------------
do $$
declare
  v_row record;
begin
  set role authenticated;
  set request.jwt.claim.sub = '88000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  select * into v_row from public.club_insights('88000000-0000-0000-0000-0000000000c2', 7);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK14_empty_club_new_members', v_row.new_members::text, '1';
  insert into results select 'CHECK15_empty_club_everything_else_zero',
    (v_row.new_posts + v_row.likes_and_comments + v_row.active_members)::text, '0';
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
