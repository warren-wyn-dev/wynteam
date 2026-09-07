#!/usr/bin/env bash
# Regression test for the WYN-128 fast-follow (report a Club Group Chat
# message) -- proves the moderation gap QA found is actually closed at
# the real RLS/RPC layer under the `authenticated` role (not the
# Postgres superuser, which bypasses RLS entirely), mirroring
# wyn_029_moderation_queue_test.sh's own submit_report()/
# apply_moderation_action() exercising pattern. See
# .wyn/tasks/bugs/WYN-128-group-chat-missing-report-action.md.
#
#   1. An approved Club member can submit_report() a 'club_channel_message'
#      authored by someone else in the same Club.
#   2. The message's own author cannot report their own message.
#   3. A non-member of the message's Club cannot report it, even though
#      submit_report() is SECURITY DEFINER and would otherwise bypass
#      club_channel_messages' own membership-gated SELECT policy.
#   4. A Banned member of the message's Club (club_role() null, same as
#      a non-member) cannot report it either.
#   5. apply_moderation_action('remove_content', ...) against that
#      report resolves target_user_id to the message's real author, and
#      actually hard-deletes the message row (mirrors club_post_comment's
#      identical Remove Content behavior -- no restore path, unlike a
#      Drop).
#   6. The report's own status flips to 'actioned', and the author gets
#      a moderation_content_removed notification with actor_id left
#      null (WYN-029's reviewer-identity-leak fix, unchanged behavior
#      extended to this new target type).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_029_moderation_queue_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_128_group_chat_report_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn128_group_chat_report_regression_test"
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

