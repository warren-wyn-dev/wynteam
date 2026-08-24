# Design Task — WYN-058

Status: approved (Coding + QA เสร็จ, 2026-08-24 — flutter analyze สะอาด, flutter test เต็ม suite 725/725 ผ่าน) — รอ AI Deploy & DevOps เมื่อมี infra จริง
Owner: AI Design → AI Coding → AI QA & Security

Screen: `ClubPage` — Header Join button visual hierarchy
Purpose: ต่อยอด WYN-056 (Founder ขอต่อเนื่อง 2026-08-24) — ยกน้ำหนักภาพปุ่ม Join (action สำคัญที่สุดของหน้า) ให้เด่นเท่าปุ่ม "+ สร้าง Club" ของ WYN-056 แทนที่จะเป็น OutlinedButton เดียวกับปุ่มรอง
Components: ดู `.wyn/docs/design/wyn-057-058-club-create-and-page-visual-polish.md` Screen 2
Interactions: เหมือนเดิมทุกประการ (`_toggleJoin`/`_confirmLeave` ไม่เปลี่ยน logic)
States: สถานะ "เข้าร่วม" (ยังไม่ได้เข้าร่วม) → FilledButton พื้น cyan เต็ม / สถานะ "เข้าร่วมแล้ว"/"รออนุมัติ" → OutlinedButton สี outline ทั้งคู่ (เดิม "รออนุมัติ" ใช้สี primary ทั้งที่กดไม่ได้ — ปรับให้สอดคล้องกับ "เข้าร่วมแล้ว" ในรอบนี้ด้วย)
Accessibility: Semantics label เดิมคงไว้ทั้ง 3 สถานะ
Design Rules: ปุ่มเดียวที่เป็นพื้น cyan เต็มในหน้านี้ ไม่ขัด DS-001 ข้อ 6 (≤15% พื้นที่จอ)

Acceptance Criteria:
- [x] สถานะ "เข้าร่วม" แสดงเป็น FilledButton พื้น colorScheme.primary — ยืนยันด้วย widget test (`isA<FilledButton>()`)
- [x] สถานะ "เข้าร่วมแล้ว" ยัง OutlinedButton, สถานะ "รออนุมัติ" ก็ยัง OutlinedButton แต่เปลี่ยนสีจาก primary → outline ให้ตรงกับ "เข้าร่วมแล้ว" (บันทึกไว้ชัดเจนว่าไม่ใช่ "เหมือนเดิมทุกประการ" ตามที่ตั้งใจไว้แต่แรก) — ยืนยันด้วย widget test เทียบสีจริงกับ `colorScheme.outline`
- [x] Key/Semantics label เดิมทั้ง 3 สถานะยังอยู่ครบ — ไม่แตะ semantics label ใดๆ ในโค้ด
- [x] `flutter analyze`/`flutter test` ผ่านสะอาด ไม่มี regression กับ `club_page_test.dart` เดิม — รันจริง 725/725 ผ่าน
- [x] ไม่แตะ schema/RLS/repository — ยืนยันด้วย diff (แก้แค่ `_buildJoinButton()`)

Handoff: ส่งต่อ AI Coding (`/code`)
