# Product Task — WYN-024

Status: backlog
Owner: AI Product Manager

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

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบตำแหน่ง Cover Image (ด้านบน avatar แบบ Instagram/Twitter หรือรูปแบบอื่นที่เข้ากับ WYN Design System), ตำแหน่ง Website link, และ flow การแก้ Username ใน Edit Profile — ให้ตรวจสอบประเด็น mention/username coupling ใน Risks ก่อนส่งต่อ AI Coding
