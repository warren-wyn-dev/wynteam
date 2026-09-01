# Design Task — WYN-072

Status: bugs (QA round 1 — FAIL, 1 test-infra bug found, blocked on Debug Engineer)
Owner: AI QA & Security → ส่งต่อ AI Debug Engineer
Screen: Welcome, Auth Method Selection, Guest Mode (new)
Purpose: 1) แก้ wordmark "WYN"→"WYNOS" ในหน้า Welcome/Auth Method 2) ซ่อนปุ่ม "เข้าสู่ระบบด้วย Apple" ชั่วคราว (Apple Developer Program ยังไม่สมัคร) 3) เพิ่มทางเข้าชม WYNOS แบบไม่ล็อกอิน (guest browsing ผ่าน Anonymous Sign-In ที่มีอยู่แล้ว) — ดูโพสต์ได้ แต่หน้า/action ที่ผูกกับตัวตน (โปรไฟล์, สร้าง Drop, แจ้งเตือน, แชท, Like/Comment/Save/ReDrop/Poll vote/Follow, Club create/join) ต้องล็อกอินก่อน
User Flow / Components / Interactions / States: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md`
Responsive Behavior: ไม่เปลี่ยนจากเดิม (ใช้ layout/component เดิมทั้งหมด)
Accessibility: Semantics label ชัดเจนบนปุ่ม guest ใหม่ + dialog gate ใช้ `AlertDialog` มาตรฐาน (trap focus ตาม Material default)
Design Rules: ไม่แตะสี/ฟอนต์/spacing ใดๆ จาก design-principles.md

## QA Round 1 ผลสรุป (2026-09-01) — ดู QA output เต็มที่ session ส่งมอบ

**PASS**: flutter analyze สะอาด (0 issues), `User.isAnonymous` compile ผ่านจริง (ยืนยันกับ gotrue 2.27.2 จริง — pubspec.lock เดิมที่ Coding อ้างว่าเป็น 2.7.1 นั้นอ่านผิดแถว จริงๆ คือ 2.27.2), guest เข้า Home ได้จริงไม่ค้าง Username Setup, gate ทำงานจริงครบ 4 จุด (โปรไฟล์/+/แจ้งเตือน/แชท) ยืนยันด้วย widget test ใหม่ 6 ตัวที่ QA เพิ่มเอง (`test/root_shell_guest_gate_test.dart`), ปุ่ม Apple หายจาก UI จริงไม่กระทบปุ่มอื่น, กด "สมัคร/เข้าสู่ระบบ" แล้ว session ถูก signOut จริง

**FAIL**: `flutter test` เต็ม suite ได้ 876/877 — เทสต์เดียวที่แดงคือ `test/auth_gate_test.dart`'s "a guest (Anonymous Sign-In) skips Username Setup and lands on RootShell directly" (ที่ AI Coding เพิ่มเอง) ล้มเหลวด้วย `!timersPending` (Realtime channel pending-disconnect Timer leak เมื่อ AuthGate ไปถึง RootShell จริงในบรรยากาศ widget test) — **ยืนยันแล้วว่าไม่ใช่บั๊กใน production code** (logic ที่ทดสอบถูกต้อง 100%, เป็น test-infrastructure gap เท่านั้น) รายละเอียด root cause + fix ที่แนะนำเต็มๆ ที่ `.wyn/tasks/bugs/WYN-072-auth-gate-test-realtime-timer-leak.md`

**Security finding (ไม่ block แต่ Founder ควรรู้)**: gate ที่เพิ่มเป็น UI-level เท่านั้น ยืนยันแล้วว่า `supabase/schema.sql` ไม่มีจุดไหนเช็ค `is_anonymous` เลย — guest ที่ยิง API ตรง (ข้าม UI) ยังคง Like/Comment/Post ได้จริงทางเทคนิค เป็น known/pre-existing characteristic ของ Anonymous Sign-In (อนุมัติไว้แล้ว 2026-08-16) ไม่ใช่ช่องโหว่ใหม่จาก WYN-072 แต่ WYN-072 ทำให้สร้าง anonymous account ได้ง่าย/เด่นชัดขึ้นมาก (มีปุ่มบนหน้าเข้าสู่ระบบเลย) จึงเพิ่มโอกาสถูกใช้สแปม/หลบ moderation ที่ผูกกับตัวตนได้มากขึ้นในทางปฏิบัติ

**Known gap ที่ยังไม่ verify เต็มที่**: การไหลจริง "guest กด สมัคร/เข้าสู่ระบบ ใน dialog → signOut → AuthGate เห็น signedOut event → popUntil → กลับไป WelcomeScreen จริง" ยืนยันแค่บางส่วน (signOut() เคลียร์ session จริง ยืนยันด้วย test) — ส่วน AuthGate's popUntil/WelcomeScreen re-render ที่เกิดจากจุดนี้โดยเฉพาะยังไม่มี integration test ตรงๆ (ติดปัญหา Realtime timer เดียวกับข้างบน) แต่ mechanism เดียวกันถูกพิสูจน์แล้วว่าทำงานถูกต้องในบริบทอื่น (AccountRestrictedScreen's "ตกลง" test)

Handoff to Debug Engineer: แก้ตาม `.wyn/tasks/bugs/WYN-072-auth-gate-test-realtime-timer-leak.md` (เพิ่ม `rootShellBuilder` optional param ให้ `AuthGate` เพื่อให้ test inject placeholder แทน `RootShell` จริงได้) แล้วส่งกลับ AI QA & Security รันเต็ม suite ยืนยัน 877/877 ก่อนอนุมัติ deploy — ห้าม deploy จนกว่าจะ PASS รอบใหม่
