#!/usr/bin/env bash
# Regression test for WYN-129 (Club Role Badge) -- proves the RLS
# permission boundaries at the real `authenticated` role (not the
# Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_115_club_poll_test.sh's exact harness/role-switching convention.
#
# This feature had **no** committed RLS regression test at all before
# this file -- see .wyn/tasks/bugs/WYN-129-badge-update-target-membership-gap.md
# and .wyn/tasks/bugs/WYN-127-128-129-missing-staged-rollout-gate.md's
# sibling bug report for the same observation.
#
#   1. Owner/Admin can INSERT a badge for an approved member; Moderator/
#      plain Member/non-member cannot.
#   2. INSERT rejects a target who is a non-member, a still-pending
#      member, or a banned member (club_role(club_id, user_id) is null
#      in all 3 cases) -- the `insert` policy's own target-membership
#      gate.
#   3. color_key is restricted to the 3 approved values -- any other
#      value is rejected by the CHECK constraint.
#   4. At most 1 badge per (club_id, user_id) -- enforced by the primary
#      key, a second INSERT for the same pair is rejected.
#   5. **This bug's exact repro** (WYN-129-badge-update-target-membership-gap.md):
#      before the fix, an Owner/Admin could UPDATE an existing badge
#      row's `user_id` to point at a non-member/pending/banned user,
#      bypassing the same invariant INSERT enforces. After the fix, all
#      3 retarget attempts are rejected (0 rows affected).
#   6. A legitimate UPDATE that only changes label/color_key (never
#      user_id) still succeeds for Owner/Admin -- the fix must not
#      break the one real call site (ClubBadgeRepository.setBadge's
#      upsert, which never changes user_id).
#   7. DELETE is Owner/Admin only; a plain Member cannot delete anyone's
#      badge.
#   8. SELECT is open to every authenticated user regardless of their
#      own membership in the Club (badges carry no privacy boundary of
#      their own -- same posture as club_channels).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_115_club_poll_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_129_club_role_badges_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn129_club_role_badges_regression_test"
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

create table results (check_name text primary key, actual int, expected int);

