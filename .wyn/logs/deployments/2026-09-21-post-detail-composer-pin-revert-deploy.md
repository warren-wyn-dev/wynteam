# Deployment Log — Post Detail Composer: Revert to Pinned + Compositor-Layer Fix

**Release**: Founder ตัดสินใจกลับให้ช่องพิมพ์คอมเมนต์หน้า Post Detail pin ก้นจอไว้ตลอด (revert PR #583)
แทนการเลื่อนตาม scroll แล้วแก้ปัญหา "ทับเนื้อหา" เดิมด้วยวิธีอื่นแทน
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Investigation**:
- ทดสอบสมมติฐาน "PageTransition (framer-motion `x` animation) สร้าง CSS containing block ทับ
  `position: fixed`" ด้วย throwaway Playwright fixture — **พิสูจน์ว่าไม่ใช่สาเหตุ** (framer-motion
  set `transform: none` เมื่อนิ่งแล้ว)
- สมมติฐานที่เหลือ (มี doc รองรับกว้างขวางแต่ reproduce ใน sandbox นี้ไม่ได้ เพราะไม่มี iOS Safari จริง):
  iOS Safari's known `position: fixed` lag ระหว่าง momentum scroll เมื่อ element ไม่ได้ถูก promote
  ขึ้น compositor layer ของตัวเอง

**Changes**:
- `web/app/system-parity-final.css`, `web/app/post-detail-parity.css` — revert `.detail-composer-shell`
  กลับเป็น `position: fixed` (ของเดิมก่อน PR #583), เปลี่ยน `transform: translateX(-50%)` →
  `translate3d(-50%, 0, 0)` + เพิ่ม `will-change: transform` (มาตรฐานแก้ iOS fixed-position scroll lag)

**PR**: [#584](https://github.com/warren-wyn-dev/wynteam/pull/584) (`claude/web-beta1-readiness-7hysen` → `main`)

**ยังไม่ verify**: การแก้ iOS momentum-scroll lag บนอุปกรณ์จริง — sandbox ไม่มี iOS Safari รอ Founder
ทดสอบ scroll เร็วๆ ที่หน้า Post Detail บนไอโฟนจริงหลัง deploy

**Rollback Plan**: Revert PR — เป็น CSS diff เล็ก ไม่กระทบ business logic ปลอดภัยที่จะ revert ทันที
