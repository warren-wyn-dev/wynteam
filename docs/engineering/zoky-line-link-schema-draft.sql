-- DESIGN DRAFT ONLY. NOT A MIGRATION. DO NOT APPLY TO PRODUCTION.
-- Zoky Merchant / LINE account linking storage for review and isolated DB QA.
-- Tables are deliberately denied to anon/authenticated; server-only service role.
-- A single owner/staff may link a LINE ID for each eligible store.
-- Next: generate a real migration with Supabase CLI, run migration/RLS tests
-- on disposable Postgres, review/approve BEFORE any production schema changes.

create table public.zoky_line_link_requests (
  nonce_sha256 text primary key check (nonce_sha256 ~ '^[0-9a-f]{64}$'),
  user_id uuid not null references auth.users(id) on delete cascade,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  constraint zoky_line_link_requests_ttl check (
    expires_at > created_at and expires_at <= created_at + interval '11 minutes'
  )
);

create index zoky_line_link_requests_expiry_idx
  on public.zoky_line_link_requests (expires_at) where consumed_at is null;

create table public.zoky_line_connections (
  store_id uuid not null references public.food_stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  line_user_id text not null check (line_user_id ~ '^U[0-9a-f]{32}$'),
  linked_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (store_id, user_id)
);

-- Prevent a single LINE account impersonating two staff members at one store.
-- Distinct stores remain valid when the same user has authorization for both.
create unique index zoky_line_one_active_user_per_store_idx
  on public.zoky_line_connections (store_id, line_user_id)
  where revoked_at is null;

alter table public.zoky_line_link_requests enable row level security;
alter table public.zoky_line_connections enable row level security;
revoke all on public.zoky_line_link_requests from public, anon, authenticated;
revoke all on public.zoky_line_connections from public, anon, authenticated;
grant select, insert, update, delete
  on public.zoky_line_link_requests, public.zoky_line_connections
  to service_role;

-- Caller MUST first verify LINE webhook HMAC over raw body. An event from
-- browser, client, or other channel cannot call this function.
-- Only callable from a server-only service role, with a signed LINE user ID.
-- The row lock makes nonce consumption atomic under concurrent webhook calls.
create or replace function public.zoky_line_complete_link(
  p_nonce_sha256 text,
  p_line_user_id text
) returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  pending public.zoky_line_link_requests%rowtype;
  eligible boolean;
begin
  if p_nonce_sha256 !~ '^[0-9a-f]{64}$'
     or p_line_user_id !~ '^U[0-9a-f]{32}$' then
    return false;
  end if;

  select * into pending from public.zoky_line_link_requests
   where nonce_sha256 = p_nonce_sha256
     and consumed_at is null
     and expires_at > clock_timestamp()
   for update;
  if not found then return false; end if;

  -- Re-check current membership at callback time, not only link initiation.
  select exists (
    select 1 from public.food_stores s
    where s.id = pending.store_id
      and (
        exists (
          select 1 from public.merchant_memberships mm
          where mm.merchant_account_id = s.merchant_account_id
            and mm.user_id = pending.user_id
            and mm.active = true
            and mm.role in ('owner','admin','manager','orders')
        )
        or exists (
          select 1 from public.food_staff fs
          where fs.store_id = s.id and fs.user_id = pending.user_id
            and fs.active = true and fs.role in ('owner','staff')
        )
      )
  ) into eligible;
  if not eligible then return false; end if;

  insert into public.zoky_line_connections
    (store_id, user_id, line_user_id, linked_at, revoked_at)
  values (pending.store_id, pending.user_id, p_line_user_id, clock_timestamp(), null)
  on conflict (store_id, user_id)
  do update set line_user_id = excluded.line_user_id,
                linked_at = excluded.linked_at, revoked_at = null;

  update public.zoky_line_link_requests
     set consumed_at = clock_timestamp()
   where nonce_sha256 = pending.nonce_sha256;
  return true;
end;
$$;
revoke all on function public.zoky_line_complete_link(text,text)
  from public, anon, authenticated;
grant execute on function public.zoky_line_complete_link(text,text)
  to service_role;

-- Review still required:
-- - Store UUID and active merchant role verification in start-link endpoint.
-- - Auth JWT gets user_id from Supabase auth.getUser, never from client body.
-- - RLS/permission tests as anon/authenticated, cross-store user, service_role.
-- - Revoke/unlink operation checks current ownership + deletes pending links.
-- - PostgreSQL concurrent replay test, unique-index conflict test, rollback test.
-- - Zoky/WYNOS brand isolation and staging/prod segregation.
