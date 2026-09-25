#!/usr/bin/env bash
# WYN-191: isolated Postgres proof that Plus has read-own-only RLS.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_NAME="wyn191_plus_memberships_test"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
chmod 755 "$WORK_DIR"

psql_file() {
  local db="$1" file="$2"
  psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >/dev/null 2>&1 \
    || sudo -u postgres psql -d "$db" -v ON_ERROR_STOP=1 -f "$file" >/dev/null
}
createdb_any() {
  createdb "$1" >/dev/null 2>&1 || sudo -u postgres createdb "$1" >/dev/null
}
dropdb_any() {
  dropdb --if-exists "$1" >/dev/null 2>&1 \
    || sudo -u postgres dropdb --if-exists "$1" >/dev/null 2>&1 || true
}

cat > "$WORK_DIR/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table if not exists auth.users (
 id uuid primary key default gen_random_uuid(), email text
);
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
 select nullif(current_setting('request.jwt.claim.role',true),'')
$$;
create schema if not exists storage;
create table if not exists storage.buckets (
 id text primary key,name text not null,public boolean not null default false
);
create table if not exists storage.objects (
 id uuid primary key default gen_random_uuid(),
 bucket_id text references storage.buckets(id),name text,owner uuid
);
create or replace function storage.foldername(name text)
 returns text[] language sql immutable as $$ select string_to_array(name,'/') $$;
do $$ begin
 if not exists (select 1 from pg_roles where rolname='authenticated')
 then create role authenticated nologin; end if;
 if not exists (select 1 from pg_roles where rolname='anon')
 then create role anon nologin; end if;
end $$;
grant usage on schema public,storage to authenticated,anon;
alter default privileges in schema public
 grant select,insert,update,delete on tables to authenticated,anon;
SQL

cat > "$WORK_DIR/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
create table results (name text primary key, actual integer, expected integer);
insert into auth.users(id,email) values
 ('90000000-0000-0000-0000-000000000041','plus-a@example.invalid'),
 ('90000000-0000-0000-0000-000000000042','plus-b@example.invalid');
insert into public.wynos_plus_memberships(user_id,status,current_period_end) values
 ('90000000-0000-0000-0000-000000000041','active',now()+interval '25 days'),
 ('90000000-0000-0000-0000-000000000042','past_due',now()+interval '5 days');
insert into internal.wynos_plus_billing_refs(user_id,provider,customer_id,subscription_id)
 values ('90000000-0000-0000-0000-000000000041','fixture','private-cust','private-sub');
insert into results values
 ('rls_on',(select relrowsecurity::int from pg_class
  where oid='public.wynos_plus_memberships'::regclass),1),
 ('private_rls_on',(select relrowsecurity::int from pg_class
  where oid='internal.wynos_plus_billing_refs'::regclass),1),
 ('anon_read_denied',has_table_privilege('anon','public.wynos_plus_memberships','SELECT')::int,0),
 ('authenticated_read_only',has_table_privilege('authenticated','public.wynos_plus_memberships','SELECT')::int,1),
 ('auth_insert_denied',has_table_privilege('authenticated','public.wynos_plus_memberships','INSERT')::int,0),
 ('auth_update_denied',has_table_privilege('authenticated','public.wynos_plus_memberships','UPDATE')::int,0),
 ('auth_delete_denied',has_table_privilege('authenticated','public.wynos_plus_memberships','DELETE')::int,0),
 ('provider_ref_private',
  has_table_privilege('authenticated','internal.wynos_plus_billing_refs','SELECT')::int,0);

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000041';
set request.jwt.claim.role='authenticated';
insert into results select 'A_own_membership',count(*)::int,1
 from public.wynos_plus_memberships where user_id=
 '90000000-0000-0000-0000-000000000041';
insert into results select 'A_cannot_read_B',count(*)::int,0
 from public.wynos_plus_memberships where user_id=
 '90000000-0000-0000-0000-000000000042';
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000042';
set request.jwt.claim.role='authenticated';
insert into results select 'B_own_membership',count(*)::int,1
 from public.wynos_plus_memberships;
reset role; reset request.jwt.claim.sub; reset request.jwt.claim.role;

do $check$
begin
 if exists (select 1 from results where actual is distinct from expected) then
  raise exception 'WYN-191 FAILED: %',
   (select string_agg(name || '=' || actual::text || '/' || expected::text,', ')
    from results where actual is distinct from expected);
 end if;
end
$check$;
SQL

echo "== WYN-191 Plus membership ownership and provider isolation =="
dropdb_any "$DB_NAME"
createdb_any "$DB_NAME"
trap 'dropdb_any "$DB_NAME"; rm -rf "$WORK_DIR"' EXIT
psql_file "$DB_NAME" "$WORK_DIR/stub.sql"
psql_file "$DB_NAME" "$SCRIPT_DIR/../schema.sql"
# The separate upgrade must be safe even when a fresh schema already has Plus.
psql_file "$DB_NAME" "$SCRIPT_DIR/../migrations_wyn191_plus_memberships.sql"
psql_file "$DB_NAME" "$WORK_DIR/assert.sql"
dropdb_any "$DB_NAME"
echo "ALL CHECKS PASSED"
