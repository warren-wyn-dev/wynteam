# Product Task — WYN-002

Status: qa (Debug เสร็จแล้ว รอ AI QA & Security ทดสอบซ้ำรอบ 2)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (FAIL รอบ 1) → AI Debug Engineer (เสร็จ) → AI QA & Security (ถัดไป)

Feature: Authentication & Onboarding

Target User: วัยรุ่น / Gen Z ที่คุ้นเคยกับการ login ด้วย social account หรือเบอร์โทรศัพท์ ไม่คุ้นเคย/ไม่ชอบกรอก email+password

Dependencies: WYN-001 (เสร็จแล้ว), WYN-002 Design (เสร็จแล้ว)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป

---

## Debug Engineer Report (AI Debug Engineer)

Bug: 3 ปัญหาจาก QA รอบ 1 (`.wyn/tasks/bugs/WYN-002-authentication-onboarding.md`) — (1) Critical: ผู้ใช้ค้างหน้าเดิมหลัง sign-in สำเร็จ ไม่เข้า Home/Username Setup อัตโนมัติ, (2) Medium: username race condition ทำให้ error หายเงียบ, (3) Medium: OTP input ไม่ตรง design spec (ช่องเดียวแทนที่จะเป็น 6 ช่องแยก + ไม่มี accessibility)

Reproduction: ไล่โค้ดจริงทีละบรรทัดตาม Navigator stack ที่เกิดขึ้นจริง (ไม่ได้เดา):
1. `MaterialApp.home = AuthGate()` คือ route ฐาน (route แรกสุด)
2. `WelcomeScreen` → กด "เริ่มต้นใช้งาน" → `Navigator.push(AuthMethodScreen)` → stack: [AuthGate, AuthMethodScreen]
3. เลือก "ใช้เบอร์โทรศัพท์แทน" → `Navigator.push(PhoneEntryScreen)` → stack: [AuthGate, AuthMethodScreen, PhoneEntryScreen]
4. ส่ง OTP → `Navigator.push(OtpVerificationScreen)` → stack: [AuthGate, AuthMethodScreen, PhoneEntryScreen, OtpVerificationScreen]
5. กรอก OTP ถูก → `verifyPhoneOtp()` สำเร็จ → Supabase ยิง `AuthChangeEvent.signedIn` → **แต่ก่อนแก้ไข** `AuthGate` (route ฐานที่อยู่ล่างสุด) แค่ rebuild เนื้อหาของตัวเอง ไม่ pop หน้าที่ซ้อนอยู่ด้านบนออกเลย ผู้ใช้จึงยังเห็น `OtpVerificationScreen` อยู่ ทั้งที่ข้างใต้ `AuthGate` เปลี่ยนเป็นแสดง `UsernameSetupScreen` แล้ว

**สรุปสิ่งที่พบเพิ่มเติมนอกเหนือจาก QA รอบ 1**: QA รายงานปัญหาเฉพาะช่วง "ตั้ง username แล้วไม่ไป Home" แต่จากการ trace จริงพบว่า root cause กว้างกว่านั้นมาก — **ทุกเส้นทาง sign-in (Google, Apple, Phone OTP) มีปัญหาเดียวกัน** คือหน้าที่ถูก push ไว้ (AuthMethodScreen/PhoneEntryScreen/OtpVerificationScreen) ไม่เคยถูก pop กลับเมื่อ auth state resolve เลย ไม่ใช่แค่ตอน username step บันทึกไว้ที่ `.wyn/learning/MISTAKES.md` และ `.wyn/learning/LESSONS_LEARNED.md` แล้ว

Root Cause: แอปผสม 2 รูปแบบการนำทางเข้าด้วยกันโดยไม่มีจุดเชื่อม — (A) `AuthGate` ตัดสินใจเนื้อหาแบบ declarative จาก auth state ที่ route ฐาน (B) หน้าถัดไป ๆ ใช้ `Navigator.push` แบบ imperative ซ้อนทับขึ้นไปเรื่อย ๆ เมื่อ (A) เปลี่ยนสถานะ ไม่มีโค้ดจุดไหนสั่ง pop (B) กลับเลย ผู้ใช้จึงติดอยู่หน้าบนสุดตลอดไป (จนกว่าจะ restart แอปซึ่งสร้าง Navigator ใหม่ทั้งหมด)

