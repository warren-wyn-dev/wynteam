#!/usr/bin/env bash
# Admin inactive reminders (supabase/migrations_admin_inactive_reminders.sql).
#
#   1. Only people not active for the chosen 1 / 3 / 7 days are reached.
#      Activity = sign-in, a refreshed session (app open), or a post.
#   2. Brand-new accounts, staff, banned accounts and people who turned off
#      "system" notifications are never reached.
#   3. A person is reminded at most once per 24 hours.
#   4. Only an admin may count or send; moderators and users are refused.
#   5. Invalid days and blank / too long messages are refused.
#   6. The helper and the log table are not reachable by app users.
#   7. Each send writes one audit_log row with the recipient count, and the
#      migration can be applied twice without losing older event types.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations_admin_inactive_reminders.sql"
DB_NAME="admin_inactive_reminders_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

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
  email text,
  last_sign_in_at timestamptz
);

-- Supabase keeps one row per signed-in device; updated_at moves when the
-- app refreshes its session.
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
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

-- ir_admin, ir_mod, and eight regular users:
--   idle10  created 10 days ago, never did anything
--   idle2   created 10 days ago, app session refreshed 2 days ago
--   post2   created 10 days ago, posted 2 days ago
--   open    created 10 days ago, app session refreshed 1 hour ago
--   login   created 10 days ago, signed in 1 hour ago
--   new     created 2 hours ago
--   optout  created 10 days ago, turned off system notifications
--   banned  created 10 days ago, banned
insert into auth.users (id, email, last_sign_in_at) values
  ('91000000-0000-0000-0000-000000000001', 'a1@test.invalid', null),
  ('91000000-0000-0000-0000-000000000002', 'm1@test.invalid', null),
  ('91000000-0000-0000-0000-000000000011', 'idle10@test.invalid', null),
  ('91000000-0000-0000-0000-000000000012', 'idle2@test.invalid', null),
  ('91000000-0000-0000-0000-000000000013', 'post2@test.invalid', null),
  ('91000000-0000-0000-0000-000000000014', 'open@test.invalid', null),
  ('91000000-0000-0000-0000-000000000015', 'login@test.invalid', now() - interval '1 hour'),
  ('91000000-0000-0000-0000-000000000016', 'new@test.invalid', null),
  ('91000000-0000-0000-0000-000000000017', 'optout@test.invalid', null),
  ('91000000-0000-0000-0000-000000000018', 'banned@test.invalid', null);

insert into public.profiles (id, username, display_name, platform_role, is_private, created_at) values
  ('91000000-0000-0000-0000-000000000001', 'ir_admin', 'admin', 'admin', false, now() - interval '30 days'),
  ('91000000-0000-0000-0000-000000000002', 'ir_mod', 'mod', 'moderator', false, now() - interval '30 days'),
  ('91000000-0000-0000-0000-000000000011', 'ir_idle10', 'idle10', 'user', false, now() - interval '10 days'),
  ('91000000-0000-0000-0000-000000000012', 'ir_idle2', 'idle2', 'user', false, now() - interval '10 days'),
  ('91000000-0000-0000-0000-000000000013', 'ir_post2', 'post2', 'user', false, now() - interval '10 days'),
  ('91000000-0000-0000-0000-000000000014', 'ir_open', 'open', 'user', false, now() - interval '10 days'),
  ('91000000-0000-0000-0000-000000000015', 'ir_login', 'login', 'user', false, now() - interval '10 days'),
  ('91000000-0000-0000-0000-000000000016', 'ir_new', 'new', 'user', false, now() - interval '2 hours'),
  ('91000000-0000-0000-0000-000000000017', 'ir_optout', 'optout', 'user', false, now() - interval '10 days'),
  ('91000000-0000-0000-0000-000000000018', 'ir_banned', 'banned', 'user', false, now() - interval '10 days');

insert into auth.sessions (user_id, created_at, updated_at) values
  ('91000000-0000-0000-0000-000000000012', now() - interval '9 days', now() - interval '2 days'),
  ('91000000-0000-0000-0000-000000000014', now() - interval '9 days', now() - interval '1 hour');

insert into public.drops (author_id, image_url, caption, created_at) values
  ('91000000-0000-0000-0000-000000000013', 'https://example.invalid/a.jpg', 'hello', now() - interval '2 days');

insert into public.notification_settings (user_id, system) values
  ('91000000-0000-0000-0000-000000000017', false);

do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '91000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  perform public.admin_apply_user_action('91000000-0000-0000-0000-000000000018', 'ban', 'test ban', null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK 1: who each choice reaches before anything is sent.
-- 1 day: idle10, idle2, post2.  3 and 7 days: idle10 only.
do $$
declare v1 int; v3 int; v7 int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  v1 := public.admin_count_inactive_users(1);
  v3 := public.admin_count_inactive_users(3);
  v7 := public.admin_count_inactive_users(7);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values
    ('CHECK1a_count_1_day', v1, 3),
    ('CHECK1b_count_3_days', v3, 1),
    ('CHECK1c_count_7_days', v7, 1);
end
$$;

