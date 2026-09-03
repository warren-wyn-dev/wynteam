#!/usr/bin/env bash
# ============================================================
# STALE as of WYN-083 (Wynos V1.0.0 Beta2, item 21, 2026-09-02) -- DO
# NOT TRUST CHECK2/CHECK3 (or anything numerically downstream of them,
# which is most of the rest of this file) UNTIL RE-AUDITED.
#
# Founder reversed 2 of this task's own original design decisions:
# "การนับวิว จะนับตั้งแต่วินาทีแรก ที่มีคนเห็น รวมถึงเจ้าของโพสต์ด้วย
# นับไม่จำกัด" -- record_drop_view() no longer excludes the Drop's own
# author (CHECK3 now asserts the wrong thing) and drop_views is no
# longer a unique-viewer/lifetime-dedup ledger, so a repeat View from
# the same viewer now increments the count again (CHECK2 now asserts
# the wrong thing too). See supabase/schema.sql's drop_views/
# record_drop_view() doc comments and .wyn/company/DECISIONS.md
# (2026-09-02) for the full change.
#
# This file could not be run *at all* in the WYN-083 session to verify
# a rewrite -- schema.sql currently fails to load fresh into an empty
# Postgres 16 (a separate, pre-existing, unrelated bug -- a home_feed
# view migration-history conflict, also documented in DECISIONS.md
# 2026-09-02) -- so rewriting all the interdependent counts below
# blind, with no way to execute and catch a mistake, was judged too
# risky to do as part of that task. WYN-083 instead added a small,
# actually-runnable standalone test (not dependent on schema.sql
# loading) that directly proves the 2 new behaviors:
# wyn_083_view_count_owner_and_repeat_test.sh.
#
# Whoever picks this file up next: fix the schema.sql load issue
# first (or work around it the same way wyn_083's test does), then
# re-derive every count below by hand against the new behavior, then
# actually run it before trusting it again.
# ============================================================
#
# Regression test for WYN-038 (View Counting System -- Drop) -- proves
# record_drop_view()/drop_view_count() enforce their business rules at
# the database layer under the real `authenticated` role (not the
# Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_037_edit_delete_drop_test.sh's exact harness/role-switching
# convention.
#
#   1.  First-time View from a non-owner increments drop_view_count().
#   2.  A repeat View from the SAME viewer (any number of times) never
#       increments it again -- the (drop_id, viewer_id) primary key is
#       the unique-viewer/lifetime dedup mechanism.
#   3.  The Drop's own author viewing their own Drop never counts.
#   4.  A different viewer counts as a genuinely new View (unique per
#       person, not a global counter).
#   5.  Rate limit: one account calling record_drop_view() rapidly
#       across many distinct Drops is capped at 20 new rows in the
#       trailing 60 seconds -- the rest are silent no-ops, never a
#       raised exception.
#   6.  Velocity cap: many distinct accounts calling record_drop_view()
#       rapidly against the SAME Drop is capped at 50 new rows in the
#       trailing 10 seconds -- same silent-no-op posture.
#   7.  drop_views' SELECT policy only ever lets a user see their OWN
#       view history -- never another specific viewer's rows, even by
#       filtering directly for that viewer_id, and never the full
#       table total.
#   8.  drop_view_count() returns the exact same number regardless of
#       who calls it (owner, a viewer, or a stranger who never viewed).
#   9.  A soft-deleted Drop (WYN-037) can no longer accrue new Views --
#       silent no-op, not an error.
#   10. Regression: Like/Comment/Save/ReDrop/Poll vote counts are
#       unaffected by View recording, and vice versa.
#   11. Regression: Pop's own increment_pop_view_count()/view_count is
#       completely untouched by this task (out of scope).
#   12. home_feed's Drop branch surfaces the real drop_view_count()
#       value (was hardcoded null::bigint before this task).
#   13. saved_feed's Drop branch does the same.
#   14. home_feed's ReDrop branch (a ReDrop of a Drop) also surfaces
#       the SAME view_count as the original Drop.
#   15. home_feed's Pop branch still surfaces the raw pops.view_count
#       column, unrouted through drop_view_count() -- proving the Pop
#       branch itself was never touched.
#   16. There is no client-facing INSERT policy on drop_views at all --
#       a raw INSERT attempt (bypassing record_drop_view()) is denied
#       by RLS.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_037_edit_delete_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_038_view_counting_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn038_view_counting_regression_test"
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

