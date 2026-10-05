-- WYNOS Maps missing-place suggestions v1
-- Authenticated users can suggest a missing public place. Suggestions never
-- become public Places until an admin explicitly approves them.

create table if not exists public.wynos_place_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  category text not null default 'place',
  address text,
  note text,
  latitude double precision not null,
  longitude double precision not null,
  status text not null default 'pending',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  place_id text references public.wynos_places(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint wynos_place_suggestions_name_length check (char_length(btrim(name)) between 1 and 160),
  constraint wynos_place_suggestions_category check (
    category in ('place','restaurant','store','building','residence','poi')
  ),
  constraint wynos_place_suggestions_address_length check (address is null or char_length(address) <= 1000),
  constraint wynos_place_suggestions_note_length check (note is null or char_length(note) <= 500),
  constraint wynos_place_suggestions_latitude check (latitude between -90 and 90),
  constraint wynos_place_suggestions_longitude check (longitude between -180 and 180),
  constraint wynos_place_suggestions_status check (status in ('pending','approved','rejected'))
);

create index if not exists wynos_place_suggestions_pending_idx
on public.wynos_place_suggestions(status, created_at desc);

create index if not exists wynos_place_suggestions_user_idx
on public.wynos_place_suggestions(user_id, created_at desc);

alter table public.wynos_place_suggestions enable row level security;

revoke all on table public.wynos_place_suggestions from anon, authenticated;
grant select, insert, update, delete on table public.wynos_place_suggestions to service_role;

drop trigger if exists wynos_place_suggestions_touch_updated_at on public.wynos_place_suggestions;
create trigger wynos_place_suggestions_touch_updated_at
before update on public.wynos_place_suggestions
for each row execute function public.food_touch_updated_at();

create or replace function public.submit_wynos_place_suggestion(
  p_name text,
  p_category text,
  p_address text,
  p_note text,
  p_latitude double precision,
  p_longitude double precision
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_name text := left(btrim(coalesce(p_name, '')), 160);
  v_category text := btrim(coalesce(p_category, 'place'));
  v_id uuid;
begin
  if v_user is null then
    raise exception 'authentication required';
  end if;
  if v_name = '' then
    raise exception 'place name is required';
  end if;
  if v_category not in ('place','restaurant','store','building','residence','poi') then
    raise exception 'invalid place category';
  end if;
  if p_latitude not between -90 and 90 or p_longitude not between -180 and 180 then
    raise exception 'invalid place location';
  end if;

  if (
    select count(*)
    from public.wynos_place_suggestions s
    where s.user_id = v_user
      and s.created_at >= now() - interval '24 hours'
  ) >= 10 then
    raise exception 'daily suggestion limit reached';
  end if;

  if exists (
    select 1
    from public.wynos_place_suggestions s
    where s.user_id = v_user
      and s.status = 'pending'
      and lower(s.name) = lower(v_name)
      and internal.food_distance_km(
        s.latitude, s.longitude, p_latitude, p_longitude
      ) <= 0.05
  ) then
    raise exception 'duplicate pending suggestion';
  end if;

  insert into public.wynos_place_suggestions(
    user_id, name, category, address, note, latitude, longitude
  ) values (
    v_user,
    v_name,
    v_category,
    nullif(left(btrim(coalesce(p_address, '')), 1000), ''),
    nullif(left(btrim(coalesce(p_note, '')), 500), ''),
    p_latitude,
    p_longitude
  )
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.submit_wynos_place_suggestion(
  text,text,text,text,double precision,double precision
) from public, anon;
grant execute on function public.submit_wynos_place_suggestion(
  text,text,text,text,double precision,double precision
) to authenticated;

create or replace function public.admin_wynos_place_suggestions(
  p_status text default 'pending',
  p_limit integer default 200
)
returns table (
  id uuid,
  user_id uuid,
  name text,
  category text,
  address text,
  note text,
  latitude double precision,
  longitude double precision,
  status text,
  place_id text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
begin
  if coalesce(internal.current_platform_role(), '') not in ('admin','moderator') then
    raise exception 'Not authorized';
  end if;

  return query
  select
    s.id, s.user_id, s.name, s.category, s.address, s.note,
    s.latitude, s.longitude, s.status, s.place_id, s.created_at
  from public.wynos_place_suggestions s
  where v_status is null or s.status = v_status
  order by
    case when s.status = 'pending' then 0 else 1 end,
    s.created_at desc
  limit v_limit;
end;
$$;

revoke all on function public.admin_wynos_place_suggestions(text,integer) from public, anon;
grant execute on function public.admin_wynos_place_suggestions(text,integer) to authenticated;

create or replace function public.admin_review_wynos_place_suggestion(
  p_suggestion_id uuid,
  p_decision text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_suggestion public.wynos_place_suggestions%rowtype;
  v_place_id text;
  v_decision text := lower(btrim(coalesce(p_decision, '')));
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can review WYNOS Place suggestions';
  end if;
  if v_decision not in ('approve','reject') then
    raise exception 'invalid review decision';
  end if;

  select * into v_suggestion
  from public.wynos_place_suggestions
  where id = p_suggestion_id
  for update;

  if not found then
    raise exception 'suggestion not found';
  end if;
  if v_suggestion.status <> 'pending' then
    raise exception 'suggestion already reviewed';
  end if;

  if v_decision = 'approve' then
    insert into public.wynos_places(
      name_th, category, address, latitude, longitude,
      source, source_ref, verification_status, is_active
    ) values (
      v_suggestion.name,
      v_suggestion.category,
      v_suggestion.address,
      v_suggestion.latitude,
      v_suggestion.longitude,
      'user_report',
      'suggestion:' || v_suggestion.id::text,
      'unverified',
      true
    )
    on conflict (source, source_ref) where source_ref is not null do update
    set name_th = excluded.name_th,
        category = excluded.category,
        address = excluded.address,
        latitude = excluded.latitude,
        longitude = excluded.longitude,
        is_active = true,
        updated_at = now()
    returning id into v_place_id;

    update public.wynos_place_suggestions
    set status = 'approved',
        reviewed_by = v_admin,
        reviewed_at = now(),
        place_id = v_place_id
    where id = v_suggestion.id;

    perform internal.log_audit_event(
      v_admin,
      'admin_wynos_place_saved',
      null,
      jsonb_build_object(
        'place_id', v_place_id,
        'suggestion_id', v_suggestion.id,
        'source', 'user_report'
      )
    );
  else
    update public.wynos_place_suggestions
    set status = 'rejected',
        reviewed_by = v_admin,
        reviewed_at = now()
    where id = v_suggestion.id;
  end if;

  return v_place_id;
end;
$$;

revoke all on function public.admin_review_wynos_place_suggestion(uuid,text)
from public, anon;
grant execute on function public.admin_review_wynos_place_suggestion(uuid,text)
to authenticated;
