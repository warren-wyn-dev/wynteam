-- WYNOS WEB BETA 2 — STAGING ONLY. DO NOT APPLY TO PRODUCTION.
-- Approved staging Supabase ref: yydgdapzlrjmlrjgijkj.
-- Comparison: production kqokpocajhfbidcxpvhh has 17 anon EXECUTE functions;
-- 15 of those exist in this older staging schema. The other 103 anonymous grants
-- here are excess privileges relative to production. Authenticated grants are explicit.
-- Apply ONLY to the unseeded staging project via mcp Supabase apply_migration.
-- This migration must be reviewed if staging schema or grants change.

DO $guard$
BEGIN
  IF (SELECT count(*) FROM auth.users) <> 0 OR (SELECT count(*) FROM public.profiles) <> 0 THEN
    RAISE EXCEPTION 'Refusing anonymous-grant reconciliation on a populated database: staging-only operation';
  END IF;
  IF to_regprocedure('public.club_chat_actions_available()') IS NULL THEN
    RAISE EXCEPTION 'Staging Club Chat schema is missing';
  END IF;
END
$guard$;

-- Production parity for the 143 functions currently installed in this empty
-- staging database. Revoking PUBLIC inheritance is necessary; anon REVOKE alone
-- leaves all 103 functions callable through PUBLIC grants.
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;

-- Preserve only the 15 legitimate anonymous functions that exist in both.
GRANT EXECUTE ON FUNCTION public.calculate_top100_score(p_likes integer, p_comments integer, p_shares integer, p_saves integer, p_qualified_views integer, p_unique_engagers integer, p_action_count integer, p_content_age_hours double precision, p_trend_score double precision, p_report_count integer, p_suspicious boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.calculate_trend_score(p_velocity_15m double precision, p_velocity_1h double precision, p_velocity_6h double precision, p_previous_velocity_1h double precision, p_unique_engagers integer, p_action_count integer, p_report_count integer, p_content_age_hours double precision, p_suspicious boolean) TO anon;
GRANT EXECUTE ON FUNCTION public.club_event_rsvp_counts(p_event_ids uuid[]) TO anon;
GRANT EXECUTE ON FUNCTION public.fetch_mutual_follows(p_page integer) TO anon;
GRANT EXECUTE ON FUNCTION public.generate_referral_code() TO anon;
GRANT EXECUTE ON FUNCTION public.get_top100_candidates(p_limit integer) TO anon;
GRANT EXECUTE ON FUNCTION public.get_trending_candidates(p_limit integer) TO anon;
GRANT EXECUTE ON FUNCTION public.is_invite_gate_enabled() TO anon;
GRANT EXECUTE ON FUNCTION public.prevent_cross_channel_message_reply() TO anon;
GRANT EXECUTE ON FUNCTION public.prevent_cross_conversation_reply() TO anon;
GRANT EXECUTE ON FUNCTION public.preview_club_invite_link(p_code text) TO anon;
GRANT EXECUTE ON FUNCTION public.set_referral_code_on_profile() TO anon;
GRANT EXECUTE ON FUNCTION public.valid_draft_poll_options(p_options text[]) TO anon;
GRANT EXECUTE ON FUNCTION public.valid_poll_options(p_options text[]) TO anon;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(p_code text) TO anon;

-- PostgreSQL function grants to authenticated and service_role are left alone.
