-- WYN-220 Phase 1: WYNOS AI Secretary foundation (development only).
--
-- Additive only. Nothing existing reads or changes behaviour because of this
-- migration. Depends on the WYN-219 foundation (internal.is_super_admin(),
-- internal.log_audit_event()).
--
-- Governance (Founder approval still required before any production apply):
--   * Only the super admin can use the AI Secretary in Phase 1. Granting it to
--     other admins is a later, separate decision.
--   * The kill switch defaults to OFF. The super admin turns it on/off with
--     ai_secretary_set_enabled(); every change is written to audit_log.
--   * Messages, tool runs and token usage are written only through the
--     security definer RPCs below, so a client cannot forge usage counts or
--     audit rows. Tool runs are append-only.
--   * Conversations and memory notes expire (90 / 180 days by default) and
--     are hidden once expired; internal.ai_secretary_purge_expired() deletes
--     them. Scheduling the purge is a separate ops step.
--
-- Spec: .wyn/docs/engineering/wyn-220-ai-secretary-architecture.md
-- Test: supabase/tests/wyn_220_ai_secretary_foundation_test.sh
--
-- ROLLBACK (nothing outside the AI Secretary reads these objects):
--   drop function public.ai_secretary_status(), public.ai_secretary_set_enabled(boolean),
--     public.ai_secretary_set_limits(integer, integer),
--     public.ai_secretary_begin_request(uuid, text),
--     public.ai_secretary_record_reply(uuid, text, text, integer, integer, integer),
--     public.ai_secretary_record_tool_run(uuid, text, smallint, text, text, jsonb, jsonb, text, integer),
--     public.ai_secretary_conversation_messages(uuid, integer),
--     internal.ai_secretary_purge_expired(), internal.ai_secretary_allowed();
--   drop table public.ai_tool_runs, public.ai_usage, public.ai_messages,
--     public.ai_memory_items, public.ai_conversations, internal.ai_secretary_settings;
--   (the extra audit_log event type is harmless and may stay)

create schema if not exists internal;

-- ------------------------------------------------------------
-- Settings (kill switch and limits) -- one row, internal schema only.
-- ------------------------------------------------------------

create table if not exists internal.ai_secretary_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default false,
  daily_token_limit integer not null default 300000 check (daily_token_limit between 0 and 10000000),
  requests_per_minute integer not null default 6 check (requests_per_minute between 0 and 60),
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into internal.ai_secretary_settings (id) values (true) on conflict (id) do nothing;

revoke all on table internal.ai_secretary_settings from public, anon, authenticated;

-- ------------------------------------------------------------
-- Tables
-- ------------------------------------------------------------

create table if not exists public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '90 days'
);

create index if not exists ai_conversations_owner_updated_idx
  on public.ai_conversations (owner_id, updated_at desc);

create table if not exists public.ai_messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (char_length(content) between 1 and 40000),
  created_at timestamptz not null default now()
);

create index if not exists ai_messages_conversation_idx
  on public.ai_messages (conversation_id, id);
create index if not exists ai_messages_owner_created_idx
  on public.ai_messages (owner_id, created_at desc) where role = 'user';

-- Append-only record of every tool call the AI attempted, including denied ones.
create table if not exists public.ai_tool_runs (
  id bigint generated always as identity primary key,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  tool_name text not null check (tool_name ~ '^[a-z][a-z0-9_]{0,63}$'),
  permission_level smallint not null check (permission_level between 1 and 3),
  status text not null check (status in ('succeeded', 'failed', 'denied', 'timed_out')),
  source text check (source is null or char_length(source) <= 200),
  input jsonb not null default '{}'::jsonb check (pg_column_size(input) <= 8192),
  output_summary jsonb check (output_summary is null or pg_column_size(output_summary) <= 16384),
  error text check (error is null or char_length(error) <= 500),
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  created_at timestamptz not null default now()
);

create index if not exists ai_tool_runs_owner_created_idx
  on public.ai_tool_runs (owner_id, created_at desc);

