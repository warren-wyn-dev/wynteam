# Deployment Log — WYN-032 (Message Request flow)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-032 went through Product spec, Design spec, Coding, and a full independent QA cycle all in this same session (Coding then a distinct, adversarial QA pass over the finished work):

- **Product/Design**: Master Spec section 18's terse "Message Request: คนที่ไม่รู้จักส่งข้อความ → Accept/Delete/Block/Report" was fleshed out into a full spec — "unknown" defined as a one-directional check (the recipient doesn't already follow the sender), evaluated once at conversation-creation time only, mirroring how most DM apps gate first contact. Design reused `ConversationScreen`'s existing composer-area-state pattern (already used for Blocked/Restricted/Suspended in WYN-031) for the pending-recipient view rather than building a new screen, keeping the change's blast radius small.
- **Coding**: 1 new column (`conversations.requested_by`), 2 new RPCs (`accept_message_request()`/`delete_message_request()`), 1 new view (`message_requests`), and edits to `get_or_create_conversation()`/the `messages` INSERT policy/the `chat_inbox` view to implement the gate. 1 new Flutter screen (`MessageRequestListScreen`), a banner entry point on `ChatInboxScreen`, a 4th composer-area state on `ConversationScreen`, and a new `message_request` notification type.
- **Independent QA — PASS (single round, one real gap found and fixed)**: reviewed the full `schema.sql` diff directly, ran `flutter analyze` (clean) and `flutter test` (499/499) independently. **Found a real security-relevant gap**: the `messages` INSERT policy was updated to let the requester keep sending while their request was still pending, but the `chat-media` storage bucket's own INSERT policy was not updated to match — it still hard-required `status = 'active'`. Since an image message uploads to storage *before* its `messages` row is inserted, this meant a requester's image (not text) message would have silently failed during the pending phase, violating the Product spec's "ส่ง Text/Image ได้" requirement. Fixed by mirroring the exact same active-or-own-pending condition in both policies, with 2 new regression checks proving both directions (requester can upload while pending, recipient still can't). Also independently verified a genuine regression the Coding session had already found and fixed: `wyn_031_chat_test.sh`'s fixtures never seeded a `follows` relationship, so conversations that used to start `active` under WYN-031's original gate-free behavior started `pending` under this new gate — confirmed the fix (seeding mutual follows for the pairs that script expects to stay active) was a legitimate fixture update, not a coverage reduction.

