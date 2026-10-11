-- WYNOS Merchant GP v1: per-store GP rates, kept as history, snapshotted on
-- every order, collected as a Stripe application fee.
--
-- Founder decisions (AskUserQuestion, 2026-10-11, .wyn/company/DECISIONS.md):
--   * Default GP: WYNOS does not take GP yet -> with no rate row every store
--     resolves to 0%. Nothing changes for any order until the super admin
--     sets a rate above 0.
--   * GP base: food value after the store's own discount. Delivery is not in
--     the base; a discount WYNOS funds does not lower the base.
--         base = subtotal - max(campaign_discount - platform_funded, 0)
--   * Collection: Stripe application fee on each Stripe order. Orders paid by
--     PromptPay slip straight to the store carry a GP figure but nothing is
--     collected (reported as not collectable).
--   * Only the super admin sets or cancels GP. No second approver.
--
-- Money is integer satang; rates are integer basis points (2000 = 20.00%).
-- Rounding: GP = round half up to the satang of base * rate / 10000, capped at
-- the amount the customer pays (Stripe refuses a larger fee).
--
-- History is append-only: a rate is never edited or deleted. A new row with a
-- later effective_from replaces the older one; a temporary rate ends at
-- effective_to and the earlier rate applies again. A store row with no rate
-- (rate_bp null) means "back to the default" from its start. Only a rate that has not
-- started yet can be cancelled. Rates cannot start in the past, so a change
-- never moves money on orders already placed: each order keeps the rate it
-- was placed with (gp_rate_bp / gp_rate_id / gp_rule_version).
--
-- Test: supabase/tests/merchant_gp_v1_test.sh
-- ROLLBACK: supabase/rollbacks/20261011140000_merchant_gp_v1_rollback.sql

-- ------------------------------------------------------------
-- Rates
-- ------------------------------------------------------------

create table if not exists public.merchant_gp_rates (
  id uuid primary key default gen_random_uuid(),
  -- null = the default for every store without a rate of its own.
  store_id uuid references public.food_stores (id) on delete restrict,
  -- null (store rows only) = follow the default from effective_from.
  rate_bp integer check (rate_bp between 0 and 10000),
  effective_from timestamptz not null,
  effective_to timestamptz,
  reason text not null check (char_length(btrim(reason)) between 3 and 300),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  idempotency_key uuid not null,
  -- md5 of the whole request, so a reused key with any different value is refused.
  request_fingerprint text not null,
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles (id) on delete set null,
  cancel_reason text check (cancel_reason is null or char_length(btrim(cancel_reason)) between 3 and 300),
  constraint merchant_gp_rates_period_check check (effective_to is null or effective_to > effective_from),
  constraint merchant_gp_rates_default_has_rate check (rate_bp is not null or store_id is not null),
  constraint merchant_gp_rates_idempotency_unique unique (idempotency_key)
);

create index if not exists merchant_gp_rates_store_from_idx
  on public.merchant_gp_rates (store_id, effective_from desc);

alter table public.merchant_gp_rates enable row level security;
-- No policies and no grants: read and written only through the RPCs below.
revoke all on table public.merchant_gp_rates from public, anon, authenticated;

-- Append-only guard: no deletes; the only update is cancelling a rate that
-- has not started yet.
create or replace function internal.merchant_gp_rates_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'GP history cannot be deleted';
  end if;
  if old.cancelled_at is not null then
    raise exception 'GP rate is already cancelled';
  end if;
  if old.effective_from <= now() then
    raise exception 'GP rate already in effect cannot be changed';
  end if;
  if new.cancelled_at is null
     or (new.id, new.store_id, new.rate_bp, new.effective_from, new.effective_to, new.reason,
         new.created_by, new.created_at, new.idempotency_key, new.request_fingerprint)
        is distinct from
        (old.id, old.store_id, old.rate_bp, old.effective_from, old.effective_to, old.reason,
         old.created_by, old.created_at, old.idempotency_key, old.request_fingerprint) then
    raise exception 'GP rates are append-only; only a future rate can be cancelled';
  end if;
  return new;
