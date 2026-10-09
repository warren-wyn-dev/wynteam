-- TEMPORARY LOCAL SUPABASE AUTH QA ONLY.
-- This fixture is never applied to any hosted/Production Supabase project.
-- It is intentionally minimal and cannot certify WYNOS's complete live schema/RPCs.
BEGIN;
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text NOT NULL UNIQUE,
  display_name text,
  platform_role text NOT NULL DEFAULT 'user'
    CHECK (platform_role IN ('user', 'moderator', 'admin'))
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO service_role;
CREATE POLICY "local_owner_read_only" ON public.profiles
FOR SELECT TO authenticated USING ((select auth.uid()) = id);
COMMIT;
NOTIFY pgrst, 'reload schema';
