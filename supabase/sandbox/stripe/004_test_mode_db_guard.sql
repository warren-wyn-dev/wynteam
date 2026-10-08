-- Sandbox-only invariants: no live Stripe account mappings or ledger rows.
do $guard$
begin
 if not exists(select 1 from pg_constraint where conrelid='public.food_stripe_accounts'::regclass and conname='sandbox_stripe_accounts_test_only') then
  alter table public.food_stripe_accounts add constraint sandbox_stripe_accounts_test_only check(livemode is false);
 end if;
 if not exists(select 1 from pg_constraint where conrelid='public.food_stripe_payments'::regclass and conname='sandbox_stripe_payments_test_only') then
  alter table public.food_stripe_payments add constraint sandbox_stripe_payments_test_only check(livemode is false);
 end if;
end $guard$;