create table if not exists public.ai_usage (
  id bigint generated always as identity primary key,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  model text not null check (char_length(model) between 1 and 80),
  input_tokens integer not null check (input_tokens >= 0),
  output_tokens integer not null check (output_tokens >= 0),
  duration_ms integer check (duration_ms is null or duration_ms >= 0),
  created_at timestamptz not null default now()
);

create index if not exists ai_usage_owner_created_idx
  on public.ai_usage (owner_id, created_at desc);

-- Notes the super admin asks the AI to remember. Owner-only, expiring,
-- deletable. Nothing is saved without the owner adding it.
create table if not exists public.ai_memory_items (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  kind text not null default 'note' check (kind in ('note', 'decision', 'context')),
  content text not null check (char_length(btrim(content)) between 1 and 2000),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '180 days',
  constraint ai_memory_items_expiry_window check (expires_at > created_at and expires_at <= created_at + interval '366 days')
);

create index if not exists ai_memory_items_owner_idx
  on public.ai_memory_items (owner_id, created_at desc);

alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_tool_runs enable row level security;
alter table public.ai_usage enable row level security;
alter table public.ai_memory_items enable row level security;

-- Deny by default: drop Supabase's default table grants, then grant back only
-- what each table needs.
revoke all on table public.ai_conversations, public.ai_messages, public.ai_tool_runs,
  public.ai_usage, public.ai_memory_items from public, anon, authenticated;

grant select on table public.ai_conversations, public.ai_messages, public.ai_tool_runs,
  public.ai_usage to authenticated;
grant select, insert, delete on table public.ai_memory_items to authenticated;

-- ------------------------------------------------------------
-- Access helper
-- ------------------------------------------------------------

-- Phase 1: the super admin only.
create or replace function internal.ai_secretary_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select internal.is_super_admin();
$$;

revoke all on function internal.ai_secretary_allowed() from public, anon;
grant execute on function internal.ai_secretary_allowed() to authenticated;

drop policy if exists "ai_conversations_select_own" on public.ai_conversations;
create policy "ai_conversations_select_own" on public.ai_conversations
  for select to authenticated
  using (owner_id = (select auth.uid()) and expires_at > now() and internal.ai_secretary_allowed());

drop policy if exists "ai_messages_select_own" on public.ai_messages;
create policy "ai_messages_select_own" on public.ai_messages
  for select to authenticated
  using (
    owner_id = (select auth.uid())
    and internal.ai_secretary_allowed()
    and exists (
      select 1 from public.ai_conversations c
      where c.id = conversation_id and c.expires_at > now()
    )
  );

drop policy if exists "ai_tool_runs_select_own" on public.ai_tool_runs;
create policy "ai_tool_runs_select_own" on public.ai_tool_runs
  for select to authenticated
  using (owner_id = (select auth.uid()) and internal.ai_secretary_allowed());

drop policy if exists "ai_usage_select_own" on public.ai_usage;
create policy "ai_usage_select_own" on public.ai_usage
  for select to authenticated
  using (owner_id = (select auth.uid()) and internal.ai_secretary_allowed());

drop policy if exists "ai_memory_items_select_own" on public.ai_memory_items;
create policy "ai_memory_items_select_own" on public.ai_memory_items
  for select to authenticated
  using (owner_id = (select auth.uid()) and expires_at > now() and internal.ai_secretary_allowed());

drop policy if exists "ai_memory_items_insert_own" on public.ai_memory_items;
create policy "ai_memory_items_insert_own" on public.ai_memory_items
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and internal.ai_secretary_allowed());

drop policy if exists "ai_memory_items_delete_own" on public.ai_memory_items;
create policy "ai_memory_items_delete_own" on public.ai_memory_items
  for delete to authenticated
  using (owner_id = (select auth.uid()) and internal.ai_secretary_allowed());

-- ------------------------------------------------------------
-- Audit event type (additive; same approach as the WYN-219 foundation)
-- ------------------------------------------------------------

do $$
declare
  v_name text;
  v_def text;
  v_values text[];
  v_new text[] := array['ai_secretary_settings_changed'];
