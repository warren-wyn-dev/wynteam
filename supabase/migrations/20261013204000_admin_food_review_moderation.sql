-- WYNOS Food review moderation from Admin. Does not hide/unhide any review on install.
-- Backend review feed already excludes is_hidden rows and recalculates aggregates.
create table if not exists public.food_review_moderation_actions (
 id uuid primary key default gen_random_uuid(),
 review_id uuid not null references public.food_store_reviews(id) on delete cascade,
 actor_id uuid not null references auth.users(id),
 reason text not null check (char_length(reason) between 5 and 300),
 old_hidden boolean not null,
 new_hidden boolean not null,
 created_at timestamptz not null default now()
);
create index if not exists food_review_moderation_history on public.food_review_moderation_actions(review_id,created_at desc);
alter table public.food_review_moderation_actions enable row level security;
revoke all on public.food_review_moderation_actions from public,anon,authenticated;

create or replace function public.admin_food_review_moderation_feed(p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_result jsonb;
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('food','view')
 then raise exception 'Not authorized'; end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',r.id,'store_id',r.store_id,'store_name',s.name,'rating',r.rating,
  'review_text',r.review_text,'tags',r.tags,
  'reviewer_label',r.reviewer_label,'merchant_reply',r.merchant_reply,
  'is_hidden',r.is_hidden,'created_at',r.created_at,'updated_at',r.updated_at
 ) order by r.created_at desc),'[]'::jsonb) into v_result
 from (
   select * from public.food_store_reviews order by created_at desc
   limit greatest(1,least(coalesce(p_limit,100),200))
 ) r join public.food_stores s on s.id=r.store_id;
 return v_result;
end;
$$;
revoke all on function public.admin_food_review_moderation_feed(integer) from public,anon;
grant execute on function public.admin_food_review_moderation_feed(integer) to authenticated;

create or replace function public.admin_set_food_review_hidden(
 p_review_id uuid, p_expected_updated_at timestamptz,
 p_hidden boolean, p_reason text
) returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
 v_review public.food_store_reviews%rowtype;
 v_reason text:=btrim(coalesce(p_reason,''));
begin
 if (select auth.uid()) is null or not internal.has_admin_permission('food','edit')
 then raise exception 'Not authorized'; end if;
 if p_review_id is null or p_expected_updated_at is null or p_hidden is null
 then raise exception 'Missing review or expected state'; end if;
 if char_length(v_reason) not between 5 and 300
 then raise exception 'Reason must be 5-300 characters'; end if;
 select * into v_review from public.food_store_reviews where id=p_review_id for update;
 if not found then raise exception 'Review not found'; end if;
 if v_review.updated_at is distinct from p_expected_updated_at
 then raise exception 'Review changed; reload before moderating'; end if;
 if v_review.is_hidden is not distinct from p_hidden
 then raise exception 'No change to review visibility'; end if;
 update public.food_store_reviews
  set is_hidden=p_hidden,updated_at=clock_timestamp()
  where id=p_review_id;
 insert into public.food_review_moderation_actions(review_id,actor_id,reason,old_hidden,new_hidden)
 values(v_review.id,(select auth.uid()),v_reason,v_review.is_hidden,p_hidden);
 return jsonb_build_object('id',v_review.id,'is_hidden',p_hidden);
end;
$$;
revoke all on function public.admin_set_food_review_hidden(uuid,timestamptz,boolean,text) from public,anon;
grant execute on function public.admin_set_food_review_hidden(uuid,timestamptz,boolean,text) to authenticated;
