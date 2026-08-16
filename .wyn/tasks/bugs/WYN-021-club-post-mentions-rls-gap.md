# Bug Report — WYN-021

Status: bugs | new
Owner: AI Debug Engineer

Bug: `club_post_mentions`'s `select` RLS policy is `using (true)` (any authenticated user), instead of being gated by club membership like every sibling table this same task/file already establishes the pattern for (`club_posts`, `club_post_likes`, `club_post_comments` all correctly gate `select` with `public.club_role(club_id, auth.uid()) is not null`). This lets **any authenticated WYN user — including someone who was never even a pending member of a private Club — read `club_post_mentions` rows directly**, exposing (a) the existence/UUID of a private Club's post, and (b) exactly which user was mentioned in it, neither of which they are authorized to see per the private-Club visibility invariant WYN-014 established ("club posts are members-only-visible at the DB layer").

This is exploitable over the raw Supabase/PostgREST API (`GET /rest/v1/club_post_mentions?select=*`) with nothing more than any authenticated user's own JWT — it does not require any Flutter app code path, so app-level UI restrictions provide zero protection against it.

Reproduction (verified end-to-end against real local Postgres 16, `supabase/schema.sql` loaded clean with `ON_ERROR_STOP=1`):
1. Seed: `clubowner` creates a **private** Club. `author` is an **approved member**. `outsider` is **not a member at all** (not even `pending`).
2. `author` creates a Club post in that private Club, mentioning `mentioned` (`@mentioned`) — this correctly inserts a `club_post_mentions` row via the `insert` policy, which correctly checks `club_posts.author_id = auth.uid()`.
3. As `outsider` (`request.jwt.claim.sub` set to outsider's id, role `authenticated`):
   - `select content from public.club_posts where id = '<the post>'` → **0 rows** (correctly blocked — proves outsider truly has no visibility, `club_role()` returns `null` for them).
   - `select club_post_id, mentioned_user_id from public.club_post_mentions where club_post_id = '<the post>'` → **1 row returned**, leaking the post's id and the mentioned user's id to someone with zero legitimate access to that Club.

Root Cause: `supabase/schema.sql`, the `"Club post mentions are viewable by authenticated users"` policy (WYN-021 section) was written with `using (true)` — the same broad-select shape used for `drop_mentions` (which is correct there, because `drops` themselves are globally public, `using (true)`, per WYN-005). The author of this policy did not carry over the membership-gated `using` clause that `club_post_likes`/`club_post_comments`/`club_posts` all use in the exact same file, for the exact same club-post-privacy reason. This is an inconsistency/oversight, not a documented, accepted tradeoff — nothing in `.wyn/docs/design/wyn-021-mention-system.md` mentions or accepts this gap.

Fix: Mirror `club_post_likes`'s/`club_post_comments`'s `select` policy shape exactly:

```sql
create policy "Approved club members can view club post mentions"
  on public.club_post_mentions
  for select
  to authenticated
  using (
    exists (
      select 1 from public.club_posts cp
      where cp.id = club_post_id
        and public.club_role(cp.club_id, auth.uid()) is not null
    )
  );
```

(`drop_mentions`'s `using (true)` policy does **not** need any change — `drops` have no privacy boundary, so that one is correct as-is. Do not "fix" it into something more restrictive.)

Files Changed (expected): `supabase/schema.sql` only (WYN-021 section, `club_post_mentions`'s `select` policy) — this is a pure RLS gap, no Dart change anticipated. Re-run `flutter analyze`/`flutter test` regardless per standing practice; nothing in the Dart client currently reads `club_post_mentions` directly (mentions are only ever consumed indirectly via `notifications`, per WYN-021's Coding notes), so tightening this policy should not break any existing app behavior.

Tests: Verify against a real local Postgres 16 (same harness this QA round used — stub `auth`/`storage` schemas + grants, load `schema.sql` with `ON_ERROR_STOP=1`) that after the fix:
1. The exact non-member-read reproduction above now returns 0 rows for `outsider`.
2. `author` (approved member) can still see the mention row for their own post.
3. A second approved member (not the author, not the mentioned user) can also still see it (matches `club_post_comments`'s "any approved member can view" semantics — mentions aren't restricted to just the author/mentioned pair).
4. Re-run the `drop_mentions` insert/self-mention-guard/non-author-insert-block proofs from this QA round to confirm no regression there (they don't touch this policy, but confirm the fix's surrounding transaction/DO block edits didn't disturb them).

Regression Risk: Low — the fix only *tightens* an over-broad policy to match the already-established, already-shipped pattern of its three sibling tables in the same file. No legitimate current read path (mentions are only ever displayed to whoever can already see the underlying post's content) requires the broader access.

Handoff to QA: Once fixed, send back to AI QA & Security for round 2 — must re-verify this specific policy against real Postgres (not just read the SQL), plus re-run the full WYN-021 Requirements/Design/Acceptance Criteria walk and the two other independent proofs from round 1 (self-mention guard, non-author insert block) to confirm no regression, per `.wyn/company/WORKFLOW.md`'s regression-test-memory convention.
