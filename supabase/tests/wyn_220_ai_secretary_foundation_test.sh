#!/usr/bin/env bash
# WYN-220 Phase 1: WYNOS AI Secretary foundation
# (supabase/migrations/20261010170000_wyn220_ai_secretary_foundation.sql).
#
#   1. Only the super admin is allowed; status() reports allowed=false to a
#      platform admin, a moderator and a user, and the kill switch starts OFF.
#   2. begin_request is refused while the kill switch is off, for anyone but
#      the super admin, for empty/oversized messages and for someone else's
#      conversation.
#   3. Kill switch and limits: super admin only, audited, no-op when unchanged.
#   4. Rate limit (requests per minute) and daily token budget are enforced.
#   5. Messages, tool runs and usage cannot be written directly by API roles;
#      tool runs cannot be updated or deleted.
#   6. Each owner reads only their own rows; other admins read nothing.
#   7. Memory notes: owner-only insert/delete, expiry window enforced,
#      expired notes and conversations are hidden and purged.
#   8. The migration is idempotent and keeps older audit event types.
#
# Requirements: a local PostgreSQL server reachable either as the
# current OS user or via `sudo -u postgres`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
WYN219_FILE="$SCRIPT_DIR/../migrations/20261010150000_wyn219_admin_permissions_foundation.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations/20261010170000_wyn220_ai_secretary_foundation.sql"
DB_NAME="wyn_220_ai_secretary_foundation_test"
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


cat > "$WORK_DIR/05_pre_seed.sql" <<'EOF2'
\set ON_ERROR_STOP on
--   sa    the super admin
--   adm   another platform admin (not super admin)
--   mod   a moderator
--   usr   a regular user
insert into auth.users (id, email) values
  ('92200000-0000-0000-0000-000000000001', 'sa@test.invalid'),
  ('92200000-0000-0000-0000-000000000002', 'adm@test.invalid'),
  ('92200000-0000-0000-0000-000000000003', 'mod@test.invalid'),
  ('92200000-0000-0000-0000-000000000004', 'usr@test.invalid');

insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('92200000-0000-0000-0000-000000000001', 'p_sa', 'sa', 'admin', false),
  ('92200000-0000-0000-0000-000000000002', 'p_adm', 'adm', 'admin', false),
  ('92200000-0000-0000-0000-000000000003', 'p_mod', 'mod', 'moderator', false),
  ('92200000-0000-0000-0000-000000000004', 'p_usr', 'usr', 'user', false);

insert into public.audit_log (actor_id, event_type, detail)
values (null, 'system_notification_sent', '{}'::jsonb);
EOF2

cat > "$WORK_DIR/07_super_admin.sql" <<'EOF2'
insert into internal.platform_super_admins (user_id) values ('92200000-0000-0000-0000-000000000001');
EOF2

cat > "$WORK_DIR/10_assert.sql" <<'EOF2'
\pset pager off
\set ON_ERROR_STOP on

create table results (check_name text primary key, actual bigint, expected bigint);
grant all on results to authenticated;

create or replace function pg_temp.refused(p_user uuid, p_sql text) returns int
language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('role', 'authenticated', true);
  begin
    execute p_sql;
  exception when others then
    perform set_config('role', 'postgres', true);
    return 1;
  end;
  perform set_config('role', 'postgres', true);
  return 0;
end;
$$;

-- Evaluates a scalar expression as p_user.
create or replace function pg_temp.as_user(p_user uuid, p_expr text) returns bigint
language plpgsql as $$
declare v bigint;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('role', 'authenticated', true);
  execute 'select (' || p_expr || ')::bigint' into v;
  perform set_config('role', 'postgres', true);
  return v;
end;
$$;

create or replace function pg_temp.flag(p_user uuid, p_expr text) returns bigint
language plpgsql as $$
declare v boolean;
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('role', 'authenticated', true);
  execute 'select (' || p_expr || ')' into v;
  perform set_config('role', 'postgres', true);
  return case when v then 1 else 0 end;
end;
$$;

-- CHECK 1: access and default state.
do $$
declare
  sa uuid := '92200000-0000-0000-0000-000000000001';
  adm uuid := '92200000-0000-0000-0000-000000000002';
  m uuid := '92200000-0000-0000-0000-000000000003';
  u uuid := '92200000-0000-0000-0000-000000000004';
