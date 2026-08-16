# Product Task — WYN-021

Status: QA รอบ 1 — FAIL (Major security finding — RLS gap ใน `club_post_mentions`) — ส่งต่อ AI Debug Engineer, 2026-08-17
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (independent — FAIL) → AI Debug Engineer (ถัดไป)

## Independent QA — Round 1 (AI QA & Security, 2026-08-17)

**หมายเหตุสำคัญ**: การ "PASS" เดิมใน section ด้านล่าง (`## Coding + QA Output`) เป็นแค่ **self-verified โดย session เดียวกับที่เขียนโค้ด** ไม่ใช่ QA อิสระจริงตามกติกา WORKFLOW.md ("ห้ามข้าม QA สำหรับงานที่จะขึ้น production") — รอบนี้คือ QA อิสระรอบแรกที่แท้จริงของ 6 task (WYN-017–022) ทั้งชุด

```
Feature: @Mention System — autocomplete ตอนพิมพ์ + tappable @mention ในโพสต์ + Notification
Environment: Re-synced ไป origin/main tip (commit 8d338cb, เดียวกับที่ merge PR #124 แล้ว) ก่อนเริ่ม, Flutter 3.47.0 / Dart 3.13.0, PostgreSQL 16.13 local (สร้าง harness เอง: stub schema `auth`/`storage`, `auth.uid()`, `storage.foldername()`, grants ให้ role `authenticated`/`anon` — mirror ของจริงที่ Supabase platform ทำให้อัตโนมัติ) ตรวจสอบ schema.sql ทั้งไฟล์ (`ON_ERROR_STOP=1`, load สำเร็จไม่มี error)
Test Cases:
1. `flutter analyze` อิสระ — ยืนยันตรงกับที่ Coding รายงาน
2. `flutter test` อิสระทั้ง suite — ยืนยันตัวเลขตรงกับที่ Coding รายงาน (336 ตอนจบ task นี้, 362 ที่ HEAD ปัจจุบันหลัง WYN-022+ranking follow-up)
3. Compose-time: `MentionInput` widget code review — debounce/cancel, `_activeMentionQuery()` boundary logic, try/catch รอบ profile-resolution บน tap (อ่านโค้ดยืนยันตรงกับที่ Coding อ้างว่าแก้ bug นี้ไว้)
4. Render-time: `HashtagText` รองรับทั้ง hashtag+mention token ในข้อความเดียวกัน ไม่ชนกัน (อ่านโค้ด `_findTokens`/`_HashtagTextState.build`)
5. DB: mention insert เป็น author จริง → ยืนยันสร้าง notification ถูกคน (real Postgres)
6. DB: self-mention (author mention ตัวเอง) → ยืนยัน 0 notification (real Postgres, guard ถูกทิศ)
7. DB: non-author พยายาม insert mention บนโพสต์คนอื่น → ยืนยัน RLS insert policy บล็อกจริง (real Postgres)
8. **DB (พบปัญหา): `club_post_mentions`'s select policy** — เทียบกับ sibling table 3 ตัวในไฟล์เดียวกัน (`club_posts`/`club_post_likes`/`club_post_comments`) ที่ gate ด้วย `club_role(...) is not null` ทั้งหมด แต่ `club_post_mentions` ใช้ `using (true)` — ตั้งสมมติฐานว่าอาจรั่ว แล้วพิสูจน์ด้วย real Postgres จริง
9. Regression: ยืนยัน notification 13 ประเภทเดิม (WYN-012/014/015) ไม่ถูกแตะ — `notifications_type_check` constraint ขยายแบบ backward-compatible (dynamic constraint-name lookup ตามที่ session อื่นเคยทำ), trigger เดิมทั้งหมดไม่ถูกแก้
Passed: 8/9 (test 8 คือจุดที่พบ Major finding — ไม่ใช่ "ทดสอบไม่ผ่านเพราะเทสพัง" แต่คือ "ทดสอบแล้วพบช่องโหว่จริง")
Failed: 1/9 — test 8: `club_post_mentions`'s select RLS
Severity: **Major (Security — Broken Access Control / Information Disclosure ใน private Club)**
Reproduction Steps:
  1. Seed real Postgres 16: `clubowner` สร้าง Club แบบ **private**; `author` เป็น **approved member**; `outsider` **ไม่ใช่สมาชิกเลย** (ไม่มีแม้แต่แถว `pending`)
  2. `author` สร้างโพสต์ในคลับ private นั้น พร้อม mention `@mentioned` (insert `club_post_mentions` ผ่าน insert policy ที่ถูกต้อง — ยืนยัน author-only insert ทำงานถูกต้องแล้วในข้อ 7)
  3. Set session เป็น `outsider` (`request.jwt.claim.sub` = outsider's id, role authenticated)
  4. `select content from club_posts where id = '<post>'` → 0 rows (ถูกต้อง — พิสูจน์ outsider ไม่มีสิทธิ์จริง, `club_role()` คืน null)
  5. `select club_post_id, mentioned_user_id from club_post_mentions where club_post_id = '<post>'` → **ได้ 1 row กลับมา**
Expected: ข้อ 5 ควรได้ 0 rows เหมือนข้อ 4 (private club post's mention data ต้องเห็นได้เฉพาะ approved member เท่านั้น เหมือนที่ `club_post_likes`/`club_post_comments` ทำถูกต้องอยู่แล้วในไฟล์เดียวกัน)
Actual: `outsider` (ไม่ใช่สมาชิกคลับเลย) อ่าน `club_post_mentions` ได้ตรงๆ ผ่าน `select` policy ที่เป็น `using (true)` — เห็นทั้ง `club_post_id` (ยืนยันว่ามีโพสต์ private นี้อยู่จริง) และ `mentioned_user_id` (รู้ว่าใครถูกแท็กในโพสต์ private ที่ตัวเองไม่มีสิทธิ์เห็น) — exploitable ตรงผ่าน raw Supabase/PostgREST API (`GET /rest/v1/club_post_mentions?select=*`) ด้วย JWT ของ user ธรรมดาคนไหนก็ได้ ไม่ต้องพึ่ง Flutter app เลย ดังนั้น UI-level restriction ใดๆ ในแอปก็ป้องกันไม่ได้
Security Findings:
  - **Major**: `club_post_mentions`'s select RLS policy (`"Club post mentions are viewable by authenticated users"`, `using (true)`) ไม่ gate ด้วย club membership เหมือน sibling table 3 ตัว (`club_posts`/`club_post_likes`/`club_post_comments`) ในไฟล์เดียวกัน — ขัดกับ invariant ที่ WYN-014 วางไว้ชัดเจนว่า "club posts are members-only-visible at the DB layer" ไม่มีการบันทึกไว้ใน Design doc (`wyn-021-mention-system.md`) ว่าเป็น tradeoff ที่ยอมรับแล้ว — เป็นช่องโหว่จริงที่ยังไม่ถูกพบมาก่อน ไม่ใช่ known/accepted risk
  - `drop_mentions`'s เทียบเคียง `using (true)` policy **ไม่ใช่ปัญหา** — `drops` เป็น global-public content อยู่แล้ว (`drops`'s select policy เองก็ `using (true)`) จึงสอดคล้องกัน ไม่ต้องแก้
  - Self-mention guard: ถูกต้อง (0 notification เมื่อ mention ตัวเอง, พิสูจน์กับ Postgres จริง)
  - Non-author insert block: ถูกต้อง (RLS ปฏิเสธ insert ของคนที่ไม่ใช่เจ้าของโพสต์, พิสูจน์กับ Postgres จริง)
  - Unresolvable mention (fetch fail) fails silently ตามที่ออกแบบไว้ — try/catch ครอบถูกจุดจริง (ยืนยันจากการอ่านโค้ด)
Recommendation: ส่งต่อ AI Debug Engineer พร้อม bug report เต็ม (`.wyn/tasks/bugs/WYN-021-club-post-mentions-rls-gap.md`) — fix ที่เสนอคือ mirror select policy shape ของ `club_post_likes`/`club_post_comments` ให้ `club_post_mentions` ตรงๆ (ใช้ `club_role(cp.club_id, auth.uid()) is not null` แทน `using (true)`) ความเสี่ยง regression ต่ำมาก เพราะเป็นการ "เข้มงวดขึ้น" จาก policy ที่หลวมเกินไป ไม่มี legitimate read path ปัจจุบันที่ต้องพึ่งความหลวมนี้
Final Status: FAIL
```

---

## Coding + QA Output (เดิม — self-verified เท่านั้น ไม่ใช่ QA อิสระ)

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
