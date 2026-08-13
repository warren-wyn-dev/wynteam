# Product Task — WYN-003

Status: approved (QA รอบ 2 — PASS ระดับโค้ด/static — ดูเงื่อนไขก่อน deploy จริงด้านล่าง)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (FAIL รอบ 1, **PASS รอบ 2**) → AI Debug Engineer (แก้ 1 รอบ) → AI Deploy & DevOps (ถัดไป — เมื่อพร้อม)

Feature: User Profile (View & Edit)

Target User: วัยรุ่น / Gen Z ที่ต้องการปรับแต่งตัวตนบนแอปให้เป็นของตัวเอง

Dependencies: WYN-002 (เสร็จแล้ว, ผ่าน QA รอบ 3)

Priority: สูง — เป็นฐานให้ Feed/Follow ในอนาคต (ปลดล็อกแล้วในระดับโค้ด)

---

## QA & Security Report — รอบ 2 (AI QA & Security)

Feature: WYN-003 — User Profile (หลัง Debug Engineer แก้บั๊ก Critical จาก QA รอบ 1 ใน PR #16)

Environment: Code review + static analysis บน `main` หลัง merge PR #16 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับรอบก่อน

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. **Trace fix**: `normalizeOptionalText` แปลง `''` → `null` ถูกต้องตามที่ต้องการ เทียบกับ constraint อีกครั้ง
4. Edge case: ผู้ใช้ที่ **เคยตั้ง** ชื่อแสดงไว้แล้ว ลบออกจนว่างเปล่า แล้วบันทึก — ต้อง unset กลับเป็น "ยังไม่ได้ตั้ง" ได้ถูกต้อง (ไม่ใช่แค่กรณีตั้งครั้งแรก)
5. Edge case: ชื่อแสดงที่เป็นช่องว่างล้วน (เช่น "   ") — ต้องถูก trim ก่อนแล้วกลายเป็น null เหมือนกัน
6. Edge case: ชื่อแสดงยาวพอดี 50 ตัวอักษร — ต้องผ่าน constraint
7. ตรวจสอบว่า `bio` ไม่ได้รับผลกระทบจากการแก้ (ยังส่ง empty string ได้ตามปกติ)
8. Regression check: fix รอบ 1 (screens, avatar upload, RLS) ยังทำงานถูกต้อง ไม่มีอะไรถูกแก้ทับ

Passed: 8/8

Failed: 0/8

### รายละเอียดการยืนยัน Test Case #4-5 (edge case ที่ QA รอบ 1 ไม่ได้ครอบคลุม)

ไล่โค้ดจริง:
1. `EditProfileScreen._save()` เรียก `_displayNameController.text.trim()` เสมอ ก่อนส่งเข้า `updateProfile()` — ดังนั้นทั้งกรณี "ไม่เคยพิมพ์อะไร" และ "พิมพ์แล้วลบจนว่าง" และ "พิมพ์แต่ space" ล้วนได้ผลลัพธ์เป็น `''` เหมือนกันหมดก่อนถึง repository
2. `ProfileRepository.updateProfile()` เรียก `normalizeOptionalText(displayName)` ซึ่งแปลง `''` → `null` โดยไม่สนใจว่าค่าเดิมใน DB เป็นอะไรมาก่อน (INSERT/UPDATE เป็น `null` ตรง ๆ ) — ครอบคลุมทั้งกรณี "ตั้งครั้งแรก" และ "ลบออกจากที่เคยตั้งไว้" เหมือนกัน ไม่มีความแตกต่างในการจัดการทั้งสองกรณี
3. ฝั่ง UI: `Profile.nameOrUsername` เช็คทั้ง `displayName != null` และ `displayName!.isNotEmpty` — แม้ Profile object ที่ return กลับมาจาก `EditProfileScreen` (ผ่าน `Navigator.pop`) จะเก็บ `displayName` เป็น `''` (ไม่ใช่ `null`, เพราะจุดที่ pop ไม่ได้เรียก `normalizeOptionalText`) แต่ getter นี้ก็ยัง fallback ไป `@username` ถูกต้องอยู่ดี — เป็นความไม่สอดคล้องเล็กน้อยระหว่าง in-memory object กับค่าที่ persist จริงใน DB (`''` vs `null`) แต่**ไม่ก่อให้เกิดพฤติกรรมผิดใด ๆ ที่สังเกตเห็นได้** เพราะ getter จัดการทั้งสองแบบเหมือนกัน — ไม่ถือเป็นบั๊ก

**สรุป**: Fix ครอบคลุมทั้งกรณีตั้งครั้งแรกและกรณีลบออก ถูกต้องตามที่ควรจะเป็น

Security Findings: ไม่มีจุดใหม่ — RLS, secret handling เหมือนเดิมทุกประการ ไฟล์ที่แก้ (`profile_repository.dart`) ไม่แตะ security-sensitive code

Minor (ไม่ block, เหมือนรอบก่อน): orphaned avatar files เมื่อเปลี่ยนนามสกุลไฟล์รูป — ยังไม่ block, เป็น storage-cost risk ระยะยาว

Recommendation: **อนุมัติระดับโค้ด** — ส่งต่อ AI Deploy & DevOps ได้ แต่ยังห้าม deploy จริงจนกว่าจะมี Supabase project จริง + native platform config + `flutter build` สำเร็จ + dynamic test บนอุปกรณ์จริง (เงื่อนไขเดิมจาก WYN-002 ยังไม่เปลี่ยนแปลง — infra ยังไม่พร้อม)

Final Status: **PASS** (code/static-level)

---

## สรุป QA Cycle ทั้งหมดของ WYN-003

- รอบ 1: FAIL (1 Critical — บันทึกล้มเหลวเมื่อไม่กรอกชื่อแสดง)
- รอบ 2: **PASS**

Handoff: WYN-003 พร้อมส่งต่อ AI Deploy & DevOps เช่นเดียวกับ WYN-002 — จะ deploy จริงพร้อมกันได้เมื่อ infra (Supabase project, native config, build toolchain) พร้อมตามที่ระบุใน `.wyn/tasks/approved/WYN-002-authentication-onboarding.md`
