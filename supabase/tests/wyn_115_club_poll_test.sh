#!/usr/bin/env bash
# Regression test for WYN-115 (Club Poll) -- proves the security/
# privacy-sensitive behavior actually works at the RLS/RPC/trigger
# layer, under the real `authenticated` role (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_035_poll_in_drop_test.sh's exact harness/role-switching
# convention (this feature reuses that one's schema/RPC shape almost
# entirely -- see .wyn/docs/design/wyn-115-club-poll.md).
#
#   1. create_poll_club_post(): atomically creates a club_posts row
#      (image_urls/link_url null, content = the question) + its 1:1
#      club_post_polls row + club_post_mentions, only for an approved
#      club member who isn't posting-blocked -- rejects a non-member,
#      a still-pending member, and a posting-blocked (banned) member.
#   2. valid_poll_options() input validation (reused directly from
#      WYN-035, not re-tested here) and create_poll_club_post()'s own
#      duration-outside-{1,3,7} rejection.
#   3. Voting: an approved member can vote; changing your mind
#      (upsert) updates the same row; out-of-range option_index is
#      rejected; the poll's own author cannot vote on it; a non-member,
#      a pending member, and a posting-blocked member all cannot vote
#      (the extra club-membership gate drop_poll_votes never needed);
#      voting after expires_at is rejected.
#   4. Privacy: get_club_poll_results() -- a non-member gets zero rows
#      back entirely (not just visible=false); an approved member who
#      hasn't voted sees visible=false while open; a voter or the
#      author sees visible=true with correct counts; once a poll's
#      expires_at has passed, even a non-voting member sees
#      visible=true. A direct SELECT against club_post_poll_votes as
#      any authenticated user only ever returns that user's own row.
#   5. RLS on club_post_polls itself: only an approved club member can
#      SELECT the poll row at all -- a non-member and a pending member
#      both get zero rows, same trust model club_posts already has.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_035_poll_in_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_115_club_poll_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn115_club_poll_regression_test"
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

-- alice: club owner, poll author (P1). bob/carol: approved members who
-- vote on P1. dave: still-pending member (never approved) -- tests the
-- pending-member gates on both create and vote. frank: an approved
-- member who is separately Banned (posting-blocked) -- tests that gate
-- distinctly from "not a member at all". grace: not a club member of
-- any kind -- the true outsider. henry: mentioned in P1's question, to
-- prove create_poll_club_post()'s mention insert still lands a row.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'frank@test.com'),
  ('77777777-7777-7777-7777-777777777777', 'grace@test.com'),
  ('88888888-8888-8888-8888-888888888888', 'henry@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user'),
  ('66666666-6666-6666-6666-666666666666', 'frank', 'Frank', 'user'),
  ('77777777-7777-7777-7777-777777777777', 'grace', 'Grace', 'user'),
  ('88888888-8888-8888-8888-888888888888', 'henry', 'Henry', 'user');

insert into public.clubs (id, name, privacy, owner_id) values
  ('c0000000-0000-0000-0000-000000000001', 'Photography Club', 'public', '11111111-1111-1111-1111-111111111111');

