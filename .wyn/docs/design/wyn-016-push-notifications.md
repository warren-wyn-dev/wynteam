# Design Spec — WYN-016 (Push Notification)

> โดย AI Design — 2026-08-16 | ต่อยอด WYN-012/WYN-015/ZOKY-005 (13 ประเภท notification ที่มี trigger ครบแล้ว) ไม่แก้ trigger เดิมเลยแม้แต่ตัวเดียว

## สถาปัตยกรรม

```
notifications INSERT (trigger เดิม 13 ตัว ไม่แก้)
        │
        ▼ (Supabase Database Webhook — ตั้งค่าผ่าน Dashboard, ไม่ใช่ SQL)
Edge Function: send-push-notification
        │  1. ดึง actor profile (username/display_name)
        │  2. ดึงชื่อ club/store ถ้ามี (club_id/order_id)
        │  3. ประกอบข้อความไทย (mirror ข้อความ in-app ที่มีอยู่แล้ว)
        │  4. ดึง push_tokens ทั้งหมดของ recipient_id
        │  5. ยิง FCM v1 API ทีละ token (ลบ token ที่ตายแล้วทิ้งอัตโนมัติ)
        ▼
Firebase Cloud Messaging → อุปกรณ์ผู้ใช้
```

**ทำไมใช้ Database Webhook ผ่าน Dashboard แทนที่จะเขียน trigger ลง `schema.sql`**: `supabase_functions.http_request()` (กลไกเบื้องหลัง Database Webhook) ไม่มีอยู่ใน Postgres เปล่า ทำให้ QA รอบนี้ (ที่ยืนยัน `schema.sql` ทุกไฟล์ด้วยการรันจริงกับ Postgres 16 local ตลอดทั้งเซสชัน) ตรวจสอบไม่ได้ถ้าใส่ลงไปตรงๆ — เก็บ `schema.sql` ไว้เป็นส่วนที่ verify ได้ 100% เหมือนเดิม แล้วให้ Founder ตั้งค่า Webhook ผ่าน Dashboard เป็นขั้นตอนเดียว (Database → Webhooks → New webhook → Table: `notifications`, Event: Insert, Target: Edge Function) เหมือนขั้นตอน "เปิด Allow anonymous sign-ins" ที่ทำไปแล้วก่อนหน้านี้

## Client-side (ทั้ง `app/` และ `seller_app/`)

