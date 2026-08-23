# Deployment Log — WYN-039 (Private Account + Follow Request)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-039 went through Product spec, Design spec, Coding, and a full independent QA cycle in this same session, continuing the Phase 3 session-pattern WYN-034 through WYN-038 established (Founder: "WYN 39" to start immediately after WYN-038).

- **Product/Design**: Master Spec section 10/11 ("PRIVATE ACCOUNT"/"FOLLOW SYSTEM") scoped into 6 numbered requirements: Account type toggle, Follow Request flow, Remove Follower, Content Visibility Gating, a `follows` SELECT-policy review, and 2 new notification types — deliberately deferring DM Permissions/Mention/Comment-level privacy settings to WYN-045 (Phase 5), mirroring how WYN-032 already added `message_request` ahead of WYN-043's nominal slot.
- **Architecture**: pending Follow Request state lives in a brand-new `follow_requests` table, not a `status` column bolted onto `follows` (WYN-008) — `follows` has too many existing call sites to retrofit safely. Content visibility is gated at a single point — `drops`' own RLS SELECT policy (extending WYN-027's Block pattern) — so `home_feed`/`saved_feed`/Search/Hashtag feed/ReDrop/`drop_comments`/`drop_polls` all inherit the gate automatically with no separate change at any of those call sites. Follower/Following *counts* stay visible to everyone via `follower_count()`/`following_count()` (SECURITY DEFINER, mirrors `drop_view_count()` from WYN-038), while the raw row list is gated through `follows`' own (tightened) SELECT policy.
- **Real issues found and fixed during Coding, before QA**: (1) `follows`' INSERT policy never checked the target's privacy — without the fix, a client could bypass the Follow Request flow entirely and instant-follow a Private account directly. (2) `get_poll_results()` (WYN-035, SECURITY DEFINER) bypassed the new gate entirely — a stranger who knew a Private Drop's `poll_id` could still read its vote results. (3) A genuine regression: Postgres truncates policy identifiers over 63 bytes, and two different policy names (pre- and post-WYN-037) truncated to the same prefix — the first `drop policy` statement written matched the wrong (newer) policy and silently dropped WYN-037's soft-delete visibility condition. Caught by re-running the WYN-037 regression suite and seeing 2 real check failures, not by inspection.
- **Independent QA found and fixed one more real gap**: Requirement 3 ("Remove Follower") was missing entirely from both the Design doc and the Coding implementation, despite being an explicit, numbered Product requirement with its own Acceptance Criteria and even schema-level detail already spelled out in the Product spec. Caught by checking every numbered Requirement and every Acceptance Criteria line against the actual code, not by trusting Coding Output's own "all criteria checked" claim (which was false). Fixed in the same round: an additive `follows` DELETE policy (`following_id = auth.uid()`, alongside WYN-008's original `follower_id` one), `FollowRepository.removeFollower()`, and a "ลบ" button on the caller's own Followers list. Recorded as a process lesson in `.wyn/learning/MISTAKES.md` (Design should checklist every numbered Product Requirement before handoff).

Full history: `.wyn/tasks/approved/WYN-039-private-account-follow-request.md` (Product/Design references/Coding Output/Independent QA sections), `.wyn/docs/design/wyn-039-private-account-follow-request.md`, `.wyn/company/DECISIONS.md` (2026-08-23 entry), `.wyn/learning/MISTAKES.md` (2026-08-23 entry).

## Build Status

Verified directly in this session (Flutter SDK installed fresh for this task) and a local Postgres 16 server, re-run again after the QA-round fix:

- `flutter analyze`: **0 issues**
- `flutter test`: **632/632 pass** (607 baseline from WYN-038 + 25 new from Coding, including the Remove Follower fix from QA)
- SQL regression scripts, each against a fresh Postgres 16 database under the real `authenticated` role (not superuser):
  - `supabase/tests/wyn_039_private_account_test.sh` — **28/28 PASS** (new this round)
  - All 12 prior scripts (`wyn_021` through `wyn_038`) — re-run independently after every change, **all still passing, no cross-task regression**
