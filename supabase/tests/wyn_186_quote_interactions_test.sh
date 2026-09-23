#!/usr/bin/env bash
# WYN-186: independent Quote likes/comments/reposts/saves. New throwaway DB only.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../schema.sql"
DB_NAME="wyn186_quote_independent_test"
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
insert into auth.users (id,email) values
  ('11111111-1111-1111-1111-111111111111','alice@fixture.test'),
  ('22222222-2222-2222-2222-222222222222','bob@fixture.test'),
  ('33333333-3333-3333-3333-333333333333','carol@fixture.test'),
  ('44444444-4444-4444-4444-444444444444','dave@fixture.test');
insert into public.profiles (id,username,display_name,platform_role) values
  ('11111111-1111-1111-1111-111111111111','alice','Alice','user'),
  ('22222222-2222-2222-2222-222222222222','bob','Bob','user'),
  ('33333333-3333-3333-3333-333333333333','carol','Carol','user'),
  ('44444444-4444-4444-4444-444444444444','dave','Dave','user');
insert into public.drops (id,author_id,image_url)
  values ('d1000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111','https://example.com/fixture.jpg');
insert into public.drop_likes(drop_id,user_id)
  select 'd1000000-0000-0000-0000-000000000001',id from public.profiles
  where id in ('11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444');
insert into public.redrops(id,drop_id,redropper_id,quote_text) values
  ('a1000000-0000-0000-0000-000000000001',
   'd1000000-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222','สวย');
insert into public.redrops(drop_id,redropper_id)
  values ('d1000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333');

set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
set request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","is_anonymous":false}';
do $$
declare e record;
begin
  select * into strict e from public.get_quote_engagement(array['a1000000-0000-0000-0000-000000000001'::uuid]);
  if (e.like_count,e.comment_count,e.redrop_count) <> (0::bigint,0::bigint,0::bigint)
     or e.liked_by_me or e.saved_by_me or e.redropped_by_me then
    raise exception 'Quote inherited original Drop activity instead of starting from zero';
  end if;
end $$;

insert into public.quote_likes(quote_id,user_id)
  values ('a1000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333');
insert into public.quote_reposts(quote_id,user_id)
  values ('a1000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333');
insert into public.quote_saves(quote_id,user_id)
  values ('a1000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333');
insert into public.quote_comments(quote_id,author_id,text_content)
  values ('a1000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333','ถูกใจโพสต์อ้างอิง');

do $$
declare e record;
        rejected boolean := false;
begin
  select * into strict e from public.get_quote_engagement(array['a1000000-0000-0000-0000-000000000001'::uuid]);
  if (e.like_count,e.comment_count,e.redrop_count) <> (1::bigint,1::bigint,1::bigint)
     or not e.liked_by_me or not e.saved_by_me or not e.redropped_by_me then
    raise exception 'Quote-only actions or viewer flags were not saved';
  end if;
  if (select count(*) from public.drop_likes where drop_id='d1000000-0000-0000-0000-000000000001') <> 4
     or (select count(*) from public.redrops where drop_id='d1000000-0000-0000-0000-000000000001') <> 2 then
    raise exception 'Quote action unexpectedly touched source Drop activity';
  end if;
  -- RLS must not allow writing a reaction as another account.
  begin
    insert into public.quote_likes(quote_id,user_id)
    values ('a1000000-0000-0000-0000-000000000001','44444444-4444-4444-4444-444444444444');
  exception when others then
    rejected := true;
  end;
  if not rejected then raise exception 'Quote reaction spoof was accepted'; end if;
end $$;

reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.role;
reset request.jwt.claims;
-- Same source Drop, a second Quote: it must have an independent zero state.
insert into public.redrops(id,drop_id,redropper_id,quote_text) values
  ('a2000000-0000-0000-0000-000000000002',
   'd1000000-0000-0000-0000-000000000001',
   '22222222-2222-2222-2222-222222222222','อ้างอิงครั้งที่สอง');

set role authenticated;
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
set request.jwt.claim.role = 'authenticated';
set request.jwt.claims = '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated","is_anonymous":false}';
do $$
declare e record;
begin
  select * into strict e from public.get_quote_engagement(array['a2000000-0000-0000-0000-000000000002'::uuid]);
  if (e.like_count,e.comment_count,e.redrop_count) <> (0::bigint,0::bigint,0::bigint) then
    raise exception 'Different quotes of the same Drop shared interactions';
  end if;
end $$;
delete from public.quote_likes where quote_id='a1000000-0000-0000-0000-000000000001' and user_id=auth.uid();
delete from public.quote_reposts where quote_id='a1000000-0000-0000-0000-000000000001' and user_id=auth.uid();
delete from public.quote_saves where quote_id='a1000000-0000-0000-0000-000000000001' and user_id=auth.uid();
do $$
declare e record;
begin
  select * into strict e from public.get_quote_engagement(array['a1000000-0000-0000-0000-000000000001'::uuid]);
  if e.like_count <> 0 or e.redrop_count <> 0 or e.liked_by_me or e.saved_by_me or e.redropped_by_me then
    raise exception 'Unliking/repost undo/unsave did not affect only the Quote';
  end if;
end $$;

reset role;
reset request.jwt.claim.sub;
reset request.jwt.claim.role;
reset request.jwt.claims;
-- Removing a Quote cascades all four interaction types.
delete from public.redrops where id='a1000000-0000-0000-0000-000000000001';
do $$
begin
  if exists(select 1 from public.quote_comments where quote_id='a1000000-0000-0000-0000-000000000001')
     or exists(select 1 from public.quote_likes where quote_id='a1000000-0000-0000-0000-000000000001')
     or exists(select 1 from public.quote_reposts where quote_id='a1000000-0000-0000-0000-000000000001')
     or exists(select 1 from public.quote_saves where quote_id='a1000000-0000-0000-0000-000000000001') then
    raise exception 'Deleted Quote retained orphan interactions';
  end if;
end $$;
select 'ALL QUOTE CHECKS PASSED';
EOF

if ! createdb_any "$DB_NAME"; then
  echo "FAIL: could not create throwaway database" >&2
  exit 1
fi
if ! run_psql "$DB_NAME" "$WORK_DIR/00_stub.sql"; then
  echo "FAIL: Supabase platform stubs did not load" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
if ! run_psql "$DB_NAME" "$SCHEMA_FILE"; then
  echo "FAIL: canonical schema.sql did not load" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
if ! run_psql "$DB_NAME" "$WORK_DIR/10_seed_and_assert.sql"; then
  echo "FAIL: Quote schema or RLS regression" >&2
  dropdb_any "$DB_NAME"
  exit 1
fi
cat "$WORK_DIR/psql.out"
dropdb_any "$DB_NAME"
echo "ALL CHECKS PASSED"
