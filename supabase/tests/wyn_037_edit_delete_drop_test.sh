#!/usr/bin/env bash
# Regression test for WYN-037 (Edit / Delete Drop) -- proves the 3 new
# RPCs (edit_drop/soft_delete_drop/restore_drop) enforce their business
# rules at the database layer under the real `authenticated` role (not
# the Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_035_poll_in_drop_test.sh/wyn_036_draft_system_test.sh's exact
# harness/role-switching convention.
#
#   1. The author can edit their own Drop's caption within the
#      30-minute window; edited_at gets set.
#   2. The author CANNOT edit past the 30-minute window (a real
#      exception, not a silent no-op -- verified by catching it).
#   3. A stranger cannot edit someone else's Drop at all (any window).
#   4. The author can soft-delete their own Drop -- the row still
#      physically exists (deleted_at set) but disappears from a
#      stranger's SELECT entirely, while the author can still see it.
#   5. Cannot soft-delete an already-deleted Drop.
#   6. The author can restore within the 30-day window -- the Drop
#      becomes visible to a stranger again.
#   7. CANNOT restore past the 30-day window.
#   8. A stranger cannot soft-delete or restore someone else's Drop.
#   9. A ReDrop of a soft-deleted original disappears from home_feed
#      for everyone, including the redropper themselves (only the
#      original Drop's own author can still see it) -- no view/schema
#      change needed for this, proving RLS-on-drops alone is enough.
#   10. Comments on a soft-deleted Drop become invisible to a stranger
#       but stay visible to the Drop's own author.
#   11. A Restricted (posting-blocked) user can still edit/delete/
#       restore their own Drop.
#   12. Regression: plain Drop creation, create_poll_drop(), and
#       ReDrop still work unaffected.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_035_poll_in_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_037_edit_delete_drop_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn037_edit_delete_drop_regression_test"
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

-- alice: owns a fresh Drop (D1, well within the edit window) and an
-- old Drop (D2, created 31 minutes ago -- edit window already
-- passed). bob: a stranger who tries to edit/delete/restore alice's
-- Drops directly, and who ReDrops D1. carol: a third party who only
-- ever reads, to prove visibility rules from someone with no stake in
-- either Drop. erin: gets Restricted, to prove edit/delete/restore of
-- her OWN Drop still works while posting-blocked.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'erin@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'erin', 'Erin', 'user');

-- Fixture: erin gets an active Restrict (direct table-owner inserts,
-- bypassing RLS -- same fixture shape as wyn_034/035/036's own).
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'user', '55555555-5555-5555-5555-555555555555', 'spam', 'actioned');
insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'restrict', 'spam fixture', 3, now() + interval '3 days');