end;
$$;

drop trigger if exists merchant_gp_rates_guard on public.merchant_gp_rates;
create trigger merchant_gp_rates_guard
  before update or delete on public.merchant_gp_rates
  for each row execute function internal.merchant_gp_rates_guard();

-- The rate row that applies to a store at a moment: the store's own latest
-- row covering that moment, unless that row says "back to the default"
-- (rate_bp null); then the default's latest covering row; else none (0%).
create or replace function internal.merchant_gp_rate_at(p_store_id uuid, p_at timestamptz)
returns table (rate_id uuid, rate_bp integer, source text)
language sql
stable
security definer
set search_path = ''
as $$
  with store_row as (
    select r.id, r.rate_bp
    from public.merchant_gp_rates r
    where p_store_id is not null
      and r.store_id = p_store_id
      and r.cancelled_at is null
      and r.effective_from <= p_at
      and (r.effective_to is null or p_at < r.effective_to)
    order by r.effective_from desc, r.created_at desc
    limit 1
  ),
  default_row as (
    select r.id, r.rate_bp
    from public.merchant_gp_rates r
    where r.store_id is null
      and r.cancelled_at is null
      and r.effective_from <= p_at
      and (r.effective_to is null or p_at < r.effective_to)
    order by r.effective_from desc, r.created_at desc
    limit 1
  )
  select s.id, s.rate_bp, 'store' from store_row s where s.rate_bp is not null
  union all
  select d.id, d.rate_bp, 'default' from default_row d
  where not exists (select 1 from store_row s where s.rate_bp is not null);
$$;

revoke all on function internal.merchant_gp_rate_at(uuid, timestamptz) from public, anon, authenticated;

-- ------------------------------------------------------------
-- Snapshot on every order
-- ------------------------------------------------------------

alter table public.food_orders
  add column if not exists gp_rate_bp integer,
  add column if not exists gp_rate_id uuid,
  add column if not exists gp_rule_version text;

alter table public.food_stripe_payments
  add column if not exists application_fee_satang bigint not null default 0,
  -- Set by merchant-stripe-refund when it asks Stripe to return the fee
  -- (refund_application_fee). A refund made outside WYNOS keeps the fee.
  add column if not exists application_fee_refunded_satang bigint not null default 0,
  add column if not exists application_fee_refunded_at timestamptz;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'food_stripe_payments_application_fee_check') then
    alter table public.food_stripe_payments
      add constraint food_stripe_payments_application_fee_check
      check (application_fee_satang >= 0 and application_fee_satang <= amount_satang);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'food_stripe_payments_fee_refunded_check') then
    alter table public.food_stripe_payments
      add constraint food_stripe_payments_fee_refunded_check
      check (application_fee_refunded_satang >= 0 and application_fee_refunded_satang <= application_fee_satang);
  end if;
end
$$;

-- Set by the database on insert whatever the caller sends, and frozen after.
create or replace function internal.food_orders_gp_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rate record;
begin
  if tg_op = 'INSERT' then
    select * into v_rate from internal.merchant_gp_rate_at(new.store_id, now());
    new.gp_rate_bp := coalesce(v_rate.rate_bp, 0);
    new.gp_rate_id := v_rate.rate_id;
    new.gp_rule_version := 'gp_v1_food_after_store_discount';
  else
    new.gp_rate_bp := old.gp_rate_bp;
    new.gp_rate_id := old.gp_rate_id;
    new.gp_rule_version := old.gp_rule_version;
  end if;
  return new;
end;
$$;

revoke all on function internal.food_orders_gp_snapshot() from public, anon, authenticated;

drop trigger if exists food_orders_gp_snapshot on public.food_orders;
create trigger food_orders_gp_snapshot
  before insert or update of gp_rate_bp, gp_rate_id, gp_rule_version on public.food_orders
  for each row execute function internal.food_orders_gp_snapshot();

