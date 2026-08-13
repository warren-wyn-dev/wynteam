# Product Task — WYN-002

Status: approved (QA รอบ 3 — PASS ระดับ code/static review — ดู เงื่อนไขก่อน deploy จริงด้านล่าง)
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (FAIL รอบ 1, FAIL รอบ 2, **PASS รอบ 3**) → AI Debug Engineer (แก้ 2 รอบ) → AI Deploy & DevOps (ถัดไป — เมื่อพร้อม)

Feature: Authentication & Onboarding

Target User: วัยรุ่น / Gen Z

Dependencies: WYN-001 (เสร็จแล้ว), WYN-002 Design (เสร็จแล้ว)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป (ปลดล็อกแล้วในระดับโค้ด)

---

## QA & Security Report — รอบ 3 (AI QA & Security)

Feature: WYN-002 — Authentication & Onboarding (หลัง Debug Engineer แก้ regression จาก QA รอบ 2 ใน PR #10)

Environment: Code review + static analysis บน `main` หลัง merge PR #10 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับ 2 รอบก่อน (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. **Trace build tree**: `HomeScreen` ของผู้ใช้ใหม่ (ผ่าน username setup) เป็นลูกของ `AuthGate` จริงหรือไม่ (ไม่ใช่ route แยกเหมือนรอบ 2)
4. `AuthGate` state/`_authSubscription` ยังอยู่ครบหลังผู้ใช้ใหม่ตั้ง username สำเร็จหรือไม่
5. Full lifecycle ผู้ใช้ใหม่: sign in → Username Setup → Home → **logout** → กลับ Welcome
6. Full lifecycle ผู้ใช้เดิม: sign in → Home → logout → กลับ Welcome (regression check)
7. Fix รอบ 1 ทั้ง 3 จุด (popUntil, race condition, OTP boxes) ยังทำงานถูกต้อง ไม่มีอะไรถูกแก้ทับโดยไม่ตั้งใจ
8. Security review ซ้ำ: ไม่มี secret ใหม่หลุด, RLS ไม่เปลี่ยนแปลง

Passed: 8/8

Failed: 0/8

### รายละเอียดการยืนยัน Test Case #3-5 (จุดที่เคย FAIL ในรอบ 2)

ไล่โค้ดจริงทีละบรรทัด (`auth_gate.dart:59-80`, `username_setup_screen.dart:61-72`):
1. `UsernameSetupScreen._submit()` เรียก `widget.onUsernameSet()` แทน `Navigator.pushReplacement` เดิม — **ไม่มีการสร้าง route ใหม่แล้ว**
2. `onUsernameSet` ที่ `AuthGate` ส่งมาคือ `() => setState(() {})` — เรียก `setState` บน `_AuthGateState` เอง ทำให้ `AuthGate.build()` รันใหม่
3. `build()` ใหม่เรียก `_authRepository.hasUsername(session.user.id)` สดใหม่ (ไม่แคช) → คืนค่า `true` เพราะ profile ถูกเขียนไปแล้วจริง → return `HomeScreen()` **เป็นค่าที่ FutureBuilder ของ AuthGate.build() คืน** ไม่ใช่ route แยก
4. เพราะ `HomeScreen` อยู่ใน subtree เดียวกับ `AuthGate` เสมอ (เหมือน branch `usernameSnapshot.data == true` ที่ผู้ใช้เดิมใช้อยู่แล้ว) `_AuthGateState` (รวม `_authSubscription`) จึงไม่ถูก dispose
5. เมื่อกด logout → `signOut()` → auth state เปลี่ยนเป็น signed-out → `StreamBuilder<AuthState>` ของ `AuthGate` (ซึ่งยังฟังอยู่) rebuild ตามปกติ → `currentSession == null` → กลับไป `WelcomeScreen` ถูกต้อง **เหมือนกับเส้นทางผู้ใช้เดิมทุกประการ**

**สรุป**: บั๊ก regression ของ QA รอบ 2 ถูกแก้ถูกจุดจริง ไม่ใช่แค่ปิดอาการ

Security Findings: ไม่มีจุดใหม่ — RLS policies, secret handling เหมือนเดิมทุกประการ ไฟล์ที่แก้ (`auth_gate.dart`, `username_setup_screen.dart`) ไม่แตะ security-sensitive code

Minor (ไม่ block, บันทึกไว้เฉย ๆ เหมือนรอบก่อน):
- Comment ใน `auth_gate.dart:13` ยังอ้างอิง path `.wyn/tasks/bugs/WYN-002-*.md` ซึ่งตอนนี้ย้ายไป `tasks/approved/` แล้ว — ไม่กระทบการทำงาน เป็นแค่ comment ล้าสมัยเล็กน้อย
- `OtpBoxInput` ยังไม่รองรับ backspace ข้ามช่องว่างต่อเนื่องหลายครั้ง (เดิมจากรอบ 2) — ยังไม่ block
- ไม่มี automated regression test สำหรับ pop-back navigation, race condition, และ callback-rebuild fix — ยืนยันด้วย code review 3 รอบติดต่อกันแทน (ดู IMPROVEMENTS.md — priority สูงแล้ว)

Recommendation: **อนุมัติระดับโค้ด** — ส่งต่อ AI Deploy & DevOps ได้ แต่**ยังห้าม deploy ขึ้น production จริง**จนกว่าจะมี: (1) Supabase project จริง + RLS/schema apply แล้ว, (2) native URL scheme + Apple Sign-In capability ตั้งค่าใน platform folders, (3) `flutter build apk`/`flutter build ios` สำเร็จจริงในเครื่อง/CI ที่มี toolchain ครบ, (4) ทดสอบ dynamic บนอุปกรณ์จริงอย่างน้อย 1 รอบ — รายการนี้เหมือนเดิมทุกรอบ ยังไม่มีอะไรเปลี่ยนแปลงเพราะเป็นข้อจำกัดของ environment ไม่ใช่ของโค้ด

Final Status: **PASS** (code/static-level — ดูเงื่อนไขก่อน deploy จริงด้านบน)

---

## สรุป QA Cycle ทั้งหมดของ WYN-002

- รอบ 1: FAIL (3 บั๊ก: 1 Critical + 2 Medium)
- รอบ 2: FAIL (1 Critical regression จากการแก้รอบ 1)
- รอบ 3: **PASS**

Handoff: ส่งต่อ AI Deploy & DevOps (`/deploy`) เพื่อเตรียม build verification และ deployment plan — Deploy AI ต้องตรวจสอบเงื่อนไขที่ยังไม่ครบใน Recommendation ก่อนดำเนินการ deploy จริงตาม `.wyn/company/RULES.md`

---

## Deploy & DevOps Report (AI Deploy & DevOps)

Release: WYN V0.1 — WYN-002 (Authentication & Onboarding)

Version: `0.1.0+1` (จาก `app/pubspec.yaml`)

QA Status: PASS (รอบ 3, ระดับโค้ด/static — ดูรายละเอียดด้านบน) — PR #11 ที่บันทึกผลนี้ยังไม่ได้ merge เข้า `main` ตามคำสั่ง Founder (รอ merge ทีหลัง)

Build Status:
- `flutter analyze` — ผ่าน (0 issues)
- `flutter test` — ผ่าน (6/6)
- `flutter build apk` / `flutter build ios` — **ยังไม่เคยรันสำเร็จเลยทั้งโปรเจกต์** เพราะไม่มี Android SDK และไม่มี Xcode ในทุกเครื่องที่ AI ใช้ทำงานมาตลอด (`flutter doctor` ยืนยันซ้ำแล้วหลายรอบ) — **นี่คือ blocker หลักของการ deploy จริง**

Deployment Target: **Internal Testing** (อนุมัติโดย Founder เมื่อ 2026-08-13) — TestFlight (iOS ผ่าน App Store Connect) + Firebase App Distribution หรือ Google Play Internal Testing Track (Android) สำหรับทีมภายในเท่านั้น ยังไม่ใช่ public store release

Changes: WYN-002 ทั้งหมด — 5 screens (Welcome, Auth Method Selection, Phone Entry, OTP Verification, Username Setup), `AuthGate` routing, `AuthRepository` (Supabase Auth wrapper), `supabase/schema.sql` (ตาราง `profiles` + RLS), แก้บั๊ก QA 2 รอบ

Deployment Result: **ยังไม่ deploy — Blocked** ด้วยเหตุผลต่อไปนี้ (เรียงตามลำดับที่ต้องทำ):

1. **Merge PR #11** เข้า `main` (รอคำสั่ง Founder)
2. **สร้าง Supabase project จริง** (แนะนำแยก dev/staging จาก production ในอนาคต) แล้วรัน `supabase/schema.sql` ผ่าน SQL editor — Founder ต้องเป็นผู้สร้าง account/project เอง (ไม่ใช่สิ่งที่ AI ทำแทนได้ เพราะต้องผูกบัตรเครดิต/ organization จริง)
3. **เปิดใช้งาน Auth providers** ใน Supabase dashboard: Google OAuth (ต้องสร้าง OAuth Client ID ใน Google Cloud Console), Apple OAuth (ต้องมี Apple Developer account), Phone/SMS OTP (ต้องผูก SMS provider เช่น Twilio — **มีค่าใช้จ่ายต่อข้อความ ต้องแจ้ง Founder อนุมัติงบก่อน**)
4. **ตั้งค่า native URL scheme** (`io.wyn.app://login-callback`) ใน `android/app/src/main/AndroidManifest.xml` และ `ios/Runner/Info.plist`
5. **เปิด "Sign in with Apple" capability** ใน Xcode + ผูก Apple Developer account
6. **Build จริง** ในเครื่อง/CI ที่มี Android SDK + Xcode ครบ: `flutter build apk --release` และ `flutter build ipa` — ยังไม่เคยทำสำเร็จแม้แต่ครั้งเดียวตลอดโปรเจกต์นี้
7. **ตั้งค่า distribution channel**: TestFlight (ผ่าน App Store Connect) และ Firebase App Distribution หรือ Google Play Internal Testing Track
8. **Dynamic test บนอุปกรณ์จริงอย่างน้อย 1 รอบ** ก่อนแจก internal testers (เป็นงานของ AI QA & Security รอบสุดท้ายกับ Supabase project จริง)
9. **จัดการ secrets สำหรับ CI/build อย่างปลอดภัย** — `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` ต้องเก็บใน CI secret store (เช่น GitHub Actions secrets) ห้าม commit ลง repo เด็ดขาด (ยังไม่มี `.github/workflows` ในโปรเจกต์นี้ — เป็นงานที่ต้องทำเพิ่มเติม)

Production Verification: N/A — ยังไม่มีการ deploy จริง

Rollback Plan (เตรียมไว้ล่วงหน้าแม้ยังไม่ deploy จริง):
- **Code**: revert ผ่าน git บน `main` (PR-based history สะอาดอยู่แล้ว ทุก merge เป็น squash commit เดียวตรวจสอบง่าย)
- **Database**: `supabase/schema.sql` เป็น versioned SQL file ใน repo — การเปลี่ยนแปลง schema ในอนาคตควรเพิ่มเป็นไฟล์ migration ใหม่ (ไม่แก้ไฟล์เดิม) และสำรองข้อมูลก่อน apply เสมอ
- **App distribution**: TestFlight และ Firebase App Distribution/Play Internal Testing รองรับการย้อนกลับไปเวอร์ชันก่อนหน้าได้ในตัวโดยไม่กระทบข้อมูลผู้ใช้

Handoff: รอ Founder ดำเนินการข้อ 1-3 และ 5 (สร้าง account/project ต่าง ๆ ที่ AI ทำแทนไม่ได้) ก่อน AI Deploy & DevOps จะดำเนินการข้อ 4, 6-9 ต่อได้ — เมื่อพร้อมครบ ให้เรียก `/deploy` อีกครั้งเพื่อดำเนินการ build + distribute จริง
