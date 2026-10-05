-- WYNOS Maps saved places v1: Home, Work and Favorites per signed-in user.
--
-- Owner-only data. The table is not reachable through PostgREST at all
-- (RLS on, no policies, no table grants); every read and write goes through
-- the SECURITY DEFINER RPCs below, which scope by auth.uid().
-- Additive only: one new table and three new functions.
-- ROLLBACK: drop function public.wynos_saved_places_list(),
--   public.wynos_save_place(text,text,text,text,text,double precision,double precision),
--   public.wynos_delete_saved_place(uuid); drop table public.wynos_saved_places;

create table if not exists public.wynos_saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'favorite',
  label text not null,
  place_id text references public.wynos_places(id) on delete set null,
  name text not null,
  address text,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wynos_saved_places_kind check (kind in ('home', 'work', 'favorite')),
  constraint wynos_saved_places_label_length check (char_length(btrim(label)) between 1 and 80),
  constraint wynos_saved_places_name_length check (char_length(btrim(name)) between 1 and 160),
  constraint wynos_saved_places_address_length check (address is null or char_length(address) <= 300),
  constraint wynos_saved_places_latitude check (latitude between -90 and 90),
  constraint wynos_saved_places_longitude check (longitude between -180 and 180)
);

create unique index if not exists wynos_saved_places_one_home_work_idx
on public.wynos_saved_places(user_id, kind)
where kind in ('home', 'work');

create index if not exists wynos_saved_places_user_idx
on public.wynos_saved_places(user_id, created_at desc);

drop trigger if exists wynos_saved_places_touch_updated_at on public.wynos_saved_places;
create trigger wynos_saved_places_touch_updated_at
before update on public.wynos_saved_places
for each row execute function public.food_touch_updated_at();

alter table public.wynos_saved_places enable row level security;
revoke all on table public.wynos_saved_places from public, anon, authenticated;

create or replace function public.wynos_saved_places_list()
returns table (
  id uuid,
  kind text,
  label text,
  place_id text,
  name text,
  address text,
  latitude double precision,
  longitude double precision
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  return query
  select s.id, s.kind, s.label, s.place_id, s.name, s.address, s.latitude, s.longitude
  from public.wynos_saved_places s
  where s.user_id = auth.uid()
  order by
    case s.kind when 'home' then 0 when 'work' then 1 else 2 end,
    s.created_at desc
  limit 60;
end;
$$;

-- Home and Work are one per user and are replaced in place; Favorites are
-- capped at 50 and a favorite at the same point with the same name is reused.
create or replace function public.wynos_save_place(
  p_kind text,
  p_label text,
  p_place_id text,
  p_name text,
  p_address text,
  p_latitude double precision,
  p_longitude double precision
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_kind text := lower(btrim(coalesce(p_kind, '')));
  v_name text := left(btrim(coalesce(p_name, '')), 160);
  v_label text := left(btrim(coalesce(p_label, '')), 80);
  v_address text := nullif(left(btrim(coalesce(p_address, '')), 300), '');
  v_place_id text;
  v_id uuid;
begin
  if v_user is null then
    raise exception 'authentication required';
  end if;
  if v_kind not in ('home', 'work', 'favorite') then
    raise exception 'invalid saved place kind';
  end if;
  if v_name = '' then
    raise exception 'saved place name required';
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'invalid saved place location';
  end if;
  if v_label = '' then
    v_label := case v_kind when 'home' then 'บ้าน' when 'work' then 'ที่ทำงาน' else v_name end;
  end if;

  -- Only link to a place that exists and is visible; otherwise keep the copy.
  select p.id into v_place_id
  from public.wynos_places p
  where p.id = nullif(btrim(coalesce(p_place_id, '')), '') and p.is_active;

  if v_kind in ('home', 'work') then
    insert into public.wynos_saved_places as s (user_id, kind, label, place_id, name, address, latitude, longitude)
    values (v_user, v_kind, v_label, v_place_id, v_name, v_address, p_latitude, p_longitude)
    on conflict (user_id, kind) where kind in ('home', 'work') do update
      set label = excluded.label,
          place_id = excluded.place_id,
          name = excluded.name,
          address = excluded.address,
          latitude = excluded.latitude,
          longitude = excluded.longitude
    returning s.id into v_id;
    return v_id;
  end if;

  select s.id into v_id
  from public.wynos_saved_places s
  where s.user_id = v_user
    and s.kind = 'favorite'
    and s.name = v_name
    and abs(s.latitude - p_latitude) < 0.00001
    and abs(s.longitude - p_longitude) < 0.00001
  limit 1;
  if v_id is not null then
    return v_id;
  end if;

  if (select count(*) from public.wynos_saved_places s where s.user_id = v_user and s.kind = 'favorite') >= 50 then
    raise exception 'saved place limit reached';
  end if;

  insert into public.wynos_saved_places (user_id, kind, label, place_id, name, address, latitude, longitude)
  values (v_user, 'favorite', v_label, v_place_id, v_name, v_address, p_latitude, p_longitude)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.wynos_delete_saved_place(p_id uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  delete from public.wynos_saved_places s
  where s.id = p_id and s.user_id = auth.uid();
  return found;
end;
$$;

revoke all on function public.wynos_saved_places_list() from public, anon;
revoke all on function public.wynos_save_place(text,text,text,text,text,double precision,double precision) from public, anon;
revoke all on function public.wynos_delete_saved_place(uuid) from public, anon;
grant execute on function public.wynos_saved_places_list() to authenticated;
grant execute on function public.wynos_save_place(text,text,text,text,text,double precision,double precision) to authenticated;
grant execute on function public.wynos_delete_saved_place(uuid) to authenticated;