-- alice: owner. bob: admin (approved). carol: plain member (approved) --
-- the legitimate badge target. dave: never had a club_members row at
-- all. erin: still-pending member. frank: approved member who is later
-- Banned. grace: plain member (approved) -- proves a non-Owner/Admin
-- cannot manage badges at all.
insert into auth.users (id, email) values
  ('a1111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('a2222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('a3333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('a4444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('a5555555-5555-5555-5555-555555555555', 'erin@test.com'),
  ('a6666666-6666-6666-6666-666666666666', 'frank@test.com'),
  ('a7777777-7777-7777-7777-777777777777', 'grace@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('a1111111-1111-1111-1111-111111111111', 'alice129', 'Alice', 'user'),
  ('a2222222-2222-2222-2222-222222222222', 'bob129', 'Bob', 'user'),
  ('a3333333-3333-3333-3333-333333333333', 'carol129', 'Carol', 'user'),
  ('a4444444-4444-4444-4444-444444444444', 'dave129', 'Dave', 'user'),
  ('a5555555-5555-5555-5555-555555555555', 'erin129', 'Erin', 'user'),
  ('a6666666-6666-6666-6666-666666666666', 'frank129', 'Frank', 'user'),
  ('a7777777-7777-7777-7777-777777777777', 'grace129', 'Grace', 'user');

insert into public.clubs (id, name, privacy, owner_id) values
  ('c1111111-0000-0000-0000-000000000001', 'Badge Club', 'public', 'a1111111-1111-1111-1111-111111111111');

-- alice's own (owner, approved) row is inserted automatically by the
-- clubs_add_owner_membership trigger -- not seeded again here.
insert into public.club_members (club_id, user_id, role, status) values
  ('c1111111-0000-0000-0000-000000000001', 'a2222222-2222-2222-2222-222222222222', 'admin', 'approved'),
  ('c1111111-0000-0000-0000-000000000001', 'a3333333-3333-3333-3333-333333333333', 'member', 'approved'),
  ('c1111111-0000-0000-0000-000000000001', 'a5555555-5555-5555-5555-555555555555', 'member', 'pending'),
  ('c1111111-0000-0000-0000-000000000001', 'a6666666-6666-6666-6666-666666666666', 'member', 'banned'),
  ('c1111111-0000-0000-0000-000000000001', 'a7777777-7777-7777-7777-777777777777', 'member', 'approved');
-- dave is deliberately not a club_members row at all.

-- ------------------------------------------------------------
-- CHECK1-4: INSERT permission boundary -- only Owner/Admin, only for an
-- approved-member target.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK1: Owner (alice) can badge an approved member (carol).
  set role authenticated;
  set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a3333333-3333-3333-3333-333333333333', 'VIP', 'gold', 'a1111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK1_owner_can_badge_approved_member', 1, 1);
  exception when others then
    insert into results values ('CHECK1_owner_can_badge_approved_member', 0, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK2: Admin (bob) can badge another approved member (grace).
  set role authenticated;
  set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a7777777-7777-7777-7777-777777777777', 'Helper', 'sage', 'a2222222-2222-2222-2222-222222222222');
    insert into results values ('CHECK2_admin_can_badge_approved_member', 1, 1);
  exception when others then
    insert into results values ('CHECK2_admin_can_badge_approved_member', 0, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK3: a plain Member (carol) cannot badge anyone, even herself.
  set role authenticated;
  set request.jwt.claim.sub = 'a3333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a3333333-3333-3333-3333-333333333333', 'Self', 'plum', 'a3333333-3333-3333-3333-333333333333');
    insert into results values ('CHECK3_plain_member_cannot_insert_badge', 0, 1);
  exception when others then
    insert into results values ('CHECK3_plain_member_cannot_insert_badge', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK4a: Owner cannot badge dave (not a club_members row at all).
  set role authenticated;
  set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a4444444-4444-4444-4444-444444444444', 'Ghost', 'gold', 'a1111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK4a_owner_cannot_badge_non_member', 0, 1);
  exception when others then
    insert into results values ('CHECK4a_owner_cannot_badge_non_member', 1, 1);
  end;

  -- CHECK4b: Owner cannot badge erin (still pending).
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a5555555-5555-5555-5555-555555555555', 'Pending', 'gold', 'a1111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK4b_owner_cannot_badge_pending_member', 0, 1);
  exception when others then
    insert into results values ('CHECK4b_owner_cannot_badge_pending_member', 1, 1);
  end;

  -- CHECK4c: Owner cannot badge frank (banned).
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a6666666-6666-6666-6666-666666666666', 'Banned', 'gold', 'a1111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK4c_owner_cannot_badge_banned_member', 0, 1);
  exception when others then
    insert into results values ('CHECK4c_owner_cannot_badge_banned_member', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK5: color_key is restricted to the 3 approved values.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a3333333-3333-3333-3333-333333333333', 'Bad Color', 'crimson', 'a1111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK5_color_key_rejects_value_outside_palette', 0, 1);
  exception when others then
    insert into results values ('CHECK5_color_key_rejects_value_outside_palette', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK6: at most 1 badge per (club_id, user_id) -- carol already has a
-- badge from CHECK1; a second insert for the same pair must be
-- rejected by the primary key.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_member_badges (club_id, user_id, label, color_key, created_by)
    values ('c1111111-0000-0000-0000-000000000001', 'a3333333-3333-3333-3333-333333333333', 'Second Badge', 'sage', 'a1111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK6_one_badge_per_member_per_club_enforced', 0, 1);
  exception when others then
    insert into results values ('CHECK6_one_badge_per_member_per_club_enforced', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK7-9: **the bug's exact repro** -- WYN-129-badge-update-target-
-- membership-gap.md. Before the fix, an Owner/Admin could UPDATE an
-- existing badge's user_id to point at a non-member/pending/banned
-- user (0 rows blocked -- the bug). After the fix (the `with check`
-- added to the `update` policy), Postgres raises "new row violates
-- row-level security policy" for each of these 3 attempts instead of
-- silently matching-but-filtering -- each is caught and recorded as
-- "0 rows affected", the same observable outcome QA's repro checked
-- for either way.
-- ------------------------------------------------------------
do $$
declare
  v_rows int;
begin
  set role authenticated;
  set request.jwt.claim.sub = 'a2222222-2222-2222-2222-222222222222'; -- bob, admin
  set request.jwt.claim.role = 'authenticated';

  -- CHECK7: retarget carol's badge to dave (not a member at all).
  begin
    update public.club_member_badges
    set user_id = 'a4444444-4444-4444-4444-444444444444'
    where club_id = 'c1111111-0000-0000-0000-000000000001' and user_id = 'a3333333-3333-3333-3333-333333333333';
    get diagnostics v_rows = row_count;
  exception when others then
    v_rows := 0;
  end;
  insert into results values ('CHECK7_update_cannot_retarget_to_non_member', v_rows, 0);

  -- CHECK8: retarget carol's badge to erin (still pending).
  begin
    update public.club_member_badges
    set user_id = 'a5555555-5555-5555-5555-555555555555'
    where club_id = 'c1111111-0000-0000-0000-000000000001' and user_id = 'a3333333-3333-3333-3333-333333333333';
    get diagnostics v_rows = row_count;
  exception when others then
    v_rows := 0;
  end;
  insert into results values ('CHECK8_update_cannot_retarget_to_pending_member', v_rows, 0);

  -- CHECK9: retarget carol's badge to frank (banned).
  begin
    update public.club_member_badges
    set user_id = 'a6666666-6666-6666-6666-666666666666'
    where club_id = 'c1111111-0000-0000-0000-000000000001' and user_id = 'a3333333-3333-3333-3333-333333333333';
    get diagnostics v_rows = row_count;
  exception when others then
    v_rows := 0;
  end;
  insert into results values ('CHECK9_update_cannot_retarget_to_banned_member', v_rows, 0);

  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK10: regression -- carol's badge row survived every rejected
-- retarget above completely unchanged (still points at carol).
-- ------------------------------------------------------------
insert into results select 'CHECK10_carol_badge_unchanged_after_rejected_retargets', count(*), 1
from public.club_member_badges
where club_id = 'c1111111-0000-0000-0000-000000000001' and user_id = 'a3333333-3333-3333-3333-333333333333';

-- ------------------------------------------------------------
-- CHECK11: a legitimate UPDATE (label/color only, user_id unchanged)
-- still succeeds for Owner/Admin -- the fix must not break the app's
-- one real call site (ClubBadgeRepository.setBadge's upsert).
-- ------------------------------------------------------------
do $$
declare
  v_rows int;
begin
  set role authenticated;
  set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111'; -- alice, owner
  set request.jwt.claim.role = 'authenticated';

  update public.club_member_badges
  set label = 'VIP+', color_key = 'plum'
  where club_id = 'c1111111-0000-0000-0000-000000000001' and user_id = 'a3333333-3333-3333-3333-333333333333';
  get diagnostics v_rows = row_count;
  insert into results values ('CHECK11_legitimate_label_color_update_still_succeeds', v_rows, 1);

  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

insert into results select 'CHECK11b_legitimate_update_applied', count(*), 1
from public.club_member_badges
where club_id = 'c1111111-0000-0000-0000-000000000001'
  and user_id = 'a3333333-3333-3333-3333-333333333333'
  and label = 'VIP+' and color_key = 'plum';

-- ------------------------------------------------------------
-- CHECK12-13: DELETE is Owner/Admin only.
-- ------------------------------------------------------------
do $$
declare
  v_rows int;
begin
  -- CHECK12: a plain Member (carol) cannot delete grace's badge.
  set role authenticated;
  set request.jwt.claim.sub = 'a3333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  delete from public.club_member_badges
  where club_id = 'c1111111-0000-0000-0000-000000000001' and user_id = 'a7777777-7777-7777-7777-777777777777';
  get diagnostics v_rows = row_count;
  insert into results values ('CHECK12_plain_member_cannot_delete_badge', v_rows, 0);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK13: Owner (alice) can delete grace's badge.
  set role authenticated;
  set request.jwt.claim.sub = 'a1111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  delete from public.club_member_badges
  where club_id = 'c1111111-0000-0000-0000-000000000001' and user_id = 'a7777777-7777-7777-7777-777777777777';
  get diagnostics v_rows = row_count;
  insert into results values ('CHECK13_owner_can_delete_badge', v_rows, 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK14: SELECT is open to every authenticated user, regardless of
-- their own membership in this Club (dave is not a member at all).
-- ------------------------------------------------------------
do $$
declare
  v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = 'a4444444-4444-4444-4444-444444444444'; -- dave, non-member
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_member_badges
  where club_id = 'c1111111-0000-0000-0000-000000000001';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK14_non_member_can_still_select_badges', case when v_count >= 1 then 1 else 0 end, 1);
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
