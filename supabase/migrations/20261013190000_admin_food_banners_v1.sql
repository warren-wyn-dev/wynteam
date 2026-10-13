
-- Food homepage campaign banners: opt-in, no banner published by migration.
-- Public RPC returns only active, scheduled content. Admin writes must pass food:edit
-- inside Postgres. Images upload to a separately permissioned public bucket.
-- Rollback: see supabase/rollbacks/20261013190000_admin_food_banners_v1_rollback.sql

create table if not exists public.food_home_banners (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) between 2 and 90),
  subtitle text check (subtitle is null or char_length(subtitle) <= 180),
  image_path text not null check (image_path ~ '^banners/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|jpeg|webp)$'),
  destination_store_id uuid references public.food_stores(id) on delete set null,
  sort_order integer not null default 100 check (sort_order between 0 and 9999),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default false,
  version integer not null default 1 check (version >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_home_banners_schedule check (ends_at is null or ends_at > starts_at)
);
create index if not exists food_home_banners_active_schedule_idx
  on public.food_home_banners(is_active,starts_at,ends_at,sort_order);
alter table public.food_home_banners enable row level security;
revoke all on public.food_home_banners from public, anon, authenticated;

create table if not exists public.food_home_banner_edits (
 id uuid primary key default gen_random_uuid(),
 banner_id uuid not null references public.food_home_banners(id) on delete cascade,
 actor_id uuid not null references auth.users(id),
 reason text not null check (char_length(reason) between 5 and 300),
 before_state jsonb,
 after_state jsonb not null,
 created_at timestamptz not null default now()
);
create index if not exists food_banner_edits_latest_idx on public.food_home_banner_edits(banner_id,created_at desc);
alter table public.food_home_banner_edits enable row level security;
revoke all on public.food_home_banner_edits from public,anon,authenticated;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('food-banners','food-banners',true,5242880,array['image/png','image/jpeg','image/webp']::text[])
on conflict (id) do nothing;

create or replace function public.food_banner_admin_can_edit()
returns boolean language sql stable security definer set search_path=''
as $$ select (select auth.uid()) is not null and internal.has_admin_permission('food','edit') $$;
revoke all on function public.food_banner_admin_can_edit() from public,anon;
grant execute on function public.food_banner_admin_can_edit() to authenticated;

drop policy if exists "Food banner Admin upload" on storage.objects;
create policy "Food banner Admin upload" on storage.objects
  for insert to authenticated with check (
    bucket_id='food-banners'
    and public.food_banner_admin_can_edit()
    and name ~ '^banners/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|jpeg|webp)$'
  );
-- No object update or delete policy. Each upload creates an immutable unique image.
-- Archived banners simply stop displaying. Object cleanup requires a separate reviewed process.

create or replace function public.food_active_home_banners()
returns jsonb language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', x.id, 'title', x.title, 'subtitle', x.subtitle,
    'image_path', x.image_path, 'destination_store_id', x.destination_store_id
  ) order by x.sort_order,x.created_at desc),'[]'::jsonb)
  from (
    select b.* from public.food_home_banners b
    left join public.food_stores s on s.id=b.destination_store_id
    where b.is_active and b.starts_at <= now()
      and (b.ends_at is null or b.ends_at > now())
      and (b.destination_store_id is null or (s.is_published and s.admin_suspended_at is null))
    order by b.sort_order, b.created_at desc limit 8
  ) x;
$$;
revoke all on function public.food_active_home_banners() from public;
grant execute on function public.food_active_home_banners() to anon,authenticated;

create or replace function public.admin_food_home_banners()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_result jsonb;
begin
  if not internal.has_admin_permission('food','view') then raise exception 'Not authorized'; end if;
  select coalesce(jsonb_agg(
    to_jsonb(b) order by b.sort_order,b.created_at desc
  ),'[]'::jsonb) into v_result
  from public.food_home_banners b;
  return v_result;
end;
$$;
revoke all on function public.admin_food_home_banners() from public,anon;
grant execute on function public.admin_food_home_banners() to authenticated;

