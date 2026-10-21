-- Serialize the prospective queue cutover; do not abandon an in-flight refund.
lock table public.food_orders in share row exclusive mode;
do $$ begin
if exists(select 1 from internal.food_auto_refunds where state<>'complete') then
raise exception 'Drain earlier automatic refund jobs before migration';
end if;
end $$;
-- Financial operations: all private facts, immutable refund reservations and
-- dual-control adjustments. No provider money movement is enabled here.
create table internal.food_payment_facts (
  order_id uuid primary key references public.food_orders(id),
  charge_id text not null, balance_transaction_id text,
  processor_fee_satang bigint check(processor_fee_satang>=0),
  charged_satang bigint not null check(charged_satang>0),
  refunded_satang bigint not null default 0 check(refunded_satang>=0),
  gp_refunded_satang bigint not null default 0 check(gp_refunded_satang>=0),
  gp_charged_satang bigint not null check(gp_charged_satang>=0),
  available_on date, provider_status text not null,
  checked_at timestamptz not null default now(),
  check(refunded_satang<=charged_satang)
);
create table internal.food_finance_refunds (
  id uuid primary key default gen_random_uuid(),
  queue_number bigint generated always as identity unique,
  order_id uuid not null references public.food_orders(id),
  request_key uuid not null unique,
  fingerprint text not null,
  kind text not null check(kind in ('full','items')),
  items jsonb not null default '[]',
  food_satang bigint not null check(food_satang>=0),
  delivery_satang bigint not null check(delivery_satang>=0),
  gp_satang bigint not null check(gp_satang>=0),
  reason text not null check(length(btrim(reason)) between 3 and 500),
  requested_by uuid references public.profiles(id),
  state text not null default 'queued' check(state in ('queued','processing','pending','succeeded','needs_review')),
  refund_id text, fee_refund_id text,
  attempts integer not null default 0, lease uuid, lease_until timestamptz,
  next_attempt_at timestamptz not null default now(),
  created_at timestamptz not null default now(), completed_at timestamptz,
  check(food_satang+delivery_satang>0)
);
create index food_finance_refunds_order_idx on internal.food_finance_refunds(order_id);
create table internal.food_finance_adjustments (
  id uuid primary key default gen_random_uuid(), store_id uuid not null references public.food_stores(id),
  amount_satang bigint not null check(amount_satang<>0 and abs(amount_satang)<=100000000),
  reason text not null check(length(btrim(reason)) between 3 and 500),
  request_key uuid not null unique,
  proposed_by uuid not null references public.profiles(id),
  reviewed_by uuid references public.profiles(id), review_reason text,
  state text not null default 'pending' check(state in ('pending','approved','rejected')),
  created_at timestamptz not null default now(), reviewed_at timestamptz,
  check(reviewed_by is null or reviewed_by<>proposed_by)
);
create table internal.food_finance_reconciliation (
  order_id uuid primary key references public.food_orders(id),
  issue text not null check(issue in ('awaiting_provider','amount_mismatch','refund_mismatch','gp_mismatch','matched')),
  checked_at timestamptz not null default now()
);
create table internal.food_finance_payout_runs (
  id uuid primary key default gen_random_uuid(),store_id uuid not null references public.food_stores(id),account_id text not null,
  business_day date not null, cutoff_at timestamptz not null,
  state text not null default 'awaiting_funds' check(state in ('awaiting_funds','requires_configuration','processing','submitted','paid','failed')),
  amount_satang bigint not null default 0 check(amount_satang>=0),
  provider_payout_id text unique, arrival_date date,
  lease uuid, lease_until timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint food_finance_payout_store_day unique(store_id,business_day)
);
create table internal.food_managed_payouts (
  store_id uuid primary key references public.food_stores(id), account_id text not null, enabled boolean not null default false,
  starts_at timestamptz not null default now(), opening_balance_satang bigint not null default 0,
  configured_by uuid, configured_at timestamptz not null default now()
);
create table internal.food_provider_transactions (
  account_id text not null, transaction_id text not null, store_id uuid not null references public.food_stores(id),
  amount_satang bigint not null, fee_satang bigint not null, net_satang bigint not null,
  source_id text, kind text not null, provider_created_at timestamptz not null,
  available_on date, status text not null check(status in ('available','pending')),
  primary key(account_id,transaction_id), check(amount_satang-fee_satang=net_satang)
);
create table internal.food_provider_account_checks (
  store_id uuid primary key references public.food_stores(id), account_id text not null,
  next_cursor text, backfill_complete boolean not null default false,
  reconciled boolean not null default false, observed_balance_satang bigint,
  checked_at timestamptz not null default now()
);
alter table internal.food_finance_adjustments add column provider_transfer_id text unique;
alter table internal.food_finance_adjustments add column funding_started_at timestamptz;
alter table internal.food_finance_adjustments add column funding_account_id text;
create table internal.food_finance_audit (
  id bigint generated always as identity primary key, actor_id uuid,
  action text not null, target_id uuid, detail jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create table internal.food_finance_issuer (
  singleton boolean primary key default true check(singleton),
  display_name text not null, address text not null,
  vat_registered boolean not null default false check(not vat_registered),
  updated_at timestamptz not null default now()
);
create table internal.food_finance_documents (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.food_stores(id),
  document_number bigint generated always as identity unique,
  period_from date not null, period_to date not null,
  payload jsonb not null, created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);
do $$ declare t text; begin
foreach t in array array['food_payment_facts','food_finance_refunds','food_finance_adjustments','food_finance_reconciliation','food_finance_payout_runs','food_finance_audit','food_finance_issuer','food_finance_documents','food_managed_payouts','food_provider_transactions','food_provider_account_checks'] loop
execute format('alter table internal.%I enable row level security',t);
execute format('revoke all on internal.%I from public,anon,authenticated',t);
end loop;
end $$;

create function internal.food_finance_manager(p_store_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
select auth.uid() is not null and (exists(select 1 from public.food_stores s
join public.merchant_memberships m on m.merchant_account_id=s.merchant_account_id
where s.id=p_store_id and m.user_id=auth.uid() and m.active and m.role in ('owner','admin','manager'))
or exists(select 1 from public.food_staff f where f.store_id=p_store_id and f.user_id=auth.uid() and f.active and f.role='owner'));
$$;
revoke all on function internal.food_finance_manager(uuid) from public,anon,authenticated;

create function internal.food_finance_admin(p_edit boolean default false)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare allowed boolean:=false;
begin
if auth.uid() is null then return false; end if;
if to_regprocedure('internal.has_admin_permission(text,text)') is not null then
execute 'select internal.has_admin_permission(''merchant'',$1)' into allowed using case when p_edit then 'edit' else 'view' end;
elsif exists(select 1 from internal.food_auto_refund_settings where project_url='https://pcatuxtenluqzjzzwsvl.supabase.co')
and to_regprocedure('public.wynos_gp_qa_is_admin()') is not null then
-- Reuse the isolated project's existing explicit QA finance allowlist.
-- No account, profile role, membership or privilege is granted here.
execute 'select public.wynos_gp_qa_is_admin()' into allowed;
end if;
return coalesce(allowed,false);
end $$;
revoke all on function internal.food_finance_admin(boolean) from public,anon,authenticated;

create function public.food_finance_admin_access()
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('user_id',auth.uid(),'can_view',internal.food_finance_admin(false),'can_edit',internal.food_finance_admin(true));
$$;
revoke all on function public.food_finance_admin_access() from public,anon;
grant execute on function public.food_finance_admin_access() to authenticated;

create function public.merchant_finance_order_lines(p_store_id uuid,p_from date,p_to date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
if not internal.food_finance_manager(p_store_id) then raise exception 'merchant manager access required'; end if;
if p_from is null or p_to is null or p_to<p_from or p_to-p_from>365 then raise exception 'invalid date range'; end if;
return jsonb_build_object('orders',coalesce((select jsonb_agg(x order by x->>'paid_at' desc) from (
select jsonb_build_object('id',o.id,'order_number',o.order_number,'paid_at',o.paid_at,
 'food_satang',round(o.subtotal*100)::bigint,'delivery_satang',round(o.delivery_fee*100)::bigint,
 'discount_satang',round((o.subtotal+o.delivery_fee-o.total)*100)::bigint,
 'paid_satang',round(o.total*100)::bigint,'gp_satang',coalesce(f.gp_charged_satang,p.application_fee_satang),
 'gp_rate_bp',coalesce(o.gp_rate_bp,0),'processor_fee_satang',f.processor_fee_satang,
 'refunded_satang',f.refunded_satang,'gp_refunded_satang',f.gp_refunded_satang,
 'net_satang',case when f.processor_fee_satang is not null then round(o.total*100)::bigint-f.refunded_satang-f.gp_charged_satang+f.gp_refunded_satang-f.processor_fee_satang end,
 'available_on',f.available_on,'checked_at',f.checked_at,'payment_status',o.payment_status,
 'items',(select jsonb_agg(jsonb_build_object('id',i.id,'name',i.item_name,'quantity',i.quantity,'unit_satang',round(i.unit_price*100)::bigint)) from public.food_order_items i where i.order_id=o.id),
 'reconciliation',coalesce(r.issue,'awaiting_provider')) x
from public.food_orders o join public.food_stripe_payments p on p.order_id=o.id
left join internal.food_payment_facts f on f.order_id=o.id
left join internal.food_finance_reconciliation r on r.order_id=o.id
where o.store_id=p_store_id and o.payment_status in ('paid','refunded')
and (coalesce(o.paid_at,o.created_at) at time zone 'Asia/Bangkok')::date between p_from and p_to
) q),'[]'),
'payouts',coalesce((select jsonb_agg(to_jsonb(p)-'store_id') from internal.food_finance_payout_runs p where p.store_id=p_store_id and p.business_day between p_from and p_to),'[]'),
'refunds',coalesce((select jsonb_agg(to_jsonb(r)-'fingerprint'-'lease'-'lease_until') from internal.food_finance_refunds r join public.food_orders o on o.id=r.order_id where o.store_id=p_store_id and (r.created_at at time zone 'Asia/Bangkok')::date between p_from and p_to),'[]'),
'adjustments',coalesce((select jsonb_agg(to_jsonb(a)-'proposed_by'-'reviewed_by') from internal.food_finance_adjustments a where a.store_id=p_store_id and (a.created_at at time zone 'Asia/Bangkok')::date between p_from and p_to),'[]'));
end $$;
revoke all on function public.merchant_finance_order_lines(uuid,date,date) from public,anon;
grant execute on function public.merchant_finance_order_lines(uuid,date,date) to authenticated;

create function public.merchant_request_item_refund(p_order_id uuid,p_items jsonb,p_reason text,p_request_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype; p public.food_stripe_payments%rowtype;
v_items jsonb; v_gross bigint; v_food bigint; v_gp bigint; v_prev_food bigint; v_prev_gp bigint;
v_subtotal bigint; v_food_total bigint; v_id uuid; v_fp text; v_existing internal.food_finance_refunds%rowtype;
begin
if auth.uid() is null then raise exception 'authentication required'; end if;
if p_request_key is null or length(btrim(coalesce(p_reason,''))) not between 3 and 500
or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 100 then raise exception 'invalid refund request'; end if;
select * into o from public.food_orders where id=p_order_id for update;
if not found or not (internal.food_finance_manager(o.store_id) or internal.food_finance_admin(true)) then raise exception 'refund authorization required'; end if;
-- Post-delivery claims must be reviewed by a platform administrator.
if o.status='delivered' and not internal.food_finance_admin(true) then raise exception 'delivered refund requires admin review'; end if;
v_fp:=md5(jsonb_build_array(p_order_id,p_items,btrim(p_reason))::text);
select * into v_existing from internal.food_finance_refunds where request_key=p_request_key;
if found then if v_existing.fingerprint<>v_fp then raise exception 'request key conflict'; end if; return v_existing.id; end if;
if o.payment_status<>'paid' or o.payment_provider<>'stripe' or o.status='cancelled' then raise exception 'refund not eligible'; end if;
if exists(select 1 from internal.food_auto_refunds where order_id=o.id and state<>'complete') then raise exception 'full refund in progress'; end if;
select * into strict p from public.food_stripe_payments where order_id=o.id;
if exists(select 1 from jsonb_array_elements(p_items) x where jsonb_typeof(x)<>'object' or coalesce(x->>'quantity','') !~ '^[1-9][0-9]{0,3}$' or coalesce(x->>'item_id','') !~ '^[0-9a-fA-F-]{36}$') then raise exception 'invalid item quantity'; end if;
if (select count(distinct x->>'item_id') from jsonb_array_elements(p_items) x)<>jsonb_array_length(p_items) then raise exception 'duplicate item'; end if;
if exists(select 1 from jsonb_array_elements(p_items) x left join public.food_order_items i on i.id=(x->>'item_id')::uuid and i.order_id=o.id
where i.id is null or (x->>'quantity')::integer+coalesce((select sum((y->>'quantity')::integer) from internal.food_finance_refunds r cross join lateral jsonb_array_elements(r.items) y where r.order_id=o.id and y->>'item_id'=x->>'item_id'),0)>i.quantity) then raise exception 'quantity exceeds refundable items'; end if;
v_subtotal:=round(o.subtotal*100)::bigint;
if v_subtotal<=0 or v_subtotal<>(select sum(round(unit_price*100)::bigint*quantity) from public.food_order_items where order_id=o.id) then raise exception 'invalid food subtotal'; end if;
select coalesce(sum(round(i.unit_price*100)::bigint*(x->>'quantity')::integer),0),jsonb_agg(jsonb_build_object('item_id',i.id,'quantity',(x->>'quantity')::integer))
into v_gross,v_items from jsonb_array_elements(p_items) x join public.food_order_items i on i.id=(x->>'item_id')::uuid and i.order_id=o.id;
v_food_total:=round((o.subtotal-coalesce((select campaign_discount from public.food_order_campaigns where order_id=o.id),0))*100)::bigint;
select coalesce(sum(food_satang),0),coalesce(sum(gp_satang),0) into v_prev_food,v_prev_gp from internal.food_finance_refunds where order_id=o.id;
-- Cumulative item allocation avoids double rounding and reserves all attempts,
-- including jobs needing review, until explicitly reconciled.
v_food:=floor(((coalesce((select sum(round(i.unit_price*100)::bigint*(y->>'quantity')::integer) from internal.food_finance_refunds r cross join lateral jsonb_array_elements(r.items) y join public.food_order_items i on i.id=(y->>'item_id')::uuid where r.order_id=o.id),0)+v_gross)*v_food_total+v_subtotal/2)/v_subtotal)-v_prev_food;
v_gp:=least(p.application_fee_satang,((v_prev_food+v_food)*p.application_fee_satang+greatest(v_food_total,1)/2)/greatest(v_food_total,1))-v_prev_gp;
if v_food<=0 or v_gp<0 or v_prev_food+v_food>p.amount_satang then raise exception 'invalid refund allocation'; end if;
insert into internal.food_finance_refunds(order_id,request_key,fingerprint,kind,items,food_satang,delivery_satang,gp_satang,reason,requested_by)
values(o.id,p_request_key,v_fp,'items',v_items,v_food,0,v_gp,btrim(p_reason),auth.uid()) returning id into v_id;
insert into internal.food_finance_audit(actor_id,action,target_id) values(auth.uid(),'item_refund_requested',v_id);
return v_id;
end $$;
revoke all on function public.merchant_request_item_refund(uuid,jsonb,text,uuid) from public,anon;
grant execute on function public.merchant_request_item_refund(uuid,jsonb,text,uuid) to authenticated;

create function public.admin_food_finance_adjust(p_store_id uuid,p_amount_satang bigint,p_reason text,p_request_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare a internal.food_finance_adjustments%rowtype;
begin
if not internal.food_finance_admin(true) then raise exception 'finance admin required'; end if;
select * into a from internal.food_finance_adjustments where request_key=p_request_key;
if found then
if a.store_id<>p_store_id or a.amount_satang<>p_amount_satang or a.reason<>btrim(p_reason) or a.proposed_by<>auth.uid() then raise exception 'request key conflict'; end if;
return a.id;
end if;
insert into internal.food_finance_adjustments(store_id,amount_satang,reason,request_key,proposed_by)
values(p_store_id,p_amount_satang,btrim(p_reason),p_request_key,auth.uid()) returning * into a;
insert into internal.food_finance_audit(actor_id,action,target_id) values(auth.uid(),'adjustment_proposed',a.id);
return a.id;
end $$;
revoke all on function public.admin_food_finance_adjust(uuid,bigint,text,uuid) from public,anon;
grant execute on function public.admin_food_finance_adjust(uuid,bigint,text,uuid) to authenticated;

create function public.admin_food_finance_review(p_id uuid,p_approve boolean,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare a internal.food_finance_adjustments%rowtype;
begin
if not internal.food_finance_admin(true) then raise exception 'finance admin required'; end if;
select * into strict a from internal.food_finance_adjustments where id=p_id for update;
if a.proposed_by=auth.uid() then raise exception 'second administrator required'; end if;
if a.state<>'pending' or p_approve is null or length(btrim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'invalid review'; end if;
update internal.food_finance_adjustments set state=case when p_approve then 'approved' else 'rejected' end,reviewed_by=auth.uid(),reviewed_at=now(),review_reason=btrim(p_reason) where id=p_id;
insert into internal.food_finance_audit(actor_id,action,target_id,detail) values(auth.uid(),'adjustment_reviewed',p_id,jsonb_build_object('approved',p_approve));
end $$;
revoke all on function public.admin_food_finance_review(uuid,boolean,text) from public,anon;
grant execute on function public.admin_food_finance_review(uuid,boolean,text) to authenticated;

create function public.admin_food_finance_operations(p_from date,p_to date)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
if not internal.food_finance_admin(false) then raise exception 'finance admin required'; end if;
if p_from is null or p_to is null or p_to<p_from or p_to-p_from>365 then raise exception 'invalid date range'; end if;
return jsonb_build_object(
'stores',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.food_stores),'[]'),
'audit',coalesce((select jsonb_agg(to_jsonb(a)) from (select * from internal.food_finance_audit where (created_at at time zone 'Asia/Bangkok')::date between p_from and p_to order by id desc limit 200) a),'[]'),
'gp_rates',coalesce((select jsonb_agg(jsonb_build_object('id',id,'store_id',store_id,'rate_bp',rate_bp,'effective_from',effective_from,'reason',reason)) from public.merchant_gp_rates),'[]'),
'adjustments',coalesce((select jsonb_agg(to_jsonb(a)) from internal.food_finance_adjustments a where (a.created_at at time zone 'Asia/Bangkok')::date between p_from and p_to),'[]'),
'reconciliation',coalesce((select jsonb_agg(to_jsonb(r)) from internal.food_finance_reconciliation r where r.issue<>'matched'),'[]'),
'refunds',coalesce((select jsonb_agg(to_jsonb(r)-'fingerprint'-'lease') from internal.food_finance_refunds r where r.state<>'succeeded'),'[]'),
'payouts',coalesce((select jsonb_agg(to_jsonb(p)) from internal.food_finance_payout_runs p where p.business_day between p_from and p_to),'[]'));
end $$;
revoke all on function public.admin_food_finance_operations(date,date) from public,anon;
grant execute on function public.admin_food_finance_operations(date,date) to authenticated;

create function public.admin_food_finance_order(p_order_number text)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare o public.food_orders%rowtype;
begin
if not internal.food_finance_admin(true) then raise exception 'finance admin required'; end if;
if p_order_number !~ '^WF[0-9]{6,12}$' then raise exception 'invalid order number'; end if;
select * into strict o from public.food_orders where order_number=p_order_number;
return jsonb_build_object('id',o.id,'order_number',o.order_number,'status',o.status,'payment_status',o.payment_status,
'items',(select jsonb_agg(jsonb_build_object('id',i.id,'name',i.item_name,'quantity',i.quantity)) from public.food_order_items i where i.order_id=o.id));
end $$;
revoke all on function public.admin_food_finance_order(text) from public,anon;
grant execute on function public.admin_food_finance_order(text) to authenticated;

create function public.admin_food_finance_retry_refund(p_id uuid,p_refund_id text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare r internal.food_finance_refunds%rowtype;
begin
if not internal.food_finance_admin(true) then raise exception 'finance admin required'; end if;
if length(btrim(coalesce(p_reason,''))) not between 3 and 500 or (p_refund_id is not null and p_refund_id !~ '^re_[A-Za-z0-9]+$') then raise exception 'invalid review'; end if;
select * into strict r from internal.food_finance_refunds where id=p_id for update;
if r.state<>'needs_review' or (r.refund_id is not null and p_refund_id is not null and r.refund_id<>p_refund_id) then raise exception 'refund review conflict'; end if;
if r.created_at<now()-interval '20 hours' and coalesce(r.refund_id,p_refund_id) is null then raise exception 'provider refund id required for old request'; end if;
update internal.food_finance_refunds set state='queued',attempts=0,lease=null,lease_until=null,next_attempt_at=now(),refund_id=coalesce(refund_id,p_refund_id) where id=p_id;
insert into internal.food_finance_audit(actor_id,action,target_id,detail) values(auth.uid(),'refund_retry_reviewed',p_id,jsonb_build_object('reason',btrim(p_reason)));
end $$;
revoke all on function public.admin_food_finance_retry_refund(uuid,text,text) from public,anon;
grant execute on function public.admin_food_finance_retry_refund(uuid,text,text) to authenticated;

create function public.food_finance_sync_candidates()
returns table(order_id uuid,payment_intent_id text,stripe_account_id text,livemode boolean)
language sql security definer set search_path='' as $$
select o.id,p.payment_intent_id,p.stripe_account_id,p.livemode
from public.food_orders o join public.food_stripe_payments p on p.order_id=o.id
left join internal.food_payment_facts f on f.order_id=o.id
join internal.food_auto_refund_settings s on s.singleton
where s.enabled and (s.store_ids is null or o.store_id=any(s.store_ids))
and o.payment_status in ('paid','refunded') and p.payment_intent_id is not null
order by f.checked_at nulls first limit 10;
$$;
revoke all on function public.food_finance_sync_candidates() from public,anon,authenticated;
grant execute on function public.food_finance_sync_candidates() to service_role;

create function public.food_record_payment_facts(p_order_id uuid,p_charge_id text,p_balance_id text,p_fee bigint,
p_amount bigint,p_refunded bigint,p_gp_refunded bigint,p_gp_charged bigint,p_available_on date,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare p public.food_stripe_payments%rowtype; v_issue text;
begin
select * into strict p from public.food_stripe_payments where order_id=p_order_id for update;
if p_charge_id !~ '^ch_[A-Za-z0-9]+$' or p_amount<=0 or p_refunded<0 or p_refunded>p_amount
or p_gp_charged<0 or p_gp_charged>p_amount or p_gp_refunded<0 or p_gp_refunded>p_gp_charged or (p_fee is not null and p_fee<0)
or p_status not in ('available','pending') then raise exception 'invalid provider facts'; end if;
insert into internal.food_payment_facts(order_id,charge_id,balance_transaction_id,processor_fee_satang,
charged_satang,refunded_satang,gp_refunded_satang,gp_charged_satang,available_on,provider_status)
values(p_order_id,p_charge_id,p_balance_id,p_fee,p_amount,p_refunded,p_gp_refunded,p_gp_charged,p_available_on,p_status)
on conflict(order_id) do update set charge_id=excluded.charge_id,balance_transaction_id=excluded.balance_transaction_id,
processor_fee_satang=excluded.processor_fee_satang,charged_satang=excluded.charged_satang,
refunded_satang=excluded.refunded_satang,gp_refunded_satang=excluded.gp_refunded_satang,gp_charged_satang=excluded.gp_charged_satang,
available_on=excluded.available_on,provider_status=excluded.provider_status,checked_at=now();
v_issue:=case when p_amount<>p.amount_satang then 'amount_mismatch'
when p_refunded<>case when exists(select 1 from internal.food_finance_refunds r where r.order_id=p_order_id and r.state='succeeded')
then (select sum(food_satang+delivery_satang) from internal.food_finance_refunds r where r.order_id=p_order_id and r.state='succeeded')
when p.status='refunded' then p.amount_satang else 0 end then 'refund_mismatch'
when p_gp_charged<>p.application_fee_satang or p_gp_refunded<>p.application_fee_refunded_satang then 'gp_mismatch'
when p_fee is null then 'awaiting_provider' else 'matched' end;
insert into internal.food_finance_reconciliation(order_id,issue) values(p_order_id,v_issue)
on conflict(order_id) do update set issue=excluded.issue,checked_at=now();
end $$;
revoke all on function public.food_record_payment_facts(uuid,text,text,bigint,bigint,bigint,bigint,bigint,date,text) from public,anon,authenticated;
grant execute on function public.food_record_payment_facts(uuid,text,text,bigint,bigint,bigint,bigint,bigint,date,text) to service_role;

create function public.merchant_finance_document(p_store_id uuid,p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_data jsonb; v_issuer jsonb; v_id uuid; v_number bigint;
begin
if not internal.food_finance_manager(p_store_id) then raise exception 'merchant manager access required'; end if;
select jsonb_build_object('name',display_name,'address',address,'vat_registered',false) into v_issuer from internal.food_finance_issuer where singleton;
if v_issuer is null then raise exception 'document issuer not configured'; end if;
v_data:=public.merchant_finance_order_lines(p_store_id,p_from,p_to);
v_data:=v_data||jsonb_build_object('issuer',v_issuer,'from',p_from,'to',p_to,'store_name',(select name from public.food_stores where id=p_store_id),
'document_type','statement','vat_invoice',false,'generated_at',now(),'currency','THB');
insert into internal.food_finance_documents(store_id,period_from,period_to,payload,created_by)
values(p_store_id,p_from,p_to,v_data,auth.uid()) returning id,document_number into v_id,v_number;
insert into internal.food_finance_audit(actor_id,action,target_id) values(auth.uid(),'statement_created',v_id);
return v_data||jsonb_build_object('id',v_id,'document_number','ZOKY-ST-'||lpad(v_number::text,8,'0'));
end $$;
revoke all on function public.merchant_finance_document(uuid,date,date) from public,anon;
grant execute on function public.merchant_finance_document(uuid,date,date) to authenticated;

create function internal.food_reserve_cancelled_refund(p_order_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare o public.food_orders%rowtype; p public.food_stripe_payments%rowtype; v_id uuid;
v_food bigint; v_delivery bigint; v_gp bigint; v_reserved bigint;
begin
select * into strict o from public.food_orders where id=p_order_id for update;
if o.status<>'cancelled' or o.payment_status<>'paid' or o.payment_provider<>'stripe' then return null; end if;
if not exists(select 1 from internal.food_auto_refund_settings s where s.enabled and (s.store_ids is null or o.store_id=any(s.store_ids))) then return null; end if;
select id into v_id from internal.food_finance_refunds where order_id=o.id and kind='full';
if found then return v_id; end if;
select * into strict p from public.food_stripe_payments where order_id=o.id;
select coalesce(sum(food_satang+delivery_satang),0) into v_reserved from internal.food_finance_refunds where order_id=o.id;
if exists(select 1 from internal.food_payment_facts f where f.order_id=o.id and f.refunded_satang>coalesce((select sum(food_satang+delivery_satang) from internal.food_finance_refunds where order_id=o.id and state='succeeded'),0)) then raise exception 'external refund requires reconciliation'; end if;
v_food:=round((o.subtotal-coalesce((select campaign_discount from public.food_order_campaigns where order_id=o.id),0))*100)::bigint-coalesce((select sum(food_satang) from internal.food_finance_refunds where order_id=o.id),0);
v_delivery:=p.amount_satang-v_reserved-v_food;
v_gp:=p.application_fee_satang-coalesce((select sum(gp_satang) from internal.food_finance_refunds where order_id=o.id),0);
if v_food<0 or v_delivery<0 or v_gp<0 then raise exception 'refund budgets require reconciliation'; end if;
if v_food+v_delivery=0 then return null; end if;
insert into internal.food_finance_refunds(order_id,request_key,fingerprint,kind,food_satang,delivery_satang,gp_satang,reason)
values(o.id,gen_random_uuid(),md5(o.id::text||'cancelled_remaining'),'full',v_food,v_delivery,v_gp,'Automatic cancellation refund') returning id into v_id;
return v_id;
end $$;
revoke all on function internal.food_reserve_cancelled_refund(uuid) from public,anon,authenticated;

-- Replaces the earlier full-only queue prospectively; old jobs must be drained
-- before rollout. No scan or backfill of existing cancelled orders.
create or replace function internal.food_enqueue_auto_refund()
returns trigger language plpgsql security definer set search_path='' as $$
begin
if new.status='cancelled' and new.payment_provider='stripe' and new.payment_status='paid' then
perform internal.food_reserve_cancelled_refund(new.id);
end if;
return new;
end $$;
revoke all on function internal.food_enqueue_auto_refund() from public,anon,authenticated;

create function public.merchant_request_cancelled_refund(p_order_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_store uuid;
begin
select store_id into v_store from public.food_orders where id=p_order_id;
if not internal.food_finance_manager(v_store) then raise exception 'merchant manager access required'; end if;
return internal.food_reserve_cancelled_refund(p_order_id);
end $$;
revoke all on function public.merchant_request_cancelled_refund(uuid) from public,anon;
grant execute on function public.merchant_request_cancelled_refund(uuid) to authenticated;

create function public.food_finance_claim_refunds()
returns table(request_id uuid,order_id uuid,lease uuid,refund_id text,food_satang bigint,delivery_satang bigint,gp_satang bigint,payment_intent_id text,stripe_account_id text,livemode boolean,attempts integer,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
update internal.food_finance_refunds expired set state='needs_review'
where expired.state='processing' and expired.attempts>=8 and expired.lease_until<=now();
return query with due as (
select r.id from internal.food_finance_refunds r join public.food_orders o on o.id=r.order_id
join internal.food_auto_refund_settings s on s.singleton
where s.enabled and (s.store_ids is null or o.store_id=any(s.store_ids))
and r.state in ('queued','pending','processing') and r.attempts<8 and r.next_attempt_at<=now()
and coalesce(r.lease_until,now())<=now()
and not exists(select 1 from internal.food_finance_refunds prev where prev.order_id=r.order_id and prev.queue_number<r.queue_number and prev.state<>'succeeded')
order by r.queue_number for update of r skip locked limit 2
), claimed as (
update internal.food_finance_refunds r set state='processing',lease=gen_random_uuid(),lease_until=now()+interval '3 minutes',attempts=r.attempts+1
from due where r.id=due.id returning r.*
) select r.id,r.order_id,r.lease,r.refund_id,r.food_satang,r.delivery_satang,r.gp_satang,p.payment_intent_id,p.stripe_account_id,p.livemode,r.attempts,r.created_at
from claimed r join public.food_stripe_payments p on p.order_id=r.order_id;
end $$;
revoke all on function public.food_finance_claim_refunds() from public,anon,authenticated;
grant execute on function public.food_finance_claim_refunds() to service_role;

create function public.food_finance_finish_refund(p_id uuid,p_lease uuid,p_state text,p_refund_id text,p_fee_refund_id text)
returns boolean language plpgsql security definer set search_path='' as $$
declare r internal.food_finance_refunds%rowtype; v_total bigint; v_gp bigint;
begin
select * into r from internal.food_finance_refunds where id=p_id for update;
if not found or r.state<>'processing' or r.lease is distinct from p_lease then return false; end if;
if p_state not in ('pending','succeeded','retry','needs_review') or (p_refund_id is not null and p_refund_id !~ '^re_[A-Za-z0-9]+$')
or (p_fee_refund_id is not null and p_fee_refund_id !~ '^fr_[A-Za-z0-9]+$') then raise exception 'invalid provider refund'; end if;
if p_state='succeeded' and (p_refund_id is null or (r.gp_satang>0 and p_fee_refund_id is null)) then raise exception 'refund verification incomplete'; end if;
update internal.food_finance_refunds set state=case when p_state='retry' and attempts<8 then 'queued' when p_state='retry' then 'needs_review' else p_state end,
refund_id=coalesce(p_refund_id,refund_id),fee_refund_id=coalesce(p_fee_refund_id,fee_refund_id),lease=null,lease_until=null,
attempts=case when p_state='pending' then 0 else attempts end,
next_attempt_at=now()+case when p_state='pending' then interval '10 minutes' else interval '1 minute'*least(60,power(2,attempts)::integer) end,
completed_at=case when p_state='succeeded' then now() else null end where id=p_id;
if p_state='succeeded' then
select coalesce(sum(food_satang+delivery_satang),0),coalesce(sum(gp_satang),0) into v_total,v_gp
from internal.food_finance_refunds where order_id=r.order_id and state='succeeded';
update public.food_stripe_payments set application_fee_refunded_satang=v_gp,application_fee_refunded_at=case when v_gp>0 then now() else application_fee_refunded_at end,
status=case when v_total=amount_satang then 'refunded' else status end
where order_id=r.order_id and v_gp<=application_fee_satang;
if not found then raise exception 'GP ledger mismatch'; end if;
update public.food_orders set stripe_refund_id=p_refund_id,
payment_status=case when v_total=round(total*100)::bigint then 'refunded' else payment_status end,
refund_status=case when v_total=round(total*100)::bigint then 'refunded' else refund_status end,
refunded_at=case when v_total=round(total*100)::bigint then coalesce(refunded_at,now()) else refunded_at end where id=r.order_id;
end if;
return true;
end $$;
revoke all on function public.food_finance_finish_refund(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.food_finance_finish_refund(uuid,uuid,text,text,text) to service_role;

create function public.food_store_managed_payouts(p_store_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from internal.food_managed_payouts m join public.food_stripe_accounts a on a.store_id=m.store_id
where m.store_id=p_store_id and m.enabled and m.account_id=a.stripe_account_id);
$$;
revoke all on function public.food_store_managed_payouts(uuid) from public,anon,authenticated;
grant execute on function public.food_store_managed_payouts(uuid) to service_role;

create function public.admin_food_finance_configuration_access(p_store_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
select internal.food_finance_admin(true) and exists(select 1 from public.food_stores where id=p_store_id);
$$;
revoke all on function public.admin_food_finance_configuration_access(uuid) from public,anon;
grant execute on function public.admin_food_finance_configuration_access(uuid) to authenticated;

create function public.food_enable_managed_payouts(p_store_id uuid,p_opening bigint,p_actor uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
if public.food_store_managed_payouts(p_store_id) then return; end if;
if exists(select 1 from internal.food_finance_payout_runs where store_id=p_store_id and state in ('processing','submitted')) then raise exception 'existing payouts require reconciliation'; end if;
insert into internal.food_managed_payouts(store_id,account_id,enabled,opening_balance_satang,configured_by)
values(p_store_id,(select stripe_account_id from public.food_stripe_accounts where store_id=p_store_id),true,p_opening,p_actor)
on conflict(store_id) do update set enabled=true,account_id=excluded.account_id,opening_balance_satang=excluded.opening_balance_satang,starts_at=now(),configured_by=excluded.configured_by,configured_at=now();
insert into internal.food_finance_audit(actor_id,action,target_id) values(p_actor,'managed_payouts_enabled',p_store_id);
end $$;
revoke all on function public.food_enable_managed_payouts(uuid,bigint,uuid) from public,anon,authenticated;
grant execute on function public.food_enable_managed_payouts(uuid,bigint,uuid) to service_role;

create function public.food_finance_payout_candidates()
returns table(run_id uuid,store_id uuid,stripe_account_id text,livemode boolean,lease uuid,amount_satang bigint,provider_payout_id text,created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare v_day date:=(now() at time zone 'Asia/Bangkok')::date; v_cutoff timestamptz;
begin
v_cutoff:=v_day::timestamp at time zone 'Asia/Bangkok';
update internal.food_finance_payout_runs r set state=case when p.status='paid' then 'paid' else 'failed' end,updated_at=now()
from public.food_stripe_payouts p where p.payout_id=r.provider_payout_id and r.state='submitted' and p.status in ('paid','failed','canceled');
insert into internal.food_finance_payout_runs(store_id,account_id,business_day,cutoff_at)
select m.store_id,m.account_id,v_day-1,v_cutoff from internal.food_managed_payouts m
join internal.food_auto_refund_settings s on s.singleton
where m.enabled and s.enabled and (s.store_ids is null or m.store_id=any(s.store_ids))
on conflict on constraint food_finance_payout_store_day do nothing;
-- Closing is allowed at midnight; initiating starts at 08:00 Bangkok.
if (now() at time zone 'Asia/Bangkok')::time<'08:00' then return; end if;
return query with due as (
 select r.id from internal.food_finance_payout_runs r join internal.food_managed_payouts m on m.store_id=r.store_id
 where m.enabled and r.account_id=m.account_id and r.business_day=v_day-1 and r.state in ('awaiting_funds','processing')
 and coalesce(r.lease_until,now())<=now()
 order by r.created_at for update of r skip locked limit 2
),claimed as (
update internal.food_finance_payout_runs r set lease=gen_random_uuid(),lease_until=now()+interval '3 minutes'
from due where r.id=due.id returning r.*
)
select r.id,r.store_id,a.stripe_account_id,a.livemode,r.lease,r.amount_satang,r.provider_payout_id,r.created_at
from claimed r join public.food_stripe_accounts a on a.store_id=r.store_id and a.stripe_account_id=r.account_id;
end $$;
revoke all on function public.food_finance_payout_candidates() from public,anon,authenticated;
grant execute on function public.food_finance_payout_candidates() to service_role;

create function public.food_finance_prepare_payout(p_id uuid,p_lease uuid,p_available bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare r internal.food_finance_payout_runs%rowtype; m internal.food_managed_payouts%rowtype; v_owed bigint;
begin
select * into r from internal.food_finance_payout_runs where id=p_id for update;
if not found or r.lease is distinct from p_lease or r.lease_until<now() then raise exception 'invalid payout lease'; end if;
if r.amount_satang>0 then return r.amount_satang; end if;
select * into strict m from internal.food_managed_payouts where store_id=r.store_id and enabled for update;
if r.account_id<>m.account_id or not public.food_store_managed_payouts(r.store_id) then raise exception 'payout account changed'; end if;
-- Do not pay while refunds, provider facts, fees or adjustments are unresolved.
if exists(select 1 from internal.food_finance_refunds f join public.food_orders o on o.id=f.order_id where o.store_id=r.store_id and f.state<>'succeeded')
or not exists(select 1 from internal.food_provider_account_checks c where c.store_id=r.store_id and c.account_id=r.account_id and c.reconciled and c.backfill_complete and c.checked_at>now()-interval '30 minutes')
or exists(select 1 from public.food_orders o left join internal.food_payment_facts f on f.order_id=o.id
where o.store_id=r.store_id and o.paid_at>=m.starts_at and o.paid_at<r.cutoff_at
and o.payment_provider='stripe' and o.payment_status in ('paid','refunded')
and (f.processor_fee_satang is null or f.checked_at<now()-interval '1 day'))
or exists(select 1 from internal.food_finance_reconciliation c join public.food_orders o on o.id=c.order_id where o.store_id=r.store_id and c.issue not in ('matched'))
or exists(select 1 from internal.food_finance_adjustments a where a.store_id=r.store_id and a.state='approved' and a.amount_satang>0 and a.provider_transfer_id is null)
then return 0; end if;
-- Provider balance transactions include historic automatic payouts, refunds,
-- fees and platform funding. Never reconstruct an opening balance from order
-- timestamps or pay the same historic money twice after schedule migration.
v_owed:=coalesce((select sum(t.net_satang) from internal.food_provider_transactions t where t.store_id=r.store_id and t.account_id=r.account_id
and (t.net_satang<0 or (t.status='available' and t.provider_created_at<r.cutoff_at))),0)
+coalesce((select sum(a.amount_satang) from internal.food_finance_adjustments a where a.store_id=r.store_id and a.state='approved' and a.amount_satang<0 and a.reviewed_at<r.cutoff_at),0)
-coalesce((select sum(p.amount_satang) from internal.food_finance_payout_runs p where p.store_id=r.store_id and p.account_id=r.account_id and p.state in ('submitted','paid','processing') and p.id<>r.id
and not exists(select 1 from internal.food_provider_transactions t where t.account_id=(select stripe_account_id from public.food_stripe_accounts where store_id=r.store_id) and t.source_id=p.provider_payout_id)),0);
v_owed:=greatest(0,least(v_owed,greatest(0,p_available)));
if v_owed>0 then update internal.food_finance_payout_runs set amount_satang=v_owed,state='processing',updated_at=now() where id=r.id; end if;
return v_owed;
end $$;
revoke all on function public.food_finance_prepare_payout(uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function public.food_finance_prepare_payout(uuid,uuid,bigint) to service_role;

create function public.food_finance_finish_payout(p_id uuid,p_lease uuid,p_state text,p_provider_id text,p_arrival date)
returns boolean language plpgsql security definer set search_path='' as $$
begin
if p_state not in ('submitted','paid','failed','requires_configuration','awaiting_funds')
or (p_provider_id is not null and p_provider_id !~ '^po_[A-Za-z0-9]+$') then raise exception 'invalid payout result'; end if;
if p_state in ('submitted','paid') and p_provider_id is null then raise exception 'provider payout required'; end if;
update internal.food_finance_payout_runs set state=p_state,provider_payout_id=coalesce(p_provider_id,provider_payout_id),arrival_date=p_arrival,
lease=null,lease_until=case when p_state='awaiting_funds' then (date_trunc('day',now() at time zone 'Asia/Bangkok') at time zone 'Asia/Bangkok')+interval '1 day' else null end,updated_at=now()
where id=p_id and lease=p_lease;
return found;
end $$;
revoke all on function public.food_finance_finish_payout(uuid,uuid,text,text,date) from public,anon,authenticated;
grant execute on function public.food_finance_finish_payout(uuid,uuid,text,text,date) to service_role;

create function public.food_finance_funding_jobs()
returns table(id uuid,amount_satang bigint,account_id text,livemode boolean,started_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
if (now() at time zone 'Asia/Bangkok')::time<'08:00' then return; end if;
return query with due as (
select a.id from internal.food_finance_adjustments a join internal.food_managed_payouts m on m.store_id=a.store_id
join public.food_stripe_accounts p on p.store_id=a.store_id
join internal.food_auto_refund_settings s on s.singleton
where s.enabled and m.enabled and (s.store_ids is null or a.store_id=any(s.store_ids)) and a.state='approved'
and a.amount_satang>0 and a.provider_transfer_id is null
and a.reviewed_at<(now() at time zone 'Asia/Bangkok')::date::timestamp at time zone 'Asia/Bangkok'
and (a.funding_account_id is null or a.funding_account_id=p.stripe_account_id)
order by a.created_at for update of a skip locked limit 2
), claimed as (
update internal.food_finance_adjustments a set funding_started_at=coalesce(a.funding_started_at,now()),
funding_account_id=coalesce(a.funding_account_id,(select stripe_account_id from public.food_stripe_accounts where store_id=a.store_id))
from due where a.id=due.id returning a.*
) select a.id,a.amount_satang,a.funding_account_id,p.livemode,a.funding_started_at from claimed a join public.food_stripe_accounts p on p.store_id=a.store_id;
end $$;
revoke all on function public.food_finance_funding_jobs() from public,anon,authenticated;
grant execute on function public.food_finance_funding_jobs() to service_role;

create function public.food_finance_record_funding(p_id uuid,p_transfer_id text)
returns void language plpgsql security definer set search_path='' as $$
begin
if p_transfer_id !~ '^tr_[A-Za-z0-9]+$' then raise exception 'invalid transfer id'; end if;
update internal.food_finance_adjustments set provider_transfer_id=p_transfer_id where id=p_id and state='approved' and amount_satang>0
and (provider_transfer_id is null or provider_transfer_id=p_transfer_id);
if not found then raise exception 'funding mismatch'; end if;
end $$;
revoke all on function public.food_finance_record_funding(uuid,text) from public,anon,authenticated;
grant execute on function public.food_finance_record_funding(uuid,text) to service_role;

create function public.food_finance_sync_accounts()
returns table(store_id uuid,account_id text,livemode boolean,next_cursor text)
language sql security definer set search_path='' as $$
select a.store_id,a.stripe_account_id,a.livemode,case when c.account_id=a.stripe_account_id then c.next_cursor end from public.food_stripe_accounts a
join internal.food_auto_refund_settings s on s.singleton
left join internal.food_provider_account_checks c on c.store_id=a.store_id
where s.enabled and (s.store_ids is null or a.store_id=any(s.store_ids))
order by c.checked_at nulls first limit 5;
$$;
revoke all on function public.food_finance_sync_accounts() from public,anon,authenticated;
grant execute on function public.food_finance_sync_accounts() to service_role;

create function public.food_finance_record_transactions(p_store_id uuid,p_rows jsonb,p_balance bigint,p_cursor text,p_complete boolean)
returns void language plpgsql security definer set search_path='' as $$
declare v_account text; x record; old internal.food_provider_transactions%rowtype;
begin
select stripe_account_id into strict v_account from public.food_stripe_accounts where store_id=p_store_id;
if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)>100 or p_complete is null
or (p_cursor is not null and p_cursor !~ '^txn_[A-Za-z0-9]+$') then raise exception 'invalid transaction batch'; end if;
for x in select * from jsonb_to_recordset(p_rows) as t(id text,amount bigint,fee bigint,net bigint,source text,kind text,created_at timestamptz,available_on date,status text) loop
if x.id !~ '^txn_[A-Za-z0-9]+$' or x.amount-x.fee<>x.net or x.status not in ('available','pending') or x.kind is null or x.created_at is null then raise exception 'invalid provider transaction'; end if;
select * into old from internal.food_provider_transactions where account_id=v_account and transaction_id=x.id for update;
if found and (old.amount_satang,old.fee_satang,old.net_satang,old.source_id,old.provider_created_at)
is distinct from (x.amount,x.fee,x.net,x.source,x.created_at) then raise exception 'provider monetary history changed'; end if;
insert into internal.food_provider_transactions(account_id,transaction_id,store_id,amount_satang,fee_satang,net_satang,source_id,kind,provider_created_at,available_on,status)
values(v_account,x.id,p_store_id,x.amount,x.fee,x.net,x.source,x.kind,x.created_at,x.available_on,x.status)
on conflict(account_id,transaction_id) do update set status=excluded.status,available_on=excluded.available_on;
end loop;
insert into internal.food_provider_account_checks(store_id,account_id,next_cursor,backfill_complete,observed_balance_satang)
values(p_store_id,v_account,p_cursor,p_complete,p_balance)
on conflict(store_id) do update set next_cursor=excluded.next_cursor,
backfill_complete=case when internal.food_provider_account_checks.account_id=excluded.account_id then internal.food_provider_account_checks.backfill_complete or excluded.backfill_complete else excluded.backfill_complete end,
account_id=excluded.account_id,observed_balance_satang=excluded.observed_balance_satang,checked_at=now();
update internal.food_provider_account_checks c set reconciled=c.backfill_complete and p_complete
and coalesce((select sum(net_satang) from internal.food_provider_transactions where account_id=v_account),0)=p_balance where store_id=p_store_id;
end $$;
revoke all on function public.food_finance_record_transactions(uuid,jsonb,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.food_finance_record_transactions(uuid,jsonb,bigint,text,boolean) to service_role;

create index food_provider_transactions_store_idx on internal.food_provider_transactions(store_id,account_id,provider_created_at);
create index food_finance_adjustments_store_idx on internal.food_finance_adjustments(store_id,state,created_at);
create index food_finance_documents_store_idx on internal.food_finance_documents(store_id,created_at);
create index food_finance_audit_created_idx on internal.food_finance_audit(created_at);

create function public.admin_food_finance_gp_rate(p_store_id uuid,p_rate_bp integer,p_effective_from timestamptz,p_reason text,p_request_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_fp text; v_old text;
begin
if not internal.food_finance_admin(true) then raise exception 'finance admin required'; end if;
if p_rate_bp not between 0 and 10000 or p_rate_bp is null or p_request_key is null or length(btrim(coalesce(p_reason,''))) not between 3 and 300 then raise exception 'invalid GP rate'; end if;
if p_store_id is not null and not exists(select 1 from public.food_stores where id=p_store_id) then raise exception 'store not found'; end if;
v_fp:=md5(jsonb_build_array(p_store_id,p_rate_bp,p_effective_from,btrim(p_reason))::text);
select id,request_fingerprint into v_id,v_old from public.merchant_gp_rates where idempotency_key=p_request_key;
if found then if v_fp<>v_old then raise exception 'request key conflict'; end if; return v_id; end if;
if p_effective_from is not null and p_effective_from<now() then raise exception 'GP cannot start in the past'; end if;
insert into public.merchant_gp_rates(store_id,rate_bp,effective_from,reason,created_by,idempotency_key,request_fingerprint)
values(p_store_id,p_rate_bp,coalesce(p_effective_from,now()),btrim(p_reason),auth.uid(),p_request_key,v_fp) returning id into v_id;
insert into internal.food_finance_audit(actor_id,action,target_id,detail) values(auth.uid(),'gp_rate_scheduled',v_id,jsonb_build_object('store_id',p_store_id,'rate_bp',p_rate_bp,'effective_from',p_effective_from));
return v_id;
end $$;
revoke all on function public.admin_food_finance_gp_rate(uuid,integer,timestamptz,text,uuid) from public,anon;
grant execute on function public.admin_food_finance_gp_rate(uuid,integer,timestamptz,text,uuid) to authenticated;

-- Founder approved prospective 10% default. Existing orders retain snapshots;
-- store-specific agreements and already scheduled future rates are preserved.
insert into public.merchant_gp_rates(store_id,rate_bp,effective_from,reason,idempotency_key,request_fingerprint)
select null,1000,now(),'Founder approved default GP 10 percent on 2026-10-21',gen_random_uuid(),md5('food_finance_operations_default_10_percent')
where not exists(select 1 from public.merchant_gp_rates where store_id is null and request_fingerprint=md5('food_finance_operations_default_10_percent'));

-- Founder approved Stripe-paid customer cancellation before merchant acceptance.
create or replace function public.food_cancel_order(
  p_order_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_customer_access_enabled() then
    raise exception 'food customer access required';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id
  for update;

  if not found or v_order.buyer_id is distinct from auth.uid() then
    raise exception 'order not found';
  end if;

  if v_order.status <> 'pending_acceptance'
     or not (v_order.payment_status in ('pending','issue') or (v_order.payment_status='paid' and v_order.payment_provider='stripe')) then
    raise exception 'order cannot be cancelled by customer';
  end if;

  -- Expire the gateway session through food-stripe-cancel first. Holding the
  -- order lock makes this check atomic with Checkout assignment and webhooks.
  if v_order.payment_status<>'paid' and v_order.stripe_checkout_session_id is not null then
    raise exception 'cancel stripe checkout before cancelling order';
  end if;

  update public.food_orders
  set status = 'cancelled',
      cancelled_at = now()
  where id = p_order_id;

  insert into public.food_order_events (
    order_id, event_type, from_status, to_status, note, actor_id
  ) values (
    p_order_id,
    'customer_cancelled',
    v_order.status,
    'cancelled',
    nullif(left(trim(coalesce(p_reason,'')),1000),''),
    auth.uid()
  );
end;
$$;


revoke all on function public.food_cancel_order(uuid,text) from public,anon;
grant execute on function public.food_cancel_order(uuid,text) to authenticated;

create function internal.food_finance_tick(p_kind text)
returns bigint language plpgsql security definer set search_path='' as $$
declare v_url text; v_token text; v_request bigint;
begin
if p_kind not in ('sync','refund','payout') then raise exception 'invalid finance worker'; end if;
select project_url into v_url from internal.food_auto_refund_settings where enabled;
if v_url is null then return null; end if;
if p_kind='refund' and not exists(select 1 from internal.food_finance_refunds where state in ('queued','processing','pending') and next_attempt_at<=now()) then return null; end if;
select decrypted_secret into v_token from vault.decrypted_secrets where name='wynos_food_auto_refund_cron_key';
if length(coalesce(v_token,''))<64 then raise exception 'finance scheduler not configured'; end if;
select net.http_post(url:=v_url||'/functions/v1/food-finance-'||p_kind,
headers:=jsonb_build_object('Content-Type','application/json','x-wynos-cron-key',v_token),body:='{}'::jsonb,timeout_milliseconds:=60000) into v_request;
return v_request;
end $$;
revoke all on function internal.food_finance_tick(text) from public,anon,authenticated;

-- Preserve the existing summary contract, including partial refund/GP events.
create or replace function public.merchant_finance_summary(p_store_id uuid, p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days integer;
  v_prev_from date;
  v_prev_to date;
  v_result jsonb;
begin
  -- Checked here, not with merchant_has_store_role(): that helper also lets
  -- every developer account into any store and ignores roles for legacy
  -- food_staff rows. Money is for this store's managers only.
  if (select auth.uid()) is null or not (
    exists (
      select 1
      from public.food_stores s
      join public.merchant_memberships mm on mm.merchant_account_id = s.merchant_account_id
      where s.id = p_store_id
        and mm.user_id = (select auth.uid())
        and mm.active
        and mm.role in ('owner', 'admin', 'manager')
    )
    or exists (
      select 1
      from public.food_staff fs
      where fs.store_id = p_store_id
        and fs.user_id = (select auth.uid())
        and fs.active
        and fs.role = 'owner'
    )
  ) then
    raise exception 'merchant manager access required';
  end if;
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid date range';
  end if;
  v_days := p_to - p_from + 1;
  if v_days > 366 then
    raise exception 'date range is too long';
  end if;
  v_prev_to := p_from - 1;
  v_prev_from := p_from - v_days;

  with paid as (
    select o.id, (coalesce(o.paid_at, o.created_at) at time zone 'Asia/Bangkok')::date as day,
           o.subtotal, o.delivery_fee, o.total, o.status, o.payment_status, o.payment_provider
    from public.food_orders o
    where o.store_id = p_store_id
      and o.payment_status in ('paid', 'refunded')
      and (coalesce(o.paid_at, o.created_at) at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  refunded as (
    select (r.completed_at at time zone 'Asia/Bangkok')::date as day,
      (r.food_satang+r.delivery_satang)/100.0 as total
    from internal.food_finance_refunds r join public.food_orders o on o.id=r.order_id
    where o.store_id=p_store_id and r.state='succeeded'
      and (r.completed_at at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
    union all
    select (coalesce(o.refunded_at,o.updated_at) at time zone 'Asia/Bangkok')::date,o.total
    from public.food_orders o where o.store_id=p_store_id
      and (o.payment_status='refunded' or o.refund_status='refunded')
      and not exists(select 1 from internal.food_finance_refunds r where r.order_id=o.id and r.state='succeeded')
      and (coalesce(o.refunded_at,o.updated_at) at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  ads as (
    select c.click_day as day, c.cost
    from public.food_ad_clicks c
    where c.store_id = p_store_id and c.click_day between v_prev_from and p_to
  ),
  -- GP v1, booked like sales and refunds. Collected: the application fee of
  -- an order that was really paid through Stripe (payment_provider 'stripe'),
  -- on the day it was paid. Returned: only the fee WYNOS actually refunded
  -- (merchant-stripe-refund with refund_application_fee), on the day it was
  -- refunded. Neither reads the Stripe ledger status, which a late webhook
  -- from an older checkout attempt can rewrite, and a refund made outside
  -- WYNOS (e.g. the Stripe Dashboard) does not return the fee.
  gp as (
    select p.day,round(fsp.application_fee_satang/100.0,2) as amount
    from paid p join public.food_stripe_payments fsp on fsp.order_id=p.id
    where p.payment_provider='stripe' and fsp.application_fee_satang>0
    union all
    select (r.completed_at at time zone 'Asia/Bangkok')::date,-r.gp_satang/100.0
    from internal.food_finance_refunds r join public.food_orders o on o.id=r.order_id
    where o.store_id=p_store_id and r.state='succeeded'
      and (r.completed_at at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
    union all
    select (fsp.application_fee_refunded_at at time zone 'Asia/Bangkok')::date,-fsp.application_fee_refunded_satang/100.0
    from public.food_stripe_payments fsp join public.food_orders o on o.id=fsp.order_id
    where o.store_id=p_store_id and fsp.application_fee_refunded_satang>0
      and not exists(select 1 from internal.food_finance_refunds r where r.order_id=o.id and r.state='succeeded')
      and (fsp.application_fee_refunded_at at time zone 'Asia/Bangkok')::date between v_prev_from and p_to
  ),
  funded as (
    select p.day, foc.platform_funded as amount
    from paid p
    join public.food_order_campaigns foc on foc.order_id = p.id
    where foc.platform_funded > 0
      and foc.released_at is null
      and p.status = 'delivered'
      and p.payment_status <> 'refunded'
  ),
  days as (
    select d::date as day,
      (select count(*) from paid p where p.day = d::date) as orders,
      coalesce((select sum(p.subtotal) from paid p where p.day = d::date), 0) as food,
      coalesce((select sum(p.delivery_fee) from paid p where p.day = d::date), 0) as delivery,
      coalesce((select sum(p.subtotal + p.delivery_fee - p.total) from paid p where p.day = d::date), 0) as discounts,
      coalesce((select sum(p.total) from paid p where p.day = d::date), 0) as paid_total,
      (select count(*) from refunded r where r.day = d::date) as refund_count,
      coalesce((select sum(r.total) from refunded r where r.day = d::date), 0) as refunds,
      coalesce((select sum(a.cost) from ads a where a.day = d::date), 0) as ad_spend,
      coalesce((select sum(f.amount) from funded f where f.day = d::date), 0) as platform_funded,
      coalesce((select sum(g.amount) from gp g where g.day = d::date), 0) as gp
    from generate_series(v_prev_from, p_to, interval '1 day') as d
  ),
  shaped as (
    select day, orders, food, delivery, discounts, refund_count, refunds,
           paid_total - refunds as sales_net, ad_spend, platform_funded, gp,
           paid_total - refunds - ad_spend + platform_funded - gp as income
    from days
  ),
  cur as (select * from shaped where day between p_from and p_to),
  prev as (select * from shaped where day between v_prev_from and v_prev_to)
  select jsonb_build_object(
    'from', p_from,
    'to', p_to,
    'orders', (select coalesce(sum(orders), 0) from cur),
    'food', (select coalesce(sum(food), 0) from cur),
    'delivery', (select coalesce(sum(delivery), 0) from cur),
    'discounts', (select coalesce(sum(discounts), 0) from cur),
    'refund_count', (select coalesce(sum(refund_count), 0) from cur),
    'refunds', (select coalesce(sum(refunds), 0) from cur),
    'sales_net', (select coalesce(sum(sales_net), 0) from cur),
    'ad_spend', (select coalesce(sum(ad_spend), 0) from cur),
    'platform_funded', (select coalesce(sum(platform_funded), 0) from cur),
    'gp', (select coalesce(sum(gp), 0) from cur),
    'income', (select coalesce(sum(income), 0) from cur),
    'prev_sales_net', (select coalesce(sum(sales_net), 0) from prev),
    'prev_orders', (select coalesce(sum(orders), 0) from prev),
    'days', coalesce((select jsonb_agg(jsonb_build_object(
        'day', day, 'orders', orders, 'food', food, 'delivery', delivery, 'discounts', discounts,
        'refunds', refunds, 'sales_net', sales_net, 'ad_spend', ad_spend,
        'platform_funded', platform_funded, 'gp', gp, 'income', income) order by day) from cur), '[]'::jsonb),
    'pending_slip_count', (select count(*) from public.food_orders o
      where o.store_id = p_store_id and o.payment_status = 'submitted' and o.status <> 'cancelled'),
    'pending_slip_total', coalesce((select sum(o.total) from public.food_orders o
      where o.store_id = p_store_id and o.payment_status = 'submitted' and o.status <> 'cancelled'), 0),
    'platform_owed', coalesce((select sum(w.amount) from internal.food_platform_owed_rows(p_store_id) w), 0)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.merchant_finance_summary(uuid, date, date) from public, anon;
grant execute on function public.merchant_finance_summary(uuid, date, date) to authenticated;

-- ------------------------------------------------------------
