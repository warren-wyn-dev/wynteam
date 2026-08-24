# Design Task — WYN-057

Status: approved (Coding + QA เสร็จ, 2026-08-24 — flutter analyze สะอาด, flutter test เต็ม suite 725/725 ผ่าน) — รอ AI Deploy & DevOps เมื่อมี infra จริง
Owner: AI Design → AI Coding → AI QA & Security

Screen: `CreateClubScreen` — Cover picker visual polish
Purpose: ต่อยอด WYN-056 (Founder ขอต่อเนื่อง 2026-08-24) — ยกระดับ cover picker ที่ตอนนี้เหลือเป็นจุดอัปโหลดรูปเดียวของฟอร์ม (หลังตัด Icon picker ออก) ให้ดูตั้งใจ/พรีเมียมขึ้น
Components: ดู `.wyn/docs/design/wyn-057-058-club-create-and-page-visual-polish.md` Screen 1
Interactions: เหมือนเดิมทุกประการ (ไม่แตะ `_pickCover`)
States: เพิ่มข้อความแนะนำอัตราส่วน 16:9 ตอนยังไม่มีรูป
Accessibility: Semantics label เดิมคงไว้
Design Rules: ห้าม Liquid Glass, สีอ้างอิง colorScheme เท่านั้น

Acceptance Criteria:
- [x] Cover picker (ตอนยังไม่มีรูป) มีกรอบเส้นประ (`DashedRectBorderPainter` ใหม่ใน `core/widgets/`) + ไอคอนกล้องในวงกลม + ข้อความ "แตะเพื่อเลือกรูปปก" + "แนะนำอัตราส่วน 16:9" — ยืนยันด้วย widget test ใหม่
- [x] ตอนมีรูปแล้วแสดงรูปเต็มเหมือนเดิม ไม่มีกรอบเส้นประทับซ้อน (แยก branch `_coverBytes != null` ออกจาก placeholder ชัดเจน)
- [x] `flutter analyze`/`flutter test` ผ่านสะอาด ไม่มี regression กับ `create_club_screen_test.dart` เดิม — รันจริง 725/725 ผ่าน
- [x] ไม่แตะ logic การอัปโหลด/schema/RLS — ยืนยันด้วย diff (แก้แค่ `_buildCoverPicker()`)

Handoff: ส่งต่อ AI Coding (`/code`)
