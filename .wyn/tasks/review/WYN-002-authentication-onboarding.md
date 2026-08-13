# Product Task — WYN-002

Status: review (Coding + build verification เสร็จแล้ว รอ AI QA & Security ทดสอบ end-to-end)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (ถัดไป)

Feature: Authentication & Onboarding

Goal: ให้ผู้ใช้ใหม่สมัคร/เข้าสู่ระบบ WYN ได้อย่างรวดเร็วและ friction ต่ำที่สุด เพื่อเป็นฐานให้ feature อื่น ๆ (Profile, Feed) ทำงานต่อได้ เนื่องจากทุก feature ต้องมี user ที่ยืนยันตัวตนแล้วก่อนเสมอ

Target User: วัยรุ่น / Gen Z ที่คุ้นเคยกับการ login ด้วย social account หรือเบอร์โทรศัพท์ ไม่คุ้นเคย/ไม่ชอบกรอก email+password

Problem: ปัจจุบัน WYN ยังไม่มี source code หรือระบบ authentication ใด ๆ ทำให้ยังไม่มี user account และ feature อื่นทั้งหมด (Profile, Feed) ยังเริ่มไม่ได้

Requirements:
- สมัครสมาชิก/เข้าสู่ระบบผ่าน **Social Login: Google และ Apple**
- สมัครสมาชิก/เข้าสู่ระบบผ่าน **Phone Number + OTP** (รองรับเบอร์ไทย)
- ไม่มี Email + Password ใน V0.1 (ลด friction ตามที่ Founder อนุมัติ)
- หลังสมัครสำเร็จครั้งแรก ต้องพาผู้ใช้เข้าสู่ขั้นตอน onboarding เบื้องต้น (อย่างน้อย: ตั้งชื่อผู้ใช้/username)
- ใช้ Supabase Auth เป็นระบบยืนยันตัวตน (ตามที่อนุมัติใน WYN-001 — Google/Apple OAuth provider + Phone OTP provider)
- Session ต้องคงอยู่ (persist) หลังปิดแอป ไม่ต้อง login ใหม่ทุกครั้ง

Acceptance Criteria (สถานะ implement — ยังไม่ผ่าน QA end-to-end):
- [x] Google Sign-In — เรียก Supabase `signInWithOAuth` แล้ว (compile ผ่าน ยังไม่ทดสอบกับ Supabase project จริง)
- [x] Apple Sign-In — เรียก Supabase `signInWithOAuth` แล้ว (compile ผ่าน ยังไม่ทดสอบกับ Supabase project จริง)
- [x] Phone + OTP — เรียก Supabase `signInWithOtp` / `verifyOTP` แล้ว (compile ผ่าน ยังไม่ทดสอบกับ Supabase project จริง)
- [x] ผู้ใช้เดิม login ซ้ำไม่สร้าง account ซ้ำ — ใช้ Supabase Auth ผูกกับ `auth.users` ตาม provider identity มาตรฐาน (ยังไม่ทดสอบจริง)
- [x] Username setup ก่อนเข้าแอป — `UsernameSetupScreen` + `AuthGate` ตรวจสอบ `profiles.username`
- [x] Session persistence — จัดการโดย `supabase_flutter` เอง (ค่าเริ่มต้นของ package)
- [x] Logout — ปุ่ม logout ใน `HomeScreen` เรียก `signOut()`
- [x] ไม่มีการเก็บ credential ที่อ่อนไหวใน client — ไม่มีการเก็บรหัสผ่าน/token แบบ manual, ใช้ session management ของ `supabase_flutter`

**หมายเหตุสำคัญ**: เครื่องหมาย [x] หมายถึง "implement แล้วและผ่าน static analysis + unit/widget test" เท่านั้น **ยังไม่ได้ทดสอบ end-to-end กับ Supabase project จริงหรือบนอุปกรณ์จริง** — AI QA & Security ต้องทดสอบ flow จริงทั้งหมด

Dependencies: WYN-001 (Vision & Tech Stack — เสร็จแล้ว: Flutter + Supabase)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป (Profile, Feed ต้องมี user ที่ login แล้ว)

Risks:
- Apple Sign-In มีข้อกำหนดเฉพาะจาก Apple (บังคับต้องมีถ้ามี social login อื่นบน iOS) — โฟลเดอร์ `ios/` มีแล้วแต่ยังไม่ได้เปิด capability "Sign in with Apple" ใน Xcode
- Phone OTP ผ่าน SMS มีต้นทุนต่อข้อความ — ต้องแจ้ง Founder เรื่องค่าใช้จ่ายก่อนเปิดใช้งานจริง
- ยังไม่มี Android SDK / Xcode ในเครื่องที่ตรวจสอบ ทำให้ `flutter build apk`/`flutter build ios` ยังไม่เคยรันสำเร็จ — ตรวจสอบได้แค่ระดับ static analysis + unit/widget test เท่านั้น

