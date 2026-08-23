#!/usr/bin/env bash
# Regression test for WYN-036 (Draft System) -- proves the privacy
# guarantee ("Draft ต้องเป็น Private") actually works at the RLS layer,
# under the real `authenticated` role (not the Postgres superuser,
# which bypasses RLS entirely), mirroring wyn_035_poll_in_drop_test.sh's
# exact harness/role-switching convention.
#
#   1. A user can insert, update (in place, no duplicate row), and
#      delete their own draft.
#   2. Privacy: a different user's direct SELECT against
#      drop_drafts never returns another user's draft row -- not
#      filtered results, an outright absent row.
#   3. A different user cannot UPDATE or DELETE someone else's draft
#      (0-row no-op, enforced at the database layer).
#   4. A Restricted (posting-blocked) user can still create/update a
#      draft -- drafting privately is not "posting."
#   5. valid_draft_poll_options()/the table's own CHECK: rejects >4
#      options and an over-length (>80 char) option, but -- unlike
#      drop_polls' stricter valid_poll_options() -- accepts a single
#      duplicate-heavy or partially-empty set (a Draft is allowed to
#      be incomplete).
#   6. Deleting the author's profile cascades away their drafts.
#   7. Regression: a plain image-based Drop and a Poll Drop
#      (create_poll_drop()) still work unaffected.
#
# Requirements: a local PostgreSQL 16 server reachable either as the
# current OS user or via `sudo -u postgres` (mirrors
# wyn_035_poll_in_drop_test.sh's harness).
#
# Usage:
#   bash supabase/tests/wyn_036_draft_system_test.sh
#
# Exit code 0 and "ALL CHECKS PASSED" on success, non-zero and a
# failure message otherwise. Never touches any real/dev/prod database
# -- creates and drops its own throwaway database.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn036_draft_system_regression_test"
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

-- alice: owns a draft (image-only, no poll). bob: a stranger who
-- tries to read/update/delete alice's draft directly. erin: gets
-- Restricted, to prove drafting still works while posting-blocked.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'bob@test.com'),
  ('55555555-5555-5555-5555-555555555555', 'erin@test.com');

insert into public.profiles (id, username, display_name, platform_role) values
  ('11111111-1111-1111-1111-111111111111', 'alice', 'Alice', 'user'),
  ('22222222-2222-2222-2222-222222222222', 'bob', 'Bob', 'user'),
  ('55555555-5555-5555-5555-555555555555', 'erin', 'Erin', 'user');

