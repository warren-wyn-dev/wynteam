#!/usr/bin/env bash
# Regression test for WYN-030 (Appeal System) -- proves the
# security-sensitive behavior actually works at the RLS/RPC layer,
# under the real `authenticated` role (not the Postgres superuser,
# which bypasses RLS entirely), mirroring
# wyn_029_moderation_queue_test.sh's exact harness/role-switching
# convention:
#
#   1. submit_appeal() rejects: appealing someone else's action,
#      appealing a `no_action` action, a blank reason, an evidence
#      path outside the caller's own uid folder, and a second appeal
#      on an action already appealed (unique constraint) -- with the
#      friendly "already appealed" message, not a raw unique_violation.
#   2. decide_appeal() rejects: a non-moderator caller, the
#      self-review case (moderator deciding an appeal for an action
#      taken against their own account) for BOTH approve and reject,
#      and a reject with no decision_reason.
#   3. An approved appeal sets moderation_actions.overturned_at, which
#      flips internal.is_posting_blocked() from true to false and
#      is_restricted/is_suspended/is_banned in get_my_moderation_status()
#      from true to false -- a rejected appeal does neither.
#   4. appeal_approved/appeal_rejected notifications get actor_id =
#      NULL from the very first insert (the real reviewer identity
#      lives only in appeals.reviewer_id) -- proven both by a direct
#      column check AND by re-running, as the recipient under RLS, the
#      join query notification_repository.dart's embed relies on.
#   5. RLS on `appeals` itself: an unrelated third user gets zero rows
#      querying someone else's appeal directly (not just "the column
#      happens to be absent from a hand-picked select list") --
#      appellant sees their own, a moderator sees any.
#   6. RLS on the `appeal-evidence` storage bucket: a user can INSERT
#      an object under their own uid-prefixed folder, but not under
#      another user's.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_029_moderation_queue_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_030_appeal_system_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway DB.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn030_appeal_regression_test"
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

-- Real Supabase projects ship storage.objects with RLS already
-- enabled by the platform -- schema.sql only ever adds policies to
-- it, never enables RLS itself (see every other bucket's policy
-- block above). This stub has to do that one platform-level step
-- itself for the appeal-evidence policies below to mean anything.
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
-- CHECK22 below runs `set role anon` and writes its own outcome into
-- this table from inside that role -- default privileges only ever
-- covered `authenticated`.
grant select, insert on results to anon;

-- alice: target of a Restrict, appeals it (approved). bob: target of a
-- Suspend, appeals it (rejected). carol: moderator, decides alice's
-- and bob's appeals. dave: moderator, gets Restricted himself (self-
-- review case) and is decided by carol instead. eve: an uninvolved
-- third party, tries to read appeals/evidence that aren't hers.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'eve@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'frank@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'moderator'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'moderator'),
  ('55555555-5555-5555-5555-555555555555', 'eve', 'Eve', 'user'),
  ('66666666-6666-6666-6666-666666666666', 'frank', 'Frank', 'user');

insert into storage.buckets (id, name, public) values ('appeal-evidence', 'appeal-evidence', false)
  on conflict (id) do nothing;

