-- Admin-controlled featured restaurant placements for Food home.
-- Additive, default empty, no existing ranking altered. Public read is read-only.
create table if not exists public.food_featured_stores (
 store_id uuid primary key references public.food_stores(id) on delete cascade,
 priority integer not null default 10 check(priority between 1 and 100),
 active boolean not null default false,
 starts_at timestamptz not null default now(),
 ends_at timestamptz,
 version integer not null default 1 check(version>=1),
 updated_at timestamptz not null default now(),
 constraint featured_schedule check(ends_at is null or ends_at>starts_at)
);
create index if not exists food_featured_active_idx on public.food_featured_stores(active,priority);
alter table public.food_featured_stores enable row level security;
revoke all on public.food_featured_stores from public,anon,authenticated;

create table if not exists public.food_featured_store_edits (
 id uuid primary key default gen_random_uuid(),
 store_id uuid not null references public.food_stores(id),
 actor_id uuid not null references auth.users(id),
 reason text not null check(char_length(reason) between 5 and 300),
 before_state jsonb,
 after_state jsonb not null,
 created_at timestamptz not null default now()
);
create index if not exists food_featured_edits_store_idx on public.food_featured_store_edits(store_id,created_at desc);
alter table public.food_featured_store_edits enable row level security;
revoke all on public.food_featured_store_edits from public,anon,authenticated;

create or replace function public.food_active_featured_stores()
returns jsonb language sql stable security definer set search_path=''
as $$
 select coalesce(jsonb_agg(jsonb_build_object('store_id',x.store_id,'priority',x.priority) order by x.priority,x.store_id),'[]'::jsonb)
 from (
   select p.store_id,p.priority
   from public.food_featured_stores p
   join public.food_stores s on s.id=p.store_id
   where p.active and p.starts_at<=now() and (p.ends_at is null or p.ends_at>now())
     and s.is_published and s.admin_suspended_at is null
   order by p.priority,p.store_id limit 20
 ) x;
$$;
revoke all on function public.food_active_featured_stores() from public;
grant execute on function public.food_active_featured_stores() to anon,authenticated;

create or replace function public.admin_food_featured_stores()
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_result jsonb;
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('food','view') then raise exception 'Not authorized'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
   'store_id',p.store_id,'store_name',s.name,'priority',p.priority,'active',p.active,
   'starts_at',p.starts_at,'ends_at',p.ends_at,'version',p.version
 ) order by p.priority,s.name),'[]'::jsonb) into v_result
 from public.food_featured_stores p join public.food_stores s on s.id=p.store_id;
 return v_result;
end;
$$;
revoke all on function public.admin_food_featured_stores() from public,anon;
grant execute on function public.admin_food_featured_stores() to authenticated;

create or replace function public.admin_save_food_featured_store(
 p_store_id uuid,p_expected_version integer,p_priority integer,p_active boolean,
 p_starts_at timestamptz,p_ends_at timestamptz,p_reason text
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
 v_old jsonb;
 v_new jsonb;
 v_current public.food_featured_stores%rowtype;
 v_reason text:=btrim(coalesce(p_reason,''));
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('food','edit') then raise exception 'Not authorized'; end if;
 if p_store_id is null or not exists(select 1 from public.food_stores where id=p_store_id)
    then raise exception 'Store not found'; end if;
 if p_priority is null or p_priority not between 1 and 100 or p_active is null or p_starts_at is null
    or (p_ends_at is not null and p_ends_at<=p_starts_at) then raise exception 'Invalid featured placement'; end if;
 if char_length(v_reason) not between 5 and 300 then raise exception 'Reason must be 5-300 characters'; end if;
 -- Lock the referenced store row to serialize creation of the same placement.
 perform 1 from public.food_stores where id=p_store_id for update;
 select * into v_current from public.food_featured_stores where store_id=p_store_id for update;
 if found then
   if p_expected_version is distinct from v_current.version then raise exception 'Featured placement changed; reload'; end if;
   v_old:=to_jsonb(v_current);
   update public.food_featured_stores
     set priority=p_priority,active=p_active,starts_at=p_starts_at,ends_at=p_ends_at,
       version=version+1,updated_at=now()
     where store_id=p_store_id returning * into v_current;
 else
   if p_expected_version is not null then raise exception 'Featured placement changed; reload'; end if;
   v_old:=null;
   insert into public.food_featured_stores(store_id,priority,active,starts_at,ends_at)
     values(p_store_id,p_priority,p_active,p_starts_at,p_ends_at)
     returning * into v_current;
 end if;
 v_new:=to_jsonb(v_current);
 insert into public.food_featured_store_edits(store_id,actor_id,reason,before_state,after_state)
   values(p_store_id,(select auth.uid()),v_reason,v_old,v_new);
 return v_new;
end;
$$;
revoke all on function public.admin_save_food_featured_store(uuid,integer,integer,boolean,timestamptz,timestamptz,text) from public,anon;
grant execute on function public.admin_save_food_featured_store(uuid,integer,integer,boolean,timestamptz,timestamptz,text) to authenticated;
