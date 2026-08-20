# WYN — App (V0.1)

Flutter + Supabase mobile app for WYN. Implements **WYN-002: Authentication & Onboarding**
(see `.wyn/tasks/approved/WYN-002-authentication-onboarding.md` and
`.wyn/docs/design/wyn-002-authentication-onboarding.md`).

## สถานะปัจจุบัน (สำคัญ — อ่านก่อน)

โปรเจกต์นี้ผ่านการตรวจสอบด้วย Flutter SDK จริงแล้ว (Flutter 3.47.0 stable):

- ✅ `flutter create --org io.wyn --project-name wyn --platforms=android,ios .` — สร้างโฟลเดอร์ `android/` และ `ios/` แล้ว (คอมมิตไว้ในนี้)
- ✅ `flutter pub get` — resolve dependencies สำเร็จ (`pubspec.lock` คอมมิตไว้แล้ว)
- ✅ `flutter analyze` — **No issues found**
- ✅ `flutter test` — **All tests passed!**
- ✅ `flutter build apk --debug` — **ยืนยันแล้วว่ารันได้จริง** (2026-08-17, เมื่อมี Android SDK ในเครื่อง) — ดูหมายเหตุ AGP 9 / `video_thumbnail` ใน Known Issues ด้านล่างถ้าเจอ build fail ที่ปลั๊กอินนี้อีก
- ❌ `flutter build ios` — **ยังไม่ได้ทำ** เพราะ sandbox ที่ตรวจสอบไม่มี Xcode ให้ build จริงจนออกมาเป็นไฟล์ IPA ได้ ต้องทำในเครื่อง dev หรือ CI ที่มี toolchain ครบ
- ❌ ยังไม่ได้ทดสอบ flow จริงบนอุปกรณ์/emulator เพราะยังไม่มี Supabase project จริงเชื่อมต่อ — งานนี้เป็นของ AI QA & Security

### ต้องทำก่อนรันแอปได้จริงบนอุปกรณ์/emulator

1. Clone repo แล้วเข้าไปที่โฟลเดอร์ `app/`
2. รัน `flutter pub get`
3. ตั้งค่า Supabase project จริง แล้วรัน `supabase/schema.sql` (อยู่ที่ root ของ repo) ใน SQL editor ของ Supabase
4. เปิดใช้งาน Auth providers ใน Supabase dashboard: Google OAuth, Apple OAuth, Phone (SMS OTP — ต้องตั้งค่า SMS provider เช่น Twilio ก่อน มีต้นทุนต่อข้อความ)
5. ตั้งค่า native URL scheme (`io.wyn.app://login-callback`) สำหรับ OAuth redirect ใน `android/app/src/main/AndroidManifest.xml` และ `ios/Runner/Info.plist` (ยังไม่ได้ตั้งค่า — ดู Known Issues)
6. รันแอปพร้อมส่งค่า config:
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=xxxx
   ```

### Known Issues / งานที่เหลือ

- Google/Apple OAuth ใช้ Supabase `signInWithOAuth` (web redirect flow) — ยังไม่ได้ตั้งค่า native URL scheme (`io.wyn.app://login-callback`) ใน `AndroidManifest.xml`/`Info.plist`
- Apple Sign-In ต้องเปิดใช้งาน capability "Sign in with Apple" ใน Xcode และ Apple Developer account ก่อน
- ยังไม่มี Supabase project จริงให้เชื่อมต่อทดสอบ end-to-end
- `flutter build ios` (IPA) ยังไม่เคยรันสำเร็จเพราะไม่มี Xcode ในเครื่องที่ตรวจสอบ — มีแค่ `flutter analyze`/`flutter test`/`flutter build apk --debug` ที่ยืนยันแล้ว
- `video_thumbnail` (ใช้สร้าง thumbnail ของคลิป Pop) — เวอร์ชันจาก pub.dev (0.5.6, ล่าสุด) build ไม่ผ่านบน AGP 9.1.0 (`android/settings.gradle.kts`) เพราะ `android/build.gradle` ของแพ็กเกจใช้ `jcenter()` (ถูกลบออกจาก Gradle แล้ว) และ apply AGP แบบเก่า แก้แล้วด้วยการ vendor สำเนา local ที่แพตช์เฉพาะ `android/build.gradle` (ดู `packages/video_thumbnail/NOTICE.md`) — ถ้าเพิ่มปลั๊กอินตัวใหม่แล้วเจอ error แบบเดียวกัน (`Could not find method jcenter()`) ให้ใช้แนวทางเดียวกันนี้
- ยังไม่ได้ทดสอบ flow จริงบนอุปกรณ์ — งานนี้เป็นของ AI QA & Security รอบถัดไป (ห้าม deploy ก่อนผ่าน QA)

## โครงสร้างโค้ด

```
lib/
  core/env.dart                          # อ่าน Supabase URL/publishable key จาก --dart-define
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
