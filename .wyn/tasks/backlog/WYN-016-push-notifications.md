# Product Task — WYN-016

Status: coded + self-verified (QA — PASS, 2026-08-16) — ทุกส่วนที่ไม่ต้องพึ่ง Firebase project จริงเสร็จสมบูรณ์ รอ Founder ทำ 4 ขั้นตอน Firebase setup (ดูหัวข้อด้านล่าง) ก่อนใช้งานจริงได้

**อัปเดต 2026-08-30**: พบระหว่างตรวจระบบแจ้งเตือนทั้งหมดตามคำขอ Founder ว่า push message/deep-link ที่ทำไว้ตอนแรก (รอบนี้) ครอบคลุมแค่ 13 ประเภทแรก (WYN-012/015/ZOKY-005) — 11 ประเภทที่เพิ่มเข้ามาทีหลัง (WYN-021 mention ×2, WYN-034 redrop, WYN-029 moderation ×2, WYN-030 appeal ×2, WYN-032 message request, WYN-039 follow request ×2, WYN-043 system) ไม่เคยถูกเพิ่มเข้า Edge Function/client deep-link handler เลย แก้ครบแล้วทั้งหมด (`_lib.ts`/`index.ts`/`push_notification_service.dart`) — ข้อความ Thai ตรงกับ `notification_list_screen.dart`'s `_messageFor` เป๊ะทุกตัวอักษร, deep-link ปลายทางตรงกับ `_openNotification` เป๊ะ ดูรายละเอียดที่ `.wyn/company/DECISIONS.md` (2026-08-30) — สถานะ Firebase setup ไม่เปลี่ยน ยังรอ Founder เหมือนเดิม
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (PASS ในส่วนที่ verify ได้)

Feature: Push Notification (แจ้งเตือนจริง แม้ปิดแอป/ไม่ได้เปิดหน้าจออยู่)

Goal: ต่อยอดระบบ in-app notification ที่มีอยู่แล้ว (WYN-012/WYN-015/ZOKY-005 — 13 ประเภท: like/comment/follow/club × 9 + order × 4) ให้ส่ง push แจ้งเตือนจริงไปที่อุปกรณ์ผู้ใช้ได้ ไม่ใช่แค่กระดิ่งในแอปที่ต้องเปิดแอปถึงจะเห็น

Target User: ผู้ใช้ WYN Social และ ZOKY Sellers by WYN ทุกคน

Problem: ตอนนี้ระบบแจ้งเตือนมีแค่ "in-app" — ผู้ใช้ต้องเปิดแอปเองถึงจะเห็นว่ามีคนถูกใจ/คอมเมนต์/ติดตาม/มีคำสั่งซื้อใหม่ ฯลฯ ไม่มีทางรู้ทันทีถ้าปิดแอปอยู่ ซึ่งเป็นช่องว่างที่ ZOKY-005's Handoff เคยถามไว้ (Q2: "ต้องการ push notification จริงหรือแค่ in-app") และ Founder เพิ่งยืนยันให้เริ่มทำรอบนี้

Requirements:

R1. เพิ่มตาราง `push_tokens` ใหม่ใน Supabase (user_id, token, platform, updated_at) — เก็บ FCM device token ต่อผู้ใช้ต่ออุปกรณ์ RLS ให้ผู้ใช้เขียน/ลบได้แค่ token ของตัวเอง
R2. Client (`app/`, `seller_app/`) ขอสิทธิ์แจ้งเตือนจากผู้ใช้ (iOS ต้องขอชัดเจน, Android 13+ ต้องขอชัดเจนเช่นกัน) แล้วลงทะเบียน FCM token เข้า `push_tokens` เมื่อ sign-in สำเร็จ และอัปเดตเมื่อ token เปลี่ยน (`onTokenRefresh`)
R3. Server-side: ทุกครั้งที่มีแถวใหม่ใน `notifications` (จาก trigger ที่มีอยู่แล้วทั้ง 13 ตัว ไม่แก้ trigger เดิมเลย) ต้องส่ง push ไปหา `recipient_id`'s ทุก token ที่ลงทะเบียนไว้ ผ่าน Supabase Database Webhook → Edge Function → Firebase Cloud Messaging (FCM) HTTP v1 API
R4. แตะ push notification แล้วเปิดแอปตรงไปหน้าที่เกี่ยวข้อง (Drop/Pop/Profile/Club/Order) — reuse mapping เดิมที่ `NotificationListScreen`/`SellerNotificationListScreen` มีอยู่แล้ว ไม่ประดิษฐ์ deep-link ใหม่
R5. ข้อความ push เป็นภาษาไทย ใช้ข้อความเดียวกับที่ in-app แสดงอยู่แล้ว (ไม่ต้องเขียนชุดข้อความใหม่)
R6. ไม่แก้ trigger/schema เดิมของ notifications 13 ตัวเลย — เป็น layer เสริมที่ทำงานคู่ขนาน ปิด push ได้โดยไม่กระทบ in-app (fail-safe: ถ้า push ส่งไม่สำเร็จ in-app ต้องยังทำงานปกติ)

