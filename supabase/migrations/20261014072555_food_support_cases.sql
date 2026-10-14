-- Issue #1145: order-linked support. No order, review, payment or account mutations.
-- Text and evidence are minimized: only order-item references, no uploaded media/PII.
-- New customer APIs remain developer-only until an explicit public rollout.
create table if not exists public.food_support_cases (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.food_orders(id) on delete restrict,
 store_id uuid not null references public.food_stores(id) on delete restrict,
 buyer_id uuid references public.profiles(id) on delete set null,
 kind text not null check(kind in ('order','payment','review','safety','other')),
 subject text not null check(char_length(subject) between 5 and 120),
 status text not null default 'open' check(status in ('open','in_progress','waiting_customer','resolved','appealed')),
 evidence_order_item_id uuid references public.food_order_items(id) on delete set null,
 compensation_requested boolean not null default false,
 assigned_to uuid references public.profiles(id) on delete set null,
 appeal_count integer not null default 0 check(appeal_count between 0 and 1),
 version integer not null default 1 check(version>0),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp()
);
create unique index if not exists food_support_one_active_order_kind on public.food_support_cases(order_id,kind)
 where status<>'resolved';
create index if not exists food_support_buyer_created on public.food_support_cases(buyer_id,created_at desc,id desc);
create index if not exists food_support_queue_created on public.food_support_cases(status,created_at desc,id desc);
create table if not exists public.food_support_messages (
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references public.food_support_cases(id) on delete restrict,
 actor_id uuid references public.profiles(id) on delete set null,
 actor_role text not null check(actor_role in ('customer','support')),
 body text not null check(char_length(body) between 5 and 2000),
 created_at timestamptz not null default clock_timestamp()
);
create index if not exists food_support_message_case on public.food_support_messages(case_id,created_at,id);
create index if not exists food_support_message_actor on public.food_support_messages(actor_id,created_at desc);
create table if not exists public.food_support_events (
 id uuid primary key default gen_random_uuid(),
 case_id uuid not null references public.food_support_cases(id) on delete restrict,
 actor_id uuid references public.profiles(id) on delete set null,
 action text not null check(action in ('created','customer_reply','appealed','agent_update')),
 before_status text,
 after_status text not null,
 reason text not null check(char_length(reason) between 5 and 300),
 created_at timestamptz not null default clock_timestamp()
);
create index if not exists food_support_event_case on public.food_support_events(case_id,created_at,id);
create index if not exists food_support_event_actor on public.food_support_events(actor_id,created_at desc);
alter table public.food_support_cases enable row level security;
alter table public.food_support_messages enable row level security;
alter table public.food_support_events enable row level security;
revoke all on public.food_support_cases,public.food_support_messages,public.food_support_events from public,anon,authenticated;

-- Minimize common contact details before persisting text; clients render plain text.
create or replace function internal.food_support_safe_text(p_text text)
returns text language sql immutable set search_path='' as $$
 select btrim(regexp_replace(regexp_replace(regexp_replace(coalesce(p_text,''),
 '[[:cntrl:]]',' ','g'),'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}','[อีเมลถูกปิดบัง]','g'),
 '\+?[0-9][0-9 ()-]{7,}[0-9]','[หมายเลขถูกปิดบัง]','g'))
$$;
revoke all on function internal.food_support_safe_text(text) from public,anon,authenticated;

-- Called only by authenticated, authorized public RPCs below. Never exposed directly.
create or replace function internal.food_support_case_json(p_id uuid,p_detail boolean default false)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object(
 'id',c.id,'order_id',c.order_id,'order_number',o.order_number,'store_id',c.store_id,
 'store_name',s.name,'kind',c.kind,'subject',c.subject,'status',c.status,
 'evidence_item_name',i.item_name,'compensation_requested',c.compensation_requested,
 'assigned',c.assigned_to is not null,'assigned_to_me',c.assigned_to=(select auth.uid()),
 'appeal_count',c.appeal_count,'version',c.version,'created_at',c.created_at,'updated_at',c.updated_at
 ) || case when p_detail then jsonb_build_object(
 'messages',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'actor_role',m.actor_role,
 'body',m.body,'created_at',m.created_at) order by m.created_at,m.id)
 from public.food_support_messages m where m.case_id=c.id),'[]'::jsonb),
 'history',coalesce((select jsonb_agg(jsonb_build_object('action',e.action,'before_status',e.before_status,
 'after_status',e.after_status,'created_at',e.created_at) order by e.created_at,e.id)
 from public.food_support_events e where e.case_id=c.id),'[]'::jsonb)
 ) else '{}'::jsonb end
 from public.food_support_cases c join public.food_orders o on o.id=c.order_id
 join public.food_stores s on s.id=c.store_id
 left join public.food_order_items i on i.id=c.evidence_order_item_id where c.id=p_id
$$;
revoke all on function internal.food_support_case_json(uuid,boolean) from public,anon,authenticated;

