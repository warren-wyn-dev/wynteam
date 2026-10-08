-- WYNOS Finance QA JWT-claims spoof resistance checks.
-- ONLY project pcatuxtenluqzjzzwsvl; DB-role emulation, NOT signature validation.
-- No persistent records, Stripe calls, GP drafts or money movement.
BEGIN;
DO $$
declare
  v_store uuid;
  v_owner uuid;
  v_outsider uuid;
begin
  select s.id,mm.user_id into v_store,v_owner
  from public.food_stores s join public.merchant_memberships mm
    on mm.merchant_account_id=s.merchant_account_id
    and mm.active and mm.role='owner'
  join public.food_orders o on o.store_id=s.id and o.order_number='WF000005'
  limit 1;
  select id into v_outsider from auth.users where id <> v_owner limit 1;
  if v_store is null or v_owner is null or v_outsider is null then
    raise exception 'QA-only identity fixtures missing';
  end if;
  perform set_config('qa.finance.spoof.store_id',v_store::text,true);
  perform set_config('qa.finance.spoof.outsider_id',v_outsider::text,true);
  perform set_config('qa.finance.spoof.owner_id',v_owner::text,true);
end;$$;

-- Simulate an outsider presenting all kinds of self-claimed admin/owner fields.
-- PostgREST would validate an actual signed JWT BEFORE forwarding claims.
select set_config('request.jwt.claim.sub',current_setting('qa.finance.spoof.outsider_id'),true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub',current_setting('qa.finance.spoof.outsider_id'),
  'role','authenticated',
  'email','admin@not-real.example',
  'user_metadata',jsonb_build_object('is_admin',true,'merchant_role','owner','is_gp_admin',true),
  'app_metadata',jsonb_build_object('role','admin','is_gp_admin',true,'merchant_role','owner')
)::text,true);
set local role authenticated;
DO $$
declare v_store uuid := current_setting('qa.finance.spoof.store_id')::uuid;
begin
  if public.wynos_gp_qa_is_admin() then
    raise exception 'Nonallowlisted outsider gained QA GP admin via forged JWT fields';
  end if;
  if public.merchant_has_store_role(v_store,array['owner']::text[]) then
    raise exception 'Outsider gained merchant owner via forged JWT fields';
  end if;
  begin
    perform public.admin_food_finance_report_qa(now()-interval '1 day',now()+interval '1 day',null);
    raise exception 'Forged claims granted Admin Finance Reporting';
  exception when sqlstate '42501' then null; end;
  begin
    perform public.admin_food_finance_events_qa(now()-interval '1 day',now()+interval '1 day',null,50,0);
    raise exception 'Forged claims granted Admin Finance timeline';
  exception when sqlstate '42501' then null; end;
  begin
    perform public.merchant_food_finance_report_qa(v_store,now()-interval '1 day',now()+interval '1 day');
    raise exception 'Forged claims granted Merchant Finance Reporting';
  exception when sqlstate '42501' then null; end;
  begin
    perform public.merchant_food_finance_events_qa(v_store,now()-interval '1 day',now()+interval '1 day',50,0);
    raise exception 'Forged claims granted Merchant Finance timeline';
  exception when sqlstate '42501' then null; end;
  raise notice 'PASS: user-editable claims do not authorize finance access';
end;$$;
reset role;
rollback;