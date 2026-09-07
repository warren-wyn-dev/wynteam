#!/usr/bin/env bash
# QA regression test for WYN-133 (DM Presence -- privacy reciprocal
# check) -- written independently by AI QA & Security to verify the
# RPC/RLS layer directly, mirroring
# wyn_134_dm_new_message_notification_test.sh's harness/role-switching
# convention. Covers:
#   1. touch_my_presence() persists the caller's own last_seen_at.
#   2. get_conversation_partner_presence()'s coding-time bugfix: always
#      returns exactly 1 row when the reciprocal check passes (not 0
#      rows for a partner who never had a user_presence row written).
#   3. The reciprocal privacy rule actually works both directions --
#      turning your own show_online_status off hides the partner's
#      presence from you too, and vice versa; turning it back on
#      restores visibility.
#   4. Bypass test: a direct SELECT against `user_presence` for another
#      user's row is blocked by RLS regardless of toggle state -- the
#      RPC is the only sanctioned read path.
#   5. A non-participant cannot call the RPC for someone else's
#      conversation, and no one can INSERT/UPDATE another user's
#      presence row directly.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage: bash supabase/tests/wyn_133_dm_presence_test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn133_qa_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

run_psql() {
  local db="$1"; local file="$2"
  if psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  elif sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >"$WORK_DIR/psql.out" 2>&1; then
    return 0
  else
    cat "$WORK_DIR/psql.out" >&2
    return 1
  fi
}
createdb_any() { local db="$1"; createdb "$db" >/dev/null 2>&1 || sudo -u postgres createdb "$db" >/dev/null 2>&1; }
dropdb_any() { local db="$1"; dropdb --if-exists "$db" >/dev/null 2>&1 || sudo -u postgres dropdb --if-exists "$db" >/dev/null 2>&1 || true; }

cat > "$WORK_DIR/00_stub.sql" <<'EOF'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table if not exists auth.users (id uuid primary key default gen_random_uuid(), email text);
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role', true), '')
$$;
create schema if not exists storage;
create table if not exists storage.buckets (id text primary key, name text not null, public boolean not null default false);
create table if not exists storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text references storage.buckets (id), name text, owner uuid);
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name, '/') $$;
alter table storage.objects enable row level security;
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
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
create table results (check_name text primary key, actual text, expected text);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user');

insert into public.follows (follower_id, following_id) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111');

do $$
declare v_conv_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.get_or_create_conversation('22222222-2222-2222-2222-222222222222'::uuid);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;

-- CHECK1: touch_my_presence sets caller's own last_seen_at
do $$
declare v_ts timestamptz;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.touch_my_presence();
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select last_seen_at into v_ts from public.user_presence where user_id = '11111111-1111-1111-1111-111111111111'::uuid;
  insert into results values ('CHECK1_touch_my_presence_sets_own_last_seen', (case when v_ts is not null then 'set' else 'null' end), 'set');
end
$$;

