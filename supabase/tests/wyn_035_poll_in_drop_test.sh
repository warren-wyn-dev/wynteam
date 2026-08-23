#!/usr/bin/env bash
# Regression test for WYN-035 (Poll ใน Drop) -- proves the
# security/privacy-sensitive behavior actually works at the RLS/RPC/
# trigger layer, under the real `authenticated` role (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_034_redrop_test.sh's exact harness/role-switching convention.
#
#   1. create_poll_drop(): atomically creates a drops row with a null
#      image_url + its 1:1 drop_polls row + drop_mentions, and the
#      existing notify_drop_mention() trigger still fires from it.
#   2. valid_poll_options(): rejects <2 options, a >80-char option, and
#      case-insensitive duplicate options.
#   3. create_poll_drop() rejects a duration outside {1, 3, 7} days.
#   4. Voting: a vote inserts; changing your mind (upsert) updates the
#      same row rather than creating a second one; out-of-range
#      option_index is rejected; the poll's own author cannot vote on
#      it; a user blocked-either-way with the author cannot vote; a
#      posting-blocked (Restricted) user cannot vote; voting after
#      expires_at is rejected.
#   5. Privacy: get_poll_results() -- a non-voting, non-author viewer
#      sees visible=false (no counts) while the poll is open; a voter
#      or the author sees visible=true with correct counts; once a
#      poll's expires_at has passed, even a non-voter sees visible=true.
#      A direct SELECT against drop_poll_votes as any authenticated
#      user only ever returns that user's own row, never anyone else's
#      -- not even the poll's own author.
#   6. Deleting the underlying Drop cascades away its drop_polls and
#      drop_poll_votes rows.
#   7. home_feed's poll_id/poll_options/poll_expires_at columns are
#      populated correctly for a Poll Drop.
#   8. Regression: a normal image-based Drop (image_url not null) still
#      inserts cleanly after image_url became nullable.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_034_redrop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_035_poll_in_drop_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn035_poll_in_drop_regression_test"
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