- `supabase/check_schema_ordering.py`: no forward references

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below.

## Changes

24 files changed across the full task (Product spec → Design spec → Coding → QA fix), merged via PR #151:

- **SQL** (`supabase/schema.sql`): `profiles.is_private`, `internal.can_view_author_content()`, new `follow_requests` table + 3 RLS policies + notify trigger, `accept_follow_request()` RPC, an auto-approve-on-public trigger, `drops`' SELECT policy extended for the Private gate (fixed to also preserve WYN-037's soft-delete condition), `get_poll_results()` extended with the same gate, `follows`' SELECT policy tightened + a 2nd INSERT-gate condition + a 2nd, additive DELETE policy (Remove Follower), `follower_count()`/`following_count()`, and 2 new notification types.
- **Flutter**: `Profile.isPrivate`, `ProfileRepository.updateIsPrivate()`, `FollowRepository` (count RPCs + `removeFollower()`), new `FollowRequestRepository`, new `FollowRequestListScreen`, `SettingsScreen` (now stateful, new Privacy section), `ViewProfileScreen` (3-state Follow button, Locked persona, own-profile badge), `FollowListScreen` (Remove Follower button), `NotificationType`/`NotificationListScreen` (2 new types).
- **New persisted regression test**: `supabase/tests/wyn_039_private_account_test.sh` (28 checks).
- **Tests**: `settings_screen_test.dart`, `view_profile_private_account_test.dart` (new file), `follow_request_list_screen_test.dart` (new file), `follow_list_screen_test.dart`, plus supporting `Recording*Repository` fakes.

Full history: `.wyn/tasks/approved/WYN-039-private-account-follow-request.md`.

## Deployment Result

**Merged to `main` via PR #151, pushed successfully.** Merge method: merge commit, matching the precedent set by PR #143–#150 (WYN-035 through WYN-038). This is the sixth and final task of **Phase 3 (Drop Enhancement)** to land on `main`, following WYN-034 (ReDrop), WYN-035 (Poll in Drop), WYN-036 (Draft System), WYN-037 (Edit/Delete Drop), and WYN-038 (View Counting) — **Phase 3 is now fully closed**. Users can now switch their account to Private, gating Drop visibility behind an approved Follow Request, and manage incoming requests and their own Followers list.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-038-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-seventh+ approved batch** in this project's history to reach this exact same gate — all "approved, ready for `main`, waiting for real infra." None of this has ever been a WYN-039-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: once merged, `git revert` the merge commit on `main` restores the pre-merge state. Reverting would remove the Private Account toggle, the Follow Request flow, and Remove Follower — `Profile.isPrivate` would go back to always-false, and any account a user had switched to Private would revert to fully public in the UI (though the underlying `is_private` column and its data would remain in the schema unless the SQL is also rolled back). Leaves WYN-021 through WYN-038 untouched.
- **Database**: `supabase/schema.sql` grew by the `follow_requests` table, `profiles.is_private`, several new/redefined RLS policies on `drops`/`follows`, and 4 new SECURITY DEFINER functions/triggers. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse, no accumulated `follow_requests`/private-account rows to reconcile.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-039-specific manual step is needed beyond those.

With WYN-039 code-complete and QA-approved, **Phase 3 (Drop Enhancement) is fully closed** (6/6 tasks: WYN-034 through WYN-039). Per the Roadmap, the next work is **Phase 4 (Discovery & Trending Engine)** — WYN-040 (Discovery page), WYN-041 (Trending Engine v2, a direct dependent of WYN-038's View data), and WYN-042 (WYN Top 100) — not started yet. Also still outstanding and unblocked at any time: WYN-023 (Home/Drop polish, small backlog item, design already done) and WYN-016 (Push Notifications, coded and self-verified but blocked on the Founder completing Firebase setup).
