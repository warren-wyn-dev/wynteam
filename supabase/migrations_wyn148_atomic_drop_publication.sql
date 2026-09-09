-- WYN-148: atomic and idempotent publication for non-poll Drops.
-- Additive and backward-compatible with the currently deployed Beta4 client.

alter table public.drops
  add column if not exists publication_operation_id uuid;

create unique index if not exists drops_publication_operation_id_key
  on public.drops (publication_operation_id)
  where publication_operation_id is not null;

create or replace function public.drop_id_for_publication(p_operation_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select d.id
  from public.drops d
  where d.publication_operation_id = p_operation_id
    and d.author_id = auth.uid();
$$;

revoke all on function public.drop_id_for_publication(uuid) from public, anon;
grant execute on function public.drop_id_for_publication(uuid) to authenticated;

create or replace function public.publish_drop(
  p_operation_id uuid,
  p_image_url text,
  p_caption text,
  p_audience text,
  p_excluded_friend_ids uuid[] default '{}',
  p_images jsonb default '[]'::jsonb,
  p_mentioned_user_ids uuid[] default '{}',
  p_location text default null,
  p_location_lat double precision default null,
  p_location_lon double precision default null,
  p_location_place_id text default null,
  p_image_width integer default null,
  p_image_height integer default null,
  p_image_aspect_ratio text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid := auth.uid();
  v_drop_id uuid;
  v_image_count integer;
begin
  if v_author is null then
    raise exception 'Not authenticated';
  end if;
  if p_operation_id is null then
    raise exception 'Publication operation ID is required';
  end if;

  -- Serialize concurrent retries of the same logical publication. Without
  -- this, two first calls could both miss the lookup and one would surface a
  -- unique violation instead of returning the winner's Drop ID.
  perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text, 0));

  -- The unique operation ID is global, but an idempotent result is disclosed
  -- only to its owner. A collision with another owner is rejected below by
  -- the unique index without leaking that owner's Drop ID.
  select d.id into v_drop_id
  from public.drops d
  where d.publication_operation_id = p_operation_id
    and d.author_id = v_author;
  if v_drop_id is not null then
    return v_drop_id;
  end if;

  if internal.is_posting_blocked(v_author) then
    raise exception 'Account is posting-restricted';
  end if;
  if p_audience not in
      ('everyone', 'friends', 'friends_except', 'close_friends', 'only_me') then
    raise exception 'Invalid audience';
  end if;
  if p_image_url is null and nullif(trim(p_caption), '') is null then
    raise exception 'A Drop requires an image or caption';
  end if;
  if p_caption is not null and char_length(trim(p_caption)) > 500 then
    raise exception 'Caption exceeds 500 characters';
  end if;
  if (p_location_lat is null) <> (p_location_lon is null)
      or (p_location_lat is not null and p_location_lat not between -90 and 90)
      or (p_location_lon is not null and p_location_lon not between -180 and 180) then
    raise exception 'Invalid location coordinates';
  end if;
  if p_images is null or jsonb_typeof(p_images) <> 'array' then
    raise exception 'Images must be an array';
  end if;

  v_image_count := jsonb_array_length(p_images);
  if v_image_count > 9
      or (p_image_url is null and v_image_count <> 0)
      or (p_image_url is not null and v_image_count not between 1 and 9) then
    raise exception 'Invalid image count';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_images) with ordinality as e(value, ordinal)
    where jsonb_typeof(value) <> 'object'
       or nullif(value->>'image_url', '') is null
       or (value->>'position') is null
       or (value->>'position') !~ '^[0-9]+$'
       or (value->>'position')::integer <> ordinal - 1
       or (value->>'position')::integer not between 0 and 8
       or ((value->>'image_width') is not null
           and ((value->>'image_width') !~ '^[1-9][0-9]*$'))
       or ((value->>'image_height') is not null
           and ((value->>'image_height') !~ '^[1-9][0-9]*$'))
  ) then
    raise exception 'Invalid image metadata';
  end if;
  if v_image_count > 0
      and (p_images->0->>'image_url') is distinct from p_image_url then
    raise exception 'Primary image does not match image position zero';
  end if;

  if p_audience <> 'friends_except'
      and coalesce(cardinality(p_excluded_friend_ids), 0) <> 0 then
    raise exception 'Audience exclusions require friends_except';
  end if;
  if coalesce(cardinality(p_excluded_friend_ids), 0) <>
      coalesce((select count(distinct x) from unnest(p_excluded_friend_ids) x), 0)
      or exists (
        select 1 from unnest(p_excluded_friend_ids) x
        where x = v_author
           or not exists (select 1 from public.profiles p where p.id = x)
           or not internal.is_mutual_follow(v_author, x)
      ) then
    raise exception 'Invalid audience exclusions';
  end if;
  if coalesce(cardinality(p_mentioned_user_ids), 0) <>
      coalesce((select count(distinct x) from unnest(p_mentioned_user_ids) x), 0)
      or exists (
        select 1 from unnest(p_mentioned_user_ids) x
        where not exists (select 1 from public.profiles p where p.id = x)
      ) then
    raise exception 'Invalid mentioned users';
  end if;

  insert into public.drops (
    author_id, image_url, caption, audience, publication_operation_id,
    location, location_lat, location_lon, location_place_id,
    image_width, image_height, image_aspect_ratio
  ) values (
    v_author, p_image_url, nullif(trim(p_caption), ''), p_audience,
    p_operation_id, p_location, p_location_lat, p_location_lon,
    p_location_place_id, p_image_width, p_image_height,
    p_image_aspect_ratio
  ) returning id into v_drop_id;

  if p_audience = 'friends_except' then
    insert into public.drop_audience_exclusions(drop_id, excluded_user_id)
    select v_drop_id, x from unnest(p_excluded_friend_ids) x;
  end if;

  insert into public.drop_images(
    drop_id, image_url, position, image_width, image_height
  )
  select v_drop_id, e.value->>'image_url', (e.value->>'position')::integer,
    nullif(e.value->>'image_width', '')::integer,
    nullif(e.value->>'image_height', '')::integer
  from jsonb_array_elements(p_images) e(value);

  -- Preserve the established privacy behavior: disallowed mentions remain
  -- plain caption text and do not create rows/notifications.
  insert into public.drop_mentions(drop_id, mentioned_user_id)
  select v_drop_id, x
  from unnest(p_mentioned_user_ids) x
  where not internal.is_blocked_either_way(v_author, x)
    and internal.mention_allowed(x, v_author);

  return v_drop_id;
end;
$$;

revoke all on function public.publish_drop(
  uuid,text,text,text,uuid[],jsonb,uuid[],text,double precision,
  double precision,text,integer,integer,text
) from public, anon;
grant execute on function public.publish_drop(
  uuid,text,text,text,uuid[],jsonb,uuid[],text,double precision,
  double precision,text,integer,integer,text
) to authenticated;
