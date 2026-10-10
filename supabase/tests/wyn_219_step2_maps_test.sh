#!/usr/bin/env bash
# WYN-219 Phase 2 step 2 (Maps): supabase/migrations/20261010160000_wyn219_step2_maps_permissions.sql
#
#   1. The four Maps read RPCs pass for the super admin, maps:view and
#      maps:edit, and refuse other platform admins, moderators (social only)
#      and users.
#   2. The five Maps write RPCs pass only for the super admin and maps:edit;
#      maps:view is refused.
#   3. place-photos storage policies: owners keep their own files; maps:view
#      reads everyone's, maps:edit deletes; others see only their own.
#   4. No Maps function or policy still reads profiles.platform_role.
#   5. The migration is idempotent and the rollback restores the role checks.
#
# "Pass" means the role check let the call through (it may then fail on a
# missing Maps table, which this test does not load); "refused" means the
# function raised its own authorization error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
FOUNDATION_FILE="$SCRIPT_DIR/../migrations/20261010150000_wyn219_admin_permissions_foundation.sql"
MIGRATION_FILE="$SCRIPT_DIR/../migrations/20261010160000_wyn219_step2_maps_permissions.sql"
ROLLBACK_FILE="$SCRIPT_DIR/../rollbacks/20261010160000_wyn219_step2_maps_permissions_rollback.sql"
DB_NAME="wyn_219_step2_maps_test"
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
grant select, insert, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
EOF

cat > "$WORK_DIR/05_pre.sql" <<'EOF'
\set ON_ERROR_STOP on
-- %rowtype targets used by the Maps RPCs; the Maps tables themselves are out of scope.
create table if not exists public.wynos_places (id text primary key);
create table if not exists public.wynos_place_suggestions (id uuid primary key);
-- The production place-photo approval helper; approval itself is out of scope.
create or replace function internal.wynos_place_photo_is_approved(p_path text)
returns boolean language sql stable as $$ select false $$;
grant execute on function internal.wynos_place_photo_is_approved(text) to authenticated;
insert into storage.buckets (id, name) values ('place-photos', 'place-photos');
-- Pre-existing policies the migration replaces (production shape).
create policy "Place photos readable when approved" on storage.objects for select to authenticated
  using (bucket_id = 'place-photos' and ((storage.foldername(name))[1] = (auth.uid())::text
    or coalesce(internal.current_platform_role(), '') = any (array['admin', 'moderator'])
    or internal.wynos_place_photo_is_approved(name)));
create policy "Place photos delete own or admin" on storage.objects for delete to authenticated
  using (bucket_id = 'place-photos' and ((storage.foldername(name))[1] = (auth.uid())::text
    or coalesce(internal.current_platform_role(), '') = 'admin'));

insert into auth.users (id, email) values
  ('92190000-0000-0000-0000-000000000001', 'sa@test.invalid'),
  ('92190000-0000-0000-0000-000000000002', 'adm@test.invalid'),
  ('92190000-0000-0000-0000-000000000003', 'mod@test.invalid'),
  ('92190000-0000-0000-0000-000000000004', 'usr@test.invalid'),
  ('92190000-0000-0000-0000-000000000005', 'mv@test.invalid'),
  ('92190000-0000-0000-0000-000000000006', 'me@test.invalid');
insert into public.profiles (id, username, display_name, platform_role, is_private) values
  ('92190000-0000-0000-0000-000000000001', 'm_sa', 'sa', 'admin', false),
  ('92190000-0000-0000-0000-000000000002', 'm_adm', 'adm', 'admin', false),
  ('92190000-0000-0000-0000-000000000003', 'm_mod', 'mod', 'moderator', false),
  ('92190000-0000-0000-0000-000000000004', 'm_usr', 'usr', 'user', false),
  ('92190000-0000-0000-0000-000000000005', 'm_mv', 'mv', 'user', false),
  ('92190000-0000-0000-0000-000000000006', 'm_me', 'me', 'user', false);
EOF

