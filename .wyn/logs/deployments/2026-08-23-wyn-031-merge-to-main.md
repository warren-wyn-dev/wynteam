# Deployment Log — WYN-031 (1:1 Chat)

Release: code-integration merge to `main` (not a production/end-user deploy — see Readiness Gate below)
Date: 2026-08-23

## QA Status

**PASS** — WYN-031 went through a full independent QA cycle in this same session (Coding then a distinct, adversarial QA pass over the finished work):

- **Coding**: implemented the entire feature from the existing Design spec (`.wyn/docs/design/wyn-031-chat-1to1.md`), the Founder having said to continue straight into Phase 2 once Phase 1 closed. 10 SQL changes (new `conversations`/`messages`/`conversation_mutes` tables + RLS, `get_or_create_conversation()`/`mark_conversation_read()`/`delete_message()` RPCs, a `prevent_cross_conversation_reply()` trigger, a new `get_message_for_moderation()` RPC not explicitly called out in the Design doc but required because a moderator is never a conversation participant and so has no ordinary RLS path to a reported message's content, a `chat-media` storage bucket, a `chat_inbox` view, `count_unread_conversations()`, and a `submit_report()` extension for `target_type = 'message'`) and 6 new/modified Flutter screens (`ChatRepository`, a Chat icon entry point on Home, `ChatInboxScreen`, `ConversationScreen`, a "ส่งข้อความ" entry point on other users' profiles, delete-confirm + mute/block/report menu). One layout bug surfaced and was fixed during Coding: the Design doc's proposed AppBar placement for the Chat icon pushed `HomeFeedScreen`'s already-tight header past overflow on the standard test viewport (measured 34px over, following an existing ~22px margin that predated this feature) — fixed with a zero-layout-cost `Stack` overlay instead of an `AppBar`, documented as a deviation in the Design doc.
- **Independent QA — PASS (single round, one real gap found and fixed)**: reviewed the full `schema.sql` diff directly, ran `flutter analyze` (clean) and `flutter test` independently. Wrote a new persisted regression script, `supabase/tests/wyn_031_chat_test.sh`, run under the real `authenticated` Postgres role (not superuser) per the RLS-verification convention this project settled on during WYN-030 — **29/29 checks pass**, covering `get_or_create_conversation()`'s self-chat/blocked-either-way rejection plus canonical-ordering and idempotency, RLS on `conversations`/`messages`/`conversation_mutes`/the `chat-media` bucket, a block created *after* a conversation already exists still cutting off further sends (not just a block-before-first-message case), a posting-blocked (Restricted) participant being unable to send despite being a real participant, the cross-conversation-reply trigger in both directions, `delete_message()`'s content-nulling and sender-only enforcement, the `conversations_canonical_order` check constraint catching a reversed-order row even from a direct table-owner insert, `submit_report()`'s new `message` branch (participant can report, sender can't report their own message, non-participant can't report), and `get_message_for_moderation()`'s moderator-only gate. Re-ran `wyn_021`/`wyn_027`/`wyn_029`/`wyn_030` — no cross-task regression. **Found one real acceptance-criteria gap while reading the code adversarially**: the Product spec required replies to be limited to 1 level ("reply ไปยัง reply อื่นทำไม่ได้"), but neither the DB trigger (which only checks same-conversation, not chain depth) nor the UI (the long-press menu offered "ตอบกลับ" on every message, including ones that were themselves replies) actually enforced it. Fixed immediately with a UI guard in `_showMessageMenu()` plus a new regression test, re-verified `flutter test` 481/481 clean afterward. Walked all 12 Acceptance Criteria individually against this evidence — all satisfied.

Full history: `.wyn/tasks/approved/WYN-031-chat-1to1.md` (Design/Coding Output/Independent QA sections), `.wyn/company/DECISIONS.md` (2026-08-23 entry).

## Build Status

Verified at `main` HEAD post-merge, using Flutter (stable) from `/home/user/flutter`:

