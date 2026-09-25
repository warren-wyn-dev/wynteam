-- WYN-190 staged hardening of the two remaining privileged API views.
-- Do not broaden client SELECT on raw reports or user_affinities: those
-- existing barriers protect reporter anonymity and private learning signals.
-- Keep a scoped, audited SECURITY DEFINER read helper in the internal schema;
-- its output is the original view's exact safe column projection, checked
-- against auth.uid() or a trusted, non-user platform role.
-- Only the OUTER public API views switch to security_invoker=true.
--
-- Rollback (after independent incident review):
--   CREATE OR REPLACE VIEW public.moderation_queue
--     WITH (security_invoker=false) AS
--     SELECT id,target_type,target_id,category,detail,status,created_at
--     FROM public.reports
--     WHERE internal.current_platform_role() <> 'user';
--   CREATE OR REPLACE VIEW public.my_effective_affinities
--     WITH (security_invoker=false,security_barrier=true) AS
--     SELECT dimension_type,dimension_key,
--       tanh((0.65*recent_score*power(0.5,extract(epoch FROM
--         (now()-updated_at))/3600.0/168.0)
--       +0.35*long_term_score*power(0.5,extract(epoch FROM
--         (now()-updated_at))/3600.0/2160.0))/10.0) AS effective_score,
--       personalization_version,updated_at
--     FROM public.user_affinities WHERE user_id=auth.uid();
--   DROP FUNCTION internal.wyn190_staff_report_rows();
--   DROP FUNCTION internal.wyn190_my_affinity_rows();
DO $preflight$
BEGIN
  IF NOT has_schema_privilege('authenticated','internal','USAGE')
     OR NOT EXISTS (
       SELECT 1 FROM pg_class
       WHERE oid='public.reports'::regclass AND relrowsecurity
     )
     OR NOT EXISTS (
       SELECT 1 FROM pg_policies
       WHERE schemaname='public' AND tablename='reports'
         AND cmd='SELECT' AND position('reporter_id' IN qual)>0
     )
     OR NOT EXISTS (
       SELECT 1 FROM pg_class
       WHERE oid='public.user_affinities'::regclass AND relrowsecurity
     )
     OR has_table_privilege('authenticated','public.user_affinities','SELECT')
  THEN
    RAISE EXCEPTION 'WYN-190: raw-data privacy preconditions changed; refusing migration';
  END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION internal.wyn190_staff_report_rows()
RETURNS TABLE (
  id uuid,target_type text,target_id uuid,category text,
  detail text,status text,created_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $reports$
  SELECT r.id,r.target_type,r.target_id,r.category,
         r.detail,r.status,r.created_at
  FROM public.reports AS r
  WHERE internal.current_platform_role() <> 'user'
$reports$;
REVOKE ALL ON FUNCTION internal.wyn190_staff_report_rows()
  FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION internal.wyn190_staff_report_rows() TO authenticated;

CREATE OR REPLACE FUNCTION internal.wyn190_my_affinity_rows()
RETURNS TABLE (
  dimension_type text,dimension_key text,effective_score double precision,
  personalization_version integer,updated_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = ''
AS $affinities$
  SELECT a.dimension_type,a.dimension_key,
    tanh((
      0.65*a.recent_score*power(0.5,
        extract(epoch FROM (now()-a.updated_at))/3600.0/168.0)
      +0.35*a.long_term_score*power(0.5,
        extract(epoch FROM (now()-a.updated_at))/3600.0/2160.0)
    )/10.0)::double precision AS effective_score,
    a.personalization_version,a.updated_at
  FROM public.user_affinities AS a
  WHERE a.user_id=auth.uid()
$affinities$;
REVOKE ALL ON FUNCTION internal.wyn190_my_affinity_rows()
  FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION internal.wyn190_my_affinity_rows() TO authenticated;

CREATE OR REPLACE VIEW public.moderation_queue
WITH (security_invoker=true)
AS SELECT id,target_type,target_id,category,detail,status,created_at
FROM internal.wyn190_staff_report_rows();

CREATE OR REPLACE VIEW public.my_effective_affinities
WITH (security_barrier=true,security_invoker=true)
AS SELECT dimension_type,dimension_key,effective_score,
          personalization_version,updated_at
FROM internal.wyn190_my_affinity_rows();

REVOKE ALL ON TABLE public.moderation_queue,public.my_effective_affinities
  FROM public,anon,authenticated;
GRANT SELECT ON TABLE public.moderation_queue,public.my_effective_affinities
  TO authenticated;
