# Deployment Log — WYN-035 (Poll ใน Drop)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-035 went through Product spec, Design spec, Coding, and a full independent QA cycle all in this same session (Coding then a distinct, adversarial QA pass over the finished work), continuing the same session-pattern WYN-034 established for Phase 3:

- **Product/Design**: Master Spec sections 1/2 list Poll as one of the content types a Drop must support ("สร้าง Drop รองรับ: Text, รูปภาพสูงสุด 9 รูป, Caption, Hashtag, Mention, Link, Poll, Location"), with no further detail — Product filled in the mechanics itself (2-4 options, 1/3/7-day fixed voting windows, single-select, vote-changeable, Poll and image mutually exclusive this round to avoid touching the not-yet-built multi-image system) and made one privacy-first architectural call: **votes are anonymous — no one, not even the poll's own author, can see who voted for what**, only aggregate counts. This is stricter than Instagram Stories polls (author sees voter identities) but matches Twitter polls and directly serves the WYN Mission's "ให้ความสำคัญกับความปลอดภัย/ความเป็นส่วนตัวมากกว่าแพลตฟอร์มเดิม" — decided by Product under the authority RULES.md already grants (not a Security Architecture change requiring Founder approval).
- **Coding**: `drops.image_url` became nullable — no cross-table CHECK enforces "image or poll" (Postgres CHECK can't reference other tables), so `create_poll_drop()` (a new SECURITY DEFINER RPC mirroring `create_orders()`'s atomic-multi-insert shape) is the only path that can ever produce a null-image `drops` row, guaranteeing the invariant by construction rather than by constraint. Two new tables (`drop_polls`, `drop_poll_votes`) plus a `validate_poll_vote()` trigger enforce every vote-time rule (not the poll's own author, not posting-blocked, not blocked-either-way with the author, not after `expires_at`, option index in range) that RLS `using`/`with check` can't express alone. Aggregate results come from a second RPC, `get_poll_results()`, which computes across every voter's row (bypassing `drop_poll_votes`' own SELECT policy via SECURITY DEFINER) but only reveals non-null counts once its own visibility rule (voted, or the author, or the poll has closed) is satisfied — enforced once, at the database layer, not left for each UI call site to reimplement or forget. `home_feed`/`saved_feed` gained 3 trailing columns (`poll_id`/`poll_options`/`poll_expires_at`) on every branch; `notifications`/`reports` were untouched entirely (Product decided against a vote notification, to avoid spamming a poll author if it goes viral, and against a separate report target, since reporting the underlying Drop already covers a poll's content). Flutter added `PollCard` (voting/results display, shared verbatim between `HomeDropCard` and `DropDetailScreen`) and `PollPlaceholderTile` (the square fallback for every spot that used to assume a Drop always has an image — grid tiles, the Quote ReDrop preview, the Trending row), a Poll composer toggle in `CreateDropScreen`, and poll-state batch-fetch helpers (`_fetchPollStates`, mirroring the existing `_fetchLikedDropIds`/`_fetchRedroppedDropIds` "one query per page, not one per card" shape) wired into all 6 `DropRepository` fetch methods and all 5 `HomeRepository` fetch methods. Found and fixed 1 real bug while writing the SQL regression script (disclosed per this project's standing practice): `get_poll_results()`'s `RETURNS TABLE` column named `poll_id` shadowed `drop_poll_votes.poll_id` inside the function's own subqueries, causing a genuine "column reference is ambiguous" error the first time it ran against real Postgres — fixed by aliasing every table reference inside the function.
- **Independent QA — PASS (single round, 2 gaps found and fixed before approval)**: read the full `schema.sql` diff directly, ran `flutter analyze` (clean) and `flutter test` (553/553) independently, re-ran all 9 SQL regression scripts independently (196/196). Grepped the whole app for non-null-safe `.imageUrl` usages itself rather than trusting Coding's own sweep, and independently verified all 3 `HomeDropCard` call sites (`home_feed_screen.dart`/`profile_redrops_tab.dart`/`hashtag_feed_screen.dart`) wired `onVotePoll`. Reasoned through the privacy design adversarially — confirmed that even a raw `GROUP BY`/aggregate PostgREST query against `drop_poll_votes` can never leak another voter's choice, because Postgres RLS filters rows before aggregation runs, not after — this is a structural guarantee, not just "the RPC is the only exposed path." Found 2 gaps: (1) Coding's own regression script proved a Restricted user can't *vote*, but never proved one can't *create* a Poll Drop in the first place, despite the RPC already containing that check — added a new live-database check (CHECK23) that passed immediately (the code was already correct, only the proof was missing); (2) `valid_poll_options()` validated option length against the *trimmed* string but the RPC inserted the *untrimmed* value, so a direct RPC call bypassing the Flutter client's own `.trim()` could leave stray whitespace in stored option text — not a security hole, but cheap to fix, so fixed immediately (trim server-side before validating/inserting) rather than left as an accepted Minor. Re-ran all 9 SQL scripts after both fixes — still 196/196.

