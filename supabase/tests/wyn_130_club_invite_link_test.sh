#!/usr/bin/env bash
# QA regression test for WYN-130 (Club Invite Link) -- written
# independently by AI QA & Security (not by AI Coding) to verify the
# RPC/RLS layer directly, mirroring wyn_134_dm_new_message_notification_test.sh's
# harness/role-switching convention. Covers:
#   1. create/revoke restricted to Owner/Admin (member and non-member both
#      rejected calling the RPC directly, not just UI-hidden).
#   2. redeem_club_invite_link(): Founder-locked "Choice A" -- a valid
#      link joins a Private Club immediately, no Join Request/Approve,
#      and upgrades a pre-existing stale 'pending' row to 'approved'.
#   3. Race condition on max-uses: two concurrent redeems of a
#      max_uses=1 link -- exactly one succeeds, use_count never exceeds
#      max_uses (proves the `for update` row lock actually serializes).
#   4. Revoked/expired/exhausted links can never be redeemed again, and
#      preview_club_invite_link() reports the right status for each.
#   5. A banned member cannot redeem a link into that club.
#   6. RLS: a non-owner/admin member cannot list a club's invite links.
#   7. Public Club baseline (redeem still joins approved).
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres`.
#
# Usage: bash supabase/tests/wyn_130_club_invite_link_test.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn130_qa_test"
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
psql_any_capture() {
  local db="$1"; shift
  local out
  out="$(psql -d "$db" "$@" 2>/dev/null)" && [ -n "$out" ] && { printf '%s' "$out"; return 0; }
  sudo -u postgres psql -d "$db" "$@" 2>/dev/null
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

cat > "$WORK_DIR/10_seed.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
create table results (check_name text primary key, actual text, expected text);

-- owner (alice), regular member (bob, already approved), non-member (carol), banned member (dave)
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('33333333-3333-3333-3333-333333333333', 'carol@test.com'),
  ('44444444-4444-4444-4444-444444444444', 'dave@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'erin@test.com'),
  ('66666666-6666-6666-6666-666666666666', 'frank@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('33333333-3333-3333-3333-333333333333', 'carol', 'Carol', 'user'),
  ('44444444-4444-4444-4444-444444444444', 'dave', 'Dave', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'erin', 'Erin', 'user'),
  ('66666666-6666-6666-6666-666666666666', 'frank', 'Frank', 'user');

-- Private club owned by alice
do $$
declare v_club_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.clubs (name, privacy, owner_id) values ('Private Test Club', 'private', '11111111-1111-1111-1111-111111111111') returning id into v_club_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  -- bob is already an approved regular member
  insert into public.club_members (club_id, user_id, role, status) values (v_club_id, '22222222-2222-2222-2222-222222222222', 'member', 'approved');
  -- dave is banned
  insert into public.club_members (club_id, user_id, role, status) values (v_club_id, '44444444-4444-4444-4444-444444444444', 'member', 'banned');
  -- erin has a stale pending join request from before this feature existed
  insert into public.club_members (club_id, user_id, role, status) values (v_club_id, '55555555-5555-5555-5555-555555555555', 'member', 'pending');
end
$$;

EOF

cat > "$WORK_DIR/20_checks.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on

-- CHECK1: a regular member (bob, not owner/admin) CANNOT create an invite link
do $$
declare v_club_id uuid; v_failed boolean := false;
begin
  select id into v_club_id from public.clubs where name = 'Private Test Club';
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_club_invite_link(v_club_id, null, null);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK1_regular_member_cannot_create_link', v_failed::text, 'true');
end
$$;

-- CHECK2: a non-member (carol) CANNOT create an invite link
do $$
declare v_club_id uuid; v_failed boolean := false;
begin
  select id into v_club_id from public.clubs where name = 'Private Test Club';
  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.create_club_invite_link(v_club_id, null, null);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK2_non_member_cannot_create_link', v_failed::text, 'true');
end
$$;

-- CHECK3: owner (alice) CAN create an invite link with expiry + max_uses
do $$
declare v_club_id uuid; v_code text;
begin
  select id into v_club_id from public.clubs where name = 'Private Test Club';
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select code into v_code from public.create_club_invite_link(v_club_id, 7, 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK3_owner_can_create_link', (case when v_code is not null then 'created' else 'failed' end), 'created');
end
$$;

-- CHECK4: a regular member CANNOT revoke someone else's link (only owner/admin)
do $$
declare v_link_id uuid; v_failed boolean := false;
begin
  select id into v_link_id from public.club_invite_links where max_uses = 1;
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.revoke_club_invite_link(v_link_id);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK4_regular_member_cannot_revoke_link', v_failed::text, 'true');
end
$$;

-- CHECK5: dave is banned -- CANNOT redeem the max_uses=1 link even though it's still valid
do $$
declare v_code text; v_failed boolean := false;
begin
  select code into v_code from public.club_invite_links where max_uses = 1;
  set role authenticated;
  set request.jwt.claim.sub = '44444444-4444-4444-4444-444444444444';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.redeem_club_invite_link(v_code);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK5_banned_member_cannot_redeem', v_failed::text, 'true');
end
$$;

-- CHECK6: erin (stale pending join request) redeems the link -- gets upgraded to approved immediately (Choice A), even for a Private Club, no Join Request wait
do $$
declare v_code text; v_status text; v_result uuid;
begin
  select code into v_code from public.club_invite_links where max_uses = 1;
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  select public.redeem_club_invite_link(v_code) into v_result;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status into v_status from public.club_members
  where user_id = '55555555-5555-5555-5555-555555555555'::uuid and club_id = (select id from public.clubs where name = 'Private Test Club');
  insert into results values ('CHECK6a_redeem_returns_club_id', (case when v_result is not null then 'returned' else 'null' end), 'returned');
  insert into results values ('CHECK6b_stale_pending_upgraded_to_approved_immediately', v_status, 'approved');
end
$$;

-- CHECK7: the link had max_uses=1 and is now used up -- a brand new user (frank) CANNOT redeem it (exhausted)
do $$
declare v_code text; v_failed boolean := false;
begin
  select code into v_code from public.club_invite_links where max_uses = 1;
  set role authenticated;
  set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.redeem_club_invite_link(v_code);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK7_exhausted_link_cannot_be_reused', v_failed::text, 'true');
end
$$;

-- CHECK8: preview shows 'exhausted' status for this used-up link
do $$
declare v_code text; v_status text;
begin
  select code into v_code from public.club_invite_links where max_uses = 1;
  select status into v_status from public.preview_club_invite_link(v_code);
  insert into results values ('CHECK8_preview_shows_exhausted', v_status, 'exhausted');
end
$$;

-- CHECK9: revoked link cannot be redeemed
do $$
declare v_club_id uuid; v_code text; v_failed boolean := false; v_status text;
begin
  select id into v_club_id from public.clubs where name = 'Private Test Club';
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  select code into v_code from public.create_club_invite_link(v_club_id, null, null);
  perform public.revoke_club_invite_link((select id from public.club_invite_links where code = v_code));
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.redeem_club_invite_link(v_code);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status into v_status from public.preview_club_invite_link(v_code);
  insert into results values ('CHECK9a_revoked_link_cannot_be_redeemed', v_failed::text, 'true');
  insert into results values ('CHECK9b_preview_shows_revoked', v_status, 'revoked');
end
$$;

-- CHECK9c: revoking the same link twice fails the second time (already revoked)
do $$
declare v_link_id uuid; v_failed boolean := false;
begin
  select id into v_link_id from public.club_invite_links where revoked_at is not null limit 1;
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.revoke_club_invite_link(v_link_id);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK9c_double_revoke_fails', v_failed::text, 'true');
end
$$;

-- CHECK10: expired link cannot be redeemed (create with expires_at in the past directly, bypassing the RPC's day-offset param since we need a past date)
do $$
declare v_club_id uuid; v_code text; v_failed boolean := false; v_status text;
begin
  select id into v_club_id from public.clubs where name = 'Private Test Club';
  v_code := 'expiredcode1';
  insert into public.club_invite_links (club_id, code, created_by, expires_at, max_uses)
  values (v_club_id, v_code, '11111111-1111-1111-1111-111111111111', now() - interval '1 day', null);

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  begin
    perform public.redeem_club_invite_link(v_code);
  exception when others then
    v_failed := true;
  end;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status into v_status from public.preview_club_invite_link(v_code);
  insert into results values ('CHECK10a_expired_link_cannot_be_redeemed', v_failed::text, 'true');
  insert into results values ('CHECK10b_preview_shows_expired', v_status, 'expired');
end
$$;

-- CHECK11: preview for a totally bogus/nonexistent code returns 'not_found' (not an error, not an empty crash)
--
-- KNOWN BUG (found by AI QA & Security, 2026-09-07, see
-- .wyn/docs/qa/2026-09-07-wyn-130-132-133-134-phase-a-qa.md): this
-- currently FAILS once `club_invite_links` has at least one row
-- ANYWHERE in the database (true in production after the first-ever
-- link is created) -- the RPC's `right join (select p_code as code)
-- req on true` trick only produces the intended zero-match fallback
-- row when the table is completely empty; once any row exists, every
-- row "matches" the `on true` clause, so a genuinely non-matching code
-- returns 0 rows instead of a `status = 'not_found'` row. This is NOT
-- user-visible today: `ClubRepository.previewInviteLink()` already
-- treats an empty RPC result as `ClubInviteLinkStatus.notFound`
-- (`app/lib/features/club/data/club_repository.dart`), so real users
-- still see the friendly "ไม่พบลิงก์เชิญนี้" message -- but the RPC
-- itself violates its own documented return contract, so any other
-- caller (a future admin tool, a direct RPC integration test, etc.)
-- that assumes at least one row is always returned would break.
-- Recommended fix: replace the `right join ... on true` trick with an
-- explicit `union all` fallback (e.g. `select ... from
-- club_invite_links where code = p_code union all select 'not_found',
-- null, null, null, null where not exists (select 1 from
-- club_invite_links where code = p_code) limit 1`) so a row is
-- returned unconditionally regardless of table contents.
do $$
declare v_status text; v_row_count int;
begin
  select count(*) into v_row_count from public.preview_club_invite_link('doesnotexist99');
  select status into v_status from public.preview_club_invite_link('doesnotexist99');
  insert into results values ('CHECK11a_bogus_code_preview_row_count', v_row_count::text, '1');
  insert into results values ('CHECK11b_bogus_code_status_not_found', coalesce(v_status, 'NULL_OR_NO_ROW'), 'not_found');
end
$$;

-- CHECK12: RLS -- a regular member (bob) cannot SELECT another club's invite links list (only owner/admin can view)
do $$
declare v_count int;
begin
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  select count(*) into v_count from public.club_invite_links;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results values ('CHECK12_regular_member_cannot_list_invite_links', v_count::text, '0');
end
$$;

-- CHECK13: public club -- invite link redeem also joins immediately as approved (baseline, should already work same as before WYN-130 via normal join, but verify link path too)
do $$
declare v_club_id uuid; v_code text; v_status text;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.clubs (name, privacy, owner_id) values ('Public Test Club', 'public', '11111111-1111-1111-1111-111111111111') returning id into v_club_id;
  select code into v_code from public.create_club_invite_link(v_club_id, null, null);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  set role authenticated;
  set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
  set request.jwt.claim.role = 'authenticated';
  perform public.redeem_club_invite_link(v_code);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  select status into v_status from public.club_members where club_id = v_club_id and user_id = '33333333-3333-3333-3333-333333333333'::uuid;
  insert into results values ('CHECK13_public_club_link_joins_approved', v_status, 'approved');
end
$$;

select check_name, actual, expected from results order by check_name;
EOF

if ! createdb_any "$DB_NAME"; then echo "FAIL: could not create test database $DB_NAME" >&2; exit 1; fi
if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then echo "FAIL: stub setup failed" >&2; dropdb_any "$DB_NAME"; exit 1; fi
if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then echo "FAIL: schema.sql failed to load cleanly" >&2; dropdb_any "$DB_NAME"; exit 1; fi
echo "== Seeding fixtures (WYN-130) =="
if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed.sql"; then echo "FAIL: seed script errored" >&2; cat "$WORK_DIR/psql.out" >&2; dropdb_any "$DB_NAME"; exit 1; fi

echo "== Race-condition test: two users redeem a max_uses=1 link concurrently =="
# Create a fresh max_uses=1 link owned by alice's Private Test Club for the race test.
cat > "$WORK_DIR/race_setup.sql" <<'EOF'
\set ON_ERROR_STOP on
do $$
declare v_club_id uuid;
begin
  select id into v_club_id from public.clubs where name = 'Private Test Club';
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  perform public.create_club_invite_link(v_club_id, null, 1);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
end
$$;
EOF
run_psql "$DB_NAME" "$WORK_DIR/race_setup.sql" || { echo "FAIL: race setup"; dropdb_any "$DB_NAME"; exit 1; }
RACE_CODE="$(psql_any_capture "$DB_NAME" -tAc "select code from public.club_invite_links order by created_at desc limit 1;" | xargs)"
echo "RACE_CODE=[$RACE_CODE]"

# Session A: acquires the row lock, sleeps 2s while holding it (simulating
# in-flight work between lock-acquire and commit), then performs the real
# redeem (already holding the lock in the same tx) and commits.
cat > "$WORK_DIR/race_a.sql" <<EOF
\\set ON_ERROR_STOP on
begin;
set role authenticated;
set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
set request.jwt.claim.role = 'authenticated';
select id from public.club_invite_links where code = '$RACE_CODE' for update;
select pg_sleep(2);
select public.redeem_club_invite_link('$RACE_CODE');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
commit;
EOF

# Session B: starts ~0.5s later, tries to redeem the same link -- must
# block on the FOR UPDATE lock inside redeem_club_invite_link() itself
# until Session A commits, then correctly see max_uses reached and fail.
cat > "$WORK_DIR/race_b.sql" <<EOF
\\set ON_ERROR_STOP on
begin;
set role authenticated;
set request.jwt.claim.sub = '66666666-6666-6666-6666-666666666666';
set request.jwt.claim.role = 'authenticated';
select public.redeem_club_invite_link('$RACE_CODE');
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
commit;
EOF

(psql -d "$DB_NAME" -f "$WORK_DIR/race_a.sql" >"$WORK_DIR/race_a.out" 2>&1 || sudo -u postgres psql -d "$DB_NAME" -f "$WORK_DIR/race_a.sql" >"$WORK_DIR/race_a.out" 2>&1) &
PID_A=$!
sleep 0.5
(psql -d "$DB_NAME" -f "$WORK_DIR/race_b.sql" >"$WORK_DIR/race_b.out" 2>&1 || sudo -u postgres psql -d "$DB_NAME" -f "$WORK_DIR/race_b.sql" >"$WORK_DIR/race_b.out" 2>&1) &
PID_B=$!
set +e
wait "$PID_A"
wait "$PID_B"
set -e

echo "--- Session A (erin) output ---"
cat "$WORK_DIR/race_a.out"
echo "--- Session B (frank) output ---"
cat "$WORK_DIR/race_b.out"

A_OK=0; B_OK=0
grep -q "ERROR" "$WORK_DIR/race_a.out" || A_OK=1
grep -q "ERROR" "$WORK_DIR/race_b.out" || B_OK=1
FINAL_USE_COUNT="$(psql_any_capture "$DB_NAME" -tAc "select use_count from public.club_invite_links where code = '$RACE_CODE';" | xargs)"

echo ""
echo "RACE_A_SUCCEEDED=$A_OK RACE_B_SUCCEEDED=$B_OK FINAL_USE_COUNT=$FINAL_USE_COUNT (max_uses=1)"

RACE_FAIL=0
EXACTLY_ONE_SUCCEEDED=$((A_OK + B_OK))
if [ "$EXACTLY_ONE_SUCCEEDED" != "1" ]; then
  echo "FAIL: RACE CONDITION -- expected exactly one of the two concurrent redeems to succeed, got $EXACTLY_ONE_SUCCEEDED successes"
  RACE_FAIL=1
fi
if [ "$FINAL_USE_COUNT" != "1" ]; then
  echo "FAIL: RACE CONDITION -- use_count should be exactly 1 (max_uses cap), got $FINAL_USE_COUNT"
  RACE_FAIL=1
fi
if [ "$RACE_FAIL" = "0" ]; then
  echo "PASS: race condition on max-uses correctly serialized by FOR UPDATE (exactly 1 success, use_count=1)"
fi

echo "== Cleaning up race-test link so it doesn't collide with sequential checks =="
psql_any_capture "$DB_NAME" -c "delete from public.club_invite_link_uses where link_id = (select id from public.club_invite_links where code = '$RACE_CODE'); delete from public.club_members where user_id = '66666666-6666-6666-6666-666666666666'; delete from public.club_invite_links where code = '$RACE_CODE';" >/dev/null

echo "== Sequential RLS/RPC checks (WYN-130) =="
if ! run_psql "$DB_NAME" "$WORK_DIR/20_checks.sql"; then echo "FAIL: checks script errored" >&2; cat "$WORK_DIR/psql.out" >&2; dropdb_any "$DB_NAME"; exit 1; fi
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
if [ "$FAILURES" -gt 0 ] || [ "$RACE_FAIL" != "0" ]; then
  echo "FAIL: $FAILURES sequential check(s) failed, race_fail=$RACE_FAIL"
  exit 1
fi
echo "ALL CHECKS PASSED (including race-condition test)"
