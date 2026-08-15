# ZOKY Sellers by WYN — App (V1)

Flutter + Supabase mobile app for sellers on ZOKY Marketplace. Implements
**SELLER-001: Foundation** (see
`.wyn/tasks/backlog/SELLER-001-foundation.md` and
`.wyn/docs/design/seller-001-foundation.md`) — sign-in, "สมัครร้าน" (store
registration), and a Seller Dashboard.

A separate Flutter app from `app/` (WYN Social / ZOKY Marketplace
Customer), sharing the **same Supabase project** and the same
`auth.users`/`profiles` tables -- a seller is just an existing WYN user
who registers a store. See `.wyn/company/DECISIONS.md`, 2026-08-15
("Phase 4 (ZOKY Sellers by WYN) — Founder แก้ไขคำตัดสินใจเป็นแอปแยกต่างหาก").

## สถานะปัจจุบัน (สำคัญ — อ่านก่อน)

โปรเจกต์นี้ผ่านการตรวจสอบด้วย Flutter SDK จริงแล้ว (Flutter 3.47.0 stable):

- ✅ `flutter create --org io.wyn --project-name zoky_seller --platforms=android,ios seller_app` — สร้างโฟลเดอร์ `android/` และ `ios/` แล้ว (คอมมิตไว้ในนี้), ปรับ bundle ID/applicationId เป็น `io.wyn.zokyseller` ด้วยมือหลังสร้าง
- ✅ `flutter pub get` — resolve dependencies สำเร็จ (`pubspec.lock` คอมมิตไว้แล้ว)
- ✅ `flutter analyze` — **No issues found**
- ✅ `flutter test` — **All tests passed! (17/17)**
- ❌ `flutter build apk` / `flutter build ios` — **ยังไม่ได้ทำ** เพราะ sandbox ที่ตรวจสอบไม่มี Android SDK / Xcode ให้ build จริงจนออกมาเป็นไฟล์ APK/IPA ได้ ต้องทำในเครื่อง dev หรือ CI ที่มี toolchain ครบ
- ❌ ยังไม่ได้ทดสอบ flow จริงบนอุปกรณ์/emulator เพราะยังไม่มี Supabase project จริงเชื่อมต่อ — งานนี้เป็นของ AI QA & Security

### ต้องทำก่อนรันแอปได้จริงบนอุปกรณ์/emulator

1. Clone repo แล้วเข้าไปที่โฟลเดอร์ `seller_app/`
2. รัน `flutter pub get`
3. Supabase project **เดียวกับ** `app/` — ต้องรัน `supabase/schema.sql` (อยู่ที่ root ของ repo) ตัวเดียวกันไว้แล้ว ไม่มี schema แยกสำหรับแอปนี้
4. เปิดใช้งาน Auth providers ใน Supabase dashboard เหมือนกับที่ `app/` ต้องการ: Google OAuth, Apple OAuth, Phone (SMS OTP)
5. ตั้งค่า native URL scheme (`io.wyn.zokyseller://login-callback`) สำหรับ OAuth redirect ใน `android/app/src/main/AndroidManifest.xml` และ `ios/Runner/Info.plist` (ยังไม่ได้ตั้งค่า — ดู Known Issues, เหมือนกับสถานะเดิมที่ `app/`'s README มีมาตั้งแต่ WYN-002)
6. รันแอปพร้อมส่งค่า config (ค่าเดียวกับที่ใช้กับ `app/`):
   ```
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=xxxx
   ```

### Known Issues / งานที่เหลือ

- Google/Apple OAuth ใช้ Supabase `signInWithOAuth` (web redirect flow) — ยังไม่ได้ตั้งค่า native URL scheme (`io.wyn.zokyseller://login-callback`) ใน `AndroidManifest.xml`/`Info.plist`
- Apple Sign-In ต้องเปิดใช้งาน capability "Sign in with Apple" ใน Xcode และ Apple Developer account ก่อน
- ยังไม่มี Supabase project จริงให้เชื่อมต่อทดสอบ end-to-end
- `flutter build` (APK/IPA) ยังไม่เคยรันสำเร็จเพราะไม่มี Android SDK/Xcode ในเครื่องที่ตรวจสอบ — มีแค่ `flutter analyze`/`flutter test` ที่ยืนยันแล้ว
- **Seller Approval auto-approved**: สร้างร้านแล้วขายได้ทันที ไม่มี Admin ตรวจสอบก่อนรอบนี้ (รอ WYN Admin, Phase 6) — เป็นความเสี่ยงที่ยอมรับได้ชั่วคราว ไม่ใช่การมองข้าม (ดู Product spec's Risks)
- **1 seller ต่อ 1 ร้าน**: ขอบเขต V1 ตั้งใจ ไม่มี store switcher UI (ดู Product spec's Risks)
- **Balance/Payout** ยังไม่มีระบบรองรับเลย — Dashboard แสดง "เร็ว ๆ นี้" แทนตัวเลข ไม่ใช่การมองข้าม
- ยังไม่ได้ทดสอบ flow จริงบนอุปกรณ์ — งานนี้เป็นของ AI QA & Security รอบถัดไป (ห้าม deploy ก่อนผ่าน QA)

## โครงสร้างโค้ด

```
lib/
  core/
    env.dart                            # อ่าน Supabase URL/publishable key จาก --dart-define (ชี้ Supabase project เดียวกับ app/)
    text_utils.dart                     # thaiBahtLabel — duplicate จาก app/ เพื่อ format เงินให้ตรงกัน
  main.dart                             # entry point + theme (Blue+White+Soft Gray, seed 0xFF2D6CDF, เหมือน app/)
  features/
    auth/
      data/seller_auth_repository.dart  # ครอบ Supabase Auth + profile calls — mirror app/'s AuthRepository เป๊ะ
      presentation/
        seller_auth_gate.dart           # ตัดสินใจหน้าจอจาก auth + onboarding + store state
        seller_sign_in_screen.dart      # รวม Welcome+AuthMethod เดิมของ app/ เป็นหน้าเดียว
        phone_entry_screen.dart         # ported ตรงจาก app/ ไม่ปรับ logic
        otp_verification_screen.dart    # ported ตรงจาก app/ ไม่ปรับ logic
        username_setup_screen.dart      # ported ตรงจาก app/ ไม่ปรับ logic
    store/
      data/
        store.dart                      # Store model (duplicate จาก app/'s ZOKY Store model, ไม่มี productCount)
        seller_repository.dart          # fetchMyStore/createStore/fetchOrderCounts/fetchSalesSummary/fetchBestSellingProducts
      presentation/create_store_screen.dart  # "สมัครร้าน" ฟอร์มขั้นต่ำ
    shell/presentation/
      seller_home_shell.dart            # Bottom Nav 5 tab (IndexedStack, mirror app/'s RootShell)
      seller_coming_soon_screen.dart    # placeholder เดียวสำหรับ 4 tab ที่ยังไม่ทำ
    dashboard/presentation/
      seller_dashboard_screen.dart      # New/Total Orders, Sales วันนี้/เดือนนี้/รวม, Best Selling top 5
```
