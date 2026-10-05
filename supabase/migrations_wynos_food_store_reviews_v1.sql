-- WYN-216: WYNOS Food verified store reviews.
--
-- Customers may review only their own delivered orders, once per order.
-- Reviewer identity is never exposed: the server stores only a masked Food
-- recipient label (or "ไม่ระบุชื่อ"). Social username/avatar are never read.
-- Review reads go through sanitized RPCs; the underlying table is not readable
-- through the Data API by customers or merchants.
--
-- Merchants may view sanitized reviews for their own store. Owner/admin/manager
-- can reply; merchants cannot delete or hide reviews. is_hidden is reserved for
-- future platform moderation.
--
-- Additive and non-destructive. Existing orders/stores are unchanged.
-- Rollback: revoke/drop the five public RPCs below, drop
-- internal.food_mask_reviewer_name(text), then drop public.food_store_reviews.

create table if not exists public.food_store_reviews (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.food_orders(id) on delete cascade,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review_text text,
  tags text[] not null default '{}'::text[],
  reviewer_label text not null,
  is_anonymous boolean not null default false,
  merchant_reply text,
  merchant_replied_at timestamptz,
  merchant_replied_by uuid references public.profiles(id) on delete set null,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_store_reviews_text_length check (
    review_text is null or char_length(review_text) between 1 and 500
  ),
  constraint food_store_reviews_reply_length check (
    merchant_reply is null or char_length(merchant_reply) between 1 and 500
  ),
  constraint food_store_reviews_label_length check (
    char_length(reviewer_label) between 1 and 120
  ),
  constraint food_store_reviews_tags_limit check (
    cardinality(tags) <= 5
    and tags <@ array['อร่อย','ปริมาณดี','แพ็กดี','ตรงปก','คุ้มราคา','ส่งเร็ว']::text[]
  )
);

create index if not exists food_store_reviews_store_created_idx
  on public.food_store_reviews(store_id, created_at desc);
create index if not exists food_store_reviews_buyer_created_idx
  on public.food_store_reviews(buyer_id, created_at desc);

alter table public.food_store_reviews enable row level security;
revoke all on table public.food_store_reviews from public, anon, authenticated;