-- GP of one order from its snapshot. Orders placed before GP v1 have no
-- snapshot and count as 0%.
create or replace function internal.food_order_gp(p_order_id uuid)
returns table (base_satang bigint, rate_bp integer, gp_satang bigint, total_satang bigint)
language sql
stable
security definer
set search_path = ''
as $$
  with o as (
    select
      greatest(
        round((o.subtotal - greatest(coalesce(foc.campaign_discount, 0) - coalesce(foc.platform_funded, 0), 0)) * 100),
        0
      )::bigint as base_satang,
      coalesce(o.gp_rate_bp, 0) as rate_bp,
      round(o.total * 100)::bigint as total_satang
    from public.food_orders o
    left join public.food_order_campaigns foc on foc.order_id = o.id
    where o.id = p_order_id
  )
  select o.base_satang, o.rate_bp,
         least((o.base_satang * o.rate_bp + 5000) / 10000, o.total_satang)::bigint,
         o.total_satang
  from o;
$$;

revoke all on function internal.food_order_gp(uuid) from public, anon, authenticated;

-- For the food-stripe-checkout Edge Function (service role only).
create or replace function public.food_order_gp_quote(p_order_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('base_satang', g.base_satang, 'rate_bp', g.rate_bp,
                            'gp_satang', g.gp_satang, 'total_satang', g.total_satang)
  from internal.food_order_gp(p_order_id) g;
$$;

revoke all on function public.food_order_gp_quote(uuid) from public, anon, authenticated;
grant execute on function public.food_order_gp_quote(uuid) to service_role;

-- ------------------------------------------------------------
-- Audit event types (additive; keeps every existing value)
-- ------------------------------------------------------------

do $$
declare
  v_name text;
  v_def text;
  v_values text[];
  v_new text[] := array['admin_gp_rate_set', 'admin_gp_rate_cancelled'];
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
-- Admin RPCs
-- ------------------------------------------------------------

-- Read: merchant:view. Default rate now, every store's rate now and next
-- change, and the full history.
create or replace function public.admin_gp_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not internal.has_admin_permission('merchant', 'view') then
    raise exception 'Not authorized';
  end if;

  select jsonb_build_object(
    'can_edit', internal.is_super_admin(),
    'rule_version', 'gp_v1_food_after_store_discount',
    'default', (
      select jsonb_build_object(
        'rate_bp', coalesce(r.rate_bp, 0),
        'rate_id', r.rate_id,
        'next', (
          select jsonb_build_object('id', n.id, 'rate_bp', n.rate_bp, 'effective_from', n.effective_from, 'effective_to', n.effective_to)
          from public.merchant_gp_rates n
          where n.store_id is null and n.cancelled_at is null and n.effective_from > now()
          order by n.effective_from, n.created_at desc limit 1
        )
      )
      from (select 1) one
      left join lateral (
        select g.rate_id, g.rate_bp from internal.merchant_gp_rate_at(null, now()) g where g.source = 'default'
      ) r on true
    ),
    'stores', coalesce((
      select jsonb_agg(jsonb_build_object(
        'store_id', s.id,
        'store_name', s.name,
        'is_published', s.is_published,
        'suspended', s.admin_suspended_at is not null,
        'rate_bp', coalesce(cur.rate_bp, 0),
        'source', coalesce(cur.source, 'none'),
        'next', (
          select jsonb_build_object('id', n.id, 'rate_bp', n.rate_bp, 'effective_from', n.effective_from, 'effective_to', n.effective_to)
          from public.merchant_gp_rates n
          where n.store_id = s.id and n.cancelled_at is null and n.effective_from > now()
          order by n.effective_from, n.created_at desc limit 1
        )
      ) order by s.name)
      from public.food_stores s
      left join lateral (select * from internal.merchant_gp_rate_at(s.id, now())) cur on true
    ), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'store_id', r.store_id,
        'store_name', s.name,
        'rate_bp', r.rate_bp,
        'effective_from', r.effective_from,
        'effective_to', r.effective_to,
        'reason', r.reason,
        'created_by_username', cb.username,
        'created_at', r.created_at,
        'cancelled_at', r.cancelled_at,
        'cancelled_by_username', xb.username,
        'cancel_reason', r.cancel_reason
      ) order by r.created_at desc)
      from (select * from public.merchant_gp_rates order by created_at desc limit 500) r
      left join public.food_stores s on s.id = r.store_id
      left join public.profiles cb on cb.id = r.created_by
      left join public.profiles xb on xb.id = r.cancelled_by
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.admin_gp_settings() from public, anon;
grant execute on function public.admin_gp_settings() to authenticated;

-- Full GP history, newest first, one page at a time (merchant:view):
-- rows created before p_before (null = now), at most 500 per page.
create or replace function public.admin_gp_history(p_before timestamptz default null, p_limit integer default 200)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 200), 1), 500);
  v_rows jsonb;