cat > "$WORK_DIR/07_grants.sql" <<'EOF'
\set ON_ERROR_STOP on
insert into internal.platform_super_admins (user_id) values ('92190000-0000-0000-0000-000000000001');
insert into public.admin_permissions (user_id, system, level) values
  ('92190000-0000-0000-0000-000000000005', 'maps', 'view'),
  ('92190000-0000-0000-0000-000000000006', 'maps', 'edit');
insert into storage.objects (bucket_id, name) values
  ('place-photos', '92190000-0000-0000-0000-000000000004/a.jpg'),
  ('place-photos', '92190000-0000-0000-0000-000000000004/b.jpg'),
  ('place-photos', '92190000-0000-0000-0000-000000000003/c.jpg');
EOF

cat > "$WORK_DIR/10_assert.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
create table results (check_name text primary key, actual int, expected int);
grant all on results to authenticated;

-- 1 = the role check let the call through, 0 = refused with the function's own auth error.
create or replace function pg_temp.passes(p_user uuid, p_sql text) returns int
language plpgsql as $$
declare msg text;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
  begin
    execute p_sql;
  exception when others then
    msg := sqlerrm;
    perform set_config('role', 'postgres', true);
    if msg in ('Not authorized', 'Only admins can manage WYNOS Places', 'Only admins can import WYNOS Places',
               'Only admins can review place photos', 'Only admins can review WYNOS Place suggestions') then
      return 0;
    end if;
    return 1;
  end;
  perform set_config('role', 'postgres', true);
  return 1;
end;
$$;

create temp table calls (fn text, kind text, sql text);
insert into calls values
  ('places', 'read', 'select public.admin_wynos_places(null::text, null::text, null::text, 10)'),
  ('place_for_store', 'read', 'select public.admin_wynos_place_for_store(gen_random_uuid())'),
  ('place_photos', 'read', 'select public.admin_wynos_place_photos(null::text, 10)'),
  ('place_suggestions', 'read', 'select public.admin_wynos_place_suggestions(null::text, 10)'),
  ('upsert_place', 'write', 'select public.admin_upsert_wynos_place(null::text, ''x'', null::text, ''place'', null::text, null::text, 16.0::float8, 103.0::float8, null::float8, null::float8, ''manual'', null::text, ''unverified'', true)'),
  ('set_place_active', 'write', 'select public.admin_set_wynos_place_active(''x'', false)'),
  ('import_places', 'write', 'select public.admin_import_wynos_places(''[]''::jsonb)'),
  ('review_photo', 'write', 'select public.admin_review_wynos_place_photo(gen_random_uuid(), ''approved'')'),
  ('review_suggestion', 'write', 'select public.admin_review_wynos_place_suggestion(gen_random_uuid(), ''approved'')');
grant select on calls to authenticated;

create temp table who (label text, id uuid, read_ok int, write_ok int);
insert into who values
  ('super_admin', '92190000-0000-0000-0000-000000000001', 1, 1),
  ('platform_admin', '92190000-0000-0000-0000-000000000002', 0, 0),
  ('moderator', '92190000-0000-0000-0000-000000000003', 0, 0),
  ('user', '92190000-0000-0000-0000-000000000004', 0, 0),
  ('maps_view', '92190000-0000-0000-0000-000000000005', 1, 0),
  ('maps_edit', '92190000-0000-0000-0000-000000000006', 1, 1);

do $$
declare c record; w record;
begin
  for w in select * from who loop
    for c in select * from calls loop
      insert into results values (
        format('CHECK1_%s_%s', w.label, c.fn),
        pg_temp.passes(w.id, c.sql),
        case when c.kind = 'read' then w.read_ok else w.write_ok end);
    end loop;
  end loop;
end
$$;

-- CHECK 3: storage policies.
create or replace function pg_temp.seen(p_user uuid) returns int language plpgsql as $$
declare n int;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
  select count(*) into n from storage.objects where bucket_id = 'place-photos';
  perform set_config('role', 'postgres', true);
  return n;