## ⚠️ Dependency ที่ Founder ต้องทำเอง (บล็อกการทดสอบจริงจนกว่าจะทำ)

Push notification ผ่าน FCM **ต้องมี Firebase project จริง** — เป็นงานนอกเหนือที่ทีมทำแทนได้ เหมือนสถานการณ์ Google OAuth/Apple Developer/Twilio ก่อนหน้านี้:

1. **สร้าง Firebase project ใหม่ (ฟรี — ไม่ต้องผูกบัตร, FCM ไม่มีค่าใช้จ่ายไม่จำกัดปริมาณ)** ที่ https://console.firebase.google.com
2. **เพิ่มแอป Android** เข้า project (bundle `io.wyn.wyn` สำหรับ `app/`, `io.wyn.zokyseller` สำหรับ `seller_app/`) → ดาวน์โหลด `google-services.json` ส่งมาให้ทีมวางในแต่ละแอป
3. **เพิ่มแอป iOS** เข้า project เดียวกัน → ดาวน์โหลด `GoogleService-Info.plist` — **แต่ iOS push ต้องมี Apple Developer Program (ปีละ ~3,300 บาท) ก่อน** เพื่อสร้าง APNs Auth Key (.p8) อัปโหลดเข้า Firebase — Founder ยังไม่ได้สมัคร Apple Developer (บันทึกไว้แล้วจากรอบ OAuth) → **iOS push จะยังใช้งานจริงไม่ได้จนกว่าจะสมัคร Apple Developer** แต่ Android ทำได้เต็มรูปแบบทันทีที่มี Firebase project (ข้อ 2 อย่างเดียวพอ)
4. **สร้าง Service Account** ใน Firebase project (Project Settings → Service Accounts → Generate new private key) → ส่งไฟล์ JSON ให้ทีมเก็บเป็น Supabase secret (สำหรับ Edge Function เรียก FCM v1 API) — ไฟล์นี้เป็นความลับ ห้ามส่งผ่านช่องทางที่ไม่ปลอดภัย

**ทีมจะเขียนโค้ดทั้งหมดให้พร้อมทันที** (schema, Edge Function, client integration) แต่ **ทดสอบส่ง push จริงไม่ได้จนกว่า Founder จะทำ 4 ข้อข้างบน** — เหมือนที่ guest sign-in ใช้แทน Google/Apple/Twilio ไปก่อนหน้านี้

Acceptance Criteria:
- [ ] `push_tokens` table + RLS ผ่าน QA (รันจริงกับ Postgres local)
- [ ] Client ขอสิทธิ์แจ้งเตือนและลงทะเบียน token ได้ (ทดสอบด้วย mock FCM token ในเทส ไม่ต้องพึ่ง Firebase จริง)
- [ ] Edge Function เรียก FCM v1 API ถูก payload (ทดสอบ logic แยกจากการยิงจริง)
- [ ] แตะ push (จำลอง) แล้วเปิดหน้าที่ถูกต้องตรงกับ notification type
- [ ] ไม่กระทบ in-app notification เดิมเลย (13 ประเภท, `flutter test` ผ่านครบ)
- [ ] Android ใช้งานจริงได้ทันทีที่ Founder ทำ 4 ข้อ (ไม่ต้องรอ iOS)