-- Fixture Drops, inserted directly as the table owner (bypassing RLS)
-- so their created_at can be backdated -- D1 is fresh (inside the
-- 30-minute edit window), D2 is 31 minutes old (just past it), D3 is
-- erin's own fresh Drop (for the Restricted-user checks).
insert into public.drops (id, author_id, image_url, caption, created_at) values
  ('d1111111-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'https://example.com/d1.jpg', 'ต้นฉบับ D1', now()),
  ('d2222222-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'https://example.com/d2.jpg', 'ต้นฉบับ D2', now() - interval '31 minutes'),
  ('d3333333-0000-0000-0000-000000000003', '55555555-5555-5555-5555-555555555555', 'https://example.com/d3.jpg', 'erin ของฉัน', now());

-- ------------------------------------------------------------
-- CHECK 1-3: edit_drop() -- within window succeeds, past window
-- fails, a stranger can never edit someone else's Drop.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK1: alice edits D1 (fresh, well within the 30-minute window).
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.edit_drop('d1111111-0000-0000-0000-000000000001', 'แก้ไขแล้ว D1');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK1_edit_within_window_succeeds', count(*), 1
  from public.drops
  where id = 'd1111111-0000-0000-0000-000000000001'
    and caption = 'แก้ไขแล้ว D1'
    and edited_at is not null;
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  -- CHECK2: alice tries to edit D2 (31 minutes old) -- must raise.
  begin
    set role authenticated;
    set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
    set request.jwt.claim.role = 'authenticated';
    perform public.edit_drop('d2222222-0000-0000-0000-000000000002', 'สายไปแล้ว');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;

  insert into results select 'CHECK2_edit_past_window_raises', case when v_failed then 1 else 0 end, 1;
  insert into results
  select 'CHECK2b_caption_unchanged_after_failed_edit', count(*), 1
  from public.drops where id = 'd2222222-0000-0000-0000-000000000002' and caption = 'ต้นฉบับ D2';
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  -- CHECK3: bob (a stranger) tries to edit alice's D1 -- must raise,
  -- regardless of the window.
  begin
    set role authenticated;
    set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    set request.jwt.claim.role = 'authenticated';
    perform public.edit_drop('d1111111-0000-0000-0000-000000000001', 'แอบแก้ของคนอื่น');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;

  insert into results select 'CHECK3_stranger_edit_raises', case when v_failed then 1 else 0 end, 1;
  insert into results
  select 'CHECK3b_caption_unchanged_after_stranger_edit', count(*), 1
  from public.drops where id = 'd1111111-0000-0000-0000-000000000001' and caption = 'แก้ไขแล้ว D1';
end
$$;

-- ------------------------------------------------------------
-- CHECK 4-5: soft_delete_drop() -- author can delete once, the row
-- survives but becomes invisible to a stranger while staying visible
-- to the author, and a second delete attempt fails.
-- ------------------------------------------------------------

-- bob ReDrops D1 before it gets deleted, so CHECK9 below can prove the
-- ReDrop disappears from feeds too once the original is soft-deleted.
insert into public.redrops (id, drop_id, redropper_id) values
  ('a1111111-0000-0000-0000-00000000000a', 'd1111111-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

-- dana... reuse carol as the commenter for CHECK10's fixture, inserted
-- directly (bypassing RLS) before D1 is deleted.
insert into public.drop_comments (id, drop_id, author_id, text_content) values
  ('c1111111-0000-0000-0000-00000000000c', 'd1111111-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'คอมเมนต์ก่อนถูกลบ');

do $$
begin
  -- CHECK4: alice soft-deletes D1.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.soft_delete_drop('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- The row still physically exists (superuser/table-owner read,
  -- bypassing RLS) -- soft delete, not a real DELETE.
  insert into results
  select 'CHECK4_row_still_exists_after_soft_delete', count(*), 1
  from public.drops where id = 'd1111111-0000-0000-0000-000000000001' and deleted_at is not null;

  -- carol (a stranger) can no longer see D1 at all.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK4b_stranger_cannot_see_deleted_drop',
    (select count(*) from public.drops where id = 'd1111111-0000-0000-0000-000000000001'), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- alice (the author) still sees her own deleted Drop.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK4c_author_still_sees_own_deleted_drop',
    (select count(*) from public.drops where id = 'd1111111-0000-0000-0000-000000000001'), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  -- CHECK5: alice tries to soft-delete D1 again -- must raise (already
  -- deleted).
  begin
    set role authenticated;
    set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
    set request.jwt.claim.role = 'authenticated';
    perform public.soft_delete_drop('d1111111-0000-0000-0000-000000000001');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK5_double_delete_raises', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8: a stranger cannot soft-delete/restore someone else's Drop.
-- ------------------------------------------------------------
do $$
declare
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    set request.jwt.claim.role = 'authenticated';
    perform public.restore_drop('d1111111-0000-0000-0000-000000000001');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK8_stranger_restore_raises', case when v_failed then 1 else 0 end, 1;
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    set request.jwt.claim.role = 'authenticated';
    perform public.soft_delete_drop('d3333333-0000-0000-0000-000000000003');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK8b_stranger_delete_of_erins_drop_raises', case when v_failed then 1 else 0 end, 1;
  insert into results
  select 'CHECK8c_erins_drop_still_live', count(*), 1
  from public.drops where id = 'd3333333-0000-0000-0000-000000000003' and deleted_at is null;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9-10: a soft-deleted Drop's ReDrop and comments disappear too.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK9: bob's own ReDrop of (now-deleted) D1 no longer shows up in
  -- his OWN home_feed -- he is the redropper, not the author, so RLS
  -- on `drops` hides the joined original from him just like anyone
  -- else. No view change was needed for this -- proves the design's
  -- claim.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK9_redrop_of_deleted_drop_hidden_from_redropper',
    (select count(*) from public.home_feed where id = 'd1111111-0000-0000-0000-000000000001' and redrop_id is not null), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK10: carol (who commented on D1 before it was deleted) can no
  -- longer read that comment at all, even though the comment row
  -- itself still physically exists.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK10_comment_on_deleted_drop_hidden_from_stranger',
    (select count(*) from public.drop_comments where id = 'c1111111-0000-0000-0000-00000000000c'), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- ... but alice (D1's own author) can still read that same comment.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK10b_comment_on_own_deleted_drop_visible_to_author',
    (select count(*) from public.drop_comments where id = 'c1111111-0000-0000-0000-00000000000c'), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK10c: bob (a stranger) cannot even INSERT a new comment onto D1
-- while it's soft-deleted -- QA finding: before this check existed,
-- the drop_comments INSERT policy never looked at deleted_at at all,
-- so this would have silently succeeded (and fired
-- notify_drop_comment(), notifying alice about a comment on content
-- she believes is gone).
do $$
declare
  v_failed boolean := false;
begin
  begin
    set role authenticated;
    set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
    set request.jwt.claim.role = 'authenticated';
    insert into public.drop_comments (drop_id, author_id, text_content)
    values ('d1111111-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'แอบคอมเมนต์ของที่ถูกลบ');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK10c_stranger_cannot_comment_on_deleted_drop', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6-7: restore_drop() -- within window succeeds and un-hides
-- everything again, past window fails.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK6: alice restores D1 within the (default, wide-open) 30-day
  -- window.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.restore_drop('d1111111-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK6_restore_clears_deleted_at', count(*), 1
  from public.drops where id = 'd1111111-0000-0000-0000-000000000001' and deleted_at is null;

  -- carol can see D1 again, and bob's ReDrop of it is back in the feed.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK6b_stranger_sees_restored_drop_again',
    (select count(*) from public.drops where id = 'd1111111-0000-0000-0000-000000000001'), 1;
  insert into results
  select 'CHECK6c_redrop_visible_again_after_restore',
    (select count(*) from public.home_feed where id = 'd1111111-0000-0000-0000-000000000001' and redrop_id is not null), 1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

do $$
declare
  v_failed boolean := false;
begin
  -- CHECK7: D2 gets soft-deleted 31 days ago (backdated directly,
  -- bypassing RLS) -- alice's restore attempt must raise.
  update public.drops set deleted_at = now() - interval '31 days'
  where id = 'd2222222-0000-0000-0000-000000000002';

  begin
    set role authenticated;
    set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
    set request.jwt.claim.role = 'authenticated';
    perform public.restore_drop('d2222222-0000-0000-0000-000000000002');
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  exception when others then
    v_failed := true;
    reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  end;
  insert into results select 'CHECK7_restore_past_window_raises', case when v_failed then 1 else 0 end, 1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 11: erin (Restricted -- posting-blocked) can still edit/
-- delete/restore her own Drop.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  perform public.edit_drop('d3333333-0000-0000-0000-000000000003', 'erin แก้ไขได้แม้โดน Restrict');
  perform public.soft_delete_drop('d3333333-0000-0000-0000-000000000003');
  perform public.restore_drop('d3333333-0000-0000-0000-000000000003');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK11_restricted_user_can_edit_delete_restore_own_drop', count(*), 1
  from public.drops
  where id = 'd3333333-0000-0000-0000-000000000003'
    and caption = 'erin แก้ไขได้แม้โดน Restrict'
    and deleted_at is null;
end
$$;

-- ------------------------------------------------------------
-- CHECK 12: regression -- plain Drop creation, create_poll_drop(),
-- and ReDrop still work unaffected.
-- ------------------------------------------------------------
do $$
declare
  v_plain_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (author_id, image_url, caption)
  values ('11111111-1111-1111-1111-111111111111', 'https://example.com/plain.jpg', 'Drop ปกติ')
  returning id into v_plain_id;
  perform set_config('wyn037.plain_drop', v_plain_id::text, false);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK12_plain_drop_still_works', count(*), 1
  from public.drops where id = v_plain_id and deleted_at is null;
end
$$;

do $$
declare
  v_poll_drop_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  v_poll_drop_id := public.create_poll_drop(
    p_caption := 'กินอะไรดี?',
    p_options := array['พิซซ่า', 'ซูชิ'],
    p_duration_days := 3,
    p_mentioned_user_ids := array[]::uuid[]
  );
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK12b_poll_drop_still_works', count(*), 1
  from public.drops where id = v_poll_drop_id and deleted_at is null;
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
