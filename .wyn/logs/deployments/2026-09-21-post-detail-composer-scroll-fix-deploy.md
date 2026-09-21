# Deployment Log — Post Detail Comment Composer Scrolls With Page

**Release**: แก้ช่องพิมพ์คอมเมนต์หน้า Post Detail ที่ลอยทับเนื้อหาอยู่ (Founder รายงานจาก screenshot)
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Root Cause**:
`.detail-composer-shell` เป็น `position: fixed` ปักที่ก้นจอตลอดเวลา ทำให้เนื้อหาที่ scroll ผ่านไป
(เช่น รูปโพสต์) ดูเหมือนโดนทับอยู่ข้างหลัง — Founder อยากให้ช่องพิมพ์เลื่อนไปกับหน้าตามปกติแทน

**Verification**:
- Live-verified ด้วย throwaway Playwright fixture (ลบก่อน commit) — วัดตำแหน่ง viewport ของ composer
  ก่อน/หลัง scroll 222px: เปลี่ยนตาม scroll พอดี (953→731) ยืนยันว่าเลื่อนไปกับหน้าจริงแล้ว
- `npx playwright test --project=chromium-desktop --project=chromium-android` — 106/106 ผ่าน

**Changes**:
- `web/app/system-parity-final.css` — `.detail-composer-shell`: `position: fixed` → `position: static`,
  ลด `.flutter-detail-comments` padding-bottom 96px → 16px (ไม่ต้องกันที่ให้ fixed bar แล้ว)
- `web/app/post-detail-parity.css` — sync rule เดียวกัน (เดิมโดน cascade ทับอยู่แล้ว) + ลบ dead
  desktop border rule ของ composer ที่ไม่จำเป็นแล้ว

**PR**: [#583](https://github.com/warren-wyn-dev/wynteam/pull/583) (`claude/web-beta1-readiness-7hysen` → `main`)

**Rollback Plan**: Revert PR — ทั้งหมดเป็น CSS diff เล็ก ไม่กระทบ business logic ปลอดภัยที่จะ revert ทันที
