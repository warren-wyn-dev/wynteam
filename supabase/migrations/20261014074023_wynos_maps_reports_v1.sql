-- Issue #1151: human-reviewed reports for existing public WYNOS places.
-- No coordinates, uploads, reporter contact fields or automatic place changes.
create table if not exists public.wynos_map_reports (
 id uuid primary key default gen_random_uuid(),
 place_id text references public.wynos_places(id) on delete set null,
 place_name text not null check(char_length(place_name) between 1 and 160),
 reporter_id uuid references public.profiles(id) on delete set null,
 kind text not null check(kind in ('wrong_info','closed','duplicate','unsafe','other')),
 note text not null check(char_length(note) between 10 and 500),
 status text not null default 'open' check(status in ('open','reviewing','resolved','dismissed')),
 version integer not null default 1 check(version>0),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp()
);
create unique index if not exists wynos_map_reports_one_active
 on public.wynos_map_reports(reporter_id,place_id) where status in ('open','reviewing');
create index if not exists wynos_map_reports_owner_created
 on public.wynos_map_reports(reporter_id,created_at desc,id desc);
create index if not exists wynos_map_reports_queue_created
 on public.wynos_map_reports(status,created_at,id);
create index if not exists wynos_map_reports_place on public.wynos_map_reports(place_id);
create table if not exists public.wynos_map_report_events (
 id uuid primary key default gen_random_uuid(),
 report_id uuid not null references public.wynos_map_reports(id) on delete restrict,
 actor_id uuid references public.profiles(id) on delete set null,
 before_status text,
 after_status text not null check(after_status in ('open','reviewing','resolved','dismissed')),
 version integer not null check(version>0),
 reason text not null check(char_length(reason) between 5 and 300),
 created_at timestamptz not null default clock_timestamp(),
 unique(report_id,version)
);
create index if not exists wynos_map_report_events_actor on public.wynos_map_report_events(actor_id);
alter table public.wynos_map_reports enable row level security;
alter table public.wynos_map_report_events enable row level security;
revoke all on public.wynos_map_reports,public.wynos_map_report_events from public,anon,authenticated;

-- Mask common contact data before persistence. Render all returned text as text.
create or replace function internal.wynos_map_report_safe_text(p_text text)
returns text language sql immutable set search_path='' as $$
 select btrim(regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(coalesce(p_text,''),
 '[[:cntrl:]]',' ','g'),'<[^>]*>','[ข้อความถูกปิดบัง]','g'),
 '(https?://|www\.)[^[:space:]]+','[ลิงก์ถูกปิดบัง]','gi'),
 '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}','[อีเมลถูกปิดบัง]','g'),
 '\+?[0-9๐-๙][0-9๐-๙ ()-]{7,}[0-9๐-๙]','[หมายเลขถูกปิดบัง]','g'))
$$;
revoke all on function internal.wynos_map_report_safe_text(text) from public,anon,authenticated;

create or replace function public.wynos_my_map_reports(p_limit integer default 50)
returns table(id uuid,place_id text,place_name text,kind text,status text,created_at timestamptz,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not coalesce(public.is_developer_account(),false) then raise exception 'Not authorized'; end if;
 return query select r.id,r.place_id,r.place_name,r.kind,r.status,r.created_at,r.updated_at
 from public.wynos_map_reports r where r.reporter_id=(select auth.uid())
 order by r.created_at desc,r.id desc limit greatest(1,least(coalesce(p_limit,50),100));
end $$;

create or replace function public.submit_wynos_map_report(p_place_id text,p_kind text,p_note text)
returns uuid language plpgsql volatile security definer set search_path='' as $$
declare
 v_actor uuid:=(select auth.uid());v_place public.wynos_places%rowtype;v_id uuid;
 v_note text:=internal.wynos_map_report_safe_text(p_note);
begin
 if v_actor is null or not coalesce(public.is_developer_account(),false) then raise exception 'Not authorized'; end if;
 if p_kind is null or p_kind not in ('wrong_info','closed','duplicate','unsafe','other')
 or char_length(coalesce(p_note,'')) not between 10 and 500 or char_length(v_note) not between 10 and 500
 or p_place_id is null or p_place_id !~ '^wynos_place_[0-9a-f]{32}$'
 then raise exception 'Invalid report input'; end if;
 -- Inactive merchant previews, raw OSM ids and saved/private snapshots are excluded.
 select * into v_place from public.wynos_places p where p.id=p_place_id and p.is_active for share;
 if not found then raise exception 'Public place not available'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('maps-report:'||v_actor::text,0));
 if exists(select 1 from public.wynos_map_reports r where r.reporter_id=v_actor
 and r.place_id=p_place_id and r.status in ('open','reviewing')) then raise exception 'Active report already exists'; end if;
 if (select count(*) from public.wynos_map_reports r where r.reporter_id=v_actor
 and r.created_at>now()-interval '24 hours')>=5 then raise exception 'Report rate limit'; end if;
 insert into public.wynos_map_reports(place_id,place_name,reporter_id,kind,note)
 values(v_place.id,v_place.name_th,v_actor,p_kind,v_note) returning id into v_id;
 insert into public.wynos_map_report_events(report_id,actor_id,after_status,version,reason)
 values(v_id,v_actor,'open',1,'Report submitted');
 return v_id;
