# Product Task — WYN-003

Status: qa (Debug เสร็จแล้ว รอ AI QA & Security ทดสอบรอบ 2)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (FAIL รอบ 1) → AI Debug Engineer (เสร็จ) → AI QA & Security (ถัดไป)

Feature: User Profile (View & Edit)

Target User: วัยรุ่น / Gen Z ที่ต้องการปรับแต่งตัวตนบนแอปให้เป็นของตัวเอง

Dependencies: WYN-002 (เสร็จแล้ว, ผ่าน QA รอบ 3)

Priority: สูง — เป็นฐานให้ Feed/Follow ในอนาคต

---

## Debug Engineer Report (AI Debug Engineer)

Bug: Critical จาก QA รอบ 1 (`.wyn/tasks/bugs/WYN-003-user-profile.md`) — บันทึกโปรไฟล์ล้มเหลวทุกครั้งที่ผู้ใช้ไม่ได้กรอกชื่อแสดง (ค่าเริ่มต้นของผู้ใช้ทุกคน)

Reproduction: ยืนยันตรงกับที่ QA รายงาน — เทียบโค้ด `ProfileRepository.updateProfile()` กับ constraint `profiles_display_name_length` ใน `supabase/schema.sql` บรรทัดต่อบรรทัด: โค้ดส่ง `displayName` (empty string เมื่อผู้ใช้ไม่กรอก) ตรง ๆ ไม่มีการแปลงใด ๆ แต่ constraint ต้องการ `null` หรือความยาว 1-50 — empty string ไม่เข้าเงื่อนไขไหนเลย

Root Cause: ความไม่สอดคล้องกันระหว่าง Dart-side default (`widget.profile.displayName ?? ''` ทำให้ผู้ใช้ที่ยังไม่ตั้งชื่อแสดงเห็นช่อง input ว่างเปล่า ซึ่งเมื่อไม่แก้ไขแล้ว submit จะได้ `''`) กับความหมายที่ตั้งใจไว้ฝั่ง database (`''` ไม่เท่ากับ "ยังไม่ได้ตั้ง" — ต้องเป็น `null` เท่านั้น) ไม่มีจุดไหนในโค้ดแปลงค่าให้ตรงกันก่อนส่ง

Fix: เพิ่มฟังก์ชัน `normalizeOptionalText(String value) => value.isEmpty ? null : value;` ใน `profile_repository.dart` แล้วใช้กับ `display_name` ก่อนส่งไป Supabase ใน `updateProfile()` — ไม่แตะ `bio` เพราะ constraint ของ bio อนุญาตความยาว 0 อยู่แล้ว (ไม่ใช่บั๊ก)

Files Changed:
- `app/lib/features/profile/data/profile_repository.dart`
- `app/test/profile_repository_test.dart` (ใหม่ — regression test)

Tests:
- `flutter analyze` (รันซ้ำอย่างอิสระ) — **No issues found**
- `flutter test` (รันซ้ำอย่างอิสระ) — **All tests passed! (14/14)** เพิ่ม 2 เคสใหม่ทดสอบ `normalizeOptionalText` โดยตรง (empty string → null, non-empty string → unchanged)
- **รอบนี้มี automated regression test คุ้มครอง fix จริง** (ต่างจาก fix ของ WYN-002 ที่ยังไม่มี) เพราะ logic ที่แก้เป็น pure function แยกออกมาได้ ไม่ต้องพึ่ง Supabase จริงในการทดสอบ

Regression Risk: ต่ำ — มี unit test ตรงจุดคุ้มครองไว้แล้ว ถ้ามีคนแก้ไฟล์นี้อีกในอนาคตแล้วลบ normalization ออก test จะ fail ทันที

Handoff to QA: ส่งกลับ AI QA & Security (`/qa`) ทดสอบรอบ 2 — เน้นตรวจสอบว่า: (ก) `updateProfile` ตอนนี้ส่ง `null` แทน `''` ถูกต้องจริงสำหรับ `display_name` (ข) `bio` ยังคงส่ง empty string ได้ปกติไม่กระทบ (ค) ไม่มี regression กับส่วนอื่นของ WYN-003 (avatar upload, view profile)

Final Status: **แก้ไขแล้ว รอ QA รอบ 2 ยืนยัน**