-- CHECK2: default state (both show_online default true, no explicit row for bob) -- alice sees bob's presence, 1 row, show_online=true
do $$
declare v_conv_id uuid; v_show boolean; v_count int;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.get_conversation_partner_presence(v_conv_id);
  select show_online into v_show from public.get_conversation_partner_presence(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK2a_default_returns_exactly_1_row_bugfix', v_count::text, '1');
  insert into results values ('CHECK2b_default_show_online_true', v_show::text, 'true');
end
$$;

-- CHECK3: alice turns OFF her own show_online_status -- she can no longer see bob's presence (reciprocal), even though bob's own is still on
do $$
declare v_conv_id uuid; v_show boolean; v_last timestamptz;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.user_presence (user_id, show_online_status) values ('11111111-1111-1111-1111-111111111111', false)
    on conflict (user_id) do update set show_online_status = false;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select show_online, last_seen_at into v_show, v_last from public.get_conversation_partner_presence(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK3a_reciprocal_hides_others_when_i_turn_off_show_online', v_show::text, 'false');
  insert into results values ('CHECK3b_reciprocal_hides_last_seen_too', (case when v_last is null then 'null' else 'leaked' end), 'null');
end
$$;

-- CHECK4: bob still has show_online on -- but since bob queries from HIS side, does he see alice (alice turned hers off)? Should be hidden too (reciprocal is symmetric per-pair)
do $$
declare v_conv_id uuid; v_show boolean;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select show_online into v_show from public.get_conversation_partner_presence(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK4_bob_also_cannot_see_alice_since_alice_opted_out', v_show::text, 'false');
end
$$;

-- CHECK5: alice turns her own show_online back ON -- now she can see bob's presence again
do $$
declare v_conv_id uuid; v_show boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  update public.user_presence set show_online_status = true where user_id = '11111111-1111-1111-1111-111111111111';
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select show_online into v_show from public.get_conversation_partner_presence(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK5_turning_back_on_restores_visibility', v_show::text, 'true');
end
$$;

-- CHECK6: bob turns HIS OWN show_online off -- alice (who has hers on) should now see bob hidden too (reciprocal from the other direction)
do $$
declare v_conv_id uuid; v_show boolean;
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into public.user_presence (user_id, show_online_status) values ('22222222-2222-2222-2222-222222222222', false)
    on conflict (user_id) do update set show_online_status = false;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select show_online into v_show from public.get_conversation_partner_presence(v_conv_id);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK6_partner_opting_out_also_hides_from_me', v_show::text, 'false');
end
$$;

-- reset bob back to visible for remaining checks
do $$
begin
  update public.user_presence set show_online_status = true where user_id = '22222222-2222-2222-2222-222222222222';
end
$$;

-- CHECK7: CRITICAL BYPASS TEST -- can alice read bob's raw user_presence row directly via SELECT (bypassing the RPC's reciprocal check entirely)?
-- Alice has show_online back on, bob has show_online back on -- but this must still be blocked
-- via RLS regardless of toggle state, since the ONLY sanctioned read path is the RPC.
do $$
declare v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.user_presence where user_id = '22222222-2222-2222-2222-222222222222'::uuid;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK7_direct_table_read_of_others_presence_blocked_by_rls', v_count::text, '0');
end
$$;

-- CHECK8: a non-participant (carol) cannot call get_conversation_partner_presence for alice/bob's conversation
do $$
declare v_conv_id uuid; v_failed boolean := false;
begin
  select id into v_conv_id from public.conversations where user_a_id='11111111-1111-1111-1111-111111111111'::uuid or user_b_id='11111111-1111-1111-1111-111111111111'::uuid;
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.get_conversation_partner_presence(v_conv_id);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK8_non_participant_cannot_query_presence', v_failed::text, 'true');
end
$$;

-- CHECK9: no client UPDATE/INSERT policy lets one user write ANOTHER user's presence row (with_check enforces auth.uid() = user_id)
do $$
declare v_failed boolean := false;
begin
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.user_presence (user_id, show_online_status) values ('11111111-1111-1111-1111-111111111111', false);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK9_cannot_write_others_presence_row', v_failed::text, 'true');
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then echo "FAIL: could not create test database $DB_NAME" >&2; exit 1; fi
if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then echo "FAIL: stub setup failed" >&2; dropdb_any "$DB_NAME"; exit 1; fi
if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then echo "FAIL: schema.sql failed to load cleanly" >&2; dropdb_any "$DB_NAME"; exit 1; fi
echo "== Seeding fixtures and running RLS/RPC checks (WYN-133) =="
if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then echo "FAIL: seed/assert script errored" >&2; cat "$WORK_DIR/psql.out" >&2; dropdb_any "$DB_NAME"; exit 1; fi
cat "$WORK_DIR/psql.out"

FAILURES=0
while IFS='|' read -r name actual expected; do
  name="$(echo "$name" | xargs)"; actual="$(echo "$actual" | xargs)"; expected="$(echo "$expected" | xargs)"
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
if [ "$FAILURES" -gt 0 ]; then echo "FAIL: $FAILURES check(s) failed"; exit 1; fi
echo "ALL CHECKS PASSED"