-- alice: club owner. bob: approved member, the reporter. carol:
-- approved member, the message's author (the target). dave: not a
-- member of this club at all. erin: an approved member who is later
-- Banned. frank: WYN platform moderator (platform_role='admin'),
-- entirely separate from any club_role -- the one who actually reviews
-- the report.
insert into auth.users (id, email) values
  ('b1111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('b2222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('b3333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('b4444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('b5555555-5555-5555-5555-555555555555', 'erin@test.com'),
  ('b6666666-6666-6666-6666-666666666666', 'frank@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('b1111111-1111-1111-1111-111111111111', 'alice128', 'Alice', 'user'),
  ('b2222222-2222-2222-2222-222222222222', 'bob128', 'Bob', 'user'),
  ('b3333333-3333-3333-3333-333333333333', 'carol128', 'Carol', 'user'),
  ('b4444444-4444-4444-4444-444444444444', 'dave128', 'Dave', 'user'),
  ('b5555555-5555-5555-5555-555555555555', 'erin128', 'Erin', 'user'),
  ('b6666666-6666-6666-6666-666666666666', 'frank128', 'Frank', 'admin');

insert into public.clubs (id, name, privacy, owner_id) values
  ('d1111111-0000-0000-0000-000000000001', 'Report Club', 'public', 'b1111111-1111-1111-1111-111111111111');

-- alice's own (owner, approved) row is inserted automatically by the
-- clubs_add_owner_membership trigger. The Club's default "ทั่วไป"
-- channel is inserted automatically by clubs_add_default_channel.
insert into public.club_members (club_id, user_id, role, status) values
  ('d1111111-0000-0000-0000-000000000001', 'b2222222-2222-2222-2222-222222222222', 'member', 'approved'),
  ('d1111111-0000-0000-0000-000000000001', 'b3333333-3333-3333-3333-333333333333', 'member', 'approved'),
  ('d1111111-0000-0000-0000-000000000001', 'b5555555-5555-5555-5555-555555555555', 'member', 'banned');
-- dave is deliberately not a club_members row at all. frank has no
-- club_members row either -- he reviews as a WYN platform moderator,
-- not as a Club member.

-- carol's message in the default channel, seeded as the table owner
-- (bypassing RLS -- the insert policy itself is WYN-128's own concern,
-- already covered by the feature's own manual QA pass).
insert into public.club_channel_messages (id, channel_id, author_id, content)
select 'e0000000-0000-0000-0000-000000000001', ch.id, 'b3333333-3333-3333-3333-333333333333', 'ข้อความที่ถูกรายงาน'
from public.club_channels ch
where ch.club_id = 'd1111111-0000-0000-0000-000000000001';

-- ------------------------------------------------------------
-- CHECK1-4: submit_report() membership/authorship gates for
-- 'club_channel_message'.
-- ------------------------------------------------------------
do $$
begin
  -- CHECK1: bob (approved member, not the author) can report carol's message.
  set role authenticated;
  set request.jwt.claim.sub = 'b2222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('club_channel_message', 'e0000000-0000-0000-0000-000000000001', 'harassment', 'ไม่เหมาะสม');
    insert into results values ('CHECK1_approved_member_can_report_others_message', 1, 1);
  exception when others then
    insert into results values ('CHECK1_approved_member_can_report_others_message', 0, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK2: carol (the message's own author) cannot report her own message.
  set role authenticated;
  set request.jwt.claim.sub = 'b3333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('club_channel_message', 'e0000000-0000-0000-0000-000000000001', 'spam', 'self report');
    insert into results values ('CHECK2_author_cannot_report_own_message', 0, 1);
  exception when others then
    insert into results values ('CHECK2_author_cannot_report_own_message', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK3: dave (not a member of this Club at all) cannot report it.
  set role authenticated;
  set request.jwt.claim.sub = 'b4444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('club_channel_message', 'e0000000-0000-0000-0000-000000000001', 'spam', 'outsider report');
    insert into results values ('CHECK3_non_member_cannot_report_message', 0, 1);
  exception when others then
    insert into results values ('CHECK3_non_member_cannot_report_message', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK4: erin (Banned member -- club_role() is null, same as a
  -- non-member) cannot report it either.
  set role authenticated;
  set request.jwt.claim.sub = 'b5555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_report('club_channel_message', 'e0000000-0000-0000-0000-000000000001', 'spam', 'banned report');
    insert into results values ('CHECK4_banned_member_cannot_report_message', 0, 1);
  exception when others then
    insert into results values ('CHECK4_banned_member_cannot_report_message', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK5-9: apply_moderation_action('remove_content', ...) against
-- bob's report (CHECK1) -- resolves the real author, deletes the
-- message, flips report status, notifies without leaking reviewer
-- identity.
-- ------------------------------------------------------------
do $$
declare
  v_report_id uuid;
begin
  select id into v_report_id from public.reports
    where target_type = 'club_channel_message' and target_id = 'e0000000-0000-0000-0000-000000000001'
    order by created_at asc limit 1;

  set role authenticated;
  set request.jwt.claim.sub = 'b6666666-6666-6666-6666-666666666666'; -- frank, platform admin
  set request.jwt.claim.role = 'authenticated';
  perform public.apply_moderation_action(v_report_id, 'remove_content', 'ลบข้อความไม่เหมาะสม', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results select 'CHECK5_target_user_resolved_to_real_author', count(*), 1
  from public.moderation_actions
  where report_id = v_report_id and target_user_id = 'b3333333-3333-3333-3333-333333333333';
end
$$;

-- CHECK6: the message is actually gone -- a plain hard DELETE, same as
-- club_post_comment's own Remove Content behavior (no restore path).
insert into results select 'CHECK6_message_hard_deleted', count(*), 0
from public.club_channel_messages where id = 'e0000000-0000-0000-0000-000000000001';

-- CHECK7: the report itself flipped to 'actioned'.
insert into results select 'CHECK7_report_status_actioned', count(*), 1
from public.reports
where target_type = 'club_channel_message' and target_id = 'e0000000-0000-0000-0000-000000000001'
  and status = 'actioned';

-- CHECK8: carol (the real author) got a moderation_content_removed
-- notification with the reviewer's reason.
insert into results
select 'CHECK8_author_notified_content_removed', count(*), 1
from public.notifications
where recipient_id = 'b3333333-3333-3333-3333-333333333333'
  and type = 'moderation_content_removed'
  and reason = 'ลบข้อความไม่เหมาะสม';

-- CHECK9: WYN-029's reviewer-identity-leak fix holds for this new
-- target type too -- actor_id is null on that notification.
insert into results
select 'CHECK9_notification_actor_id_is_null', count(*), 1
from public.notifications
where recipient_id = 'b3333333-3333-3333-3333-333333333333'
  and type = 'moderation_content_removed'
  and actor_id is null;

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
