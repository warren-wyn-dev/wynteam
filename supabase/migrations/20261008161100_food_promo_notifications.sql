-- WYNOS Food marketing inbox + opt-in push. Never modify order/system notifications.
create table if not exists public.food_marketing_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  in_app_marketing boolean not null default true,
  push_marketing boolean not null default false,
  updated_at timestamptz not null default now()
);
create table if not exists public.food_promo_broadcasts (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid references public.food_coupon_codes(id) on delete set null,
  title text not null,
  body text not null,
  audience text not null default 'all',
  scheduled_at timestamptz not null default now(),
  state text not null default 'queued',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint food_promo_broadcast_title_len check (char_length(btrim(title)) between 3 and 90),
  constraint food_promo_broadcast_body_len check (char_length(btrim(body)) between 5 and 260),
  constraint food_promo_broadcast_audience check (audience in ('all','returning')),
  constraint food_promo_broadcast_state check (state in ('queued','sent','cancelled'))
);
create table if not exists public.food_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  broadcast_id uuid not null references public.food_promo_broadcasts(id) on delete cascade,
  title text not null,
  body text not null,
  coupon_code text,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint food_notifications_unique_delivery unique (recipient_id,broadcast_id)
);
create index if not exists food_notifications_recipient_idx
 on public.food_notifications(recipient_id,created_at desc);

create table if not exists public.food_promo_deliveries (
  id uuid primary key default gen_random_uuid(),
  broadcast_id uuid not null references public.food_promo_broadcasts(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  state text not null default 'queued',
  attempts integer not null default 0,
  lease_until timestamptz,
  last_error text,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  constraint food_promo_deliveries_unique unique (broadcast_id,recipient_id),
  constraint food_promo_deliveries_state check (state in ('queued','sending','sent','failed','no_token'))
);
create index if not exists food_promo_deliveries_queue_idx on public.food_promo_deliveries(state,lease_until,created_at);

alter table public.food_marketing_preferences enable row level security;
alter table public.food_notifications enable row level security;
alter table public.food_promo_broadcasts enable row level security;
alter table public.food_promo_deliveries enable row level security;
revoke all on public.food_marketing_preferences, public.food_notifications,
 public.food_promo_broadcasts, public.food_promo_deliveries from public,anon,authenticated;

grant select,insert,update on public.food_marketing_preferences to authenticated;
create policy "Food users read own marketing choice"
 on public.food_marketing_preferences for select to authenticated
 using (user_id=auth.uid());
create policy "Food users create own marketing choice"
 on public.food_marketing_preferences for insert to authenticated
 with check (user_id=auth.uid());
create policy "Food users update own marketing choice"
 on public.food_marketing_preferences for update to authenticated
 using (user_id=auth.uid()) with check (user_id=auth.uid());

grant select on public.food_notifications to authenticated;
grant update(read_at) on public.food_notifications to authenticated;
create policy "Food customers read own inbox"
 on public.food_notifications for select to authenticated
 using (recipient_id=auth.uid());
create policy "Food customers mark own inbox read"
 on public.food_notifications for update to authenticated
 using (recipient_id=auth.uid()) with check (recipient_id=auth.uid());

create or replace function public.admin_food_promo_schedule(
  p_title text,p_body text,p_coupon_id uuid default null,
  p_audience text default 'all',p_scheduled_at timestamptz default null
) returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_id uuid;
begin
  if coalesce(internal.current_platform_role(), '')<>'admin' then
    raise exception 'Only admins can send Food promotions';
  end if;
  if p_coupon_id is not null and not exists(
    select 1 from public.food_coupon_codes where id=p_coupon_id and is_active
  ) then raise exception 'coupon_not_active'; end if;
  if p_audience not in ('all','returning') then raise exception 'invalid_audience'; end if;
  if char_length(trim(coalesce(p_title,''))) not between 3 and 90
    or char_length(trim(coalesce(p_body,''))) not between 5 and 260 then
    raise exception 'invalid_promotion_copy';
  end if;
  insert into public.food_promo_broadcasts(title,body,coupon_id,audience,scheduled_at,created_by)
  values(trim(p_title),trim(p_body),p_coupon_id,p_audience,coalesce(p_scheduled_at,now()),auth.uid())
  returning id into v_id;
  return v_id;
end;
$fn$;
create or replace function public.admin_food_promo_cancel(p_broadcast_id uuid)
returns void language plpgsql security definer set search_path='' as $fn$
begin
  if coalesce(internal.current_platform_role(),'')<>'admin' then
    raise exception 'Only admins can cancel Food promotions';
  end if;
  update public.food_promo_broadcasts set state='cancelled'
  where id=p_broadcast_id and state='queued';
  if not found then raise exception 'already_sent_or_not_found'; end if;
end;
$fn$;
create or replace function public.admin_food_promo_list()
returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare v_result jsonb;
begin
  if coalesce(internal.current_platform_role(),'') not in ('admin','moderator') then
    raise exception 'Admin access required';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
   'id',p.id,'title',p.title,'body',p.body,'audience',p.audience,
   'scheduled_at',p.scheduled_at,'state',p.state,
   'coupon_code',c.code,'coupon_id',p.coupon_id,
   'inbox_count',(select count(*) from public.food_notifications n where n.broadcast_id=p.id),
   'push_sent',(select count(*) from public.food_promo_deliveries d where d.broadcast_id=p.id and d.state='sent'),
   'push_failed',(select count(*) from public.food_promo_deliveries d where d.broadcast_id=p.id and d.state='failed')
  ) order by p.created_at desc),'[]'::jsonb) into v_result
  from (select * from public.food_promo_broadcasts order by created_at desc limit 100) p
  left join public.food_coupon_codes c on c.id=p.coupon_id;
  return v_result;
