# Product Task — WYN-024

Status: design complete — ready for AI Coding
Owner: AI Product Manager (spec) → AI Design (spec เสร็จแล้ว) → AI Coding (ถัดไป)

Feature: Profile Identity Fields — Cover Image, Website, และ Username Edit หลัง Onboarding

Goal: ปิดช่องว่างที่ Phase 0 Audit ของ "WYN Core 3 Pages Hardening" (`.wyn/docs/product/wyn-core-3-pages-hardening-audit.md`) พบว่า Profile ยังขาดอยู่ 3 จุด ซึ่งเป็น field ระดับ identity พื้นฐานที่ Social platform ส่วนใหญ่มีตั้งแต่ V1 — ทั้งหมดเป็น additive column ล้วนๆ ไม่กระทบ schema เดิม ความเสี่ยงต่ำ ทำก่อนงานใหญ่ (Drop multi-image, Block/Mute/Report) ตามลำดับที่ตกลงไว้

Target User: ผู้ใช้ WYN Social ทุกคนที่มี Profile

Problem:
1. `profiles` table มีแค่ `username`/`display_name`/`bio`/`avatar_url` — ไม่มี cover image เลย ทำให้ Profile ดูโล่งเทียบกับ Social platform อื่นที่ผู้ใช้คาดหวัง
2. ไม่มี field สำหรับใส่ลิงก์ (website/social link) ใน Profile เลย — ผู้ใช้ที่อยากลิงก์ไปหาตัวเองที่อื่นทำไม่ได้
3. Username ตั้งได้ครั้งเดียวตอน onboarding (`username_setup_screen.dart`) แล้วไม่มีทางแก้ไขภายหลังเลยแม้แต่จุดเดียว — ผิดพลาดตอนตั้งครั้งแรกแล้วแก้ไม่ได้ตลอดไป

Requirements:

R1. เพิ่มคอลัมน์ `cover_url text` ใน `profiles` table (nullable, เหมือน `avatar_url` เดิม) — reuse Storage bucket `avatars` เดิม (path แยกเช่น `{userId}/cover.{ext}`) ไม่ต้องสร้าง bucket ใหม่ reuse upload/resize flow เดียวกับ avatar ที่มีอยู่แล้วใน `edit_profile_screen.dart` (`image_picker` maxWidth/maxHeight + imageQuality:85)
R2. เพิ่มคอลัมน์ `website text` ใน `profiles` table (nullable) — ต้องมี validation รูปแบบ URL ฝั่ง client ก่อนบันทึก (ให้ AI Design/Coding ตัดสินใจ regex/package ที่เหมาะสม ไม่ต้องเข้มงวดเกินไป เช่นรับทั้งมี/ไม่มี `https://` นำหน้า)
R3. เปิดหน้าจอแก้ Username ใหม่ (หรือเพิ่มเข้า `edit_profile_screen.dart` เดิม) — reuse `AuthRepository.isUsernameAvailable` เดิมที่มีอยู่แล้วจาก onboarding (WYN-002) ตรงๆ ไม่ต้องเขียน availability-check ใหม่ ใช้ validation regex เดียวกับตอน onboarding (`^[a-z0-9_]{3,20}$`)

Acceptance Criteria:
- [ ] Own Profile เห็นปุ่มอัปโหลด/เปลี่ยน Cover Image ใน Edit Profile — บันทึกแล้วแสดงผลใน `ViewProfileScreen` ของทุกคนที่ดู
- [ ] Own Profile กรอก Website ได้ใน Edit Profile — บันทึกแล้วแสดงเป็นลิงก์ที่กดได้ (เปิด browser ภายนอก) ใน `ViewProfileScreen`
- [ ] Website ที่กรอกรูปแบบไม่ถูกต้อง (ไม่ใช่ URL) ต้อง validate และแจ้ง error ก่อนบันทึก
- [ ] แก้ Username ได้จาก Edit Profile — เช็ค availability real-time เหมือนตอน onboarding, บันทึกสำเร็จแล้วอัปเดตทุกจุดที่อ้างอิง username เดิม (@username ใน card, mention, follow list ฯลฯ)
- [ ] Username ที่ถูกใช้แล้วโดยคนอื่นต้องบล็อกการบันทึกพร้อม error message ชัดเจน
- [ ] Cover/Website ที่ยังไม่ได้ตั้งค่า (null) ต้องมี fallback UI ที่เหมาะสม ไม่ error ไม่แสดงช่องว่างที่ดูเหมือน bug
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-003/WYN-013

