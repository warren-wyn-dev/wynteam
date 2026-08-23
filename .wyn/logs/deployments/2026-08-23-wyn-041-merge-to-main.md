# Deployment Log — WYN-041 (Trending Engine v2) merged to `main`

```
Release: WYN-041 -- Trending Engine v2 (view count wiring + anti-manipulation moderation exclusion)
Version: N/A (no versioned build yet -- code-integration merge only, see Readiness Gate below)
QA Status: PASS (Independent QA, 2026-08-23 -- full report in .wyn/tasks/approved/WYN-041-trending-engine-v2.md, "Independent QA" section)
Build Status:
  - supabase/tests/wyn_041_trending_engine_test.sh: 9/9 PASS (run independently against a local PostgreSQL 16, not reusing Coding's numbers)
  - All 15 SQL regression scripts (wyn_021 through wyn_041): PASS, no cross-task regression
  - check_schema_ordering.py: clean, no forward references
  - Adversarial probes beyond the committed test script: empty/null array input to authors_posting_blocked(), a batch mixing a nonexistent uuid with real ids, duplicate-id input, and a direct confirmation that an ordinary (non-moderator) authenticated user gets 0 rows from a raw moderation_actions select -- all behaved correctly
  - flutter analyze: 0 issues (Flutter stable SDK)
  - flutter test: 651/651 pass (644 baseline + 7 new)
  - GitHub PR #155 status checks: Vercel previews failed with "Deployment rate limited -- retry in 24 hours" (the same free-tier build-minute quota condition already documented in the WYN-030/WYN-040 deployment logs) -- an infra/quota condition unrelated to this diff, not a code or test failure. Netlify preview was still processing at merge time.
Deployment Target: `main` branch on GitHub only (warren-wyn-dev/wynteam) -- a code-integration step, not a deploy to any live/production/user-facing environment. See Readiness Gate below for why a real production deploy is still not possible.
Changes: PR #155 (`claude/wyn-40-continuation-ul5ngq` -> `main`, merge commit `4dc57ff`, fast-forward-clean merge, no conflicts):
  - Flutter: new `engagementScore(HomeFeedItem item)` in `home_ranking.dart` -- a single source of truth for the "how much engagement has this item gotten" formula, replacing two independently-inlined versions that had drifted apart (rankingScore's 2:3 like:comment weights vs fetchTrending's 1:1). Adds a Drop-only view-count term (`_viewWeight = 0.1`, a Product-chosen placeholder pending real traffic data) via an early return that excludes Pop entirely -- Pop's view counter (`increment_pop_view_count()`, WYN-006) has no unique-viewer dedup/rate-limit/self-view-exclusion, unlike Drop's (`drop_view_count()`, WYN-038), so folding it into an "anti-manipulation" formula would hand back exactly the gaming vector this task exists to close.
  - `rankingScore()` (WYN-018) and `fetchTrending()` (WYN-017) both now call `engagementScore()` instead of their own inlined formulas.
  - New `_fetchPostingBlockedAuthorIds()` helper in `home_repository.dart` (mirrors the existing `_fetchFollowedAuthorIds()` pattern), called before the sort/take step in both `fetchTrending()` and `fetchRankedFeed()` to remove candidates whose author currently has an active restrict/suspend/ban. Their content remains fully reachable through every other path (`fetchFeed()`, `fetchFollowingFeed()`, Search, own profile) -- neither of those methods nor any RLS policy/view was touched.
  - SQL (`supabase/schema.sql`): new `public.authors_posting_blocked(p_author_ids uuid[])` (SECURITY DEFINER, `stable`) wraps `internal.is_posting_blocked()` (WYN-029/030) as a batched, anti-gaming RPC -- returns only the excluded `author_id`s, never the action_type/reason/reviewer_id/expires_at behind them.
  - New `supabase/tests/wyn_041_trending_engine_test.sh` (9 checks) added to the persisted regression suite.
Deployment Result: Merged to `main` via PR #155, pushed successfully. `origin/main` now at commit `4dc57ff`, verified matching local `main` after fetch. `main` previously sat at `dd106a0` (the WYN-040 deployment-log entry); this merge continues Phase 4 (Discovery & Trending Engine) on `main`.
Production Verification: Not applicable -- no production environment exists. Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-13-wyn-002-readiness.md`, `.wyn/logs/deployments/2026-08-23-wyn-040-merge-to-main.md`) -- re-verified directly in this session, not assumed:
  - No real Supabase project -- `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
  - No native OAuth/Firebase config -- no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
  - No distribution channel (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
  - No CI pipeline -- `.github/workflows/` does not exist.
  - No Android SDK/Xcode in this sandbox -- `flutter build apk`/`flutter build ipa` cannot be attempted here.
  This is now the twentieth+ approved batch in this project's history to reach this exact same gate -- all "approved, merged to `main`, waiting for real infra." Not a WYN-041-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.
Rollback Plan:
  - Code: `git revert` the merge commit `4dc57ff` on `main` restores the pre-merge state. Reverting removes the view-count/anti-manipulation wiring entirely (both ranking formulas revert to their pre-WYN-041 shape and the new RPC disappears) but leaves WYN-005 through WYN-040 untouched, since those are separate, earlier merges. No other repository or screen depends on `engagementScore()`/`authors_posting_blocked()`, so a revert is fully self-contained.
  - Database: `supabase/schema.sql` grew by exactly one new function (`authors_posting_blocked`) and its `grant execute` statement -- no new tables, no column additions, no altered RLS policy on any existing table. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" -- no live migration to reverse.
  - Distribution: not applicable -- nothing has been distributed to any real device/store.
```

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from the WYN-040 deployment log's Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-041-specific manual step is needed beyond those.

With WYN-041 merged, the second task of **Phase 4 (Discovery & Trending Engine)** is code-complete. The only remaining task in Phase 4 per the roadmap is **WYN-042** (WYN Top 100). Product's WYN-041 spec also flagged a separate, not-yet-scheduled follow-up worth Founder consideration: **"Pop View Counting Hardening"** — retrofitting Pop's view counter with the same unique-viewer dedup/rate-limit/self-view-exclusion Drop already has (WYN-038), which would let a future task safely include Pop's view count in the same anti-manipulation-safe ranking formula this task built for Drop.