Recommendation: ส่งต่อ AI QA & Security ได้แล้วสำหรับการทดสอบระดับ static/logic แต่การทดสอบ end-to-end บนอุปกรณ์จริงต้องรอเครื่อง/CI ที่มี Android SDK หรือ Xcode และ Supabase project จริง

## Coding Output (AI Coding)

Implementation: สร้าง Flutter project ที่ `app/` — 5 screens ตาม design spec (Welcome, Auth Method Selection, Phone Entry, OTP Verification, Username Setup) + `AuthGate` สำหรับ routing ตามสถานะ auth/onboarding + `AuthRepository` ครอบ Supabase Auth calls ทั้งหมด + `supabase/schema.sql` (ตาราง `profiles` พร้อม RLS policy) พร้อมโฟลเดอร์ platform (`android/`, `ios/`) ที่สร้างจริงด้วย `flutter create`

Files Changed:
- `app/pubspec.yaml`, `app/pubspec.lock`, `app/analysis_options.yaml`, `app/.gitignore`, `app/.metadata`, `app/README.md`
- `app/lib/core/env.dart`, `app/lib/main.dart`
- `app/lib/features/auth/data/auth_repository.dart`
- `app/lib/features/auth/presentation/{welcome,auth_method,phone_entry,otp_verification,username_setup}_screen.dart`
- `app/lib/features/auth/presentation/auth_gate.dart`
- `app/lib/features/home/presentation/home_screen.dart` (placeholder)
- `app/test/widget_test.dart`
- `app/android/`, `app/ios/` (สร้างจาก `flutter create`)
- `supabase/schema.sql`

Reason: Implement WYN-002 ตาม Design Spec เพื่อปลดล็อก feature ถัดไป (Profile, Feed) ที่ต้องมี user login แล้วก่อนเสมอ

Tests: เขียน widget test 2 เคส (`test/widget_test.dart`) — เช็คว่า WelcomeScreen แสดงข้อความ/ปุ่มถูกต้อง และกดปุ่มแล้ว navigate ไป AuthMethodScreen สำเร็จ พร้อมเห็นปุ่ม Google/Apple/เบอร์โทร ครบ — **รันจริงแล้ว: `flutter test` → All tests passed! (2/2)**

Build:
- ติดตั้ง Flutter SDK 3.47.0 (stable) ในเครื่องที่ทำงาน แล้วรัน `flutter create --org io.wyn --project-name wyn --platforms=android,ios .` สร้างโฟลเดอร์ platform สำเร็จ (ไม่ทับ `lib/`/`pubspec.yaml` เดิม)
- `flutter pub get` — สำเร็จ
- `flutter analyze` — **No issues found** (พบและแก้ 1 ปัญหาจริงระหว่างทาง: `Supabase.initialize` พารามิเตอร์ `anonKey` เป็น deprecated ใน supabase_flutter 2.17.1 เปลี่ยนเป็น `publishableKey` แล้ว)
- `flutter test` — **All tests passed! (2/2)**
- `flutter build apk` / `flutter build ios` — **ยังไม่ได้รัน** เพราะเครื่องที่ตรวจสอบไม่มี Android SDK และไม่มี Xcode (`flutter doctor` ยืนยัน)

Known Issues:
- `flutter build` (APK/IPA) ยังไม่เคยรันสำเร็จ — ต้องทำในเครื่อง/CI ที่มี Android SDK หรือ Xcode
- ยังไม่ได้ตั้งค่า Supabase project จริง (URL/publishable key, OAuth providers, SMS provider)
- ยังไม่มี native URL scheme (`io.wyn.app://login-callback`) ตั้งใน `AndroidManifest.xml`/`Info.plist` สำหรับ OAuth redirect
- Apple Sign-In capability ยังไม่ได้เปิดใน Xcode

Handoff: ส่งต่อ AI QA & Security (`/qa`) สำหรับรีวิว static analysis/test ที่ทำแล้ว — การทดสอบ end-to-end บนอุปกรณ์จริงต้องรอ Founder/AI Deploy & DevOps ตั้งค่า Supabase project จริงและมีเครื่อง/CI ที่มี Android SDK หรือ Xcode ก่อน
