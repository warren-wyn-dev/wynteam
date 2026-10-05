-- WYNOS Maps place photos v1: signed-in users add photos to WYNOS Places;
-- photos become visible to others only after an admin approves them.
--
-- Storage: private bucket `place-photos`, objects at `<uploader uid>/<uuid>.jpg`.
-- The web client compresses and re-encodes every photo before upload (which
-- also drops EXIF/GPS); the bucket limits size and MIME type, and
-- validate-upload sniffs the bytes once `place-photos` is in IMAGE_BUCKETS.
-- Data: wynos_place_photos is RPC-only (RLS on, no policies, no table grants).
-- Additive only.
-- ROLLBACK: drop the five public functions and internal.wynos_place_photo_is_approved, drop the three "Place photos" storage policies,
--   drop table public.wynos_place_photos; empty and delete the bucket from
--   the Storage dashboard (objects must be removed through the Storage API).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('place-photos', 'place-photos', false, 5242880, array['image/jpeg', 'image/webp']::text[])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.wynos_place_photos (
  id uuid primary key default gen_random_uuid(),
  place_id text not null references public.wynos_places(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  width integer,
  height integer,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  constraint wynos_place_photos_status check (status in ('pending', 'approved', 'rejected')),
  constraint wynos_place_photos_path_format check (
    storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|webp)$'
  ),
  constraint wynos_place_photos_size check (
    (width is null or width between 1 and 4096) and (height is null or height between 1 and 4096)
  )
);

create index if not exists wynos_place_photos_place_idx
on public.wynos_place_photos(place_id, status, created_at desc);

create index if not exists wynos_place_photos_user_idx
on public.wynos_place_photos(user_id, created_at desc);

create index if not exists wynos_place_photos_pending_idx
on public.wynos_place_photos(created_at)
where status = 'pending';

alter table public.wynos_place_photos enable row level security;
revoke all on table public.wynos_place_photos from public, anon, authenticated;

-- The storage read policy runs as the caller, who has no access to the
-- table, so approval is checked through this narrow definer helper.
create or replace function internal.wynos_place_photo_is_approved(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.wynos_place_photos p
    where p.storage_path = p_path and p.status = 'approved'
  );
$$;

revoke all on function internal.wynos_place_photo_is_approved(text) from public, anon;
grant execute on function internal.wynos_place_photo_is_approved(text) to authenticated;

-- Storage access: uploaders write only into their own folder; reads are
-- allowed for the uploader, admins/moderators, and anyone signed in once the
-- photo is approved. No updates; uploaders may delete their own objects.
drop policy if exists "Place photos upload own folder" on storage.objects;
create policy "Place photos upload own folder"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'place-photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Place photos readable when approved" on storage.objects;
create policy "Place photos readable when approved"
on storage.objects for select to authenticated
using (
  bucket_id = 'place-photos'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or coalesce(internal.current_platform_role(), '') in ('admin', 'moderator')
    or internal.wynos_place_photo_is_approved(name)
  )
);

drop policy if exists "Place photos delete own or admin" on storage.objects;
create policy "Place photos delete own or admin"
on storage.objects for delete to authenticated
using (
  bucket_id = 'place-photos'
  and (
    (storage.foldername(name))[1] = auth.uid()::text
    or coalesce(internal.current_platform_role(), '') = 'admin'
  )
);

create or replace function public.submit_wynos_place_photo(
  p_place_id text,
  p_storage_path text,
  p_width integer,
  p_height integer
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_path text := btrim(coalesce(p_storage_path, ''));
  v_id uuid;
begin
  if v_user is null then
    raise exception 'authentication required';
  end if;
  if not exists (select 1 from public.wynos_places p where p.id = p_place_id and p.is_active) then
    raise exception 'place not found';
  end if;
  if v_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|webp)$' or split_part(v_path, '/', 1) <> v_user::text then
    raise exception 'invalid photo path';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'place-photos' and o.name = v_path) then
    raise exception 'photo upload not found';
  end if;
  if (
    select count(*) from public.wynos_place_photos ph
    where ph.user_id = v_user and ph.place_id = p_place_id and ph.status <> 'rejected'
  ) >= 5 then
    raise exception 'place photo limit reached';
  end if;
  if (
    select count(*) from public.wynos_place_photos ph
    where ph.user_id = v_user and ph.created_at > now() - interval '24 hours'
  ) >= 20 then
    raise exception 'daily photo limit reached';
  end if;

  insert into public.wynos_place_photos (place_id, user_id, storage_path, width, height)
  values (
    p_place_id,
    v_user,
    v_path,
    case when p_width between 1 and 4096 then p_width end,
    case when p_height between 1 and 4096 then p_height end
  )
  returning id into v_id;
  return v_id;
