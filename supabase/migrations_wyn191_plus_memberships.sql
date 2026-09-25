-- Phase 3 schema is a staged proposal, not an approved production migration.
-- Browser clients cannot grant or update their own Plus status.
CREATE TABLE IF NOT EXISTS public.wynos_plus_memberships (
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 tier text NOT NULL DEFAULT 'plus' CHECK(tier='plus'),
 status text NOT NULL DEFAULT 'incomplete'
   CHECK(status IN ('incomplete','trialing','active','past_due','canceled','unpaid')),
 current_period_end timestamptz,
 cancel_at_period_end boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.wynos_plus_memberships ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.wynos_plus_memberships FROM public,anon,authenticated;
GRANT SELECT ON TABLE public.wynos_plus_memberships TO authenticated;
DROP POLICY IF EXISTS "Read only own Plus membership" ON public.wynos_plus_memberships;
CREATE POLICY "Read only own Plus membership" ON public.wynos_plus_memberships
  FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);

-- Opaque billing references stay outside public Data API in internal schema.
CREATE TABLE IF NOT EXISTS internal.wynos_plus_billing_refs (
 user_id uuid PRIMARY KEY REFERENCES public.wynos_plus_memberships(user_id) ON DELETE CASCADE,
 provider text NOT NULL CHECK(length(provider) BETWEEN 1 AND 40),
 customer_id text,
 subscription_id text,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(provider,customer_id), UNIQUE(provider,subscription_id)
);
ALTER TABLE internal.wynos_plus_billing_refs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE internal.wynos_plus_billing_refs FROM public,anon,authenticated;
DO $grants$
BEGIN
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN
  GRANT ALL ON TABLE public.wynos_plus_memberships TO service_role;
  GRANT ALL ON TABLE internal.wynos_plus_billing_refs TO service_role;
 END IF;
END
$grants$;
