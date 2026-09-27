# WYNOS for Android

แอป Android ของ **WYNOS Web Beta1** สำหรับลง Google Play

## ทำงานยังไง

แอปนี้เป็น **Trusted Web Activity (TWA)** คือแอป Android จริง (มีไอคอน, splash, ชื่อ package ของตัวเอง, ลง Google Play ได้, แจ้งเตือนขึ้นเป็นของแอป WYNOS) ที่เปิด `https://wynos.online` แบบเต็มจอผ่าน Chrome ในเครื่อง

- ใช้โค้ดเว็บ `web/` ตัวเดียวกับ wynos.online ทั้งหมด → ฟีเจอร์ครบเท่า Beta1 ทันที และทุกครั้งที่ deploy เว็บ แอปอัปเดตตามโดยไม่ต้องส่ง Play ใหม่
- **Google Sign-in ใช้ได้** (Google ห้าม sign-in ใน WebView แต่ TWA ใช้ Chrome จริง)
- **Web Push** ขึ้นเป็นการแจ้งเตือนของแอป WYNOS (ผ่าน `DelegationService`) และขอ permission แจ้งเตือนของ Android 13+ ให้
- ลิงก์ `https://wynos.online/...` ที่กดจากแอปอื่น (LINE, Messenger ฯลฯ) เปิดในแอปได้เลย
- ถ้าเครื่องไม่มี Chrome/เบราว์เซอร์ที่รองรับ TWA จะเปิดเป็น Custom Tab (ไม่ใช้ WebView)

| ค่า | ใช้อะไร |
| --- | --- |
| Package name | `online.wynos.app` (**เปลี่ยนไม่ได้หลังขึ้น Play ครั้งแรก**) |
| Version | `1.0.0-beta1` (versionCode 1) |
| minSdk / targetSdk | 23 (Android 6) / 36 (Android 16) |
| ไลบรารี | `com.google.androidbrowserhelper:androidbrowserhelper` (Google) |

## แถบ URL ด้านบน / Digital Asset Links

Chrome จะเปิดเต็มจอ (ไม่มีแถบ URL) ก็ต่อเมื่อ `https://wynos.online/.well-known/assetlinks.json` ระบุ SHA-256 fingerprint ของ key ที่เซ็นแอปที่ติดตั้งอยู่ เว็บอ่านค่านี้จาก environment variable บน Vercel:

```
ANDROID_TWA_SHA256_FINGERPRINTS=AA:BB:...:FF,11:22:...:99
```

ใส่ได้หลายค่า คั่นด้วย `,` ควรใส่:

1. **App signing key** จาก Play Console → *Test and release → App integrity → App signing* (ตัวที่ผู้ใช้ติดตั้งจาก Play)
2. **Upload key** (ใช้ทดสอบ APK ที่เซ็นเองก่อนขึ้น Play) — ดูด้วย `keytool -list -v -keystore upload.jks`

ถ้ายังไม่ได้ตั้งค่า แอปยังเปิดได้ปกติ แค่มีแถบ URL ของ Chrome ด้านบน (`assetlinks.json` คืนค่า `[]`)

## Build

ต้องมี JDK 17+ และ Android SDK (API 36)

```bash
cd android
echo "sdk.dir=$ANDROID_HOME" > local.properties   # ครั้งแรกครั้งเดียว
./gradlew assembleDebug     # APK ทดสอบ → app/build/outputs/apk/debug/app-debug.apk
./gradlew bundleRelease     # AAB สำหรับ Play → app/build/outputs/bundle/release/app-release.aab
```

หรือรัน GitHub Actions workflow **Android App (TWA)** แบบ manual (*Run workflow*) จะได้ทั้ง debug APK และ release AAB เป็น artifact

## Signing (Upload key)

ห้าม commit keystore หรือรหัสผ่านเด็ดขาด (`*.jks`, `keystore.properties` ถูก git-ignore แล้ว)

สร้าง upload key ครั้งเดียว แล้วเก็บไฟล์กับรหัสผ่านไว้ที่ปลอดภัย (ถ้าหาย ต้องขอ reset upload key กับ Google):

```bash
keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
```

- **เครื่อง local:** สร้าง `android/keystore.properties`
  ```
  storeFile=/path/to/upload.jks
  storePassword=...
  keyAlias=upload
  keyPassword=...
  ```
- **GitHub Actions:** ตั้ง repository secrets `WYNOS_ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`), `WYNOS_ANDROID_KEYSTORE_PASSWORD`, `WYNOS_ANDROID_KEY_ALIAS`, `WYNOS_ANDROID_KEY_PASSWORD`

ไม่มีทั้งสองอย่าง → `bundleRelease` ได้ AAB ที่ยังไม่เซ็น (อัปขึ้น Play ไม่ได้)

## ขั้นตอนขึ้น Google Play (Founder)

1. สมัคร Google Play Developer account (ค่าธรรมเนียมครั้งเดียว $25) — บัญชีส่วนตัวที่สร้างใหม่ต้องทำ closed testing กับผู้ทดสอบอย่างน้อย 12 คนต่อเนื่อง 14 วันก่อนขอ production ได้; บัญชีองค์กร (organization) ไม่ต้อง
2. Play Console → *Create app* → ชื่อ WYNOS, ภาษาเริ่มต้นไทย, App, Free
3. สร้าง upload key + build `app-release.aab` ที่เซ็นแล้ว (หัวข้อด้านบน) แล้วอัปขึ้น track **Internal testing** ก่อน (เปิด Play App Signing ตามค่า default)
4. คัดลอก SHA-256 ของ App signing key (และ upload key) ใส่ `ANDROID_TWA_SHA256_FINGERPRINTS` บน Vercel แล้ว redeploy เว็บ — ตรวจที่ `https://wynos.online/.well-known/assetlinks.json`
5. ติดตั้งจาก internal testing บนมือถือ Android → ต้องเปิดเต็มจอไม่มีแถบ URL, login Google ได้, เปิดแจ้งเตือนได้
6. กรอก Store listing (ไอคอน 512×512, feature graphic 1024×500, screenshot มือถือ ≥ 2 รูป), Privacy policy URL, Data safety, Content rating, Target audience
7. QA & Security ผ่าน → Founder อนุมัติ → promote ไป Production

## อัปเดตเวอร์ชันแอป

การเปลี่ยนแปลงของเว็บไม่ต้องอัปเดตแอป ส่ง AAB ใหม่เฉพาะเมื่อแก้ไฟล์ใน `android/` (ไอคอน, splash, สี, permission) โดยเพิ่ม `versionCode` (+1 ทุกครั้ง) และ `versionName` ใน `app/build.gradle.kts`
