# WYN — App (V0.1)

Flutter + Supabase mobile app for WYN. Implements **WYN-002: Authentication & Onboarding**
(see `.wyn/tasks/active/WYN-002-authentication-onboarding.md` and
`.wyn/docs/design/wyn-002-authentication-onboarding.md`).

## สถานะปัจจุบัน (สำคัญ — อ่านก่อน)

โค้ดในโฟลเดอร์นี้ถูกเขียนโดย AI Coding ใน environment ที่ **ไม่มี Flutter/Dart SDK ติดตั้งอยู่**
ทำให้ยังไม่เคยรัน `flutter pub get`, `flutter analyze`, `flutter test`, หรือ `flutter build`
เพื่อยืนยันความถูกต้องเลย และ **ยังไม่มีโฟลเดอร์ platform (`android/`, `ios/`, `web/`)**
เพราะโฟลเดอร์เหล่านี้ต้องถูกสร้างโดยเครื่องมือ `flutter create` เท่านั้น เขียนเองด้วยมือไม่ได้อย่างแม่นยำ

### ต้องทำก่อนรันแอปได้จริง (ในเครื่องที่มี Flutter SDK)

1. Clone repo แล้วเข้าไปที่โฟลเดอร์ `app/`
2. รัน `flutter create --org io.wyn --project-name wyn .` เพื่อสร้างโฟลเดอร์ platform (`android/`, `ios/`) — คำสั่งนี้จะไม่ทับไฟล์ `lib/` และ `pubspec.yaml` ที่มีอยู่แล้ว
3. รัน `flutter pub get`
4. รัน `flutter analyze` และแก้ error/warning ที่พบ (โค้ดยังไม่เคยผ่านการตรวจสอบนี้)
5. ตั้งค่า Supabase project จริง แล้วรัน `supabase/schema.sql` (อยู่ที่ root ของ repo) ใน SQL editor ของ Supabase
6. เปิดใช้งาน Auth providers ใน Supabase dashboard: Google OAuth, Apple OAuth, Phone (SMS OTP — ต้องตั้งค่า SMS provider เช่น Twilio ก่อน มีต้นทุนต่อข้อความ)
7. รันแอปพร้อมส่งค่า config:
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=xxxx
   ```

### Known Issues / งานที่เหลือ

- ยังไม่มี automated test (widget/unit test) — ต้องเขียนเพิ่มเมื่อมี Flutter SDK สำหรับรันจริง
- Google/Apple OAuth ใช้ Supabase `signInWithOAuth` (web redirect flow) ยังไม่ได้ตั้งค่า native URL scheme (`io.wyn.app://login-callback`) ในโฟลเดอร์ platform เพราะยังไม่มีโฟลเดอร์เหล่านั้น — ต้องตั้งค่าหลัง `flutter create`
- Apple Sign-In ต้องเปิดใช้งาน capability "Sign in with Apple" ใน Xcode และ Apple Developer account ก่อน
- ยังไม่ได้ทดสอบ flow จริงบนอุปกรณ์ — งานนี้เป็นของ AI QA & Security รอบถัดไป (ห้าม deploy ก่อนผ่าน QA)

## โครงสร้างโค้ด

```
lib/
  core/env.dart                          # อ่าน Supabase URL/anon key จาก --dart-define
  main.dart                              # entry point + theme (light/dark)
  features/
    auth/
      data/auth_repository.dart          # ครอบ Supabase Auth + profile calls ทั้งหมด
      presentation/
        auth_gate.dart                   # ตัดสินใจว่าจะโชว์หน้าไหนตามสถานะ auth
        welcome_screen.dart              # Screen 1
        auth_method_screen.dart          # Screen 2
        phone_entry_screen.dart          # Screen 3
        otp_verification_screen.dart     # Screen 4
        username_setup_screen.dart       # Screen 5
    home/presentation/home_screen.dart   # placeholder — Feed เป็น feature ถัดไป
```
