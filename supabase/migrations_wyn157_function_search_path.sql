-- WYN-157 / system audit: pin search_path on the remaining functions that
-- Supabase's security advisor reports as role-mutable.
--
-- These functions are SECURITY INVOKER today, but leaving name resolution to
-- the caller/session search_path is unnecessary and makes future edits easier
-- to get wrong. Use one conservative path that includes only WYNOS schemas
-- these functions legitimately reference, with pg_catalog first and pg_temp
-- last. Existing function bodies/permissions are unchanged.

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where (n.nspname, p.proname) in (
      ('internal', 'experiment_bucket'),
      ('internal', 'repetition_adjust_source_scores'),
      ('internal', 'get_wynos_ranked_feed_base_v1'),
      ('public', 'prevent_cross_conversation_reply'),
      ('public', 'valid_poll_options'),
      ('public', 'valid_draft_poll_options'),
      ('public', 'get_wynos_ranked_feed'),
      ('public', 'club_event_rsvp_counts'),
      ('public', 'generate_referral_code'),
      ('public', 'set_referral_code_on_profile'),
      ('public', 'prevent_cross_channel_message_reply'),
      ('public', 'calculate_feed_quality_score'),
      ('public', 'calculate_trend_score'),
      ('public', 'get_trending_candidates'),
      ('public', 'calculate_top100_score'),
      ('public', 'get_top100_candidates')
    )
  loop
    execute format(
      'alter function %s set search_path = pg_catalog, public, internal, auth, pg_temp',
      fn.signature
    );
  end loop;
end
$$;
