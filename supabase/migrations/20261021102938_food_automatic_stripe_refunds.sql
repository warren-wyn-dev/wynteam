-- Durable, prospective automatic refunds. Disabled until worker and Cron are verified.
-- Existing cancelled orders are intentionally not backfilled.
create table if not exists internal.food_auto_refund_settings (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false,
  store_ids uuid[],
  project_url text check(project_url ~ '^https://[a-z0-9-]+[.]supabase[.]co$')
);
insert into internal.food_auto_refund_settings(singleton) values(true) on conflict do nothing;
alter table internal.food_auto_refund_settings enable row level security;
revoke all on internal.food_auto_refund_settings from public,anon,authenticated;

create table if not exists internal.food_auto_refunds (
  order_id uuid primary key references public.food_orders(id) on delete restrict,
  state text not null default 'queued' check(state in ('queued','processing','pending','retry','complete','needs_review')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  lease_token uuid,
  lease_until timestamptz,
  refund_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table internal.food_auto_refunds enable row level security;
revoke all on internal.food_auto_refunds from public,anon,authenticated;
create index if not exists food_auto_refunds_due_idx on internal.food_auto_refunds(next_attempt_at)
where state in ('queued','pending','retry','processing');

create or replace function internal.food_enqueue_auto_refund()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status='cancelled' and new.payment_provider='stripe' and new.payment_status='paid'
     and new.stripe_payment_intent_id is not null
     and exists(select 1 from internal.food_auto_refund_settings s where s.enabled
       and (s.store_ids is null or new.store_id=any(s.store_ids))) then
    insert into internal.food_auto_refunds(order_id) values(new.id) on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function internal.food_enqueue_auto_refund() from public,anon,authenticated;
drop trigger if exists food_enqueue_auto_refund on public.food_orders;
create trigger food_enqueue_auto_refund after insert or update of status,payment_status on public.food_orders
for each row execute function internal.food_enqueue_auto_refund();

create or replace function public.food_auto_refund_authorized(p_token text)
returns boolean language sql stable security definer set search_path='' as $$
select p_token is not null and length(p_token)>=64 and exists(
  select 1 from vault.decrypted_secrets where name='wynos_food_auto_refund_cron_key' and decrypted_secret=p_token
);
$$;
revoke all on function public.food_auto_refund_authorized(text) from public,anon,authenticated;
grant execute on function public.food_auto_refund_authorized(text) to service_role;

create or replace function public.food_claim_auto_refunds()
returns table(order_id uuid,lease_token uuid,refund_id text)
language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from internal.food_auto_refund_settings where enabled) then return; end if;
  update internal.food_auto_refunds j set state='needs_review',updated_at=now()
  where j.attempts>=8 and j.state in ('retry','processing') and coalesce(j.lease_until,now())<=now();
  return query with due as (
    select j.order_id from internal.food_auto_refunds j
    join public.food_orders o on o.id=j.order_id
    join internal.food_auto_refund_settings s on s.singleton
    where j.state in ('queued','pending','retry','processing') and j.attempts<8
      and j.next_attempt_at<=now() and coalesce(j.lease_until,now())<=now()
      and (s.store_ids is null or o.store_id=any(s.store_ids))
    order by j.next_attempt_at for update of j skip locked limit 2
  ) update internal.food_auto_refunds j
  set state='processing',lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes',
      attempts=j.attempts+1,updated_at=now()
  from due where j.order_id=due.order_id returning j.order_id,j.lease_token,j.refund_id;
end $$;
revoke all on function public.food_claim_auto_refunds() from public,anon,authenticated;
grant execute on function public.food_claim_auto_refunds() to service_role;

create or replace function public.food_finish_auto_refund(p_order_id uuid,p_lease uuid,p_outcome text,p_refund_id text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_job internal.food_auto_refunds%rowtype; v_now timestamptz:=now();
begin
  select * into v_job from internal.food_auto_refunds where order_id=p_order_id for update;
  if not found or v_job.state<>'processing' or v_job.lease_token is distinct from p_lease then return false; end if;
  if p_outcome not in ('succeeded','pending','retry','needs_review') then raise exception 'invalid outcome'; end if;
  if p_refund_id is not null and p_refund_id !~ '^re_[A-Za-z0-9]+$' then raise exception 'invalid refund id'; end if;
  if p_outcome in ('succeeded','pending') and p_refund_id is null then raise exception 'refund id required'; end if;
  if p_refund_id is not null then
    update public.food_orders set stripe_refund_id=p_refund_id,
      refund_requested_at=coalesce(refund_requested_at,v_now),
      refund_status=case when p_outcome='succeeded' then 'refunded' when refund_status='refunded' then refund_status else 'pending' end,
      payment_status=case when p_outcome='succeeded' then 'refunded' else payment_status end,
      refunded_at=case when p_outcome='succeeded' then coalesce(refunded_at,v_now) else refunded_at end
    where id=p_order_id and status='cancelled' and payment_provider='stripe' and payment_status in ('paid','refunded');
    if not found then raise exception 'refund order no longer eligible'; end if;
  end if;
  if p_outcome='succeeded' then
    update public.food_stripe_payments set application_fee_refunded_satang=application_fee_satang,
      application_fee_refunded_at=case when application_fee_satang>0 then coalesce(application_fee_refunded_at,v_now) else application_fee_refunded_at end,
      status='refunded'
    where order_id=p_order_id;
    if not found then raise exception 'refund ledger missing'; end if;
  end if;
  if p_outcome='needs_review' or (p_outcome='retry' and v_job.attempts>=8) then
    update public.food_orders set refund_status='failed'
    where id=p_order_id and status='cancelled' and refund_status<>'refunded';
  end if;
  update internal.food_auto_refunds set
    state=case when p_outcome='succeeded' then 'complete' when p_outcome='retry' and attempts>=8 then 'needs_review' else p_outcome end,
    attempts=case when p_outcome='pending' then 0 else attempts end,
    next_attempt_at=v_now+case when p_outcome='pending' then interval '10 minutes' else interval '1 minute' * least(60,power(2,attempts)::integer) end,
    refund_id=coalesce(p_refund_id,refund_id),lease_until=null,lease_token=null,updated_at=v_now
  where order_id=p_order_id;
  return true;
end $$;
revoke all on function public.food_finish_auto_refund(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.food_finish_auto_refund(uuid,uuid,text,text) to service_role;

create or replace function internal.food_auto_refund_tick()
returns bigint language plpgsql security definer set search_path='' as $$
declare v_token text; v_url text; v_request_id bigint;
begin
  select project_url into v_url from internal.food_auto_refund_settings where enabled;
  if v_url is null or not exists(select 1 from internal.food_auto_refunds where state in ('queued','pending','retry','processing') and next_attempt_at<=now()) then return null; end if;
  select decrypted_secret into v_token from vault.decrypted_secrets where name='wynos_food_auto_refund_cron_key';
  if nullif(v_token,'') is null then raise exception 'auto refund cron key missing'; end if;
  select net.http_post(url:=v_url||'/functions/v1/food-auto-refund',
    headers:=jsonb_build_object('Content-Type','application/json','x-wynos-cron-key',v_token),
    body:='{}'::jsonb,timeout_milliseconds:=60000) into v_request_id;
  return v_request_id;
end $$;
revoke all on function internal.food_auto_refund_tick() from public,anon,authenticated;

-- No rate, rollout, cron, key, historical refund or enabled setting changed here.