Dependencies: ต่อยอด WYN-003 (User Profile)/WYN-002 (Auth — username validation/availability check เดิม)/WYN-013 (Profile V2) ที่ผ่าน QA แล้วทั้งหมด

Priority: สูง — ตามลำดับที่ Founder ยืนยันให้เริ่มหลัง WYN-023 (ก่อน Drop multi-image และ Block/Mute/Report)

Risks: ต่ำ — เป็น additive column ล้วนๆ ไม่มี breaking change กับข้อมูลเดิม จุดที่ต้องระวังคือ R3 (username เปลี่ยนได้) กระทบทุกจุดที่ cache/display username เดิมไว้ (เช่น mention ที่บันทึกเป็น username string แทน user_id ต้องตรวจสอบว่า mention system ของ WYN-021 ผูกกับ user_id หรือ username string — ถ้าผูกกับ username string การเปลี่ยน username จะทำให้ mention เก่าอ้างอิงผิดคน ต้องตรวจสอบให้ชัดก่อนเริ่ม Coding)

Recommendation: ทำ R1/R2 ก่อนได้เลยเพราะ additive ล้วนๆ ไม่มี risk พิเศษ — R3 ต้องให้ AI Design/Coding ตรวจสอบ mention/hashtag storage ก่อนว่าผูกกับ user_id (ปลอดภัย) หรือ username string (ต้องคิดเรื่อง migration/backfill เพิ่ม) ก่อนเริ่มจริง

Handoff: **AI Design เสร็จแล้ว** — spec เต็มที่ `.wyn/docs/design/wyn-024-profile-identity-fields.md`

**ผลตรวจสอบ Risk (mention/username coupling)**: ยืนยันแล้วว่า `drop_mentions`/`club_post_mentions` (`supabase/schema.sql`) เก็บ `mentioned_user_id uuid references profiles(id)` — ผูกกับ **user_id (uuid ถาวร) ไม่ใช่ username string** — populate ตอนสร้างโพสต์จาก id ที่ resolve แล้วของ `MentionInput` (WYN-021) ไม่ใช่ re-parse caption ทีหลัง และทุกจุดที่แสดง `author_username`/`@username` ในระบบ (views, `ProfileRepository`) query จาก `profiles.username` สดทุกครั้ง ไม่มีคอลัมน์ไหน denormalize username เก็บไว้ที่อื่น — **การเปลี่ยน username ปลอดภัย 100% ต่อ mention/notification ไม่ต้อง migration/backfill เพิ่ม** (รายละเอียดเต็มดู Section 0 ของ design spec) ผลข้างเคียงเล็กน้อยที่ไม่ block: แคปชันเก่าที่พิมพ์ `@oldusername` ไว้จะ resolve ไม่เจอ (เงียบ ไม่ error) หลัง username เปลี่ยน — เป็นพฤติกรรม "unresolvable mention fails silently" ที่ WYN-021 ออกแบบไว้อยู่แล้วสำหรับ typo/บัญชีถูกลบ ไม่ใช่ gap ใหม่

**ความเสี่ยงตัวจริงที่ AI Design พบเพิ่ม (ไม่ใช่ mention แต่เป็น availability-check self-exclusion)**: `AuthRepository.isUsernameAvailable(username)` เดิม (WYN-002) ไม่ exclude user id ของตัวเองออกจาก query — ถ้า Edit Profile เรียกมันตรง ๆ กับ username เดิมของผู้ใช้เอง (ค่า prefill ที่ไม่ได้แก้) จะรายงานผิดว่า "ถูกใช้แล้ว" ทั้งที่เป็นของตัวเอง ต้องแก้ด้วย client-side short-circuit ใน Edit Profile เอง (ไม่แก้ `AuthRepository` ตามที่ Product สั่งให้ reuse ตรง ๆ) — ดูรายละเอียด/ทางแก้เต็มใน design spec R3

