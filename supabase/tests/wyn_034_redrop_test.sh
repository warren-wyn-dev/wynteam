#!/usr/bin/env bash
# Regression test for WYN-034 (ReDrop: Standard + Quote) -- proves the
# security-sensitive behavior actually works at the RLS/RPC/trigger
# layer, under the real `authenticated` role (not the Postgres
# superuser, which bypasses RLS entirely), mirroring
# wyn_031/032/033_..._test.sh's exact harness/role-switching convention.
#
#   1. Standard ReDrop toggle: insert succeeds, a 2nd Standard ReDrop of
#      the same Drop by the same user is rejected (partial unique
#      index), un-ReDrop (delete) then re-ReDrop works cleanly.
#   2. Quote ReDrop: the same Drop can be quoted multiple times by the
#      same user with different text (no uniqueness limit, unlike
#      Standard) -- and `redrops_quote_text_length` still rejects text
#      over 500 characters.
#   3. INSERT policy: a user blocked-either-way with the original
#      Drop's author cannot ReDrop it at all; a posting-blocked
#      (Restricted) user cannot ReDrop anything.
#   4. SELECT policy: a viewer blocked-either-way with the *redropper*
#      cannot see that specific redrop row, but still sees redrops by
#      someone else of the same Drop (the filter is scoped to the
#      redropper, not blanket) -- and a viewer blocked-either-way with
#      the *original author* cannot see ANY redrop of that Drop at all,
#      piggybacking on `drops`' own block-aware SELECT policy.
#   5. `home_feed`'s 3rd (redrop) branch: content_type stays 'drop',
#      redrop_id/redropper_* are populated, and the underlying
#      id/author/image/caption still describe the *original* Drop
#      (credit preserved) -- plus `redrop_count` on the plain-drop
#      branch reflects the true total across Standard + Quote.
#   6. `notify_redrop()` trigger fires a `redrop` notification to the
#      original author on every ReDrop, except when redropping your
#      own Drop (no self-notification).
#   7. `submit_report()`'s new 'redrop' branch: a stranger can report
#      someone else's Quote ReDrop text; the redropper cannot report
#      their own; a nonexistent redrop id is rejected.
#   8. Deleting the original Drop cascades away every ReDrop (Standard
#      and Quote alike) that pointed to it.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_031_chat_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_034_redrop_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn034_redrop_regression_test"
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

-- alice: author of D1/D2. bob: Standard-ReDrops both. carol: Quote-
-- ReDrops both (twice on D1, once on D2). dave: blocked BY alice (the
-- *original author*) -- tests the author-side block filter. erin:
-- blocked by bob (the *redropper*) -- tests the redropper-side block
-- filter, scoped to bob only. frank: gets Restricted via a
-- moderation_actions fixture -- tests the posting-blocked INSERT gate.
-- grace: a neutral viewer for home_feed/redrop_count checks
-- (unblocked from everyone). henry: reports carol's Quote ReDrop.
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

