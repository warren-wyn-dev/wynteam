-- Stripe Sandbox compatibility fields pulled from WYNOS Merchant readiness expectations.
-- Additive, sandbox-only. This is not a replacement for the full production migrations.
alter table public.food_stores
 add column if not exists latitude double precision,
 add column if not exists longitude double precision,
 add column if not exists business_schedule jsonb not null default '{}'::jsonb,
 add column if not exists prep_time_min_minutes integer not null default 15,
 add column if not exists prep_time_max_minutes integer not null default 30;
