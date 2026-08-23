# Deployment Log — WYN-033 (Share to Chat — Drop/Profile/Club)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-033 went through Product spec, Design spec, Coding, and a full independent QA cycle all in this same session (Coding then a distinct, adversarial QA pass over the finished work):

- **Product/Design**: Master Spec sections 8 and 18 called for sharing a Drop/Profile/Club directly into WYN Chat, not just via native share/copy-link. Scoped to the 3 content types the Master Spec names (no Club Post/Comment/Pop this round). Key design decision: `messages` gains 2 polymorphic columns (`shared_content_type`/`shared_content_id`, no FK) mirroring `reports.target_type`/`target_id` exactly — deliberately **not** denormalized into the row. The actual Drop/Profile/Club content is resolved client-side, at render time, through the same `DropRepository`/`ProfileRepository`/`ClubRepository` used everywhere else in the app, so each table's own existing RLS protects a shared reference automatically with no new privacy mechanism needed.
- **Coding**: SQL added the 2 columns, a CHECK on `shared_content_type`, extended `messages_not_blank_unless_deleted` to treat a non-null `shared_content_id` as satisfying "not blank," and updated `delete_message()`/`get_message_for_moderation()` to handle the new columns. Flutter added a `SharedContentType` enum, a new `ShareToChatScreen` (Screen 3 — existing conversations + search, single-tap-to-send, reusing WYN-032's `getOrCreateConversation()` gate unchanged for new recipients), a shared `share_sheet.dart` (2 options: Share to Chat / native share), entry points on Drop/Club's existing "แชร์" button and a new "แชร์โปรไฟล์" item on Profile's "..." menu, and a preview-card widget in `ConversationScreen` that lazily resolves and caches the shared content, opening the real `DropDetailScreen`/`ViewProfileScreen`/`ClubPage` on tap. Found and fixed 2 real bugs while writing tests (disclosed per this project's standing practice): (1) an `_isSending` guard that silently no-op'd `sendMessage()` when sharing to a newly-searched user — the entry method set the guard flag then called a shared method whose own first line re-checked that same flag, so it always returned early; fixed by splitting into 2 guard-owning entry points calling a guard-free core `_doSend()`. (2) A test-harness issue (`MaterialApp(home: ShareToChatScreen(...))` gives the screen no route for `Navigator.pop()` to return to) — fixed with the same push-from-a-placeholder-screen pattern already used in `conversation_screen_test.dart`.
- **Independent QA — PASS (single round)**: reviewed the full `schema.sql` diff directly, ran `flutter analyze` (clean) and `flutter test` (508/508) independently. **Specifically stress-tested the Design's central privacy claim** ("no new privacy mechanism needed") rather than taking it at face value: read all 3 referenced tables' SELECT policies directly and found the claim is only partially true — `drops`' SELECT policy does filter `is_blocked_either_way()`, but `clubs`' and `profiles`' SELECT policies are both `using (true)` with no block filtering at all. Investigated whether this was a gap opened by WYN-033 and confirmed it is not: both policies predate this task, and a blocked user's profile/club were already viewable through other existing paths (e.g. search) before this feature existed — so the "blocked users see a placeholder" acceptance criterion is correctly satisfied only for Drop, the one content type in the whole app where content visibility is block-gated. Went further than reading policies: built a separate throwaway database and manually proved, end to end, that after sharing a Drop and then blocking the recipient, the `messages` row survives (still 1 row visible) but a direct `SELECT` against `drops` under the same role returns 0 rows — confirming `DropRepository.fetchById()`'s `.maybeSingle()` call returns `null` (not an exception) in this case, so the client-side preview card degrades to a safe placeholder instead of crashing.

