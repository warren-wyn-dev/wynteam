-- =====================================================================
-- Web Beta2 — WYN-188 / WYN-189: per-account display preferences
--
-- Founder-approved spec: .wyn/docs/product/wyn-188-189-web-theme-and-language.md
-- Production apply needs its own Founder approval (AGENTS.md Change Control).
-- Additive and idempotent: one new owner-only table, no existing data touched.
--
-- Why a new table, not profiles/profile_private:
-- - profiles is readable by other users; a display preference is private.
-- - Upserting into profile_private creates a row with
--   onboarding_completed=false for web users who have none, which the Flutter
--   onboarding resume logic reads. This table has no such side effect.
-- NULL means "not chosen": theme follows the phone, language follows the
-- device language (the web decides; the Push function reads language here).
-- =====================================================================

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  theme_preference text check (theme_preference in ('system', 'light', 'dark')),
  language_preference text check (language_preference in ('th', 'en')),
  updated_at timestamptz not null default now()
);

alter table public.user_preferences enable row level security;

revoke all on public.user_preferences from anon;
grant select, insert, update on public.user_preferences to authenticated;
grant all on public.user_preferences to service_role;

drop policy if exists "Users read their own preferences" on public.user_preferences;
create policy "Users read their own preferences"
  on public.user_preferences for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "Users insert their own preferences" on public.user_preferences;
create policy "Users insert their own preferences"
  on public.user_preferences for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "Users update their own preferences" on public.user_preferences;
create policy "Users update their own preferences"
  on public.user_preferences for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create or replace function internal.touch_user_preferences()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

revoke all on function internal.touch_user_preferences() from public, anon, authenticated;

drop trigger if exists user_preferences_touch on public.user_preferences;
create trigger user_preferences_touch
  before update on public.user_preferences
  for each row execute function internal.touch_user_preferences();