ส่งต่อ AI Coding (`/code`) เพื่อ implement ตาม `.wyn/docs/design/wyn-024-profile-identity-fields.md` — ครอบคลุม schema migration (additive, ไม่ต้องขออนุมัติ Founder), `Profile`/`ProfileRepository` extension, `EditProfileScreen`/`ViewProfileScreen` changes, และ `url_launcher` dependency ใหม่ (ปัจจุบันเป็นแค่ transitive ผ่าน `share_plus`)

---

## Status Update (2026-08-17) — Coding เสร็จสมบูรณ์แล้ว รอ QA

Implementation ครบตาม R1/R2/R3 ของ Design spec (ตรวจสอบโค้ดจริงเทียบ spec ทีละจุดแล้ว ตรงทุกประการ): `cover_url`/`website` columns (additive), `ProfileCoverAvatar` widget ใหม่ reuse ทั้ง View/Edit Profile, website validation + tappable link, username edit flow พร้อม self-exclusion short-circuit + fail-fast save ordering ครบ

งานนี้ถูกส่งมาต่อจาก agent ก่อนหน้าที่ implementation เสร็จแล้วแต่ session หมดก่อน commit ได้ — งานที่ทำต่อคือแก้ test ที่ยังไม่ผ่าน (ไม่ใช่แก้ implementation ใหม่):
- **`edit_profile_screen_test.dart` ทั้งไฟล์ (14 เทสต์) เคย fail หมด**: root cause คือ `RecordingProfileRepository`/`RecordingAuthRepository` สร้าง `SupabaseClient(...)` ตรงในตัว `testWidgets()` (ไม่ผ่าน `setUp()`) ทำให้ `GoTrueClient`'s auto-refresh `Timer.periodic` โดน `FakeAsync` track แล้ว trip "A Timer is still pending" ทุกเทสต์ — แก้ root cause ที่ shared test support ด้วย `AuthClientOptions(autoRefreshToken: false)` (ไม่กระทบเทสต์อื่นในโปรเจกต์)
- **ปุ่ม "บันทึก" ตกขอบ viewport เทสต์มาตรฐาน 800x600** เพราะฟอร์มยาวขึ้นจาก cover header ใหม่ — แก้ด้วย `tester.ensureVisible()` ก่อน tap (มี precedent อยู่แล้วใน `create_club_screen_test.dart`)
- **3 เทสต์ที่แตะ `Image.memory`/`Image.network` ของรูปปลอม/URL ปลอมโยน exception async ที่ไม่เกี่ยวกับ assertion** — แก้ด้วย `tester.takeException()` (pattern ที่มีอยู่แล้วในโปรเจกต์)
- **`view_profile_screen_test.dart` 2 เทสต์ RenderFlex overflow จริง** (header ของ `ViewProfileScreen` ไม่ได้อยู่ใน scrollable ใด ๆ โดยตั้งใจ — สูงขึ้นจาก cover header ใหม่จนเกิน 544px ของ viewport เทสต์มาตรฐาน) — แก้ด้วย `tester.view.physicalSize` ขยาย viewport เทสต์ (precedent มีอยู่แล้วใน `drop_detail_screen_test.dart`, เหตุผล: viewport เทสต์ 800x600 แคบกว่าอุปกรณ์เป้าหมายจริงของ WYN ที่เป็น mobile portrait)

ไม่พบ production bug อื่นนอกเหนือจากที่ WYN-025 พบ (ดู WYN-025's status update สำหรับบั๊ก `PopScope.canPop` ที่ไม่เกี่ยวกับ WYN-024 โดยตรง)

`flutter analyze`: clean. `flutter test`: full suite 396/396 ผ่านหมด (baseline เดิม 369 ก่อน WYN-024/025)

ส่งต่อ AI QA & Security (`/qa`) — ย้ายเข้า `.wyn/tasks/review/`
