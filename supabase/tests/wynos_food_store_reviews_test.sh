#!/usr/bin/env bash
# WYN-216 verified WYNOS Food store-review behaviour on throwaway PostgreSQL.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PSQL="${PSQL:-psql}"
DB="wyn_food_reviews_test_$$"

$PSQL -q -v ON_ERROR_STOP=1 -d postgres -c "create database $DB" >/dev/null
trap '$PSQL -q -d postgres -c "drop database if exists $DB" >/dev/null' EXIT
run() { $PSQL -q -X -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

run >/dev/null <<'SQL'
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
create schema auth; create schema internal;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid',true),'')::uuid $$;

create table public.profiles(id uuid primary key);
create table public.food_stores(
  id uuid primary key,
  merchant_account_id uuid,
  is_published boolean not null default true,
  admin_suspended_at timestamptz
);
create table public.food_orders(
  id uuid primary key,
  store_id uuid not null references public.food_stores(id),
  buyer_id uuid references public.profiles(id),
  recipient_name text not null,
  status text not null,
  delivered_at timestamptz
);
create table public.merchant_memberships(
  merchant_account_id uuid,
  user_id uuid,
  role text,
  active boolean
);
create table public.food_staff(store_id uuid,user_id uuid,role text,active boolean);

create function public.food_customer_access_enabled() returns boolean
language sql stable as $$ select auth.uid() is not null $$;
create function public.is_developer_account() returns boolean
language sql stable as $$ select false $$;
create function public.merchant_has_store_role(p_store_id uuid,p_roles text[] default null) returns boolean
language sql stable security definer set search_path='' as $fn$
  select exists (
    select 1
    from public.food_stores s
    join public.merchant_memberships mm on mm.merchant_account_id=s.merchant_account_id
    where s.id=p_store_id
      and mm.user_id=(select auth.uid())
      and mm.active
      and (p_roles is null or mm.role=any(p_roles))
  )
$fn$;
create function public.food_has_merchant_access(p_store_id uuid default null) returns boolean
language sql stable security definer set search_path='' as $fn$
  select exists (
    select 1
    from public.food_stores s
    join public.merchant_memberships mm on mm.merchant_account_id=s.merchant_account_id
    where mm.user_id=(select auth.uid())
      and mm.active
      and (p_store_id is null or s.id=p_store_id)
  )
$fn$;

insert into public.profiles(id) values
('00000000-0000-0000-0000-0000000000c1'),
('00000000-0000-0000-0000-0000000000c2'),
('00000000-0000-0000-0000-0000000000a1'),
('00000000-0000-0000-0000-0000000000b1');

insert into public.food_stores(id,merchant_account_id,is_published) values
('aaaaaaaa-0000-0000-0000-000000000000','aaaaaaaa-1111-1111-1111-111111111111',true);

insert into public.merchant_memberships values
('aaaaaaaa-1111-1111-1111-111111111111','00000000-0000-0000-0000-0000000000a1','owner',true);

insert into public.food_orders values
('11111111-0000-0000-0000-000000000000','aaaaaaaa-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c1','วรพล','delivered',now()),
('22222222-0000-0000-0000-000000000000','aaaaaaaa-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c1','วรพล','preparing',null),
('33333333-0000-0000-0000-000000000000','aaaaaaaa-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c2','สมชาย','delivered',now()),
('44444444-0000-0000-0000-000000000000','aaaaaaaa-0000-0000-0000-000000000000','00000000-0000-0000-0000-0000000000c2','กานต์','delivered',now());
SQL

run >/dev/null < "$ROOT/supabase/migrations_wynos_food_store_reviews_v1.sql"

expect_ok() {
  run -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" >/dev/null 2>&1     || { echo "FAIL (expected success): $3"; exit 1; }
}
expect_fail() {
  local err
  if err="$(run -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" 2>&1)"; then
    echo "FAIL (expected error): $3"; exit 1
  fi
  [[ "$err" == *"$4"* ]] || { echo "FAIL: $3 (wrong error: $err)"; exit 1; }
}
expect_eq() {
  local got
  got="$(run -At -c "set role authenticated; select set_config('test.uid','$1',false);" -c "$2" | tail -n1)"
  [[ "$got" == "$3" ]] || { echo "FAIL: $4 (got '$got', want '$3')"; exit 1; }
}

C1=00000000-0000-0000-0000-0000000000c1
C2=00000000-0000-0000-0000-0000000000c2
A1=00000000-0000-0000-0000-0000000000a1
B1=00000000-0000-0000-0000-0000000000b1
STORE=aaaaaaaa-0000-0000-0000-000000000000
O1=11111111-0000-0000-0000-000000000000
O2=22222222-0000-0000-0000-000000000000
O3=33333333-0000-0000-0000-000000000000
O4=44444444-0000-0000-0000-000000000000