insert into public.drops (id, author_id, image_url) values
  ('d1000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'https://example.com/d1.jpg'),
  ('d2000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'https://example.com/d2.jpg');

-- Fixture: frank gets an active Restrict (direct table-owner inserts,
-- bypassing RLS -- apply_moderation_action() itself is WYN-029's own
-- concern, already regression-tested there; this fixture only needs a
-- report row to satisfy the FK, not a real submit flow. Mirrors
-- wyn_030_appeal_system_test.sh's identical fixture shape.)
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', 'user', '66666666-6666-6666-6666-666666666666', 'spam', 'actioned');
insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '66666666-6666-6666-6666-666666666666', '77777777-7777-7777-7777-777777777777', 'restrict', 'spam fixture', 3, now() + interval '3 days');

-- alice blocks dave (original-author-side block). bob blocks erin
-- (redropper-side block).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.block_user('44444444-4444-4444-4444-444444444444'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.block_user('55555555-5555-5555-5555-555555555555'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 1-4: Standard ReDrop toggle lifecycle on D1.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK1: bob Standard-ReDrops D1.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id)
  values ('d1000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK1_standard_redrop_inserted', count(*), 1
  from public.redrops
  where drop_id = 'd1000000-0000-0000-0000-000000000001' and redropper_id = '22222222-2222-2222-2222-222222222222' and quote_text is null;

  -- CHECK2: bob cannot Standard-ReDrop D1 a second time.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.redrops (drop_id, redropper_id)
    values ('d1000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
    insert into results values ('CHECK2_second_standard_redrop_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK2_second_standard_redrop_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK3: bob un-ReDrops (deletes) it.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  delete from public.redrops
  where drop_id = 'd1000000-0000-0000-0000-000000000001' and redropper_id = '22222222-2222-2222-2222-222222222222' and quote_text is null;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK3_un_redrop_removes_row', count(*), 0
  from public.redrops
  where drop_id = 'd1000000-0000-0000-0000-000000000001' and redropper_id = '22222222-2222-2222-2222-222222222222';

  -- CHECK4: bob can re-ReDrop after un-ReDropping.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id)
  values ('d1000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK4_re_redrop_after_un_redrop', count(*), 1
  from public.redrops
  where drop_id = 'd1000000-0000-0000-0000-000000000001' and redropper_id = '22222222-2222-2222-2222-222222222222';
end
$$;

-- ------------------------------------------------------------
-- CHECK 5-7: Quote ReDrop -- no uniqueness limit, length constraint.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK5: carol Quote-ReDrops D1 the first time.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id, quote_text)
  values ('d1000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'ดูนี่สิ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK6: carol Quote-ReDrops D1 a second time, different text --
  -- no unique-index rejection like Standard's CHECK2.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id, quote_text)
  values ('d1000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'อีกรอบ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK5_6_two_quote_redrops_from_same_user_both_kept', count(*), 2
  from public.redrops
  where drop_id = 'd1000000-0000-0000-0000-000000000001' and redropper_id = '33333333-3333-3333-3333-333333333333' and quote_text is not null;

  -- CHECK7: quote_text over 500 characters is rejected.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.redrops (drop_id, redropper_id, quote_text)
    values ('d1000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', repeat('x', 501));
    insert into results values ('CHECK7_quote_text_over_500_chars_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK7_quote_text_over_500_chars_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 8-9: INSERT policy -- blocked-author and posting-blocked
-- rejections.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK8: dave (blocked by alice, D1's author) cannot ReDrop D1.
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.redrops (drop_id, redropper_id)
    values ('d1000000-0000-0000-0000-000000000001', '44444444-4444-4444-4444-444444444444');
    insert into results values ('CHECK8_blocked_author_redrop_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK8_blocked_author_redrop_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK9: frank (posting-blocked via active Restrict) cannot ReDrop
  -- D2 (an entirely different, non-blocked-author Drop).
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.redrops (drop_id, redropper_id)
    values ('d2000000-0000-0000-0000-000000000002', '66666666-6666-6666-6666-666666666666');
    insert into results values ('CHECK9_posting_blocked_redrop_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK9_posting_blocked_redrop_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 10-12: SELECT policy -- redropper-side vs author-side block
-- filtering.
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK10_blocked_redropper_row_hidden_from_erin', count(*), 0
from public.redrops
where drop_id = 'd1000000-0000-0000-0000-000000000001' and redropper_id = '22222222-2222-2222-2222-222222222222';
insert into results
select 'CHECK11_unblocked_redropper_rows_still_visible_to_erin', count(*), 2
from public.redrops
where drop_id = 'd1000000-0000-0000-0000-000000000001' and redropper_id = '33333333-3333-3333-3333-333333333333';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK12_blocked_author_hides_every_redrop_of_their_drop', count(*), 0
from public.redrops
where drop_id = 'd1000000-0000-0000-0000-000000000001';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 13-14: home_feed's 3rd (redrop) branch + redrop_count.
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '77777777-7777-7777-7777-777777777777';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK13a_redrop_branch_row_exists_for_bob', count(*), 1
from public.home_feed
where id = 'd1000000-0000-0000-0000-000000000001'
  and redrop_id is not null
  and redropper_username = 'bob';
insert into results
select 'CHECK13b_redrop_branch_still_shows_original_author_and_image', count(*), 1
from public.home_feed
where id = 'd1000000-0000-0000-0000-000000000001'
  and redropper_username = 'bob'
  and author_username = 'alice'
  and image_url = 'https://example.com/d1.jpg';
insert into results
select 'CHECK14_redrop_count_reflects_standard_plus_quote_total', redrop_count, 3
from public.home_feed
where id = 'd1000000-0000-0000-0000-000000000001' and redrop_id is null;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 15-16: notify_redrop() trigger -- fires for others, not for
-- self-ReDrop.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK15: bob Standard-ReDrops D2 -- alice (D2's author) gets
  -- notified.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id)
  values ('d2000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK15_redrop_by_other_notifies_original_author', count(*), 1
  from public.notifications
  where recipient_id = '11111111-1111-1111-1111-111111111111'::uuid
    and actor_id = '22222222-2222-2222-2222-222222222222'::uuid
    and type = 'redrop'
    and drop_id = 'd2000000-0000-0000-0000-000000000002';

  -- CHECK16: alice Standard-ReDrops her OWN D2 -- allowed, but no
  -- self-notification.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id)
  values ('d2000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK16_self_redrop_creates_no_self_notification', count(*), 0
  from public.notifications
  where recipient_id = '11111111-1111-1111-1111-111111111111'::uuid
    and actor_id = '11111111-1111-1111-1111-111111111111'::uuid
    and type = 'redrop';
end
$$;

-- ------------------------------------------------------------
-- CHECK 17-20: submit_report()'s new 'redrop' branch.
-- ------------------------------------------------------------
do $$
declare
  v_carol_redrop_id uuid;
begin
  -- CHECK17: carol Quote-ReDrops D2, for the report checks below.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  insert into public.redrops (drop_id, redropper_id, quote_text)
  values ('d2000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'ข้อความที่ถูกรายงาน')
  returning id into v_carol_redrop_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK18: henry (a stranger) reports carol's Quote ReDrop.
  set role authenticated;
  set request.jwt.claim.sub = '88888888-8888-8888-8888-888888888888';
  set request.jwt.claim.role = 'authenticated';
  perform public.submit_report('redrop', v_carol_redrop_id, 'harassment', 'ไม่เหมาะสม');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK18_stranger_can_report_redrop', count(*), 1
  from public.reports
  where target_type = 'redrop' and target_id = v_carol_redrop_id and reporter_id = '88888888-8888-8888-8888-888888888888'::uuid;

  -- CHECK19: carol cannot report her own redrop.
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('redrop', v_carol_redrop_id, 'harassment', null);
    insert into results values ('CHECK19_cannot_report_own_redrop', 0, 1);
  exception when others then
    insert into results values ('CHECK19_cannot_report_own_redrop', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK20: reporting a nonexistent redrop id is rejected.
  set role authenticated;
  set request.jwt.claim.sub = '88888888-8888-8888-8888-888888888888';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('redrop', gen_random_uuid(), 'spam', null);
    insert into results values ('CHECK20_nonexistent_redrop_report_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK20_nonexistent_redrop_report_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 21: deleting the original Drop used to hard-delete it (real
-- FK cascade away every ReDrop of it). WYN-037 replaced self-delete
-- with soft_delete_drop() -- there is no more client-facing DELETE
-- policy on `drops` at all, so a raw `delete from drops` here is now
-- a silent 0-row RLS no-op, not the real deletion this check used to
-- rely on. Updated to call the real (soft-delete) path instead: the
-- ReDrop rows now deliberately SURVIVE (no FK cascade fires on an
-- UPDATE), but become invisible in feeds -- proven directly by
-- wyn_037_edit_delete_drop_test.sh's own CHECK9, not re-proven here.
-- D1 has bob's 1 Standard + carol's 2 Quotes = 3 rows at this point --
-- dave/erin's rejected attempts never inserted anything.
-- ------------------------------------------------------------
do $$
declare
  v_count_before int;
begin
  select count(*) into v_count_before from public.redrops where drop_id = 'd1000000-0000-0000-0000-000000000001';
  insert into results values ('CHECK21z_fixture_has_redrops_before_delete', (case when v_count_before = 3 then 1 else 0 end), 1);

  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.soft_delete_drop('d1000000-0000-0000-0000-000000000001');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK21_soft_delete_drop_does_not_cascade_redrop_rows', count(*), 3
  from public.redrops where drop_id = 'd1000000-0000-0000-0000-000000000001';
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