end $$;

-- Explicit projection: never return reporter/actor ids, profile data or coordinates.
create or replace function public.admin_wynos_map_reports(p_status text default 'open',p_limit integer default 100)
returns table(id uuid,place_id text,place_name text,kind text,note text,status text,version integer,created_at timestamptz,updated_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('maps','view') then raise exception 'Not authorized'; end if;
 if p_status is not null and p_status not in ('open','reviewing','resolved','dismissed') then raise exception 'Invalid report status'; end if;
 return query select r.id,r.place_id,r.place_name,r.kind,internal.wynos_map_report_safe_text(r.note),r.status,r.version,r.created_at,r.updated_at
 from public.wynos_map_reports r where p_status is null or r.status=p_status
 order by r.created_at,r.id limit greatest(1,least(coalesce(p_limit,100),200));
end $$;

create or replace function public.admin_wynos_map_report_history(p_report_id uuid)
returns table(before_status text,after_status text,version integer,reason text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('maps','view') then raise exception 'Not authorized'; end if;
 return query select e.before_status,e.after_status,e.version,internal.wynos_map_report_safe_text(e.reason),e.created_at
 from public.wynos_map_report_events e where e.report_id=p_report_id order by e.version;
end $$;

-- Preserve the existing audit allowlist; add just this event, using the WYN-219 pattern.
do $$
declare v_name text;v_def text;v_values text[];
begin
 select c.conname,pg_get_constraintdef(c.oid) into v_name,v_def from pg_constraint c
 where c.conrelid='public.audit_log'::regclass and c.contype='c'
 and pg_get_constraintdef(c.oid) like '%event_type%' limit 1;
 if v_def is null then raise exception 'audit_log event_type check constraint not found'; end if;
 select array_agg(distinct x.m[1] order by x.m[1]) into v_values
 from regexp_matches(v_def,'''([a-z0-9_]+)''','g') as x(m);
 if v_values is null then
  select array_agg(distinct btrim(v) order by btrim(v)) into v_values
  from regexp_matches(v_def,'''\{([^}]*)\}''') as x(m),unnest(string_to_array(x.m[1],',')) as v;
 end if;
 if v_values is null or cardinality(v_values)<2 or exists(select 1 from unnest(v_values) as v where v !~ '^[a-z0-9_]+$')
 then raise exception 'Could not read audit event types'; end if;
 if 'admin_wynos_map_report_updated'=any(v_values) then return; end if;
 v_values:=array_append(v_values,'admin_wynos_map_report_updated');
 execute format('alter table public.audit_log drop constraint %I',v_name);
 execute format('alter table public.audit_log add constraint audit_log_event_type_check check(event_type in (%s))',
 (select string_agg(quote_literal(v),', ') from unnest(v_values) as v));
end $$;

create or replace function public.admin_update_wynos_map_report(p_report_id uuid,p_expected_version integer,p_status text,p_reason text)
returns integer language plpgsql volatile security definer set search_path='' as $$
declare v_actor uuid:=(select auth.uid());v_report public.wynos_map_reports%rowtype;
 v_reason text:=internal.wynos_map_report_safe_text(p_reason);
begin
 if v_actor is null or not internal.has_admin_permission('maps','edit') then raise exception 'Not authorized'; end if;
 if char_length(coalesce(p_reason,'')) not between 5 and 300 or char_length(v_reason) not between 5 and 300
 then raise exception 'Review reason required'; end if;
 select * into v_report from public.wynos_map_reports where id=p_report_id for update;
 if not found then raise exception 'Report not available'; end if;
 if p_expected_version is distinct from v_report.version then raise exception 'Report changed; reload'; end if;
 if p_status is null or not ((v_report.status='open' and p_status='reviewing')
 or (v_report.status='reviewing' and p_status in ('resolved','dismissed')))
 then raise exception 'Invalid report transition'; end if;
 update public.wynos_map_reports set status=p_status,version=version+1,updated_at=clock_timestamp() where id=p_report_id;
 insert into public.wynos_map_report_events(report_id,actor_id,before_status,after_status,version,reason)
 values(p_report_id,v_actor,v_report.status,p_status,v_report.version+1,v_reason);
 perform internal.log_audit_event(v_actor,'admin_wynos_map_report_updated',p_report_id,
 jsonb_build_object('report_id',p_report_id,'place_id',v_report.place_id,'before_status',v_report.status,
 'after_status',p_status,'version',v_report.version+1));
 return v_report.version+1;
end $$;

revoke all on function public.wynos_my_map_reports(integer),public.submit_wynos_map_report(text,text,text),
 public.admin_wynos_map_reports(text,integer),public.admin_wynos_map_report_history(uuid),
 public.admin_update_wynos_map_report(uuid,integer,text,text) from public,anon;
grant execute on function public.wynos_my_map_reports(integer),public.submit_wynos_map_report(text,text,text),
 public.admin_wynos_map_reports(text,integer),public.admin_wynos_map_report_history(uuid),
 public.admin_update_wynos_map_report(uuid,integer,text,text) to authenticated;
