-- WYNOS Merchant Campaign Center total consistency v1.
-- Follow-up hardening for production databases where Campaign Center v1 is already applied.

alter table public.food_orders
  drop constraint if exists food_orders_total_consistency;

alter table public.food_orders
  add constraint food_orders_total_consistency
  check (
    total = subtotal - campaign_discount + delivery_fee - delivery_discount
  );