begin
  insert into results values
    ('CHECK1a_super_admin_allowed', pg_temp.flag(sa, $q$(public.ai_secretary_status()->>'allowed')::boolean$q$), 1),
    ('CHECK1b_kill_switch_defaults_off', pg_temp.flag(sa, $q$(public.ai_secretary_status()->>'enabled')::boolean$q$), 0),
    ('CHECK1c_admin_not_allowed', pg_temp.flag(adm, $q$(public.ai_secretary_status()->>'allowed')::boolean$q$), 0),
    ('CHECK1d_moderator_not_allowed', pg_temp.flag(m, $q$(public.ai_secretary_status()->>'allowed')::boolean$q$), 0),
    ('CHECK1e_user_not_allowed', pg_temp.flag(u, $q$(public.ai_secretary_status()->>'allowed')::boolean$q$), 0),
    ('CHECK1f_no_session_not_allowed', pg_temp.flag(null, $q$(public.ai_secretary_status()->>'allowed')::boolean$q$), 0),
    ('CHECK1g_status_hides_settings_from_admin', pg_temp.flag(adm, $q$public.ai_secretary_status() ? 'enabled'$q$), 0);
end
$$;

-- CHECK 2: begin_request gate.
do $$
declare
  sa uuid := '92200000-0000-0000-0000-000000000001';
  adm uuid := '92200000-0000-0000-0000-000000000002';
begin
  insert into results values
    ('CHECK2a_refused_while_off', pg_temp.refused(sa, $q$select public.ai_secretary_begin_request(null, 'hello')$q$), 1),
    ('CHECK2b_admin_cannot_turn_on', pg_temp.refused(adm, $q$select public.ai_secretary_set_enabled(true)$q$), 1),
    ('CHECK2c_super_admin_turns_on', pg_temp.refused(sa, $q$select public.ai_secretary_set_enabled(true)$q$), 0),
    ('CHECK2d_admin_refused_when_on', pg_temp.refused(adm, $q$select public.ai_secretary_begin_request(null, 'hello')$q$), 1),
    ('CHECK2e_empty_message_refused', pg_temp.refused(sa, $q$select public.ai_secretary_begin_request(null, '   ')$q$), 1),
    ('CHECK2f_oversized_message_refused', pg_temp.refused(sa, $q$select public.ai_secretary_begin_request(null, repeat('x', 4001))$q$), 1),
    ('CHECK2g_unknown_conversation_refused', pg_temp.refused(sa, $q$select public.ai_secretary_begin_request('92200000-0000-0000-0000-0000000000ff', 'hi')$q$), 1),
    ('CHECK2h_super_admin_starts_conversation', pg_temp.refused(sa, $q$select public.ai_secretary_begin_request(null, 'สรุปภาพรวมวันนี้')$q$), 0);
end
$$;

insert into results
select 'CHECK2i_conversation_created_with_title', count(*), 1 from public.ai_conversations
 where owner_id = '92200000-0000-0000-0000-000000000001' and title = 'สรุปภาพรวมวันนี้';

-- Someone else's conversation: give adm a conversation directly, sa must not continue it.
insert into public.ai_conversations (id, owner_id, title)
values ('92200000-0000-0000-0000-0000000000c2', '92200000-0000-0000-0000-000000000002', 'adm private');
insert into results values
  ('CHECK2j_cannot_continue_others_conversation',
   pg_temp.refused('92200000-0000-0000-0000-000000000001', $q$select public.ai_secretary_begin_request('92200000-0000-0000-0000-0000000000c2', 'x')$q$), 1),
  ('CHECK2k_cannot_record_into_others_conversation',
   pg_temp.refused('92200000-0000-0000-0000-000000000001', $q$select public.ai_secretary_record_reply('92200000-0000-0000-0000-0000000000c2', 'x', 'm', 1, 1, 1)$q$), 1),
  ('CHECK2l_cannot_read_others_messages',
   pg_temp.as_user('92200000-0000-0000-0000-000000000001', $q$(select count(*) from public.ai_secretary_conversation_messages('92200000-0000-0000-0000-0000000000c2', 20))$q$), 0);

-- CHECK 3: kill switch and limits are audited and idempotent.
do $$
declare sa uuid := '92200000-0000-0000-0000-000000000001';
begin
  perform pg_temp.refused(sa, $q$select public.ai_secretary_set_enabled(true)$q$); -- unchanged: no-op
  insert into results values
    ('CHECK3a_bad_limits_refused', pg_temp.refused(sa, $q$select public.ai_secretary_set_limits(-1, 6)$q$), 1),
    ('CHECK3b_admin_cannot_set_limits', pg_temp.refused('92200000-0000-0000-0000-000000000002', $q$select public.ai_secretary_set_limits(1000, 2)$q$), 1),
    ('CHECK3c_super_admin_sets_limits', pg_temp.refused(sa, $q$select public.ai_secretary_set_limits(1000, 3)$q$), 0);
end
$$;

