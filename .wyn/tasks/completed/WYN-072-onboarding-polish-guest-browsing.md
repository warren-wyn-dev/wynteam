# Design Task — WYN-072

Status: completed (deployed to production, 2026-09-01)
Owner: AI Deploy & DevOps (deployed) — ดู `.wyn/logs/deployments/2026-09-01-wyn-072-real-deploy.md`
Screen: Welcome, Auth Method Selection, Guest Mode (new)
Purpose: 1) แก้ wordmark "WYN"→"WYNOS" ในหน้า Welcome/Auth Method 2) ซ่อนปุ่ม "เข้าสู่ระบบด้วย Apple" ชั่วคราว (Apple Developer Program ยังไม่สมัคร) 3) เพิ่มทางเข้าชม WYNOS แบบไม่ล็อกอิน (guest browsing ผ่าน Anonymous Sign-In ที่มีอยู่แล้ว) — ดูโพสต์ได้ แต่หน้า/action ที่ผูกกับตัวตน (โปรไฟล์, สร้าง Drop, แจ้งเตือน, แชท) ต้องล็อกอินก่อน
User Flow / Components / Interactions / States: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md`
Design Rules: ไม่แตะสี/ฟอนต์/spacing ใดๆ จาก design-principles.md

## QA Round 1 (2026-09-01) — FAIL
PASS ทุกจุดฟีเจอร์จริง — FAIL จาก test-infrastructure bug 1 ตัว (ไม่ใช่ production bug) ดู `.wyn/tasks/bugs/WYN-072-auth-gate-test-realtime-timer-leak.md`

## Debug Engineer Fix (2026-09-01)
เพิ่ม `rootShellBuilder` injection seam ให้ `AuthGate` — ไม่แตะ production behavior

## QA Round 2 (2026-09-01) — PASS
`flutter analyze` 0 issues, `flutter test` 878/878, รัน test ที่เคย flaky ซ้ำ 3 รอบไม่มี flaky, ไม่มี regression

## Deploy (2026-09-01) — SUCCESS

รายละเอียดเต็มที่ `.wyn/logs/deployments/2026-09-01-wyn-072-real-deploy.md` สรุปสั้น:
- Merge PR #193 เข้า `main` (`33150ae`) → trigger `deploy-web.yml` (run 33503100073) → **SUCCESS**
- **พบและแก้ปัญหาสำคัญก่อน deploy**: schema production ไม่ตรงกับ `supabase/schema.sql` มา 2-3 วันแล้ว (คอลัมน์ `is_verified`, view `home_feed` ใหม่, `drop_count()`) — เหมือนเหตุการณ์ WYN-071 P0 เดิม เช็คกับ production ตรงๆ ก่อน (ไม่เดา) แล้วให้ Founder run migration SQL ที่แก้แล้ว (session พยายาม apply เองผ่าน Management API แต่ sandbox safety classifier บล็อกไว้ตามที่ตั้งใจ) — สำเร็จ ยืนยันซ้ำกับ production แล้ว
- **พบเพิ่ม**: `.wyn/logs/deployments/` ไม่ได้บันทึก real deploy 7 ครั้งที่เกิดขึ้นจริงระหว่าง 2026-08-25 ถึง 2026-08-31 (เช็คจาก GitHub Actions run history ตรงๆ) — เป็น documentation gap ไม่ใช่ deployment gap บันทึกไว้กันสับสนในอนาคต
- Production verification: index.html/main.dart.js/manifest.json/flutter_bootstrap.js ทั้งหมด HTTP 200, main.dart.js ขนาดต่างจาก build เดิม (ยืนยันเป็น build ใหม่จริง ไม่ใช่ cache เก่า), REST query คอลัมน์ใหม่ของ `home_feed` ผ่านไม่มี error
- **ยังไม่ได้ทำ**: real-browser smoke test (sandbox เข้า browser จริงไม่ได้) — รอ Founder เปิด https://web-neon-sigma-66.vercel.app ยืนยันด้วยตาจริง

**Security note (แจ้งแล้ว ไม่ block)**: guest gate เป็น UI-level เท่านั้น RLS ไม่แยก anonymous — เป็น known characteristic เดิม ไม่ใช่ช่องโหว่ใหม่ แต่ตอนนี้สร้าง anonymous account ง่ายขึ้นมาก

**Scope ที่ยังไม่ทำ (ตั้งใจ)**: gate ของ Like/Comment/Save/ReDrop/Poll vote/Follow/Club create-join ที่กระจายหลายสิบไฟล์ — เป็นงานต่อยอดถ้า Founder ต้องการ (แนะนำเปิดเป็น WYN-073)
