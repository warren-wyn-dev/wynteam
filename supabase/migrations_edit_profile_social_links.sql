-- Founder-approved Edit Profile: persist Instagram / Twitter (X) / YouTube links.
-- Additive only; the existing profile page layout is intentionally unchanged.

begin;

alter table public.profiles
  add column if not exists social_links jsonb not null default '{}'::jsonb;

commit;
