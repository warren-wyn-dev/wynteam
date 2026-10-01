-- WYNOS Merchant separate signup/application surface.
-- Auth remains shared with WYNOS; Merchant approval is stored separately and
-- cannot be escalated to approved by the applicant.

create table if not exists public.merchant_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  business_name text not null check (char_length(business_name) between 1 and 120),
  business_type text not null default 'food' check (business_type in ('food', 'retail', 'service', 'other')),
  contact_name text not null check (char_length(contact_name) between 1 and 120),
  phone text not null check (char_length(phone) between 3 and 50),
  address text not null check (char_length(address) between 1 and 800),
  note text check (note is null or char_length(note) <= 1200),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  rejection_reason text check (rejection_reason is null or char_length(rejection_reason) <= 1200),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null,
  terms_accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.merchant_applications enable row level security;

drop policy if exists "Merchant applicants can view own application" on public.merchant_applications;
create policy "Merchant applicants can view own application"
on public.merchant_applications
for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Merchant applicants can create own application" on public.merchant_applications;
create policy "Merchant applicants can create own application"
on public.merchant_applications
for insert
to authenticated
with check ((select auth.uid()) = user_id and status = 'pending');

drop policy if exists "Merchant applicants can edit pending or rejected application" on public.merchant_applications;
create policy "Merchant applicants can edit pending or rejected application"
on public.merchant_applications
for update
to authenticated
using ((select auth.uid()) = user_id and status in ('pending', 'rejected'))
with check ((select auth.uid()) = user_id and status = 'pending');

revoke all on public.merchant_applications from anon;
revoke all on public.merchant_applications from authenticated;
grant select on public.merchant_applications to authenticated;
grant insert (user_id, business_name, business_type, contact_name, phone, address, note, updated_at)
  on public.merchant_applications to authenticated;
grant update (business_name, business_type, contact_name, phone, address, note, status, updated_at)
  on public.merchant_applications to authenticated;

create index if not exists merchant_applications_status_created_idx
  on public.merchant_applications (status, created_at);
