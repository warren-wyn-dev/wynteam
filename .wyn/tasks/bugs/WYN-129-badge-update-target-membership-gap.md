# Bug Report — WYN-129

Status: bugs
Owner: AI Debug Engineer

Bug: `public.club_member_badges`'s `update` RLS policy re-validates only that the caller is still Owner/Admin of `club_id` — it never re-validates that the row's (possibly changed) `user_id` is still an approved member of that Club, unlike the `insert` policy which explicitly requires `public.club_role(club_id, user_id) is not null`. An Owner/Admin can therefore `UPDATE` an existing badge row's `user_id` to point at any other user id at all (a pending member, a banned member, or someone with zero relationship to the Club whatsoever), completely bypassing the "target must be an approved member" invariant the feature's own Coding Notes describe as an insert-time guarantee.

Confirmed **empirically against a real local PostgreSQL 16.13** (not just read-through, per this project's `supabase/tests/*.sh` convention) — full repro script and current stub/schema-loading harness available on request; the minimal reproduction is below.

Reproduction:
1. Load `supabase/schema.sql` into an empty Postgres 16 DB with the project's standard `auth`/`storage`/`authenticated` role stub (same stub every `supabase/tests/wyn_*_test.sh` script in this repo uses).
2. Seed: Club `c1` owned by `alice`; `bob` = admin (approved); `carol` = member (approved); `dave` = a user with **no** `club_members` row for `c1` at all (not even pending).
3. As `bob` (admin, `set role authenticated; set request.jwt.claim.sub = bob`), `INSERT INTO club_member_badges (club_id, user_id, label, color_key, created_by) VALUES (c1, carol, 'VIP', 'gold', bob)` — succeeds correctly (carol is an approved member).
4. Still as `bob`, `UPDATE club_member_badges SET user_id = dave WHERE club_id = c1 AND user_id = carol` — **this succeeds** (0 rows returned as blocked, expected 1/rejected). Verified via `psql` under `set role authenticated` with the JWT claim GUCs the rest of this repo's RLS tests use.
5. Read `supabase/schema.sql`'s policies (WYN-129 section, ~line 13355):
   ```sql
   create policy "Club owners and admins can set member badges"
     on public.club_member_badges
     for insert to authenticated
     with check (
       auth.uid() = created_by
       and public.club_role(club_id, auth.uid()) in ('owner', 'admin')
       and public.club_role(club_id, user_id) is not null   -- target-membership gate
     );

   create policy "Club owners and admins can edit member badges"
     on public.club_member_badges
     for update to authenticated
     using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'));
     -- no `with check`, and critically: no `club_role(club_id, user_id) is not null` re-check either
   ```

Root Cause: Same bug class as `ZOKY-004-review-update-rls-gap.md` in this same repo (Postgres reuses `using` as the implicit `with check` when a `for update` policy omits one, but that only re-verifies whatever conditions `using` itself expresses — here, only the *caller's* role, never the *target row's* own membership invariant). The `insert` policy correctly encodes two separate invariants (caller is owner/admin, AND target is an approved member); the `update` policy only carries the first one forward.

Practical impact is **low but real**: badges are confirmed (separately, by QA this round) to never feed into any permission/authorization decision anywhere in the codebase, so this cannot be used to escalate privilege. It also cannot be reached through the shipped Flutter UI today — `ClubBadgeRepository.setBadge()` always `upsert()`s with `onConflict: 'club_id,user_id'` and never changes an existing row's `user_id`. The exposure is to a user with a valid Owner/Admin session making a direct REST call to Supabase (bypassing the app), who could reassign an existing badge to a non-member/banned/pending user, silently violating the feature's own documented invariant and leaving orphaned-looking cosmetic data behind after someone leaves/is banned.

Fix: Add an explicit `with check` to the `update` policy mirroring the `insert` policy's target-membership gate:

```sql
create policy "Club owners and admins can edit member badges"
  on public.club_member_badges
  for update
  to authenticated
  using (public.club_role(club_id, auth.uid()) in ('owner', 'admin'))
  with check (
    public.club_role(club_id, auth.uid()) in ('owner', 'admin')
    and public.club_role(club_id, user_id) is not null
  );
```

Apply the identical change to both `supabase/schema.sql` (WYN-129 section) and `supabase/migrations_wyn129_club_member_badges.sql` (kept in sync per this project's convention), so a fresh apply and the already-drafted migration agree.

Files Changed (expected): `supabase/schema.sql`, `supabase/migrations_wyn129_club_member_badges.sql`. No Dart changes anticipated — `ClubBadgeRepository.setBadge()` never changes `user_id` on an existing row, so the tightened policy cannot reject anything the app itself does.

Tests: Add a dedicated `supabase/tests/wyn_129_club_role_badges_test.sh` (this feature currently has **no** committed RLS regression test at all, unlike WYN-115/116/117/118/etc., each of which has one — see `.wyn/company/WORKFLOW.md`'s Regression Test Memory convention) covering: insert/update/delete restricted to owner/admin; insert rejects a non-member/pending/banned target; **this bug's exact repro** (update cannot retarget `user_id` to a non-member); 1-badge-per-member-per-Club enforced via the `(club_id, user_id)` primary key; `color_key` restricted to the 3-value palette.

Regression Risk: Low — purely additive tightening of an `update` policy; cannot break the one legitimate call site (`ClubBadgeRepository.setBadge`'s upsert), which never changes `user_id`.

Handoff to QA: Once fixed, re-verify this specific policy (re-run the repro above expecting rejection) plus a full walk of WYN-129's Requirements/Acceptance Criteria again, per this project's regression-test-memory convention.
