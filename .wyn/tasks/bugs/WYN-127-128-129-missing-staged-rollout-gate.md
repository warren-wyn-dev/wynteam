# Bug Report — WYN-127 / WYN-128 / WYN-129

Status: **closed (2026-09-07)** — gate implemented, independently re-verified live by AI QA & Security (round 2, PASS) — shipped to production (deploy run #96, then again as part of run #97's tab restructure)
Owner: AI Debug Engineer (เสร็จ) → AI QA & Security (ถัดไป)

## Fix (2026-09-07, AI Debug Engineer)

Followed the one real, already-shipped `DeveloperAccessService` call site (`settings_screen.dart`'s `_VersionFooter`) exactly: optional constructor param defaulting to a real `DeveloperAccessService()`, `late final Future<bool> _isDeveloperFuture = _developerAccessService.isDeveloperAccount()`, `FutureBuilder<bool>` gating render (`snapshot.data == true`) — fail-closed while loading/on error, same as that call site.

- `app/lib/features/club/presentation/widgets/club_posts_tab.dart`: the channel chip row and the "โพสต์ | แชท" toggle (and therefore `ClubChannelChatView`, since `_viewMode` never leaves `.posts` when the toggle never renders) are wrapped in a `FutureBuilder<bool>` on `_isDeveloperFuture`. WYN-129's `_loadBadges()` is deferred until the future resolves `true`, so `_badges` stays permanently empty for a non-developer account — `ClubPostCard`'s `authorBadge` param is simply always `null`, requiring no change to `club_post_card.dart` itself. Also gated: `CreateClubPostScreen`'s locked chip — passes `channelName: ''` for a non-developer account so the composer falls back to its exact pre-WYN-127 "โพสต์ใน [ชื่อ Club]" text (no "· #ห้อง" suffix), since that text alone would otherwise leak the channel concept even with the switcher hidden. `channelId` is still passed correctly either way — posting itself is unaffected.
- `app/lib/features/club/presentation/widgets/club_members_tab.dart`: badge fetch deferred behind the same check; the "ตั้งป้าย/แก้ไขป้าย/ถอดป้าย" `IconButton` is additionally gated on `_canManage && _isDeveloper`.
- `app/lib/features/club/presentation/club_post_detail_screen.dart`: badge fetch deferred the same way (covers both the post header and every comment row's badge pill with one change).
- `app/lib/features/club/presentation/club_page.dart`: threads one shared `DeveloperAccessService` instance down to both `ClubPostsTab` and `ClubMembersTab`.
- `club_channel_switcher.dart`/`club_post_card.dart` needed no direct changes — both are already conditionally fed by their callers above.

Tests added (`app/test/club_posts_tab_test.dart`, `club_members_tab_test.dart`): a "Staged rollout gate" group in each, asserting the `false` state renders identically to the pre-WYN-127/128/129 UI (no channel chip row, no "+ ห้องใหม่" chip, no "แชท" toggle, no badge pill/management button, no channel name in the create-post composer chip) and the `true` state still renders the new UI (regression). `club_page_test.dart`/`club_channel_chat_view_test.dart` updated to inject `RecordingDeveloperAccessService` so they don't attempt a real RPC call. `flutter analyze`: no issues. `flutter test`: 1377/1377 (was 1367/1367 — 10 net-new tests across this bug's 3 fixes).

Handoff to QA: re-verify both states end-to-end for all three features per WORKFLOW.md item 3, including the create-post composer chip text for a non-developer account.

---

## Original report

Bug: None of the three Club Discord-identity features (WYN-127 Club Channels, WYN-128 Club Group Chat, WYN-129 Club Role Badges) are gated behind `DeveloperAccessService.isDeveloperAccount()`. Per `.wyn/company/WORKFLOW.md`'s "Staged Rollout เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่ทุกตัว" (added 2026-09-06, one day before this branch's Coding work on 2026-09-07), **every new user-facing feature must default to developer-account-only visibility** until the Founder explicitly says to open it to everyone. None of the three tasks' Design Output or Coding Notes mention this gate at all, and `grep -rn "isDeveloperAccount" app/lib/features/club/` returns zero matches. As written, merging/deploying this branch shows the channel switcher, the "โพสต์ | แชท" toggle + full group chat, and role badges to **100% of existing Club users immediately** — not just developer accounts.

Reproduction:
1. Read `.wyn/company/WORKFLOW.md`'s "Staged Rollout เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่ทุกตัว" section — mandatory, no exception requested for Club/community features, and the listed exceptions (bug fix / security fix / hotfix to already-shipped behavior) do not apply here (these are 3 brand-new, previously-nonexistent features).
2. `grep -rn "isDeveloperAccount\|DeveloperAccessService" app/lib/features/club/` → no matches in any of the new files (`club_channel_switcher.dart`, `club_posts_tab.dart`, `club_channel_chat_view.dart`, `club_badge_pill.dart`, `club_members_tab.dart`, `club_post_card.dart`, `club_post_detail_screen.dart`).
3. Confirm the only place `isDeveloperAccount()` is used anywhere in `app/lib/` today is WYN-125's own Settings screen (`app/lib/features/settings/presentation/settings_screen.dart`) — i.e. no product feature has actually exercised this policy yet, and these three are the first real-world test of it.
4. None of the three tasks' backlog files (`.wyn/tasks/backlog/WYN-127-club-channels.md`, `WYN-128-club-group-chat.md`, `WYN-129-club-role-badges.md`) mention an approved exception from the Founder to skip staged rollout for this work.

Root Cause: AI Design (writing Design Output on 2026-09-07) and AI Coding did not apply the standing company policy that took effect the day before (2026-09-06) — the policy explicitly says AI Coding must do this "เป็นมาตรฐานโดยอัตโนมัติ" without waiting to be asked per-task, but that didn't happen here.

Fix (recommended — does not require reworking the DB/RLS layer, which is fine for everyone once a Club has channels):
- `ClubPostsTab`: wrap the `ClubChannelSwitcher` and the "โพสต์ | แชท" toggle/`ClubChannelChatView` behind `isDeveloperAccount`. For `false`, keep exactly the pre-WYN-127 experience: a single flat feed with no channel bar, no chat toggle (query `club_posts` for the Club's own default/oldest channel only, so non-developer accounts still see their existing posts with zero visible change).
- `ClubMembersTab` / `ClubPostCard` / `ClubPostDetailScreen`: wrap `ClubBadgePill` rendering and the "ตั้งป้าย/แก้ไขป้าย/ถอดป้าย" menu entries behind `isDeveloperAccount`.
- The migration/schema itself (channels table, default-channel backfill, badges table, chat tables) can stay exactly as-is and apply to every Club regardless of account type — it's additive and invisible if the UI never surfaces it. Gating only needs to happen in the four widget files above.
- Once Founder explicitly says "เปิดให้ทุกคนได้แล้ว" for these three, remove the gates (per WORKFLOW.md's own unwind instructions).

Files Changed (expected): `app/lib/features/club/presentation/widgets/club_posts_tab.dart`, `club_channel_switcher.dart` (call site), `club_members_tab.dart`, `club_post_card.dart`, `app/lib/features/club/presentation/club_post_detail_screen.dart`, `club_page.dart` (thread `isDeveloperAccount`/`DeveloperAccessService` down to these widgets the same way other gated features do it).

Tests: Add/extend widget tests asserting the `false` state renders identically to the pre-WYN-127/128/129 UI (no channel chip row, no chat toggle, no badge pills, no "+ ห้องใหม่"/"ตั้งป้าย" affordances) and the `true` state renders the new UI, mirroring the existing pattern QA already checks for other gated features per WORKFLOW.md item 3.

Regression Risk: Low-medium — this is additive gating around already-built, already-tested widgets, not a rewrite. Main risk is any widget test that currently constructs `ClubPostsTab`/`ClubMembersTab` directly (bypassing the app's real `DeveloperAccessService`) needs an explicit `isDeveloperAccount: true` (or equivalent constructor param/mock) to keep exercising the new code paths, or a new test needs adding for the `false` path specifically.

Handoff to QA: Once gated, QA must re-verify **both** states end-to-end for all three features (per WORKFLOW.md item 3: "ตรวจทั้งสอง state เสมอ (true/false) เหมือนตรวจ edge case ปกติ") — this was not done in this round since the gate doesn't exist yet at all.