- เพิ่ม `firebase_core`/`firebase_messaging` ใน `pubspec.yaml` — **ไม่แตะไฟล์ native (`android/`, `ios/`) เลยในรอบนี้** เพราะยังไม่มี `google-services.json`/`GoogleService-Info.plist` จริงจาก Founder ถ้าใส่ native config plugin (`com.google.gms.google-services`) ไปตอนนี้จะทำให้ build APK/iOS พังทันทีที่ไม่มีไฟล์ config
- `Firebase.initializeApp()` เรียกใน `main.dart` ห่อด้วย `try/catch` — ไม่มี config จริงตอนนี้จะ throw แล้วถูกจับเงียบๆ แอปทำงานต่อปกติทุกอย่างเหมือนเดิม (เหมือนพฤติกรรมก่อนมี push เลย) เมื่อ Founder ใส่ config จริงเข้ามาทีหลัง โค้ด Dart ส่วนนี้ **ไม่ต้องแก้อะไรเพิ่มเลย** จะเริ่มทำงานเองทันที
- `PushNotificationService` (ใหม่) ห่อ `FirebaseMessaging.instance` ทุกจุด: ขอ permission, `getToken()`, `onTokenRefresh` stream, `onMessage` (foreground), `onMessageOpenedApp`/`getInitialMessage` (แตะ push แล้วเปิดแอป) — ทุก method เช็ค `Firebase.apps.isNotEmpty` ก่อนเรียกจริง ถ้า Firebase ไม่ได้ init (ยังไม่มี config) จะ no-op เงียบๆ ไม่ throw ออกมาให้ UI เห็น
- ขอ permission **หลัง onboarding เสร็จ** (ครั้งแรกที่ `RootShell`/`SellerHomeShell` render) — ไม่ขอตั้งแต่หน้า Welcome (ผู้ใช้ยังไม่รู้จักแอปเลย ขอสิทธิ์ตอนนั้นจะถูกปฏิเสธเยอะ) ใช้ native permission prompt ของระบบตรงๆ ไม่สร้างหน้า pre-permission education เพิ่ม (ยังไม่มี requirement ให้ทำ ไม่ควรเพิ่มเอง)
- `PushTokenRepository` (ใหม่ ทั้ง 2 แอป มิเรอร์กันเหมือน pattern อื่น) — `upsertToken()`/`deleteToken()` เขียนเข้า `push_tokens` table ตรงๆ ผ่าน Supabase client เป็น CRUD ธรรมดา ไม่พึ่ง Firebase SDK เลย จึงเทสได้เต็มรูปแบบทันทีไม่ต้องรอ Firebase project จริง
- แตะ push แล้วเปิดหน้า: ใช้ `GlobalKey<NavigatorState>` (`rootNavigatorKey`) ผูกกับ `MaterialApp.navigatorKey` เพื่อ push route จากนอก widget tree ได้ (background/terminated tap handler ไม่มี BuildContext ของ widget ใดให้ใช้) — payload `data` ที่ FCM ส่งมามี field เดียวกับคอลัมน์ตาราง `notifications` เป๊ะ (`type`, `drop_id`, `pop_id`, `club_id`, `club_post_id`, `order_id`, `actor_id`) จึง parse ด้วย logic เดียวกับที่ `WynNotification.fromMap`/`SellerNotification.fromMap` ใช้อยู่แล้ว ไม่ประดิษฐ์ mapping ใหม่

## Edge Function

- Deno, ที่ `supabase/functions/send-push-notification/index.ts`
- อ่าน service account JSON จาก secret `FCM_SERVICE_ACCOUNT` (Founder ต้องตั้งผ่าน `supabase secrets set` หรือ Dashboard) — เซ็น JWT ด้วย private key ของ service account (RS256, ผ่าน `crypto.subtle` ของ Deno ไม่พึ่ง library ภายนอกที่ไม่รองรับ Edge runtime) แลก access token จาก Google OAuth2 token endpoint แล้วเรียก `https://fcm.googleapis.com/v1/projects/{project_id}/messages:send`
- ข้อความไทย mirror จาก `_messageFor` ใน `notification_list_screen.dart`/`seller_notification_list_screen.dart` ทุกตัวอักษร (13 ประเภท) — คนละภาษา (TypeScript) แต่เนื้อหาต้องตรงกันเป๊ะ มี comment ชี้กลับไปที่ไฟล์ต้นทางเพื่อกันข้อความสองฝั่งเพี้ยนออกจากกันในอนาคต
- Token ที่ FCM ตอบ `UNREGISTERED`/`INVALID_ARGUMENT` → ลบออกจาก `push_tokens` อัตโนมัติ (self-cleaning) ไม่ throw error กระทบ token อื่นในชุดเดียวกัน

## Acceptance (สิ่งที่ยืนยันได้จริงในรอบนี้ ไม่ต้องรอ Firebase)

- `push_tokens` table + RLS ผ่าน QA ด้วยการรันจริงกับ Postgres local (เหมือนทุกตารางก่อนหน้า)
- `PushTokenRepository` มี unit-style test (Recording pattern) ยืนยัน upsert/delete เรียกถูก
- `flutter analyze`/`flutter test` ผ่านสะอาดทั้ง 2 แอป หลังเพิ่ม `firebase_core`/`firebase_messaging` (ยืนยันว่าไม่กระทบอะไรที่มีอยู่)
- Edge Function เขียนเสร็จ ตรวจ logic ด้วยการอ่าน/reasoning อย่างละเอียด (ยิงจริงไม่ได้จนกว่าจะมี Firebase service account จริง — บันทึกไว้ชัดเจนใน QA)