- `flutter pub get`: clean (21 packages have newer versions available, none blocking)
- `flutter analyze`: **0 issues**
- `flutter test`: **481/481 pass**
- Merge method: **merge commit** via GitHub (`claude/wyn-031-chat-1to1` → `main`, PR #135). Before opening the PR, `origin/main` was fetched and merged into the feature branch first — a parallel session had landed a WYN-030 QA-round-2 catch-up merge in the meantime (process-flag fix + 7 new adversarial checks, `wyn_030_appeal_system_test.sh` grown from 24 to 31 checks), advancing `main` past this branch's original base. That merge hit 2 conflicts, both in `CONTEXT.md`/`DECISIONS.md` — pure append-conflicts (both sides had appended a different bullet/entry to the same file), resolved by keeping both entries in full, in chronological order. Re-ran the full verification suite (all 5 SQL regression scripts + `flutter analyze`/`flutter test`) after the merge, before pushing, to confirm the merge itself introduced nothing broken.
- SQL regression scripts re-run against a fresh local Postgres 16 (cluster `16/main`, port 5432) at the merged tree, each script builds and drops its own throwaway database:
  - `supabase/tests/wyn_021_club_post_mentions_rls_test.sh` — **5/5 PASS**
  - `supabase/tests/wyn_027_is_blocked_either_way_rpc_exposure_test.sh` — **9/9 PASS**
  - `supabase/tests/wyn_029_moderation_queue_test.sh` — **36/36 PASS**
  - `supabase/tests/wyn_030_appeal_system_test.sh` — **31/31 PASS** (grown from 24 by the parallel session's QA round 2, brought in by this merge)
  - `supabase/tests/wyn_031_chat_test.sh` — **29/29 PASS** (new this round, run under the real `authenticated` role, not superuser)
  - No failures — the merge did not disturb anything QA had already verified.
- All 5 GitHub PR status checks (4 Vercel preview deployments + 1 Netlify deploy preview) reported success on the merged commit before merging.

## Deployment Target

**`main` branch on GitHub only** (`warren-wyn-dev/wynteam`). This is a code-integration step, not a deploy to any live/production/user-facing environment — see Readiness Gate below for why a real production deploy is not currently possible.

## Changes

24 files changed (this branch's own commit) merged into `main` via PR #135, plus the WYN-030 QA-round-2 catch-up content brought in by the pre-PR merge from `origin/main`:

- **SQL** (`supabase/schema.sql`): new `conversations` table (canonical-ordered pair table — `user_a_id`/`user_b_id` with `check (user_a_id < user_b_id)` enforced at the constraint level, not just by convention; `status` column reserved for WYN-032's future Message Request gate, always `'active'` this round; SELECT-only RLS, no insert/update policy for the client — both writes only ever happen through the RPCs below). `get_or_create_conversation()`/`mark_conversation_read()` RPCs. New `messages` table (a CHECK constraint rejects blank messages except once soft-deleted; SELECT policy is participant-only; the INSERT policy is a plain RLS check, not an RPC — mirrors `drops`/`club_posts`'s pattern, reusing `internal.is_blocked_either_way()`/`internal.is_posting_blocked()` directly). `prevent_cross_conversation_reply()` trigger. `delete_message()` RPC (nulls `text`/`image_url` and sets `deleted_at`, rather than just flagging a column — this project's recurring lesson about RLS being row-level, not column-level). New `get_message_for_moderation()` RPC (`security definer`, re-implements a moderator-only check rather than relying on ambient RLS, mirroring the `moderation_queue` view's own reasoning). New `conversation_mutes` table (deliberately a separate table and mechanism from WYN-028's user-level `mutes` — per-conversation notification mute, not content hiding). New private `chat-media` storage bucket (participant-only both ways). New `chat_inbox` view (`security_invoker = true`, mirrors `home_feed`/`saved_feed`). New `count_unread_conversations()` RPC. `submit_report()` extended with a `message` branch (validates the caller is a participant and not the message's own sender).
- **Flutter**: new `app/lib/features/chat/data/{conversation,chat_message,chat_repository}.dart` and `app/lib/features/chat/presentation/{chat_inbox_screen,conversation_screen}.dart`. `ReportTargetType`/`ModerationTargetSummary`/`ModerationRepository` extended for `message` targets. `HomeFeedScreen`/`RootShell` gain a Chat icon entry point with an unread badge (as a `Stack` overlay, not an `AppBar` — see the layout note above). `ViewProfileScreen` gains a "ส่งข้อความ" button next to Follow (hidden on the caller's own profile and on a blocked-either-way persona). `ModerationQueueScreen`/`ModerationReportDetailScreen` gain a `message` target icon and a "cannot open conversation directly" path for moderators.
- **New persisted regression test**: `supabase/tests/wyn_031_chat_test.sh` (29 checks, added to the same `supabase/tests/` suite as `wyn_021`/`wyn_027`/`wyn_029`/`wyn_030`).
- **Tests**: `app/test/chat_model_test.dart` (13 cases), `app/test/chat_inbox_screen_test.dart` (6 cases), `app/test/conversation_screen_test.dart` (12 cases including the reply-depth regression test added during QA), `app/test/support/recording_chat_repository.dart` (new fake — its 2 realtime subscribe methods deliberately never call `.subscribe()`, avoiding a real WebSocket attempt during widget tests), `app/test/home_feed_screen_test.dart` updated for the new `chatRepository` param.
- **Brought in from `origin/main` by the pre-PR merge** (not authored by this branch): WYN-030's QA-round-2 catch-up — a process-flag correction (the task file's original "Independent QA — Round 1" had been written by the same session as Coding, not a genuinely separate QA pass) plus 7 new adversarial checks added to `wyn_030_appeal_system_test.sh` (Suspend/Ban-approved `overturned_at` flip end-to-end, `anon` role RPC exposure, re-deciding an already-decided appeal, `get_my_moderation_action()`'s cross-user scoping).

Full history: `.wyn/tasks/approved/WYN-031-chat-1to1.md`.

## Deployment Result

**Merged to `main` via PR #135, pushed successfully.** This is the first task of **Phase 2 (WYN Chat)** to land on `main`, following Phase 1 (Safety & Trust Foundation, WYN-026 through WYN-030)'s completion. `main` now carries 1:1 direct messaging with full Block/Restrict-Suspend-Ban/Report integration, and the project's first working use of Supabase Realtime `postgres_changes`.

## Production Verification

**Not applicable — no production environment exists.** Readiness Gate (unchanged since the last several assessments, e.g. `.wyn/logs/deployments/2026-08-22-wyn-030-merge-to-main.md`) — re-verified directly in this session, not assumed:

- **No real Supabase project** — `app/lib/core/env.dart` still reads `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` from `String.fromEnvironment(...)`, unset anywhere in the repo. No `supabase/config.toml`.
- **No native OAuth/Firebase config** — no `google-services.json`/`GoogleService-Info.plist` anywhere in the repo.
- **No distribution channel** (TestFlight / Google Play Internal Testing / Firebase App Distribution) set up.
- **No CI pipeline** — `.github/workflows/` does not exist.
- **No Android SDK/Xcode in this sandbox** — `flutter build apk`/`flutter build ipa` cannot be attempted here.

This is now the **nineteenth+ approved batch** in this project's history to reach this exact same gate — all "approved, merged to `main`, waiting for real infra." None of this has ever been a WYN-031-specific blocker; it is a whole-project blocker that needs Founder action. No new infra has appeared since the last assessment.

**WYN-031-specific addition to this gate**: Realtime `postgres_changes` delivery across two real clients cannot be verified end-to-end until a live Supabase project exists — this feature's own known limitation (disclosed in the task file's Coding Output and QA sections), verified only at the SQL/RLS level and via widget tests that simulate realtime events directly. This is not a code defect; it is the same "no live infra yet" gate applied to the one part of this feature that specifically depends on a running Realtime server to prove end-to-end.

## Rollback Plan

- **Code**: `git revert` the merge commit on `main` restores the pre-merge state (a real merge commit with two parents, since `main` had advanced past this branch's original base before merging). Reverting would remove the 1:1 Chat feature entirely but leaves WYN-026 through WYN-030 untouched, since those are separate, earlier merges.
- **Database**: `supabase/schema.sql` grew by the `conversations`/`messages`/`conversation_mutes` tables + RLS, the `chat-media` bucket + policies, `get_or_create_conversation()`/`mark_conversation_read()`/`delete_message()`/`get_message_for_moderation()`/`count_unread_conversations()`, the `chat_inbox` view, and the `submit_report()` extension. Since there is no live database yet, rollback here simply means "don't apply this `schema.sql` version" — no live migration to reverse.
- **Distribution**: not applicable — nothing has been distributed to any real device/store.

## Next Steps (Founder-only, per RULES.md's Founder-authority list — "โครงสร้างพื้นฐาน production")

Unchanged from prior deployment logs' Next Steps (real Supabase project, native OAuth/Firebase config, distribution channel, Android SDK/Xcode or CI environment) — all still outstanding, all still Founder-gated. No WYN-031-specific manual step is needed beyond those.

With WYN-031 merged, **Phase 2 (WYN Chat)'s first task is code-complete**. Per the Founder's "พาท1 ถ้าเสร็จแล้ว ต่อ2 เลย" instruction, the next step is to continue with the remaining Phase 2 tasks in Roadmap order: **WYN-032 (Message Request flow)**, then **WYN-033 (Share to Chat)** — both already have a direct dependency satisfied by this merge (a working `conversations`/`messages` layer to build on).
