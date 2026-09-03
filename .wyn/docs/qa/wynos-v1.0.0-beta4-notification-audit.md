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

1. สร้าง Firebase project (ถ้ายังไม่มี)
2. **Native:** วาง `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
   ⚠️ Android ต้อง apply google-services Gradle plugin ด้วย — **ยังไม่ได้ทำ** เพราะการ apply โดยไม่มีไฟล์จริงจะพัง build ทันที (ตัดสินใจไว้ตั้งแต่ WYN-016 ไม่เปลี่ยนใน Beta4)
3. **Web:** Firebase Console → Project Settings → Cloud Messaging → Web Push certificates → generate VAPID key
4. เพิ่ม 7 `--dart-define` ใน `deploy-web.yml`
5. `supabase secrets set FCM_SERVICE_ACCOUNT='<service account JSON>'`
6. ตั้ง Database Webhook บน `public.notifications` INSERT → `send-push-notification`
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

   **บทเรียนที่ได้จาก run 4-5:** GitHub บล็อก workflow ที่อ้าง `secrets` context ทั้งก้อน
   (ทั้งแบบ dump ชื่อ และแบบ `contains(...)` ที่พิมพ์แค่ boolean) — บล็อกตั้งแต่ก่อนสร้าง job
   จึงไม่มี log ให้อ่านเลย **อย่าใช้วิธีนั้น diagnose secret ใน repo นี้**
   วิธีที่ปลอดภัยและใช้ได้จริงคือ `secrets.X != ''` ซึ่งอ้างถึง secret ตัวเดียว

   **สถานะปัจจุบัน:** ทุกขั้นของ workflow ผ่านหมด — `deno check`/`deno test` ผ่าน,
   CLI ติดตั้งได้, project ref ดึงถูก (`kqokpocajhfbidcxpvhh`) — ค้างที่ขั้นเดียวคือ
   `SUPABASE_ACCESS_TOKEN` ยังอ่านค่าไม่ได้ (`non-empty: false`)
   **ต้องให้ Founder ตรวจว่า secret ถูกบันทึกที่ Repository secret ของ repo นี้จริง
   และมีค่าไม่ว่าง (ค่าต้องขึ้นต้น `sbp_`)**

---

## 11. Known Issues

| # | เรื่อง | ความรุนแรง | รายละเอียด |
|---|---|---|---|
| K-1 | **ยังไม่เคยส่ง push จริงแม้แต่ครั้งเดียว** | — | ไม่มี Firebase project ใน session นี้ ทุกอย่างในเอกสารนี้ยืนยันด้วย: การอ่านโค้ด, widget test (permission flow ครบ 4 สถานะ), `deno check` + `deno test` (payload/collapse key), และการอ่าน RLS ใน `schema.sql` **end-to-end delivery ยังไม่ได้พิสูจน์** |
| K-2 | Android Gradle plugin ยังไม่ apply | กลาง | Push บน Android จะยังไม่ทำงานจนกว่าจะทำข้อ 2 ข้างบน — เจตนาเดิมตั้งแต่ WYN-016 |
| K-3 | Badge ยังไม่ realtime | ต่ำ | อัปเดตตอน resume และตอน foreground push การแจ้งเตือนที่มาถึงระหว่างแอปเปิดอยู่ *และ* push ไม่ได้ตั้งค่า จะยังไม่ขยับจนกว่าจะ resume — การเพิ่ม Realtime channel เป็นทางแก้ที่ไม่ใช่ polling แต่เพิ่ม subscription ตลอด session ควรเป็น task แยกที่ Founder ตัดสิน |
| K-4 | iOS Safari ต้องติดตั้งเป็น PWA ก่อน | ต่ำ | ข้อจำกัดของ Apple — ควรบอกผู้ใช้ในภายหน้า ยังไม่มี UI อธิบายเรื่องนี้ |
| K-5 | **`web/firebase-messaging-sw.js` เกือบไม่ได้ถูก commit** | — (แก้แล้ว) | `app/.gitignore` ทำ `/web/*` แล้ว allowlist ทีละไฟล์ (มีมาก่อน Beta4 เพราะ `flutter create . --platforms web` regenerate โฟลเดอร์นี้ตอน deploy) ไฟล์ service worker ใหม่จึงถูก ignore เงียบๆ — ถ้า merge ไปตามนั้น production จะไม่มีไฟล์นี้เลย และ Web Push จะยังเป็นไปไม่ได้เหมือนก่อน Beta4 ทั้งที่เอกสารบอกว่าทำได้แล้ว **จับได้ก่อน deploy ครั้งแรก** ตอนอ่าน `deploy-web.yml` — เพิ่ม `!/web/firebase-messaging-sw.js` ใน allowlist แล้ว |
| K-6 | ไม่มี UI ให้ "ปิด push" หลังเปิดแล้ว | ต่ำ | ไม่มีแอปไหนปิด OS permission ของตัวเองได้ — แถวในตั้งค่าแสดงสถานะและชี้ไปที่การตั้งค่าระบบ ส่วนการปิดรายหมวดทำได้ด้วย 7 สวิตช์ที่มีอยู่แล้ว |