Full history: `.wyn/tasks/approved/WYN-033-share-to-chat.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified at `main` HEAD post-merge, using Flutter (stable) from `/home/user/flutter`:

- `flutter pub get`: clean (packages have newer versions available, none blocking)
- `flutter analyze`: **0 issues**
- `flutter test`: **508/508 pass**
- Merge method: **merge commit** via GitHub (`claude/wyn-033-share-to-chat` → `main`, PR #139). `origin/main` was confirmed an ancestor of the feature branch before opening the PR.
- SQL regression scripts re-run against a fresh local Postgres 16 (cluster `16/main`, port 5432) at the merged tree, each script builds and drops its own throwaway database:
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - `supabase/tests/wyn_030_appeal_system_test.sh` — **31/31 PASS**
  - `supabase/tests/wyn_031_chat_test.sh` — **29/29 PASS**
  - `supabase/tests/wyn_032_message_request_test.sh` — **30/30 PASS**
  - `supabase/tests/wyn_033_share_to_chat_test.sh` — **12/12 PASS** (new this round, run under the real `authenticated` role, not superuser)
  - **152/152 checks total** — no failures, the merge itself did not disturb anything QA had already verified.
- All 4 GitHub PR status checks succeeded (4 Vercel deployments, no quota rate-limiting this round). Merged immediately per the standing merge policy.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

20 files changed (1633 insertions, 27 deletions) merged into `main` via PR #139:

- **SQL** (`supabase/schema.sql`): `messages` gains `shared_content_type text` (CHECK'd to `'drop'`/`'profile'`/`'club'` or null) and `shared_content_id uuid` (no FK — polymorphic, mirrors `reports.target_type`/`target_id`). `messages_not_blank_unless_deleted` extended so a non-null `shared_content_id` alone satisfies "not blank." `delete_message()` now nulls both new columns alongside `text`/`image_url`. `get_message_for_moderation()`'s return-table shape changed (added the 2 new columns), requiring `drop function` before `create or replace` (same lesson as `get_my_moderation_status()` in WYN-030) — its moderator-only gate is otherwise unchanged.
- **Flutter**: new `app/lib/features/chat/data/shared_content_type.dart` (`SharedContentType` enum, mirrors `ReportTargetType`'s wire-value pattern). `ChatMessage`/`ChatRepository.sendMessage()` extended for the 2 new fields. New `app/lib/features/chat/presentation/share_to_chat_screen.dart` (`ShareToChatScreen`) and `share_sheet.dart` (`showShareSheet()`, 2 options). `DropDetailScreen`/`ClubPage`'s existing "แชร์" button now opens the share sheet instead of native share directly; `ViewProfileScreen`'s "..." menu gains "แชร์โปรไฟล์" as its first item. `ConversationScreen` gains `_resolveSharedContent()`/`_openSharedContent()` plus a per-conversation cache, a new `_SharedContentPreview` widget rendered inside message bubbles, and optional `ClubRepository`/`ClubPostRepository` constructor params (mirroring `DropDetailScreen`'s existing optional-repository pattern). `ModerationRepository._fetchMessageSummary()` gains a short label for shared-content-only messages in the moderation queue.
- **New persisted regression test**: `supabase/tests/wyn_033_share_to_chat_test.sh` (12 checks, added to the same `supabase/tests/` suite as `wyn_021`/`wyn_027`/`wyn_029`/`wyn_030`/`wyn_031`/`wyn_032`).
- **Tests**: `app/test/share_to_chat_screen_test.dart` (new, 7 cases), plus additions to `app/test/chat_model_test.dart` (2 cases: `ChatMessage.fromMap` shared-content parsing), and 1 expected-regression fix in `app/test/view_profile_mute_test.dart` (More-menu item order, now leading with "แชร์โปรไฟล์").

Full history: `.wyn/tasks/approved/WYN-033-share-to-chat.md`.

## Deployment Result

**Merged to `main` via PR #139, pushed successfully.** This is the third and final task of **Phase 2 (WYN Chat)** to land on `main`, following WYN-031 (1:1 Chat) and WYN-032 (Message Request flow). **Phase 2 is now fully code-complete.** Users can share a Drop, Profile, or Club directly into a chat conversation, with the shared content rendered as a tappable preview card and protected by each content type's own existing visibility rules — no separate privacy surface was added for this feature.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-032-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twenty-first+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-033-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: `git revert` the merge commit on `main` restores the pre-merge state (a real merge commit with two parents). Reverting would remove the Share to Chat feature entirely — the "แชร์" buttons on Drop/Club would need their pre-WYN-033 direct-native-share behavior manually restored if not simply reverting cleanly — leaves WYN-026 through WYN-032 untouched, since those are separate, earlier merges.
- **Database**: `supabase/schema.sql` grew by `messages.shared_content_type`/`messages.shared_content_id` and edits to `delete_message()`/`get_message_for_moderation()`/`messages_not_blank_unless_deleted`. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-033-specific manual step is needed beyond those.

With WYN-033 merged, **Phase 2 (WYN Chat) is fully code-complete** — all 3 tasks (WYN-031/032/033) are in `.wyn/tasks/approved/`. Per the Roadmap, the next phase is **Phase 3 (Drop Enhancement: ReDrop/Poll/Draft/Edit-Delete/View counting)** — not started; the Founder has not yet been asked to confirm starting it.