begin
  select c.conname, pg_get_constraintdef(c.oid)
    into v_name, v_def
  from pg_constraint c
  where c.conrelid = 'public.audit_log'::regclass
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) like '%event_type%'
  limit 1;

  if v_def is null then
    raise exception 'audit_log event_type check constraint not found';
  end if;

  select array_agg(distinct x.m[1] order by x.m[1])
    into v_values
  from regexp_matches(v_def, '''([a-z0-9_]+)''', 'g') as x(m);

  if v_values is null then
    select array_agg(distinct btrim(v) order by btrim(v))
      into v_values
    from regexp_matches(v_def, '''\{([^}]*)\}''') as x(m),
         unnest(string_to_array(x.m[1], ',')) as v;
  end if;

  if v_values is null or cardinality(v_values) < 2
     or exists (select 1 from unnest(v_values) as v where v !~ '^[a-z0-9_]+$') then
    raise exception 'Could not read the audit_log event types from: %', v_def;
  end if;

  if v_new <@ v_values then
    return;
  end if;

  select array_agg(distinct v order by v) into v_values
  from unnest(v_values || v_new) as v;

  execute format('alter table public.audit_log drop constraint %I', v_name);
  execute format(
    'alter table public.audit_log add constraint audit_log_event_type_check check (event_type in (%s))',
    (select string_agg(quote_literal(v), ', ') from unnest(v_values) as v)
  );
end
$$;

-- ------------------------------------------------------------
-- RPCs
-- ------------------------------------------------------------

