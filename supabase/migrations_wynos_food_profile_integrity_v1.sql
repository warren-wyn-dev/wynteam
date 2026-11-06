-- Keep permanent Auth users aligned with public.profiles so Food foreign keys
-- cannot fail for a valid signed-in customer. Anonymous users are intentionally
-- left without profiles until they are upgraded to permanent accounts.

create schema if not exists private;

create or replace function private.ensure_permanent_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;

  insert into public.profiles (id, created_at)
  values (new.id, coalesce(new.created_at, now()))
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function private.ensure_permanent_user_profile() from public, anon, authenticated;

drop trigger if exists wynos_profile_on_auth_insert on auth.users;
create trigger wynos_profile_on_auth_insert
after insert on auth.users
for each row
when (coalesce(new.is_anonymous, false) = false)
execute function private.ensure_permanent_user_profile();

drop trigger if exists wynos_profile_on_anonymous_upgrade on auth.users;
create trigger wynos_profile_on_anonymous_upgrade
after update of is_anonymous on auth.users
for each row
when (coalesce(new.is_anonymous, false) = false)
execute function private.ensure_permanent_user_profile();

insert into public.profiles (id, created_at)
select u.id, coalesce(u.created_at, now())
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
  and coalesce(u.is_anonymous, false) = false
on conflict (id) do nothing;
