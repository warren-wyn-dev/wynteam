# Product Task — WYN-002

Status: review (Coding เสร็จแล้ว รอ AI QA & Security ทดสอบ)
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

Acceptance Criteria (สถานะ implement — ยังไม่ผ่าน QA):
- [x] Google Sign-In — เรียก Supabase `signInWithOAuth` แล้ว (ยังไม่ทดสอบจริง)
- [x] Apple Sign-In — เรียก Supabase `signInWithOAuth` แล้ว (ยังไม่ทดสอบจริง)
- [x] Phone + OTP — เรียก Supabase `signInWithOtp` / `verifyOTP` แล้ว (ยังไม่ทดสอบจริง)
- [x] ผู้ใช้เดิม login ซ้ำไม่สร้าง account ซ้ำ — ใช้ Supabase Auth ผูกกับ `auth.users` ตาม provider identity มาตรฐาน (ยังไม่ทดสอบจริง)
- [x] Username setup ก่อนเข้าแอป — `UsernameSetupScreen` + `AuthGate` ตรวจสอบ `profiles.username`
- [x] Session persistence — จัดการโดย `supabase_flutter` เอง (ค่าเริ่มต้นของ package)
- [x] Logout — ปุ่ม logout ใน `HomeScreen` เรียก `signOut()`
- [x] ไม่มีการเก็บ credential ที่อ่อนไหวใน client — ไม่มีการเก็บรหัสผ่าน/token แบบ manual, ใช้ session management ของ `supabase_flutter`

**หมายเหตุสำคัญ**: เครื่องหมาย [x] ข้างต้นหมายถึง "implement แล้วตาม spec" เท่านั้น **ไม่ได้แปลว่าทดสอบผ่านจริง** เพราะ sandbox ที่ใช้เขียนโค้ดนี้ไม่มี Flutter SDK ทำให้ไม่เคย build/run จริงเลย AI QA & Security ต้องทดสอบทุกข้อใหม่ทั้งหมด

Dependencies: WYN-001 (Vision & Tech Stack — เสร็จแล้ว: Flutter + Supabase)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป (Profile, Feed ต้องมี user ที่ login แล้ว)

Risks:
- Apple Sign-In มีข้อกำหนดเฉพาะจาก Apple (บังคับต้องมีถ้ามี social login อื่นบน iOS) — ยังไม่ได้ตั้งค่า capability เพราะยังไม่มีโฟลเดอร์ `ios/`
- Phone OTP ผ่าน SMS มีต้นทุนต่อข้อความ — ต้องแจ้ง Founder เรื่องค่าใช้จ่ายก่อนเปิดใช้งานจริง
- **โค้ดทั้งหมดยังไม่เคยผ่าน `flutter analyze`/`flutter test`/`flutter build` เพราะ environment ที่เขียนไม่มี Flutter SDK** — ความเสี่ยงหลักของรอบนี้

Recommendation: ส่งต่อ AI QA & Security แต่ก่อนอื่น **ต้องมีคนรัน `flutter create` เพื่อสร้างโฟลเดอร์ platform ก่อน** (ดู `app/README.md`) — QA จะทดสอบจริงไม่ได้จนกว่าจะมีโฟลเดอร์ platform และตั้งค่า Supabase project จริง

## Coding Output (AI Coding)

Implementation: สร้าง Flutter project เบื้องต้นที่ `app/` — 5 screens ตาม design spec (Welcome, Auth Method Selection, Phone Entry, OTP Verification, Username Setup) + `AuthGate` สำหรับ routing ตามสถานะ auth/onboarding + `AuthRepository` ครอบ Supabase Auth calls ทั้งหมด + `supabase/schema.sql` (ตาราง `profiles` พร้อม RLS policy)

Files Changed:
- `app/pubspec.yaml`, `app/analysis_options.yaml`, `app/.gitignore`, `app/README.md`
- `app/lib/core/env.dart`
- `app/lib/main.dart`
- `app/lib/features/auth/data/auth_repository.dart`
- `app/lib/features/auth/presentation/{welcome,auth_method,phone_entry,otp_verification,username_setup}_screen.dart`
- `app/lib/features/auth/presentation/auth_gate.dart`
- `app/lib/features/home/presentation/home_screen.dart` (placeholder)
- `supabase/schema.sql`

Reason: Implement WYN-002 ตาม Design Spec เพื่อปลดล็อก feature ถัดไป (Profile, Feed) ที่ต้องมี user login แล้วก่อนเสมอ

Tests: ไม่มี automated test ในรอบนี้ — ไม่มี Flutter SDK ให้เขียนแล้วรันยืนยัน จึงไม่เขียน test ที่ไม่เคยรันผ่านเพื่อไม่ให้เข้าใจผิดว่าเชื่อถือได้

Build: **ไม่ได้รัน** — sandbox ไม่มี Flutter/Dart SDK (`flutter`/`dart` command not found) ตรวจสอบได้แค่ brace/paren balance แบบ manual เท่านั้น ยังไม่ผ่าน `flutter analyze` จริง

Known Issues:
- ไม่มีโฟลเดอร์ `android/`, `ios/`, `web/` — ต้องรัน `flutter create --org io.wyn --project-name wyn .` ในเครื่องที่มี Flutter SDK ก่อน (ดูขั้นตอนเต็มใน `app/README.md`)
- ยังไม่ได้ตั้งค่า Supabase project จริง (URL/anon key, OAuth providers, SMS provider)
- ยังไม่มี native URL scheme (`io.wyn.app://login-callback`) สำหรับ OAuth redirect — ต้องตั้งหลังมีโฟลเดอร์ platform
- ยังไม่มี automated test

Handoff: ส่งต่อ AI QA & Security (`/qa`) **แต่ต้องมีคนรัน `flutter create` + ตั้งค่า Supabase project ก่อน** ถึงจะทดสอบจริงได้ — แนะนำให้ Founder หรือ AI Deploy & DevOps ทำ 2 ขั้นตอนนี้ในเครื่อง/CI ที่มี Flutter SDK ก่อนส่งต่อ QA
