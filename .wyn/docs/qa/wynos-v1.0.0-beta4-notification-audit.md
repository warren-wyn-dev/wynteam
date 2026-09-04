# WYNOS v1.0.0 Beta4 — Notification & Web Push Audit

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta4-master-implementation-j5lke8` — **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ขอบเขต: Beta4 §11 ทั้งหมด (11.1–11.8), §17 (Functional QA — Notifications)
> Environment: Flutter 3.47.1 · Deno (deno check + deno test สำหรับ Edge Function)
> **ไม่มี Firebase project และไม่มี Supabase production credential ใน session นี้** — ทุกข้อความติดป้ายว่าตรวจที่ไหน

---

## 0. สรุปสั้น — สิ่งที่สำคัญที่สุดที่ต้องรู้

**ก่อน Beta4 Web Push ไม่ได้ "ตั้งค่าไม่ครบ" แต่มัน *เป็นไปไม่ได้เชิงโครงสร้าง*:**

1. `main.dart` เรียก `Firebase.initializeApp()` **โดยไม่ส่ง options** — บน Flutter Web ไม่มีไฟล์ config แบบ native ให้อ่าน คำสั่งนี้ throw **ทุกครั้งที่เปิดเว็บ** ไม่ว่าจะตั้งค่า Firebase ดีแค่ไหน → `Firebase.apps` ว่าง → ทุก method ของ `PushNotificationService` เดิน no-op path
2. ไม่มี `web/firebase-messaging-sw.js` — ต่อให้ init สำเร็จ ก็ไม่มีที่ให้ push ลงเมื่อแท็บปิดหรืออยู่เบื้องหลัง ซึ่งเป็นกรณีเดียวที่แยก push notification ออกจาก in-app notification

Beta4 แก้ทั้งสองข้อ และแก้ปัญหา UX ที่ใหญ่กว่านั้น: **การขอ permission**

---

## 1. §11.2 — Permission Flow (การเปลี่ยนแปลงที่สำคัญที่สุดในหมวดนี้)

### สภาพก่อน

```dart
// RootShell.initState
PushNotificationService(PushTokenRepository(client)).initialize();

