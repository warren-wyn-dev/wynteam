# Design Task — WYN-072

Status: review (Debug Engineer fixed the QA round 1 bug, 2026-09-01 — awaiting QA round 2)
Owner: AI Debug Engineer (fixed) → ส่งต่อ AI QA & Security
Screen: Welcome, Auth Method Selection, Guest Mode (new)
Purpose: 1) แก้ wordmark "WYN"→"WYNOS" ในหน้า Welcome/Auth Method 2) ซ่อนปุ่ม "เข้าสู่ระบบด้วย Apple" ชั่วคราว (Apple Developer Program ยังไม่สมัคร) 3) เพิ่มทางเข้าชม WYNOS แบบไม่ล็อกอิน (guest browsing ผ่าน Anonymous Sign-In ที่มีอยู่แล้ว) — ดูโพสต์ได้ แต่หน้า/action ที่ผูกกับตัวตน (โปรไฟล์, สร้าง Drop, แจ้งเตือน, แชท, Like/Comment/Save/ReDrop/Poll vote/Follow, Club create/join) ต้องล็อกอินก่อน
User Flow / Components / Interactions / States: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md`
Responsive Behavior: ไม่เปลี่ยนจากเดิม (ใช้ layout/component เดิมทั้งหมด)
Accessibility: Semantics label ชัดเจนบนปุ่ม guest ใหม่ + dialog gate ใช้ `AlertDialog` มาตรฐาน (trap focus ตาม Material default)
Design Rules: ไม่แตะสี/ฟอนต์/spacing ใดๆ จาก design-principles.md

## QA Round 1 (2026-09-01) — FAIL

PASS ทุกจุดฟีเจอร์จริง (wordmark, ปุ่ม Apple ซ่อน, guest bypass Username Setup, gate 4 จุดทำงานจริงยืนยันด้วย test ใหม่, signOut จริง) — FAIL เพราะ `flutter test` เต็ม suite ได้ 876/877 จาก test-infrastructure bug 1 ตัว (ไม่ใช่ production bug) รายละเอียดเต็มที่ `.wyn/tasks/bugs/WYN-072-auth-gate-test-realtime-timer-leak.md`

**Security finding (ไม่ block แต่ Founder ควรรู้)**: gate ที่เพิ่มเป็น UI-level เท่านั้น ยืนยันแล้วว่า `supabase/schema.sql` ไม่มีจุดไหนเช็ค `is_anonymous` เลย — guest ที่ยิง API ตรง (ข้าม UI) ยังคง Like/Comment/Post ได้จริงทางเทคนิค เป็น known/pre-existing characteristic ของ Anonymous Sign-In (อนุมัติไว้แล้ว 2026-08-16) ไม่ใช่ช่องโหว่ใหม่จาก WYN-072 แต่ WYN-072 ทำให้สร้าง anonymous account ได้ง่าย/เด่นชัดขึ้นมาก (มีปุ่มบนหน้าเข้าสู่ระบบเลย) จึงเพิ่มโอกาสถูกใช้สแปม/หลบ moderation ที่ผูกกับตัวตนได้มากขึ้นในทางปฏิบัติ

## Debug Engineer Fix (2026-09-01)

เพิ่ม `rootShellBuilder` optional constructor param ให้ `AuthGate` (default `() => const RootShell()`, pattern เดียวกับ `authRepository`/`moderationRepository` ที่มีอยู่แล้ว) แก้ `auth_gate_test.dart`'s guest test ให้ inject placeholder widget แทน `RootShell` จริง — ไม่แตะ production behavior เลย (ไม่มี call site จริงส่ง param นี้)

ยืนยันด้วย:
- `flutter analyze`: 0 issues
- `flutter test` เต็ม suite: **878/878 ผ่านหมด**

รายละเอียดเต็มที่ `.wyn/tasks/bugs/WYN-072-auth-gate-test-realtime-timer-leak.md` (ส่วน Resolution)

Handoff: ส่งกลับ AI QA & Security (`/qa`) รอบ 2 — ตรวจแค่ยืนยัน `flutter analyze`/`flutter test` เขียวจริง 878/878 (ฟีเจอร์จริงผ่านหมดแล้วตั้งแต่รอบ 1) ถ้าผ่านให้ย้าย task ไป `.wyn/tasks/approved/` และส่งต่อ AI Deploy & DevOps — ควรแจ้ง Founder เรื่อง security finding ข้างบนก่อน deploy ด้วย (ไม่ block แต่ Founder ควรรับทราบ)