Dependencies: WYN-012 (notification), WYN-015 (club notifications), ZOKY-005 R1 (order notifications) — ทั้งหมดเสร็จแล้ว, พร้อมต่อยอด

Priority: สูง (Founder ยืนยันให้ทำก่อน Chat)

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ทดสอบส่ง push จริงไม่ได้จนกว่า Founder ทำ Firebase setup | สูง (บล็อกการยืนยัน end-to-end) | เขียนโค้ดครบ + เทส logic ทุกจุดที่ไม่ต้องพึ่ง Firebase จริง แยกให้ชัดว่าอะไรพร้อม อะไรรอ |
| R2 | iOS push ต้องมี Apple Developer (ยังไม่มี) | กลาง | Android ทำงานได้อิสระ ไม่ต้องรอ iOS |
| R3 | Edge Function ใหม่ (ยังไม่เคยมีในโปรเจกต์นี้เลย) | กลาง | ทดสอบ logic ด้วย mock request/response ก่อนเชื่อม FCM จริง |
| R4 | ถ้า push ส่งไม่สำเร็จ (token หมดอายุ/ผู้ใช้ปิดสิทธิ์) ต้องไม่กระทบ in-app | ต่ำ | Edge Function ล้มเหลวแบบ silent ต่อ token เดียว ไม่ throw กระทบ trigger หลัก |

Recommendation: อนุมัติ เริ่ม Design ทันที — งานแบ่งเป็น 2 ส่วนชัดเจน: (1) โค้ดที่ทำได้ทันที ไม่ต้องรอ Founder (2) การเชื่อม Firebase จริงที่ต้องรอ

Handoff: ส่งต่อ AI Design เพื่อออกแบบ permission-request UX (ขอตอนไหน ข้อความอะไร) + deep-link mapping table เต็ม แล้วส่งต่อ AI Coding — **เสร็จแล้ว ดู Coding Output/QA Verification ด้านล่าง**

---

## Design Output

> spec เต็ม: `.wyn/docs/design/wyn-016-push-notifications.md`

สรุป: Database Webhook (ตั้งค่าผ่าน Dashboard ไม่ใช่ SQL trigger — เหตุผลเต็มในสเปก) → Edge Function → FCM v1 API ผ่าน service account JWT ฝั่ง client ใช้ `firebase_core`/`firebase_messaging` ห่อด้วย graceful-degradation ทุกจุด (ไม่มี config จริงก็ไม่พังอะไร) permission ขอหลัง onboarding เสร็จ ไม่ใช่ตั้งแต่หน้า Welcome deep-link ใช้ field เดียวกับคอลัมน์ `notifications` เป๊ะ ไม่ประดิษฐ์ mapping ใหม่

## Coding Output

**Database** (`supabase/schema.sql`, ส่วนใหม่ "WYN-016: Push Notification"):
- ตาราง `push_tokens` (user_id, token unique, platform, timestamps) + RLS 4 policy — select/insert/update จำกัดเจ้าของเอง delete จำกัดเจ้าของเอง
- Comment อธิบายละเอียดว่าทำไม RLS ไม่ยอมให้ผู้ใช้คนอื่น retarget token แถวที่มีอยู่ (ต้อง sign-out ลบก่อน ผู้ใช้ใหม่ค่อย insert สะอาด)

**`app/` และ `seller_app/`** (มิเรอร์กันทั้งคู่):
- เพิ่ม `firebase_core`/`firebase_messaging` ใน pubspec.yaml — **ไม่แตะไฟล์ native เลย**
- `PushTokenRepository` (ใหม่ ทั้ง 2 แอป) — CRUD ล้วน ไม่พึ่ง Firebase SDK
- `PushNotificationService` (ใหม่ ทั้ง 2 แอป) — ห่อ `firebase_messaging` ทุกจุด เช็ค `Firebase.apps.isNotEmpty` ก่อนเรียกจริงเสมอ ไม่งั้น no-op เงียบ
- `main.dart` ทั้ง 2 แอป: `Firebase.initializeApp()` ใน try/catch + `navigatorKey` (ใหม่ `core/navigation/app_navigator.dart`) สำหรับเปิดหน้าจากนอก widget tree ตอนแตะ push
- `RootShell`/`SellerHomeShell`: เรียก `PushNotificationService.initialize()` ใน `initState` (หลัง onboarding เสร็จ)
- `ViewProfileScreen` (`app/`): sign-out เรียก `unregisterCurrentDevice()` ก่อนเสมอ (best-effort ไม่บล็อก sign-out) — **`seller_app/` ไม่มีปุ่ม sign-out เลยตั้งแต่ต้น** (gap เดิม นอกขอบเขต ไม่ได้สร้างเพิ่มในรอบนี้)
- `SellerHomeShell`/`SellerAuthGate` เพิ่ม optional constructor injection `pushNotificationService` มิเรอร์ pattern เดิมที่มีให้ `notificationRepository` อยู่แล้ว