expect_eq "$C1" "select has_table_privilege('authenticated','public.food_store_reviews','select')" "f" "review table is not directly readable"
expect_eq "$C1" "reset role; select internal.food_mask_reviewer_name('กานต์')" "ก**ต์" "Thai combining marks stay attached to the visible last character"
expect_eq "$C1" "reset role; select internal.food_mask_reviewer_name('พล')" "พ**ล" "short names keep the first and last visible characters"
expect_fail "$C1" "select public.food_submit_store_review('$O2',5,null,array[]::text[],false)" "non-delivered order cannot be reviewed" "only delivered orders can be reviewed"
expect_fail "$C1" "select public.food_submit_store_review('$O3',5,null,array[]::text[],false)" "another buyer's order cannot be reviewed" "order not found"
expect_fail "$C1" "select public.food_submit_store_review('$O1',6,null,array[]::text[],false)" "rating must be one to five" "invalid review rating"
expect_fail "$C1" "select public.food_submit_store_review('$O1',5,null,array['ไม่อยู่ในรายการ']::text[],false)" "unknown review tag rejected" "invalid review tags"

expect_ok "$C1" "select public.food_submit_store_review('$O1',5,'อร่อยมาก',array['อร่อย','คุ้มราคา']::text[],false)" "buyer reviews delivered order"
expect_eq "$C1" "select public.food_store_review_feed('$STORE',20)->>'count'" "1" "review count is one"
expect_eq "$C1" "select public.food_store_review_feed('$STORE',20)#>>'{reviews,0,reviewer_label}'" "ว**ล" "recipient name is masked"
expect_eq "$C1" "select public.food_store_review_feed('$STORE',20)#>>'{reviews,0,verified_order}'" "true" "review is marked as verified order"
expect_eq "$C1" "select ((public.food_store_review_feed('$STORE',20)->'reviews'->0) ? 'buyer_id')::text" "false" "feed does not expose buyer id"
expect_eq "$C1" "select count(*) from public.food_my_store_reviews()" "1" "buyer sees own review membership"
expect_fail "$C1" "select public.food_submit_store_review('$O1',4,null,array[]::text[],false)" "one review per order" "order already reviewed"

REVIEW_ID="$(run -At -c "reset role; select id from public.food_store_reviews where order_id='$O1'" | tail -n1)"
expect_fail "$C1" "select public.food_reply_store_review('$REVIEW_ID','ขอบคุณครับ')" "buyer cannot reply as merchant" "merchant management role required"
expect_fail "$B1" "select public.merchant_store_reviews('$STORE',50)" "unrelated account cannot read merchant reviews" "merchant access required"
expect_eq "$A1" "select public.merchant_store_reviews('$STORE',50)->>'count'" "1" "store owner sees review count"
expect_eq "$A1" "select public.merchant_store_reviews('$STORE',50)->>'unanswered'" "1" "new review is awaiting a reply"
expect_eq "$A1" "select ((public.merchant_store_reviews('$STORE',50)->'reviews'->0) ? 'buyer_id')::text" "false" "merchant review feed stays sanitized"
expect_eq "$A1" "select ((public.merchant_store_reviews('$STORE',50)->'reviews'->0) ? 'order_id')::text" "false" "merchant review feed does not expose order id"
expect_fail "$B1" "select public.food_reply_store_review('$REVIEW_ID','ขอบคุณครับ')" "unrelated account cannot reply" "merchant management role required"
expect_ok "$A1" "select public.food_reply_store_review('$REVIEW_ID','ขอบคุณที่อุดหนุนครับ')" "store owner replies"
expect_eq "$A1" "select public.merchant_store_reviews('$STORE',50)->>'unanswered'" "0" "reply clears the unanswered count"
expect_eq "$C1" "select public.food_store_review_feed('$STORE',20)#>>'{reviews,0,merchant_reply}'" "ขอบคุณที่อุดหนุนครับ" "merchant reply is visible in feed"

expect_ok "$C2" "select public.food_submit_store_review('$O4',3,null,array['แพ็กดี']::text[],true)" "anonymous verified review"
expect_eq "$C2" "select (public.food_store_review_feed('$STORE',20)->'reviews') @> '[{\"reviewer_label\":\"ไม่ระบุชื่อ\"}]'::jsonb" "t" "anonymous label hides name"
expect_eq "$C2" "select public.food_store_review_feed('$STORE',20)->>'average'" "4.0" "average rating is correct"
expect_eq "$C2" "select public.food_store_review_feed('$STORE',20)->>'count'" "2" "review count is correct"
expect_eq "$A1" "select public.merchant_store_reviews('$STORE',50)->>'unanswered'" "1" "merchant sees the new anonymous review awaiting a reply"

echo "PASS: WYNOS Food reviews are delivered-order-only, masked, sanitized and merchant-reply capable"
