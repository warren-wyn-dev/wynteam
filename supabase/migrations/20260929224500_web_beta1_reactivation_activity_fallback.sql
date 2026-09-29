-- WYNOS Web Beta 1 — activation fallback using the existing Web Push heartbeat.
-- The current production Web app refreshes an enabled Web Push token on a
-- later page load. Treat that refresh (after onboarding) as a return to WYNOS,
-- so the reactivation campaign can stop without requiring a new Web bundle.

create or replace function internal.activate_web_reactivation_from_push_token()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.platform <> 'web' then
    return new;
  end if;

  update internal.web_reactivation_state
  set
    activated_at = now(),
    lease_until = null,
    updated_at = now()
  where user_id = new.user_id
    and activated_at is null
    and registered_at <= now() - interval '10 minutes';

  return new;
end;
$$;

revoke all on function internal.activate_web_reactivation_from_push_token()
from public, anon, authenticated;

drop trigger if exists push_tokens_activate_web_reactivation_insert on public.push_tokens;
create trigger push_tokens_activate_web_reactivation_insert
after insert on public.push_tokens
for each row
execute function internal.activate_web_reactivation_from_push_token();

drop trigger if exists push_tokens_activate_web_reactivation_update on public.push_tokens;
create trigger push_tokens_activate_web_reactivation_update
after update of updated_at, user_id, platform on public.push_tokens
for each row
when (
  new.platform = 'web'
  and (
    old.user_id is distinct from new.user_id
    or old.platform is distinct from new.platform
    or old.updated_at is distinct from new.updated_at
  )
)
execute function internal.activate_web_reactivation_from_push_token();
