-- Guest browsing may use Supabase Anonymous Sign-In, which still assumes
-- the authenticated Postgres role. Follow and Follow Request are real-account
-- actions, so distinguish anonymous sessions with the JWT claim at RLS.
-- Restrictive policies AND with the existing permissive insert policies.

drop policy if exists "Only permanent users can create follows" on public.follows;
create policy "Only permanent users can create follows"
  on public.follows
  as restrictive
  for insert
  to authenticated
  with check ((select (auth.jwt()->>'is_anonymous')::boolean) is false);

drop policy if exists "Only permanent users can create follow requests" on public.follow_requests;
create policy "Only permanent users can create follow requests"
  on public.follow_requests
  as restrictive
  for insert
  to authenticated
  with check ((select (auth.jwt()->>'is_anonymous')::boolean) is false);