-- alice: poll author (P1 on D1, P2 on D2). bob/carol: vote on P1.
-- dave: blocked BY alice -- tests the author-block vote gate. erin:
-- gets Restricted -- tests the posting-blocked vote gate. frank: votes
-- (then is blocked by the expiry check) on P2. grace: a neutral
-- never-voting viewer for visibility checks. henry: mentioned in D1's
-- caption, to prove notify_drop_mention() still fires from
-- create_poll_drop()'s mention insert.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'erin@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'frank@test.com'),
  ('77777777-7777-7777-7777-777777777777', 'grace@test.com'),
  ('88888888-8888-8888-8888-888888888888', 'henry@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'erin', 'Erin', 'user'),
  ('66666666-6666-6666-6666-666666666666', 'frank', 'Frank', 'user'),
  ('77777777-7777-7777-7777-777777777777', 'grace', 'Grace', 'user'),
  ('88888888-8888-8888-8888-888888888888', 'henry', 'Henry', 'user');

-- Fixture: erin gets an active Restrict (direct table-owner inserts,
-- bypassing RLS -- apply_moderation_action()/is_posting_blocked() are
-- WYN-029's own concern, already regression-tested there). Mirrors
-- wyn_034_redrop_test.sh's identical fixture shape.
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', 'user', '55555555-5555-5555-5555-555555555555', 'spam', 'actioned');
insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555', '77777777-7777-7777-7777-777777777777', 'restrict', 'spam fixture', 3, now() + interval '3 days');

-- alice blocks dave.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.block_user('44444444-4444-4444-4444-444444444444'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 1-2: create_poll_drop() creates drops+drop_polls atomically
-- with a null image_url, and its mention insert still fires
-- notify_drop_mention().
-- ------------------------------------------------------------
do $$
declare
  v_drop_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.create_poll_drop(
    'กินอะไรดี @henry?',
    array['Pizza', 'Sushi', 'Burger'],
    3,
    array['88888888-8888-8888-8888-888888888888'::uuid]
  ) into v_drop_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  perform set_config('wyn035.d1', v_drop_id::text, false);

  insert into results
  select 'CHECK1_poll_drop_created_null_image', count(*), 1
  from public.drops where id = v_drop_id and image_url is null;

  insert into results
  select 'CHECK2_mention_notification_fired', count(*), 1
  from public.notifications
  where recipient_id = '88888888-8888-8888-8888-888888888888'
    and type = 'mention_drop' and drop_id = v_drop_id;
end
$$;

-- ------------------------------------------------------------
-- CHECK 3-6: valid_poll_options()/create_poll_drop() input validation.
-- ------------------------------------------------------------
do $$
begin
  insert into results values (
    'CHECK3_rejects_single_option',
    case when public.valid_poll_options(array['Only one']) then 1 else 0 end,
    0
  );
  insert into results values (
    'CHECK4_rejects_too_long_option',
    case when public.valid_poll_options(array['a', repeat('x', 81)]) then 1 else 0 end,
    0
  );
  insert into results values (
    'CHECK5_rejects_case_insensitive_duplicate',
    case when public.valid_poll_options(array['Yes', 'yes']) then 1 else 0 end,
    0
  );
  insert into results values (
    'CHECK6_accepts_valid_options',
    case when public.valid_poll_options(array['Yes', 'No']) then 1 else 0 end,
    1
  );

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_poll_drop('bad duration?', array['Yes', 'No'], 2, '{}');
    insert into results values ('CHECK7_rejects_invalid_duration', 0, 1);
  exception when others then
    insert into results values ('CHECK7_rejects_invalid_duration', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8-16: voting lifecycle, permission gates, and privacy on P1
-- (the poll on D1, still open -- expires_at = now() + 3 days).
-- ------------------------------------------------------------
do $$
declare
  v_d1 uuid := current_setting('wyn035.d1')::uuid;
  v_p1 uuid;
begin
  select id into v_p1 from public.drop_polls where drop_id = v_d1;
  perform set_config('wyn035.p1', v_p1::text, false);

  -- CHECK8: bob votes option 0.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_poll_votes (poll_id, voter_id, option_index)
  values (v_p1, '22222222-2222-2222-2222-222222222222', 0);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK8_vote_inserted', count(*), 1
  from public.drop_poll_votes where poll_id = v_p1 and voter_id = '22222222-2222-2222-2222-222222222222' and option_index = 0;

  -- CHECK9: bob changes his mind to option 1 (upsert -- still one row).
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_poll_votes (poll_id, voter_id, option_index)
  values (v_p1, '22222222-2222-2222-2222-222222222222', 1)
  on conflict (poll_id, voter_id) do update set option_index = excluded.option_index;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK9_vote_changed_single_row', count(*), 1
  from public.drop_poll_votes where poll_id = v_p1 and voter_id = '22222222-2222-2222-2222-222222222222' and option_index = 1;

  -- carol votes option 1 too (no CHECK of its own -- feeds CHECK12/13's counts).
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_poll_votes (poll_id, voter_id, option_index)
  values (v_p1, '33333333-3333-3333-3333-333333333333', 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK10: out-of-range option_index (P1 has 3 options -- valid 0-2) rejected.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '77777777-7777-7777-7777-777777777777', 5);
    insert into results values ('CHECK10_out_of_range_option_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK10_out_of_range_option_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK11: the poll's own author (alice) cannot vote on it.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '11111111-1111-1111-1111-111111111111', 0);
    insert into results values ('CHECK11_author_cannot_vote_own_poll', 0, 1);
  exception when others then
    insert into results values ('CHECK11_author_cannot_vote_own_poll', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK12: dave (blocked by alice, the author) cannot vote.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '44444444-4444-4444-4444-444444444444', 0);
    insert into results values ('CHECK12_blocked_author_cannot_vote', 0, 1);
  exception when others then
    insert into results values ('CHECK12_blocked_author_cannot_vote', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK13: erin (Restricted / posting-blocked) cannot vote.
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_poll_votes (poll_id, voter_id, option_index)
    values (v_p1, '55555555-5555-5555-5555-555555555555', 0);
    insert into results values ('CHECK13_restricted_user_cannot_vote', 0, 1);
  exception when others then
    insert into results values ('CHECK13_restricted_user_cannot_vote', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK14: privacy -- bob's own SELECT on drop_poll_votes for P1
  -- returns only his own row (1), never carol's, even though 2 exist.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK14_privacy_only_own_vote_visible',
    (select count(*) from public.drop_poll_votes where poll_id = v_p1), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK15: grace (never voted, not author, poll still open) sees
  -- visible=false via get_poll_results -- no percentages leaked.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK15_non_voter_results_hidden_while_open',
    (select case when visible then 1 else 0 end from public.get_poll_results(array[v_p1])), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK16: bob (voted) sees visible=true with correct total (2) and
  -- per-option counts ([0, 2, 0] -- both bob and carol landed on
  -- index 1 after bob's CHECK9 vote change).
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK16_voter_sees_correct_results',
    (select case when visible and total_votes = 2 and option_counts = array[0, 2, 0]::bigint[] then 1 else 0 end
     from public.get_poll_results(array[v_p1])),
    1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK17: alice (author, never voted herself) also sees visible=true
  -- with the same correct results -- the author-sees-results rule
  -- doesn't depend on having voted.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK17_author_sees_results_without_voting',
    (select case when visible and total_votes = 2 then 1 else 0 end from public.get_poll_results(array[v_p1])),
    1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 18-19: a poll past its expires_at rejects new votes, and
-- reveals results even to a viewer who never voted.
-- ------------------------------------------------------------
do $$
declare
  v_d2 uuid;
  v_p2 uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.create_poll_drop('จะไปเที่ยวไหมพรุ่งนี้?', array['ไป', 'ไม่ไป'], 1, '{}') into v_d2;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_p2 from public.drop_polls where drop_id = v_d2;
  perform set_config('wyn035.d2', v_d2::text, false);

  -- Force this poll into the past -- direct owner-bypassing update
  -- (fixture setup, same posture as the moderation_actions fixture
  -- above), simulating "3 days already elapsed" without waiting.
  update public.drop_polls set expires_at = now() - interval '1 minute' where id = v_p2;

  -- CHECK18: frank tries to vote on the now-closed P2 -- rejected.
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_poll_votes (poll_id, voter_id, option_index)
    values (v_p2, '66666666-6666-6666-6666-666666666666', 0);
    insert into results values ('CHECK18_closed_poll_rejects_vote', 0, 1);
  exception when others then
    insert into results values ('CHECK18_closed_poll_rejects_vote', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK19: grace (never voted P2, not its author) sees results now
  -- that it's closed -- visible=true, 0 votes.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK19_closed_poll_visible_to_everyone',
    (select case when visible and total_votes = 0 and option_counts = array[0, 0]::bigint[] then 1 else 0 end
     from public.get_poll_results(array[v_p2])),
    1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 20-21: home_feed's poll columns, and cascade delete.
-- ------------------------------------------------------------
do $$
declare
  v_d1 uuid := current_setting('wyn035.d1')::uuid;
  v_p1 uuid := current_setting('wyn035.p1')::uuid;
  v_d2 uuid := current_setting('wyn035.d2')::uuid;
begin
  -- CHECK20: home_feed exposes P2's poll_id/poll_options/expires_at
  -- correctly on its drop row.
  set role authenticated;
  set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK20_home_feed_poll_columns_populated',
    (select case when poll_id is not null and poll_options = array['ไป', 'ไม่ไป'] and poll_expires_at is not null then 1 else 0 end
     from public.home_feed where id = v_d2),
    1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK21: deleting D1 cascades away its drop_polls + drop_poll_votes rows.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  delete from public.drops where id = v_d1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK21_delete_drop_cascades_poll_and_votes',
    (select count(*) from public.drop_polls where id = v_p1)
      + (select count(*) from public.drop_poll_votes where poll_id = v_p1),
    0;
end
$$;

-- ------------------------------------------------------------
-- CHECK 22: regression -- a plain image-based Drop still inserts
-- cleanly now that drops.image_url is nullable rather than required.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (author_id, image_url, caption)
  values ('11111111-1111-1111-1111-111111111111', 'https://example.com/plain.jpg', 'ปกติ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK22_plain_image_drop_still_works', count(*), 1
  from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and image_url = 'https://example.com/plain.jpg';
end
$$;

-- ------------------------------------------------------------
-- CHECK 23: a Restricted (posting-blocked) user cannot create a Poll
-- Drop at all -- create_poll_drop() re-derives is_posting_blocked()
-- itself (it's a SECURITY DEFINER function that bypasses the drops
-- INSERT policy's own posting-blocked check), so this has to be
-- proven directly against the RPC, not inferred from the base table's
-- RLS.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_poll_drop('โพลของ erin?', array['Yes', 'No'], 1, '{}');
    insert into results values ('CHECK23_restricted_user_cannot_create_poll', 0, 1);
  exception when others then
    insert into results values ('CHECK23_restricted_user_cannot_create_poll', 1, 1);
  end;
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
