-- WYNOS Food + Merchant launch hardening v1
--
-- 1) Conservatively backfill the only legacy address field we can recover
--    without guessing. Province/district/subdistrict/postal code are NOT
--    inferred from free text; the Food UI requires the customer to review and
--    complete those fields before checkout.
-- 2) Correct production privilege drift for food_store_open_status(uuid).
--    The public storefront does not call this RPC anonymously; the existing
--    production-readiness hardening and tests require authenticated-only use.
--
-- The three public share RPCs remain intentionally executable by anon:
--   food_store_id_by_share_code(text)
--   food_store_share_preview(uuid)
--   food_record_share_open(text)
-- They expose only published-store public/share data and are covered by
-- dedicated share-link tests.
--
-- ROLLBACK:
--   grant execute on function public.food_store_open_status(uuid) to anon;
-- Address_line1 backfill is intentionally not rolled back because it only
-- copies the already-stored legacy address into its normalized compatibility
-- field when that field is blank.

update public.food_customer_addresses
set address_line1 = nullif(btrim(address), '')
where nullif(btrim(coalesce(address_line1, '')), '') is null
  and nullif(btrim(coalesce(address, '')), '') is not null;

revoke execute on function public.food_store_open_status(uuid) from public, anon;
grant execute on function public.food_store_open_status(uuid) to authenticated;