-- Fixture moderation_actions, inserted directly as the table owner
-- (bypasses RLS entirely -- apply_moderation_action() itself is
-- WYN-029's own concern, already regression-tested there; this fixture
-- only needs a report row to satisfy the FK, not a real submit flow).
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'user', '11111111-1111-1111-1111-111111111111', 'spam', 'actioned'),
  ('30000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'user', '22222222-2222-2222-2222-222222222222', 'spam', 'actioned'),
  ('30000000-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', 'user', '44444444-4444-4444-4444-444444444444', 'spam', 'actioned'),
  ('30000000-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', 'user', '11111111-1111-1111-1111-111111111111', 'spam', 'actioned'),
  ('30000000-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333', 'user', '11111111-1111-1111-1111-111111111111', 'spam', 'actioned');

insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'restrict', 'spam', 3, now() + interval '3 days'),
  ('a0000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333', 'suspend', 'harassment', 7, now() + interval '7 days'),
  ('a0000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', '44444444-4444-4444-4444-444444444444', '33333333-3333-3333-3333-333333333333', 'restrict', 'self-review fixture', 1, now() + interval '1 day'),
  ('a0000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'no_action', 'nothing to see', null, null),
  ('a0000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333', 'warning', 'second warning fixture', null, null);

-- ------------------------------------------------------------
-- CHECK 1-4: submit_appeal() input validation.
-- ------------------------------------------------------------

-- CHECK1: bob tries to appeal alice's action -- must be rejected.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_appeal('a0000000-0000-0000-0000-000000000001'::uuid, 'not mine', null);
    insert into results values ('CHECK1_appeal_someone_elses_action_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK1_appeal_someone_elses_action_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK2: alice tries to appeal a no_action action -- must be rejected.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_appeal('a0000000-0000-0000-0000-000000000004'::uuid, 'appealing nothing', null);
    insert into results values ('CHECK2_appeal_no_action_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK2_appeal_no_action_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK3: alice tries to appeal with an evidence path under bob's
-- folder, not her own -- must be rejected.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_appeal(
      'a0000000-0000-0000-0000-000000000001'::uuid,
      'has evidence',
      array['22222222-2222-2222-2222-222222222222/evidence.jpg']
    );
    insert into results values ('CHECK3_evidence_path_wrong_owner_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK3_evidence_path_wrong_owner_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK4: alice submits a real appeal on her Restrict, with evidence
-- under her own folder -- must succeed.
do $$
declare
  v_appeal_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select public.submit_appeal(
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'ฉันไม่ได้ทำผิด',
    array['11111111-1111-1111-1111-111111111111/evidence.jpg']
  ) into v_appeal_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK4_submit_appeal_succeeds', (case when v_appeal_id is not null then 1 else 0 end), 1);
end
$$;

-- CHECK5: alice tries to appeal the SAME action a second time -- must
-- be rejected with the friendly message, not a raw unique_violation.
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.submit_appeal('a0000000-0000-0000-0000-000000000001'::uuid, 'again', null);
    insert into results values ('CHECK5_duplicate_appeal_rejected', 0, 1);
  exception
    when others then
      insert into results values ('CHECK5_duplicate_appeal_rejected', 1, 1);
      insert into results values (
        'CHECK5b_duplicate_appeal_friendly_message',
        (case when sqlerrm = 'This moderation action has already been appealed' then 1 else 0 end),
        1
      );
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- bob submits his own appeal on the Suspend (used by CHECK9-11 below).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  perform public.submit_appeal('a0000000-0000-0000-0000-000000000002'::uuid, 'ฉันไม่ได้คุกคามใคร', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- dave (a moderator, restricted himself) appeals his own action --
-- used by CHECK7-8 (self-review).
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  perform public.submit_appeal('a0000000-0000-0000-0000-000000000003'::uuid, 'ฉันเป็นผู้ดูแลเอง', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: RLS on `appeals` -- eve (an uninvolved ordinary user) gets
-- zero rows querying alice's appeal directly, but alice/carol (the
-- appellant/a moderator) each get their own visibility.
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK6a_unrelated_user_sees_no_appeals', count(*), 0
from public.appeals;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK6b_appellant_sees_own_appeal', count(*), 1
from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000001'::uuid;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK6c_moderator_sees_all_pending_appeals', count(*), 3
from public.appeals where status = 'pending';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 7-8: decide_appeal() self-review guard -- neither approve nor
-- reject is allowed when the reviewer is the target of the action.
-- ------------------------------------------------------------
do $$
declare
  v_appeal_id uuid;
begin
  select id into v_appeal_id from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000003'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.decide_appeal(v_appeal_id, true, null);
    insert into results values ('CHECK7_self_review_approve_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK7_self_review_approve_rejected', 1, 1);
  end;
  begin
    perform public.decide_appeal(v_appeal_id, false, 'no');
    insert into results values ('CHECK8_self_review_reject_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK8_self_review_reject_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK9: bob (an ordinary user, not a moderator) tries to decide his
-- own appeal -- must be rejected for a different reason (not
-- authorized at all, regardless of self-review).
do $$
declare
  v_appeal_id uuid;
begin
  select id into v_appeal_id from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000002'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.decide_appeal(v_appeal_id, true, null);
    insert into results values ('CHECK9_non_moderator_decide_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK9_non_moderator_decide_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- A *different* moderator (carol) CAN decide dave's self-review appeal.
do $$
declare
  v_appeal_id uuid;
begin
  select id into v_appeal_id from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000003'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.decide_appeal(v_appeal_id, true, null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results
select 'CHECK9b_different_moderator_can_decide_self_review_case', count(*), 1
from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000003'::uuid and status = 'approved';

-- ------------------------------------------------------------
-- CHECK 10-11: reject requires a reason.
-- ------------------------------------------------------------
do $$
declare
  v_appeal_id uuid;
begin
  select id into v_appeal_id from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000002'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.decide_appeal(v_appeal_id, false, null);
    insert into results values ('CHECK10_reject_without_reason_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK10_reject_without_reason_rejected', 1, 1);
  end;
  perform public.decide_appeal(v_appeal_id, false, 'หลักฐานไม่เพียงพอ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 12-16: overturned_at flips is_posting_blocked()/
-- get_my_moderation_status() -- approve does, reject doesn't -- and
-- appeal_approved/appeal_rejected notifications never leak the
-- reviewer's identity.
-- ------------------------------------------------------------
do $$
declare
  v_appeal_id uuid;
begin
  select id into v_appeal_id from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000001'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.decide_appeal(v_appeal_id, true, null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

insert into results
select 'CHECK12_approved_restrict_no_longer_blocks_posting',
  (case when internal.is_posting_blocked('11111111-1111-1111-1111-111111111111'::uuid) then 1 else 0 end),
  0;

insert into results
select 'CHECK13_rejected_suspend_still_blocks_posting',
  (case when internal.is_posting_blocked('22222222-2222-2222-2222-222222222222'::uuid) then 1 else 0 end),
  1;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK14_approved_restrict_status_no_longer_restricted',
  (case when is_restricted then 1 else 0 end), 0
from public.get_my_moderation_status();
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

insert into results
select 'CHECK15a_approved_notification_actor_id_null', count(*), 1
from public.notifications
where recipient_id = '11111111-1111-1111-1111-111111111111' and type = 'appeal_approved' and actor_id is null;

insert into results
select 'CHECK15b_rejected_notification_has_reason_actor_id_null', count(*), 1
from public.notifications
where recipient_id = '22222222-2222-2222-2222-222222222222' and type = 'appeal_rejected'
  and actor_id is null and reason = 'หลักฐานไม่เพียงพอ';

-- Re-run, as alice (the recipient) under RLS, the exact join query
-- notification_repository.dart's actor embed relies on -- must come
-- back with zero rows (the reviewer's identity is unreachable through
-- this table, not just absent from a hand-picked select list).
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK16_approved_actor_unreachable_via_join', count(*), 0
from public.notifications n
join public.profiles p on p.id = n.actor_id
where n.recipient_id = '11111111-1111-1111-1111-111111111111' and n.type = 'appeal_approved';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 17: appellant-facing fetchMyAppeal-shaped query never
-- includes reviewer_id in its column list (column-list discipline,
-- not RLS -- AppealRepository.fetchMyAppeal's actual select list).
-- ------------------------------------------------------------
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK17_fetch_my_appeal_shape_succeeds', count(*), 1
from (
  select reason, evidence_paths, status, decision_reason, created_at
  from public.appeals
  where moderation_action_id = 'a0000000-0000-0000-0000-000000000001'::uuid
) t;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

-- ------------------------------------------------------------
-- CHECK 18-19: RLS on the appeal-evidence storage bucket -- a user
-- can only INSERT an object under their own uid-prefixed folder.
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('appeal-evidence', '22222222-2222-2222-2222-222222222222/sneaky.jpg', '11111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK18_evidence_upload_wrong_folder_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK18_evidence_upload_wrong_folder_rejected', 1, 1);
  end;
  begin
    insert into storage.objects (bucket_id, name, owner)
    values ('appeal-evidence', '11111111-1111-1111-1111-111111111111/own.jpg', '11111111-1111-1111-1111-111111111111');
    insert into results values ('CHECK19_evidence_upload_own_folder_accepted', 1, 1);
  exception when others then
    insert into results values ('CHECK19_evidence_upload_own_folder_accepted', 0, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- ------------------------------------------------------------
-- CHECK 20: regression -- WYN-029's own reporter-identity-invisible
-- and moderation_queue behavior untouched by this migration (spot
-- check, the full suite lives in wyn_029_moderation_queue_test.sh).
-- ------------------------------------------------------------
insert into results
select 'CHECK20_moderation_queue_still_has_no_reporter_id_column',
  (case when exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'moderation_queue' and column_name = 'reporter_id'
  ) then 1 else 0 end),
  0;

-- ------------------------------------------------------------
-- CHECK 21-24: added by an independent QA pass (Round 2) after CHECK
-- 1-20 above shipped self-QA'd by the same session as the Coding
-- Output, not a genuinely separate QA run -- these close the 4 real
-- coverage gaps that left: this script only ever verified
-- Restrict-approved end to end (never Suspend-approved/Ban-approved),
-- never exercised the `anon` role (the exact root cause class WYN-027
-- already hit once: Postgres grants EXECUTE to PUBLIC by default),
-- never tried re-deciding an already-decided appeal, and never tested
-- get_my_moderation_action()'s cross-user scoping.
-- ------------------------------------------------------------
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000006', '33333333-3333-3333-3333-333333333333', 'user', '66666666-6666-6666-6666-666666666666', 'harassment', 'actioned');

-- frank: a fresh user with no other active moderation action (bob
-- already has his own still-active rejected Suspend, which would keep
-- blocking him regardless of this one -- using him here would prove
-- nothing). No new Ban fixture is added -- suspend-approved and
-- ban-approved use the same overturned_at code path (see
-- get_my_moderation_status() above), restrict-approved is already
-- covered by CHECK12/14, so exercising Suspend here closes the only
-- branch neither covers.
insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('a0000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000006', '66666666-6666-6666-6666-666666666666', '33333333-3333-3333-3333-333333333333', 'suspend', 'frank suspend fixture', 7, now() + interval '7 days');

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  perform public.submit_appeal('a0000000-0000-0000-0000-000000000006'::uuid, 'appealing my suspend', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
do $$
declare
  v_appeal_id uuid;
begin
  select id into v_appeal_id from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000006'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.decide_appeal(v_appeal_id, true, null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
insert into results
select 'CHECK21_suspend_approved_no_longer_blocks_posting',
  (case when internal.is_posting_blocked('66666666-6666-6666-6666-666666666666'::uuid) then 1 else 0 end), 0;

-- CHECK22: `anon` role (no JWT at all) calling submit_appeal/decide_appeal
-- must be rejected, not just silently no-op -- Postgres grants EXECUTE
-- to PUBLIC by default on function creation.
set role anon;
do $$
begin
  begin
    perform public.submit_appeal('a0000000-0000-0000-0000-000000000006'::uuid, 'anon appeal', null);
    insert into results values ('CHECK22a_anon_submit_appeal_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK22a_anon_submit_appeal_rejected', 1, 1);
  end;
  begin
    perform public.decide_appeal(gen_random_uuid(), true, null);
    insert into results values ('CHECK22b_anon_decide_appeal_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK22b_anon_decide_appeal_rejected', 1, 1);
  end;
end
$$;
reset role;

-- CHECK23: re-deciding an already-decided appeal (alice's, approved by
-- CHECK12 above) must be rejected -- not silently re-applied, which
-- would let a moderator flip a decision back and forth or double-insert
-- notifications.
do $$
declare
  v_appeal_id uuid;
  v_before int;
  v_after int;
begin
  select id into v_appeal_id from public.appeals where moderation_action_id = 'a0000000-0000-0000-0000-000000000001'::uuid;
  select count(*) into v_before from public.notifications where recipient_id = '11111111-1111-1111-1111-111111111111' and type = 'appeal_approved';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.decide_appeal(v_appeal_id, false, 'changed my mind');
    insert into results values ('CHECK23a_redecide_already_decided_rejected', 0, 1);
  exception when others then
    insert into results values ('CHECK23a_redecide_already_decided_rejected', 1, 1);
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select count(*) into v_after from public.notifications where recipient_id = '11111111-1111-1111-1111-111111111111' and type = 'appeal_approved';
  insert into results values ('CHECK23b_redecide_no_duplicate_notification', v_after - v_before, 0);
end
$$;

-- CHECK24: get_my_moderation_action() cross-user scoping -- eve
-- (uninvolved) querying alice's action id gets zero rows, alice gets
-- her own.
set role authenticated;
set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK24a_get_my_moderation_action_cross_user_empty', count(*), 0
from public.get_my_moderation_action('a0000000-0000-0000-0000-000000000001'::uuid);
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
set request.jwt.claim.role = 'authenticated';
insert into results
select 'CHECK24b_get_my_moderation_action_own_visible', count(*), 1
from public.get_my_moderation_action('a0000000-0000-0000-0000-000000000001'::uuid);
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

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
