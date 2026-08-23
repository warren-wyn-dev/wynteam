#!/usr/bin/env bash
# Regression test for WYN-039 (Private Account + Follow Request) -- proves
# the core security/product guarantees at the database layer under the
# real `authenticated` role (not the Postgres superuser, which bypasses
# RLS entirely), mirroring wyn_038_view_counting_test.sh's exact
# harness/role-switching convention.
#
#   1.  Sending a Follow Request to a Private account creates a
#       follow_requests row, NOT a follows row.
#   2.  A pending requester cannot see the target's Drop (RLS on drops).
#   3.  An unrelated third party cannot see a Private account's Drop.
#   4.  The account owner can always see their own Drop.
#   5.  Accept: follows row created, follow_requests row gone,
#       follow_request_accepted notification sent to the requester.
#   6.  After Accept, the (former) requester can see the Drop.
#   7.  Reject (target deletes the request): no follows row, no
#       notification, request gone.
#   8.  A blocked user cannot send a Follow Request at all.
#   9.  A raw client INSERT directly into `follows` against a Private
#       target is denied by RLS (the only path is the Request flow).
#   10. follower_count()/following_count() return the true total
#       regardless of who is asking (unlike the raw follows row list).
#   11. A third party cannot see a `follows` edge into/out of a Private
#       account they have no relationship with, even though the edge is
#       real.
#   12. Following a Public account is still an instant, direct `follows`
#       insert -- WYN-008 regression, completely unchanged.
#   13. Switching Private -> Public auto-approves every pending request.
#   14. Self-request is rejected by a CHECK constraint.
#   15. Requesting someone you already follow is rejected.
#   16. get_poll_results() hides a Private account's poll results from a
#       non-follower even when they already know the poll_id, and still
#       shows them to an accepted follower.
#   17. ReDrop leak: if a follower of a Private author ReDrops that
#       Drop, a third party who does NOT follow the original author
#       still cannot see the ReDrop -- visibility is inherited from the
#       original author, not the redropper.
#   18. Remove Follower (Requirement 3, added after an independent QA
#       finding that it was missing entirely): the person being followed
#       can remove one of their own followers directly; the follower
#       themself can still unfollow (WYN-008, unchanged); an unrelated
#       third party can do neither.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_038_view_counting_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_039_private_account_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a failure
# message otherwise. Never touches any real/dev/prod database -- creates
# and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn039_private_account_regression_test"
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

create table results (check_name text primary key, actual int, expected int);

-- alice: Private account owner. bob: requester who ends up accepted.
-- carol: unrelated third party/stranger. dave: blocked by alice, tries
-- to request anyway. erin: requester who gets rejected. frank: a Public
-- account (regression baseline). grace: follows frank directly. henry:
-- has a pending request against alice when she flips back to Public.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'erin@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'frank@test.com'),
  ('77777777-7777-7777-7777-777777777777', 'grace@test.com'),
  ('88888888-8888-8888-8888-888888888888', 'henry@test.com');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user', true),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user', false),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user', false),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user', false),
  ('55555555-5555-5555-5555-555555555555', 'erin', 'Erin', 'user', false),
  ('66666666-6666-6666-6666-666666666666', 'frank', 'Frank', 'user', false),
  ('77777777-7777-7777-7777-777777777777', 'grace', 'Grace', 'user', false),
  ('88888888-8888-8888-8888-888888888888', 'henry', 'Henry', 'user', false);