-- alice: Drop author (D1). bob: first non-owner viewer (also ReDrops
-- D1 for CHECK14). carol: second non-owner viewer, and reads-only
-- stranger for the privacy checks. dave: dedicated account for the
-- per-account rate-limit check (CHECK5). erin: dedicated viewer used
-- after D1 is soft-deleted (CHECK9), and also gets a fresh Pop for the
-- Pop-regression check (CHECK11).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'erin@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'erin', 'Erin', 'user');

-- Fixture Drop D1, owned by alice -- inserted directly as the table
-- owner (bypassing RLS), same fixture shape as wyn_037's own.
insert into public.drops (id, author_id, image_url, caption, created_at) values
  ('d1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'https://example.com/d1.jpg', 'ต้นฉบับ D1', now());

-- ------------------------------------------------------------
-- CHECK 1-4: unique-viewer dedup, self-view exclusion, and per-person
-- counting via record_drop_view()/drop_view_count().
-- ------------------------------------------------------------
do $$
begin
  -- CHECK1: bob (a non-owner) views D1 for the first time.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK1_first_view_increments',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 1;
end
$$;

do $$
begin
  -- CHECK2: bob views D1 again, several more times (different
  -- sessions/app opens, same account) -- must NOT increment again.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK2_repeat_view_same_viewer_no_increment',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 1;
end
$$;

do $$
begin
  -- CHECK3: alice (D1's own author) views her own Drop -- must NOT
  -- count as a View.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK3_self_view_excluded',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 1;

  -- alice's own view was never inserted at all -- not just excluded
  -- from the count.
  insert into results
  select 'CHECK3b_self_view_not_inserted_as_a_row',
    (select count(*) from public.drop_views
     where drop_id = 'd1111111-0000-0000-0000-000000000001'
       and viewer_id = '11111111-1111-1111-1111-111111111111')::int, 0;
end
$$;

do $$
begin
  -- CHECK4: carol (a different non-owner) views D1 -- a genuinely new
  -- View, count goes to 2.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK4_different_viewers_count_correctly',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 5: rate limit -- one account (dave) hammering record_drop_view
-- across 25 distinct Drops must be capped at 20 new rows.
-- ------------------------------------------------------------
do $$
declare
  v_drop_ids uuid[] := array(select gen_random_uuid() from generate_series(1, 25));
  i int;
  v_failed boolean := false;
begin
  for i in 1..25 loop
    insert into public.drops (id, author_id, image_url, caption, created_at)
    values (v_drop_ids[i], '11111111-1111-1111-1111-111111111111', 'https://example.com/rate.jpg', 'rate-limit fixture', now());
  end loop;

  begin
    set role authenticated;
    set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
    set request.jwt.claim.role = 'authenticated';
    for i in 1..25 loop
      perform public.record_drop_view(v_drop_ids[i]);
    end loop;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;

  insert into results
  select 'CHECK5a_rate_limit_never_raises', case when v_failed then 0 else 1 end, 1;

  insert into results
  select 'CHECK5b_rate_limit_caps_new_rows_at_20',
    (select count(*) from public.drop_views where viewer_id = '44444444-4444-4444-4444-444444444444')::int, 20;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: velocity cap -- 55 distinct fresh accounts hammering the
-- SAME Drop must be capped at 50 new rows.
-- ------------------------------------------------------------
do $$
declare
  v_target_drop uuid := 'd6666666-0000-0000-0000-000000000006';
  v_viewer_ids uuid[] := array(select gen_random_uuid() from generate_series(1, 55));
  i int;
  v_failed boolean := false;
begin
  insert into public.drops (id, author_id, image_url, caption, created_at)
  values (v_target_drop, '11111111-1111-1111-1111-111111111111', 'https://example.com/velocity.jpg', 'velocity-cap fixture', now());

  for i in 1..55 loop
    insert into auth.users (id, email) values (v_viewer_ids[i], 'velocity' || i || '@test.com');
    insert into public.profiles (id, username, display_name, platform_role)
    values (v_viewer_ids[i], 'velocity' || i, 'Velocity ' || i, 'user');
  end loop;

  begin
    set role authenticated;
    set request.jwt.claim.role = 'authenticated';
    for i in 1..55 loop
      perform set_config('request.jwt.claim.sub', v_viewer_ids[i]::text, false);
      perform public.record_drop_view(v_target_drop);
    end loop;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;

  insert into results
  select 'CHECK6a_velocity_cap_never_raises', case when v_failed then 0 else 1 end, 1;

  insert into results
  select 'CHECK6b_velocity_cap_caps_new_rows_at_50',
    public.drop_view_count(v_target_drop)::int, 50;
end
$$;

-- ------------------------------------------------------------
-- CHECK 7-8: drop_views' SELECT policy leaks nothing about other
-- viewers, and drop_view_count() agrees for every caller regardless.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK7a: carol (who has exactly 1 view row of her own, on D1) sees
  -- only her own row when reading drop_views unfiltered -- not the
  -- true total across every account (bob + dave's 20 + the 55
  -- velocity-cap viewers' 50, all recorded above).
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK7a_select_sees_only_own_rows',
    (select count(*) from public.drop_views)::int, 1;

  -- CHECK7b: carol explicitly filtering for bob's viewer_id still sees
  -- nothing -- RLS hides the row entirely, filter or not.
  insert into results
  select 'CHECK7b_cannot_see_another_specific_viewers_row',
    (select count(*) from public.drop_views
     where viewer_id = '22222222-2222-2222-2222-222222222222')::int, 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK7c: the real total (read as table owner, bypassing RLS) is
  -- much larger than what carol could see above -- proves CHECK7a
  -- wasn't just "there happens to be only one row".
  insert into results
  select 'CHECK7c_true_total_is_larger_than_any_single_viewers_view',
    case when (select count(*) from public.drop_views) > 1 then 1 else 0 end, 1;
end
$$;

do $$
begin
  -- CHECK8: alice (owner), bob (a viewer), and carol (a viewer) all
  -- get the exact same drop_view_count(D1) -- 2, from CHECK4 -- no
  -- matter which of them calls it.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK8a_view_count_same_for_owner',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 2;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK8b_view_count_same_for_a_viewer',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 2;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK8c_view_count_same_for_another_viewer',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 2;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9: a soft-deleted Drop (WYN-037) can no longer accrue Views.
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.soft_delete_drop('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  begin
    set role authenticated;
    set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
    set request.jwt.claim.role = 'authenticated';
    perform public.record_drop_view('d1111111-0000-0000-0000-000000000001');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;

  insert into results
  select 'CHECK9a_view_on_deleted_drop_never_raises', case when v_failed then 0 else 1 end, 1;

  -- drop_view_count() itself is called as alice (table-owner-bypassing
  -- SECURITY DEFINER, so it can still see the soft-deleted row's
  -- children fine) -- the count must stay at 2, unchanged from CHECK4.
  insert into results
  select 'CHECK9b_view_count_unchanged_after_delete',
    public.drop_view_count('d1111111-0000-0000-0000-000000000001')::int, 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10: regression -- Like/Comment/Save/ReDrop/Poll counts are
-- unaffected by View recording, and vice versa.
-- ------------------------------------------------------------
insert into public.drops (id, author_id, image_url, caption, created_at) values
  ('d1010101-0000-0000-0000-000000000010', '11111111-1111-1111-1111-111111111111', 'https://example.com/regression.jpg', 'regression fixture', now());

do $$
declare
  v_poll_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_likes (drop_id, user_id) values ('d1010101-0000-0000-0000-000000000010', '22222222-2222-2222-2222-222222222222');
  insert into public.drop_comments (drop_id, author_id, text_content) values ('d1010101-0000-0000-0000-000000000010', '22222222-2222-2222-2222-222222222222', 'คอมเมนต์ regression');
  insert into public.saves (user_id, content_type, content_id) values ('22222222-2222-2222-2222-222222222222', 'drop', 'd1010101-0000-0000-0000-000000000010');
  insert into public.redrops (drop_id, redropper_id) values ('d1010101-0000-0000-0000-000000000010', '22222222-2222-2222-2222-222222222222');
  perform public.record_drop_view('d1010101-0000-0000-0000-000000000010');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  v_poll_id := public.create_poll_drop(
    p_caption := 'กินอะไรดี?',
    p_options := array['พิซซ่า', 'ซูชิ'],
    p_duration_days := 3,
    p_mentioned_user_ids := array[]::uuid[]
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.record_drop_view(v_poll_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK10a_like_count_unaffected_by_view',
    (select count(*) from public.drop_likes where drop_id = 'd1010101-0000-0000-0000-000000000010')::int, 1;
  insert into results
  select 'CHECK10b_comment_count_unaffected_by_view',
    (select count(*) from public.drop_comments where drop_id = 'd1010101-0000-0000-0000-000000000010')::int, 1;
  insert into results
  select 'CHECK10c_save_unaffected_by_view',
    (select count(*) from public.saves where content_id = 'd1010101-0000-0000-0000-000000000010')::int, 1;
  insert into results
  select 'CHECK10d_redrop_count_unaffected_by_view',
    (select count(*) from public.redrops where drop_id = 'd1010101-0000-0000-0000-000000000010')::int, 1;
  insert into results
  select 'CHECK10e_view_count_unaffected_by_like_comment_save_redrop',
    public.drop_view_count('d1010101-0000-0000-0000-000000000010')::int, 1;
  insert into results
  select 'CHECK10f_poll_drop_still_works_and_can_still_be_viewed',
    public.drop_view_count(v_poll_id)::int, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 11: regression -- Pop's own increment_pop_view_count()/
-- view_count is completely untouched by this task.
-- ------------------------------------------------------------
insert into public.pops (id, author_id, video_url, duration_seconds, caption) values
  ('50000000-0000-0000-0000-000000000011', '55555555-5555-5555-5555-555555555555', 'https://example.com/regression.mp4', 20, 'pop regression');

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.increment_pop_view_count('50000000-0000-0000-0000-000000000011');
  perform public.increment_pop_view_count('50000000-0000-0000-0000-000000000011');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK11_pop_view_count_unaffected_still_a_plain_counter',
    (select view_count from public.pops where id = '50000000-0000-0000-0000-000000000011')::int, 2;
end
$$;

-- ------------------------------------------------------------
-- CHECK 12-15: home_feed/saved_feed surface the real value for Drops
-- (and only Drops) via drop_view_count(), while Pop's own branch stays
-- untouched.
-- ------------------------------------------------------------
insert into public.saves (user_id, content_type, content_id) values
  ('33333333-3333-3333-3333-333333333333', 'drop', 'd1010101-0000-0000-0000-000000000010');

do $$
begin
  -- Read as carol -- a viewer with no special relationship to any of
  -- these rows beyond what home_feed/saved_feed themselves grant.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';

  insert into results
  select 'CHECK12_home_feed_drop_branch_view_count_matches',
    (select view_count from public.home_feed
     where id = 'd1010101-0000-0000-0000-000000000010' and redrop_id is null)::int,
    public.drop_view_count('d1010101-0000-0000-0000-000000000010')::int;

  insert into results
  select 'CHECK13_saved_feed_drop_branch_view_count_matches',
    (select view_count from public.saved_feed
     where id = 'd1010101-0000-0000-0000-000000000010' and user_id = '33333333-3333-3333-3333-333333333333')::int,
    public.drop_view_count('d1010101-0000-0000-0000-000000000010')::int;

  insert into results
  select 'CHECK14_home_feed_redrop_branch_view_count_matches_original',
    (select view_count from public.home_feed
     where id = 'd1010101-0000-0000-0000-000000000010' and redrop_id is not null)::int,
    public.drop_view_count('d1010101-0000-0000-0000-000000000010')::int;

  insert into results
  select 'CHECK15_home_feed_pop_branch_view_count_still_raw_pops_column',
    (select view_count from public.home_feed where id = '50000000-0000-0000-0000-000000000011')::int,
    (select view_count from public.pops where id = '50000000-0000-0000-0000-000000000011')::int;

  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 16: no client-facing INSERT policy on drop_views at all -- a
-- raw insert (bypassing record_drop_view()) is denied by RLS.
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    set request.jwt.claim.role = 'authenticated';
    insert into public.drop_views (drop_id, viewer_id)
    values ('d1010101-0000-0000-0000-000000000010', '22222222-2222-2222-2222-222222222222')
    on conflict (drop_id, viewer_id) do nothing;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK16_raw_client_insert_denied_by_rls', case when v_failed then 1 else 0 end, 1;
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
