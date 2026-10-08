-- WYNOS Food GP / commissions: isolated QA scaffolding only.
-- No default rate, no Stripe application_fee_amount, no money transfers.
-- Every configuration remains DRAFT, projection only.
-- Authz: a separate, empty QA allowlist provisioned ONLY by service_role;
-- ordinary merchants, moderators, developers and anonymous users cannot write.
-- Do NOT deploy this migration to the production Supabase project.
create table if not exists public.food_gp_admin_allowlist (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now(),
  note text not null default 'WYNOS GP QA admin'
);

create table if not exists public.food_gp_store_rates (
  store_id uuid primary key references public.food_stores(id) on delete cascade,
  rate_bps integer not null check (rate_bps between 0 and 10000),
  basis text not null default 'food_subtotal_excluding_delivery'
    check (basis = 'food_subtotal_excluding_delivery'),
  mode text not null default 'simulation_only'
    check (mode = 'simulation_only'),
  updated_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.food_gp_rate_audit (
  id bigint generated always as identity primary key,
  store_id uuid not null references public.food_stores(id) on delete restrict,
  previous_rate_bps integer,
  new_rate_bps integer not null check (new_rate_bps between 0 and 10000),
  actor_id uuid not null references auth.users(id),
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  created_at timestamptz not null default now(),
  mode text not null default 'simulation_only' check (mode = 'simulation_only')
);

-- In particular, never expose allowlist or commission data as a PostgREST table.
alter table public.food_gp_admin_allowlist enable row level security;
alter table public.food_gp_store_rates enable row level security;
alter table public.food_gp_rate_audit enable row level security;
revoke all on table public.food_gp_admin_allowlist, public.food_gp_store_rates,
  public.food_gp_rate_audit from public, anon, authenticated;
grant select, insert, update, delete on table public.food_gp_admin_allowlist,
  public.food_gp_store_rates, public.food_gp_rate_audit to service_role;
revoke all on sequence public.food_gp_rate_audit_id_seq from public, anon, authenticated;
grant usage, select on sequence public.food_gp_rate_audit_id_seq to service_role;

create or replace function public.wynos_gp_qa_is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.food_gp_admin_allowlist a
    where a.user_id = (select auth.uid())
  );
$$;
revoke all on function public.wynos_gp_qa_is_admin() from public, anon;
grant execute on function public.wynos_gp_qa_is_admin() to authenticated, service_role;

-- Only the explicitly allowlisted WYNOS GP admin can list config, never all users.
create or replace function public.admin_food_gp_list()
returns table (
 store_id uuid, store_name text, store_slug text, rate_bps integer,
 updated_at timestamptz, mode text
)
language plpgsql stable security definer set search_path = ''
as $$
begin
 if not public.wynos_gp_qa_is_admin() then
   raise exception 'Only WYNOS GP admins' using errcode = '42501';
 end if;
 return query
 select s.id,s.name,s.slug,r.rate_bps,r.updated_at,r.mode
 from public.food_stores s
 left join public.food_gp_store_rates r on r.store_id=s.id
 order by s.name,s.id
 limit 500;
end;
$$;
revoke all on function public.admin_food_gp_list() from public, anon;
grant execute on function public.admin_food_gp_list() to authenticated, service_role;

-- Optimistic concurrency and an audit reason prevent silent overwrites.
-- NULL is "not configured"; explicit 0 is allowed but NOT collected.
create or replace function public.admin_food_gp_set_draft(
 p_store_id uuid,
 p_rate_bps integer,
 p_expected_rate_bps integer,
 p_reason text
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
 v_prior integer;
 v_actor uuid := (select auth.uid());
 v_note text := btrim(coalesce(p_reason,''));
begin
 if not public.wynos_gp_qa_is_admin() then
   raise exception 'Only WYNOS GP admins' using errcode = '42501';
 end if;
 if p_store_id is null or not exists (select 1 from public.food_stores where id=p_store_id) then
   raise exception 'store not found';
 end if;
 if p_rate_bps is null or p_rate_bps < 0 or p_rate_bps > 10000 then
   raise exception 'GP basis points must be between 0 and 10000';
 end if;
 if char_length(v_note) not between 3 and 500 then
   raise exception 'GP reason must have 3 to 500 characters';
 end if;
 -- Serialize changes to this store, including the absent-row case.
 perform 1 from public.food_stores where id=p_store_id for update;
 select r.rate_bps into v_prior
 from public.food_gp_store_rates r where r.store_id=p_store_id;
 if v_prior is distinct from p_expected_rate_bps then
   raise exception 'GP rate changed; reload before saving';
 end if;
 if v_prior is not distinct from p_rate_bps then
   return jsonb_build_object('saved',false,'rate_bps',v_prior,'mode','simulation_only');
 end if;
 insert into public.food_gp_store_rates(store_id,rate_bps,updated_by)
 values (p_store_id,p_rate_bps,v_actor)
 on conflict (store_id) do update
 set rate_bps=excluded.rate_bps,updated_by=excluded.updated_by,updated_at=now();
 insert into public.food_gp_rate_audit
   (store_id,previous_rate_bps,new_rate_bps,actor_id,reason)
 values (p_store_id,v_prior,p_rate_bps,v_actor,v_note);
 return jsonb_build_object('saved',true,'rate_bps',p_rate_bps,'mode','simulation_only');
end;
$$;
revoke all on function public.admin_food_gp_set_draft(uuid,integer,integer,text) from public, anon;
grant execute on function public.admin_food_gp_set_draft(uuid,integer,integer,text) to authenticated, service_role;

-- Financial preview only. satang integer arithmetic, rounded half up;
-- the rate is a percentage of food subtotal, excludes delivery fees.
-- This function never writes payment, payout, order, or Stripe data.
create or replace function public.admin_food_gp_preview(
 p_store_id uuid,
 p_food_subtotal_satang bigint
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
 v_rate integer;
 v_gp bigint;
begin
 if not public.wynos_gp_qa_is_admin() then
   raise exception 'Only WYNOS GP admins' using errcode = '42501';
 end if;
 if p_store_id is null or not exists (select 1 from public.food_stores where id=p_store_id) then
   raise exception 'store not found';
 end if;
 if p_food_subtotal_satang is null or p_food_subtotal_satang < 0
    or p_food_subtotal_satang > 100000000000 then
   raise exception 'invalid food amount';
 end if;
 select rate_bps into v_rate
 from public.food_gp_store_rates where store_id=p_store_id;
 if v_rate is null then
   return jsonb_build_object('configured',false,'mode','simulation_only');
 end if;
 v_gp := floor(p_food_subtotal_satang::numeric * v_rate / 10000 + 0.5)::bigint;
 return jsonb_build_object(
   'configured',true,'mode','simulation_only',
   'food_subtotal_satang',p_food_subtotal_satang,
   'rate_bps',v_rate,'estimated_gp_satang',v_gp,
   'estimated_store_before_other_fees_satang',p_food_subtotal_satang-v_gp,
   'actually_collected_gp_satang',0
 );
end;
$$;
revoke all on function public.admin_food_gp_preview(uuid,bigint) from public, anon;
grant execute on function public.admin_food_gp_preview(uuid,bigint) to authenticated, service_role;
