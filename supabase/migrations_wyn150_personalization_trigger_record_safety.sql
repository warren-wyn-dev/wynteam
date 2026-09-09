-- WYN-150 / BUG-004 follow-up: make the polymorphic personalization trigger record-safe.
-- PL/pgSQL NEW only has fields from the table that fired the trigger; branch on
-- TG_TABLE_NAME before referencing table-specific fields.

create or replace function internal.capture_personalization_signal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_weight double precision;
  v_event_key text;
begin
  if tg_table_name = 'drop_likes' then
    perform internal.learn_from_drop('like:' || new.drop_id || ':' || new.user_id
      || ':' || new.created_at, new.user_id, new.drop_id, 2.0, new.created_at);
  elsif tg_table_name = 'drop_comments' then
    perform internal.learn_from_drop('comment:' || new.id, new.author_id,
      new.drop_id, 3.0, new.created_at);
  elsif tg_table_name = 'redrops' then
    perform internal.learn_from_drop('redrop:' || new.id, new.redropper_id,
      new.drop_id, 5.0, new.created_at,
      case when new.quote_text is null then null else 'quote' end);
  elsif tg_table_name = 'saves' then
  if new.content_type = 'drop' then
    perform internal.learn_from_drop('save:' || new.content_id || ':' || new.user_id
      || ':' || new.created_at, new.user_id, new.content_id, 4.0, new.created_at);
  end if;
  elsif tg_table_name = 'follows' then
    v_event_key := 'follow:' || new.follower_id || ':' || new.following_id
      || ':' || new.created_at;
    insert into public.personalization_processed_events(event_key)
    values(v_event_key) on conflict do nothing;
    if found then
      perform internal.apply_affinity_signal(new.follower_id, 'creator',
        new.following_id::text, 8.0, new.created_at);
    end if;
  elsif tg_table_name = 'feed_signals' then
    v_weight := case new.signal_type
      when 'profile_visit' then 1.0 when 'hide' then -6.0
      when 'not_interested' then -10.0 when 'fast_skip' then -1.0
      when 'short_view' then 0.25 when 'qualified_view' then 1.0
      when 'long_view' then 4.0 when 'follow_from_feed' then 2.0
      else 0.0 end;
    if new.target_type = 'drop' then
      perform internal.learn_from_drop('feed_signal:' || new.id, new.user_id,
        new.target_id, v_weight, new.created_at);
    elsif new.target_type = 'profile' and new.target_id <> new.user_id
      and exists(select 1 from public.profiles where id = new.target_id) then
      insert into public.personalization_processed_events(event_key)
      values('feed_signal:' || new.id) on conflict do nothing;
      if found then
        perform internal.apply_affinity_signal(new.user_id, 'creator',
          new.target_id::text, v_weight, new.created_at);
      end if;
    end if;
  elsif tg_table_name = 'reports' then
  if new.target_type = 'drop' then
    perform internal.learn_from_drop('report:' || new.id, new.reporter_id,
      new.target_id, -12.0, new.created_at);
  end if;
  elsif tg_table_name = 'blocks' then
  v_event_key := 'blocks:' || new.blocker_id || ':' || new.blocked_id
    || ':' || new.created_at;
  insert into public.personalization_processed_events(event_key)
  values(v_event_key) on conflict do nothing;
  if found then
    perform internal.apply_affinity_signal(new.blocker_id, 'creator',
      new.blocked_id::text, -20.0, new.created_at);
  end if;
elsif tg_table_name = 'mutes' then
  v_event_key := 'mutes:' || new.muter_id || ':' || new.muted_id
    || ':' || new.created_at;
  insert into public.personalization_processed_events(event_key)
  values(v_event_key) on conflict do nothing;
  if found then
    perform internal.apply_affinity_signal(new.muter_id, 'creator',
      new.muted_id::text, -8.0, new.created_at);
  end if;
  end if;
  return new;
end;
$$;

revoke all on function internal.capture_personalization_signal() from public;
