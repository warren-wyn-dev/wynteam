#!/usr/bin/env bash
# WYN-148 atomic/idempotent Drop publication regression coverage.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="wyn_wyn148_test_$$"
WORK_DIR="$(mktemp -d)"
PSQL=(psql -v ON_ERROR_STOP=1 -X -q)

cleanup() {
  dropdb --if-exists "$DB" >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
createdb "$DB"
cat >"$WORK_DIR/stub.sql" <<'SQL'
create extension if not exists pgcrypto;
create schema if not exists auth;
create table auth.users(id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create function auth.role() returns text language sql stable as $$
  select nullif(current_setting('request.jwt.claim.role',true),'')
$$;
create schema if not exists storage;
create table storage.buckets(id text primary key,name text,public boolean);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,owner uuid);
create function storage.foldername(name text) returns text[] language sql immutable as $$select string_to_array(name,'/')$$;
do $$begin
 if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
 if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
end$$;
grant usage on schema public,storage to authenticated,anon;
alter default privileges in schema public grant select,insert,update,delete on tables to authenticated;
grant select,insert,update,delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
SQL
"${PSQL[@]}" -d "$DB" -f "$WORK_DIR/stub.sql" >/dev/null
"${PSQL[@]}" -d "$DB" -f "$ROOT/supabase/schema.sql" >/dev/null

"${PSQL[@]}" -d "$DB" <<'SQL'
insert into auth.users(id) values
 ('11111111-1111-1111-1111-111111111111'),
 ('22222222-2222-2222-2222-222222222222'),
 ('33333333-3333-3333-3333-333333333333');
insert into public.profiles(id,username) values
 ('11111111-1111-1111-1111-111111111111','wyn148_a'),
 ('22222222-2222-2222-2222-222222222222','wyn148_b'),
 ('33333333-3333-3333-3333-333333333333','wyn148_c');
insert into public.follows(follower_id,following_id) values
 ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222'),
 ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111'),
 ('11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333'),
 ('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111');

set role authenticated;
set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111';

-- Text, one image, multi-image, maximum images, mentions and friendsExcept.
select public.publish_drop('10000000-0000-4000-8000-000000000001',null,'text','everyone');
select public.publish_drop('10000000-0000-4000-8000-000000000002','one.jpg','one','everyone',
 '{}','[{"image_url":"one.jpg","position":0}]');
select public.publish_drop('10000000-0000-4000-8000-000000000003','a.jpg','multi','everyone',
 '{}','[{"image_url":"a.jpg","position":0},{"image_url":"b.jpg","position":1}]');
select public.publish_drop('10000000-0000-4000-8000-000000000004','0.jpg','max','everyone','{}',
 (select jsonb_agg(jsonb_build_object('image_url',i||'.jpg','position',i) order by i)
  from generate_series(0,8)i));
select public.publish_drop('10000000-0000-4000-8000-000000000005',null,'@wyn148_c','friends_except',
 array['22222222-2222-2222-2222-222222222222']::uuid[],'[]',
 array['33333333-3333-3333-3333-333333333333']::uuid[]);

do $$
declare a uuid; b uuid;
begin
  a:=public.publish_drop('10000000-0000-4000-8000-000000000001',null,'text','everyone');
  b:=public.publish_drop('10000000-0000-4000-8000-000000000001',null,'ignored retry','everyone');
  if a<>b or (select count(*) from public.drops where publication_operation_id='10000000-0000-4000-8000-000000000001')<>1 then
    raise exception 'idempotent retry failed';
  end if;
end$$;

select public.publish_drop('10000000-0000-4000-8000-000000000003','a.jpg','multi','everyone',
 '{}','[{"image_url":"a.jpg","position":0},{"image_url":"b.jpg","position":1}]');
select public.publish_drop('10000000-0000-4000-8000-000000000005',null,'@wyn148_c','friends_except',
 array['22222222-2222-2222-2222-222222222222']::uuid[],'[]',
 array['33333333-3333-3333-3333-333333333333']::uuid[]);
do $$begin
  if (select count(*) from public.drop_images where drop_id=public.drop_id_for_publication('10000000-0000-4000-8000-000000000003'))<>2
    or (select count(*) from public.drop_audience_exclusions where drop_id=public.drop_id_for_publication('10000000-0000-4000-8000-000000000005'))<>1
    or (select count(*) from public.drop_mentions where drop_id=public.drop_id_for_publication('10000000-0000-4000-8000-000000000005'))<>1
  then raise exception 'publication children were duplicated or missing'; end if;
end$$;

reset role; reset request.jwt.claim.sub;
do $$begin
  perform public.publish_drop('10000000-0000-4000-8000-000000000012',null,'x','everyone');
  raise exception 'unauthenticated publication accepted';
exception when others then
  if sqlerrm='unauthenticated publication accepted' then raise; end if;
end$$;
set role authenticated;
set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111';

-- Invalid input and cross-user operation reuse must fail.
do $$ begin
  perform public.publish_drop('10000000-0000-4000-8000-000000000010',null,'x','invalid');
  raise exception 'invalid audience accepted';
exception when others then
  if sqlerrm='invalid audience accepted' then raise; end if;
end$$;
do $$ begin
  perform public.publish_drop('10000000-0000-4000-8000-000000000011','x.jpg','x','everyone','{}',
    '[{"image_url":"x.jpg","position":1}]');
  raise exception 'invalid image position accepted';
exception when others then
  if sqlerrm='invalid image position accepted' then raise; end if;
end$$;

-- Failure in every relational child stage rolls back the Drop row too.
create function pg_temp.fail_wyn148() returns trigger language plpgsql as $$begin raise exception 'fault'; end$$;
create trigger wyn148_fail_exclusion before insert on public.drop_audience_exclusions
  for each row execute function pg_temp.fail_wyn148();
do $$ begin
  perform public.publish_drop('10000000-0000-4000-8000-000000000020',null,'x','friends_except',
    array['22222222-2222-2222-2222-222222222222']::uuid[]);
exception when others then null; end$$;
drop trigger wyn148_fail_exclusion on public.drop_audience_exclusions;
create trigger wyn148_fail_image before insert on public.drop_images
  for each row execute function pg_temp.fail_wyn148();
do $$ begin
  perform public.publish_drop('10000000-0000-4000-8000-000000000021','x.jpg','x','everyone','{}',
    '[{"image_url":"x.jpg","position":0}]');
exception when others then null; end$$;
drop trigger wyn148_fail_image on public.drop_images;
create trigger wyn148_fail_mention before insert on public.drop_mentions
  for each row execute function pg_temp.fail_wyn148();
do $$ begin
  perform public.publish_drop('10000000-0000-4000-8000-000000000022',null,'x','everyone','{}','[]',
    array['33333333-3333-3333-3333-333333333333']::uuid[]);
exception when others then null; end$$;
drop trigger wyn148_fail_mention on public.drop_mentions;
do $$ begin
  if exists(select 1 from public.drops where publication_operation_id in
    ('10000000-0000-4000-8000-000000000020','10000000-0000-4000-8000-000000000021','10000000-0000-4000-8000-000000000022')) then
    raise exception 'partial Drop survived child failure';
  end if;
end$$;

reset role; reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub='22222222-2222-2222-2222-222222222222';
do $$ begin
  if exists(select 1 from public.drops where publication_operation_id='10000000-0000-4000-8000-000000000005') then
    raise exception 'excluded user can read friendsExcept Drop';
  end if;
end$$;
-- Another user cannot discover or reuse A's operation ID.
do $$ begin
  if public.drop_id_for_publication('10000000-0000-4000-8000-000000000005') is not null then
    raise exception 'cross-user publication lookup leaked';
  end if;
  perform public.publish_drop('10000000-0000-4000-8000-000000000005',null,'attack','everyone');
  raise exception 'cross-user operation reuse accepted';
exception when unique_violation then null; end$$;
reset role; reset request.jwt.claim.sub;
set role authenticated;
set request.jwt.claim.sub='33333333-3333-3333-3333-333333333333';
do $$ begin
  if not exists(select 1 from public.drops where publication_operation_id='10000000-0000-4000-8000-000000000005') then
    raise exception 'allowed user cannot read friendsExcept Drop';
  end if;
end$$;
SQL

echo "PASS: WYN-148 atomic publication, idempotency, faults and privacy"