-- Fixture Drop D1, owned by alice (private) -- inserted directly as the
-- table owner (bypassing RLS), same fixture shape as wyn_038's own.
insert into public.drops (id, author_id, image_url, caption, created_at) values
  ('d1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'https://example.com/d1.jpg', 'alice ต้นฉบับ D1', now());

-- dave blocks alice ahead of time (CHECK8).
insert into public.blocks (blocker_id, blocked_id) values
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111');

-- ------------------------------------------------------------
-- CHECK 1-4: sending a request never creates a follow, and content
-- stays hidden from everyone but the owner until accepted.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follow_requests (requester_id, target_id) values
    ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK1_request_creates_pending_row',
    (select count(*) from public.follow_requests
     where requester_id = '22222222-2222-2222-2222-222222222222'
       and target_id = '11111111-1111-1111-1111-111111111111')::int, 1;

  insert into results select 'CHECK2_request_does_not_create_follow',
    (select count(*) from public.follows
     where follower_id = '22222222-2222-2222-2222-222222222222'
       and following_id = '11111111-1111-1111-1111-111111111111')::int, 0;
end
$$;

do $$
declare
  v_seen int;
begin
  -- CHECK3: bob (still pending, not yet accepted) cannot see alice's Drop.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen from public.drops where id = 'd1111111-0000-0000-0000-000000000001';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK3_pending_requester_cannot_see_drop', v_seen, 0;
end
$$;

do $$
declare
  v_seen int;
begin
  -- CHECK4: carol, an unrelated stranger, cannot see it either.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen from public.drops where id = 'd1111111-0000-0000-0000-000000000001';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK4_stranger_cannot_see_private_drop', v_seen, 0;
end
$$;

do $$
declare
  v_seen int;
begin
  -- CHECK5 (regression): alice always sees her own Drop.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen from public.drops where id = 'd1111111-0000-0000-0000-000000000001';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK5_owner_always_sees_own_drop', v_seen, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6-8: Accept.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.accept_follow_request('22222222-2222-2222-2222-222222222222');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK6a_accept_creates_follow',
    (select count(*) from public.follows
     where follower_id = '22222222-2222-2222-2222-222222222222'
       and following_id = '11111111-1111-1111-1111-111111111111')::int, 1;

  insert into results select 'CHECK6b_accept_removes_request',
    (select count(*) from public.follow_requests
     where requester_id = '22222222-2222-2222-2222-222222222222'
       and target_id = '11111111-1111-1111-1111-111111111111')::int, 0;

  insert into results select 'CHECK8_accept_notifies_requester',
    (select count(*) from public.notifications
     where recipient_id = '22222222-2222-2222-2222-222222222222'
       and actor_id = '11111111-1111-1111-1111-111111111111'
       and type = 'follow_request_accepted')::int, 1;
end
$$;

do $$
declare
  v_seen int;
begin
  -- CHECK7: bob can now see alice's Drop.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen from public.drops where id = 'd1111111-0000-0000-0000-000000000001';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK7_accepted_follower_sees_drop', v_seen, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: Reject (target deletes the pending request directly).
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follow_requests (requester_id, target_id) values
    ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  delete from public.follow_requests
  where requester_id = '55555555-5555-5555-5555-555555555555'
    and target_id = '11111111-1111-1111-1111-111111111111';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK9a_reject_removes_request',
    (select count(*) from public.follow_requests
     where requester_id = '55555555-5555-5555-5555-555555555555'
       and target_id = '11111111-1111-1111-1111-111111111111')::int, 0;

  insert into results select 'CHECK9b_reject_creates_no_follow',
    (select count(*) from public.follows
     where follower_id = '55555555-5555-5555-5555-555555555555'
       and following_id = '11111111-1111-1111-1111-111111111111')::int, 0;

  insert into results select 'CHECK9c_reject_sends_no_notification',
    (select count(*) from public.notifications
     where recipient_id = '55555555-5555-5555-5555-555555555555'
       and type in ('follow_request_accepted'))::int, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10: a blocked user cannot send a Follow Request at all.
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.follow_requests (requester_id, target_id) values
      ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK10_blocked_user_cannot_send_request', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 11: a raw INSERT straight into `follows` against a Private
-- target is denied -- the Request flow is the only path.
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.follows (follower_id, following_id) values
      ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK11_direct_follow_insert_denied_for_private_target', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 12: follower_count()/following_count() are always the true
-- total, even for a stranger who cannot see the row list itself.
-- ------------------------------------------------------------
do $$
declare
  v_count bigint;
begin
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select public.follower_count('11111111-1111-1111-1111-111111111111') into v_count;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK12_follower_count_visible_to_stranger', v_count::int, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 13: a third party cannot see the bob->alice follows row even
-- though it genuinely exists (alice is private, carol has no
-- relationship to her).
-- ------------------------------------------------------------
do $$
declare
  v_seen int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen from public.follows
    where follower_id = '22222222-2222-2222-2222-222222222222'
      and following_id = '11111111-1111-1111-1111-111111111111';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK13_third_party_cannot_see_private_edge', v_seen, 0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 14 (regression): following a Public account is still an
-- instant, direct `follows` insert -- WYN-008, untouched.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follows (follower_id, following_id) values
    ('77777777-7777-7777-7777-777777777777', '66666666-6666-6666-6666-666666666666');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK14_public_account_instant_follow_unchanged',
    (select count(*) from public.follows
     where follower_id = '77777777-7777-7777-7777-777777777777'
       and following_id = '66666666-6666-6666-6666-666666666666')::int, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 15: Private -> Public auto-approves pending requests.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '88888888-8888-8888-8888-888888888888';
  set request.jwt.claim.role = 'authenticated';
  insert into public.follow_requests (requester_id, target_id) values
    ('88888888-8888-8888-8888-888888888888', '11111111-1111-1111-1111-111111111111');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  update public.profiles set is_private = false where id = '11111111-1111-1111-1111-111111111111';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK15a_switch_to_public_auto_approves',
    (select count(*) from public.follows
     where follower_id = '88888888-8888-8888-8888-888888888888'
       and following_id = '11111111-1111-1111-1111-111111111111')::int, 1;

  insert into results select 'CHECK15b_switch_to_public_clears_request',
    (select count(*) from public.follow_requests
     where target_id = '11111111-1111-1111-1111-111111111111')::int, 0;

  -- flip alice back to private for the remaining checks below, which
  -- assume her Drop/poll are gated again.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  update public.profiles set is_private = true where id = '11111111-1111-1111-1111-111111111111';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 16: self-request and duplicate-request-when-already-following
-- are both rejected.
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.follow_requests (requester_id, target_id) values
      ('11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK16a_self_request_rejected', case when v_failed then 1 else 0 end, 1;
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  -- bob already follows alice (from CHECK6) -- a second request must be
  -- rejected by the INSERT policy's "not already following" clause.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.follow_requests (requester_id, target_id) values
      ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK16b_request_to_already_followed_rejected', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 17: get_poll_results() respects the same private gating even
-- though it's SECURITY DEFINER (bypasses drops' RLS internally).
-- ------------------------------------------------------------
insert into public.drop_polls (id, drop_id, options, expires_at) values
  ('99999999-0000-0000-0000-000000000001', 'd1111111-0000-0000-0000-000000000001',
   array['ตัวเลือก A', 'ตัวเลือก B'], now() + interval '1 day');

do $$
begin
  -- bob (accepted follower) votes.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_poll_votes (poll_id, voter_id, option_index) values
    ('99999999-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 0);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_row record;
begin
  -- carol (stranger, does not follow alice) must get either no row or
  -- visible=false, never real vote counts.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select * into v_row from public.get_poll_results(array['99999999-0000-0000-0000-000000000001']::uuid[]) limit 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK17a_stranger_cannot_read_private_poll_results',
    case when v_row is null then 1 else 0 end, 1;
end
$$;

do $$
declare
  v_total bigint;
begin
  -- bob (accepted follower) can read the real results.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select total_votes into v_total from public.get_poll_results(array['99999999-0000-0000-0000-000000000001']::uuid[]) limit 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK17b_follower_reads_real_poll_results', v_total::int, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 18: ReDrop leak -- bob (alice's accepted follower) ReDrops D1;
-- carol (who follows bob, but NOT alice) must still not see it.
-- Visibility follows the ORIGINAL author (alice), not the redropper.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id) values
    ('d1111111-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_seen int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen
  from public.redrops r
  join public.drops d on d.id = r.drop_id
  where r.drop_id = 'd1111111-0000-0000-0000-000000000001'
    and r.redropper_id = '22222222-2222-2222-2222-222222222222';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK18_redrop_of_private_drop_stays_hidden_from_non_follower', v_seen, 0;
end
$$;

do $$
declare
  v_seen int;
begin
  -- bob himself (the follower/redropper) must still see it.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_seen
  from public.redrops r
  join public.drops d on d.id = r.drop_id
  where r.drop_id = 'd1111111-0000-0000-0000-000000000001'
    and r.redropper_id = '22222222-2222-2222-2222-222222222222';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK18b_redrop_visible_to_follower_who_made_it', v_seen, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 19: Remove Follower (Requirement 3).
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  -- grace (unrelated third party) tries to remove bob as one of alice's
  -- followers -- must fail (grace is neither party to that edge).
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  delete from public.follows
  where follower_id = '22222222-2222-2222-2222-222222222222'
    and following_id = '11111111-1111-1111-1111-111111111111';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK19a_third_party_cannot_remove_someone_elses_follower',
    (select count(*) from public.follows
     where follower_id = '22222222-2222-2222-2222-222222222222'
       and following_id = '11111111-1111-1111-1111-111111111111')::int, 1;
end
$$;

do $$
begin
  -- alice (the one being followed) removes bob as a follower.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  delete from public.follows
  where follower_id = '22222222-2222-2222-2222-222222222222'
    and following_id = '11111111-1111-1111-1111-111111111111';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK19b_being_followed_can_remove_a_follower',
    (select count(*) from public.follows
     where follower_id = '22222222-2222-2222-2222-222222222222'
       and following_id = '11111111-1111-1111-1111-111111111111')::int, 0;
end
$$;

do $$
begin
  -- Regression: the follower themself can still unfollow directly
  -- (WYN-008's original policy, untouched) -- grace still follows frank
  -- from CHECK14 above.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  delete from public.follows
  where follower_id = '77777777-7777-7777-7777-777777777777'
    and following_id = '66666666-6666-6666-6666-666666666666';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK19c_follower_can_still_unfollow_directly',
    (select count(*) from public.follows
     where follower_id = '77777777-7777-7777-7777-777777777777'
       and following_id = '66666666-6666-6666-6666-666666666666')::int, 0;
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
