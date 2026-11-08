# ZOKY-LINE-002 ข้อ F — คำขออนุมัติขึ้น production (ร่าง รอ Founder)

สถานะ: **ยังไม่อนุมัติ ยังไม่ deploy** — Founder Gate ตาม AGENTS.md

> **ข้อควรระวัง (พบ 2026-11-07): baseline ผิด — ห้ามใช้เอกสารนี้ขออนุมัติตามเดิม**
> zoky.wynos.online ในโปรดักชันแสดงแบรนด์ ZOKY (title "เข้าสู่ระบบ — ZOKY") แต่โค้ด ZOKY UI อยู่ใน `release/zoky-web-20261018` (นำหน้า `main` 3640 commit, `main` มีของที่ release ไม่มี 112 commit) ไม่ใช่ใน `main`
> งานข้อ F ถูกสร้างและ QA/staging บน `main` จึงไม่ได้ทดสอบกับ UI ที่ ZOKY ใช้จริง ต้องย้ายการเปลี่ยนแปลงไป release branch แล้ว QA + staging ใหม่ (workflow staging มี input `zoky_release_sha` สำหรับกรณีนี้) ก่อนขออนุมัติ

## สิ่งที่จะขึ้น
กล่องแนะนำบน /food/login เมื่อเปิดใน LINE in-app browser (ข้อความ + ปุ่ม "เปิดในเบราว์เซอร์") เพื่อลดปัญหา Google ปฏิเสธ login ใน LINE
ไม่เปลี่ยน auth, DB, Merchant; ไม่มี migration; ไม่เพิ่ม dependency
ไฟล์ที่เปลี่ยน: web/components/food/line-login-guidance.tsx (ใหม่), food-auth.tsx, lib/line-liff.ts, lib/i18n/en.ts, app/food/food.css, tests/line-liff.test.mjs (+ เอกสาร docs/ .wyn/)
Branch `claude/great-cori-5zsvjp` อยู่หลัง `main` 0 commit, นำหน้า 8 commit (ตรวจ 2026-11-07)

## หลักฐาน
- QA & Security: รอบ 1 FAIL (M1–M3, L1), รอบ 2 FAIL (LOW 1 ข้อ), รอบ 3 PASS ไม่มี security finding
- test:line 12/12, test:i18n 46/46, tsc และ eslint ไม่มี error
- Staging run #2101 สำเร็จ: preflight/build, deploy preview, smoke, Playwright browser QA บน preview
- Preview: https://web-q3vqpnq3k-warren14.vercel.app/food/login

## ยังไม่ได้ตรวจ (ความเสี่ยงที่เหลือ)
- ยังไม่ได้ทดสอบบน LINE มือถือจริง (ดู staging-line-device-checklist.md) — ต้องมีผลก่อนอนุมัติ
- ไม่ทราบว่า NEXT_PUBLIC_LIFF_ID_FOOD ตั้งใน build หรือไม่ (ถ้าไม่ตั้ง จะเห็นเฉพาะข้อความสำรอง)
- ไม่มีข้อความช่วยเรื่อง "ลืมรหัสผ่าน" (ตัดออก)
- APPROVALS.md ระบุว่า production มีฟีเจอร์ (store QR ฯลฯ) ที่ไม่อยู่ใน tree นี้ ยังไม่ได้ยืนยันว่า production deploy มาจาก main — ต้องยืนยันก่อน merge

## การ deploy
Merge เข้า `main` deploy production อัตโนมัติผ่าน `wyn-158-production-deploy.yml` (ตาม docs/engineering/WEB_STAGING.md) ต้องผ่าน required checks/reviews ตาม GIT_WORKFLOW.md
ก่อน merge: ลบกฎ branch `claude/great-cori-5zsvjp` ออกจาก environment `production`

## Rollback
Vercel Instant Rollback ไปยัง production deployment ก่อนหน้า หรือ revert merge commit บน `main` (ไม่มี migration จึงไม่มีผลต่อข้อมูล)

## สิ่งที่ Founder ต้องตัดสินใจ
- [ ] ผลทดสอบบน LINE จริงผ่าน
- [ ] ยืนยัน baseline ของ production (หัวข้อ "ยังไม่ได้ตรวจ")
- [ ] อนุมัติ merge/deploy production อย่างชัดเจน (ระบุเวลา)


---
## อัปเดต 2026-11-08: Release candidate บน baseline production

- Branch `claude/zoky-line-002-release-candidate` (commit `53f9e494`) = production baseline `a70cbb03` + cherry-pick 2 commit: (1) กล่องแนะนำที่ /food/login (2) กฎ redirect ข้าม LIFF browser **ไม่รวม** การแก้ workflow `--force` (ใช้เฉพาะ staging)
- ตรวจแล้ว: test:line 19/19, test:share-links 20/20, test:i18n 51/51, tsc ไม่มี error; QA ผ่านทั้งสองส่วนบน commit ต้นทาง (รวม 2 test WebKit ที่รันไม่ได้เพราะเครื่องไม่มีเบราว์เซอร์)
- Staging #2104 ผ่านกับ commit ที่มีข้อ (1) เท่านั้น ข้อ (2) ยังไม่ผ่าน staging
- ความเสี่ยงที่เหลือ (MEDIUM): รูปแบบ UA จริงของ LIFF บนเครื่องจริงยังไม่ได้ยืนยัน (fail-safe = พฤติกรรมเดิม)
- วิธี release: workflow production ในรีโปจำกัดเฉพาะ `main` (`wyn-158-production-deploy.yml`, `web-next-phase5-production.yml`) แต่ production ปัจจุบัน deploy จาก `fix/zoky-qr-line-entry-20261105` (Vercel source=redeploy) จึง **ต้องให้ Founder ระบุวิธี release** ผมไม่เดาและไม่ promote preview (build ด้วย env ของ preview อาจต่างจาก production)
- ห้าม merge เข้า `main`: ประวัติของ `main` กับสาย ZOKY ไม่มี merge base ร่วมกัน