Full history: `.wyn/tasks/approved/WYN-035-poll-in-drop.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/docs/design/wyn-035-poll-in-drop.md`, `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified in this session, using a freshly cloned Flutter 3.47.1 (stable) and a local Postgres 16 server:

- `flutter pub get`: clean (packages have newer versions available, none blocking — same as every prior deployment log)
- `flutter analyze`: **0 issues**
- `flutter test`: **553/553 pass** (527 baseline + 26 new for this task)
- SQL regression scripts, each against a fresh throwaway Postgres 16 database under the real `authenticated` role (not superuser):
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - `supabase/tests/wyn_030_appeal_system_test.sh` — **31/31 PASS**
  - `supabase/tests/wyn_031_chat_test.sh` — **29/29 PASS**
  - `supabase/tests/wyn_032_message_request_test.sh` — **30/30 PASS**
  - `supabase/tests/wyn_033_share_to_chat_test.sh` — **12/12 PASS**
  - `supabase/tests/wyn_034_redrop_test.sh` — **21/21 PASS**
  - `supabase/tests/wyn_035_poll_in_drop_test.sh` — **23/23 PASS** (new this round, includes the QA-added CHECK23)
  - **173/173 checks total across the 8 prior scripts, 196/196 including WYN-035's own** — no failures.
- Merge method: **merge commit** via GitHub (`claude/phase-3-wyn-035-5y4yfj` → `main`, PR #143). `origin/main` was confirmed an ancestor of the feature branch before opening the PR. Post-merge, `git diff` between the pre-merge feature-branch commit and the resulting `main` HEAD across every changed source path (`supabase/schema.sql`, `app/lib`, `app/test`) is **empty** — the merge was a clean fast-forward-equivalent with no conflict resolution, so the build/test numbers above already describe exactly what landed on `main`; a second re-run against a checked-out `main` would exercise byte-identical code.
- 4 of 5 GitHub PR status checks succeeded (4 Vercel deployments) before merging; the 5th (Netlify deploy preview) was still processing at merge time — a non-blocking preview status, matching the same precedent already established on WYN-030 through WYN-034's PRs. Merged without waiting on it.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

27 files changed (3014 insertions, 36 deletions) merged into `main` via PR #143:

- **SQL** (`supabase/schema.sql`): `drops.image_url` dropped its `not null` constraint. New `valid_poll_options()` IMMUTABLE function (structural validation: 2-4 options, each 1-80 chars after trim, no case-insensitive duplicates) backs a CHECK constraint on the new `drop_polls` table (`id`, `drop_id uuid unique` FK cascade to `drops`, `options text[]`, `expires_at`). New `drop_poll_votes` table (`poll_id` FK cascade, `voter_id`, `option_index`, unique `(poll_id, voter_id)`) with a SELECT policy restricted to `auth.uid() = voter_id` only — no one else's vote row is ever readable, including via a raw client-side aggregate query, since RLS filters before aggregation. New `validate_poll_vote()` trigger (`before insert or update`) enforces every business rule RLS syntax can't: not expired, option index in range, not the poll's own author, not posting-blocked, not blocked-either-way with the author. New RPC `create_poll_drop()` (SECURITY DEFINER) atomically inserts `drops`(image_url=null)+`drop_polls`+`drop_mentions`, re-validating options/duration/posting-block status server-side regardless of what the client already checked, and trims the question/options server-side before storing them. New RPC `get_poll_results(poll_ids uuid[])` (SECURITY DEFINER, batched) returns per-poll `(visible, total_votes, option_counts[])`, enforcing the "voted, author, or closed" visibility rule at the database layer. `home_feed`/`saved_feed` views redefined with 3 new trailing columns (`poll_id`/`poll_options`/`poll_expires_at`) on every branch.
- **Flutter**: `Drop`/`HomeFeedItem` gained nullable poll fields (`pollId`/`pollOptions`/`pollExpiresAt`/`pollMyVoteIndex`/`pollTotalVotes`/`pollOptionCounts`) and a `votedPoll()` optimistic-update method; `imageUrl` became nullable on both. `DropRepository`/`HomeRepository` gained `createPollDrop()`/`votePoll()` and a batched `_fetchPollStates()` helper wired into every existing fetch method. New `app/lib/features/drop/presentation/widgets/poll_card.dart` (`PollCard`) and `poll_placeholder_tile.dart` (`PollPlaceholderTile`). `CreateDropScreen` gained an image/poll `SegmentedButton` mode toggle and a Poll composer (add/remove options 2-4, pick a 1/3/7-day duration) — the existing caption field doubles as the poll's question. Every spot that previously assumed a Drop always has an image (`HomeDropCard`, `DropDetailScreen`, `DropGridTile`, `SavedGridTile`, `QuoteRedropScreen`'s preview, `TrendingTile`) now branches on `imageUrl == null` to render the Poll or placeholder instead.
- **New persisted regression test**: `supabase/tests/wyn_035_poll_in_drop_test.sh` (23 checks, added to the same `supabase/tests/` suite as `wyn_021` through `wyn_034`).
- **Tests**: `app/test/poll_card_test.dart` (new, 6 cases), plus additions to `app/test/drop_test.dart` (9 cases: `votedPoll`/`fromMap` poll parsing), `app/test/home_feed_item_test.dart` (4 cases), `app/test/create_drop_screen_test.dart` (6 cases: the new "Poll composer" group), `app/test/drop_detail_screen_test.dart` (2 cases), `app/test/home_feed_screen_test.dart` (3 cases: the new "Poll voting" group), and `app/test/support/recording_drop_repository.dart` (fake `createPollDrop`/`votePoll` overrides).

Full history: `.wyn/tasks/approved/WYN-035-poll-in-drop.md`.

## Deployment Result

**Merged to `main` via PR #143, pushed successfully.** This is the second task of **Phase 3 (Drop Enhancement)** to land on `main`, following WYN-034 (ReDrop). Users can create a Poll Drop (question + 2-4 options, a 1/3/7-day voting window) as an alternative to an image, vote once and change their mind until it closes, and see results as soon as they vote, once the poll closes, or immediately if they're the author — with every other voter's individual choice staying genuinely unreadable, enforced at the database layer rather than merely hidden by the UI.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-034-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-third+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-035-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: `git revert` the merge commit on `main` restores the pre-merge state (a real merge commit with two parents). Reverting would remove Poll entirely — the composer toggle, `PollCard`, and every `PollPlaceholderTile` fallback would disappear, and `Drop.imageUrl`/`HomeFeedItem.imageUrl` would need to go back to non-nullable if reverted cleanly — leaves WYN-021 through WYN-034 untouched, since those are separate, earlier merges.
- **Database**: `supabase/schema.sql` grew by the `drop_polls`/`drop_poll_votes` tables, their RLS policies/indexes/trigger, the 2 new RPCs, the `home_feed`/`saved_feed` view branches, and `drops.image_url`'s relaxed constraint. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse. Note for whenever a real database exists: reverting `image_url`'s nullability would first require deciding what to do with any Poll Drop rows already created (they have no image) — not a concern today since nothing has ever been deployed to a live database.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-035-specific manual step is needed beyond those.

With WYN-035 merged, **Phase 3 (Drop Enhancement)'s second task is code-complete**. Per the Roadmap, the remaining Phase 3 tasks are WYN-036 (Draft system), WYN-037 (Edit/Delete Drop), WYN-038 (View counting system), and WYN-039 (Private Account + Follow Request) — none started yet; the Founder has not yet been asked to confirm continuing further into Phase 3.
