-- =====================================================================
-- Web Beta1 QA — referral_code guard (LOW)
--
-- Founder runs this via the Supabase Dashboard SQL editor; no AI applies
-- production SQL (AGENTS.md Change Control). Idempotent: safe to re-run.
--
-- profiles.referral_code is generated server-side on insert
-- (set_referral_code_on_profile), but the profiles UPDATE policy let an
-- owner overwrite it with any unused string, e.g. a vanity code such as
-- "WYNOS" or "ADMIN" that impersonates an official invite. Only trusted
-- server roles may change it now; the one-time backfill of a NULL code
-- (run as postgres) keeps working.
-- =====================================================================

create or replace function internal.profiles_guard_referral_code()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $function$
begin
  if current_user not in ('postgres', 'service_role', 'supabase_admin')
     and new.referral_code is distinct from old.referral_code then
    raise exception 'Only trusted server roles may modify profiles.referral_code'
      using errcode = '42501';
  end if;
  return new;
end;
$function$;

revoke all on function internal.profiles_guard_referral_code() from public, anon, authenticated;

drop trigger if exists profiles_guard_referral_code on public.profiles;
create trigger profiles_guard_referral_code
  before update on public.profiles
  for each row execute function internal.profiles_guard_referral_code();
