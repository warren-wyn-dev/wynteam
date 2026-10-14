-- Disable the new API only. Preserve cases, conversations, evidence references and audit.
-- No production rollback is authorized by this file; Owner approval is required.
begin;
revoke all on function public.food_support_cases(uuid,integer),public.food_support_case_detail(uuid),
 public.food_create_support_case(uuid,text,text,text,uuid,boolean),public.food_reply_support_case(uuid,integer,text,boolean),
 public.admin_food_support_cases(text,integer),public.admin_food_support_case_detail(uuid),
 public.admin_update_food_support_case(uuid,integer,text,text,text,boolean) from public,anon,authenticated;
revoke all on public.food_support_cases,public.food_support_messages,public.food_support_events from public,anon,authenticated;
commit;
