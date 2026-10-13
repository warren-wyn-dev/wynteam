#!/usr/bin/env bash
# Admin Food review moderation security regression, safe read and audited hide/restore.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="admin_food_review_moderation_test_$$"
$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }
run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth;create schema internal;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;
create table public.admin_permissions(user_id uuid primary key,level text);
create function internal.has_admin_permission(p_system text,p_level text)
returns boolean language sql stable security definer as $$
 select p_system='food' and exists(select 1 from public.admin_permissions a
 where a.user_id=auth.uid() and (a.level='edit' or p_level='view')) $$;
create table public.food_stores(id uuid primary key,name text not null);
create table public.food_store_reviews(
 id uuid primary key,store_id uuid not null references food_stores(id),
 rating smallint not null,review_text text,tags text[] not null default '{}',
 reviewer_label text not null,merchant_reply text,is_hidden boolean not null default false,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
insert into auth.users values
('00000000-0000-0000-0000-0000000000a1'),
('00000000-0000-0000-0000-0000000000a2');
insert into public.admin_permissions values
('00000000-0000-0000-0000-0000000000a1','edit'),
('00000000-0000-0000-0000-0000000000a2','view');
insert into public.food_stores values('00000000-0000-0000-0000-0000000000b1','Thai Shop');
insert into public.food_store_reviews(id,store_id,rating,review_text,reviewer_label)
values('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1',4,'Good','Guest');
SQL
run >/dev/null < "$ROOT/supabase/migrations/20261013204000_admin_food_review_moderation.sql"
run >/dev/null < "$ROOT/supabase/migrations/20261013204000_admin_food_review_moderation.sql"
expect_eq(){
 local got
 got="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
 [[ "$got" == "$3" ]] || { echo "FAIL $4 actual=$got expected=$3";exit 1; }
}
expect_fail(){
 local output
 if output="$(run -At -c "select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
  echo "FAIL expected error $3";exit 1;
 fi
 [[ "$output" == *"$4"* ]] || { echo "FAIL $3 error=$output";exit 1; }
}
EDIT=00000000-0000-0000-0000-0000000000a1
VIEW=00000000-0000-0000-0000-0000000000a2
NONE=00000000-0000-0000-0000-0000000000a3
REVIEW=00000000-0000-0000-0000-0000000000c1
EXPECT="$(run -At -c "select updated_at from public.food_store_reviews where id='$REVIEW'" | tail -n1)"
expect_eq "$VIEW" "select jsonb_array_length(public.admin_food_review_moderation_feed(100))" 1 "viewer list"
expect_fail "$NONE" "select public.admin_food_review_moderation_feed(100)" "outsider cannot list" "Not authorized"
expect_fail "$VIEW" "select public.admin_set_food_review_hidden('$REVIEW','$EXPECT',true,'policy violation')" "viewer cannot edit" "Not authorized"
expect_fail "$EDIT" "select public.admin_set_food_review_hidden('$REVIEW','$EXPECT',true,'x')" "reason validation" "Reason"
expect_eq "$EDIT" "select (public.admin_set_food_review_hidden('$REVIEW','$EXPECT',true,'policy violation')->>'is_hidden')::boolean" t "hide review"
expect_eq "$NONE" "select is_hidden from public.food_store_reviews where id='$REVIEW'" t "review hidden in original table"
expect_fail "$EDIT" "select public.admin_set_food_review_hidden('$REVIEW','$EXPECT',false,'restored after review')" "stale version denied" "Review changed"
expect_eq "$EDIT" "select count(*) from public.food_review_moderation_actions where old_hidden=false and new_hidden=true" 1 "audit hide"
NEW_TIME="$(run -At -c "select updated_at from public.food_store_reviews where id='$REVIEW'" | tail -n1)"
expect_eq "$EDIT" "select (public.admin_set_food_review_hidden('$REVIEW','$NEW_TIME',false,'restored after review')->>'is_hidden')::boolean" f "restore review"
expect_eq "$EDIT" "select count(*) from public.food_review_moderation_actions where new_hidden=false" 1 "audit restore"
expect_eq "$NONE" "select has_function_privilege('anon','public.admin_set_food_review_hidden(uuid,timestamptz,boolean,text)','EXECUTE')" f "anon cannot write"
echo "PASS Admin review moderation: permission, hide/restore, stale-write, audit"
