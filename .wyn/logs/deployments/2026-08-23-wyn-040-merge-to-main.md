# Deployment Log — WYN-040 (Discovery Page) merged to `main`

```
Release: WYN-040 -- Discovery Page (Trending Now / Trending Hashtags / Rising / Suggested Users / Suggested Clubs)
Version: N/A (no versioned build yet -- code-integration merge only, see Readiness Gate below)
QA Status: PASS (Independent QA, 2026-08-23 -- full report in .wyn/tasks/approved/WYN-040-discovery-page.md, "Independent QA" section)
Build Status:
  - supabase/tests/wyn_040_discovery_test.sh: 17/17 PASS (run independently against a freshly installed local PostgreSQL 16, not reusing Coding's numbers)
  - All 14 SQL regression scripts (wyn_021 through wyn_040): PASS, no cross-task regression
  - check_schema_ordering.py: clean, no forward references
  - flutter analyze: 0 issues (freshly installed Flutter stable SDK)
  - flutter test: 644/644 pass
  - GitHub PR #153 status checks: 4/4 green (Vercel preview deployments -- wynteam, wynteam-z3rr, wynteam-ipe1, wynteam-cesp)
Deployment Target: `main` branch on GitHub only (warren-wyn-dev/wynteam) -- a code-integration step, not a deploy to any live/production/user-facing environment. See Readiness Gate below for why a real production deploy is still not possible.
Changes: PR #153 (`claude/wyn-40-continuation-ul5ngq` -> `main`, merge commit `28cf7b3`, fast-forward-clean merge, no conflicts):
  - SQL (`supabase/schema.sql`): 2 new SECURITY DEFINER RPCs -- `rising_profiles(p_limit, p_days, p_min_followers)` (ranks accounts by new-follower count within a window, excludes self/already-followed/blocked, filters by minimum total followers) and `suggested_users(p_limit)` (ranks by total follower count, excludes self/already-followed/blocked/muted). Both return only `profile_id` (single column) -- deliberately never the ranking signal itself, per the anti-gaming design decision.
  - New `supabase/tests/wyn_040_discovery_test.sh` (17 checks) added to the persisted regression suite.
  - Flutter: new `DiscoveryRepository` (`app/lib/features/search/data/discovery_repository.dart`), new `discovery_ranking.dart` (pure hashtag-frequency ranking, unit-testable without Supabase), new `DiscoveryView` widget (5 sections, reuses `TrendingTile`/`ClubMiniCard`/`HashtagFeedScreen`/`FollowListScreen` row layout as-is), new `FollowActionButton` widget (WYN-039's 3-state Follow button extracted for reuse -- `ViewProfileScreen` deliberately left untouched to avoid regression risk on an already-QA'd screen). `HomeRepository.fetchTrending()` gains an optional `limit` param (default unchanged, existing Home caller unaffected). `ProfileRepository.fetchProfilesByIds()` new (bulk id-ordered fetch). `SearchScreen` (WYN-009) now shows `DiscoveryView` instead of the User/Drop/Pop/Club TabBar when the query is empty/shorter than 2 characters -- zero behavior change at 2+ characters.
Deployment Result: Merged to `main` via PR #153, pushed successfully. `origin/main` now at commit `28cf7b3`, verified matching local `main` after fetch. `main` previously sat at `5a2dce6` (the WYN-039 deployment-log entry, closing Phase 3); this merge starts Phase 4 (Discovery & Trending Engine) on `main`.
Production Verification: Not applicable -- no production environment exists. Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-13-wyn-002-readiness.md`, `.wyn/logs/deployments/2026-08-23-wyn-039-merge-to-main.md`) -- re-verified directly in this session, not assumed:
  - No real Supabase project -- `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
  - No native OAuth/Firebase config -- no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
  - No distribution channel (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
  - No CI pipeline -- `.github/workflows/` does not exist.
  - No Android SDK/Xcode in this sandbox -- `flutter build apk`/`flutter build ipa` cannot be attempted here.
  This is now the nineteenth+ approved batch in this project's history to reach this exact same gate -- all "approved, merged to `main`, waiting for real infra." Not a WYN-040-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.
Rollback Plan:
  - Code: `git revert` the merge commit `28cf7b3` on `main` restores the pre-merge state. Reverting removes the Discovery page entirely (both new RPCs and all new Flutter files) but leaves WYN-005 through WYN-039 untouched, since those are separate, earlier merges. `SearchScreen`'s own diff is additive-only at the 2+ character path (zero behavior change there), so a revert cannot regress existing search behavior beyond removing Discovery itself.
  - Database: `supabase/schema.sql` grew by 2 new functions (`rising_profiles`/`suggested_users`) and their `grant execute` statements only -- no new tables, no column additions to any existing table, no altered RLS policy on any existing table. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" -- no live migration to reverse.
  - Distribution: not applicable -- nothing has been distributed to any real device/store.
```

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from the WYN-039 deployment log's Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-040-specific manual step is needed beyond those.

With WYN-040 merged, the first task of **Phase 4 (Discovery & Trending Engine)** is code-complete. Per the WYN-040 product spec's own scope notes, the two related follow-on tasks already identified on the roadmap are **WYN-041** (Trending Engine v2 / anti-manipulation scoring, building on WYN-018's ranking) and **WYN-042** (WYN Top 100) — neither is in scope of this task and both remain unstarted.