**Edge Function ใหม่** (`supabase/functions/send-push-notification/`):
- `_lib.ts` — logic ล้วน (message template 13+2 ประเภท, JWT signing RS256, data payload shaping) แยกจาก `index.ts` เพื่อเทสได้โดยไม่ต้อง import ตัว server
- `index.ts` — thin orchestrator: รับ webhook, query actor/club/store, เรียก FCM v1, ลบ token ที่ตายแล้วอัตโนมัติ
- `_lib.test.ts` — 10 test ครอบคลุมข้อความไทยทุกประเภท (ตรวจตรงกับ Dart source เป๊ะ พบและแก้ 1 จุดที่ข้อความ `new_order` เพี้ยนจากต้นฉบับ `app/` ระหว่างเขียน) + JWT signing round-trip จริง (generate keypair จริง เซ็นจริง verify จริงด้วย Web Crypto)

## QA Verification (2026-08-16)

```
Feature: WYN-016 Push Notification (code-complete portion, no live Firebase project)
Environment: Local Flutter (both apps) + local Deno 2.x + local PostgreSQL 16
Test Cases:
  1. flutter analyze -- No issues found, both apps.
  2. flutter test -- app/ 291/291 PASS (was 289 before this task's +2 tests),
     seller_app/ 98/98 PASS (was 96 before this task's +2 tests).
  3. supabase/schema.sql (including the new push_tokens section) loaded cleanly against
     a real local Postgres 16 with zero errors -- same rigor as every other schema
     change this session.
  4. Dedicated RLS test: verified same-user token re-upsert succeeds, a different user's
     attempt to claim an existing token row is correctly BLOCKED by RLS (not just
     assumed), and the real "sign-out deletes, next user inserts clean" flow works
     end-to-end -- ran directly against real Postgres with SET ROLE authenticated
     (not superuser, which would have silently bypassed RLS and made this test
     meaningless).
  5. deno check + deno lint -- clean on all 3 Edge Function files.
  6. deno test -- 10/10 PASS, including a genuine cryptographic round-trip (generate a
     real RSA keypair, sign a JWT with the same code path production uses, verify the
     signature with the matching public key) -- the strongest verification possible
     without a real Google service account.
  7. Cross-checked every Thai message string in _lib.ts against the actual Dart source
     files (not from memory) -- found and fixed one real mismatch (new_order's message
     was hardcoded to always say "ร้านของคุณ" instead of using the real store name like
     app/'s NotificationListScreen._messageFor does).
Passed: 7/7 (of what's verifiable without a live Firebase project)
Failed: 0
Not verifiable this round (documented, not skipped):
  - An actual FCM push arriving on a real device -- needs a real Firebase project +
    service account, which is the Founder action item at the top of this file.
  - The Database Webhook itself (Dashboard configuration, not code) -- one-time manual
    step, also blocked on the Founder having a Firebase project to point it at.
Recommendation: Approve the code-complete portion. Move to .wyn/tasks/approved/ once
  the Founder confirms Firebase setup is done and a real end-to-end push has been
  observed -- until then this stays in backlog/ as "coded, pending external dependency"
  rather than approved/, since "approved" in this project's workflow means QA verified
  the feature actually works, and the core deliverable (a real push arriving) hasn't
  been observed yet.
Final Status: PASS (code-complete scope) / BLOCKED (full acceptance criteria, pending
  Founder's Firebase setup)
```
