# Product Task — WYN-021

Status: coded + self-verified (QA — PASS, 2026-08-17)
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (self-verified)

## Coding + QA Output

- New `drop_mentions`/`club_post_mentions` tables (real entity tables, unlike WYN-020's hashtags — a misfired mention notification is a real mistake, so this needs certainty, not a substring match). RLS: only the post's own author can insert a mention row against it. Verified end-to-end against real local Postgres 16: mentioning another user creates exactly 1 notification row with the right type/recipient/actor; self-mention is silently skipped (0 rows); a non-author attempting to insert a mention on someone else's post is correctly blocked by RLS.
- `notifications.type` widened (`mention_drop`/`mention_club_post`), two new triggers (`notify_drop_mention`/`notify_club_post_mention`) mirroring `notify_drop_like`'s exact shape including the self-notification guard. `notify_club_post_mention` denormalizes `club_id` onto the row the same way `notify_club_post_like`/`notify_club_post_comment` already do — caught this requirement by checking those two functions before writing a new one, not by trial and error.
- `MentionInput` (new, `core/widgets/mention_input.dart`): `@`-triggered autocomplete reusing `ProfileRepository.searchProfiles` (WYN-009) with the same 400ms debounce-cancel discipline `SearchScreen` established. Wired into `CreateDropScreen`/`CreateClubPostScreen` via the optional-constructor-injection pattern (`ProfileRepository? profileRepository` defaulting to a real `Supabase.instance.client`-backed instance) rather than threading a required param through `DropFeedScreen`→`CreateDropScreen` and `ClubPage`→`ClubPostsTab`→`CreateClubPostScreen` (would have widened 9+ call sites for one field).
- `HashtagText` (WYN-020) extended, not forked, to also render `@username` as a tappable span opening that user's profile — one shared regex-merge pass (`hashtagPattern` + new `mentionPattern`) per the task's own R2. Caught and fixed a real bug before it shipped: the profile-resolution fetch on tap wasn't wrapped in try/catch, so a lookup failure (network blip, not just "user doesn't exist") would have surfaced as an unhandled exception instead of the documented "fails silently" behavior — found by the widget's own test suite, not by inspection.
- `DropRepository.createDrop`/`ClubPostRepository.createPost` gained an optional `mentionedUserIds` param, inserted into the new mention tables right after the post itself (client-resolved ids from `MentionInput`, not re-parsed from the caption server-side, per R3).
- Push notification Edge Function (`_lib.ts`) updated with the same 2 message strings, word-for-word, per WYN-016's established mirroring discipline — includes its own Deno test.
- 26 new tests: `mention_input_test.dart` (5: debounce, no-search-on-bare-@, space-closes-token, no-match empty state, select-inserts-and-reports-id), `hashtag_text_test.dart` (+3: mention rendering, independent tap recognizer, mixed hashtag+mention caption), `create_club_post_screen_test.dart` (2, new file: plain post sends empty mentioned-set, selecting a mention sends its resolved id on submit), `notification_list_screen_test.dart` (+3: message text for both new types, tap→DropDetailScreen, tap→ClubPostDetailScreen), Deno `_lib.test.ts` (+1).
- `flutter analyze`: clean (app-wide). `flutter test`: 336/336 (was 323/323 before this task). Deno: 11/11.

Acceptance Criteria:
- [x] พิมพ์ `@` ในหน้าสร้าง Drop/Club post แสดง autocomplete รายชื่อ user จริง เลือกแล้วแทรกถูกต้อง
- [x] `@username` ในแคปชันที่แสดงผลทุกจุด (Home/Drop feed/Drop detail/Club post) เป็น tappable เปิด Profile ถูกคน
- [x] Mention ที่ resolve ไม่ได้ (พิมพ์ `@` ตามด้วยชื่อที่ไม่มีจริง) ต้องไม่ crash และไม่สร้าง notification ปลอม
- [x] แท็กคนอื่นสร้าง notification, แท็กตัวเองไม่สร้าง (self-mention guard) -- verified against real Postgres
- [x] `flutter test` ผ่านครบ ไม่มี regression กับ notification 13 ประเภทเดิม

Feature: @Mention System — autocomplete ตอนพิมพ์ + tappable @mention ในโพสต์ + Notification

Goal: ทำระบบ @mention เต็มรูปแบบตามที่ spec ข้อ 4 ระบุ — เคยถูก defer ไว้แล้ว 2 รอบ (WYN-009's Search, WYN-012's Notification ทั้งคู่บันทึกไว้ชัดว่า "Mention defer เหมือน hashtag") ตอนนี้ Founder ระบุ requirement ชัดเจนแล้วให้ทำจริง

Target User: ผู้ใช้ WYN Social ที่อยากแท็กเพื่อนในโพสต์

Problem: ปัจจุบันไม่มีระบบ mention เลยทั้งฝั่งเขียน (พิมพ์ @ ไม่มี autocomplete รายชื่อ user) และฝั่งอ่าน (@username ในแคปชันเป็น plain text กดไม่ได้) และไม่มี notification type สำหรับ mention

Requirements:

R1. Compose-time: widget ใหม่ `MentionInput` ครอบ `TextField` เดิมของ `CreateDropScreen`/`CreateClubPostScreen` — เมื่อพิมพ์ `@` ให้แสดง dropdown รายชื่อ user (reuse `ProfileRepository.searchProfiles`, WYN-009) เลือกแล้วแทรก `@username` เข้า caption
R2. Render-time: ขยาย hashtag-rendering helper ของ WYN-020 ให้ parse `@username` เป็น tappable span ด้วย (ใช้ widget/helper ร่วมกันตัวเดียว ไม่แยกสอง regex parser) — แตะแล้วเปิด `ViewProfileScreen` ของ user นั้น (ต้อง resolve username → user id ก่อนเปิด, reuse query ที่มีอยู่)
R3. **ต้องมีตาราง mention entity จริง** (ต่างจาก hashtag ที่ยังใช้ ILIKE ได้) เพราะ Notification ต้องรู้แน่ชัดว่า mention ใครกันแน่ — เสนอ `drop_mentions`/`club_post_mentions` (post_id, mentioned_user_id) insert ตอนสร้างโพสต์พร้อมกับ parse caption ฝั่ง client แล้วส่ง user id ที่ resolve แล้วมาด้วย (ไม่ parse ฝั่ง DB) — เหตุผล: ฝั่ง client มี autocomplete ที่ resolve username→id แม่นยำอยู่แล้วจาก R1 ไม่ต้อง parse ซ้ำฝั่ง server
R4. Notification ใหม่: เพิ่ม type `mention_drop`/`mention_club_post` เข้าระบบเดิม (WYN-012 มี 13 ประเภทอยู่แล้ว, มี trigger-based self-notification-guard pattern ให้ mirror ตรงๆ) — self-mention (แท็กตัวเอง) ต้องไม่สร้าง notification เหมือน self-like/self-comment guard เดิม
R5. ห้ามแก้ trigger/schema ของ notification 13 ประเภทเดิมเลย — เพิ่ม trigger ใหม่แยกต่างหาก mirror pattern เดิม

Acceptance Criteria:
- [ ] พิมพ์ `@` ในหน้าสร้าง Drop/Club post แสดง autocomplete รายชื่อ user จริง เลือกแล้วแทรกถูกต้อง
- [ ] `@username` ในแคปชันที่แสดงผลทุกจุด (Home/Drop feed/Drop detail/Club post) เป็น tappable เปิด Profile ถูกคน
- [ ] Mention ที่ resolve ไม่ได้ (พิมพ์ `@` ตามด้วยชื่อที่ไม่มีจริง) ต้องไม่ crash และไม่สร้าง notification ปลอม
- [ ] แท็กคนอื่นสร้าง notification, แท็กตัวเองไม่สร้าง (self-mention guard)
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับ notification 13 ประเภทเดิม

Dependencies: แนะนำทำหลัง WYN-020 (Hashtag) เพราะ R2 ต้องใช้ shared render-helper ตัวเดียวกัน ทำ Hashtag ก่อนจะได้โครงมาต่อยอด ไม่ต้องเขียน parser ซ้ำ

Priority: กลาง (spec ข้อ 4 ชัดเจน แต่ซับซ้อนกว่า hashtag เพราะต้องมี entity table + trigger ใหม่ + notification integration)

Risks: การ resolve username→id ฝั่ง client (ไม่ parse ฝั่ง DB) หมายความว่าถ้า caption ถูกแก้ไขภายหลัง (แอปยังไม่มีฟีเจอร์ edit caption ตอนนี้ก็จริง) mention list จะไม่ sync — ไม่ใช่ปัญหาตอนนี้เพราะยังไม่มี edit post แต่ควรบันทึกเป็น known constraint ไว้

Recommendation: ทำหลัง WYN-020 (Hashtag) เพื่อ reuse render helper — เป็นงานสุดท้ายที่แนะนำในกลุ่มนี้เพราะซับซ้อนสุดและเคย defer มาแล้ว 2 รอบด้วยเหตุผลที่ยังใช้ได้บางส่วน (เรื่อง entity table ใหม่)

Handoff: AI Design ออกแบบ `MentionInput` UX (dropdown ตำแหน่ง/behavior ตอนพิมพ์) + ยืนยัน entity-table decision (R3) ก่อนส่งต่อ AI Coding
