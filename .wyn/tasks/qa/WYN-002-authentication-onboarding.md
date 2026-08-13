# Product Task — WYN-002

Status: qa (Debug รอบ 2 เสร็จแล้ว รอ AI QA & Security ทดสอบรอบ 3)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (FAIL รอบ 1, FAIL รอบ 2) → AI Debug Engineer (แก้รอบ 1, แก้รอบ 2) → AI QA & Security (ถัดไป — รอบ 3)

Feature: Authentication & Onboarding

Target User: วัยรุ่น / Gen Z

Dependencies: WYN-001 (เสร็จแล้ว), WYN-002 Design (เสร็จแล้ว)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป

---

## Debug Engineer Report — รอบ 2 (AI Debug Engineer)

Bug: Regression Critical จาก QA รอบ 2 (`.wyn/tasks/bugs/WYN-002-authentication-onboarding.md`) — ผู้ใช้ใหม่ที่เพิ่งตั้ง username สำเร็จแล้ว logout ไม่ได้ ต้อง force-restart แอป

Reproduction: ยืนยันตาม repro steps ที่ QA เขียนไว้ทุกขั้นตอน — ไล่โค้ดจริงพบว่า `UsernameSetupScreen._submit()` เรียก `Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()))` ซึ่งแทนที่ route ที่ `AuthGate` ครองอยู่ (เพราะ `UsernameSetupScreen` ถูก return จาก `AuthGate.build()` โดยตรง ไม่ได้ถูก push แยก) ทำให้ `AuthGate` (และ `_authSubscription`) ถูก dispose ทิ้งจริงตามที่ QA วิเคราะห์ไว้ — **ไม่ได้เดา ยืนยันจาก source code ตรง ๆ**

Root Cause: การแก้บั๊ก Critical รอบ 1 (ผู้ใช้ค้างหน้าเดิมหลังตั้ง username) เลือกวิธี "สร้าง route ใหม่แทนที่ route เดิม" (`pushReplacement`) แทนที่จะ "บอกให้ widget ที่ควบคุม route เดิมอยู่ (`AuthGate`) rebuild ตัวเอง" ทำให้ `HomeScreen` ของผู้ใช้กลุ่มนี้ไม่ได้เป็นลูกของ `AuthGate` เหมือนเส้นทางผู้ใช้เดิม (returning user) จึงไม่มี auth-state listener เหลืออยู่เมื่อ logout

Fix:
1. **`UsernameSetupScreen`** — เอา `Navigator.pushReplacement`/import `HomeScreen` ออกทั้งหมด เปลี่ยนเป็นรับ `required VoidCallback onUsernameSet` จาก constructor แล้วเรียก `widget.onUsernameSet()` แทนหลัง `setUsername()` สำเร็จ (ไม่แตะ Navigator เองอีกต่อไป)
2. **`AuthGate`** — ส่ง `onUsernameSet: () => setState(() {})` ให้ `UsernameSetupScreen` ตอนสร้าง เมื่อถูกเรียก `AuthGate` จะ rebuild ตัวเอง ทำให้ `FutureBuilder<bool>` เช็ค `hasUsername()` ใหม่ (ตอนนี้ return `true` เพราะเขียนลง DB ไปแล้ว) แล้ว return `HomeScreen()` เป็นลูกของ `AuthGate` เอง **เหมือนเส้นทางผู้ใช้เดิมทุกประการ** — `AuthGate` (และ auth-state subscription) จึงยังอยู่ครบ ไม่ถูกทำลาย logout จึงทำงานถูกต้องสำหรับผู้ใช้ทุกกลุ่มแบบเดียวกัน

Files Changed:
- `app/lib/features/auth/presentation/username_setup_screen.dart`
- `app/lib/features/auth/presentation/auth_gate.dart`

Tests:
- `flutter analyze` (รันซ้ำอย่างอิสระ) — **No issues found**
- `flutter test` (รันซ้ำอย่างอิสระ) — **All tests passed! (6/6)** ไม่มี regression กับ test เดิม
- **ไม่มี automated regression test สำหรับ fix นี้โดยเฉพาะ** เหตุผลเดียวกับรอบที่แล้ว — `AuthRepository` ยังไม่ inject ได้ ทดสอบ full submit flow (ที่ต้องเรียก `setUsername()` จริง) ในรูปแบบ widget test ไม่ได้ถ้าไม่มี fake backend — **ยกระดับ priority ของ IMPROVEMENTS.md item นี้เป็นสูงแล้ว** เพราะช่องว่างนี้ทำให้เกิด regression จริงมาแล้ว 1 ครั้ง

Regression Risk: กลาง — วิธีแก้ใหม่ (callback → parent setState) เป็น pattern เดียวกับเส้นทาง "ผู้ใช้เดิม" ที่ QA ยืนยันแล้วว่าทำงานถูกต้อง (test case #6 ของ QA รอบ 2) จึงมั่นใจสูงกว่าการแก้ครั้งก่อน แต่ยังไม่มี automated test คุ้มครองอยู่ดี ควรระวังเป็นพิเศษถ้ามีคนแก้ไฟล์ 2 ไฟล์นี้อีกในอนาคต

Handoff to QA: ส่งกลับ AI QA & Security (`/qa`) ทดสอบรอบ 3 — ขอให้เน้นตรวจสอบเป็นพิเศษว่า: (ก) `HomeScreen` ของผู้ใช้ใหม่ (ผ่าน username setup) ตอนนี้เป็นลูกของ `AuthGate` เหมือนผู้ใช้เดิมจริงหรือไม่ (เทียบโครงสร้าง build tree) (ข) logout จากทั้ง 2 เส้นทาง (ผู้ใช้ใหม่/ผู้ใช้เดิม) ทำงานเหมือนกันหรือไม่ (ค) ไม่มี regression กับ fix อื่น ๆ จากรอบก่อนหน้า

Final Status: **แก้ไขแล้ว รอ QA รอบ 3 ยืนยัน**
