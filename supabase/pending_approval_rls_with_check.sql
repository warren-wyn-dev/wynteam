-- ---------------------------------------------------------------------
-- PENDING FOUNDER APPROVAL — DO NOT APPLY TO PRODUCTION YET
--
-- Beta2 audit (2026-09-03), finding §8.1: six UPDATE policies define
-- USING but no WITH CHECK.
--
-- In PostgreSQL those two clauses answer different questions. USING
-- decides *which rows a user may update*; WITH CHECK decides *what the
-- row is allowed to look like afterwards*. With USING alone, a user can
-- update a row they legitimately own into a row they do not -- moving it
-- out of their own scope and into someone else's.
--
-- Concretely, on the six policies below:
--   * profiles / profile_private -- set your own row's `id` to the uuid
--     of an auth user with no profile row yet, taking over that identity.
--   * cart_items -- move an item out of your cart into another user's.
--   * club_posts -- move a post you may pin into a club you have no role
--     in.
--   * clubs -- change a club row you administer into one you do not.
--   * storage.objects -- move a file out of your own avatar folder.
--
-- Each policy below is the EXACT policy currently in schema.sql with a
-- WITH CHECK added that mirrors its own USING clause. Nothing else
-- changes: no new permission is granted, no legitimate app flow is
-- affected (the app never rewrites an owner column on update -- verified
-- across every `.update(` call site in app/lib), and every statement is
-- idempotent.
--
-- Why this file exists instead of being appended to schema.sql: RULES.md
-- puts "สถาปัตยกรรมความปลอดภัย" (security architecture) under Founder
-- authority, so an AI role may propose and prepare it but not put it on
-- the path to production unapproved. See the APPROVAL_REQUIRED entry
-- dated 2026-09-03 in .wyn/company/APPROVALS.md.
--
-- Once approved: run this file, then move its statements into
-- schema.sql (replacing the six original policy definitions) so the
-- file stays the single source of truth.
-- ---------------------------------------------------------------------

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can update their own private profile fields" on public.profile_private;
create policy "Users can update their own private profile fields"
  on public.profile_private
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can update their own cart items" on public.cart_items;
create policy "Users can update their own cart items"
  on public.cart_items
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Club owners and admins can update club info" on public.clubs;
create policy "Club owners and admins can update club info"
  on public.clubs
  for update
  to authenticated
  using (public.club_role(id, auth.uid()) in ('owner', 'admin'))
  with check (public.club_role(id, auth.uid()) in ('owner', 'admin'));

drop policy if exists "Club staff can pin or unpin club posts" on public.club_posts;
create policy "Club staff can pin or unpin club posts"
  on public.club_posts
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'))
  with check (public.club_role(club_id, auth.uid()) in ('owner', 'admin', 'moderator'));

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
