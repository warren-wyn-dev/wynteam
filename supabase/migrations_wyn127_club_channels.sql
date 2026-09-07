-- WYN-127: Club Channels
--
-- Adds `public.club_channels` and `club_posts.channel_id` so a Club's
-- feed can be split into multiple Discord-style rooms instead of one
-- flat feed (WYN-014). See .wyn/tasks/backlog/WYN-127-club-channels.md.
--
-- SAFETY: additive + backfill, no destructive step.
--   * `club_channels` is a brand new table.
--   * Every existing Club (one that predates this migration) gets a
--     "ทั่วไป" default channel inserted for it, and every existing
--     `club_posts` row is backfilled into that channel -- no post is
--     ever left unassigned, deleted, or reassigned to the wrong Club.
--   * `channel_id` is added nullable first, backfilled, and only then
--     constrained NOT NULL -- by the time that ALTER runs every row
--     already has a value, so it cannot fail.
--   * The composite FK (channel_id, club_id) -> club_channels(id, club_id)
--     guarantees a post's channel always belongs to the same Club as
--     the post itself.
--   * Deleting a channel (ON DELETE CASCADE on that same FK) deletes
--     every post inside it -- this is intentional product behavior
--     (Founder, 2026-09-07: "ประหยัดพื้นที่", not migrate-to-default),
--     not an accident of this migration.
--
-- Re-runnable: every statement is `if not exists`/`or replace`/guarded
-- by a `where not exists`/`where channel_id is null` predicate.
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it;
-- no AI applies production SQL.

begin;

create table if not exists public.club_channels (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs (id) on delete cascade,
  name text not null,
  created_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint club_channels_name_length check (char_length(name) between 1 and 50),
  -- Composite unique target for club_posts.channel_id's own FK below --
  -- guarantees a post's channel_id/club_id can never point at a channel
  -- belonging to a *different* Club.
  constraint club_channels_id_club_id_key unique (id, club_id)
);

comment on table public.club_channels is
  'WYN-127: rooms within a Club, e.g. "#ทั่วไป"/"#ประกาศ". club_posts.channel_id '
  'scopes each post to exactly one of these.';

-- Case-insensitive per-Club uniqueness -- Design's "กันชื่อว่าง/ซ้ำ".
create unique index if not exists club_channels_club_id_lower_name_key
  on public.club_channels (club_id, lower(name));

alter table public.club_channels enable row level security;

drop policy if exists "Club channels are viewable by authenticated users" on public.club_channels;
create policy "Club channels are viewable by authenticated users"
  on public.club_channels
  for select
  to authenticated
  using (true);

drop policy if exists "Club owners and admins can create channels" on public.club_channels;
create policy "Club owners and admins can create channels"
  on public.club_channels
  for insert
  to authenticated
  with check (
    auth.uid() = created_by
    and public.club_role(club_id, auth.uid()) in ('owner', 'admin')
  );

drop policy if exists "Club owners and admins can rename channels" on public.club_channels;
create policy "Club owners and admins can rename channels"
  on public.club_channels
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

drop policy if exists "Club owners and admins can delete channels" on public.club_channels;
create policy "Club owners and admins can delete channels"
  on public.club_channels
  for delete
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));

-- Every newly created Club gets its "ทั่วไป" default channel
-- automatically, same trigger shape as clubs_add_owner_membership
-- (WYN-014).
create or replace function public.clubs_add_default_channel()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.club_channels (club_id, name, created_by)
  values (new.id, 'ทั่วไป', new.owner_id);
  return new;
end;
$$;

drop trigger if exists clubs_add_default_channel on public.clubs;
create trigger clubs_add_default_channel
  after insert on public.clubs
  for each row execute function public.clubs_add_default_channel();

-- Backfill: every Club that predates this migration (i.e. has no
-- channel yet) gets the same "ทั่วไป" default channel the trigger above
-- gives new ones.
insert into public.club_channels (club_id, name, created_by)
select c.id, 'ทั่วไป', c.owner_id
from public.clubs c
where not exists (
  select 1 from public.club_channels ch where ch.club_id = c.id
);

alter table public.club_posts add column if not exists channel_id uuid;

-- Backfill: every pre-existing club_post moves into its Club's oldest
-- channel -- guaranteed by the insert directly above to be "ทั่วไป" for
-- a Club that had none before this migration. No post is left
-- unassigned.
update public.club_posts cp
set channel_id = (
  select ch.id from public.club_channels ch
  where ch.club_id = cp.club_id
  order by ch.created_at asc
  limit 1
)
where cp.channel_id is null;

alter table public.club_posts drop constraint if exists club_posts_channel_id_club_id_fkey;
alter table public.club_posts
  add constraint club_posts_channel_id_club_id_fkey
  foreign key (channel_id, club_id) references public.club_channels (id, club_id) on delete cascade;

alter table public.club_posts alter column channel_id set not null;

create index if not exists club_posts_channel_id_idx
  on public.club_posts (channel_id, pinned, created_at);

-- create_poll_club_post() (WYN-115) inserts into club_posts directly
-- and predates channel_id -- now NOT NULL, so this needs a
-- p_channel_id argument too. The old 5-arg overload is dropped outright
-- (SCHEMA-003 lesson: leaving it behind would keep a second,
-- channel-less SECURITY DEFINER entry point reachable).
drop function if exists public.create_poll_club_post(uuid, text, text[], int, uuid[]);

create or replace function public.create_poll_club_post(
  p_club_id uuid,
  p_channel_id uuid,
  p_content text,
  p_options text[],
  p_duration_days int,
  p_mentioned_user_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author uuid := auth.uid();
  v_post_id uuid;
  v_options text[];
begin
  if v_author is null then
    raise exception 'Not authenticated';
  end if;

  if public.club_role(p_club_id, v_author) is null then
    raise exception 'Must be an approved club member to post';
  end if;

  if not exists (
    select 1 from public.club_channels where id = p_channel_id and club_id = p_club_id
  ) then
    raise exception 'Channel does not belong to this club';
  end if;

  if internal.is_posting_blocked(v_author) then
    raise exception 'Account is posting-restricted';
  end if;

  if p_content is null or length(trim(p_content)) = 0 then
    raise exception 'Poll question is required';
  end if;

  select array_agg(trim(o)) into v_options from unnest(p_options) as o;

  if not public.valid_poll_options(v_options) then
    raise exception 'Poll must have 2-4 non-empty, non-duplicate options (max 80 characters each)';
  end if;

  if p_duration_days not in (1, 3, 7) then
    raise exception 'Poll duration must be 1, 3, or 7 days';
  end if;

  insert into public.club_posts (club_id, channel_id, author_id, content, image_urls, link_url)
  values (p_club_id, p_channel_id, v_author, trim(p_content), null, null)
  returning id into v_post_id;

  insert into public.club_post_polls (club_post_id, options, expires_at)
  values (v_post_id, v_options, now() + make_interval(days => p_duration_days));

  insert into public.club_post_mentions (club_post_id, mentioned_user_id)
  select v_post_id, m
  from unnest(p_mentioned_user_ids) as m;

  return v_post_id;
end;
$$;

commit;

-- VERIFY (run separately)
--
--   select count(*) from public.club_posts where channel_id is null; -- expect 0
--   select c.id, count(ch.id) from public.clubs c
--     left join public.club_channels ch on ch.club_id = c.id
--     group by c.id having count(ch.id) = 0; -- expect 0 rows
