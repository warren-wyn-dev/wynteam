-- Sandbox-only minimal social identity dependencies for the WYNOS Food schema.
-- NEVER apply to production. No customer records are copied or seeded.
-- This is a compatibility bootstrap, not the full WYNOS Social schema.
create schema if not exists internal;
revoke all on schema internal from public, anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "Sandbox profiles own row" on public.profiles for all to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke all on public.profiles from public, anon, authenticated;
grant select, insert, update on public.profiles to authenticated;

create table if not exists public.drops (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  created_at timestamptz not null default now()
);
alter table public.drops enable row level security;
revoke all on public.drops from public, anon, authenticated;

create table if not exists public.developer_accounts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.developer_accounts enable row level security;
revoke all on public.developer_accounts from public, anon, authenticated;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  reason text,
  created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
create policy "Sandbox notification recipient read" on public.notifications
 for select to authenticated using (recipient_id = (select auth.uid()));
revoke all on public.notifications from public, anon, authenticated;
grant select on public.notifications to authenticated;
