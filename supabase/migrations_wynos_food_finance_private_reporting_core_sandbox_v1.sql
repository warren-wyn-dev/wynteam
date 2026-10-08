-- WYNOS Finance private reporting core hardening; QA pcatuxtenluqzjzzwsvl ONLY.
-- No Stripe, payment, checkout, GP rate, webhook, real refund or Production touch.
-- Move read-only privileged helpers out of PostgREST-exposed public schema.
-- Public API wrapper names and authorization semantics remain unchanged.
-- Keep migration atomic: PostgreSQL DDL in a single migration transaction.
create schema if not exists wynos_finance_qa_private;
revoke all on schema wynos_finance_qa_private from public,anon,authenticated;
grant usage on schema wynos_finance_qa_private to service_role;

alter function public.food_finance_report_core_qa(timestamptz,timestamptz,uuid)
  set schema wynos_finance_qa_private;
alter function public.food_finance_events_core_qa(timestamptz,timestamptz,uuid,integer,integer)
  set schema wynos_finance_qa_private;

-- The private helpers run with INVOKER rights. Existing privileged
-- wrappers run as owner only after checking auth.uid plus allowlist
-- or active merchant owner membership. They never accept a raw caller role.
alter function wynos_finance_qa_private.food_finance_report_core_qa(timestamptz,timestamptz,uuid)
  security invoker;
alter function wynos_finance_qa_private.food_finance_events_core_qa(timestamptz,timestamptz,uuid,integer,integer)
  security invoker;

revoke all on function
  wynos_finance_qa_private.food_finance_report_core_qa(timestamptz,timestamptz,uuid),
  wynos_finance_qa_private.food_finance_events_core_qa(timestamptz,timestamptz,uuid,integer,integer)
  from public,anon,authenticated;
grant execute on function
  wynos_finance_qa_private.food_finance_report_core_qa(timestamptz,timestamptz,uuid),
  wynos_finance_qa_private.food_finance_events_core_qa(timestamptz,timestamptz,uuid,integer,integer)
  to service_role;

create or replace function public.admin_food_finance_report_qa(
  p_from timestamptz, p_to timestamptz, p_store_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'WYNOS QA finance admin required' using errcode='42501';
  end if;
  return wynos_finance_qa_private.food_finance_report_core_qa(p_from,p_to,p_store_id);
end;
$$;

create or replace function public.admin_food_finance_events_qa(
  p_from timestamptz, p_to timestamptz, p_store_id uuid default null,
  p_limit integer default 50, p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not public.wynos_gp_qa_is_admin() then
    raise exception 'WYNOS QA finance admin required' using errcode='42501';
  end if;
  return wynos_finance_qa_private.food_finance_events_core_qa(p_from,p_to,p_store_id,p_limit,p_offset);
end;
$$;

create or replace function public.merchant_food_finance_report_qa(
  p_store_id uuid, p_from timestamptz, p_to timestamptz
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if p_store_id is null or (select auth.uid()) is null
     or not public.merchant_has_store_role(p_store_id,array['owner']::text[]) then
    raise exception 'Merchant store owner required' using errcode='42501';
  end if;
  return wynos_finance_qa_private.food_finance_report_core_qa(p_from,p_to,p_store_id);
end;
$$;

create or replace function public.merchant_food_finance_events_qa(
  p_store_id uuid, p_from timestamptz, p_to timestamptz,
  p_limit integer default 50, p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if p_store_id is null or (select auth.uid()) is null
     or not public.merchant_has_store_role(p_store_id,array['owner']::text[]) then
    raise exception 'Merchant store owner required' using errcode='42501';
  end if;
  return wynos_finance_qa_private.food_finance_events_core_qa(p_from,p_to,p_store_id,p_limit,p_offset);
end;
$$;

-- Explicitly preserve intended public wrapper RPC privileges.
revoke all on function
  public.admin_food_finance_report_qa(timestamptz,timestamptz,uuid),
  public.admin_food_finance_events_qa(timestamptz,timestamptz,uuid,integer,integer),
  public.merchant_food_finance_report_qa(uuid,timestamptz,timestamptz),
  public.merchant_food_finance_events_qa(uuid,timestamptz,timestamptz,integer,integer)
  from public,anon;
grant execute on function
  public.admin_food_finance_report_qa(timestamptz,timestamptz,uuid),
  public.admin_food_finance_events_qa(timestamptz,timestamptz,uuid,integer,integer),
  public.merchant_food_finance_report_qa(uuid,timestamptz,timestamptz),
  public.merchant_food_finance_events_qa(uuid,timestamptz,timestamptz,integer,integer)
  to authenticated,service_role;
