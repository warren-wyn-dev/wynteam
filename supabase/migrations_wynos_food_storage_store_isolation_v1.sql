-- WYN-194: isolate WYNOS Food storage per store.
--
-- Before this migration the food-private and food-public write/read policies
-- used public.food_has_merchant_access(null), which is true for a member of ANY
-- store. Once a second store joins, its staff could read other stores' customer
-- payment slips and delivery photos, and overwrite or delete other stores'
-- public media, including the PromptPay QR customers pay to.
--
-- After this migration:
-- food-private
--   * customers keep their existing access (own <uid>/slips/... folder, and
--     delivery photos of their own orders);
--   * merchants read only slips and delivery photos of orders in their store;
--   * merchants upload only to delivery/<order_id>/ for an order of their store
--     that is out for delivery, with a delivery-capable role;
--   * merchants can no longer update or delete private evidence.
-- food-public
--   * public read is unchanged;
--   * writes are limited to stores/<store_id>/... for owner/admin/manager of
--     that store (the same roles that manage menu and store settings).
--
-- Only storage.objects policies are replaced. No object or row is changed.
-- Rollback: re-run the food-private policies from
-- migrations_wynos_food_customer_access_gate_v2.sql and the food-public write
-- policies from migrations_wynos_food_merchant_v1.sql.

-- food-private --------------------------------------------------------------

drop policy if exists "Food private media readable by rollout gate" on storage.objects;
create policy "Food private media readable by rollout gate"
on storage.objects for select to authenticated
using (
  bucket_id='food-private'
  and (
    (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
    )
    or (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = 'delivery'
      and exists (
        select 1
        from public.food_orders o
        where o.id::text = (storage.foldername(name))[2]
          and o.buyer_id = auth.uid()
      )
    )
    or (
      (storage.foldername(name))[1] = 'delivery'
      and exists (
        select 1
        from public.food_orders o
        where o.id::text = (storage.foldername(name))[2]
          and public.food_has_merchant_access(o.store_id)
      )
    )
    or (
      (storage.foldername(name))[2] = 'slips'
      and exists (
        select 1
        from public.food_orders o
        where o.buyer_id::text = (storage.foldername(name))[1]
          and (
            o.id::text = (storage.foldername(name))[3]
            or o.payment_slip_path = name
          )
          and public.food_has_merchant_access(o.store_id)
      )
    )
  )
);

drop policy if exists "Food private upload by rollout gate" on storage.objects;
create policy "Food private upload by rollout gate"
on storage.objects for insert to authenticated
with check (
  bucket_id='food-private'
  and (
    (
      public.food_customer_access_enabled()
      and (storage.foldername(name))[1] = auth.uid()::text
      and (storage.foldername(name))[2] = 'slips'
    )
    or (
      (storage.foldername(name))[1] = 'delivery'
      and array_length(storage.foldername(name), 1) = 2
      and exists (
        select 1
        from public.food_orders o
        where o.id::text = (storage.foldername(name))[2]
          and o.status = 'out_for_delivery'
          and public.merchant_has_store_role(o.store_id, array['owner','admin','manager','orders','delivery'])
      )
    )
  )
);

drop policy if exists "Food private update by rollout gate" on storage.objects;
create policy "Food private update by rollout gate"
on storage.objects for update to authenticated
using (
  bucket_id='food-private'
  and public.food_customer_access_enabled()
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'slips'
)
with check (
  bucket_id='food-private'
  and public.food_customer_access_enabled()
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'slips'
);

drop policy if exists "Food private delete by rollout gate" on storage.objects;
create policy "Food private delete by rollout gate"
on storage.objects for delete to authenticated
using (
  bucket_id='food-private'
  and public.food_customer_access_enabled()
  and (storage.foldername(name))[1] = auth.uid()::text
  and (storage.foldername(name))[2] = 'slips'
);

-- food-public ---------------------------------------------------------------

drop policy if exists "Food public media merchant upload" on storage.objects;
create policy "Food public media merchant upload"
on storage.objects for insert to authenticated
with check (
  bucket_id='food-public'
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.food_stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.merchant_has_store_role(s.id, array['owner','admin','manager'])
  )
);

drop policy if exists "Food public media merchant update" on storage.objects;
create policy "Food public media merchant update"
on storage.objects for update to authenticated
using (
  bucket_id='food-public'
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.food_stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.merchant_has_store_role(s.id, array['owner','admin','manager'])
  )
)
with check (
  bucket_id='food-public'
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.food_stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.merchant_has_store_role(s.id, array['owner','admin','manager'])
  )
);

drop policy if exists "Food public media merchant delete" on storage.objects;
create policy "Food public media merchant delete"
on storage.objects for delete to authenticated
using (
  bucket_id='food-public'
  and (storage.foldername(name))[1] = 'stores'
  and exists (
    select 1
    from public.food_stores s
    where s.id::text = (storage.foldername(name))[2]
      and public.merchant_has_store_role(s.id, array['owner','admin','manager'])
  )
);