create or replace function public.admin_save_food_home_banner(
  p_id uuid, p_expected_version integer, p_title text, p_subtitle text, p_image_path text,
  p_destination_store_id uuid, p_sort_order integer, p_starts_at timestamptz,
  p_ends_at timestamptz, p_is_active boolean, p_reason text
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
  v_before jsonb;
  v_after jsonb;
  v_item public.food_home_banners%rowtype;
  v_id uuid;
  v_reason text := btrim(coalesce(p_reason,''));
begin
  if not internal.has_admin_permission('food','edit') then raise exception 'Not authorized'; end if;
  if (select auth.uid()) is null then raise exception 'Not authorized'; end if;
  if char_length(v_reason) not between 5 and 300 then raise exception 'Reason must be 5-300 characters'; end if;
  if p_title is null or char_length(btrim(p_title)) not between 2 and 90
    or (p_subtitle is not null and char_length(p_subtitle)>180)
    or p_image_path is null
    or p_image_path !~ '^banners/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|jpeg|webp)$'
    or p_sort_order is null or p_sort_order not between 0 and 9999
    or p_starts_at is null or (p_ends_at is not null and p_ends_at<=p_starts_at)
    or p_is_active is null
  then raise exception 'Invalid banner configuration'; end if;
  if p_destination_store_id is not null and not exists (
    select 1 from public.food_stores where id=p_destination_store_id
  ) then raise exception 'Destination store not found'; end if;
  -- Uploaded files are immutable and must already exist before a live banner can reference one.
  if not exists (
    select 1 from storage.objects o
    where o.bucket_id = 'food-banners' and o.name = p_image_path
  ) then raise exception 'Upload a banner image before saving'; end if;

  if p_id is null then
    if p_expected_version is not null then raise exception 'New banner must not provide version'; end if;
    insert into public.food_home_banners(
      title,subtitle,image_path,destination_store_id,sort_order,starts_at,ends_at,is_active
    ) values (btrim(p_title),nullif(btrim(coalesce(p_subtitle,'')),''),p_image_path,
      p_destination_store_id,p_sort_order,p_starts_at,p_ends_at,p_is_active)
    returning * into v_item;
    v_before := null;
  else
    select * into v_item from public.food_home_banners where id=p_id for update;
    if not found then raise exception 'Banner not found'; end if;
    if p_expected_version is distinct from v_item.version
      then raise exception 'Banner changed; reload before saving'; end if;
    v_before := to_jsonb(v_item);
    update public.food_home_banners set
      title=btrim(p_title),
      subtitle=nullif(btrim(coalesce(p_subtitle,'')),''),
      image_path=p_image_path,
      destination_store_id=p_destination_store_id,
      sort_order=p_sort_order,
      starts_at=p_starts_at,
      ends_at=p_ends_at,
      is_active=p_is_active,
      version=version+1,
      updated_at=now()
    where id=p_id returning * into v_item;
  end if;
  v_after := to_jsonb(v_item);
  insert into public.food_home_banner_edits(banner_id,actor_id,reason,before_state,after_state)
    values (v_item.id,(select auth.uid()),v_reason,v_before,v_after);
  return v_after;
end;
$$;
revoke all on function public.admin_save_food_home_banner(uuid,integer,text,text,text,uuid,integer,timestamptz,timestamptz,boolean,text) from public,anon;
grant execute on function public.admin_save_food_home_banner(uuid,integer,text,text,text,uuid,integer,timestamptz,timestamptz,boolean,text) to authenticated;

create or replace function public.admin_food_banner_history(p_banner_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_result jsonb;
begin
  if not internal.has_admin_permission('food','view') then raise exception 'Not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'actor_id', x.actor_id, 'reason', x.reason, 'before', x.before_state,
    'after', x.after_state, 'created_at', x.created_at
  ) order by x.created_at desc),'[]'::jsonb)
  into v_result from (select * from public.food_home_banner_edits
    where banner_id=p_banner_id order by created_at desc limit 20) x;
  return v_result;
end;
$$;
revoke all on function public.admin_food_banner_history(uuid) from public,anon;
grant execute on function public.admin_food_banner_history(uuid) to authenticated;