end;
$fn$;

-- Service-role-only worker. Enqueue in-app notifications and opt-in Food-only
-- push deliveries. Never read Social or Merchant push tokens, including NULL.
create or replace function public.food_promo_claim_batch(p_limit integer default 50)
returns table (
  delivery_id uuid,recipient_id uuid,broadcast_id uuid,
  push_title text,push_body text,coupon_code text
) language plpgsql security definer set search_path='' as $fn$
declare v_b record;
begin
  for v_b in
    select p.id,p.title,p.body,p.coupon_id,p.audience
    from public.food_promo_broadcasts p
    where p.state='queued' and p.scheduled_at<=now()
    order by p.scheduled_at,p.id for update skip locked limit 10
  loop
    -- Respect explicit In-App opt-out, and cap marketing frequency to
    -- no more than 3 messages in the last 7 days for each recipient.
    insert into public.food_notifications(recipient_id,broadcast_id,title,body,coupon_code)
    select r.uid,v_b.id,v_b.title,v_b.body,c.code
    from (
      select distinct x.uid from (
        select user_id as uid from public.push_tokens where platform='web' and app='food'
        union all select user_id from public.food_customer_addresses
        union all select buyer_id from public.food_orders where buyer_id is not null
        union all select user_id from public.food_marketing_preferences
      ) x where x.uid is not null
    ) r
    left join public.food_marketing_preferences pref on pref.user_id=r.uid
    left join public.food_coupon_codes c on c.id=v_b.coupon_id
    where coalesce(pref.in_app_marketing,true)
      and (v_b.audience='all' or exists(
        select 1 from public.food_orders o where o.buyer_id=r.uid
      ))
      and (select count(*) from public.food_notifications recent
           where recent.recipient_id=r.uid and recent.created_at>now()-interval '7 days')<3
    on conflict on constraint food_notifications_unique_delivery do nothing;

    -- Only recipients who explicitly enabled marketing Push and have a
    -- currently classified WYNOS Food token are queued for Web Push.
    insert into public.food_promo_deliveries(broadcast_id,recipient_id)
    select v_b.id,n.recipient_id
    from public.food_notifications n
    join public.food_marketing_preferences pref on pref.user_id=n.recipient_id
      and pref.push_marketing=true
    where n.broadcast_id=v_b.id
      and exists (select 1 from public.push_tokens pt where pt.user_id=n.recipient_id
                  and pt.platform='web' and pt.app='food')
      and not exists (
        select 1 from public.food_promo_deliveries recent
        join public.food_promo_broadcasts bp on bp.id=recent.broadcast_id
        where recent.recipient_id=n.recipient_id and recent.state='sent'
          and recent.sent_at > now()-interval '24 hours'
      )
    on conflict on constraint food_promo_deliveries_unique do nothing;

    update public.food_promo_broadcasts set state='sent',processed_at=now()
    where id=v_b.id;
  end loop;

  return query
  with candidates as (
    select d.id from public.food_promo_deliveries d
    where (d.state='queued' or
           (d.state='sending' and d.lease_until<now() and d.attempts<3))
    order by d.created_at,d.id for update skip locked
    limit greatest(1,least(coalesce(p_limit,50),200))
  ), updated as (
    update public.food_promo_deliveries d set
      state='sending',attempts=attempts+1,lease_until=now()+interval '10 minutes'
    from candidates x where d.id=x.id
    returning d.id,d.recipient_id,d.broadcast_id
  )
  select u.id,u.recipient_id,u.broadcast_id,p.title,p.body,c.code
  from updated u join public.food_promo_broadcasts p on p.id=u.broadcast_id
  left join public.food_coupon_codes c on c.id=p.coupon_id;
end;
$fn$;

create or replace function public.food_promo_finish_delivery(
  p_delivery_id uuid,p_success boolean,p_error text default null
) returns void language plpgsql security definer set search_path='' as $fn$
begin
  update public.food_promo_deliveries set
    state=case when p_success then 'sent' when attempts>=3 then 'failed' else 'queued' end,
    sent_at=case when p_success then now() else null end,
    last_error=case when p_success then null else left(coalesce(p_error,'delivery_failed'),250) end,
    lease_until=null
  where id=p_delivery_id and state='sending';
end;
$fn$;

revoke all on function public.admin_food_promo_schedule(text,text,uuid,text,timestamptz) from public,anon;
revoke all on function public.admin_food_promo_cancel(uuid) from public,anon;
revoke all on function public.admin_food_promo_list() from public,anon;
grant execute on function public.admin_food_promo_schedule(text,text,uuid,text,timestamptz) to authenticated;
grant execute on function public.admin_food_promo_cancel(uuid) to authenticated;
grant execute on function public.admin_food_promo_list() to authenticated;
revoke all on function public.food_promo_claim_batch(integer) from public,anon,authenticated;
revoke all on function public.food_promo_finish_delivery(uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.food_promo_claim_batch(integer) to service_role;
grant execute on function public.food_promo_finish_delivery(uuid,boolean,text) to service_role;
