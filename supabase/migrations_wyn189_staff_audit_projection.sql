-- WYN-189: Preserve admin audit visibility while moving its API-facing view
-- to invoker permissions. Raw audit_log deliberately retains zero client-side
-- SELECT policies, so even staff cannot query it directly through Data API.
-- Instead, only this projection uses a narrowly authorized SECURITY DEFINER
-- function in the non-exposed internal schema, returning exactly the existing
-- seven public.admin_audit_log columns. Production rollout requires approval.
--
-- Rollback, preserving raw audit_log privacy:
--   ALTER VIEW public.admin_audit_log SET (security_invoker=false);
--   CREATE OR REPLACE VIEW public.admin_audit_log AS SELECT id,actor_id,
--     actor_username_snapshot,event_type,target_id,detail,created_at
--     FROM public.audit_log
--     WHERE internal.current_platform_role() <> 'user';
--   DROP FUNCTION internal.wyn189_staff_audit_rows();
--
DO $preflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE oid='public.audit_log'::regclass AND relrowsecurity
  ) OR EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='audit_log'
      AND cmd IN ('SELECT','ALL')
  ) OR NOT has_schema_privilege('authenticated','internal','USAGE')
  THEN
    RAISE EXCEPTION 'WYN-189: protected audit_log / internal usage precondition changed';
  END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION internal.wyn189_staff_audit_rows()
RETURNS TABLE (
  id uuid,
  actor_id uuid,
  actor_username_snapshot text,
  event_type text,
  target_id uuid,
  detail jsonb,
  created_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $projection$
  SELECT a.id,a.actor_id,a.actor_username_snapshot,a.event_type,
    a.target_id,a.detail,a.created_at
  FROM public.audit_log AS a
  WHERE internal.current_platform_role() IN ('moderator','admin')
$projection$;

REVOKE ALL ON FUNCTION internal.wyn189_staff_audit_rows()
  FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION internal.wyn189_staff_audit_rows() TO authenticated;

CREATE OR REPLACE VIEW public.admin_audit_log
WITH (security_invoker=true)
AS
SELECT id,actor_id,actor_username_snapshot,event_type,target_id,detail,created_at
FROM internal.wyn189_staff_audit_rows();

REVOKE ALL ON TABLE public.admin_audit_log FROM public,anon,authenticated;
GRANT SELECT ON TABLE public.admin_audit_log TO authenticated;