-- CHECK 2: a 3-day send reaches only idle10, as a system notification.
do $$
declare v_sent int; v_idle10 int; v_others int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  v_sent := public.admin_send_inactive_reminder(3, '  คิดถึงนะ กลับมาดูโพสต์ใหม่กัน  ');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select count(*) into v_idle10 from public.notifications
   where recipient_id = '91000000-0000-0000-0000-000000000011'
     and type = 'system' and actor_id is null and reason = 'คิดถึงนะ กลับมาดูโพสต์ใหม่กัน';
  select count(*) into v_others from public.notifications
   where recipient_id <> '91000000-0000-0000-0000-000000000011'
     and reason = 'คิดถึงนะ กลับมาดูโพสต์ใหม่กัน';
  insert into results values
    ('CHECK2a_sent_3_days', v_sent, 1),
    ('CHECK2b_idle10_notified', v_idle10, 1),
    ('CHECK2c_nobody_else', v_others, 0);
end
$$;

-- CHECK 3: 24-hour limit. A 1-day send now skips idle10, who was just reminded.
do $$
declare v_sent int; v_again int; v_idle10 int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  v_sent := public.admin_send_inactive_reminder(1, 'second');
  v_again := public.admin_send_inactive_reminder(1, 'third');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  select count(*) into v_idle10 from public.notifications
   where recipient_id = '91000000-0000-0000-0000-000000000011' and type = 'system';
  insert into results values
    ('CHECK3a_second_send_reaches_idle2_post2', v_sent, 2),
    ('CHECK3b_idle10_still_one', v_idle10, 1),
    ('CHECK3c_third_send_reaches_nobody', v_again, 0);
end
$$;

-- CHECK 4: after 24 hours the same person can be reminded again.
update internal.inactive_reminders set last_sent_at = now() - interval '25 hours'
 where user_id = '91000000-0000-0000-0000-000000000011';
do $$
declare v int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '91000000-0000-0000-0000-000000000001';
  set request.jwt.claim.role = 'authenticated';
  v := public.admin_count_inactive_users(7);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK4_reminded_again_after_24h', v, 1);
end
$$;

-- CHECK 5: only admins; bad input refused (7 refusals expected).
do $$
declare
  v_refused int := 0;
  v_case record;
begin
  for v_case in
    select * from (values
      ('91000000-0000-0000-0000-000000000002', 3, 'hi'),
      ('91000000-0000-0000-0000-000000000011', 3, 'hi'),
      ('91000000-0000-0000-0000-000000000001', 2, 'hi'),
      ('91000000-0000-0000-0000-000000000001', null, 'hi'),
      ('91000000-0000-0000-0000-000000000001', 3, '   '),
      ('91000000-0000-0000-0000-000000000001', 3, repeat('a', 501))
    ) as t(caller, days, message)
  loop
    begin
      perform set_config('request.jwt.claim.sub', v_case.caller, true);
      set local role authenticated;
      perform public.admin_send_inactive_reminder(v_case.days, v_case.message);
      reset role;
    exception when others then
      reset role;
      v_refused := v_refused + 1;
    end;
  end loop;
  begin
    perform set_config('request.jwt.claim.sub', '91000000-0000-0000-0000-000000000002', true);
    set local role authenticated;
    perform public.admin_count_inactive_users(3);
    reset role;
  exception when others then
    reset role;
    v_refused := v_refused + 1;
  end;
  insert into results values ('CHECK5_refused', v_refused, 7);
end
$$;

-- CHECK 6: the helper and the log table are not reachable by app users.
insert into results
select 'CHECK6a_helper_not_executable',
  has_function_privilege('authenticated', 'internal.inactive_reminder_recipients(integer)', 'execute')::int, 0;
insert into results
select 'CHECK6b_log_not_readable',
  has_table_privilege('authenticated', 'internal.inactive_reminders', 'select')::int, 0;
insert into results
select 'CHECK6c_anon_cannot_send',
  has_function_privilege('anon', 'public.admin_send_inactive_reminder(integer, text)', 'execute')::int, 0;

-- CHECK 7: one audit row per successful send, with its recipient count;
-- older event types still accepted.
insert into results
select 'CHECK7a_audit_rows', count(*)::int, 3
from public.audit_log where event_type = 'admin_inactive_reminder_sent';
insert into results
select 'CHECK7b_audit_recipient_total', coalesce(sum((detail->>'recipient_count')::int), 0)::int, 3
from public.audit_log where event_type = 'admin_inactive_reminder_sent';
insert into results
select 'CHECK7c_older_event_type_kept', count(*)::int, 1
from public.audit_log where event_type = 'admin_user_action_applied';

select check_name, actual, expected from results order by check_name;
EOF

dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

# The migration runs twice: it must be idempotent.
for step in "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$MIGRATION_FILE" "$MIGRATION_FILE" "$WORK_DIR/10_seed_and_assert.sql"; do
  if ! run_psql "$DB_NAME" "$step"; then
    echo "FAIL: $step errored" >&2
    dropdb_any "$DB_NAME"
    exit 1
  fi
done

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