end;
$$;

-- Approved photos for everyone signed in, plus the caller's own pending ones.
create or replace function public.wynos_place_photos(p_place_id text)
returns table (
  id uuid,
  storage_path text,
  width integer,
  height integer,
  status text,
  is_mine boolean
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
  select ph.id, ph.storage_path, ph.width, ph.height, ph.status, ph.user_id = auth.uid()
  from public.wynos_place_photos ph
  where ph.place_id = p_place_id
    and (ph.status = 'approved' or (ph.user_id = auth.uid() and ph.status = 'pending'))
  order by (ph.status = 'approved') desc, ph.created_at desc
  limit 20;
end;
$$;

create or replace function public.admin_wynos_place_photos(
  p_status text default 'pending',
  p_limit integer default 200
)
returns table (
  id uuid,
  place_id text,
  place_name text,
  user_id uuid,
  storage_path text,
  width integer,
  height integer,
  status text,
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
  if coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator') then
    raise exception 'Not authorized';
  end if;

  return query
  select ph.id, ph.place_id, p.name_th, ph.user_id, ph.storage_path, ph.width, ph.height, ph.status, ph.created_at
  from public.wynos_place_photos ph
  join public.wynos_places p on p.id = ph.place_id
  where v_status is null or ph.status = v_status
  order by ph.created_at asc
  limit v_limit;
end;
$$;

create or replace function public.admin_review_wynos_place_photo(
  p_photo_id uuid,
  p_decision text
)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_decision text := lower(btrim(coalesce(p_decision, '')));
  v_status text;
begin
  if coalesce(internal.current_platform_role(), '') <> 'admin' then
    raise exception 'Only admins can review place photos';
  end if;
  if v_decision not in ('approve', 'reject') then
    raise exception 'invalid review decision';
  end if;

  update public.wynos_place_photos ph
  set status = case v_decision when 'approve' then 'approved' else 'rejected' end,
      reviewed_at = now(),
      reviewed_by = auth.uid()
  where ph.id = p_photo_id
  returning ph.status into v_status;

  if v_status is null then
    raise exception 'photo not found';
  end if;
  return v_status;
end;
$$;

-- Lets an uploader withdraw a photo (any status); the client then removes the
-- storage object, which the delete policy above allows.
create or replace function public.delete_my_wynos_place_photo(p_photo_id uuid)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_path text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  delete from public.wynos_place_photos ph
  where ph.id = p_photo_id and ph.user_id = auth.uid()
  returning ph.storage_path into v_path;
  return v_path;
end;
$$;

revoke all on function public.submit_wynos_place_photo(text,text,integer,integer) from public, anon;
revoke all on function public.wynos_place_photos(text) from public, anon;
revoke all on function public.admin_wynos_place_photos(text,integer) from public, anon;
revoke all on function public.admin_review_wynos_place_photo(uuid,text) from public, anon;
revoke all on function public.delete_my_wynos_place_photo(uuid) from public, anon;
grant execute on function public.submit_wynos_place_photo(text,text,integer,integer) to authenticated;
grant execute on function public.wynos_place_photos(text) to authenticated;
grant execute on function public.admin_wynos_place_photos(text,integer) to authenticated;
grant execute on function public.admin_review_wynos_place_photo(uuid,text) to authenticated;
grant execute on function public.delete_my_wynos_place_photo(uuid) to authenticated;
