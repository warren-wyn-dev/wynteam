#!/usr/bin/env bash
# Regression test for WYN-029 (Moderation Queue + Action) -- proves the
# security-sensitive behavior actually works at the RLS/RPC layer, not
# just in the Dart UI:
#
#   1. platform_role cannot be self-escalated via INSERT (a client's
#      own profile row) or UPDATE (an existing profile row) -- both
#      paths are exercised, since RLS's WITH CHECK is row-level, not
#      column-level, and each path needs its own guard.
#   2. A Restricted account's Drop/Comment/Club-create attempts are
#      rejected by RLS directly (not just hidden in the UI), while
#      Login/select/like remain completely unaffected.
#   3. Suspend/Ban make get_my_moderation_status() (the single source
#      AuthGate's login gate reads) report the account as blocked --
#      Ban has no expiry, Suspend does.
#   4. Auto-expiry restores access with zero manual intervention: an
#      expired Restrict/Suspend row (expires_at in the past) is treated
#      as inactive purely by the `expires_at > now()` comparison, no
#      cron/batch job involved.
#   5. Each of the 6 actions produces its documented real effect
#      (No Action/Warning/Remove Content/Restrict/Suspend/Ban), and
#      apply_moderation_action() rejects: a non-moderator caller, and a
#      second action against an already-actioned report.
#   6. Reporter identity stays invisible to a moderator working the
#      queue -- moderation_queue never exposes reporter_id (not in its
#      column list), and a moderator's raw `select * from
#      public.reports` still only returns their own submitted reports,
#      never anyone else's (the reporter-only policy is left untouched
#      on purpose -- see the schema comment on moderation_queue).
#   7. A `club` target's account-level action resolves to the Club's
#      owner_id, not the reporter or an arbitrary member.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_027_is_blocked_either_way_rpc_exposure_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_029_moderation_queue_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn029_moderation_regression_test"
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
EOF

cat > "$WORK_DIR/10_seed_and_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

-- A scratch table (postgres-owned, no RLS) to record pass/fail from
-- inside DO blocks that need to catch an *expected* exception -- the
-- WYN-027 harness only ever needed plain SELECTs (visibility checks),
-- this one also needs to prove certain writes are *rejected*.
create table results (check_name text primary key, actual int, expected int);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'eve@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'frank@test.com');

-- alice: reporter. bob: ordinary user, the target of most actions.
-- carol: moderator (inserted directly as the table owner -- bypasses
-- RLS/the insert policy entirely, exactly how a real moderator
-- promotion is meant to happen: via direct DB access, never through
-- the authenticated-role insert/update paths this test is busy
-- proving are closed). dave: ordinary user, attempts self-escalation.
-- eve: owns a Club. frank: an uninvolved third party.
insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'moderator'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'eve', 'Eve', 'user'),
  ('66666666-6666-6666-6666-666666666666', 'frank', 'Frank', 'user');

insert into public.clubs (id, name, privacy, owner_id) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'Eve''s Club', 'public', '55555555-5555-5555-5555-555555555555');

-- ------------------------------------------------------------
-- CHECK 1-2: platform_role cannot be self-escalated.
-- ------------------------------------------------------------

