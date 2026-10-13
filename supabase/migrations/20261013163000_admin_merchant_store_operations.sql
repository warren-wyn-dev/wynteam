-- Admin controls the same restaurant open/temporary-close/prep-time fields used by Food checkout.
-- Migration creates permission-limited RPCs only; does not change any live store.
-- Must be used with a confirmed merchant:edit role and a reason. Existing orders are unchanged.

create or replace function public.admin_merchant_store_operations()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_result jsonb;
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('merchant','view')
 then raise exception 'Not authorized'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',s.id,'name',s.name,'is_open',s.is_open,
  'temporary_closed_until',s.temporary_closed_until,
  'temporary_closed_reason',s.temporary_closed_reason,
  'prep_time_min_minutes',s.prep_time_min_minutes,
  'prep_time_max_minutes',s.prep_time_max_minutes,
  'published',s.is_published,
  'admin_suspended',s.admin_suspended_at is not null
 ) order by s.name,s.id),'[]'::jsonb) into v_result
 from public.food_stores s;
 return v_result;
end;
$$;
revoke all on function public.admin_merchant_store_operations() from public,anon;
grant execute on function public.admin_merchant_store_operations() to authenticated;

create or replace function public.admin_update_merchant_store_operations(
 p_store_id uuid,
 p_expected jsonb,
 p_is_open boolean,
 p_temporary_closed_until timestamptz,
 p_temporary_closed_reason text,
 p_prep_time_min_minutes integer,
 p_prep_time_max_minutes integer,
 p_reason text
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
 v_store public.food_stores%rowtype;
 v_before jsonb;
 v_after jsonb;
 v_reason text:=btrim(coalesce(p_reason,''));
 v_temp_reason text:=nullif(btrim(coalesce(p_temporary_closed_reason,'')),'');
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('merchant','edit')
 then raise exception 'Not authorized'; end if;
 if p_store_id is null or p_expected is null or jsonb_typeof(p_expected)<>'object'
  or not (p_expected ?& array['is_open','temporary_closed_until','temporary_closed_reason','prep_time_min_minutes','prep_time_max_minutes'])
 then raise exception 'Missing store or original values'; end if;
 if p_is_open is null or p_prep_time_min_minutes is null or p_prep_time_max_minutes is null
   or p_prep_time_min_minutes not between 1 and 240
   or p_prep_time_max_minutes not between p_prep_time_min_minutes and 240
 then raise exception 'Invalid preparation time'; end if;
 if p_temporary_closed_until is not null and
    (p_temporary_closed_until <= now() or p_temporary_closed_until > now()+interval '30 days'
     or char_length(coalesce(v_temp_reason,'')) not between 5 and 200)
 then raise exception 'Temporary closure requires a future date within 30 days and a reason'; end if;
 if p_temporary_closed_until is null and v_temp_reason is not null
 then raise exception 'Clear temporary closure reason when reopening'; end if;
 if char_length(v_reason) not between 5 and 300
 then raise exception 'Admin change reason must be 5-300 characters'; end if;
 select * into v_store from public.food_stores where id=p_store_id for update;
 if not found then raise exception 'Store not found'; end if;
 v_before:=jsonb_build_object(
  'is_open',v_store.is_open,
  'temporary_closed_until',v_store.temporary_closed_until,
  'temporary_closed_reason',v_store.temporary_closed_reason,
  'prep_time_min_minutes',v_store.prep_time_min_minutes,
  'prep_time_max_minutes',v_store.prep_time_max_minutes
 );
 if p_expected is distinct from v_before
 then raise exception 'Store availability changed; reload before saving'; end if;
 v_after:=jsonb_build_object(
  'is_open',p_is_open,
  'temporary_closed_until',p_temporary_closed_until,
  'temporary_closed_reason',v_temp_reason,
  'prep_time_min_minutes',p_prep_time_min_minutes,
  'prep_time_max_minutes',p_prep_time_max_minutes
 );
 if v_before=v_after then raise exception 'No changes to save'; end if;
 update public.food_stores
 set is_open=p_is_open,
     temporary_closed_until=p_temporary_closed_until,
     temporary_closed_reason=v_temp_reason,
     prep_time_min_minutes=p_prep_time_min_minutes,
     prep_time_max_minutes=p_prep_time_max_minutes
 where id=p_store_id;
 perform internal.log_audit_event(
  (select auth.uid()),'merchant_store_updated',null,
  jsonb_build_object('admin_availability_override',true,'store_id',v_store.id,
   'store_name',v_store.name,'reason',v_reason,'before',v_before,'after',v_after)
 );
 return v_after;
end;
$$;
revoke all on function public.admin_update_merchant_store_operations(uuid,jsonb,boolean,timestamptz,text,integer,integer,text) from public,anon;
grant execute on function public.admin_update_merchant_store_operations(uuid,jsonb,boolean,timestamptz,text,integer,integer,text) to authenticated;
