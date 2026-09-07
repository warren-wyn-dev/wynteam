# Bug Report — WYN-128

Status: bugs
Owner: AI Debug Engineer

Bug: Club Group Chat messages have no way to be reported at all — neither a "รายงาน" UI affordance nor backend support. `public.reports.target_type`'s CHECK constraint (`supabase/schema.sql`, `reports_target_type_check`) only allows `'user', 'drop', 'drop_comment', 'club', 'club_post', 'club_post_comment', 'message', 'redrop'` — there is no `'club_channel_message'` value, so even a hypothetical UI-side report button would 400 against `submit_report()`. This directly matches a Risk the WYN-128 Product task itself called out and asked Design/Coding to verify: "Moderation (WYN-026/027/028/029) ต้องขยายมาครอบคลุมข้อความในห้องแชท Club ด้วย ไม่ใช่แค่โพสต์ — ต้องเช็คกับระบบ report/block ที่มีอยู่แล้วว่าครอบคลุมหรือไม่" — neither the Design Output nor the Coding Notes for WYN-128 mention having checked or addressed this, and it was not addressed.

Reproduction:
1. `grep -n "รายงาน\|report" app/lib/features/club/presentation/widgets/club_channel_chat_view.dart` → no matches. `_showMessageMenu()` only ever offers "ตอบกลับ" (reply) and, conditionally, "ลบข้อความ" (delete, author/staff only) — there is no report row at all, unlike every other user-generated-content surface in this app:
   - Club posts (`club_post_card.dart`): "รายงานโพสต์"
   - Club post comments (`club_post_detail_screen.dart`): "รายงานคอมเมนต์"
   - The Club itself (`club_page.dart`): "รายงาน Club"
   - 1:1 chat (`conversation_screen.dart`): wired to `ReportRepository`/`ReportSheet`
2. `grep -n "reports_target_type_check" -A5 supabase/schema.sql` shows the constraint's allowed value list has no chat-message-equivalent for `club_channel_messages` (it does have a plain `'message'` value, presumably for 1:1 `messages`, but there is no evidence `club_channel_messages` rows can be submitted under any existing value without a dedicated code path, and none exists).
3. Because Club Group Chat is a shared, always-on real-time room (not a moderated post/comment reviewed asynchronously), the only mitigation currently in place is a Moderator/Admin/Owner happening to see and manually delete an offending message themselves — there is no way for an ordinary member on the receiving end of harassment/spam/illegal content in the room to flag it to platform moderation at all.

Root Cause: The feature's own Risk section explicitly asked for this to be checked before shipping; it appears to have been missed during Coding (no mention in Coding Notes of having investigated `reports.target_type` coverage for the new table).

Fix (recommended):
1. Add `'club_channel_message'` to `reports_target_type_check`'s allowed list in `supabase/schema.sql` (and the equivalent `migrations_wyn128_club_channel_messages.sql`, or a small follow-up migration if that file has already been finalized/applied — additive `alter table ... drop constraint ... add constraint` is safe and reversible).
2. Extend `submit_report()`/the moderation-queue read side (WYN-027/028/029) to resolve a `club_channel_message` target the same way `club_post`/`club_post_comment` already do (author lookup for `apply_moderation_action`'s `remove_content` path, moderation queue preview, etc.) — mirror the existing `club_post_comment` handling closely since a chat message is structurally similar (short text/optional image, no independent children).
3. Add a "รายงานข้อความ" row to `_showMessageMenu()` in `club_channel_chat_view.dart` for any message not the caller's own, wired to the existing `ReportSheet`/`ReportRepository` the rest of the app already uses (same pattern as `club_post_card.dart`).

Files Changed (expected): `supabase/schema.sql` (`reports_target_type_check`, `apply_moderation_action()`'s `remove_content` target resolution, moderation queue view/RPC), a small new/updated migration SQL file, `app/lib/features/club/presentation/widgets/club_channel_chat_view.dart`.

Tests: Add coverage (widget test for the new menu row + a `supabase/tests/wyn_128_*_test.sh` RLS/RPC check, see the companion WYN-129 bug report for why this feature also currently lacks any committed regression test script at all) confirming: a member can submit a report against a `club_channel_message` id; `remove_content` moderation action against a reported chat message actually removes/hard-deletes it; a non-member cannot report a message in a Club they don't belong to.

Regression Risk: Low — additive schema change (widened CHECK constraint, new target-type branch in existing moderation functions) plus one new menu row; does not change any existing report/moderation behavior for posts, comments, or 1:1 chat.

Handoff to QA: Once implemented, re-verify end-to-end: submit a report on a chat message as a plain member, confirm it appears in the Admin moderation queue (WYN-050), confirm `remove_content` actually deletes the message, confirm a non-member/banned member cannot submit a report for a Club they have no access to.