create or replace function public.food_support_cases(p_order_id uuid default null,p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if (select auth.uid()) is null or not coalesce(public.is_developer_account(),false) then raise exception 'Not authorized'; end if;
 select coalesce(jsonb_agg(internal.food_support_case_json(c.id,false) order by c.created_at desc,c.id desc),'[]'::jsonb)
 into v_result from (select id,created_at from public.food_support_cases
 where buyer_id=(select auth.uid()) and (p_order_id is null or order_id=p_order_id)
 order by created_at desc,id desc limit greatest(1,least(coalesce(p_limit,50),100))) c;
 return v_result;
end $$;
create or replace function public.food_support_case_detail(p_case_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not coalesce(public.is_developer_account(),false) or not exists(select 1 from public.food_support_cases c
 where c.id=p_case_id and c.buyer_id=(select auth.uid())) then raise exception 'Not authorized'; end if;
 return internal.food_support_case_json(p_case_id,true);
end $$;

create or replace function public.food_create_support_case(
 p_order_id uuid,p_kind text,p_subject text,p_body text,
 p_evidence_order_item_id uuid default null,p_compensation_requested boolean default false
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare
 v_actor uuid:=(select auth.uid());v_order public.food_orders%rowtype;v_id uuid;
 v_subject text:=internal.food_support_safe_text(p_subject);v_body text:=internal.food_support_safe_text(p_body);
begin
 if v_actor is null or not coalesce(public.is_developer_account(),false) then raise exception 'Not authorized'; end if;
 if p_kind is null or p_kind not in ('order','payment','review','safety','other')
 or char_length(v_subject) not between 5 and 120 or char_length(v_body) not between 5 and 2000
 or char_length(coalesce(p_subject,''))>120 or char_length(coalesce(p_body,''))>2000
 then raise exception 'Invalid support input'; end if;
 select * into v_order from public.food_orders where id=p_order_id and buyer_id=v_actor;
 if not found then raise exception 'Order not available'; end if;
 if p_evidence_order_item_id is not null and not exists(select 1 from public.food_order_items i
 where i.id=p_evidence_order_item_id and i.order_id=v_order.id) then raise exception 'Evidence not available'; end if;
 -- Serialize anti-spam checks per authenticated actor, including concurrent requests.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('food-support:'||v_actor::text,0));
 if (select count(*) from public.food_support_cases where buyer_id=v_actor and created_at>now()-interval '10 minutes')>=3
 or (select count(*) from public.food_support_cases where buyer_id=v_actor and created_at>now()-interval '1 day')>=10
 then raise exception 'Support rate limit'; end if;
 if exists(select 1 from public.food_support_cases where order_id=v_order.id and kind=p_kind and status<>'resolved')
 then raise exception 'Active case already exists'; end if;
 insert into public.food_support_cases(order_id,store_id,buyer_id,kind,subject,evidence_order_item_id,compensation_requested)
 values(v_order.id,v_order.store_id,v_actor,p_kind,v_subject,p_evidence_order_item_id,coalesce(p_compensation_requested,false)) returning id into v_id;
 insert into public.food_support_messages(case_id,actor_id,actor_role,body) values(v_id,v_actor,'customer',v_body);
 insert into public.food_support_events(case_id,actor_id,action,after_status,reason)
 values(v_id,v_actor,'created','open','Customer opened case');
 return internal.food_support_case_json(v_id,true);
end $$;

create or replace function public.food_reply_support_case(
 p_case_id uuid,p_expected_version integer,p_body text,p_appeal boolean default false
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid:=(select auth.uid());v_case public.food_support_cases%rowtype;
 v_body text:=internal.food_support_safe_text(p_body);v_status text;
begin
 if v_actor is null or not coalesce(public.is_developer_account(),false) then raise exception 'Not authorized'; end if;
 if char_length(v_body) not between 5 and 2000 or char_length(coalesce(p_body,''))>2000
 then raise exception 'Invalid support input'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('food-support:'||v_actor::text,0));
 select * into v_case from public.food_support_cases where id=p_case_id and buyer_id=v_actor for update;
 if not found then raise exception 'Not authorized'; end if;
 if p_expected_version is distinct from v_case.version then raise exception 'Case changed; reload'; end if;
 if (select count(*) from public.food_support_messages where actor_id=v_actor and created_at>now()-interval '10 minutes')>=20
 then raise exception 'Support rate limit'; end if;
 if coalesce(p_appeal,false) then
  if v_case.status<>'resolved' or v_case.appeal_count>=1 then raise exception 'Appeal not available'; end if;
  if exists(select 1 from public.food_support_cases where id<>v_case.id and order_id=v_case.order_id
   and kind=v_case.kind and status<>'resolved') then raise exception 'Active case already exists'; end if;
  v_status:='appealed';
 else
  if v_case.status='resolved' then raise exception 'Resolved case requires appeal'; end if;
  v_status:=case when v_case.status='waiting_customer' then 'in_progress' else v_case.status end;
 end if;
 insert into public.food_support_messages(case_id,actor_id,actor_role,body) values(v_case.id,v_actor,'customer',v_body);
 update public.food_support_cases set status=v_status,appeal_count=appeal_count+case when coalesce(p_appeal,false) then 1 else 0 end,
 version=version+1,updated_at=clock_timestamp() where id=v_case.id;
 insert into public.food_support_events(case_id,actor_id,action,before_status,after_status,reason)
 values(v_case.id,v_actor,case when coalesce(p_appeal,false) then 'appealed' else 'customer_reply' end,
 v_case.status,v_status,'Customer supplied information');
 return internal.food_support_case_json(v_case.id,true);
end $$;

create or replace function public.admin_food_support_cases(p_status text default null,p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('food','view') then raise exception 'Not authorized'; end if;
 if p_status is not null and p_status not in ('open','in_progress','waiting_customer','resolved','appealed')
 then raise exception 'Invalid support status'; end if;
 select coalesce(jsonb_agg(internal.food_support_case_json(c.id,false) order by c.created_at desc,c.id desc),'[]'::jsonb)
 into v_result from (select id,created_at from public.food_support_cases where p_status is null or status=p_status
 order by created_at desc,id desc limit greatest(1,least(coalesce(p_limit,100),200))) c;
 return v_result;
end $$;
create or replace function public.admin_food_support_case_detail(p_case_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('food','view') then raise exception 'Not authorized'; end if;
 if not exists(select 1 from public.food_support_cases where id=p_case_id) then raise exception 'Case not available'; end if;
 return internal.food_support_case_json(p_case_id,true);
end $$;

create or replace function public.admin_update_food_support_case(
 p_case_id uuid,p_expected_version integer,p_status text,p_reply text,p_reason text,p_assign_to_me boolean default false
) returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid:=(select auth.uid());v_case public.food_support_cases%rowtype;
 v_reply text:=internal.food_support_safe_text(p_reply);v_reason text:=internal.food_support_safe_text(p_reason);
begin
 if v_actor is null or not internal.has_admin_permission('food','edit') then raise exception 'Not authorized'; end if;
 if p_status is null or p_status not in ('in_progress','waiting_customer','resolved')
 or char_length(v_reason) not between 5 and 300 or char_length(coalesce(p_reason,''))>300
 or (v_reply<>'' and char_length(v_reply) not between 5 and 2000) or char_length(coalesce(p_reply,''))>2000
 then raise exception 'Invalid support input'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('food-support:'||v_actor::text,0));
 select * into v_case from public.food_support_cases where id=p_case_id for update;
 if not found then raise exception 'Case not available'; end if;
 if p_expected_version is distinct from v_case.version then raise exception 'Case changed; reload'; end if;
 if v_case.assigned_to is not null and v_case.assigned_to<>v_actor then raise exception 'Case assigned to another agent'; end if;
 if v_case.assigned_to is null and not coalesce(p_assign_to_me,false) then raise exception 'Claim case before updating'; end if;
 if v_case.status='resolved' then raise exception 'Resolved case requires customer appeal'; end if;
 if p_status in ('waiting_customer','resolved') and v_reply='' then raise exception 'Customer response required'; end if;
 if v_case.status='appealed' and v_reply='' then raise exception 'Appeal response required'; end if;
 if (select count(*) from public.food_support_events where actor_id=v_actor and created_at>now()-interval '10 minutes')>=60
 then raise exception 'Support rate limit'; end if;
 if v_reply<>'' then
  insert into public.food_support_messages(case_id,actor_id,actor_role,body) values(v_case.id,v_actor,'support',v_reply);
 end if;
 update public.food_support_cases set status=p_status,assigned_to=v_actor,version=version+1,updated_at=clock_timestamp() where id=v_case.id;
 insert into public.food_support_events(case_id,actor_id,action,before_status,after_status,reason)
 values(v_case.id,v_actor,'agent_update',v_case.status,p_status,v_reason);
 return internal.food_support_case_json(v_case.id,true);
end $$;

revoke all on function public.food_support_cases(uuid,integer),public.food_support_case_detail(uuid),
 public.food_create_support_case(uuid,text,text,text,uuid,boolean),public.food_reply_support_case(uuid,integer,text,boolean),
 public.admin_food_support_cases(text,integer),public.admin_food_support_case_detail(uuid),
 public.admin_update_food_support_case(uuid,integer,text,text,text,boolean) from public,anon;
grant execute on function public.food_support_cases(uuid,integer),public.food_support_case_detail(uuid),
 public.food_create_support_case(uuid,text,text,text,uuid,boolean),public.food_reply_support_case(uuid,integer,text,boolean),
 public.admin_food_support_cases(text,integer),public.admin_food_support_case_detail(uuid),
 public.admin_update_food_support_case(uuid,integer,text,text,text,boolean) to authenticated;
