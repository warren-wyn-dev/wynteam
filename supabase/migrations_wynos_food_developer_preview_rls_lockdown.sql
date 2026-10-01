-- Complete RLS/storage lockdown for the closed WYNOS Food Developer Preview.
-- Merchant staff retain operational access; customer-side reads/writes require developer status.

create or replace function public.food_can_view_order(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.food_orders o
    where o.id = p_order_id
      and (
        public.food_has_merchant_access(o.store_id)
        or (
          o.buyer_id = auth.uid()
          and public.is_developer_account()
          and public.food_is_permanent_account()
        )
      )
  );
$$;

drop policy if exists "Food orders visible to buyer and merchant" on public.food_orders;
create policy "Food orders visible to developer buyer and merchant"
on public.food_orders for select to authenticated
using (
  public.food_has_merchant_access(store_id)
  or (
    buyer_id = auth.uid()
    and public.is_developer_account()
    and public.food_is_permanent_account()
  )
);

drop policy if exists "Food order items visible to buyer and merchant" on public.food_order_items;
create policy "Food order items visible to developer buyer and merchant"
on public.food_order_items for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food order events visible to buyer and merchant" on public.food_order_events;
create policy "Food order events visible to developer buyer and merchant"
on public.food_order_events for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food delivery proofs visible to buyer and merchant" on public.food_delivery_proofs;
create policy "Food delivery proofs visible to developer buyer and merchant"
on public.food_delivery_proofs for select to authenticated
using (public.food_can_view_order(order_id));

drop policy if exists "Food private media readable" on storage.objects;
create policy "Food private media readable"
on storage.objects for select to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.is_developer_account()
      and public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
    )
    or (
      public.is_developer_account()
      and public.food_is_permanent_account()
      and (storage.foldername(name))[1] = 'delivery'
      and exists (
        select 1
        from public.food_orders o
        where o.id::text = (storage.foldername(name))[2]
          and o.buyer_id = auth.uid()
      )
    )
  )
);

drop policy if exists "Food private customer and merchant upload" on storage.objects;
create policy "Food private developer customer and merchant upload"
on storage.objects for insert to authenticated
with check (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.is_developer_account()
      and public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

drop policy if exists "Food private customer and merchant update" on storage.objects;
create policy "Food private developer customer and merchant update"
on storage.objects for update to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.is_developer_account()
      and public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
)
with check (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.is_developer_account()
      and public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

drop policy if exists "Food private customer and merchant delete" on storage.objects;
create policy "Food private developer customer and merchant delete"
on storage.objects for delete to authenticated
using (
  bucket_id='food-private'
  and (
    public.food_has_merchant_access(null)
    or (
      public.is_developer_account()
      and public.food_is_permanent_account()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
  )
);

revoke all on function public.food_can_view_order(uuid) from public, anon;
grant execute on function public.food_can_view_order(uuid) to authenticated;