-- alice's own (owner, approved) row is inserted automatically by the
-- clubs_add_owner_membership trigger above -- not seeded again here.
insert into public.club_members (club_id, user_id, role, status) values
  ('c0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'member', 'approved'),
  ('c0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'member', 'approved'),
  ('c0000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444', 'member', 'pending'),
  ('c0000000-0000-0000-0000-000000000001', '66666666-6666-6666-6666-666666666666', 'member', 'approved'),
  ('c0000000-0000-0000-0000-000000000001', '88888888-8888-8888-8888-888888888888', 'member', 'approved');
-- grace is deliberately not a club_members row at all.

-- Fixture: frank gets a permanent Ban (direct table-owner inserts,
-- bypassing RLS -- apply_moderation_action()/is_posting_blocked() are
-- WYN-029's own concern, already regression-tested there). Mirrors
-- wyn_035_poll_in_drop_test.sh's identical fixture shape.
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', 'user', '66666666-6666-6666-6666-666666666666', 'spam', 'actioned');
insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason) values
  ('a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '66666666-6666-6666-6666-666666666666', '77777777-7777-7777-7777-777777777777', 'ban', 'spam fixture');

-- ------------------------------------------------------------
-- CHECK 1-4: create_poll_club_post() membership/moderation gates.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK1: grace (not a club member at all) cannot create a poll.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_poll_club_post('c0000000-0000-0000-0000-000000000001',
      (select id from public.club_channels where club_id = 'c0000000-0000-0000-0000-000000000001' order by created_at limit 1),
      'grace poll?', array['Yes', 'No'], 1, '{}');
    insert into results values ('CHECK1_non_member_cannot_create_poll', 0, 1);
  exception when others then
    insert into results values ('CHECK1_non_member_cannot_create_poll', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK2: dave (still-pending member) cannot create a poll.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_poll_club_post('c0000000-0000-0000-0000-000000000001',
      (select id from public.club_channels where club_id = 'c0000000-0000-0000-0000-000000000001' order by created_at limit 1),
      'dave poll?', array['Yes', 'No'], 1, '{}');
    insert into results values ('CHECK2_pending_member_cannot_create_poll', 0, 1);
  exception when others then
    insert into results values ('CHECK2_pending_member_cannot_create_poll', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK3: frank (approved but Banned) cannot create a poll.
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_poll_club_post('c0000000-0000-0000-0000-000000000001',
      (select id from public.club_channels where club_id = 'c0000000-0000-0000-0000-000000000001' order by created_at limit 1),
      'frank poll?', array['Yes', 'No'], 1, '{}');
    insert into results values ('CHECK3_banned_member_cannot_create_poll', 0, 1);
  exception when others then
    insert into results values ('CHECK3_banned_member_cannot_create_poll', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK4: bad duration (approved member, but invalid duration).
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_poll_club_post('c0000000-0000-0000-0000-000000000001',
      (select id from public.club_channels where club_id = 'c0000000-0000-0000-0000-000000000001' order by created_at limit 1),
      'bad duration?', array['Yes', 'No'], 2, '{}');
    insert into results values ('CHECK4_rejects_invalid_duration', 0, 1);
  exception when others then
    insert into results values ('CHECK4_rejects_invalid_duration', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5-8: alice (owner, approved) creates P1 successfully --
-- atomic club_posts+club_post_polls, null image_urls/link_url,
-- mention insert lands.
-- ------------------------------------------------------------
do $$
declare
  v_post_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.create_poll_club_post(
    'c0000000-0000-0000-0000-000000000001',
    (select id from public.club_channels where club_id = 'c0000000-0000-0000-0000-000000000001' order by created_at limit 1),
    'กล้องรุ่นไหนดี @henry?',
    array['Canon', 'Sony', 'Fuji'],
    3,
    array['88888888-8888-8888-8888-888888888888'::uuid]
  ) into v_post_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  perform set_config('wyn115.post1', v_post_id::text, false);

  insert into results
  select 'CHECK5_poll_post_created_null_image_and_link', count(*), 1
  from public.club_posts
  where id = v_post_id and image_urls is null and link_url is null
    and content = 'กล้องรุ่นไหนดี @henry?';

  insert into results
  select 'CHECK6_poll_row_created_with_options', count(*), 1
  from public.club_post_polls
  where club_post_id = v_post_id and options = array['Canon', 'Sony', 'Fuji'];

  insert into results
  select 'CHECK7_mention_row_created', count(*), 1
  from public.club_post_mentions
  where club_post_id = v_post_id and mentioned_user_id = '88888888-8888-8888-8888-888888888888';

  -- CHECK8: grace (not a member) cannot even SELECT the poll row --
  -- club_post_polls' own RLS, same trust model club_posts itself has.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK8_non_member_cannot_select_poll_row',
    (select count(*) from public.club_post_polls where club_post_id = v_post_id), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9-19: voting lifecycle, permission gates, and privacy on P1
-- (still open -- expires_at = now() + 3 days).
-- ------------------------------------------------------------
do $$
declare
  v_post1 uuid := current_setting('wyn115.post1')::uuid;
  v_p1 uuid;
begin
  select id into v_p1 from public.club_post_polls where club_post_id = v_post1;
  perform set_config('wyn115.p1', v_p1::text, false);

  -- CHECK9: dave (pending member) can SELECT the club_posts row? no --
  -- but specifically here: can he even see the poll row? Should be 0.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK9_pending_member_cannot_select_poll_row',
    (select count(*) from public.club_post_polls where id = v_p1), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK10: carol (approved member) CAN select the poll row.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK10_approved_member_can_select_poll_row',
    (select count(*) from public.club_post_polls where id = v_p1), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK11: bob votes option 0.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
  values (v_p1, '22222222-2222-2222-2222-222222222222', 0);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK11_vote_inserted', count(*), 1
  from public.club_post_poll_votes where poll_id = v_p1 and voter_id = '22222222-2222-2222-2222-222222222222' and option_index = 0;

  -- CHECK12: bob changes his mind to option 1 (upsert -- still one row).
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
  values (v_p1, '22222222-2222-2222-2222-222222222222', 1)
  on conflict (poll_id, voter_id) do update set option_index = excluded.option_index;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK12_vote_changed_single_row', count(*), 1
  from public.club_post_poll_votes where poll_id = v_p1 and voter_id = '22222222-2222-2222-2222-222222222222' and option_index = 1;

  -- carol votes option 1 too (feeds CHECK16/17's counts).
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
  values (v_p1, '33333333-3333-3333-3333-333333333333', 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK13: out-of-range option_index (P1 has 3 options -- valid 0-2) rejected.
  set role authenticated;
  set request.jwt.claim.sub = '88888888-8888-8888-8888-888888888888';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '88888888-8888-8888-8888-888888888888', 5);
    insert into results values ('CHECK13_out_of_range_option_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK13_out_of_range_option_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK14: the poll's own author (alice) cannot vote on it.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '11111111-1111-1111-1111-111111111111', 0);
    insert into results values ('CHECK14_author_cannot_vote_own_poll', 0, 1);
  exception when others then
    insert into results values ('CHECK14_author_cannot_vote_own_poll', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK15: grace (not a club member at all) cannot vote -- the extra
  -- membership gate drop_poll_votes never needed.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '77777777-7777-7777-7777-777777777777', 0);
    insert into results values ('CHECK15_non_member_cannot_vote', 0, 1);
  exception when others then
    insert into results values ('CHECK15_non_member_cannot_vote', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK16: dave (still-pending member) cannot vote either.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '44444444-4444-4444-4444-444444444444', 0);
    insert into results values ('CHECK16_pending_member_cannot_vote', 0, 1);
  exception when others then
    insert into results values ('CHECK16_pending_member_cannot_vote', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK17: frank (approved but Banned/posting-blocked) cannot vote.
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '66666666-6666-6666-6666-666666666666', 0);
    insert into results values ('CHECK17_banned_member_cannot_vote', 0, 1);
  exception when others then
    insert into results values ('CHECK17_banned_member_cannot_vote', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK18: privacy -- bob's own SELECT on club_post_poll_votes for
  -- P1 returns only his own row (1), never carol's, even though 2 exist.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK18_privacy_only_own_vote_visible',
    (select count(*) from public.club_post_poll_votes where poll_id = v_p1), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK19: get_club_poll_results -- grace (not a member) gets zero
  -- rows back entirely, not just visible=false.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK19_non_member_gets_no_result_row',
    (select count(*) from public.get_club_poll_results(array[v_p1])), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK20: henry (approved member, never voted, not author, poll
  -- still open) sees visible=false via get_club_poll_results -- no
  -- percentages leaked.
  set role authenticated;
  set request.jwt.claim.sub = '88888888-8888-8888-8888-888888888888';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK20_non_voter_results_hidden_while_open',
    (select case when visible then 1 else 0 end from public.get_club_poll_results(array[v_p1])), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK21: bob (voted) sees visible=true with correct total (2) and
  -- per-option counts ([0, 2, 0] -- both bob and carol landed on
  -- index 1 after bob's CHECK12 vote change).
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK21_voter_sees_correct_results',
    (select case when visible and total_votes = 2 and option_counts = array[0, 2, 0]::bigint[] then 1 else 0 end
     from public.get_club_poll_results(array[v_p1])),
    1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK22: alice (author, never voted herself) also sees
  -- visible=true with the same correct results.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK22_author_sees_results_without_voting',
    (select case when visible and total_votes = 2 then 1 else 0 end from public.get_club_poll_results(array[v_p1])),
    1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 23-24: a poll past its expires_at rejects new votes, and
-- reveals results even to a member who never voted.
-- ------------------------------------------------------------
do $$
declare
  v_post2 uuid;
  v_p2 uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.create_poll_club_post('c0000000-0000-0000-0000-000000000001',
    (select id from public.club_channels where club_id = 'c0000000-0000-0000-0000-000000000001' order by created_at limit 1),
    'จะจัด meetup วันไหน?', array['เสาร์', 'อาทิตย์'], 1, '{}') into v_post2;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_p2 from public.club_post_polls where club_post_id = v_post2;

  -- Force this poll into the past -- direct owner-bypassing update
  -- (fixture setup, same posture as the moderation_actions fixture
  -- above), simulating "1 day already elapsed" without waiting.
  update public.club_post_polls set expires_at = now() - interval '1 minute' where id = v_p2;

  -- CHECK23: bob (approved member) tries to vote on the now-closed P2
  -- -- rejected.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_post_poll_votes (poll_id, voter_id, option_index)
    values (v_p2, '22222222-2222-2222-2222-222222222222', 0);
    insert into results values ('CHECK23_closed_poll_rejects_vote', 0, 1);
  exception when others then
    insert into results values ('CHECK23_closed_poll_rejects_vote', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK24: carol (never voted P2, not its author) sees results now
  -- that it's closed -- visible=true, 0 votes.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK24_closed_poll_visible_to_every_member',
    (select case when visible and total_votes = 0 and option_counts = array[0, 0]::bigint[] then 1 else 0 end
     from public.get_club_poll_results(array[v_p2])),
    1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME" >&2
  exit 1
fi

if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: stub setup failed" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: schema.sql failed to load cleanly" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi

echo "== Seeding fixtures and running RLS/RPC/trigger checks =="
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
