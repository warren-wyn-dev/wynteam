# Deployment Log — WYN-034 (ReDrop: Standard + Quote)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-034 went through Product spec, Design spec, Coding, and a full independent QA cycle all in this same session (Coding then a distinct, adversarial QA pass over the finished work):

- **Product/Design**: Master Spec section 5 calls for ReDrop in 2 forms — Standard (share as-is to your own feed) and Quote (share with your own commentary) — with the original owner's credit always preserved. Key architectural decision: a single new `redrops` table (`drop_id`/`redropper_id`/`quote_text` — null `quote_text` is a toggleable Standard ReDrop guarded by a partial unique index, non-null is an unlimited Quote ReDrop) feeds a **3rd branch on the existing `home_feed` view that stays `content_type = 'drop'`** rather than introducing a new content type. The branch's `id`/`author_id`/`image_url`/`caption`/`like_count`/`comment_count` all continue to describe the *original* Drop, so every existing Like/Comment/Save action — and the WYN-018 `rankingScore()` formula — works correctly against a ReDrop-sourced row with zero code changes to either (confirmed: `home_ranking.dart` never appears in this task's diff). Only `created_at` changes meaning for that branch (the ReDrop's own timestamp), which is what lets an old Drop resurface near the top of a chronological/recency-weighted feed when freshly reshared.
- **Coding**: SQL added the `redrops` table, 3 RLS policies (SELECT filters block on the redropper directly and, by piggybacking on `drops`' own SELECT policy via an `exists()` check, on the original author too; INSERT blocks posting-blocked/blocked-author cases; DELETE restricts to the redropper's own rows), the `home_feed` 3rd branch, CHECK extensions on `reports.target_type`/`notifications.type` for a new `'redrop'` value, and a `submit_report()` branch. Flutter added a 🔄 ReDrop button + 2-option action sheet (Standard toggle / Quote) on `HomeDropCard`/`DropDetailScreen`, a new `QuoteRedropScreen`, a "🔄 ReDrop โดย @username" feed-card label with quote text, and a Profile "ReDrops" tab that reuses `HomeDropCard` directly rather than a bespoke widget. Found and fixed 3 real gaps while self-reviewing before QA (disclosed per this project's standing practice): (1) a missing `notify_redrop()` DB trigger — the Design spec's SQL sketch was written as a comment but never actually turned into a real trigger, caught while writing the SQL regression script and finding nothing to test against; fixed by mirroring `notify_drop_like()` exactly. (2) `DropRepository.deleteRedrop()` existed with no UI ever calling it, despite the Product spec explicitly requiring the ability to delete your own Quote ReDrop — caught by walking the Acceptance Criteria against the actual code line by line before handing off to QA. (3) A `_items`-list key-collision risk: once a Drop can appear twice on the same feed page (once as itself, once via someone's ReDrop of it) sharing the same `id`, the pre-existing `ValueKey(item.id)` and id-based toggle lookups would collide — caught during design, fixed proactively with a composite key and index-based toggle methods before it could ever surface as a bug.
- **Independent QA — PASS (single round)**: reviewed the full `schema.sql` diff directly, ran `flutter analyze` (clean) and `flutter test` (527/527) independently. **Stress-tested the RLS block-filtering logic in a separate throwaway database** rather than trusting the regression script's assertions alone — and caught a flaw in the QA's own first attempt at a scenario: testing "a block applied after the ReDrop already exists is still enforced" by having one user block a redropper while checking visibility from an *uninvolved third party* (who was never blocked with anyone, so of course the row stayed visible) proved nothing about dynamic re-evaluation. Caught this from the SQL's actual output contradicting the intended assertion, not by assuming the check would pass — corrected the scenario so the *viewer themselves* blocks the redropper after the fact, then confirmed the row disappears immediately with no special action needed (RLS re-evaluates per query, not a stale snapshot from insert time). Also verified, via a direct hand-run `DELETE ... WHERE id = <someone else's redrop>`, that a non-owner delete attempt against `redrops` is a silent 0-row no-op enforced at the database layer — not something relying on the client's own `_isOwnRedrop` check as the only safeguard.

Full history: `.wyn/tasks/approved/WYN-034-redrop.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified at `main` HEAD post-merge, using Flutter (stable) from `/home/user/flutter`:

- `flutter pub get`: clean (packages have newer versions available, none blocking)
- `flutter analyze`: **0 issues**
- `flutter test`: **527/527 pass**
- Merge method: **merge commit** via GitHub (`claude/wyn-034-redrop` → `main`, PR #141). `origin/main` was confirmed an ancestor of the feature branch before opening the PR.
- SQL regression scripts re-run against a fresh local Postgres 16 (cluster `16/main`, port 5432) at the merged tree, each script builds and drops its own throwaway database:
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - `supabase/tests/wyn_030_appeal_system_test.sh` — **31/31 PASS**
  - `supabase/tests/wyn_031_chat_test.sh` — **29/29 PASS**
  - `supabase/tests/wyn_032_message_request_test.sh` — **30/30 PASS**
  - `supabase/tests/wyn_033_share_to_chat_test.sh` — **12/12 PASS**
  - `supabase/tests/wyn_034_redrop_test.sh` — **21/21 PASS** (new this round, run under the real `authenticated` role, not superuser)
  - **173/173 checks total across the 7 prior scripts, 194/194 including WYN-034's own** — no failures, the merge itself did not disturb anything QA had already verified.
- 4 of 5 GitHub PR status checks succeeded (4 Vercel deployments) before merging; the 5th (Netlify deploy preview) was still processing at merge time — a non-blocking preview status, matching the same precedent already established on WYN-030/031/032/033's PRs. Merged without waiting on it.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

24 files changed (3078 insertions, 74 deletions) merged into `main` via PR #141:

- **SQL** (`supabase/schema.sql`): new `redrops` table (`drop_id uuid` FK cascade to `drops`, `redropper_id uuid` FK to `profiles`, `quote_text text` nullable with a 1-500 character CHECK). A partial unique index (`redrops_standard_unique`, `where quote_text is null`) limits a user to one Standard ReDrop per Drop while leaving Quote ReDrop unlimited. 3 RLS policies as described above. `reports.target_type` and `notifications.type` CHECK constraints extended (via the established dynamic drop-and-recreate-constraint pattern) to accept `'redrop'`. `submit_report()` gained a `'redrop'` branch mirroring its `'club_post_comment'` branch. New `notify_redrop()` function + `redrops_notify` trigger (`after insert on redrops`), mirroring `notify_drop_like()`, notifies the original Drop's author on every ReDrop except a self-ReDrop. `home_feed` view redefined with a 3rd branch sourced from `redrops` joined to `drops`, with 6 new trailing columns (`redrop_count`, `redrop_id`, `redropper_id`, `redropper_username`, `redropper_display_name`, `redropper_avatar_url`, `quote_text`) appended after `comment_count` on all 3 branches so the `create or replace view` stays valid.
- **Flutter**: `Drop`/`HomeFeedItem` gained `redropCount`/`redroppedByMe` (`HomeFeedItem` additionally `redropId`/`redropper*`/`quoteText`), `toggledRedrop()`/`withExtraRedrop()`, and a new `HomeFeedItem.copyWith()` (replacing a fragile hand-rolled field-by-field rebuild in `HomeFeedScreen` that would have silently reset any field it forgot to repeat). `DropRepository`/`HomeRepository` gained `toggleRedrop()`/`quoteRedrop()`/`deleteRedrop()`/`fetchRedropsByUser()` and every existing fetch method now also resolves `redroppedByMe`. `HomeRepository.fetchFollowingFeed()` switched from `.inFilter('author_id', ...)` to `.or('author_id.in.(...),redropper_id.in.(...)')` so a followed user's ReDrop of someone else's Drop actually appears in the "ติดตาม" tab. New `app/lib/features/drop/presentation/quote_redrop_screen.dart` (`QuoteRedropScreen`) and `app/lib/features/profile/presentation/widgets/profile_redrops_tab.dart` (`ProfileRedropsTab`). `HomeDropCard` gained the 🔄 button + action sheet, the ReDrop feed-card label, and a "ลบ ReDrop" entry in its More menu (shown whenever the card is the viewer's own ReDrop, independent of whether they also authored the underlying Drop). `ViewProfileScreen`'s `TabBar` gained a "ReDrops" tab between Drop and Pop, requiring a new optional `HomeRepository` param (same optional-and-defaulted pattern as its existing `ChatRepository`/`ReportRepository` params).
- **New persisted regression test**: `supabase/tests/wyn_034_redrop_test.sh` (21 checks, added to the same `supabase/tests/` suite as `wyn_021` through `wyn_033`).
- **Tests**: `app/test/quote_redrop_screen_test.dart` (new, 4 cases), plus additions to `app/test/drop_test.dart` (6 cases: `toggledRedrop`/`withExtraRedrop`/`fromMap`), `app/test/home_feed_item_test.dart` (4 cases: `fromMap`/`copyWith`), `app/test/home_feed_screen_test.dart` (5 cases: the new "ReDrop action sheet" group), `app/test/view_profile_screen_test.dart` (1 new ReDrops-tab case, plus 2 existing tab-count assertions updated to the new count).

Full history: `.wyn/tasks/approved/WYN-034-redrop.md`.

## Deployment Result

**Merged to `main` via PR #141, pushed successfully.** This is the first task of **Phase 3 (Drop Enhancement)** to land on `main`, following Phase 2 (WYN Chat)'s completion. Users can ReDrop (Standard or Quote) any Drop into their own feed, with the original Drop's engagement, ranking eligibility, and privacy protections carried through automatically rather than reimplemented.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-033-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-second+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-034-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: `git revert` the merge commit on `main` restores the pre-merge state (a real merge commit with two parents). Reverting would remove ReDrop entirely — the 🔄 button, `QuoteRedropScreen`, and the "ReDrops" Profile tab would disappear, and `ViewProfileScreen`'s `TabBar` would need its pre-WYN-034 tab count restored if not simply reverting cleanly — leaves WYN-026 through WYN-033 untouched, since those are separate, earlier merges.
- **Database**: `supabase/schema.sql` grew by the `redrops` table, its RLS policies and indexes, the `notify_redrop()` trigger, the `home_feed` view's 3rd branch, and the `reports`/`notifications`/`submit_report()` extensions. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-034-specific manual step is needed beyond those.

With WYN-034 merged, **Phase 3 (Drop Enhancement)'s first task is code-complete**. Per the Roadmap, the remaining Phase 3 tasks are WYN-035 (Poll in Drop), WYN-036 (Draft system), WYN-037 (Edit/Delete Drop), WYN-038 (View counting system), and WYN-039 (Private Account + Follow Request) — none started yet; the Founder has not yet been asked to confirm continuing further into Phase 3.