-- Fixture: erin gets an active Restrict (direct table-owner inserts,
-- bypassing RLS -- same fixture shape as wyn_034/wyn_035's own).
insert into public.reports (id, reporter_id, target_type, target_id, category, status) values
  ('30000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'user', '55555555-5555-5555-5555-555555555555', 'spam', 'actioned');
insert into public.moderation_actions (id, report_id, target_user_id, reviewer_id, action_type, reason, duration_days, expires_at) values
  ('a0000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'restrict', 'spam fixture', 3, now() + interval '3 days');

-- ------------------------------------------------------------
-- CHECK 1-3: insert, update-in-place (no duplicate), delete of your
-- own draft.
-- ------------------------------------------------------------
do $$
declare
  v_draft_id uuid;
begin
  -- CHECK1: alice creates an image-only draft.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_drafts (author_id, image_url, caption)
  values ('11111111-1111-1111-1111-111111111111', 'https://example.com/draft.jpg', 'ยังคิดแคปชันไม่ออก')
  returning id into v_draft_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  perform set_config('wyn036.draft1', v_draft_id::text, false);

  insert into results
  select 'CHECK1_draft_created', count(*), 1
  from public.drop_drafts where id = v_draft_id and author_id = '11111111-1111-1111-1111-111111111111';

  -- CHECK2: alice updates the SAME draft (caption change) -- still
  -- exactly one row, updated_at moved forward.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  update public.drop_drafts set caption = 'คิดออกแล้ว!', updated_at = now() + interval '1 minute'
  where id = v_draft_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK2_draft_updated_single_row',
    (select count(*) from public.drop_drafts where author_id = '11111111-1111-1111-1111-111111111111'), 1;
  insert into results
  select 'CHECK2b_draft_caption_reflects_update', count(*), 1
  from public.drop_drafts where id = v_draft_id and caption = 'คิดออกแล้ว!';
end
$$;

-- ------------------------------------------------------------
-- CHECK 3-4: bob (a stranger) cannot read, update, or delete alice's
-- draft.
-- ------------------------------------------------------------
do $$
declare
  v_draft1 uuid := current_setting('wyn036.draft1')::uuid;
begin
  -- CHECK3: bob's own SELECT against drop_drafts never returns
  -- alice's row -- outright absent, not merely filtered.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  insert into results
  select 'CHECK3_stranger_cannot_see_draft',
    (select count(*) from public.drop_drafts where id = v_draft1), 0;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  -- CHECK4: bob's UPDATE attempt against alice's draft is a silent
  -- 0-row no-op (RLS, not a client-side check being the only guard).
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  update public.drop_drafts set caption = 'แอบแก้ของคนอื่น' where id = v_draft1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK4_stranger_update_is_noop', count(*), 0
  from public.drop_drafts where id = v_draft1 and caption = 'แอบแก้ของคนอื่น';

  -- CHECK5: same for DELETE -- bob's delete is a silent 0-row no-op,
  -- alice's draft still exists afterward.
  set role authenticated;
  set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
  set request.jwt.claim.role = 'authenticated';
  delete from public.drop_drafts where id = v_draft1;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK5_stranger_delete_is_noop', count(*), 1
  from public.drop_drafts where id = v_draft1;
end
$$;

-- ------------------------------------------------------------
-- CHECK 6: a Restricted (posting-blocked) user can still create a
-- draft -- drafting privately is not "posting."
-- ------------------------------------------------------------
do $$
begin
  set role authenticated;
  set request.jwt.claim.sub = '55555555-5555-5555-5555-555555555555';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drop_drafts (author_id, caption)
  values ('55555555-5555-5555-5555-555555555555', 'erin ร่างของฉัน');
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK6_restricted_user_can_still_draft', count(*), 1
  from public.drop_drafts where author_id = '55555555-5555-5555-5555-555555555555';
end
$$;

-- ------------------------------------------------------------
-- CHECK 7-9: valid_draft_poll_options()/the table CHECK -- looser
-- than drop_polls' own, on purpose.
-- ------------------------------------------------------------
do $$
begin
  insert into results values (
    'CHECK7_rejects_too_many_options',
    case when public.valid_draft_poll_options(array['a', 'b', 'c', 'd', 'e']) then 1 else 0 end,
    0
  );
  insert into results values (
    'CHECK8_rejects_over_length_option',
    case when public.valid_draft_poll_options(array['ok', repeat('x', 81)]) then 1 else 0 end,
    0
  );
  -- CHECK9: unlike drop_polls' strict valid_poll_options(), a Draft
  -- is allowed to have duplicate/still-empty option text -- it's
  -- explicitly permitted to be unfinished.
  insert into results values (
    'CHECK9_accepts_incomplete_duplicate_options',
    case when public.valid_draft_poll_options(array['', '']) then 1 else 0 end,
    1
  );

  -- Live-database version of the same rule via the table's own CHECK.
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  begin
    insert into public.drop_drafts (author_id, poll_options)
    values ('11111111-1111-1111-1111-111111111111', array['a', 'b', 'c', 'd', 'e']);
    insert into results values ('CHECK10_table_rejects_too_many_poll_options', 0, 1);
  exception when others then
    insert into results values ('CHECK10_table_rejects_too_many_poll_options', 1, 1);
  end;

  -- A genuinely incomplete poll draft (1 filled + 1 blank option)
  -- still saves successfully.
  insert into public.drop_drafts (author_id, caption, poll_options, poll_duration_days)
  values ('11111111-1111-1111-1111-111111111111', 'จะกินอะไรดี', array['พิซซ่า', ''], 3);
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;
  insert into results
  select 'CHECK11_incomplete_poll_draft_saves', count(*), 1
  from public.drop_drafts
  where author_id = '11111111-1111-1111-1111-111111111111' and poll_options = array['พิซซ่า', ''];
end
$$;

-- ------------------------------------------------------------
-- CHECK 12: deleting the author's profile cascades away their
-- drafts.
-- ------------------------------------------------------------
do $$
begin
  delete from public.profiles where id = '55555555-5555-5555-5555-555555555555';
  insert into results
  select 'CHECK12_profile_delete_cascades_drafts', count(*), 0
  from public.drop_drafts where author_id = '55555555-5555-5555-5555-555555555555';
end
$$;

-- ------------------------------------------------------------
-- CHECK 13-14: regression -- a plain image Drop and a Poll Drop
-- (create_poll_drop(), WYN-035) still work, completely unaffected by
-- drop_drafts existing alongside them.
-- ------------------------------------------------------------
do $$
declare
  v_poll_drop_id uuid;
begin
  set role authenticated;
  set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
  set request.jwt.claim.role = 'authenticated';
  insert into public.drops (author_id, image_url, caption)
  values ('11111111-1111-1111-1111-111111111111', 'https://example.com/real-drop.jpg', 'ของจริง');
  select public.create_poll_drop('กินอะไรดี?', array['พิซซ่า', 'ซูชิ'], 1, '{}') into v_poll_drop_id;
  reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

  insert into results
  select 'CHECK13_plain_drop_still_works', count(*), 1
  from public.drops where author_id = '11111111-1111-1111-1111-111111111111' and image_url = 'https://example.com/real-drop.jpg';
  insert into results
  select 'CHECK14_poll_drop_still_works', count(*), 1
  from public.drops where id = v_poll_drop_id and image_url is null;
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

echo "== Seeding fixtures and running RLS checks =="
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
