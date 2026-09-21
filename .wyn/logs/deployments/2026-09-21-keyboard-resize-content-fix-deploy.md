# Deployment Log — Keyboard Resizes Layout (interactiveWidget)

**Release**: แก้ปัญหาหน้ากระโดด + ช่องว่างเหนือคีย์บอร์ด ตอนกดพิมพ์คอมเมนต์ (จาก screen recording ที่ Founder ส่งมา)
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Root Cause**:
viewport config ไม่มี `interactiveWidget` เลย iOS Safari ใช้ default "resizes-visual" — visual viewport
หดตามคีย์บอร์ด แต่ layout viewport (ที่ `dvh`/`position:fixed` อิงอยู่) ไม่หดตาม ทำให้คีย์บอร์ดแค่ลอยทับ
หน้าเว็บ แล้ว Safari patch เอา fixed element มาลอยเหนือคีย์บอร์ดแทน แทนที่หน้าจะ resize จริงเหมือน
native app

**Changes**:
- `web/app/layout.tsx` — เพิ่ม `interactiveWidget: "resizes-content"` (iOS 16.4+)

**PR**: [#585](https://github.com/warren-wyn-dev/wynteam/pull/585) (`claude/web-beta1-readiness-7hysen` → `main`)

**ยังไม่ verify**: ความรู้สึกจริงบนอุปกรณ์ — sandbox ไม่มี iOS Safari รอ Founder ทดสอบเปิดคีย์บอร์ดที่
หน้า Post Detail หลัง deploy

**Rollback Plan**: Revert PR — เป็นการเปลี่ยน viewport meta property เดียว ไม่กระทบ business logic
ปลอดภัยที่จะ revert ทันที

**บริบท**: นี่คือข้อ #1/#2 จาก feedback 10 ข้อที่ Founder ส่ง screen recording มาให้ (2026-09-21) —
ดู DECISIONS.md/task ที่เกี่ยวข้องสำหรับ 8 ข้อที่เหลือ