end $$;
create or replace function pg_temp.deleted(p_user uuid, p_name text) returns int language plpgsql as $$
declare n int;
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('role', 'authenticated', true);
  with d as (delete from storage.objects where bucket_id = 'place-photos' and name = p_name returning 1) select count(*) into n from d;
  perform set_config('role', 'postgres', true);
  return n;
end $$;

insert into results values
  ('CHECK3a_owner_sees_own', pg_temp.seen('92190000-0000-0000-0000-000000000004'), 2),
  ('CHECK3b_platform_admin_sees_none', pg_temp.seen('92190000-0000-0000-0000-000000000002'), 0),
  ('CHECK3c_moderator_sees_own_only', pg_temp.seen('92190000-0000-0000-0000-000000000003'), 1),
  ('CHECK3d_maps_view_sees_all', pg_temp.seen('92190000-0000-0000-0000-000000000005'), 3),
  ('CHECK3e_super_admin_sees_all', pg_temp.seen('92190000-0000-0000-0000-000000000001'), 3),
  ('CHECK3f_maps_view_cannot_delete', pg_temp.deleted('92190000-0000-0000-0000-000000000005', '92190000-0000-0000-0000-000000000004/a.jpg'), 0),
  ('CHECK3g_platform_admin_cannot_delete', pg_temp.deleted('92190000-0000-0000-0000-000000000002', '92190000-0000-0000-0000-000000000004/a.jpg'), 0),
  ('CHECK3h_maps_edit_deletes', pg_temp.deleted('92190000-0000-0000-0000-000000000006', '92190000-0000-0000-0000-000000000004/a.jpg'), 1),
  ('CHECK3i_owner_deletes_own', pg_temp.deleted('92190000-0000-0000-0000-000000000004', '92190000-0000-0000-0000-000000000004/b.jpg'), 1);

-- CHECK 4: nothing in Maps reads platform_role any more.
insert into results
select 'CHECK4a_no_maps_function_reads_platform_role', count(*), 0
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'admin_%wynos_place%' and p.prosrc like '%platform_role%';
insert into results
select 'CHECK4b_no_place_photo_policy_reads_platform_role', count(*), 0
from pg_policies where policyname like 'Place photos%' and coalesce(qual, '') || coalesce(with_check, '') like '%platform_role%';

select check_name, actual, expected from results order by check_name;
EOF

cat > "$WORK_DIR/20_after_rollback.sql" <<'EOF'
\pset pager off
\set ON_ERROR_STOP on
select 'CHECK5a_rollback_restores_role_checks' as check_name, count(*) as actual, 9 as expected
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'admin_%wynos_place%' and p.prosrc like '%current_platform_role%'
union all
select 'CHECK5b_rollback_restores_policies', count(*), 2
from pg_policies where policyname like 'Place photos%' and qual like '%current_platform_role%';
EOF

dropdb_any "$DB_NAME"
if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create test database $DB_NAME (need local Postgres access)" >&2
  exit 1
fi

for step in "$WORK_DIR/00_stub.sql" "$SCHEMA_FILE" "$WORK_DIR/05_pre.sql" "$FOUNDATION_FILE" "$WORK_DIR/07_grants.sql" "$MIGRATION_FILE" "$MIGRATION_FILE" "$WORK_DIR/10_assert.sql"; do
  if ! run_psql "$DB_NAME" "$step"; then
    echo "FAIL: $step errored" >&2
    dropdb_any "$DB_NAME"
    exit 1
  fi
done
cp "$WORK_DIR/psql.out" "$WORK_DIR/assert.out"
for step in "$ROLLBACK_FILE" "$WORK_DIR/20_after_rollback.sql"; do
  if ! run_psql "$DB_NAME" "$step"; then
    echo "FAIL: $step errored" >&2
    dropdb_any "$DB_NAME"
    exit 1
  fi
done
cat "$WORK_DIR/psql.out" >> "$WORK_DIR/assert.out"
mv "$WORK_DIR/assert.out" "$WORK_DIR/psql.out"
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