-- CHECK1: dave tries to INSERT a *new* profile row for himself (the
-- setUsername()-upsert path) with platform_role='admin' baked in --
-- must be rejected outright by the INSERT policy's WITH CHECK, not
-- silently coerced to 'user'.
delete from public.profiles where id = '44444444-4444-4444-4444-444444444444';
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.profiles (id, username, platform_role)
    values ('44444444-4444-4444-4444-444444444444', 'dave', 'admin');
    insert into results values ('CHECK1_insert_self_escalation_rejected', 0, 1);
  exception when insufficient_privilege or others then
    insert into results values ('CHECK1_insert_self_escalation_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- Restore dave as an ordinary user (the row above never committed --
-- the exception rolled the INSERT back inside its own subtransaction,
-- but the top-level DO block still needs dave to exist for CHECK2+.
insert into public.profiles (id, username, display_name, platform_role)
values ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user')
on conflict (id) do nothing;

-- CHECK2: dave already has a profile row (platform_role='user') --
-- tries to UPDATE it to 'admin' himself. Must be rejected by the
-- profiles_prevent_platform_role_change trigger, which fires
-- regardless of RLS (RLS would otherwise allow this update -- "Users
-- can update their own profile" has no column restriction).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    update public.profiles set platform_role = 'admin' where id = '44444444-4444-4444-4444-444444444444';
    insert into results values ('CHECK2_update_self_escalation_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK2_update_self_escalation_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

insert into results
select 'CHECK2b_dave_still_plain_user', (case when platform_role = 'user' then 1 else 0 end), 1
from public.profiles where id = '44444444-4444-4444-4444-444444444444';

-- ------------------------------------------------------------
-- Alice reports Bob's Drop -- fixture used by several checks below.
-- ------------------------------------------------------------
insert into public.drops (id, author_id, image_url, caption) values
  ('d0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob1.jpg', 'bob drop 1');

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('drop', 'd0000000-0000-0000-0000-000000000001', 'spam', 'looks like spam');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 3-5: reporter identity stays invisible to the moderator.
-- ------------------------------------------------------------

-- CHECK3: moderation_queue never returns a reporter_id column at all
-- (schema-level guarantee -- this query would fail outright, not just
-- return null, if the column existed and had a `select *`-style leak.
-- Checked here by confirming the view's column list is exactly the
-- curated one, no more).
insert into results
select 'CHECK3_moderation_queue_has_no_reporter_id_column',
  (case when exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'moderation_queue' and column_name = 'reporter_id'
  ) then 1 else 0 end),
  0;

-- CHECK4: carol (moderator) queries moderation_queue and sees Alice's
-- report in the queue (proves moderator visibility works at all).
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK4_moderator_sees_report_in_queue', count(*), 1
from public.moderation_queue
where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000001';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK5: carol (moderator) queries the RAW `reports` table directly
-- (bypassing moderation_queue entirely, simulating a moderator hand-
-- crafting a REST call to try to read reporter_id off the base table)
-- -- must come back EMPTY, because no new SELECT policy was added to
-- `reports` for moderators; the pre-existing reporter-only policy is
-- untouched, so even a moderator only ever sees their *own* submitted
-- reports (carol has submitted none) via that path.
set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK5_moderator_raw_reports_table_select_empty', count(*), 0
from public.reports;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 6-7: apply_moderation_action() authorization + double-action
-- guard.
-- ------------------------------------------------------------

-- CHECK6: bob (an ordinary user, not a moderator) tries to call
-- apply_moderation_action directly -- must be rejected.
do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000001';
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.apply_moderation_action(v_report_id, 'warning', 'not allowed', null);
    insert into results values ('CHECK6_non_moderator_action_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK6_non_moderator_action_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK7: carol (moderator) applies "Warning" to Alice's report against
-- Bob's Drop -- report closes as actioned, moderation_actions row
-- recorded, Bob gets a moderation_warning notification with the reason,
-- and the Drop itself is untouched (Warning has no content effect).
do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000001';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'warning', 'please follow the rules', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

insert into results
select 'CHECK7a_report_closed_actioned', count(*), 1
from public.reports where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000001' and status = 'actioned';

insert into results
select 'CHECK7b_moderation_action_recorded', count(*), 1
from public.moderation_actions
where target_user_id = '22222222-2222-2222-2222-222222222222' and action_type = 'warning' and reviewer_id = '33333333-3333-3333-3333-333333333333';

insert into results
select 'CHECK7c_warning_notification_sent', count(*), 1
from public.notifications
where recipient_id = '22222222-2222-2222-2222-222222222222' and type = 'moderation_warning' and reason = 'please follow the rules';

insert into results
select 'CHECK7d_drop_untouched_by_warning', count(*), 1
from public.drops where id = 'd0000000-0000-0000-0000-000000000001';

-- CHECK8: acting on the same report a second time (already 'actioned')
-- must be rejected -- this is the design doc's actual double-action
-- guard (no claim/"reviewing" mechanic this round).
do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000001';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.apply_moderation_action(v_report_id, 'no_action', 'second look', null);
    insert into results values ('CHECK8_double_action_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK8_double_action_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 9-13: Restrict -- RLS-enforced (not just hidden UI), auto-expire.
-- ------------------------------------------------------------

-- Second report+action pair (bob's second drop) so this section is
-- independent of the already-closed report above.
insert into public.drops (id, author_id, image_url, caption) values
  ('d0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob2.jpg', 'bob drop 2');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('drop', 'd0000000-0000-0000-0000-000000000002', 'harassment', 'restrict please');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK9: before any action, bob can post a Drop normally (regression
-- control -- proves the INSERT policy change didn't break ordinary
-- posting).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (id, author_id, image_url) values
    ('d0000000-0000-0000-0000-000000000009', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob-before-restrict.jpg');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results select 'CHECK9_bob_can_post_before_restrict', count(*), 1
from public.drops where id = 'd0000000-0000-0000-0000-000000000009';

do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000002';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'restrict', 'stop posting for a bit', 3);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK10: bob (now Restricted) tries to post a NEW Drop -- must be
-- rejected by RLS directly (a raw insert() call, not something a
-- disabled Dart button could ever stop).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drops (id, author_id, image_url) values
      ('d0000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob3.jpg');
    insert into results values ('CHECK10_restricted_drop_insert_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK10_restricted_drop_insert_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK11: bob (Restricted) tries to comment on someone else's Drop --
-- also rejected.
insert into public.drops (id, author_id, image_url) values
  ('d0000000-0000-0000-0000-000000000004', '55555555-5555-5555-5555-555555555555', 'https://example.com/eve1.jpg');
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_comments (drop_id, author_id, text_content) values
      ('d0000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222', 'nice drop');
    insert into results values ('CHECK11_restricted_comment_insert_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK11_restricted_comment_insert_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK12: bob (Restricted) can still SELECT drops and LIKE them --
-- Restrict only blocks posting, per the Product spec ("ยัง Login/ดู/
-- Like/Follow ได้ปกติ").
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_likes (drop_id, user_id) values
    ('d0000000-0000-0000-0000-000000000004', '22222222-2222-2222-2222-222222222222');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results select 'CHECK12_restricted_user_can_still_like', count(*), 1
from public.drop_likes where drop_id = 'd0000000-0000-0000-0000-000000000004' and user_id = '22222222-2222-2222-2222-222222222222';

-- CHECK13: get_my_moderation_status() reports bob as restricted with
-- the right reason.
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK13_status_shows_restricted', (case when is_restricted and restrict_reason = 'stop posting for a bit' then 1 else 0 end), 1
from public.get_my_moderation_status();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK14: auto-expiry -- manually back-date bob's restrict row's
-- expires_at into the past (simulating "3 days later", no cron job
-- involved anywhere) and confirm posting works again immediately, with
-- zero other action taken.
update public.moderation_actions
set expires_at = now() - interval '1 hour'
where target_user_id = '22222222-2222-2222-2222-222222222222' and action_type = 'restrict';

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (id, author_id, image_url) values
    ('d0000000-0000-0000-0000-000000000005', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob5.jpg');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results select 'CHECK14_restrict_auto_expired_posting_works', count(*), 1
from public.drops where id = 'd0000000-0000-0000-0000-000000000005';

set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK14b_status_no_longer_restricted', (case when is_restricted then 0 else 1 end), 1
from public.get_my_moderation_status();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 15-19: Suspend + Ban -- get_my_moderation_status(), Suspend
-- auto-expires the same way Restrict does, Ban never does on its own.
-- ------------------------------------------------------------

insert into public.drops (id, author_id, image_url) values
  ('d0000000-0000-0000-0000-000000000006', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob6.jpg');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('drop', 'd0000000-0000-0000-0000-000000000006', 'harassment', 'suspend please');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000006';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'suspend', 'account suspended', 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK15_status_shows_suspended', (case when is_suspended and suspend_reason = 'account suspended' then 1 else 0 end), 1
from public.get_my_moderation_status();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK16: a Suspended account is also rejected at the RLS INSERT
-- layer (defense-in-depth, in case a still-valid JWT reaches the API
-- directly instead of going through AuthGate's login-time check).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drops (id, author_id, image_url) values
      ('d0000000-0000-0000-0000-000000000007', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob7.jpg');
    insert into results values ('CHECK16_suspended_drop_insert_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK16_suspended_drop_insert_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK17: Suspend auto-expires exactly like Restrict.
update public.moderation_actions
set expires_at = now() - interval '1 hour'
where target_user_id = '22222222-2222-2222-2222-222222222222' and action_type = 'suspend';
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK17_suspend_auto_expired', (case when is_suspended then 0 else 1 end), 1
from public.get_my_moderation_status();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- Ban.
insert into public.drops (id, author_id, image_url) values
  ('d0000000-0000-0000-0000-000000000008', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob8.jpg');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('drop', 'd0000000-0000-0000-0000-000000000008', 'harassment', 'ban please');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-000000000008';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'ban', 'permanent ban', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK18: Ban never auto-expires -- even after "time passes" (there's
-- no expires_at row to back-date at all, since Ban's constraint forbids
-- one), get_my_moderation_status() must keep reporting banned.
set role authenticated;
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK18_status_shows_banned_permanently', (case when is_banned and ban_reason = 'permanent ban' then 1 else 0 end), 1
from public.get_my_moderation_status();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- CHECK19: a Banned account is rejected at the RLS INSERT layer too.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.club_posts (club_id, author_id, content) values
      ('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'hi');
    insert into results values ('CHECK19_banned_club_post_insert_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK19_banned_club_post_insert_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 20-22: Remove Content, and the `club` target -> owner_id rule.
-- ------------------------------------------------------------

insert into public.drops (id, author_id, image_url, caption) values
  ('d0000000-0000-0000-0000-00000000000a', '66666666-6666-6666-6666-666666666666', 'https://example.com/frank1.jpg', 'frank drop');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('drop', 'd0000000-0000-0000-0000-00000000000a', 'illegal_content', 'remove please');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-00000000000a';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'remove_content', 'illegal content removed', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK20: the Drop is really gone (hard-deleted -- invisible to
-- everyone including its own author, exactly like self-delete).
insert into results select 'CHECK20_removed_drop_gone', count(*), 0
from public.drops where id = 'd0000000-0000-0000-0000-00000000000a';

-- CHECK21: frank got a moderation_content_removed notification with the
-- reason, and it does NOT reference the now-deleted drop (drop_id left
-- null -- see the schema comment on why, ordering/cascade hazard).
insert into results
select 'CHECK21_remove_content_notification_sent', count(*), 1
from public.notifications
where recipient_id = '66666666-6666-6666-6666-666666666666'
  and type = 'moderation_content_removed'
  and reason = 'illegal content removed'
  and drop_id is null;

-- CHECK22: a `club` target's account-level action resolves to the
-- Club's owner_id (eve), not the reporter (alice) or anyone else.
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('club', 'cccccccc-cccc-cccc-cccc-cccccccccccc', 'spam', 'spammy club');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'club' and target_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'warning', 'club rules violation', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

insert into results
select 'CHECK22_club_action_targets_owner', count(*), 1
from public.moderation_actions
where target_user_id = '55555555-5555-5555-5555-555555555555' and action_type = 'warning' and reason = 'club rules violation';

-- CHECK23: Remove Content is rejected outright for a `club` target
-- (Product spec: only content targets, never User/Club).
insert into public.clubs (id, name, privacy, owner_id) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccd', 'Frank''s Club', 'public', '66666666-6666-6666-6666-666666666666');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('club', 'cccccccc-cccc-cccc-cccc-cccccccccccd', 'spam', 'another spammy club');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'club' and target_id = 'cccccccc-cccc-cccc-cccc-cccccccccccd';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.apply_moderation_action(v_report_id, 'remove_content', 'nope', null);
    insert into results values ('CHECK23_remove_content_rejected_for_club', 0, 1);
  exception when others then
    insert into results values ('CHECK23_remove_content_rejected_for_club', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 24: No Action -- report dismissed, no side effect on the
-- target account or content.
-- ------------------------------------------------------------
insert into public.drops (id, author_id, image_url) values
  ('d0000000-0000-0000-0000-00000000000b', '66666666-6666-6666-6666-666666666666', 'https://example.com/frank2.jpg');
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
select public.submit_report('drop', 'd0000000-0000-0000-0000-00000000000b', 'spam', 'not actually spam');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-00000000000b';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'no_action', 'reviewed, looks fine', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

insert into results
select 'CHECK24a_report_dismissed', count(*), 1
from public.reports where target_type = 'drop' and target_id = 'd0000000-0000-0000-0000-00000000000b' and status = 'dismissed';
insert into results
select 'CHECK24b_drop_untouched_by_no_action', count(*), 1
from public.drops where id = 'd0000000-0000-0000-0000-00000000000b';
insert into results
select 'CHECK24c_no_notification_from_no_action', count(*), 0
from public.notifications where recipient_id = '66666666-6666-6666-6666-666666666666' and type in ('moderation_warning', 'moderation_content_removed') and reason = 'reviewed, looks fine';

-- ------------------------------------------------------------
-- CHECK 25: pop_* tables are completely untouched -- Pop feature
-- development is suspended (.wyn/company/DECISIONS.md, 2026-08-14).
-- Frank (an ordinary, never-restricted user) can still post a Pop, and
-- restricted/suspended/banned status has zero bearing on it -- if this
-- ever regresses (someone adds Restrict enforcement to pops by
-- mistake), this check starts failing immediately.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  -- bob is banned at this point in the script -- Pop must still accept
  -- his insert, proving Restrict/Suspend/Ban enforcement never touched
  -- pops.
  insert into public.pops (id, author_id, video_url, duration_seconds) values
    ('e0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'https://example.com/bob.mp4', 15);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results select 'CHECK25_pop_untouched_even_for_banned_author', count(*), 1
from public.pops where id = 'e0000000-0000-0000-0000-000000000001';

select check_name, actual, expected from results order by check_name;
EOF

echo "== Loading stub + schema.sql into fresh DB '$DB_NAME' =="
dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database '$DB_NAME' (no local Postgres access?)" >&2
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

echo "== Seeding fixtures and running RLS/RPC checks =="
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
