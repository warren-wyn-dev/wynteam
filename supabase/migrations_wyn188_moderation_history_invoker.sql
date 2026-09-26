-- WYN-188: staged security hardening; production schema change requires Founder approval.
-- This view alone can use caller privileges: moderation_actions has a staff-only
-- SELECT RLS policy and profiles is readable to authenticated users.
-- Never grant staff raw SELECT on reports or users raw SELECT on user_affinities.
-- Rollback: ALTER VIEW public.admin_user_moderation_history SET (security_invoker = false).
DO $check$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c WHERE c.oid='public.moderation_actions'::regclass
      AND c.relrowsecurity
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname='public' AND p.tablename='moderation_actions'
      AND p.cmd='SELECT' AND 'authenticated' = ANY(p.roles)
      AND position('internal.current_platform_role()' in p.qual)>0
  ) OR NOT has_table_privilege('authenticated','public.moderation_actions','SELECT')
    OR NOT has_table_privilege('authenticated','public.profiles','SELECT')
  THEN RAISE EXCEPTION 'WYN-188: RLS or underlying read grants changed; refuse migration';
  END IF;
END
$check$;
ALTER VIEW public.admin_user_moderation_history SET (security_invoker = true);
