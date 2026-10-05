-- WYNOS Push per app + 4-digit Food order numbers
-- Founder approval: 2026-10-05 ("อนุมัติ").
--
-- 1. push_tokens.app records which installed app registered a device token,
--    so send-push-notification sends Social, Food and Merchant notifications
--    only to their own app instead of every app on the phone.
--    NULL = a token registered before this change; it is treated as the
--    Social app until the app re-registers it on the next open.
-- 2. New Food orders are numbered WF0015, WF0016, ... (4 digits). Past orders
--    keep their WF000001-style numbers. Past 9999 the number grows to 5+
--    digits instead of being cut (lpad truncates longer strings).
--
-- Additive only: one nullable column with a check, one function body.
-- ROLLBACK: alter table public.push_tokens drop column app;
--   and re-run public.food_next_order_number from migrations_wynos_food_merchant_v1.sql.

alter table public.push_tokens
  add column if not exists app text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'push_tokens_app_check'
      and conrelid = 'public.push_tokens'::regclass
  ) then
    alter table public.push_tokens
      add constraint push_tokens_app_check
      check (app is null or app in ('social', 'food', 'merchant'));
  end if;
end;
$$;

create or replace function public.food_next_order_number()
returns text
language sql
volatile
set search_path = public
as $$
  select 'WF' || lpad(n, greatest(4, length(n)), '0')
  from (select nextval('public.food_order_number_seq')::text as n) s;
$$;

-- Let the API see push_tokens.app right away.
notify pgrst, 'reload schema';