// PushNotificationService.initialize
final settings = await messaging.requestPermission();  // ← OS dialog เด้งทันที
```

Dialog ของระบบเด้งขึ้น **วินาทีที่ onboarding จบ** — ก่อนที่ผู้ใช้จะได้อ่านโพสต์แม้แต่โพสต์เดียว และไม่มีคำอธิบายว่ากำลังตกลงกับอะไร

**ทำไมนี่ร้ายแรงกว่าที่เห็น:** permission นี้คือ prompt ที่ทุก platform ให้ถามได้ **ครั้งเดียว** การกด "Don't Allow" แบบสะท้อนกลับตรงนั้นเป็นการปฏิเสธถาวร และไม่มี UI ใดในแอปเปิดมันกลับมาได้อีก

นี่คือสิ่งที่ §11.2 ห้ามไว้ตรงตัว: *"ห้ามขอ Permission ทันทีโดยไม่มี UX ที่เหมาะสม"*

### สภาพหลัง

| | ก่อน | หลัง |
|---|---|---|
| `initialize()` ทำอะไร | **ขอ** permission | **รับช่วง** permission ที่ได้มาแล้ว — ถ้ายังไม่เคยถาม จะไม่ทำอะไรเลย |
| ใครเป็นคนขอ | แอป (อัตโนมัติ) | **ผู้ใช้** (กดปุ่ม) |
| ขอที่ไหน | ไม่มีบริบท | การ์ดบนหน้า **การแจ้งเตือน** + แถวใน **ตั้งค่า → การแจ้งเตือน** |
| มีคำอธิบายก่อนไหม | ไม่มี | มี — บอกว่าจะได้รับเรื่องอะไร และเลือกหมวดได้ที่ไหน |

**ทำไมวางการ์ดไว้บนหน้า Notifications:** คนที่เพิ่งเปิดหน้าที่มีหน้าที่แสดงการแจ้งเตือน ได้บอกไปแล้วว่าเขาสนใจการแจ้งเตือน และการ์ดกำลังถามถึงสิ่งที่เขากำลังมองอยู่พอดี

### 4 สถานะ ที่ §11.2 บังคับให้จัดการแยกกัน

```dart
enum PushPermissionState { unsupported, notDetermined, granted, denied }
```

| สถานะ | ความหมาย | UI ทำอะไร |
|---|---|---|
| `notDetermined` | ยังไม่เคยถาม | **สถานะเดียวที่ได้รับอนุญาตให้แสดง OS prompt** — และเฉพาะหลังกดปุ่มเท่านั้น |
| `granted` | ตกลงแล้ว (รวม iOS `provisional` = quiet delivery ซึ่งเป็นการอนุญาตจริง) | ไม่แสดงอะไรเลยบนหน้า Notifications · ตั้งค่าแสดง ✓ |
| `denied` | ปฏิเสธ | **บอกครั้งเดียว ไม่ถามซ้ำ** — ไม่มีปุ่ม เพราะไม่มี platform ไหนแสดง prompt ซ้ำ ปุ่มที่กดแล้วไม่เกิดอะไรแย่กว่าไม่มีปุ่ม · ชี้ไปที่การตั้งค่าระบบ · ย้ำว่า in-app notification ยังทำงานปกติ |
| `unsupported` | ไม่มี Firebase config เลย หรือเป็น web ที่ไม่มี VAPID key | **ไม่แสดงอะไรทั้งสิ้น** — ไม่เสนอสิ่งที่ build นี้ทำให้ไม่ได้ |

`dismissed` ตามที่ §11.2 ระบุ: บน iOS/browser การปัด dialog ทิ้งถูกรายงานกลับมาเป็น `denied` จึงเข้ากรณีเดียวกัน ส่วนปุ่ม "ไม่ใช่ตอนนี้" ของการ์ดเป็น dismiss **ของ WYNOS เอง** (ไม่แตะ OS เลย — มี test ยืนยันว่า `requestCalls == 0`) และตั้งใจไม่ persist: หน้า Notifications remount ทุกครั้งที่กด tab อยู่แล้ว ถ้า persist ไว้ การกดพลาดครั้งเดียวจะลบทางเข้าเดียวที่เหลือไปตลอดกาล

**หลักฐาน:** `test/push_permission_card_test.dart` — 7 test ครอบทั้ง 4 สถานะ + สถานะระหว่างโหลด และ test ที่สำคัญที่สุดคือ *การแสดงการ์ดต้องไม่ไปแตะ OS prompt เอง*

---

## 2. §11.2 — Web Push (ของใหม่จริง)

### 2.1 Firebase options สำหรับ web

`lib/core/push_env.dart` — อ่านจาก `--dart-define` แบบเดียวกับที่ `Env` อ่าน Supabase:

```
FIREBASE_WEB_API_KEY, FIREBASE_WEB_APP_ID, FIREBASE_MESSAGING_SENDER_ID,
FIREBASE_PROJECT_ID, FIREBASE_AUTH_DOMAIN, FIREBASE_STORAGE_BUCKET,
FIREBASE_VAPID_KEY
```

**ค่าเหล่านี้ไม่ใช่ความลับ** — Firebase Web config เป็น public by design (ติดไปกับ web bundle ทุกอันที่ใช้มัน และ Google ระบุไว้เอง) ที่ใส่ไว้หลัง `--dart-define` เพราะเหตุผลเดียวกับ `Env`: repo ไม่ต้องเก็บค่าเฉพาะ environment และ build ที่ไม่ตั้งค่า (ทุก CI run, ทุก `flutter test`) จะได้ empty string → `isConfigured == false` → ไม่มีอะไร half-start

`main.dart` แยกทาง web ออกมา:

```dart
if (kIsWeb) {
  if (PushEnv.isConfigured) await Firebase.initializeApp(options: ...);
} else {
  await Firebase.initializeApp();   // native อ่านไฟล์ config ของตัวเอง
}
```

**พฤติกรรมเมื่อไม่ได้ตั้งค่า = เท่ากับก่อน Beta4 ทุกประการ** — `Firebase.apps` ว่าง ทุก push path no-op

### 2.2 Service Worker

`web/firebase-messaging-sw.js` (ไฟล์ใหม่)

* ชื่อและตำแหน่งถูกกำหนดตายตัวโดย Firebase SDK (`/firebase-messaging-sw.js` ที่ root ของ origin) — ห้ามเปลี่ยนชื่อหรือย้าย
* Service worker เป็นไฟล์ static ที่ host เสิร์ฟ **ไม่ใช่ส่วนหนึ่งของ Flutter bundle** จึงอ่าน `--dart-define` ไม่ได้ → อ่าน config จาก query string ที่ Firebase ต่อท้ายตอนลงทะเบียน worker (ไม่มีสำเนาค่าที่สองในไฟล์นี้)
* มี guard: ถ้า 4 ค่าที่จำเป็นไม่ครบ จะไม่ `initializeApp` เลย (ไม่งั้น throw ข้างใน worker ที่ไม่มีใครเห็น)
* `onBackgroundMessage` → `showNotification` พร้อม icon/badge ของ WYNOS และ `tag` = notification id (ดู §4)
* `notificationclick` → focus แท็บ WYNOS ที่เปิดอยู่ถ้ามี แทนที่จะเปิดแท็บใหม่

**สิ่งที่ตั้งใจ *ไม่* ทำใน service worker:** ไม่ทำ routing เอง — ปลายทางของทุก notification type ตัดสินที่เดียวใน `PushNotificationService._openFromPushData` และ WYNOS ไม่มี URL routing ให้แปลงเป็น URL ได้อยู่แล้ว (เป็น single-route Flutter app ที่ navigate ด้วย `Navigator.push`) การเขียน switch ซ้ำเป็น JavaScript = สำเนาที่สองที่จะ diverge เงียบๆ

---

## 3. §11.1 — In-App Notifications

| รายการ | สถานะ | หมายเหตุ |
|---|---|---|
| Notification List | ✅ ไม่เปลี่ยน | pagination 30/หน้า, group by วัน (วันนี้/เมื่อวานนี้/เก่ากว่านี้), รวมแถว type+target เดียวกันในวันเดียวกัน |
| Read / Unread | ✅ ไม่เปลี่ยน | `_unreadSnapshot` ถูกถ่ายไว้ตอน fetch ครั้งแรก และไม่ derive ใหม่หลัง `markAllAsRead` — ตั้งใจ ไม่งั้น highlight จะหายวับก่อนผู้ใช้ทันเห็น |
| Unread Count | ✅ **แก้แล้ว** | ดู §5 |
| Badge | ✅ **แก้แล้ว** | ดู §5 |
| Timestamp | ✅ ไม่เปลี่ยน | `relativeTimeLabel` |
| Loading | ✅ ไม่เปลี่ยน | spinner ตอนโหลดครั้งแรก, spinner ท้ายลิสต์ตอน paginate |
| Empty | ✅ ไม่เปลี่ยน | `EmptyStateBlock` ทั้ง "ทั้งหมด" และ "การกล่าวถึง" |
| Error | ✅ ไม่เปลี่ยน | ข้อความ + ปุ่มลองใหม่ |
| Notification types | ✅ ไม่เปลี่ยน | 24 type ที่มีอยู่ ไม่เพิ่มไม่ลด |

---

## 4. §11.6 — Duplicate Protection

### ปัญหาจริง (ไม่ใช่สมมติ)

`send-push-notification` ถูกขับด้วย Supabase **Database Webhook** และ webhook ที่ไม่ได้รับ 200 ทันเวลาจะถูก **retry** ก่อน Beta4 การ retry ผลิต notification ซ้ำอันที่สองบนเครื่อง — แถวใน DB insert ไปแล้วรอบเดียว in-app list จึงถูก แต่โทรศัพท์ขึ้นสองครั้ง

### การแก้

`buildDataPayload` แนบ `notification_id` (= id ของแถว) และ `collapseKeyFor(row)` ป้อนให้ทั้ง 3 ชั้นการส่ง:

| Platform | field |
|---|---|
| Web | `webpush.headers.Topic` + `tag` ที่ service worker ตั้งบน `showNotification` |
| Android | `android.collapse_key` |
| iOS | `apns.headers.apns-collapse-id` |

Collapse key **ไม่ได้กันการส่งครั้งที่สอง** — มันทำให้ครั้งที่สองไป *ทับ* ครั้งแรกแทนที่จะไปวางข้างๆ ซึ่งเป็นพฤติกรรมที่ทุก platform มีให้ และเป็นทางเดียวที่ทำได้โดยไม่ต้องสร้าง ledger การส่งของตัวเอง

**key เป็น row id ไม่ใช่ type+target โดยตั้งใจ:** คนสองคนกดไลก์โพสต์เดียวกัน = 2 การแจ้งเตือนที่คนควรเห็นแยกกัน (และ in-app list จัดกลุ่มให้แล้วด้วย `_groupWithinDay`) collapse จึงจำกัดที่การส่งซ้ำของ *แถวเดียวกัน* เท่านั้น

**หลักฐาน:** `_lib.test.ts` — 3 test ใหม่: key = row id, key ต่างกันสำหรับ 2 notification คนละแถวบนโพสต์เดียวกัน, และ key ยาวไม่เกิน 64 byte ตามข้อจำกัดของ `apns-collapse-id` (uuid = 36 byte)

`deno check` ผ่าน · `deno test` 20/20 ผ่าน

### ฝั่ง client / reconnect / refresh

| จุด | ผล |
|---|---|
| `_notifications` list ตอน paginate | ✅ ไม่พบปัญหา — Beta3 แก้ duplicate-key ไปแล้ว |
| tab "การกล่าวถึง" | ✅ filter จากลิสต์เดิม ไม่ยิง fetch ที่สอง |
| `markAllAsRead` | ✅ update เดียว `eq(is_read, false)` — เรียกซ้ำไม่ทำอะไรเพิ่ม |
| foreground push → badge refresh | ✅ ใหม่ — เป็น count query ไม่ใช่การเพิ่มแถว จึงซ้ำไม่ได้ |

---

## 5. §11.4 — Unread & Badge (บั๊กจริงที่พบและแก้)

### B4-N1 — badge ค้างได้นานเท่าที่แอปเปิดอยู่

**อาการ:** `_unreadNotificationCount` ถูกอ่านครั้งเดียวใน `RootShell.initState` และไม่มีอะไรบอกให้อ่านใหม่ การแจ้งเตือนที่มาถึงตอนคนกำลังเลื่อน Home หรือตอนแอปอยู่เบื้องหลัง ทำให้กระดิ่งแสดงเลขเดิมจนกว่าจะเปิด tab การแจ้งเตือน หรือรีสตาร์ทแอป

**ทำไมเพิ่งเจอ:** ไม่มี realtime subscription สำหรับ notifications (ตรวจแล้ว — grep `channel`/`onPostgresChanges` ใน `features/notification` และ `features/root` ได้ 0 ผลลัพธ์)

**การแก้ — 2 จุด event-driven ไม่มี polling:**

1. **`didChangeAppLifecycleState` → `resumed`** — คือทั้งจังหวะที่ภาพของแอปมีโอกาสผิดมากที่สุด และเป็นจังหวะเดียวที่คนกลับมาเห็น badge ได้อีก
2. **`FirebaseMessaging.onMessage`** — FCM ไม่แสดง notification เองตอนแอปอยู่ foreground (by design) นี่จึงเป็นสัญญาณเดียวที่บอกว่ามีของมาถึง

**ไม่ทำ polling โดยเจตนา:** §11.7 ห้ามไว้ตรงตัว และ timer ก็ผิดในตัวมันเอง — มันจ่าย query ทุกช่วงเวลาให้กับกรณีที่พบบ่อยที่สุดคือ "ไม่มีอะไรเปลี่ยน"

**ไม่แสดง in-app banner ตอน foreground push:** นั่นคือ UI surface ใหม่ ซึ่งอยู่นอกขอบเขต Beta4 — callback แค่บอก badge ว่าตัวเลขขยับ

**หลักฐาน:** `test/root_shell_test.dart` — 3 test: observer ถูก register จริง, resume แล้วอ่านใหม่และเลขเปลี่ยน, background อย่างเดียวไม่อ่าน

### รายการ §11.4 อื่นๆ

| ข้อกำหนด | ผล |
|---|---|
| จำนวนถูกต้อง | ✅ `countUnread()` = exact count ที่ `recipient_id = me AND is_read = false` |
| Update ถูกต้อง | ✅ เข้า tab → 0 ทันที (optimistic, ตรงกับที่ `NotificationListScreen.initState` mark read จริง) |
| Refresh แล้วไม่เพี้ยน | ✅ **แก้แล้ว** (B4-N1) |
| Account Switching แล้วไม่ปนกัน | ✅ **แก้แล้ว** — ดู account-switching-audit §1 |
| Login/Logout ถูกต้อง | ✅ `RootShell` เกิดใหม่ทั้งก้อน badge เริ่มที่ 0 แล้ว fetch ใหม่ |
| cap ที่ "9+" | ✅ ไม่เปลี่ยน |

---

## 6. §11.3 — Deep Link

ไม่เปลี่ยน — `_openFromPushData` mirror `NotificationListScreen._openNotification` ตรงทุก case (24 type)

| type | ปลายทาง |
|---|---|
| `like_drop` / `comment_drop` / `mention_drop` / `redrop` | `DropDetailScreen` (fetch by id) |
| `follow` / `follow_request_accepted` | `ViewProfileScreen` ของ actor |
| `club_join_request` | `ClubPage` tab สมาชิก |
| `club_join_approved` | `ClubPage` tab โพสต์ |
| `club_post_like` / `club_post_comment` / `mention_club_post` | `ClubPostDetailScreen` |
| `new_order` / `order_shipped` / `order_cancelled` / `order_refunded` | `ZokyOrderDetailScreen` |
| moderation 4 type | `MyModerationActionScreen` |
| `message_request` | `ConversationScreen` |
| `follow_request` | `FollowRequestListScreen` |
| `system` | no-op โดยตั้งใจ (ข้อความเต็มคือตัว push เอง) |
| `like_pop` / `comment_pop` | SnackBar "เนื้อหานี้ไม่พร้อมใช้งานแล้ว" — WYN-102 ปิด Pop |

ใช้ routing เดิมของระบบตามที่ §11.3 สั่ง — ไม่มี deep-link table แยก

---

## 7. §11.7 — Performance

| ข้อกำหนด | ผล |
|---|---|
| Feed ช้าไหม | ไม่ — notification ไม่แตะ feed path เลย |
| Profile ช้าไหม | **เร็วขึ้น** — Beta4 ตัด `countByAuthor` ออกจาก profile load (4 query → 3) |
| App โหลดช้าไหม | ไม่ — `initialize()` ตอนนี้ทำงาน *น้อยลง* กว่าเดิม (ไม่ขอ permission ไม่ register token ถ้ายังไม่ได้รับอนุญาต) |
| Database หนักขึ้นไหม | เพิ่ม `countUnread()` 1 query ต่อการ resume 1 ครั้ง และ 1 query ต่อ foreground push 1 ครั้ง — ทั้งคู่ผูกกับเหตุการณ์จริง ไม่ใช่เวลา |
| Memory เพิ่มไหม | ไม่ — ไม่มี subscription ใหม่ ไม่มี cache ใหม่ (`onMessage` listener 1 ตัวต่อ RootShell lifetime = 1 ตัวต่อบัญชีที่ signed in) |
| Polling | **ไม่มี** — ยืนยันด้วย test ว่า background อย่างเดียวไม่ยิง query |

---

## 8. §11.8 — Security

อ่านจาก `supabase/schema.sql` โดยตรง:

| ข้อกำหนด | ผล | หลักฐาน |
|---|---|---|
| Ownership | ✅ | `notifications` select policy: `auth.uid() = recipient_id` |
| Authorization | ✅ | ไม่มี insert/delete policy ฝั่ง client เลย — แถวสร้างโดย SECURITY DEFINER trigger เท่านั้น |
| Visibility | ✅ | update policy จำกัด `is_read` ของตัวเอง (`using` + `with check` ทั้งคู่) |
| Push Subscription Ownership | ✅ | `push_tokens` ทั้ง 4 policy ผูก `auth.uid() = user_id` |
| Account Isolation | ✅ **แก้แล้ว** | ดู account-switching-audit §2 |
| Deep Link Authorization | ✅ | `_openFromPushData` fetch ผ่าน repository ปกติ → RLS บังคับใช้ ถ้าเนื้อหาไม่ควรเห็น จะ fetch ไม่ได้และ no-op ไม่มี bypass |
| ผู้ใช้เห็น notification ของคนอื่นได้ไหม | ✅ ไม่ได้ | RLS + ไม่มี query path ไหนอ่านข้าม recipient |

**หมายเหตุ:** category filter 7 หมวด บังคับที่ **ฝั่ง server ก่อน insert แถว** (`internal.notification_enabled`) ไม่ใช่ที่ Edge Function — push จึงสืบทอดการตั้งค่านั้นมาฟรี และไม่มีทางที่ push จะออกไปโดยที่ notification ไม่ควรมีอยู่ตั้งแต่แรก

---

## 9. Browser / Platform Limitations (ต้องรู้ก่อน deploy)

| ข้อจำกัด | ผลกระทบ |
|---|---|
| **iOS Safari** ต้อง "Add to Home Screen" ก่อน | Web Push บน iOS ทำงานเฉพาะ PWA ที่ติดตั้งแล้ว (iOS 16.4+) เปิดใน Safari ปกติจะไม่มี push — เป็นข้อจำกัดของ Apple ไม่ใช่ของ WYNOS `manifest.json` มี `display: standalone` อยู่แล้วจึงติดตั้งได้ |
| Service worker ต้อง HTTPS | production อยู่บน `wynos.online` (HTTPS) — ผ่าน · `localhost` ก็ผ่านตาม spec |
| VAPID key ต้องมี | ถ้าไม่ตั้ง `FIREBASE_VAPID_KEY` → `isWebPushConfigured == false` → `unsupported` → UI ไม่เสนออะไร (ตั้งใจ) |
| Firefox / Brave บล็อกได้ระดับ policy | จับที่ try/catch ใน `currentPermissionState()` → `unsupported` |
| Private browsing | service worker อาจใช้ไม่ได้ → `unsupported` |
| แท็บปิดสนิท | ต้องพึ่ง service worker ล้วนๆ — นี่คือเหตุผลที่ไฟล์นั้นสำคัญ |

---

## 10. สิ่งที่ Founder ต้องทำก่อน Push ใช้งานได้จริง

**ทั้งหมดนี้เป็นงานตั้งค่า ไม่ใช่งานโค้ด** — โค้ดพร้อมแล้วและ dormant อย่างปลอดภัยจนกว่าจะตั้งค่า

1. ✅ **เสร็จแล้ว** — Firebase project `wynos-78e85` (Web app ลงทะเบียนแล้ว)
2. **Native:** วาง `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
   ⚠️ Android ต้อง apply google-services Gradle plugin ด้วย — **ยังไม่ได้ทำ** เพราะการ apply โดยไม่มีไฟล์จริงจะพัง build ทันที (ตัดสินใจไว้ตั้งแต่ WYN-016 ไม่เปลี่ยนใน Beta4)
