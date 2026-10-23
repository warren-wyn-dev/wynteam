-- ZOKY staging seed: synthetic data only (no real people, stores, or payment data).
-- Idempotent. __OWNER__ is replaced by e2e.mjs with the E2E owner's auth user id.
-- Store 'e2e02' gets its Stripe TEST account through merchant-stripe-connect
-- (e2e.mjs setup); store 'e2e04' never has one (Stripe-only order gate check).
-- Location: inside the seeded Maha Sarakham service area.
insert into public.food_rollout_settings(id, public_enabled) values (true, true)
  on conflict (id) do update set public_enabled = true, updated_at = now();

insert into public.profiles(id, username, display_name)
  values ('__OWNER__', 'zoky_e2e_owner', 'E2E Owner')
  on conflict (id) do nothing;

insert into public.merchant_accounts(id, business_name, status)
  values ('00000000-0000-4000-8000-0000000e2e01', 'ร้านทดสอบ E2E', 'approved')
  on conflict (id) do nothing;

insert into public.merchant_memberships(merchant_account_id, user_id, role, active)
  values ('00000000-0000-4000-8000-0000000e2e01', '__OWNER__', 'owner', true)
  on conflict do nothing;

insert into public.food_stores(id, slug, name, merchant_account_id, is_open, is_published,
    latitude, longitude, delivery_radius_km, delivery_fee)
  values
    ('00000000-0000-4000-8000-0000000e2e02', 'e2e-test', 'ร้านทดสอบ E2E',
     '00000000-0000-4000-8000-0000000e2e01', true, true, 16.1849, 103.3007, 10, 0),
    ('00000000-0000-4000-8000-0000000e2e04', 'e2e-no-stripe', 'ร้านทดสอบ ไม่มี Stripe',
     '00000000-0000-4000-8000-0000000e2e01', true, true, 16.1849, 103.3007, 10, 0)
  on conflict (id) do update set is_open = true, is_published = true;

insert into public.food_menu_items(id, store_id, name, price)
  values
    ('00000000-0000-4000-8000-0000000e2e03', '00000000-0000-4000-8000-0000000e2e02', 'ข้าวผัดทดสอบ', 50),
    ('00000000-0000-4000-8000-0000000e2e05', '00000000-0000-4000-8000-0000000e2e04', 'ข้าวผัดทดสอบ', 50)
  on conflict (id) do nothing;