begin
  if not internal.has_admin_permission('merchant', 'view') then
    raise exception 'Not authorized';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id,
      'store_id', r.store_id,
      'store_name', s.name,
      'rate_bp', r.rate_bp,
      'effective_from', r.effective_from,
      'effective_to', r.effective_to,
      'reason', r.reason,
      'created_by_username', cb.username,
      'created_at', r.created_at,
      'cancelled_at', r.cancelled_at,
      'cancelled_by_username', xb.username,
      'cancel_reason', r.cancel_reason
    ) order by r.created_at desc, r.id desc), '[]'::jsonb)
  into v_rows
  from (
    select * from public.merchant_gp_rates
    where created_at < coalesce(p_before, 'infinity'::timestamptz)
    order by created_at desc, id desc
    limit v_limit + 1
  ) r
  left join public.food_stores s on s.id = r.store_id
  left join public.profiles cb on cb.id = r.created_by
  left join public.profiles xb on xb.id = r.cancelled_by;

  -- One extra row tells the page whether an older page exists.
  return jsonb_build_object(
    'rows', (select coalesce(jsonb_agg(e order by ord), '[]'::jsonb)
             from jsonb_array_elements(v_rows) with ordinality as t(e, ord) where ord <= v_limit),
    'has_more', jsonb_array_length(v_rows) > v_limit
  );
end;
$$;

revoke all on function public.admin_gp_history(timestamptz, integer) from public, anon;
grant execute on function public.admin_gp_history(timestamptz, integer) to authenticated;

