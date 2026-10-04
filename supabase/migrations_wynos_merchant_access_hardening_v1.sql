-- WYN-213: Merchant access hardening (Founder approved 2026-10-04 after the
-- WYNOS Admin Merchant audit).
--
-- 1. public.merchant_has_store_role() and public.food_has_merchant_access()
--    no longer let every developer account into every store. Developers now
--    need a real store membership like anyone else.
-- 2. Legacy food_staff rows count by their role: owner = owner, staff =
--    orders, delivery = delivery. Before this, any legacy row (even delivery)
--    passed owner/admin checks: it could promote itself, edit the store's
--    bank/PromptPay details, or mark payments paid/refunded.
-- 3. food_store_media_writable() drops its developer bypass too.
-- 4. What WYNOS owes a store for campaign discounts counts only orders that
--    were paid (not refunded) and were not placed by the store's own team.
-- 5. Recording a WYNOS payout needs the amount and order count the admin
--    saw; if more became owed meanwhile, the call stops (no short payment).
-- 6. One ad top-up slip can be submitted once (unique slip path).
--
-- Customer-side developer access (is_developer_account() in the Food
-- rollout gate, store/menu browsing) is unchanged: it never exposed another
-- store's private data.

create or replace function public.merchant_has_store_role(
  p_store_id uuid,
  p_roles text[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and (
      exists (
        select 1
        from public.food_stores s
        join public.merchant_memberships mm
          on mm.merchant_account_id = s.merchant_account_id
        where s.id = p_store_id
          and mm.user_id = (select auth.uid())
          and mm.active
          and (p_roles is null or mm.role = any(p_roles))
      )
      or exists (
        select 1
        from public.food_staff fs
        where fs.store_id = p_store_id
          and fs.user_id = (select auth.uid())
          and fs.active
          and (
            p_roles is null
            or (case fs.role when 'owner' then 'owner' when 'staff' then 'orders' when 'delivery' then 'delivery' end) = any(p_roles)
          )
      )
    );
$$;

revoke all on function public.merchant_has_store_role(uuid,text[]) from public, anon;
grant execute on function public.merchant_has_store_role(uuid,text[]) to authenticated;

create or replace function public.food_has_merchant_access(p_store_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
    and (
      exists (
        select 1
        from public.food_stores s
        join public.merchant_memberships mm
          on mm.merchant_account_id = s.merchant_account_id
        where mm.user_id = auth.uid()
          and mm.active
          and (p_store_id is null or s.id = p_store_id)
      )
      or exists (
        select 1
        from public.food_staff fs
        where fs.user_id = auth.uid()
          and fs.active
          and (p_store_id is null or fs.store_id = p_store_id)
      )
    );
$$;

revoke all on function public.food_has_merchant_access(uuid) from public, anon;
grant execute on function public.food_has_merchant_access(uuid) to authenticated;

create or replace function public.food_store_media_writable(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with target as (
    select public.food_path_uuid((storage.foldername(p_name))[2]) as store_id
    where (storage.foldername(p_name))[1] = 'stores'
  )
  select exists (
    select 1 from target t
    where (select auth.uid()) is not null
      and (
        exists (
          select 1
          from public.food_stores s
          join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
          where s.id = t.store_id
            and mm.user_id = (select auth.uid())
            and mm.active
            and mm.role in ('owner','admin','manager')
        )
        or exists (
          select 1
          from public.food_staff fs
          where fs.store_id = t.store_id
            and fs.user_id = (select auth.uid())
            and fs.active
            and fs.role = 'owner'
        )
      )
  );
$$;

revoke all on function public.food_store_media_writable(text) from public, anon;
grant execute on function public.food_store_media_writable(text) to authenticated;

-- What WYNOS owes a store: its share of discounts on delivered, paid, not
-- refunded, not yet settled orders that the store's own team did not place.
create or replace function internal.food_platform_owed_rows(p_store_id uuid)
returns table (order_id uuid, platform_campaign_id uuid, amount numeric)
language sql
stable
set search_path = ''
as $$
  select foc.order_id, foc.platform_campaign_id, foc.platform_funded
  from public.food_order_campaigns foc
  join public.food_orders o on o.id = foc.order_id
  join public.food_stores s on s.id = o.store_id
  where o.store_id = p_store_id
    and foc.platform_funded > 0
    and foc.released_at is null
    and foc.settlement_id is null
    and o.status = 'delivered'
    and o.payment_status = 'paid'
    and o.refund_status <> 'refunded'
    and not exists (
      select 1 from public.merchant_memberships mm
      where mm.merchant_account_id = s.merchant_account_id and mm.user_id = o.buyer_id
    )
    and not exists (
      select 1 from public.food_staff fs
      where fs.store_id = o.store_id and fs.user_id = o.buyer_id
    )
$$;

revoke all on function internal.food_platform_owed_rows(uuid) from public, anon, authenticated;

drop function if exists public.admin_settle_platform_store(uuid, text, text);

create or replace function public.admin_settle_platform_store(
  p_store_id uuid,
  p_reference text,
  p_expected_amount numeric,
  p_expected_count integer,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_reference text := left(btrim(coalesce(p_reference, '')), 120);
  v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
  v_store public.food_stores%rowtype;
  v_amount numeric;
  v_count integer;
  v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can record WYNOS campaign payouts';
  end if;
  if v_reference = '' then
    raise exception 'transfer reference is required';
  end if;
  select * into v_store from public.food_stores where id = p_store_id for update;
  if not found then
    raise exception 'store not found';
  end if;

  -- Lock the owed rows so two admins cannot settle the same orders twice.
  perform 1 from public.food_order_campaigns foc
  where foc.order_id in (select r.order_id from internal.food_platform_owed_rows(p_store_id) r)
  for update;

  select coalesce(sum(r.amount), 0), count(*)::integer into v_amount, v_count
  from internal.food_platform_owed_rows(p_store_id) r;
  if v_count = 0 then
    raise exception 'nothing to settle';
  end if;
  -- WYN-213: record exactly what the admin saw and transferred. If more
  -- orders became owed after the page loaded, stop and let them reload.
  if p_expected_amount is null or p_expected_count is null
     or round(p_expected_amount, 2) <> round(v_amount, 2) or p_expected_count <> v_count then
    raise exception 'owed amount changed, reload and check before recording';
  end if;

  insert into public.food_platform_settlements (store_id, amount, order_count, reference, note, settled_by)
  values (p_store_id, v_amount, v_count, v_reference, v_note, v_admin)
  returning id into v_id;

  update public.food_order_campaigns foc set settlement_id = v_id
  where foc.order_id in (select r.order_id from internal.food_platform_owed_rows(p_store_id) r);

  insert into public.notifications (recipient_id, actor_id, type, reason)
  select mm.user_id, null, 'system',
    'WYNOS โอนส่วนลดแคมเปญคืนร้าน ' || v_store.name || ' แล้ว ' || to_char(v_amount, 'FM999,999,990.00') || ' บาท (' || v_count || ' ออเดอร์) อ้างอิง ' || v_reference
  from public.merchant_memberships mm
  where mm.merchant_account_id = v_store.merchant_account_id and mm.active and mm.role in ('owner', 'admin');

  perform internal.log_audit_event(
    v_admin, 'admin_platform_campaign_settled', null,
    jsonb_build_object('store_id', p_store_id, 'store_name', v_store.name, 'amount', v_amount,
      'order_count', v_count, 'reference', v_reference, 'settlement_id', v_id)
  );
  return v_id;
end;
$$;

revoke all on function public.admin_settle_platform_store(uuid, text, numeric, integer, text) from public, anon;
grant execute on function public.admin_settle_platform_store(uuid, text, numeric, integer, text) to authenticated;

-- One transfer slip, one top-up request.
create unique index if not exists food_ad_topups_slip_path_uidx on public.food_ad_topups(slip_path);