Fix:
1. **`AuthGate`** — เพิ่ม `StreamSubscription` ฟัง `authStateChanges` โดยตรง (แยกจาก `StreamBuilder` ที่ใช้ build เนื้อหา) เมื่อเจอ event `AuthChangeEvent.signedIn` ให้เรียก `Navigator.of(context).popUntil((route) => route.isFirst)` ทันที — pop หน้าที่ค้างอยู่ทั้งหมดกลับมาที่ route ฐาน ทำให้ผู้ใช้เห็นเนื้อหาที่ `AuthGate` render ใหม่ (UsernameSetupScreen หรือ Home) ไม่ว่าจะ sign-in ด้วยวิธีไหนก็ตาม — แก้ปัญหาที่ QA เจอ (username→Home) และปัญหาที่ยังไม่ถูกรายงาน (OAuth/OTP→ค้าง) ในจุดเดียว
2. **`UsernameSetupScreen`** — หลัง `setUsername()` สำเร็จ เรียก `Navigator.of(context).pushReplacement(...HomeScreen())` ตรง ๆ เพราะการตั้ง username เป็นการเขียนข้อมูล Postgres ไม่ใช่ auth event จึง fix #1 ไม่ครอบคลุมกรณีนี้ ต้องนำทางเองแยกต่างหาก
3. **`AuthRepository.setUsername()`** — เพิ่ม `try/on PostgrestException catch (e)` เช็ค `e.code == '23505'` (unique_violation) แล้ว throw `UsernameTakenException()` เหมือนกรณี pre-check เจอซ้ำ แทนที่จะปล่อยให้ exception ดิบหลุดออกไปแบบไม่มีใครจับ
4. **OTP Input** — สร้าง widget ใหม่ `OtpBoxInput` (`app/lib/features/auth/presentation/widgets/otp_box_input.dart`) เป็น 6 กล่องแยก แต่ละกล่องห่อด้วย `Semantics(label: 'หลักที่ N จาก 6')` ตาม design spec เป๊ะ ๆ auto-advance focus ไปช่องถัดไปเมื่อพิมพ์ ถอยกลับเมื่อลบ แล้วแก้ `OtpVerificationScreen` ให้ใช้ widget นี้แทน `TextField` เดี่ยวเดิม

Files Changed:
- `app/lib/features/auth/presentation/auth_gate.dart`
- `app/lib/features/auth/presentation/username_setup_screen.dart`
- `app/lib/features/auth/data/auth_repository.dart`
- `app/lib/features/auth/presentation/otp_verification_screen.dart`
- `app/lib/features/auth/presentation/widgets/otp_box_input.dart` (ใหม่)
- `app/test/otp_box_input_test.dart` (ใหม่ — regression test)

Tests:
- `flutter analyze` (รันซ้ำอย่างอิสระหลังแก้) — **No issues found**
- `flutter test` (รันซ้ำอย่างอิสระหลังแก้) — **All tests passed! (6/6)** — 2 เคสเดิม + 4 เคสใหม่สำหรับ `OtpBoxInput` (render 6 กล่องพร้อม semantics label, auto-advance focus, `onCompleted` callback ถูกต้อง, `clear()` ทำงานถูกต้อง)
- **หมายเหตุสำคัญ**: ปัญหา #1 (pop-back หลัง sign-in) และ #2 (race condition) **ยังไม่มี automated regression test** เพราะ `AuthGate` สร้าง `AuthRepository` เองภายใน ไม่รองรับการ inject fake backend สำหรับ test — บันทึกเป็นข้อเสนอปรับปรุงใน `.wyn/learning/IMPROVEMENTS.md` แล้ว ยืนยันได้แค่ด้วยการไล่โค้ดด้วยตาเท่านั้นสำหรับ 2 ปัญหานี้

Regression Risk: ต่ำ-ปานกลาง — การแก้ #1 และ #2 ยังไม่มี automated test คุ้มครอง จึงมีความเสี่ยงที่จะ regress ได้ถ้ามีคนแก้โค้ดจุดนี้อีกในอนาคตโดยไม่รู้บริบท แนะนำให้ทำ IMPROVEMENTS.md item (dependency injection) ก่อน feature ถัดไปที่แตะ auth flow

Handoff to QA: ส่งกลับ AI QA & Security (`/qa`) ทดสอบรอบ 2 — ขอให้ตรวจสอบเป็นพิเศษว่า: (ก) ทุกเส้นทาง sign-in (ไม่ใช่แค่ phone OTP) จะ pop กลับถูกต้องหรือไม่ (ยืนยันด้วย code review เพราะยังรัน dynamic test ไม่ได้), (ข) OTP Input ใหม่ตรงตาม design spec ครบหรือยัง, (ค) ยังมี known issue ค้างอยู่ที่ยังไม่ได้แก้ในรอบนี้หรือไม่ (เช่น native URL scheme, Apple Sign-In capability — เป็น infra setup ไม่ใช่ code bug)

Final Status: **FAIL → แก้ไขแล้ว รอ QA รอบ 2 ยืนยัน**
