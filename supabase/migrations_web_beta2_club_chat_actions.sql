-- WYN-135 / WYNOS Web Beta 2: edit, pin and search Club channel messages.
-- STAGED ONLY. Founder approval and disposable-database QA are required
-- before this migration may run on the shared production Supabase database.
-- Web Beta 1 and the Flutter app are not modified by this migration until
-- the approved rollout; all new write/search RPCs are developer-gated.
--
-- Search: PostgreSQL full-text, not a leading-wildcard ILIKE table scan.
-- 'simple' full-text supports tokenized languages; an indexed pg_trgm
-- substring fallback supports Thai text without spaces. The two GIN indexes
-- avoid unindexed leading-wildcard ILIKE scans.

alter table public.club_channel_messages
  add column if not exists edited_at timestamptz;
alter table public.club_channel_messages
  add column if not exists pinned_at timestamptz;
alter table public.club_channel_messages
  add column if not exists pinned_by uuid references public.profiles(id) on delete set null;

-- pg_trgm may already be installed in a different schema on other projects.
-- Discover the installed operator class and schema-qualify it when indexing.
create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
do $$
declare
  v_schema text;
begin
  select n.nspname into v_schema
  from pg_opclass o join pg_namespace n on n.oid = o.opcnamespace
  where o.opcname = 'gin_trgm_ops'
  limit 1;
  if v_schema is null then raise exception 'pg_trgm GIN operator class unavailable'; end if;
  execute format(
    'create index if not exists club_channel_messages_trgm_idx on public.club_channel_messages using gin (content %I.gin_trgm_ops)',
    v_schema
  );
end $$;

create index if not exists club_channel_messages_fts_idx
  on public.club_channel_messages using gin
  (to_tsvector('simple'::regconfig, coalesce(content, '')));

create index if not exists club_channel_messages_pinned_idx
  on public.club_channel_messages (channel_id, pinned_at desc)
  where pinned_at is not null;

-- Direct UPDATE remains denied to authenticated users by the existing
-- club_channel_messages RLS policies. Editing is RPC-only so ownership,
-- current membership and the Beta2 gate are checked on the server.
create or replace function public.edit_club_channel_message(
  p_message_id uuid, p_content text
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_author uuid;
  v_club uuid;
  v_original text;
  v_body text := btrim(coalesce(p_content, ''));
begin
  if v_me is null then raise exception 'Not authenticated'; end if;
  if not public.is_developer_account() then
    raise exception 'Club chat actions are not available yet';
  end if;
  select m.author_id, ch.club_id, m.content into v_author, v_club, v_original
  from public.club_channel_messages m
  join public.club_channels ch on ch.id = m.channel_id
  where m.id = p_message_id
  for update of m;
  if not found or v_author <> v_me or v_original is null
    or public.club_role(v_club, v_me) is null then
    raise exception 'Message not found or not yours to edit';
  end if;
  if internal.is_posting_blocked(v_me) then
    raise exception 'Posting is restricted for this account';
  end if;
  if char_length(v_body) not between 1 and 2000 then
    raise exception 'Message must be 1-2000 characters';
  end if;
  update public.club_channel_messages
  set content = v_body, edited_at = now()
  where id = p_message_id;
end;
$$;

-- Serialize pin operations by locking the CHANNEL, not the individual
-- message; simultaneous staff pins cannot pass the three-pin cap.
create or replace function public.set_club_channel_message_pin(
  p_message_id uuid, p_pin boolean
) returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_channel uuid;
  v_club uuid;
  v_pinned_at timestamptz;
begin
  if v_me is null then raise exception 'Not authenticated'; end if;
  if not public.is_developer_account() then
    raise exception 'Club chat actions are not available yet';
  end if;
  if p_pin is null then raise exception 'Pin choice is required'; end if;
  select m.channel_id into v_channel
  from public.club_channel_messages m where m.id = p_message_id;
  if not found then raise exception 'Message not found'; end if;

  select ch.club_id into v_club
  from public.club_channels ch where ch.id = v_channel for update;
  if not found
    or coalesce(public.club_role(v_club, v_me), '') not in
      ('owner', 'admin', 'moderator') then
    raise exception 'Only Club staff can pin messages';
  end if;
  select m.pinned_at into v_pinned_at
  from public.club_channel_messages m
  where m.id = p_message_id and m.channel_id = v_channel
  for update;
  if not found then raise exception 'Message not found'; end if;

  if p_pin and v_pinned_at is null and
    (select count(*) from public.club_channel_messages
     where channel_id = v_channel and pinned_at is not null) >= 3 then
    raise exception 'Pin limit reached: unpin an older message first';
  end if;
  update public.club_channel_messages
    set pinned_at = case when p_pin then coalesce(pinned_at, now()) else null end,
        pinned_by = case when p_pin then coalesce(pinned_by, v_me) else null end
    where id = p_message_id;
end;
$$;

-- Search only the channel currently open and only for approved members.
-- SECURITY DEFINER protects the caller from accessing other channels by
-- guessing UUIDs; the explicit channel/member/developer checks are required.
create or replace function public.search_club_channel_messages(
  p_channel_id uuid, p_query text, p_limit integer default 30
) returns table (
  id uuid, content text, created_at timestamptz, author_id uuid
)
language plpgsql stable security definer set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_club uuid;
  v_term text := btrim(coalesce(p_query, ''));
  v_query tsquery;
  v_escaped text;
begin
  if v_me is null then raise exception 'Not authenticated'; end if;
  if not public.is_developer_account() then
    raise exception 'Club chat actions are not available yet';
  end if;
  select ch.club_id into v_club
  from public.club_channels ch where ch.id = p_channel_id;
  if not found or public.club_role(v_club, v_me) is null then
    raise exception 'Not an approved member of this channel';
  end if;
  if v_term = '' then return; end if;
  if char_length(v_term) > 120 then raise exception 'Search is too long'; end if;
  v_query := websearch_to_tsquery('simple'::regconfig, v_term);
  if numnode(v_query) = 0 then return; end if;
  -- Escape wildcards so the substring fallback is literal, not caller-
  -- controlled pattern syntax. A 3-character minimum preserves GIN selectivity.
  v_escaped := replace(replace(replace(v_term, chr(92), chr(92)||chr(92)),
                        '%', chr(92)||'%'), '_', chr(92)||'_');
  return query
    select m.id, m.content, m.created_at, m.author_id
    from public.club_channel_messages m
    where m.channel_id = p_channel_id
      and (
        to_tsvector('simple'::regconfig, coalesce(m.content, '')) @@ v_query
        or (char_length(v_term) >= 3 and
            m.content ilike '%' || v_escaped || '%' escape chr(92))
      )
    order by m.created_at desc, m.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 30);
end;
$$;

revoke all on function public.edit_club_channel_message(uuid, text)
  from public, anon;
revoke all on function public.set_club_channel_message_pin(uuid, boolean)
  from public, anon;
revoke all on function public.search_club_channel_messages(uuid, text, integer)
  from public, anon;
grant execute on function public.edit_club_channel_message(uuid, text)
  to authenticated;
grant execute on function public.set_club_channel_message_pin(uuid, boolean)
  to authenticated;
grant execute on function public.search_club_channel_messages(uuid, text, integer)
  to authenticated;

-- Rollback requires the Founder: drop the three functions and new indexes,
-- then remove only the three columns added above after checking that no
-- developer's pinned/edited state still needs preservation.
