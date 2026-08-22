# Deployment Log — WYN-024 (Bottom Nav V1.0.0 Restructure) + DS-009 (Rainbow Accent)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-22

## QA Status

**PASS** (QA round 5, 2026-08-22) — independently re-verified, not just Coding's own numbers:
- `flutter analyze`: 0 issues
- `flutter test`: 365/365 pass
- Both approved tasks: `.wyn/tasks/approved/WYN-024-bottom-nav-v1-restructure.md`, `.wyn/tasks/approved/DS-009-v1-rebrand-color-comparison.md`, `.wyn/tasks/approved/WYN-024-segmented-feed-mode-scrollable.md`
- Both bug reports for this saga closed: `.wyn/tasks/bugs/WYN-024-active-segment-label-truncation.md`, `.wyn/tasks/bugs/WYN-024-segmented-button-active-label-illegible-all-segments.md`

## Build Status

Re-verified independently at `main` HEAD (post-merge, not just the feature branch) before and after merge:
- `flutter analyze`: 0 issues
- `flutter test`: 365/365 pass
- Fast-forward merge (`claude/remaining-items-r10hl0` → `main`, no conflicts, `main` had not moved since branching)

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

27 files changed (2549 insertions, 1009 deletions) across the full WYN-024/DS-009 saga:
- **Bottom Nav V1.0.0 restructure** (`root_shell.dart`): 5 destinations → Home/Search/Drop(action)/Notifications/Profile, removed Pop/ZOKY tabs
- **Home feed absorbs Drop feed**: `drop_feed_screen.dart` deleted, "ติดตาม" (Following) mode added to Home's `SegmentedButton`, `HomeRepository.fetchFollowingFeed` added
- **DS-009 Rainbow accent**: `WynColors.rainbowAccent` gradient added (both `app/` and `seller_app/`), used on Trending tile ring + active feed-mode indicator strip
- **SegmentedButton scrollable-width fix**: closes a label-truncation bug that took 5 QA rounds + 3 Debug rounds + 1 Design decision to fully resolve — `SegmentedButton` now wrapped in `SingleChildScrollView` + `IntrinsicWidth` instead of being stretched to the screen, guaranteeing no segment label is ever truncated again at any real phone width
- `SearchScreen` gets an `autofocus` param (default `false`) for its new Bottom Nav tab-root role

Full history: `.wyn/tasks/approved/WYN-024-bottom-nav-v1-restructure.md`, `.wyn/tasks/approved/DS-009-v1-rebrand-color-comparison.md`, `.wyn/tasks/approved/WYN-024-segmented-feed-mode-scrollable.md`

## Deployment Result

**Merged to `main`, pushed successfully.** `origin/main` now at commit `dc614d7`, verified matching local `main` after push (`git fetch` + `git log` confirmed).

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last assessment, `.wyn/logs/deployments/2026-08-13-wyn-002-readiness.md`):
- No real Supabase project — `app/lib/core/env.dart` reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `--dart-define`, currently unset anywhere in the repo (correctly — never hardcode real credentials)
- No native OAuth/Firebase config (`Firebase.initializeApp()` in `main.dart` is wrapped in a silent try/catch specifically because there's no real `google-services.json`/`GoogleService-Info.plist` yet — see WYN-016)
- No distribution channel (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up
- This session's environment has a working Flutter SDK (enables `flutter analyze`/`flutter test`, confirmed this session) but no Android SDK/Xcode for a real `flutter build apk`/`flutter build ipa`

This is the **fifteenth+ approved task** in this project's history to reach this exact same gate (WYN-005/006/007/008/009/012/013/014/015/019-022/ZOKY-001-004/SELLER-001+/WYN-024/DS-009 — all "approved, waiting for real infra"). None of this has ever been a WYN-024/DS-009-specific blocker; it is a whole-project blocker that needs Founder action.

## Rollback Plan

- **Code**: `git revert dc614d7..3df4e47` on `main` (or revert the individual merge commit range) restores the pre-merge state exactly — no destructive history rewrite needed since this was a fast-forward, not a squash/rebase
- **Database**: no schema changes in this release (WYN-024/DS-009 are pure Flutter/Dart client changes — `HomeRepository.fetchFollowingFeed` reuses the existing `home_feed` view and `follows` table from prior approved work, no new tables/columns/RLS policies)
- **Distribution**: not applicable — nothing has been distributed to any real device/store

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

To make an actual production deploy possible for WYN-024/DS-009 (and everything already queued behind this same gate):
1. Create a real Supabase project, run `supabase/schema.sql` against it
2. Set up native OAuth Client ID (Google) + Apple Developer account (Apple Sign-In capability)
3. Add real `google-services.json`/`GoogleService-Info.plist` (unblocks WYN-016 Push Notifications too)
4. Choose and configure a distribution channel (TestFlight / Play Internal Testing / Firebase App Distribution)
5. Provide an environment with Android SDK/Xcode for real `flutter build` release artifacts, or a CI pipeline that has them

AI Deploy & DevOps can execute steps 2-5's technical configuration once step 1's account/project exists; step 1 itself requires Founder action (real account, billing).
