# Design Task — WYN-072

Status: approved (QA round 2 PASS, 2026-09-01) — พร้อม Deploy
Owner: AI QA & Security (approved) → ส่งต่อ AI Deploy & DevOps
Screen: Welcome, Auth Method Selection, Guest Mode (new)
Purpose: 1) แก้ wordmark "WYN"→"WYNOS" ในหน้า Welcome/Auth Method 2) ซ่อนปุ่ม "เข้าสู่ระบบด้วย Apple" ชั่วคราว (Apple Developer Program ยังไม่สมัคร) 3) เพิ่มทางเข้าชม WYNOS แบบไม่ล็อกอิน (guest browsing ผ่าน Anonymous Sign-In ที่มีอยู่แล้ว) — ดูโพสต์ได้ แต่หน้า/action ที่ผูกกับตัวตน (โปรไฟล์, สร้าง Drop, แจ้งเตือน, แชท) ต้องล็อกอินก่อน
User Flow / Components / Interactions / States: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md`
Design Rules: ไม่แตะสี/ฟอนต์/spacing ใดๆ จาก design-principles.md

## QA Round 1 (2026-09-01) — FAIL
PASS ทุกจุดฟีเจอร์จริง — FAIL จาก test-infrastructure bug 1 ตัว (ไม่ใช่ production bug) ดู `.wyn/tasks/bugs/WYN-072-auth-gate-test-realtime-timer-leak.md`

## Debug Engineer Fix (2026-09-01)
เพิ่ม `rootShellBuilder` injection seam ให้ `AuthGate` — ไม่แตะ production behavior

## QA Round 2 (2026-09-01) — PASS

ตรวจซ้ำอิสระ (ไม่เชื่อตัวเลขที่ Debug Engineer รายงานเฉยๆ รันเองใหม่ทั้งหมด):
- `flutter analyze`: 0 issues
- `flutter test` เต็ม suite: **878/878 ผ่านหมด**
- รัน `auth_gate_test.dart` + `root_shell_guest_gate_test.dart` ซ้ำ 3 รอบติดกันเพื่อเช็ค flaky (บั๊กเดิมเป็นเรื่อง Timer/async) — ผ่านทุกรอบ ไม่มี flaky
- ยืนยันไม่มี regression ในฟีเจอร์ที่ QA รอบ 1 เคย PASS ไว้ (อยู่ในผลรัน suite เต็มด้านบนแล้ว)

**Final Status: PASS**

**สิ่งที่ต้องแจ้ง Founder ก่อน/พร้อม deploy (ไม่ block)**: gate ที่เพิ่มเป็น UI-level เท่านั้น RLS ไม่แยก anonymous — guest ที่ยิง API ตรงยัง Like/Comment/Post ได้จริงทางเทคนิค เป็น known characteristic ของ Anonymous Sign-In เดิม ไม่ใช่ช่องโหว่ใหม่ แต่ตอนนี้สร้าง anonymous account ได้ง่ายขึ้นมากเพราะมีปุ่มเด่นชัด

**Scope ที่ยังไม่ทำ (ตั้งใจ)**: gate ของ Like/Comment/Save/ReDrop/Poll vote/Follow/Club create-join ที่กระจายหลายสิบไฟล์ — Founder สั่งตรงแค่ "เช่นโปรไฟล์" ส่วนที่เหลือเป็นการตีความต่อยอด ยังไม่ implement ตามที่ตกลงไว้ตั้งแต่ Coding round

Handoff: ส่งต่อ AI Deploy & DevOps (`/deploy`) — deploy ได้เมื่อ Founder พร้อม (ต้องขอยืนยันก่อนเริ่ม deploy จริงตามกติกาการเปลี่ยนแปลงที่กระทบ production)
