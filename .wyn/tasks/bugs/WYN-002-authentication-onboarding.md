# Product Task — WYN-002

Status: bugs (QA FAIL — ส่งกลับ AI Debug Engineer)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — FAIL) → AI Debug Engineer (ถัดไป)

Feature: Authentication & Onboarding

---

## QA & Security Report (AI QA & Security)

Feature: WYN-002 — Authentication & Onboarding

Environment: Code review + static analysis บน branch `claude/pwd-nxsvf5` (หลัง merge PR #6 เข้า `main`) ใช้ Flutter SDK 3.47.0 stable ที่ติดตั้งไว้ในเครื่องนี้ — **ไม่มี Supabase project จริง และไม่มี Android SDK/Xcode ให้ build/run บนอุปกรณ์หรือ emulator จริง** ดังนั้นการทดสอบรอบนี้คือ (1) รัน `flutter analyze`/`flutter test` ซ้ำอย่างอิสระ และ (2) อ่านโค้ดทุกไฟล์อย่างละเอียดเทียบกับ Acceptance Criteria และ Design Spec เพื่อหาจุดที่ implementation จะพังจริงเมื่อรันจริง

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. Google Sign-In เรียก Supabase API ถูกต้องหรือไม่ (code review)
4. Apple Sign-In เรียก Supabase API ถูกต้องหรือไม่ (code review)
5. Phone OTP send/verify เรียก Supabase API ถูกต้องหรือไม่ (code review)
6. ผู้ใช้เดิม login ซ้ำไม่สร้าง account ซ้ำ (code review — พึ่งพา Supabase Auth identity matching)
7. ผู้ใช้ใหม่ถูกพาไปตั้ง username ก่อนเข้าแอป (code review)
8. **หลังตั้ง username สำเร็จ ผู้ใช้ต้องเข้าหน้า Home ได้** (code review — เดิน flow ตามโค้ดจริงทีละบรรทัด)
9. Session persistence หลังปิดแอป (code review)
10. Logout และบล็อกการเข้าถึงหลัง logout (code review)
11. ไม่มีการเก็บ credential ที่อ่อนไหวใน client (code review)
12. Username uniqueness ภายใต้ race condition (code review — ตรวจ error handling)
13. OTP Input ตรงตาม Design Spec (Screen 4 — "OTP Input 6 ช่องแยก" + accessibility) หรือไม่ (เทียบกับ `.wyn/docs/design/wyn-002-authentication-onboarding.md`)

Passed: 10/13 (#1, #2, #3, #4, #5, #6, #7, #9, #10, #11)

Failed: 3/13 (#8, #12, #13)

Severity:
- #8 — **Critical** (blocker)
- #12 — Medium
- #13 — Medium (design-fidelity + accessibility)

### Failed Case #8 — Critical: ผู้ใช้ใหม่ตั้ง username สำเร็จแล้วค้างอยู่ที่หน้าเดิม เข้า Home ไม่ได้

Reproduction Steps:
1. ผู้ใช้ใหม่ login สำเร็จ (ด้วยวิธีใดก็ได้) → `AuthGate` ตรวจ `hasUsername` ครั้งแรก ได้ `false` → แสดง `UsernameSetupScreen`
2. ผู้ใช้กรอก username ที่ยังไม่มีคนใช้ กด "เสร็จสิ้น" → `UsernameSetupScreen._submit()` เรียก `authRepository.setUsername()` สำเร็จ (เขียนลง `profiles` table)
3. สังเกตหน้าจอ

Expected: ตาม Acceptance Criteria ของ WYN-002 ("ผู้ใช้ใหม่ถูกพาไปตั้ง username ก่อนเข้าหน้าแรกของแอป") ผู้ใช้ควรถูกพาไปหน้า Home ทันทีหลัง submit สำเร็จ

Actual: **ผู้ใช้ค้างอยู่ที่ `UsernameSetupScreen` เดิม ไม่ไปไหน** เพราะ:
- `AuthGate` (`app/lib/features/auth/presentation/auth_gate.dart:24-49`) ใช้ `StreamBuilder<AuthState>` ฟัง `authRepository.authStateChanges` (= `Supabase.auth.onAuthStateChange`) เป็นตัวกำหนดว่าจะ rebuild เมื่อไหร่
- การเรียก `setUsername()` เป็นการเขียนลงตาราง `profiles` (Postgres) **ไม่ใช่** auth event ใด ๆ — จึงไม่ทำให้ stream นี้ยิง event ใหม่เลย
- `FutureBuilder<bool>` ที่เช็ค `hasUsername` จึงไม่ถูกเรียกซ้ำ, `AuthGate` จึงไม่ rebuild ไปหน้า Home
- Comment ในโค้ด (`username_setup_screen.dart:57` และ `auth_gate.dart:11` "AuthGate listens for the profile change and navigates to Home") **เป็นสมมติฐานที่ผิด** — ไม่มีกลไกจริงที่ทำแบบนั้น
- ผู้ใช้จะต้อง **ปิดแอปแล้วเปิดใหม่** เท่านั้นถึงจะเข้า Home ได้ (เพราะตอนนั้น `AuthGate` build ใหม่ตั้งแต่ต้น และ `hasUsername` จะ return `true`)

นี่คือ blocker จริงที่ทำให้ onboarding flow ใช้งานไม่ได้ตามที่ออกแบบไว้ — ผู้ใช้ทุกคนที่สมัครใหม่จะเจอปัญหานี้ 100% ของเวลา

### Failed Case #12 — Medium: Username race condition ไม่ถูกจัดการ ทำให้ error หายเงียบ

Reproduction Steps:
1. ผู้ใช้ A และผู้ใช้ B พิมพ์ username เดียวกันพร้อมกัน (เช่นห่างกันไม่ถึง 1 วินาที) ทั้งคู่ผ่าน `isUsernameAvailable()` check เป็น `true` (เพราะยังไม่มีใครเขียนจริง)
2. ทั้งคู่กด "เสร็จสิ้น" — คนแรก `upsert` สำเร็จ คนที่สองชน unique constraint (`username text unique` ใน `supabase/schema.sql:7`) ที่ database ปฏิเสธ insert

Expected: ผู้ใช้คนที่สองควรเห็นข้อความ "ชื่อผู้ใช้นี้ถูกใช้แล้ว" เหมือนกรณี pre-check เจอว่าซ้ำปกติ

Actual: `setUsername()` (`auth_repository.dart:78-86`) จับเฉพาะกรณีที่ pre-check เจอว่าซ้ำ (throw `UsernameTakenException` เอง) แต่ `_submit()` ใน `username_setup_screen.dart:54-63` มีแค่ `on UsernameTakenException` เท่านั้น — ไม่มี catch สำหรับ exception ที่มาจาก Postgrest unique-violation จริงตอน `upsert()` ชน constraint จึง unhandled exception หลุดออกจาก `_submit()` ผู้ใช้ไม่เห็น error message ใด ๆ เลย (แม้ `finally` จะ reset `_isSubmitting` กลับเป็น false ก็ตาม) ต้องกดปุ่มซ้ำเองถึงจะเห็น error ที่ถูกต้องในรอบสอง (เพราะรอบสองจะไปเจอจาก pre-check แทน)

### Failed Case #13 — Medium: OTP Input ไม่ตรงตาม Design Spec ที่อนุมัติแล้ว

Reproduction Steps: เปิด `otp_verification_screen.dart:96-108` เทียบกับ `.wyn/docs/design/wyn-002-authentication-onboarding.md` (Screen 4 — Components/Accessibility)

Expected (ตาม Design Spec): "OTP Input (6 ช่องแยก)" พร้อม accessibility ที่ "แต่ละช่อง OTP ต้องประกาศลำดับ (เช่น 'หลักที่ 1 จาก 6') สำหรับ screen reader"

Actual: Implementation ใช้ **TextField เดียว** (`maxLength: 6`) ไม่ใช่ 6 ช่องแยกตามที่ออกแบบไว้ ทำให้ไม่มีทางประกาศลำดับหลักทีละช่องให้ screen reader ได้ตามที่ accessibility rule กำหนด — เป็นความเบี่ยงเบนจาก design spec ที่อนุมัติแล้ว ไม่ใช่แค่เรื่อง cosmetic เพราะกระทบ accessibility requirement โดยตรง

Security Findings:
- ไม่พบ secret/credential ที่ hardcode ในโค้ด (ตรวจสอบทุกไฟล์ใน `app/lib/` และ `supabase/schema.sql` แล้ว) — ใช้ `--dart-define` ตามที่ออกแบบไว้
- RLS policies ใน `supabase/schema.sql` ตรวจสอบแล้วถูกต้องตามเจตนา: insert/update จำกัดเฉพาะ `auth.uid() = id`, select เปิดให้อ่านได้ (ตั้งใจ เพราะ username เป็นข้อมูลสาธารณะ) — ไม่พบช่องโหว่
- **[Medium] OTP resend cooldown เป็น client-side เท่านั้น** (`otp_verification_screen.dart:37-47`, ตัวจับเวลา 30 วินาทีอยู่ใน Dart state ล้วน) ไม่มีอะไรบังคับใน backend ว่าเรียก `sendPhoneOtp()` ถี่กว่านั้นไม่ได้ (นอกจาก Supabase project's default rate limit ซึ่งยังไม่ได้ตรวจสอบว่าตั้งค่าไว้เท่าไหร่) — เป็นความเสี่ยงด้านต้นทุน (SMS มีค่าใช้จ่ายต่อข้อความตามที่ WYN-002 ระบุไว้ใน Risks) ไม่ใช่ช่องโหว่ด้านความปลอดภัยโดยตรง แต่ควรตรวจสอบ/ตั้งค่า rate limit ฝั่ง Supabase ก่อน deploy จริง
- Error message ทุกจุดเป็นข้อความทั่วไป ไม่รั่วไหลรายละเอียดระบบ (ปลอดภัยด้าน information disclosure)

Recommendation: ส่งกลับ AI Debug Engineer เพื่อแก้ไข 3 ประเด็นข้างต้น โดยเฉพาะ #8 (Critical) ต้องแก้ก่อนถึงจะทดสอบรอบถัดไปได้อย่างมีความหมาย — แนวทางแก้ที่เป็นไปได้: ให้ `UsernameSetupScreen` navigate ไป `HomeScreen` โดยตรงด้วย `Navigator.pushReplacement` ทันทีที่ `setUsername()` สำเร็จ แทนที่จะพึ่งพา `AuthGate` ตรวจจับเอง

Final Status: **FAIL**

---

## ประวัติ (จาก QA cycle นี้)

Target User: วัยรุ่น / Gen Z ที่คุ้นเคยกับการ login ด้วย social account หรือเบอร์โทรศัพท์ ไม่คุ้นเคย/ไม่ชอบกรอก email+password

Dependencies: WYN-001 (เสร็จแล้ว), WYN-002 Design (เสร็จแล้ว), WYN-002 Coding (เสร็จแล้ว — พบบั๊กจาก QA รอบนี้)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป

Handoff: AI Debug Engineer แก้ 3 ประเด็นข้างต้น (โดยเฉพาะ Critical #8) แล้วส่งกลับ AI QA & Security ทดสอบใหม่ (`/qa`) ก่อนจะย้ายไป `.wyn/tasks/approved/`
