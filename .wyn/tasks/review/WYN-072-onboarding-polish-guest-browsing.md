# Design Task — WYN-072

Status: review
Owner: AI Coding (implemented) — ส่งต่อ AI QA & Security
Screen: Welcome, Auth Method Selection, Guest Mode (new)
Purpose: 1) แก้ wordmark "WYN"→"WYNOS" ในหน้า Welcome/Auth Method 2) ซ่อนปุ่ม "เข้าสู่ระบบด้วย Apple" ชั่วคราว (Apple Developer Program ยังไม่สมัคร) 3) เพิ่มทางเข้าชม WYNOS แบบไม่ล็อกอิน (guest browsing ผ่าน Anonymous Sign-In ที่มีอยู่แล้ว) — ดูโพสต์ได้ แต่หน้า/action ที่ผูกกับตัวตน (โปรไฟล์, สร้าง Drop, แจ้งเตือน, แชท, Like/Comment/Save/ReDrop/Poll vote/Follow, Club create/join) ต้องล็อกอินก่อน
User Flow: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-072-onboarding-polish-guest-browsing.md`
Components: ดูรายละเอียดเต็มในเอกสาร design
Interactions: ดูรายละเอียดเต็มในเอกสาร design
States: ดูรายละเอียดเต็มในเอกสาร design
Responsive Behavior: ไม่เปลี่ยนจากเดิม (ใช้ layout/component เดิมทั้งหมด)
Accessibility: Semantics label ชัดเจนบนปุ่ม guest ใหม่ + dialog gate ใช้ `AlertDialog` มาตรฐาน (trap focus ตาม Material default)
Design Rules: ไม่แตะสี/ฟอนต์/spacing ใดๆ จาก design-principles.md — reuse component เดิมทั้งหมด (OutlinedButton/TextButton/AlertDialog มาตรฐาน), reuse pattern `_phoneLoginEnabled` เดิมสำหรับซ่อนปุ่ม Apple, ห้ามเขียน gate dialog ซ้ำมือทีละจุด ต้องมี helper เดียวใช้ร่วมกัน

## สถานะ implementation จริง (AI Coding, 2026-09-01)

**ทำเสร็จแล้ว**:
- Wordmark "WYN"→"WYNOS" (Welcome + หัวข้อ Auth Method screen)
- ปุ่ม Apple ซ่อนด้วย `_appleLoginEnabled = false` (`signInWithApple()` ยังอยู่ใน `AuthRepository`)
- ปุ่ม "เข้าชม WYNOS ได้เลย" ต่อกับ `signInAnonymously()` แล้วใน `auth_method_screen.dart`
- `AuthGate` ข้าม Username Setup ให้ anonymous session ตรงเข้า `RootShell`
- `requireRealAccount()` gate ใหม่ (`app/lib/features/auth/presentation/widgets/guest_gate.dart`) ต่อเข้าแล้ว 4 จุด: แท็บโปรไฟล์, ปุ่ม "+" สร้าง Drop, แท็บแจ้งเตือน (ทั้ง 3 จุดใน `root_shell.dart`), ปุ่มแชทใน Home header (`home_feed_screen.dart`)
- Test อัปเดต: `widget_test.dart` (Apple หาย + ปุ่ม guest ปรากฏ + wordmark WYNOS), `auth_gate_test.dart` (test ใหม่: guest ข้าม Username Setup เข้า RootShell ตรง)

**ยังไม่ได้ทำ (ตั้งใจ ไม่ใช่ตกหล่น) — ต้องตัดสินใจก่อนว่าจะทำต่อหรือไม่**: gate ของ Like/Comment/Save/ReDrop/Poll vote/Follow/Club create-join ที่กระจายอยู่หลายสิบไฟล์ทั่วแอป (Home feed cards, Search results, Club posts, Drop/Pop detail, Profile ของคนอื่น ฯลฯ) — Founder ยืนยันตรงแค่ "หน้าสำคัญเช่นโปรไฟล์" ส่วนที่เหลือเป็นการตีความต่อยอดของ AI Design ไม่ใช่คำสั่งตรง จึงยังไม่ implement เพื่อไม่ให้เป็น sweep ใหญ่ที่เสี่ยง error โดยไม่มี design/QA review เป็นจุดๆ — ควรเป็น task ต่อยอดแยก (WYN-073?) ถ้า Founder ต้องการ

**ความเสี่ยงด้านความปลอดภัยที่ต้องรู้**: gate ที่เพิ่มเป็น UI-level เท่านั้น ไม่ใช่ RLS-level — guest ที่ยิง API ตรงยังคง Like/Comment/Post ได้จริงในทางเทคนิค (RLS ปัจจุบันไม่แยก `is_anonymous`) นี่ไม่ใช่ security hole ใหม่ (เหมือนเดิมทุกจุดที่เคยมีอยู่แล้วในระบบ authenticated role) แต่ QA ควรรู้ขอบเขตนี้ชัดเจน

**ยังไม่ได้ยืนยัน**: `flutter analyze`/`flutter test` — ไม่มี Flutter SDK ในสภาพแวดล้อมที่เขียนโค้ดรอบนี้ (ดู Coding output เต็มในข้อความส่งมอบ) ต้อง QA/CI รันจริงก่อนอนุมัติ รวมถึงยืนยัน `User.isAnonymous` compile ผ่านจริงกับ `gotrue` 2.7.1

Handoff: ส่งต่อ AI QA & Security (`/qa`) — เน้นตรวจ: (1) `flutter analyze`/`flutter test` ผ่านสะอาดจริง โดยเฉพาะ `User(isAnonymous: ...)` compile ผ่าน (2) guest กดปุ่ม "เข้าชม WYNOS ได้เลย" แล้วเข้า Home ได้จริงไม่ค้างที่ Username Setup (3) แตะโปรไฟล์/+/แจ้งเตือน/แชท ขณะเป็น guest แล้วเจอ dialog gate จริง ไม่ผ่านไปหน้าจริง (4) กด "สมัคร/เข้าสู่ระบบ" ใน dialog แล้ว anonymous session ถูก signOut จริง กลับไปที่ WelcomeScreen ไม่ค้าง session ซ้อน (5) ปุ่ม Apple หายจาก UI จริงแต่ไม่กระทบ Google/อีเมล/build อื่นๆ — ห้าม deploy จนกว่า QA ผ่าน