Full history: `.wyn/tasks/approved/WYN-032-message-request.md` (Product/Design/Coding Output/Independent QA sections), `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified at `main` HEAD post-merge, using Flutter (stable) from `/home/user/flutter`:

- `flutter pub get`: clean (21 packages have newer versions available, none blocking)
- `flutter analyze`: **0 issues**
- `flutter test`: **499/499 pass**
- Merge method: **merge commit** via GitHub (`claude/wyn-032-message-request` → `main`, PR #137). `origin/main` was confirmed an ancestor of the feature branch before opening the PR (no divergence, no pre-merge conflict resolution needed this round).
- SQL regression scripts re-run against a fresh local Postgres 16 (cluster `16/main`, port 5432) at the merged tree, each script builds and drops its own throwaway database:
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - `supabase/tests/wyn_030_appeal_system_test.sh` — **31/31 PASS**
  - `supabase/tests/wyn_031_chat_test.sh` — **29/29 PASS** (fixtures updated this round to seed `follows`, per the regression noted above)
  - `supabase/tests/wyn_032_message_request_test.sh` — **30/30 PASS** (new this round, run under the real `authenticated` role, not superuser)
  - **140/140 checks total** — no failures, the merge itself did not disturb anything QA had already verified.
- 3 of 5 GitHub PR status checks succeeded (2 Vercel deployments + the Netlify deploy preview); the other 2 (`Vercel – wynteam-z3rr`/`wynteam-cesp`) reported "Deployment rate limited — retry in 24 hours" — a Vercel free-tier build-minute quota message, not a code or test failure, matching the exact same infra-quota condition already seen and merged past on WYN-030's PR #133 and WYN-031's PR #136. Merged without waiting.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

24 files changed (2248 insertions, 20 deletions) merged into `main` via PR #137:

- **SQL** (`supabase/schema.sql`): `conversations` gains `requested_by uuid` (nullable, FK to `profiles`) plus a new `conversations_requested_by_is_participant` CHECK constraint. `get_or_create_conversation()` now checks, only when creating a brand-new row, whether the recipient already follows the sender (`active`, `requested_by = null`) or not (`pending`, `requested_by = sender`, plus a `message_request` notification) — race-condition-safe via `on conflict do nothing returning id` with a fallback select. The `messages` INSERT policy now allows a send when `status = 'active'` OR (`status = 'pending'` AND the sender is `requested_by`) — the recipient has no INSERT path at all until they accept. The `chat-media` storage bucket's INSERT policy was updated to the identical condition (the QA-caught gap, see above). New `accept_message_request()`/`delete_message_request()` RPCs, both guarding against the requester calling them on their own request and against any non-participant calling them at all; `delete_message_request()` hard-deletes the conversation (cascading to its messages via the existing FK). New `message_requests` view (recipient-only, excludes blocked-either-way pairs). `chat_inbox` view gains a `requested_by` column and now only shows a pending conversation to its requester. `notifications` gains a `conversation_id` column (cascades on delete — a declined request's notification disappears with it) and the `message_request` type.
- **Flutter**: new `app/lib/features/chat/data/message_request.dart` (`MessageRequest` model) and `app/lib/features/chat/presentation/message_request_list_screen.dart`. `Conversation` gains `requestedBy`. `ChatRepository` gains `fetchMessageRequests()`/`countPendingMessageRequests()`/`acceptMessageRequest()`/`deleteMessageRequest()`/`fetchConversationMeta()` (the last fetched fresh on every `ConversationScreen` open, never trusted from a possibly-stale list-row prop). `ChatInboxScreen` gains a banner (hidden when there are no pending requests) linking to `MessageRequestListScreen`. `ConversationScreen` gains a 4th composer-area state (after Blocked/Restricted/Suspended in priority order): the pending request's recipient sees Accept/Delete/Block/Report instead of a composer, while the requester keeps a normal composer with a small "รอการตอบรับ" label. `NotificationType`/`WynNotification` gain `messageRequest`/`conversationId`; `NotificationListScreen` opens `ConversationScreen` directly on tap. `RootShell`/`HomeFeedScreen` badge counts now sum unread conversations and pending requests together.
- **New persisted regression test**: `supabase/tests/wyn_032_message_request_test.sh` (30 checks, added to the same `supabase/tests/` suite as `wyn_021`/`wyn_027`/`wyn_029`/`wyn_030`/`wyn_031`).
- **Updated existing regression test**: `supabase/tests/wyn_031_chat_test.sh`'s fixtures now seed mutual `follows` for the pairs it expects to start `active`, per the regression noted above.
- **Tests**: `app/test/message_request_list_screen_test.dart` (new, 4 cases), plus additions to `app/test/chat_model_test.dart` (4 cases: `MessageRequest.fromMap`, `Conversation.requestedBy`), `app/test/chat_inbox_screen_test.dart` (2 cases: banner visibility/navigation), `app/test/conversation_screen_test.dart` (6 cases: the new pending-recipient/pending-requester states), `app/test/notification_list_screen_test.dart` (2 cases: `message_request` message + tap navigation).

Full history: `.wyn/tasks/approved/WYN-032-message-request.md`.

## Deployment Result

**Merged to `main` via PR #137, pushed successfully.** This is the second task of **Phase 2 (WYN Chat)** to land on `main`, following WYN-031 (1:1 Chat)'s completion. `main` now closes the spam/harassment gap WYN-031 explicitly deferred to this task — a first-time message from someone the recipient doesn't already follow no longer reaches their main inbox unfiltered.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-23-wyn-031-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **twentieth+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-032-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

## Rollback Plan

- **Code**: `git revert` the merge commit on `main` restores the pre-merge state (a real merge commit with two parents). Reverting would remove the Message Request gate entirely, reopening WYN-031's original accepted risk (any user can message any other user with zero gate) until re-applied — leaves WYN-026 through WYN-031 untouched, since those are separate, earlier merges.
- **Database**: `supabase/schema.sql` grew by `conversations.requested_by`, `notifications.conversation_id`, `accept_message_request()`/`delete_message_request()`, the `message_requests` view, and edits to `get_or_create_conversation()`/2 RLS policies/the `chat_inbox` view. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-032-specific manual step is needed beyond those.

With WYN-032 merged, **Phase 2 (WYN Chat)'s first two tasks are code-complete**. Per the Roadmap, the next step is **WYN-033 (Share เข้า Chat — Drop/Profile/Club)**, the last task of Phase 2, which now has a fully-gated `conversations`/`messages` layer to build on.
