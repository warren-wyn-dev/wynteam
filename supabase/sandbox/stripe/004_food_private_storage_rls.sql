-- Sandbox-only private Food storage. Payment slips remain immutable once uploaded.
create policy "WYNOS sandbox food private select" on storage.objects
for select to authenticated using (
 bucket_id = 'food-private' and (
   (storage.foldername(name))[1] = (select auth.uid())::text
   or exists (
     select 1 from public.food_orders o
     where o.payment_slip_path = name and public.food_has_merchant_access(o.store_id)
   )
   or (
     (storage.foldername(name))[1] = 'delivery' and exists (
       select 1 from public.food_orders o
       where o.id = public.food_path_uuid((storage.foldername(name))[2])
         and (o.buyer_id = (select auth.uid()) or public.food_has_merchant_access(o.store_id))
     )
   )
 )
);
create policy "WYNOS sandbox food private insert" on storage.objects
for insert to authenticated with check (
 bucket_id = 'food-private' and (
   ((storage.foldername(name))[1] = (select auth.uid())::text and (storage.foldername(name))[2] = 'slips')
   or (
     (storage.foldername(name))[1] = 'delivery' and exists (
       select 1 from public.food_orders o
       where o.id = public.food_path_uuid((storage.foldername(name))[2])
         and o.status = 'out_for_delivery'
         and public.merchant_has_store_role(o.store_id,array['owner','admin','manager','orders','delivery'])
     )
   )
 )
);
