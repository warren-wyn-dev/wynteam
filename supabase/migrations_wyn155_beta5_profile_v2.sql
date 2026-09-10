-- WYN-155 / WYNOS v1.0.0 Beta5 Profile V2
-- Cover image metadata + atomic max-3 pinned Drops.

begin;

alter table public.profiles
  add column if not exists cover_url text;

alter table public.drops
  add column if not exists profile_pin_position smallint;

alter table public.drops
  drop constraint if exists drops_profile_pin_position_check;
alter table public.drops
  add constraint drops_profile_pin_position_check
  check (profile_pin_position is null or profile_pin_position between 1 and 3);

create unique index if not exists drops_author_profile_pin_position_unique
  on public.drops(author_id, profile_pin_position)
  where profile_pin_position is not null and deleted_at is null;

create or replace function public.clear_profile_pin_on_soft_delete()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.profile_pin_position := null;
  end if;
  return new;
end;
$$;

drop trigger if exists drops_clear_profile_pin_on_soft_delete on public.drops;
create trigger drops_clear_profile_pin_on_soft_delete
before update of deleted_at on public.drops
for each row
execute function public.clear_profile_pin_on_soft_delete();

create or replace function public.pin_profile_drop(p_drop_id uuid)
returns smallint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing smallint;
  v_position smallint;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('profile-pin:' || v_user_id::text, 0)
  );

  select d.profile_pin_position
    into v_existing
  from public.drops d
  where d.id = p_drop_id
    and d.author_id = v_user_id
    and d.deleted_at is null;

  if not found then
    raise exception 'drop_not_owned_or_not_found' using errcode = '42501';
  end if;

  if v_existing is not null then
    return v_existing;
  end if;

  select s.position::smallint
    into v_position
  from generate_series(1, 3) as s(position)
  where not exists (
    select 1
    from public.drops d
    where d.author_id = v_user_id
      and d.deleted_at is null
      and d.profile_pin_position = s.position
  )
  order by s.position
  limit 1;

  if v_position is null then
    raise exception 'profile_pin_limit_reached' using errcode = 'P0001';
  end if;

  update public.drops
  set profile_pin_position = v_position
  where id = p_drop_id
    and author_id = v_user_id
    and deleted_at is null;

  return v_position;
end;
$$;

create or replace function public.unpin_profile_drop(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  update public.drops
  set profile_pin_position = null
  where id = p_drop_id
    and author_id = v_user_id;

  if not found then
    raise exception 'drop_not_owned_or_not_found' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.pin_profile_drop(uuid) from public;
revoke all on function public.unpin_profile_drop(uuid) from public;
grant execute on function public.pin_profile_drop(uuid) to authenticated;
grant execute on function public.unpin_profile_drop(uuid) to authenticated;

commit;
