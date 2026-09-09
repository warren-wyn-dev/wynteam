-- WYN-152 / BUG-004 follow-up: make the WYN-145 experiment outcome trigger
-- safe across all of the tables it is attached to. PL/pgSQL evaluates record
-- field references against the trigger table's row type, so table-specific
-- fields must only be touched after TG_TABLE_NAME selects that table.

create or replace function internal.attribute_feed_experiment_outcome()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_type text;
  v_target uuid;
  v_key text;
  v_at timestamptz;
begin
  if tg_table_name = 'feed_signals' then
    v_user := new.user_id;
    v_type := new.signal_type;
    v_target := new.target_id;
    v_key := 'feed_signal:' || new.id;
    v_at := new.created_at;
  elsif tg_table_name = 'drop_likes' then
    v_user := new.user_id;
    v_type := 'like';
    v_target := new.drop_id;
    v_key := 'like:' || new.drop_id || ':' || new.user_id;
    v_at := new.created_at;
  elsif tg_table_name = 'drop_comments' then
    v_user := new.author_id;
    v_type := 'comment';
    v_target := new.drop_id;
    v_key := 'comment:' || new.id;
    v_at := new.created_at;
  elsif tg_table_name = 'redrops' then
    v_user := new.redropper_id;
    v_type := 'share';
    v_target := new.drop_id;
    v_key := 'share:' || new.id;
    v_at := new.created_at;
  elsif tg_table_name = 'saves' then
    if new.content_type <> 'drop' then
      return new;
    end if;
    v_user := new.user_id;
    v_type := 'save';
    v_target := new.content_id;
    v_key := 'save:' || new.user_id || ':' || new.content_id;
    v_at := new.created_at;
  elsif tg_table_name = 'reports' then
    if new.target_type <> 'drop' then
      return new;
    end if;
    v_user := new.reporter_id;
    v_type := 'report';
    v_target := new.target_id;
    v_key := 'report:' || new.id;
    v_at := new.created_at;
  else
    return new;
  end if;

  if v_type not in (
    'qualified_view','long_view','fast_skip','like','save','comment','share',
    'profile_visit','follow_from_feed','hide','not_interested','report'
  ) then
    return new;
  end if;

  insert into public.feed_experiment_outcomes(
    exposure_id,event_key,outcome_type,target_id,occurred_at
  )
  select x.id,v_key,v_type,v_target,v_at
  from public.feed_experiment_exposures x
  join public.feed_experiments e
    on e.experiment_key = x.experiment_key
   and e.version = x.experiment_version
  where x.user_id = v_user
    and x.surface = 'home'
    and x.exposed_at <= v_at
    and x.exposure_date = v_at::date
    and v_at >= e.start_at
    and v_at < e.end_at
  on conflict do nothing;

  return new;
end;
$$;

revoke all on function internal.attribute_feed_experiment_outcome() from public;
