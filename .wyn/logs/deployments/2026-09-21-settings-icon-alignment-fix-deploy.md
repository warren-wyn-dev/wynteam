# Deployment Log — Settings Row Icon Alignment Fix

**Release**: แก้ไอคอนในหน้า Settings ที่ไม่อยู่กึ่งกลางกล่อง (Founder รายงานจาก screenshot)
**Build Status**: `lint`/`typecheck`/`build` สะอาด — regression suite 106/106 ผ่านบน `chromium-desktop`/`chromium-android`

**Root Cause**:
`app/system-parity-lock.css` มี rule `.settings-row > span:first-child` ที่ตั้งใจ style
ช่อง title/description (`.settings-row-copy`) แต่เขียนโดยอิง structural position แทน class
เมื่อแถวมี leading icon, span ของไอคอน (`.settings-leading-icon`) จะกลายเป็น first-child จริง
แทน — rule นี้มี specificity สูงกว่า `.settings-leading-icon` ใน `system-parity-final.css`
เลย override `display: grid; place-items: center;` ด้วย `display: flex; flex-direction: column;`
ทำให้ SVG ไปติดขอบบนของกล่อง 34px แทนที่จะอยู่กึ่งกลาง

**Verification**:
- Live-verified ด้วย throwaway Playwright fixture (ลบก่อน commit) — เช็ค `getBoundingClientRect()`
  ของ SVG เทียบกล่องไอคอน ก่อน/หลังแก้ ยืนยันว่าไอคอนกึ่งกลางจริงหลังแก้ และแถวไม่มีไอคอนยัง layout เดิม
- `npx playwright test --project=chromium-desktop --project=chromium-android` — 106/106 ผ่าน

**Changes**:
- `web/app/system-parity-lock.css` — เปลี่ยน `.settings-row > span:first-child` เป็น
  `.settings-row > .settings-row-copy` (target ด้วย class แทนตำแหน่ง)

**PR**: [#581](https://github.com/warren-wyn-dev/wynteam/pull/581) (`claude/web-beta1-readiness-7hysen` → `main`)

**Rollback Plan**: Revert PR — diff เป็น CSS selector เดียว บรรทัดเดียว ไม่กระทบ business logic
ปลอดภัยที่จะ revert ทันทีถ้าจำเป็น

**Deployment Result**:
- `WYN-158 Production Deploy` run #167 ยิงตามการ merge สำเร็จ และถูก superseded โดย run #168
  (deploy ของ PR #582) ที่รวมการเปลี่ยนแปลงนี้ไปด้วยและจบสถานะ **success** ยืนยันว่า fix นี้ขึ้น
  `wynos.online` แล้ว — ดูรายละเอียดที่ 2026-09-21-follow-button-and-push-toggle-fix-deploy.md
