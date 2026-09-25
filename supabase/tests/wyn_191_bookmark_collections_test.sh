#!/usr/bin/env bash
# WYN-191: isolated RLS, ownership and unsave cleanup. No production connection.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DB="wyn191_bookmark_collection_test"
WORK="$(mktemp -d)"
trap 'dropdb --if-exists "$DB" >/dev/null 2>&1 || sudo -u postgres dropdb --if-exists "$DB" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
chmod 755 "$WORK"
run_file() {
  psql -d "$DB" -v ON_ERROR_STOP=1 -f "$1" >/dev/null 2>&1 ||
    sudo -u postgres psql -d "$DB" -v ON_ERROR_STOP=1 -f "$1" >/dev/null
}
dropdb --if-exists "$DB" >/dev/null 2>&1 || sudo -u postgres dropdb --if-exists "$DB" >/dev/null 2>&1 || true
createdb "$DB" >/dev/null 2>&1 || sudo -u postgres createdb "$DB" >/dev/null
cat > "$WORK/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table if not exists auth.users(id uuid primary key default gen_random_uuid(),email text);
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create or replace function auth.role() returns text language sql stable as $$
 select nullif(current_setting('request.jwt.claim.role',true),'')
$$;
create schema if not exists storage;
create table if not exists storage.buckets(id text primary key,name text not null,public boolean not null default false);
create table if not exists storage.objects(id uuid primary key default gen_random_uuid(),
bucket_id text references storage.buckets(id),name text,owner uuid);
create or replace function storage.foldername(name text) returns text[] language sql immutable as $$
 select string_to_array(name,'/')
$$;
do $$begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin;end if;
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin;end if;
end$$;
grant usage on schema public,storage to authenticated,anon;
alter default privileges in schema public grant select,insert,update,delete on tables to authenticated,anon;
SQL
cat > "$WORK/assert.sql" <<'SQL'
\set ON_ERROR_STOP on
create table results(label text primary key,actual int,expected int);
insert into auth.users(id,email) values
 ('90000000-0000-0000-0000-000000000051','collections-a@test.invalid'),
 ('90000000-0000-0000-0000-000000000052','collections-b@test.invalid');
insert into public.profiles(id,username,platform_role) values
 ('90000000-0000-0000-0000-000000000051','wyn191_a','user'),
 ('90000000-0000-0000-0000-000000000052','wyn191_b','user');
insert into public.drops(id,author_id,image_url,caption) values
 ('90000000-0000-0000-0000-000000000053',
  '90000000-0000-0000-0000-000000000051','https://example.invalid/a.png','Saved Drop'),
 ('90000000-0000-0000-0000-000000000054',
  '90000000-0000-0000-0000-000000000052','https://example.invalid/b.png','Unsaved Drop');
insert into public.redrops(id,drop_id,redropper_id,quote_text) values
 ('90000000-0000-0000-0000-000000000055',
  '90000000-0000-0000-0000-000000000053',
  '90000000-0000-0000-0000-000000000051','A quote');
insert into public.saves(user_id,content_type,content_id) values
 ('90000000-0000-0000-0000-000000000051','drop','90000000-0000-0000-0000-000000000053');
insert into public.quote_saves(user_id,quote_id) values
 ('90000000-0000-0000-0000-000000000051','90000000-0000-0000-0000-000000000055');
insert into results values
 ('collection_RLS_enabled',
  (select relrowsecurity::int from pg_class where oid='public.bookmark_collections'::regclass),1),
 ('items_RLS_enabled',
  (select relrowsecurity::int from pg_class where oid='public.bookmark_collection_items'::regclass),1),
 ('anon_cannot_select_collections',
  has_table_privilege('anon','public.bookmark_collections','SELECT')::int,0),
 ('anon_cannot_select_items',
  has_table_privilege('anon','public.bookmark_collection_items','SELECT')::int,0);

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000051';
set request.jwt.claim.role='authenticated';
insert into public.bookmark_collections(id,owner_id,name) values
 ('90000000-0000-0000-0000-000000000056',auth.uid(),'Favorites');
insert into public.bookmark_collection_items(collection_id,owner_id,content_type,content_id)
values
 ('90000000-0000-0000-0000-000000000056',auth.uid(),'drop','90000000-0000-0000-0000-000000000053'),
 ('90000000-0000-0000-0000-000000000056',auth.uid(),'quote','90000000-0000-0000-0000-000000000055');
insert into results select 'A_sees_two_memberships',count(*)::int,2 from public.bookmark_collection_items;
do $check$
begin
  begin
    insert into public.bookmark_collection_items(collection_id,owner_id,content_type,content_id)
    values('90000000-0000-0000-0000-000000000056',auth.uid(),'drop',
           '90000000-0000-0000-0000-000000000054');
    raise exception 'Unsaved item was incorrectly accepted';
  exception when insufficient_privilege or check_violation or foreign_key_violation then null;
  end;
end
$check$;
delete from public.quote_saves where user_id=auth.uid()
  and quote_id='90000000-0000-0000-0000-000000000055';
insert into results select 'unsave_quote_cleans_membership',count(*)::int,1
  from public.bookmark_collection_items;
delete from public.saves where user_id=auth.uid()
  and content_type='drop' and content_id='90000000-0000-0000-0000-000000000053';
insert into results select 'unsave_drop_cleans_membership',count(*)::int,0
  from public.bookmark_collection_items;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

set role authenticated;
set request.jwt.claim.sub='90000000-0000-0000-0000-000000000052';
set request.jwt.claim.role='authenticated';
insert into results select 'B_cannot_read_A_collections',count(*)::int,0 from public.bookmark_collections;
insert into results select 'B_cannot_read_A_items',count(*)::int,0 from public.bookmark_collection_items;
reset role;reset request.jwt.claim.sub;reset request.jwt.claim.role;

do $assert$
begin
 if exists(select 1 from results where actual is distinct from expected) then
 raise exception 'WYN-191 failed: %',
 (select string_agg(label||'='||actual::text||'/'||expected::text,',')
  from results where actual is distinct from expected);
 end if;
end
$assert$;
SQL
echo "WYN-191: testing private bookmark collection policies and unsave cleanup"
run_file "$WORK/stub.sql"
run_file "$HERE/../schema.sql"
run_file "$HERE/../migrations_wyn191_bookmark_collections.sql"
run_file "$WORK/assert.sql"
echo "ALL CHECKS PASSED"