-- Write: super admin only. p_store_id null = the default rate.
-- p_rate_bp null (store only) = the store goes back to following the default.
-- p_effective_from null = now. Never in the past (one minute of clock slack).
-- Repeating the same p_idempotency_key with the same request returns the
-- first row unchanged; with any different value it is refused.
create or replace function public.admin_set_gp_rate(
  p_store_id uuid,
  p_rate_bp integer,
  p_effective_from timestamptz,
  p_effective_to timestamptz,
  p_reason text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_from timestamptz := coalesce(p_effective_from, now());
  v_reason text := btrim(coalesce(p_reason, ''));
  v_existing public.merchant_gp_rates%rowtype;
  v_id uuid;
  v_previous integer;
  v_fingerprint text;
begin
  if not internal.is_super_admin() then
    raise exception 'Only the super admin can change GP';
  end if;
  if p_idempotency_key is null then
    raise exception 'idempotency key is required';
  end if;

  v_fingerprint := md5(concat_ws('|',
    coalesce(p_store_id::text, 'default'),
    coalesce(p_rate_bp::text, 'inherit'),
    coalesce(p_effective_from::text, 'now'),
    coalesce(p_effective_to::text, 'open'),
    v_reason));

  select * into v_existing from public.merchant_gp_rates where idempotency_key = p_idempotency_key;
  if found then
    if v_existing.created_by is distinct from v_admin or v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'idempotency key was used for a different change';
    end if;
    return v_existing.id;
  end if;

  if p_rate_bp is null and p_store_id is null then
    raise exception 'the default GP needs a rate';
  end if;
  if p_rate_bp is not null and (p_rate_bp < 0 or p_rate_bp > 10000) then
    raise exception 'GP must be between 0 and 100 percent';
  end if;
  if char_length(v_reason) < 3 or char_length(v_reason) > 300 then
    raise exception 'a reason of 3-300 characters is required';
  end if;
  if v_from < now() - interval '1 minute' then
    raise exception 'GP cannot start in the past';
  end if;
  if p_effective_to is not null and p_effective_to <= v_from then
    raise exception 'end must be after start';
  end if;
  if p_store_id is not null and not exists (select 1 from public.food_stores where id = p_store_id) then
    raise exception 'store not found';
  end if;

  select g.rate_bp into v_previous from internal.merchant_gp_rate_at(p_store_id, v_from) g;

  -- A concurrent request with the same key waits here for the first one,
  -- then inserts nothing and is answered like any other retry.
  insert into public.merchant_gp_rates (store_id, rate_bp, effective_from, effective_to, reason, created_by, idempotency_key, request_fingerprint)
  values (p_store_id, p_rate_bp, greatest(v_from, now()), p_effective_to, v_reason, v_admin, p_idempotency_key, v_fingerprint)
  on conflict (idempotency_key) do nothing
  returning id into v_id;
  if v_id is null then
    select * into v_existing from public.merchant_gp_rates where idempotency_key = p_idempotency_key;
    if v_existing.created_by is distinct from v_admin or v_existing.request_fingerprint <> v_fingerprint then
      raise exception 'idempotency key was used for a different change';
    end if;
    return v_existing.id;
  end if;

  perform internal.log_audit_event(
    v_admin,
    'admin_gp_rate_set',
    p_store_id,
    jsonb_build_object(
      'rate_id', v_id,
      'store_id', p_store_id,
      'scope', case when p_store_id is null then 'default' else 'store' end,
      'previous_rate_bp', coalesce(v_previous, 0),
      'rate_bp', p_rate_bp,
      'follows_default', p_rate_bp is null,
      'effective_from', greatest(v_from, now()),
      'effective_to', p_effective_to,
      'reason', v_reason
    )
  );
  return v_id;
end;
$$;

revoke all on function public.admin_set_gp_rate(uuid, integer, timestamptz, timestamptz, text, uuid) from public, anon;
grant execute on function public.admin_set_gp_rate(uuid, integer, timestamptz, timestamptz, text, uuid) to authenticated;

-- Cancel a rate that has not started yet (super admin only).
create or replace function public.admin_cancel_gp_rate(p_rate_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_admin uuid := auth.uid();
  v_reason text := btrim(coalesce(p_reason, ''));
  v_rate public.merchant_gp_rates%rowtype;
begin
  if not internal.is_super_admin() then
    raise exception 'Only the super admin can change GP';
  end if;
  if char_length(v_reason) < 3 or char_length(v_reason) > 300 then
    raise exception 'a reason of 3-300 characters is required';
  end if;
  select * into v_rate from public.merchant_gp_rates where id = p_rate_id for update;
  if not found then
    raise exception 'GP rate not found';
  end if;
  if v_rate.cancelled_at is not null then
    raise exception 'GP rate is already cancelled';
  end if;
  if v_rate.effective_from <= now() then
    raise exception 'GP rate already in effect cannot be cancelled';
  end if;

  update public.merchant_gp_rates
     set cancelled_at = now(), cancelled_by = v_admin, cancel_reason = v_reason
   where id = p_rate_id;

  perform internal.log_audit_event(
    v_admin,
    'admin_gp_rate_cancelled',
    v_rate.store_id,
    jsonb_build_object('rate_id', v_rate.id, 'store_id', v_rate.store_id, 'rate_bp', v_rate.rate_bp,
                       'effective_from', v_rate.effective_from, 'reason', v_reason)
  );
end;
$$;

revoke all on function public.admin_cancel_gp_rate(uuid, text) from public, anon;
grant execute on function public.admin_cancel_gp_rate(uuid, text) to authenticated;