-- What the Admin app needs to decide whether to show / run the AI Secretary.
create or replace function public.ai_secretary_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_settings internal.ai_secretary_settings;
begin
  if v_uid is null or not internal.ai_secretary_allowed() then
    return jsonb_build_object('allowed', false);
  end if;

  select * into v_settings from internal.ai_secretary_settings where id;

  return jsonb_build_object(
    'allowed', true,
    'enabled', coalesce(v_settings.enabled, false),
    'daily_token_limit', v_settings.daily_token_limit,
    'requests_per_minute', v_settings.requests_per_minute,
    'tokens_used_today', (
      select coalesce(sum(u.input_tokens + u.output_tokens), 0)
      from public.ai_usage u
      where u.owner_id = v_uid
        and u.created_at >= date_trunc('day', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok'
    ),
    'updated_at', v_settings.updated_at
  );
end;
$$;

-- Kill switch. Super admin only; every change is audited.
create or replace function public.ai_secretary_set_enabled(p_enabled boolean)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_previous boolean;
begin
  if v_actor is null or not internal.ai_secretary_allowed() then
    raise exception 'Only the super admin can change the AI Secretary' using errcode = '42501';
  end if;
  if p_enabled is null then
    raise exception 'enabled must be true or false' using errcode = '22023';
  end if;

  select enabled into v_previous from internal.ai_secretary_settings where id for update;
  if v_previous is not distinct from p_enabled then
    return;
  end if;

  update internal.ai_secretary_settings
     set enabled = p_enabled, updated_by = v_actor, updated_at = now()
   where id;

  perform internal.log_audit_event(
    v_actor,
    'ai_secretary_settings_changed',
    null,
    jsonb_build_object('enabled', p_enabled, 'previous_enabled', v_previous)
  );
end;
$$;

create or replace function public.ai_secretary_set_limits(p_daily_token_limit integer, p_requests_per_minute integer)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_prev internal.ai_secretary_settings;
begin
  if v_actor is null or not internal.ai_secretary_allowed() then
    raise exception 'Only the super admin can change the AI Secretary' using errcode = '42501';
  end if;
  if p_daily_token_limit is null or p_daily_token_limit not between 0 and 10000000 then
    raise exception 'daily_token_limit must be between 0 and 10000000' using errcode = '22023';
  end if;
  if p_requests_per_minute is null or p_requests_per_minute not between 0 and 60 then
    raise exception 'requests_per_minute must be between 0 and 60' using errcode = '22023';
  end if;

  select * into v_prev from internal.ai_secretary_settings where id for update;
  if v_prev.daily_token_limit = p_daily_token_limit and v_prev.requests_per_minute = p_requests_per_minute then
    return;
  end if;

  update internal.ai_secretary_settings
     set daily_token_limit = p_daily_token_limit,
         requests_per_minute = p_requests_per_minute,
         updated_by = v_actor,
         updated_at = now()
   where id;

  perform internal.log_audit_event(
    v_actor,
    'ai_secretary_settings_changed',
    null,
    jsonb_build_object(
      'daily_token_limit', p_daily_token_limit,
      'previous_daily_token_limit', v_prev.daily_token_limit,
      'requests_per_minute', p_requests_per_minute,
      'previous_requests_per_minute', v_prev.requests_per_minute
    )
  );
end;
$$;

-- The gate every chat request passes before any model call: access, kill
-- switch, per-minute rate limit and daily token budget. Creates the
-- conversation when p_conversation_id is null, stores the user message and
-- returns the conversation id.
create or replace function public.ai_secretary_begin_request(p_conversation_id uuid, p_message text)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_settings internal.ai_secretary_settings;
  v_conversation uuid := p_conversation_id;
  v_message text := btrim(coalesce(p_message, ''));
  v_recent integer;
  v_tokens bigint;
begin
  if v_uid is null or not internal.ai_secretary_allowed() then
    raise exception 'AI Secretary is not available for this account' using errcode = '42501';
  end if;

  select * into v_settings from internal.ai_secretary_settings where id;
  if not coalesce(v_settings.enabled, false) then
    raise exception 'AI Secretary is turned off' using errcode = '55000';
  end if;

  if char_length(v_message) < 1 or char_length(v_message) > 4000 then
    raise exception 'Message must be 1-4000 characters' using errcode = '22023';
  end if;

  -- Serialise this user's requests so the two checks below cannot be raced.
  perform pg_advisory_xact_lock(hashtextextended('ai_secretary:' || v_uid::text, 0));

  select count(*) into v_recent
  from public.ai_messages m
  where m.owner_id = v_uid and m.role = 'user' and m.created_at > now() - interval '1 minute';
  if v_recent >= v_settings.requests_per_minute then
    raise exception 'Too many AI requests; try again in a minute' using errcode = '54000';
  end if;

  select coalesce(sum(u.input_tokens + u.output_tokens), 0) into v_tokens
  from public.ai_usage u
  where u.owner_id = v_uid
    and u.created_at >= date_trunc('day', now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok';
  if v_tokens >= v_settings.daily_token_limit then
    raise exception 'Daily AI token budget reached' using errcode = '54000';
  end if;

  if v_conversation is null then
    insert into public.ai_conversations (owner_id, title)
    values (v_uid, left(regexp_replace(v_message, '\s+', ' ', 'g'), 120))
    returning id into v_conversation;
  else
    update public.ai_conversations
       set updated_at = now()
     where id = v_conversation and owner_id = v_uid and expires_at > now();
    if not found then
      raise exception 'Conversation not found' using errcode = 'P0002';
    end if;
  end if;

  insert into public.ai_messages (conversation_id, owner_id, role, content)
  values (v_conversation, v_uid, 'user', v_message);

  return v_conversation;
end;
$$;

-- Stores the assistant reply (optional) and the token usage of one request.
create or replace function public.ai_secretary_record_reply(
  p_conversation_id uuid,
  p_content text,
  p_model text,
  p_input_tokens integer,
  p_output_tokens integer,
  p_duration_ms integer
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not internal.ai_secretary_allowed() then
    raise exception 'AI Secretary is not available for this account' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.ai_conversations c where c.id = p_conversation_id and c.owner_id = v_uid
  ) then
    raise exception 'Conversation not found' using errcode = 'P0002';
  end if;
  if p_input_tokens is null or p_input_tokens < 0 or p_output_tokens is null or p_output_tokens < 0 then
    raise exception 'Token counts must be non-negative' using errcode = '22023';
  end if;

  if nullif(btrim(coalesce(p_content, '')), '') is not null then
    insert into public.ai_messages (conversation_id, owner_id, role, content)
    values (p_conversation_id, v_uid, 'assistant', left(p_content, 40000));
  end if;

  if p_input_tokens + p_output_tokens > 0 then
    insert into public.ai_usage (conversation_id, owner_id, model, input_tokens, output_tokens, duration_ms)
    values (p_conversation_id, v_uid, left(coalesce(nullif(p_model, ''), 'unknown'), 80),
            p_input_tokens, p_output_tokens, greatest(p_duration_ms, 0));
  end if;
end;
$$;

create or replace function public.ai_secretary_record_tool_run(
  p_conversation_id uuid,
  p_tool_name text,
  p_permission_level smallint,
  p_status text,
  p_source text,
  p_input jsonb,
  p_output_summary jsonb,
  p_error text,
  p_duration_ms integer
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not internal.ai_secretary_allowed() then
    raise exception 'AI Secretary is not available for this account' using errcode = '42501';
  end if;
  if p_conversation_id is not null and not exists (
    select 1 from public.ai_conversations c where c.id = p_conversation_id and c.owner_id = v_uid
  ) then
    raise exception 'Conversation not found' using errcode = 'P0002';
  end if;

  insert into public.ai_tool_runs (
    conversation_id, owner_id, tool_name, permission_level, status, source,
    input, output_summary, error, duration_ms
  ) values (
    p_conversation_id, v_uid, p_tool_name, p_permission_level, p_status, left(p_source, 200),
    coalesce(p_input, '{}'::jsonb), p_output_summary, left(p_error, 500), greatest(p_duration_ms, 0)
  );
end;
$$;

-- The latest messages of one of the caller's conversations, oldest first.
create or replace function public.ai_secretary_conversation_messages(p_conversation_id uuid, p_limit integer default 20)
returns table (role text, content text, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null or not internal.ai_secretary_allowed() then
    raise exception 'AI Secretary is not available for this account' using errcode = '42501';
  end if;

  return query
  select m.role, m.content, m.created_at
  from (
    select mm.id, mm.role, mm.content, mm.created_at
    from public.ai_messages mm
    join public.ai_conversations c on c.id = mm.conversation_id
    where mm.conversation_id = p_conversation_id
      and c.owner_id = v_uid
      and c.expires_at > now()
    order by mm.id desc
    limit least(greatest(coalesce(p_limit, 20), 1), 50)
  ) m
  order by m.id;
end;
$$;

-- Retention. Not exposed to API roles; run by a scheduled job (ops step).
create or replace function internal.ai_secretary_purge_expired()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_conversations integer;
  v_memory integer;
begin
  delete from public.ai_conversations where expires_at <= now();
  get diagnostics v_conversations = row_count;
  delete from public.ai_memory_items where expires_at <= now();
  get diagnostics v_memory = row_count;
  -- Tool-run and usage rows are the audit trail; keep them for a year.
  delete from public.ai_tool_runs where created_at <= now() - interval '365 days';
  delete from public.ai_usage where created_at <= now() - interval '365 days';
  return v_conversations + v_memory;
end;
$$;

revoke all on function internal.ai_secretary_purge_expired() from public, anon, authenticated;

revoke all on function public.ai_secretary_status() from public, anon;
revoke all on function public.ai_secretary_set_enabled(boolean) from public, anon;
revoke all on function public.ai_secretary_set_limits(integer, integer) from public, anon;
revoke all on function public.ai_secretary_begin_request(uuid, text) from public, anon;
revoke all on function public.ai_secretary_record_reply(uuid, text, text, integer, integer, integer) from public, anon;
revoke all on function public.ai_secretary_record_tool_run(uuid, text, smallint, text, text, jsonb, jsonb, text, integer) from public, anon;
revoke all on function public.ai_secretary_conversation_messages(uuid, integer) from public, anon;
grant execute on function public.ai_secretary_status() to authenticated;
grant execute on function public.ai_secretary_set_enabled(boolean) to authenticated;
grant execute on function public.ai_secretary_set_limits(integer, integer) to authenticated;
grant execute on function public.ai_secretary_begin_request(uuid, text) to authenticated;
grant execute on function public.ai_secretary_record_reply(uuid, text, text, integer, integer, integer) to authenticated;
grant execute on function public.ai_secretary_record_tool_run(uuid, text, smallint, text, text, jsonb, jsonb, text, integer) to authenticated;
grant execute on function public.ai_secretary_conversation_messages(uuid, integer) to authenticated;