insert into results
select 'CHECK3d_audit_rows', count(*), 2 from public.audit_log
 where event_type = 'ai_secretary_settings_changed' and actor_id = '92200000-0000-0000-0000-000000000001';

-- CHECK 4: rate limit (3/min now; one request already made) and token budget (1000/day).
do $$
declare
  sa uuid := '92200000-0000-0000-0000-000000000001';
  conv uuid;
begin
  select id into conv from public.ai_conversations where owner_id = sa limit 1;
  insert into results values
    ('CHECK4a_second_request_ok', pg_temp.refused(sa, format($q$select public.ai_secretary_begin_request(%L, 'two')$q$, conv)), 0),
    ('CHECK4b_third_request_ok', pg_temp.refused(sa, format($q$select public.ai_secretary_begin_request(%L, 'three')$q$, conv)), 0),
    ('CHECK4c_fourth_request_rate_limited', pg_temp.refused(sa, format($q$select public.ai_secretary_begin_request(%L, 'four')$q$, conv)), 1);

  -- Age the messages out of the rate-limit window, then spend the budget.
  update public.ai_messages set created_at = now() - interval '2 minutes' where owner_id = sa;
  insert into results values
    ('CHECK4d_record_reply_ok', pg_temp.refused(sa, format($q$select public.ai_secretary_record_reply(%L, 'answer', 'claude-opus-5-5', 600, 400, 1200)$q$, conv)), 0),
    ('CHECK4e_negative_tokens_refused', pg_temp.refused(sa, format($q$select public.ai_secretary_record_reply(%L, 'x', 'm', -1, 0, 1)$q$, conv)), 1),
    ('CHECK4f_budget_exhausted_refused', pg_temp.refused(sa, format($q$select public.ai_secretary_begin_request(%L, 'five')$q$, conv)), 1),
    ('CHECK4g_status_reports_tokens_used', pg_temp.as_user(sa, $q$(public.ai_secretary_status()->>'tokens_used_today')::bigint$q$), 1000),
    ('CHECK4h_history_oldest_first', pg_temp.as_user(sa, format($q$(select count(*) from public.ai_secretary_conversation_messages(%L, 20))$q$, conv)), 4);
end
$$;

-- CHECK 5: direct writes refused; tool runs append-only.
do $$
declare
  sa uuid := '92200000-0000-0000-0000-000000000001';
  conv uuid;
begin
  select id into conv from public.ai_conversations where owner_id = sa limit 1;
  insert into results values
    ('CHECK5a_record_tool_run_ok', pg_temp.refused(sa, format($q$select public.ai_secretary_record_tool_run(%L, 'get_platform_overview', 1::smallint, 'succeeded', 'admin_dashboard_metrics', '{}'::jsonb, '{"rows":1}'::jsonb, null, 42)$q$, conv)), 0),
    ('CHECK5b_bad_tool_status_refused', pg_temp.refused(sa, format($q$select public.ai_secretary_record_tool_run(%L, 'x', 1::smallint, 'approved', null, '{}'::jsonb, null, null, 1)$q$, conv)), 1),
    ('CHECK5c_admin_cannot_record_tool_run', pg_temp.refused('92200000-0000-0000-0000-000000000002', $q$select public.ai_secretary_record_tool_run(null, 'x', 1::smallint, 'succeeded', null, '{}'::jsonb, null, null, 1)$q$), 1),
    ('CHECK5d_no_direct_message_insert', pg_temp.refused(sa, format($q$insert into public.ai_messages (conversation_id, owner_id, role, content) values (%L, %L, 'user', 'x')$q$, conv, sa)), 1),
    ('CHECK5e_no_direct_usage_insert', pg_temp.refused(sa, format($q$insert into public.ai_usage (owner_id, model, input_tokens, output_tokens) values (%L, 'm', 0, 0)$q$, sa)), 1),
    ('CHECK5f_no_usage_delete', pg_temp.refused(sa, $q$delete from public.ai_usage$q$), 1),
    ('CHECK5g_no_tool_run_update', pg_temp.refused(sa, $q$update public.ai_tool_runs set status = 'failed'$q$), 1),
    ('CHECK5h_no_tool_run_delete', pg_temp.refused(sa, $q$delete from public.ai_tool_runs$q$), 1),
    ('CHECK5i_no_settings_read', pg_temp.refused(sa, $q$select * from internal.ai_secretary_settings$q$), 1),
    ('CHECK5j_no_conversation_insert', pg_temp.refused(sa, format($q$insert into public.ai_conversations (owner_id, title) values (%L, 't')$q$, sa)), 1),
    ('CHECK5k_purge_not_callable', pg_temp.refused(sa, $q$select internal.ai_secretary_purge_expired()$q$), 1);