3. ✅ **เสร็จแล้ว** — **Web:** Firebase Console → Project Settings → Cloud Messaging → Web Push certificates → generate VAPID key (VAPID key เป็นครึ่ง public ของคู่กุญแจ ไม่ใช่ความลับ)
4. ✅ **เสร็จแล้ว** — เพิ่ม 7 `--dart-define` ใน `deploy-web.yml` แล้ว และ **secret ครบทั้ง 7 ตัวใน production build จริง**

   run `33784128418` (2026-09-03 17:24, `0ffcc15`, conclusion `success`) พิมพ์รายตัว:

   ```
   Firebase secrets seen by this build:
     FIREBASE_WEB_API_KEY           present
     FIREBASE_WEB_APP_ID            present
     FIREBASE_MESSAGING_SENDER_ID   present
     FIREBASE_PROJECT_ID            present
     FIREBASE_AUTH_DOMAIN           present
     FIREBASE_STORAGE_BUCKET        present
     FIREBASE_VAPID_KEY             present
   Web Push: configured -- this build can request a push token.
   ```

   ยืนยันกับ production จริงหลัง deploy:
   · `https://wynos.online/firebase-messaging-sw.js` → `200`
   · `main.dart.js` มี `wynos-78e85` อยู่จริง (config ถูก bake เข้า bundle แล้ว ไม่ใช่แค่ CI เห็น secret)
   · `<meta name="google-adsense-account">` `ca-pub-9156145951260801` ยังอยู่ครบ (regression check ของ run #46/#48)

   **แปลว่า `PushEnv.isWebPushConfigured == true` บน production** — การ์ดขออนุญาตใน
   Notification settings จะไม่เป็น `unsupported` อีกต่อไป และกดขอ token ได้จริง
   **แต่ยังส่ง push ไม่ได้จนกว่าจะทำข้อ 5 และ 6** (ดู K-1)
5. ❌ **ยังไม่เสร็จ — พิสูจน์แล้วว่าค่าไม่เคยลงถึงโปรเจกต์** `FCM_SERVICE_ACCOUNT` ใน Supabase → Edge Functions → Secrets
   · เอกสารฉบับก่อนหน้าเขียนว่า "Founder ยืนยันว่าใส่แล้ว" ตามที่แจ้งมา **ซึ่งไม่ตรงกับความจริง** —
     `GET /v1/projects/{ref}/secrets` คืนมาเฉพาะ secret ในตัวของ Supabase เท่านั้น
     (`SUPABASE_ANON_KEY`, `SUPABASE_DB_URL`, `SUPABASE_JWKS`, `SUPABASE_PUBLISHABLE_KEYS`,
     `SUPABASE_SECRET_KEYS`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_URL`) ไม่มีชื่อที่ใกล้เคียงเลย
     จึงไม่ใช่ชื่อพิมพ์ผิด แต่ค่าไม่เคยถูกบันทึกลงหน้านี้
   · **บทเรียน:** คำยืนยันจากคนไม่ใช่หลักฐาน และรอบนี้มีวิธีตรวจอยู่แล้วแต่ผมไม่ได้ตรวจ —
     บันทึกว่า "เสร็จ" ไปก่อนโดยไม่ตรวจ ทำให้ K-1 ดูใกล้ปิดกว่าความจริงอยู่หนึ่งรอบ
   · อาการที่เกิดจริง: Edge Function ตอบ `FCM not configured` (`index.ts:83`) ทุกครั้งที่ webhook ยิงเข้ามา
   · ค่านี้เป็นความลับจริง (มี `private_key`) — ไม่เคยผ่านมาที่ผมและไม่ควรผ่าน
   · ค่านี้เป็นความลับจริง (มี `private_key`) — ไม่เคยผ่านมาที่ผมและไม่ควรผ่าน
6. ✅ **เสร็จแล้ว** (2026-09-03 18:0x) — Database Webhook บน `public.notifications` INSERT → `send-push-notification`
   ทำผ่าน `.github/workflows/setup-database-webhook.yml` (ปุ่มเดียว มี 5 โหมด: `verify` `create` `test` `remove` `enable`)
   ไม่ได้กรอกฟอร์มใน Dashboard เพราะ Founder ทำจาก iPad และหาหน้านั้นไม่เจอ

   · **เปิดกลไก webhook ให้ด้วย** — probe ก่อน/หลังยืนยันว่าเปลี่ยนจริง:
     ก่อน `pg_net 0 · schema 0 · http_request 0` → `POST /v1/projects/{ref}/database/webhooks/enable` → `201`
     → หลัง `pg_net 1 · schema 1 · http_request 1`
     เป็น endpoint เดียวกับที่ปุ่ม **Enable webhooks** ใน Dashboard เรียก จึงเป็น Supabase รัน migration ของเขาเอง
     **ไม่ใช่**การเขียน `supabase_functions.http_request` ขึ้นมาเลียนแบบ ซึ่งจงใจไม่ทำ เพราะสำเนาที่ไม่เหมือนเป๊ะ
     จะทำให้ Dashboard ไม่รู้จัก hook และชนกับ migration ครั้งต่อไปของ Supabase
   · trigger ที่ได้: `AFTER INSERT ON public.notifications FOR EACH ROW`, enabled (`tgenabled = 'O'`), timeout `5000`
   · **ยิงทดสอบจริงแล้ว** (โหมด `test`, run `33787465510`) — `net.http_post` ด้วย payload `type=UPDATE`
     ที่โค้ดตั้งใจ ignore จึงไม่เขียนแถวและไม่ push หาใคร:

     ```
     { "status_code": 200, "content": "Ignored", "error_msg": null }
     ```

     `200` = ผ่านด่าน JWT · `"Ignored"` = ข้อความจาก `index.ts:76` ของเราเอง จึงพิสูจน์ว่าไปถึงโค้ดจริง
     ไม่ใช่แค่ถึง gateway · **ยืนยันครบทั้งเส้น: Postgres → pg_net → URL → auth → Edge Function**
   · **สิ่งเดียวที่ยังไม่ได้พิสูจน์คือ trigger ยิงเองตอน INSERT จริง** และการส่ง FCM จริง (ดู K-1)

   **บั๊กที่เจอระหว่างทาง — `create` ครั้งแรกสร้าง webhook ที่ยิงไม่ได้เลย:**
   secret `SUPABASE_URL` มี newline ติดท้ายมาจากการ copy-paste ใน UI ของ GitHub
   URL จึงกลายเป็น `https://….supabase.co\n/functions/v1/…` เห็นได้ที่เดียวคือใน `pg_get_triggerdef`
   ทุกที่ที่คนจะไปดูจะดูปกติหมด · `deploy-edge-functions.yml` มี `clean()` กันเรื่องนี้อยู่แล้วแต่ไม่ได้ยกมาใช้
   · แก้แล้วใน `81bbdad` (`tr -d '[:space:]'` ทั้ง 3 ค่า) และ `create` รอบใหม่ให้ URL ที่ถูกต้อง
   · **ต้องมี HTTP header `Authorization: Bearer <anon key>`** เพราะ function ถูก deploy โดย
     **ไม่ใช้** `--no-verify-jwt` (เจตนา — ดู §8) ถ้าไม่มี header นี้ platform จะตอบ `401`
     ตั้งแต่ก่อนเข้า code ของเรา และ push จะเงียบโดยไม่มี error ให้เห็นในฝั่งแอปเลย
   · anon key ใช้ได้ (เป็น JWT ที่เซ็นด้วย JWT secret ของ project) และ **ไม่ต้องใช้ service-role**
     เพราะ function ไม่ได้ใช้ตัวตนของผู้เรียกเลย — มันใช้ `SUPABASE_SERVICE_ROLE_KEY` ของตัวเอง
     จาก env ในการ query (`index.ts:41`) การใส่ service-role ลง header ของ webhook จึงเป็น
     การเอาความลับที่แรงกว่าไปวางไว้อีกที่โดยไม่ได้อะไรเพิ่ม
   · payload ที่ function คาดหวังคือรูปแบบมาตรฐานของ Supabase webhook พอดี
     (`{type, table, record, schema}` — `_lib.ts:30`) จึงไม่ต้องตั้ง custom payload ใดๆ
7. Deploy Edge Function — **ตอนนี้กดปุ่มเดียวได้แล้ว** ไม่ต้องใช้ CLI จากเครื่องตัวเอง:
   เพิ่ม secret `SUPABASE_ACCESS_TOKEN` ครั้งเดียว (personal access token จาก
   https://supabase.com/dashboard/account/tokens) แล้วรัน workflow
   **`Deploy Supabase Edge Function`** จากแท็บ Actions เลือก function ที่จะ deploy
   · project ref ถูกดึงจาก `SUPABASE_URL` ที่มีอยู่แล้วจึงไม่ต้องเพิ่ม secret ตัวที่สอง
   · workflow รัน `deno check` + `deno test` ก่อน deploy เสมอ
   · **รันจริงแล้ว 6 ครั้ง ยังไม่สำเร็จ — ติดที่ secret ไม่ใช่ที่ workflow** (ดูตารางท้ายหัวข้อนี้)
   · run แรก (`33776152809`, `227c9bd`) — ทุกขั้นผ่านจนถึงขั้นสุดท้าย:
     checkout ✅ · setup-deno ✅ · **`deno check` + `deno test` ✅** · setup-cli ✅ ·
     **การดึง project ref ทำงานถูกกับ secret จริงใน CI** — log พิมพ์
     `Deploying send-push-notification to project kqokpocajhfbidcxpvhh` ตรงกับ project จริง
     · ล้มที่ขั้น deploy ด้วยเหตุผลเดียวคือ `Access token not provided` เพราะ
     secret `SUPABASE_ACCESS_TOKEN` ยังไม่มีในrepo (log แสดง `SUPABASE_ACCESS_TOKEN:` ว่าง)
     · **แปลว่า workflow ถูกต้องทั้งเส้นทาง เหลือแค่ secret ตัวเดียว**

   **ประวัติการรันทั้ง 6 ครั้ง:**

   | run | ผล | อ่านได้ว่า |
   |---|---|---|
   | `33776152809` | failure ที่ขั้น Deploy | `Access token not provided` — secret ยังไม่มี |
   | `33776444947` | failure ที่ขั้น Deploy | เหมือนเดิม หลัง Founder แจ้งว่าใส่ secret แล้ว |
   | `33776911753` | failure ที่ pre-flight | pre-flight ที่เพิ่มเข้าไปจับได้เอง หลัง Founder ยืนยันว่าเป็น Repository secret |
   | `33777087001` | **`action_required` · 0 jobs** | ถูกบล็อกก่อนสร้าง job — เพิ่ม step ที่ serialise secrets context ทั้งก้อน |
   | `33777275459` | **`action_required` · 0 jobs** | ยังบล็อก แม้จะพิมพ์แค่ boolean — การ *อ้างถึง* context ทั้งก้อนก็พอแล้ว |
   | `33777467741` | failure ที่ pre-flight | เอา reference ออกหมด → รันได้ปกติอีกครั้ง · probe รายงาน `SUPABASE_ACCESS_TOKEN non-empty: false` |
   | `33778330387` | failure ที่ขั้น Deploy | **secret ใช้ได้แล้ว** (`non-empty: true`) · bundle ผ่าน · upload 13 kB ผ่าน · **ล้มที่ Supabase ตอบ `403`** |
   | `33780460047` | ✅ **success** | หลัง Founder สร้าง token ใหม่จากบัญชีที่ถูกต้อง — `Deployed Functions on project kqokpocajhfbidcxpvhh: send-push-notification` |

   **✅ DEPLOYED แล้ว** — run `33780460047` (2026-09-03 16:45) สำเร็จ:

   ```
   ✅ deno check + deno test        20/20 passed
   ✅ SUPABASE_ACCESS_TOKEN         non-empty: true
   ✅ Bundling Function             send-push-notification
   ✅ Deploying Function            (script size: 13 kB)
   ✅ Deployed Functions on project kqokpocajhfbidcxpvhh: send-push-notification
   ```

   สาเหตุที่ 6 runs ก่อนหน้าไม่ผ่าน คือ token มาจากบัญชี Supabase ที่ไม่มีสิทธิ์บน project นี้
   (ตอบ `403` ไม่ใช่ `401`) — Founder สร้าง token ใหม่จากบัญชีที่ถูกต้องแล้วผ่านทันที

   ---

   **ประวัติเดิม — ปัญหาตอน run ที่ 7** (`33778330387`, 2026-09-03 16:23):

   ```
   ✅ deno check + deno test        20/20 passed
   ✅ SUPABASE_ACCESS_TOKEN         non-empty: true
   ✅ Deploying ... to project      kqokpocajhfbidcxpvhh
   ✅ Bundling Function             send-push-notification
   ✅ Deploying Function            (script size: 13 kB)
   ❌ unexpected create function status 403:
      "Your account does not have the necessary privileges to access this endpoint."
   ```

   **`403` ไม่ใช่ `401`** — token ผ่านการยืนยันตัวตนแล้ว (ถ้า token ผิดหรือหมดอายุจะเป็น `401`)
   สิ่งที่ขาดคือ **สิทธิ์ของบัญชีเจ้าของ token บน project/organization นั้น** ไม่ใช่ตัว token
   และไม่ใช่ workflow — ทุกอย่างฝั่ง GitHub ทำงานครบแล้ว

   **ต้องแก้ที่ Supabase:** ให้บัญชีที่สร้าง token มีสิทธิ์ระดับ Owner/Administrator
   บน organization ที่เป็นเจ้าของ project `kqokpocajhfbidcxpvhh`
   (Supabase Dashboard → Organization settings → Team) หรือสร้าง token ใหม่จากบัญชีที่มีสิทธิ์นั้นอยู่แล้ว
   ดู https://supabase.com/docs/guides/platform/access-control

   **บทเรียนที่ได้จาก run 4-5:** GitHub บล็อก workflow ที่อ้าง `secrets` context ทั้งก้อน
   (ทั้งแบบ dump ชื่อ และแบบ `contains(...)` ที่พิมพ์แค่ boolean) — บล็อกตั้งแต่ก่อนสร้าง job
   จึงไม่มี log ให้อ่านเลย **อย่าใช้วิธีนั้น diagnose secret ใน repo นี้**
   วิธีที่ปลอดภัยและใช้ได้จริงคือ `secrets.X != ''` ซึ่งอ้างถึง secret ตัวเดียว

   **สรุป:** ปิดเรียบร้อย — Edge Function ที่ Beta4 แก้ อยู่บน production แล้ว
   และครั้งหน้าแก้ `supabase/functions/` เมื่อไหร่ กดปุ่มเดียวจบ ไม่ต้องใช้ CLI จากเครื่องใคร

---

## 11. Known Issues

| # | เรื่อง | ความรุนแรง | รายละเอียด |
|---|---|---|---|
| ~~K-1~~ | ~~**ยังไม่เคยส่ง push จริงแม้แต่ครั้งเดียว**~~ → ✅ **ปิดแล้ว 2026-09-04 13:17** — push จริงเด้งบนหน้าจอล็อกของ iPhone ขณะแอปปิดสนิท (`รีโพสต์โพสต์ของคุณ` และ `ถูกใจโพสต์ของคุณ`) · ฝั่ง server ยืนยันตรงกัน: `net._http_response` id 39–41 ตอบ `OK sent=3` / `sent=3` / `sent=2` ไม่มี `failed` เลย · **เส้นทางที่พิสูจน์ครบแล้ว:** กดไลก์ → trigger → webhook → Edge Function → JWT → Google → FCM → Apple → service worker → หน้าจอล็อก · ต้องแก้บั๊กจริง 3 ตัวก่อนถึงจะสำเร็จ (ดู §11 ท้ายเอกสาร) | ปิดแล้ว | อัปเดต 2026-09-03 18:0x: **ข้อ 1–7 ของ §10 เสร็จหมดแล้ว** (client · Edge Function · `FCM_SERVICE_ACCOUNT` · Webhook) และเส้นทาง Postgres → Edge Function ยืนยันด้วยการยิงจริง (`200 Ignored`) **เหลือเฉพาะสองช่วงท้ายที่ยังไม่มีอะไรพิสูจน์: trigger ยิงเองตอน INSERT จริง และ FCM ส่งถึงเครื่องจริง** ทั้งสองต้องมีเครื่องที่กดอนุญาต push แล้วเท่านั้นจึงจะทดสอบได้ (ดู K-11) · ทุกอย่างในเอกสารนี้ยืนยันด้วย: การอ่านโค้ด, widget test (permission flow ครบ 4 สถานะ), `deno check` + `deno test` (payload/collapse key), และการอ่าน RLS ใน `schema.sql` **end-to-end delivery ยังไม่ได้พิสูจน์** |
| K-2 | Android Gradle plugin ยังไม่ apply | กลาง | Push บน Android จะยังไม่ทำงานจนกว่าจะทำข้อ 2 ข้างบน — เจตนาเดิมตั้งแต่ WYN-016 |
| K-3 | Badge ยังไม่ realtime | ต่ำ | อัปเดตตอน resume และตอน foreground push การแจ้งเตือนที่มาถึงระหว่างแอปเปิดอยู่ *และ* push ไม่ได้ตั้งค่า จะยังไม่ขยับจนกว่าจะ resume — การเพิ่ม Realtime channel เป็นทางแก้ที่ไม่ใช่ polling แต่เพิ่ม subscription ตลอด session ควรเป็น task แยกที่ Founder ตัดสิน |
| K-4 | iOS Safari ต้องติดตั้งเป็น PWA ก่อน | ต่ำ | ข้อจำกัดของ Apple — ควรบอกผู้ใช้ในภายหน้า ยังไม่มี UI อธิบายเรื่องนี้ |
| K-5 | **`web/firebase-messaging-sw.js` เกือบไม่ได้ถูก commit** | — (แก้แล้ว) | `app/.gitignore` ทำ `/web/*` แล้ว allowlist ทีละไฟล์ (มีมาก่อน Beta4 เพราะ `flutter create . --platforms web` regenerate โฟลเดอร์นี้ตอน deploy) ไฟล์ service worker ใหม่จึงถูก ignore เงียบๆ — ถ้า merge ไปตามนั้น production จะไม่มีไฟล์นี้เลย และ Web Push จะยังเป็นไปไม่ได้เหมือนก่อน Beta4 ทั้งที่เอกสารบอกว่าทำได้แล้ว **จับได้ก่อน deploy ครั้งแรก** ตอนอ่าน `deploy-web.yml` — เพิ่ม `!/web/firebase-messaging-sw.js` ใน allowlist แล้ว |
| K-6 | ไม่มี UI ให้ "ปิด push" หลังเปิดแล้ว | ต่ำ | ไม่มีแอปไหนปิด OS permission ของตัวเองได้ — แถวในตั้งค่าแสดงสถานะและชี้ไปที่การตั้งค่าระบบ ส่วนการปิดรายหมวดทำได้ด้วย 7 สวิตช์ที่มีอยู่แล้ว |


---

## 11. บั๊กจริงที่ต้องแก้ก่อน push จะเด้งได้ (2026-09-04)

เอกสารส่วนบนเขียนไว้ตั้งแต่ตอนที่ยังไม่เคยส่ง push จริง และทุกอย่างในนั้น
ยืนยันด้วยการอ่านโค้ดกับ unit test เท่านั้น **การส่งจริงครั้งแรกเปิดโปงบั๊ก 3 ตัว
ที่ไม่มี test ไหนจับได้ และไม่มีชั้นไหนรายงานว่าล้มเหลว** — ทั้งสามตัวมีลักษณะ
ร่วมกันคือทุกฝ่ายรายงานว่าสำเร็จ เพราะสำหรับแต่ละฝ่ายมันสำเร็จจริง

### B-1 · `Topic` header ยาวเกินสเปก (`a16b0ba`)

`webpush.headers.Topic` ส่ง uuid เต็ม 36 ตัวอักษร แต่ RFC 8030 §5.4 กำหนด
`Topic = 1*32(ALPHA / DIGIT / "-" / "_")` — **สูงสุด 32**

* FCM ไม่ตรวจความยาวนี้ ตอบ `200` ตั้งแต่รับเข้าคิว การส่งต่อไป Apple เกิดทีหลัง
  **Apple ปฏิเสธหลังจากที่เราปิดสมุดไปแล้ว** ไม่มีทางเห็นจากฝั่งเรา
* คอมเมนต์ของ `collapseKeyFor` ตรวจข้อจำกัดของ APNs ไว้ (`64 bytes` — uuid ผ่าน)
  แล้วหยุดแค่นั้น ไม่ได้ดูของ Web Push ซึ่งเข้มกว่าครึ่งหนึ่ง
* แก้: ตัดขีดกลางออก → uuid เหลือ **32 ตัวพอดี ไม่เสียข้อมูลสักตัว**
  (ตัดปลายทิ้งจะเหลือ hex 28 ตัว แล้ว notification คนละอันอาจถูกยุบรวมกัน)

### B-2 · service worker ไม่เคยมี Firebase config เลย (`5f88cfd`, `b4bad59`)

**นี่คือตัวที่ฆ่า push ทุกครั้งที่ WYNOS เคยส่งไปหาเบราว์เซอร์**

`web/firebase-messaging-sw.js` อ่าน config จาก query string โดยเชื่อว่า Firebase
ต่อท้ายให้ตอนลงทะเบียน worker — **ไม่จริง** SDK ลงทะเบียนที่ path ตายตัวเปล่าๆ
guard `if (apiKey && ...)` จึงไม่เคยเป็นจริง `onBackgroundMessage` ไม่เคยถูกลงทะเบียน

* **ไม่มีโค้ดที่ไหนให้อ่านแล้วขัดแย้งกับคอมเมนต์นั้นได้** — ทั้งบันเดิลไม่มีคำว่า
  `firebase-messaging-sw.js` เลย เพราะ SDK เป็นคนลงทะเบียนเอง ข้อสมมติที่ผิด
  จึงยืนอยู่ได้โดยไม่มีอะไรมาค้าน
* token ยังออกได้ปกติ เพราะ**หน้าเว็บ**เป็นคนสร้าง push subscription ไม่ใช่ worker
  → แผ่นตรวจสอบบนเครื่องขึ้น ✓ ครบทั้ง 4 บรรทัดอย่างถูกต้อง
* แก้: `deploy-web.yml` เขียนค่าลงไฟล์ตอน build จาก secret ชุดเดียวกับ
  `--dart-define` แล้ว **grep ตรวจงานตัวเอง** ว่าไม่มี placeholder ตกค้าง

### B-3 · `getNotificationSettings()` ค้างถาวรบน iOS web (`264aedd`)

ไม่คืนค่า ไม่โยน error — ความล้มเหลวแบบเดียวที่ `try/catch` มองไม่เห็น

* อาการที่เห็น: แถว "การแจ้งเตือนบนเครื่องนี้" ค้างที่ "กำลังตรวจสอบ..." ตลอดไป
* **อาการที่มองไม่เห็นและแพงกว่ามาก:** `initialize()` await คำสั่งเดียวกันก่อน
  ตัดสินใจลงทะเบียน → **เครื่องที่ค้างไม่เคยเก็บ token เลย และไม่รับ push ตลอดกาล**
  โดยไม่มีอะไรบันทึกไว้
* อธิบายตัวเลขที่ไม่ลงตัวมาตลอด: ติดตั้ง 2 เครื่อง × 2 บัญชี ควรมีได้ถึง 4 token
  แต่มี 2 — **เครื่องที่ค้างไม่อยู่ในตารางเลย และการไล่จากฝั่ง server ไม่มีวันเจอ
  เพราะมันไม่เคยส่งเสียงมาสักครั้ง**
* แก้: timeout 5 วินาทีทุกจุดที่เรียก Firebase
* **ไม่มี test** — จุดที่ค้างอยู่หลัง `FirebaseMessaging.instance` ซึ่งเป็น static
  ที่ inject ไม่ได้ double ที่ override เมธอดที่กำลังทดสอบจะยืนยันแค่โค้ดของตัวเอง

### เครื่องมือที่ต้องสร้างก่อนถึงจะแก้ได้

บั๊กทั้งสามหาไม่เจอด้วยการอ่านโค้ด ต้องสร้างเครื่องมือขึ้นมาก่อน:

| เครื่องมือ | ตอบคำถามว่า |
|---|---|
| `setup-database-webhook.yml` โหมด `diagnose` | แต่ละข้อต่อของโซ่เป็นยังไง — trigger, notification rows, token, คำตอบจาก function |
| `safeErrorMessage` + try/catch ครอบ handler | `500` เปล่าๆ กลายเป็น `SyntaxError: ... at position 8` ซึ่งชี้ถึงระดับตัวอักษร |
| `summariseOutcomes` (`OK sent=n failed=m`) | แยก "ส่งถึงทุกเครื่อง" ออกจาก "FCM ปฏิเสธหมด" ซึ่งเดิมตอบ `OK` เหมือนกัน |
| แผ่นตรวจสอบในแอป (`PushDiagnosticsSheet`) | บัญชีที่กำลังดูอยู่ ผูกกับเครื่องที่ถืออยู่หรือเปล่า — คำถามที่ทั้งสองฝั่งตอบเองไม่ได้ |

**ทั้งสี่อย่างยังอยู่ในโค้ด** ครั้งหน้าที่ push เงียบ ไม่ต้องเริ่มจากศูนย์
