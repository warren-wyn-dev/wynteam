# Product Task — WYN-002

Status: bugs (QA รอบ 2 — FAIL อีกครั้ง พบ regression ใหม่จากการแก้ครั้งก่อน)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (FAIL รอบ 1) → AI Debug Engineer (แก้รอบ 1) → AI QA & Security (FAIL รอบ 2) → AI Debug Engineer (ถัดไป)

Feature: Authentication & Onboarding

Target User: วัยรุ่น / Gen Z

Dependencies: WYN-001 (เสร็จแล้ว), WYN-002 Design (เสร็จแล้ว)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป

---

## QA & Security Report — รอบ 2 (AI QA & Security)

Feature: WYN-002 — Authentication & Onboarding (หลัง Debug Engineer แก้ 3 บั๊กจาก QA รอบ 1 ใน PR #8)

Environment: Code review + static analysis บน `main` หลัง merge PR #8 ใช้ Flutter SDK 3.47.0 stable — เงื่อนไขเดียวกับรอบ 1 (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. `AuthGate` pop กลับ route ฐานถูกต้องเมื่อเจอ `AuthChangeEvent.signedIn` (code review — fix #1 จากรอบ 1)
4. `setUsername()` race condition ถูกจัดการถูกต้อง (code review — fix #2 จากรอบ 1)
5. OTP 6-box input ตรงตาม design spec + accessibility (code review — fix #3 จากรอบ 1)
6. Flow เต็มของ**ผู้ใช้เดิม** (มี username แล้ว): sign in → Home → logout → กลับ Welcome
7. **Flow เต็มของผู้ใช้ใหม่**: sign in → Username Setup → Home → **logout** → กลับ Welcome
8. Regression check: จุดอื่นที่เคยผ่านในรอบ 1 ยังผ่านอยู่หรือไม่

Passed: 6/8 (#1, #2, #3, #4, #5, #6)

Failed: 1/8 (#7) — ซึ่งเป็นบั๊กใหม่ที่**เกิดจากการแก้ไขของ Debug Engineer เอง**ในรอบก่อน (#8 regression check เจอผ่าน #7 นี่แหละ ไม่ได้แยกนับซ้ำ)

Severity:
- #7 — **Critical** (blocker สำหรับผู้ใช้ใหม่ทุกคน)

### Failed Case #7 — Critical (Regression): ผู้ใช้ใหม่ที่เพิ่งตั้ง username แล้ว logout ไม่ได้ ต้อง force-restart แอป

Reproduction Steps (code trace ทีละบรรทัด ยืนยันจาก source จริง):
1. ผู้ใช้ใหม่ sign in สำเร็จ → `AuthGate` pop กลับ route ฐาน (fix #1 ทำงานถูกต้อง) → แสดง `UsernameSetupScreen` ซึ่ง**ยังคงเป็นวิดเจ็ตที่ AuthGate.build() คืนค่าอยู่ ณ route เดียวกับ AuthGate เอง** ไม่ใช่ route ที่ถูก push แยก
2. ผู้ใช้กรอก username กด "เสร็จสิ้น" → `_submit()` เรียก `setUsername()` สำเร็จ แล้วเรียก **`Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()))`** (`username_setup_screen.dart:61-64`)
3. `pushReplacement` แทนที่ **route ปัจจุบัน** (ซึ่งคือ route ฐานเดียวกับที่ `AuthGate` ครองอยู่) ด้วย route ใหม่ที่มีแค่ `HomeScreen()` เปล่า ๆ — ผลคือ **`AuthGate` (รวมถึง `_authSubscription` และ `StreamBuilder` ของมัน) ถูก dispose ทิ้งไปทั้งหมด** ไม่ได้อยู่ใน widget tree อีกต่อไปแล้ว
4. ผู้ใช้กดปุ่ม logout ใน `HomeScreen` → เรียก `Supabase.instance.client.auth.signOut()` ตรง ๆ (`home_screen.dart:18`) — Supabase auth state เปลี่ยนเป็น signed-out จริง แต่**ไม่มี widget ไหนในหน้าจอฟัง event นี้อีกแล้ว** (เพราะ AuthGate ถูกทำลายไปตั้งแต่ข้อ 3)

Expected: หลัง logout ผู้ใช้ควรกลับไปหน้า `WelcomeScreen` โดยอัตโนมัติ (ตามพฤติกรรมเดียวกับผู้ใช้เดิมที่ทดสอบผ่านใน #6)

Actual: ผู้ใช้**ค้างอยู่ที่ `HomeScreen` เดิม** ทั้งที่ session หมดแล้วจริง (ไม่มี valid session) — UI ไม่รู้ตัวเลยว่าตัวเอง sign out ไปแล้ว ต้อง **force-restart แอป** เท่านั้นถึงจะกลับไป `WelcomeScreen` ได้ (เพราะตอน restart จะสร้าง `AuthGate` ใหม่ตั้งแต่ต้น)

**นี่คือบั๊กเดิม (route ที่ AuthGate ควรคุมอยู่ถูกแทนที่โดยไม่ได้ตั้งใจ) กลับมาในรูปแบบใหม่ — คราวนี้เกิดจากการแก้ไขบั๊ก Critical รอบที่แล้วเอง** เส้นทาง "ผู้ใช้เดิมที่มี username แล้ว" (test case #6) ไม่เจอปัญหานี้ เพราะ `HomeScreen` ของผู้ใช้กลุ่มนั้นถูก return จาก `AuthGate.build()` โดยตรง (เป็นลูกของ `AuthGate` จริง ๆ ไม่ได้ผ่าน `pushReplacement`) — บั๊กนี้กระทบเฉพาะผู้ใช้ **ใหม่** ที่เพิ่งผ่านขั้นตอนตั้ง username เท่านั้น

Regression Note: จุดที่พลาดคือ Debug Engineer รอบก่อนแก้แค่ให้ "ไปถึง Home ได้" (symptom เดิมที่ QA รายงาน) แต่ไม่ได้ไล่ผลกระทบต่อไปถึง "แล้วถ้า logout จากตรงนี้จะเกิดอะไรขึ้น" — ตรงกับสิ่งที่ Debug Engineer เองก็ยอมรับไว้แล้วว่าการแก้ #1 (navigation) ยังไม่มี automated regression test คุ้มครอง (`.wyn/learning/IMPROVEMENTS.md`)

Security Findings: ไม่มีจุดใหม่เพิ่มจากรอบนี้ — RLS, secret handling ยังตรวจสอบแล้วผ่านเหมือนรอบ 1 (ดู `.wyn/tasks/qa/` เดิม — ย้ายมาที่นี่แล้ว)

Minor (ไม่ block, บันทึกไว้เฉย ๆ): `OtpBoxInput` ยังไม่รองรับการลบ (backspace) ข้ามช่องที่ว่างอยู่แล้วต่อเนื่องหลายครั้ง (ต้องกด backspace บนช่องที่มีตัวเลขอยู่เท่านั้นถึงจะขยับโฟกัสถอยได้) เป็น UX papercut เล็กน้อย ไม่กระทบ acceptance criteria

Recommendation: ส่งกลับ AI Debug Engineer แก้ #7 — แนวทางที่แนะนำ: **อย่าใช้ `pushReplacement` สร้าง route ใหม่แยกจาก `AuthGate`** ให้ `UsernameSetupScreen` แจ้ง `AuthGate` ให้ rebuild ตัวเอง (เช่น ส่ง callback `VoidCallback onUsernameSet` จาก `AuthGate` ลงไปให้ `UsernameSetupScreen` เรียกหลัง `setUsername()` สำเร็จ แล้ว `_AuthGateState` เรียก `setState(() {})` เพื่อให้ `FutureBuilder` เช็ค `hasUsername` ใหม่และ return `HomeScreen()` เป็นลูกของ `AuthGate` เองตามปกติ) วิธีนี้ทำให้ `HomeScreen` อยู่ใน subtree ของ `AuthGate` เสมอไม่ว่าจะมาจากเส้นทางไหน สอดคล้องกับพฤติกรรมที่ #6 พิสูจน์แล้วว่าถูกต้อง

Final Status: **FAIL**