end
$$;

-- CHECK 6: row visibility.
do $$
declare
  sa uuid := '92200000-0000-0000-0000-000000000001';
  adm uuid := '92200000-0000-0000-0000-000000000002';
begin
  insert into results values
    ('CHECK6a_sa_sees_own_conversation_only', pg_temp.as_user(sa, $q$(select count(*) from public.ai_conversations)$q$), 1),
    ('CHECK6b_sa_sees_own_tool_runs', pg_temp.as_user(sa, $q$(select count(*) from public.ai_tool_runs)$q$), 1),
    ('CHECK6c_admin_sees_no_conversations', pg_temp.as_user(adm, $q$(select count(*) from public.ai_conversations)$q$), 0),
    ('CHECK6d_admin_sees_no_messages', pg_temp.as_user(adm, $q$(select count(*) from public.ai_messages)$q$), 0),
    ('CHECK6e_admin_sees_no_tool_runs', pg_temp.as_user(adm, $q$(select count(*) from public.ai_tool_runs)$q$), 0),
    ('CHECK6f_admin_sees_no_usage', pg_temp.as_user(adm, $q$(select count(*) from public.ai_usage)$q$), 0);
end
$$;

-- CHECK 7: memory notes.
do $$
declare
  sa uuid := '92200000-0000-0000-0000-000000000001';
  adm uuid := '92200000-0000-0000-0000-000000000002';
begin
  insert into results values
    ('CHECK7a_sa_adds_note', pg_temp.refused(sa, $q$insert into public.ai_memory_items (kind, content) values ('decision', 'Founder อนุมัติ WYN-219 Phase 1')$q$), 0),
    ('CHECK7b_sa_cannot_add_for_someone_else', pg_temp.refused(sa, $q$insert into public.ai_memory_items (owner_id, content) values ('92200000-0000-0000-0000-000000000002', 'x')$q$), 1),
    ('CHECK7c_admin_cannot_add', pg_temp.refused(adm, $q$insert into public.ai_memory_items (content) values ('x')$q$), 1),
    ('CHECK7d_expiry_over_a_year_refused', pg_temp.refused(sa, $q$insert into public.ai_memory_items (content, expires_at) values ('x', now() + interval '400 days')$q$), 1),
    ('CHECK7e_blank_note_refused', pg_temp.refused(sa, $q$insert into public.ai_memory_items (content) values ('   ')$q$), 1),
    ('CHECK7f_admin_sees_no_notes', pg_temp.as_user(adm, $q$(select count(*) from public.ai_memory_items)$q$), 0),
    ('CHECK7g_no_note_update', pg_temp.refused(sa, $q$update public.ai_memory_items set content = 'changed'$q$), 1),
    ('CHECK7h_sa_sees_note', pg_temp.as_user(sa, $q$(select count(*) from public.ai_memory_items)$q$), 1);
end
$$;

-- Expire everything of sa's, then check hiding and purge.
update public.ai_memory_items set created_at = now() - interval '200 days', expires_at = now() - interval '1 day';
update public.ai_conversations set expires_at = now() - interval '1 day' where owner_id = '92200000-0000-0000-0000-000000000001';
insert into results values
  ('CHECK7i_expired_note_hidden', pg_temp.as_user('92200000-0000-0000-0000-000000000001', $q$(select count(*) from public.ai_memory_items)$q$), 0),
  ('CHECK7j_expired_conversation_hidden', pg_temp.as_user('92200000-0000-0000-0000-000000000001', $q$(select count(*) from public.ai_conversations)$q$), 0),
  ('CHECK7k_expired_messages_hidden', pg_temp.as_user('92200000-0000-0000-0000-000000000001', $q$(select count(*) from public.ai_messages)$q$), 0),
  ('CHECK7l_purge_count', internal.ai_secretary_purge_expired(), 2);
insert into results
select 'CHECK7m_messages_purged_with_conversation', count(*), 0 from public.ai_messages
 where owner_id = '92200000-0000-0000-0000-000000000001';
insert into results
select 'CHECK7n_tool_runs_kept_after_purge', count(*), 1 from public.ai_tool_runs;

-- CHECK 8: older event types kept.
insert into results
select 'CHECK8a_older_event_type_kept', count(*), 1 from public.audit_log where event_type = 'system_notification_sent';

select check_name, actual, expected from results order by check_name;
EOF2

dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

# The migration runs twice: it must be idempotent.
for step in "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$WORK_DIR/05_pre_seed.sql" "$WYN219_FILE" "$WORK_DIR/07_super_admin.sql" "$MIGRATION_FILE" "$MIGRATION_FILE" "$WORK_DIR/10_assert.sql"; do
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