create or replace function internal.food_mask_reviewer_name(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $fn$
declare
  v_name text := split_part(btrim(coalesce(p_name,'')), ' ', 1);
  v_visible text;
  v_first text;
  v_last text;
  v_len integer;
begin
  if v_name = '' then
    return 'ผู้ใช้ WYNOS Food';
  end if;

  -- Keep Thai combining marks attached to the visible character before them.
  -- This makes "กานต์" mask as "ก**ต์" instead of exposing a dangling mark.
  v_visible := regexp_replace(v_name, '[ัิ-ฺ็-๎]', '', 'g');
  v_len := char_length(v_visible);

  if v_len = 0 then
    return 'ผู้ใช้ WYNOS Food';
  end if;

  v_first := substring(v_name from '^([^ัิ-ฺ็-๎][ัิ-ฺ็-๎]*)');
  v_last := substring(v_name from '([^ัิ-ฺ็-๎][ัิ-ฺ็-๎]*)$');

  if v_len = 1 then
    return coalesce(v_first, v_name) || '***';
  end if;
  if v_len = 2 then
    return coalesce(v_first, left(v_visible,1))
      || '**'
      || coalesce(v_last, right(v_visible,1));
  end if;

  return coalesce(v_first, left(v_visible,1))
    || repeat('*', least(4, greatest(2, v_len - 2)))
    || coalesce(v_last, right(v_visible,1));
end;
$fn$;

revoke all on function internal.food_mask_reviewer_name(text) from public, anon, authenticated;

create or replace function public.food_submit_store_review(
  p_order_id uuid,
  p_rating integer,
  p_review_text text default null,
  p_tags text[] default '{}'::text[],
  p_anonymous boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_order public.food_orders%rowtype;
  v_review_id uuid;
  v_text text := nullif(left(btrim(coalesce(p_review_text,'')),500),'');
  v_tags text[];
  v_label text;
begin
  if (select auth.uid()) is null or not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'invalid review rating';
  end if;

  select array(
    select distinct btrim(t)
    from unnest(coalesce(p_tags,'{}'::text[])) as t
    where btrim(t) <> ''
    order by btrim(t)
  ) into v_tags;

  if cardinality(v_tags) > 5
     or not (v_tags <@ array['อร่อย','ปริมาณดี','แพ็กดี','ตรงปก','คุ้มราคา','ส่งเร็ว']::text[]) then
    raise exception 'invalid review tags';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id
    and buyer_id = (select auth.uid())
  for share;

  if not found then
    raise exception 'order not found';
  end if;
  if v_order.status <> 'delivered' or v_order.delivered_at is null then
    raise exception 'only delivered orders can be reviewed';
  end if;
  if exists (select 1 from public.food_store_reviews r where r.order_id = p_order_id) then
    raise exception 'order already reviewed';
  end if;

  v_label := case
    when coalesce(p_anonymous,false) then 'ไม่ระบุชื่อ'
    else internal.food_mask_reviewer_name(v_order.recipient_name)
  end;

  insert into public.food_store_reviews(
    order_id, store_id, buyer_id, rating, review_text, tags,
    reviewer_label, is_anonymous
  ) values (
    v_order.id, v_order.store_id, v_order.buyer_id, p_rating, v_text, v_tags,
    v_label, coalesce(p_anonymous,false)
  )
  returning id into v_review_id;

  return v_review_id;
end;
$fn$;

create or replace function public.food_my_store_reviews()
returns table(
  review_id uuid,
  order_id uuid,
  store_id uuid,
  rating smallint,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $fn$
  select r.id, r.order_id, r.store_id, r.rating, r.created_at
  from public.food_store_reviews r
  where r.buyer_id = (select auth.uid())
  order by r.created_at desc
$fn$;

create or replace function public.food_store_review_feed(
  p_store_id uuid,
  p_limit integer default 20
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_limit integer := greatest(1,least(coalesce(p_limit,20),50));
  v_average numeric;
  v_count bigint;
  v_reviews jsonb;
begin
  if (select auth.uid()) is null or not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  if not exists (
    select 1
    from public.food_stores s
    where s.id = p_store_id
      and s.admin_suspended_at is null
      and (s.is_published or public.is_developer_account())
  ) then
    raise exception 'store not found';
  end if;

  select round(avg(r.rating)::numeric,1), count(*)
  into v_average, v_count
  from public.food_store_reviews r
  where r.store_id = p_store_id
    and not r.is_hidden;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
  into v_reviews
  from (
    select
      r.id,
      r.rating,
      r.review_text,
      r.tags,
      r.reviewer_label,
      true as verified_order,
      r.created_at,
      r.merchant_reply,
      r.merchant_replied_at
    from public.food_store_reviews r
    where r.store_id = p_store_id
      and not r.is_hidden
    order by r.created_at desc
    limit v_limit
  ) x;

  return jsonb_build_object(
    'average', coalesce(v_average,0),
    'count', v_count,
    'reviews', v_reviews
  );
end;
$fn$;

create or replace function public.merchant_store_reviews(
  p_store_id uuid,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  v_limit integer := greatest(1,least(coalesce(p_limit,50),100));
  v_average numeric;
  v_count bigint;
  v_unanswered bigint;
  v_reviews jsonb;
begin
  if (select auth.uid()) is null or not public.food_has_merchant_access(p_store_id) then
    raise exception 'merchant access required';
  end if;

  select round(avg(r.rating)::numeric,1),
         count(*),
         count(*) filter (where r.merchant_reply is null)
  into v_average, v_count, v_unanswered
  from public.food_store_reviews r
  where r.store_id = p_store_id
    and not r.is_hidden;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
  into v_reviews
  from (
    select
      r.id,
      r.rating,
      r.review_text,
      r.tags,
      r.reviewer_label,
      true as verified_order,
      r.created_at,
      r.merchant_reply,
      r.merchant_replied_at
    from public.food_store_reviews r
    where r.store_id = p_store_id
      and not r.is_hidden
    order by r.created_at desc
    limit v_limit
  ) x;

  return jsonb_build_object(
    'average', coalesce(v_average,0),
    'count', v_count,
    'unanswered', v_unanswered,
    'reviews', v_reviews
  );
end;
$fn$;

create or replace function public.food_reply_store_review(
  p_review_id uuid,
  p_reply text
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_review public.food_store_reviews%rowtype;
  v_reply text := nullif(left(btrim(coalesce(p_reply,'')),500),'');
begin
  if (select auth.uid()) is null then
    raise exception 'authentication required';
  end if;

  select * into v_review
  from public.food_store_reviews
  where id = p_review_id
  for update;

  if not found then
    raise exception 'review not found';
  end if;
  if not public.merchant_has_store_role(v_review.store_id,array['owner','admin','manager']) then
    raise exception 'merchant management role required';
  end if;
  if v_reply is null then
    raise exception 'reply required';
  end if;

  update public.food_store_reviews
  set merchant_reply = v_reply,
      merchant_replied_at = now(),
      merchant_replied_by = (select auth.uid()),
      updated_at = now()
  where id = p_review_id;
end;
$fn$;

revoke all on function public.food_submit_store_review(uuid,integer,text,text[],boolean) from public, anon;
revoke all on function public.food_my_store_reviews() from public, anon;
revoke all on function public.food_store_review_feed(uuid,integer) from public, anon;
revoke all on function public.merchant_store_reviews(uuid,integer) from public, anon;
revoke all on function public.food_reply_store_review(uuid,text) from public, anon;

grant execute on function public.food_submit_store_review(uuid,integer,text,text[],boolean) to authenticated;
grant execute on function public.food_my_store_reviews() to authenticated;
grant execute on function public.food_store_review_feed(uuid,integer) to authenticated;
grant execute on function public.merchant_store_reviews(uuid,integer) to authenticated;
grant execute on function public.food_reply_store_review(uuid,text) to authenticated;
