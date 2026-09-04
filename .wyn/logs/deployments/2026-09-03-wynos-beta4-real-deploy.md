# Deployment Log — WYNOS v1.0.0 Beta4 — DEPLOYED

```
Release: WYNOS v1.0.0 Beta4 (Profile UX/UI + Account Experience + Existing Feature UX + Club Community + Notification & Web Push + UI Consistency + Responsive + QA)
Version: PR #224 merged by Founder → `main` @ `aa525bb`, deployed via deploy-web.yml run #47 (id 33774311071, conclusion success). Superseded 5 นาทีต่อมาโดย run #48 (`6de4a69`) — ดู "AdSense regression" ด้านล่าง
QA Status: PASS — ตรวจเองครบทั้ง 24 หัวข้อของ Beta4 master prompt, เอกสาร QA 7 ไฟล์ที่ `.wyn/docs/qa/wynos-v1.0.0-beta4-*`
Build Status: build จริงใน GitHub Actions (Flutter 3.47.1 — SDK เดียวกับที่ ci.yml pin) · local: flutter analyze 0 issues, flutter test 1164/1164, deno check + deno test 20/20, check_schema_ordering.py OK
Deployment Target: Vercel project "web" → https://wynos.online · ไม่มี database migration (Beta4 ไม่แตะ schema.sql เลย) · Edge Function ยังไม่ได้ deploy — ดู "ค้างอยู่" ด้านล่าง
Changes: 74 ไฟล์ (+5,501 / −907) — Profile identity block, RootShell keyed per account, push permission priming + Web Push infrastructure, Club single identity image, icon/colour tokens, 7 QA docs
```

## CI ตอน merge

| job | ผล |
|---|---|
| Flutter — app | ✅ success |
| Supabase Edge Functions (Deno) | ✅ success |
| schema.sql ordering | ✅ success |
| Admin (Next.js) | ✅ success |
| Flutter — seller_app | ❌ **failure — แดงอยู่แล้วก่อน Beta4** |

`seller_app` fail ที่ `test/design/token_sync_test.dart` 2 case พอดี (`wyn_colors` + `wyn_typography`) ส่วน `wyn_spacing`/`wyn_theme` ผ่าน — ยืนยันจาก job log จริง ไม่ใช่การอนุมาน

สาเหตุอยู่ที่ commit `a989396` (2026-08-30) ตอน re-brand Cyan → Sapphire ซึ่ง Founder อนุมัติให้ scope เฉพาะ `app/` — test เรียกร้อง byte-identity ที่ Founder ตัดสินใจไม่เอา job นี้จึงแดงมาตั้งแต่วันแรกที่มี CI (`ff51d75`, 2026-09-03) รายละเอียดเต็มที่ readiness report หัวข้อ F-1

## AdSense regression — เกิดจาก deploy นี้เอง จับได้และแก้แล้ว

**สิ่งที่เกิดขึ้น:** ก่อน deploy ผมเก็บ baseline ของ production ไว้ แล้วสังเกตว่า deploy run #46 (13:24) ปล่อย commit `48eb03a` ขึ้น production — commit นั้น **ไม่ได้อยู่บน `main`** แต่อยู่บน branch `claude/wynos-adsense-verification-r196n3` ที่ยังไม่ merge

commit นั้นเพิ่ม `<meta name="google-adsense-account" content="ca-pub-9156145951260801">` ใน `app/web/index.html` เพื่อให้ Google verify `wynos.online` ได้

การ deploy `main` (run #47) จึง **ลบ tag นั้นออกจาก production** — ยืนยันแล้วด้วยการ `curl` หน้าแรกหลัง deploy: ไม่มีคำว่า adsense เหลืออยู่เลย

**ทำไมถึงจับได้:** เพราะเทียบ baseline ก่อน/หลัง ไม่ใช่แค่ดูว่า deploy สำเร็จ — run #47 conclusion เป็น `success` ทุกประการ ถ้าดูแค่นั้นจะไม่มีอะไรบอกว่ามีอะไรหายไป

**การแก้:** ถาม Founder แล้ว Founder เลือก "กู้คืน tag แล้ว deploy ใหม่" → cherry-pick `48eb03a` ขึ้น `main` เป็น `6de4a69` (1 ไฟล์ 3 บรรทัด ไม่มี conflict) → push → deploy run #48

**บทเรียน:** production เคยถูก deploy จาก branch ที่ไม่ได้ merge เข้า `main` การ deploy `main` ครั้งถัดไปจึงย้อนงานนั้นทิ้งเงียบๆ — **ก่อน deploy ทุกครั้ง ควรเช็คว่า commit ที่ production รันอยู่เป็น ancestor ของ `main` หรือไม่** (`git merge-base --is-ancestor <prod-sha> origin/main`) ไม่ใช่แค่ดูว่า `main` พร้อมหรือยัง

## Production Verification

ต่างจากทุก deploy log ก่อนหน้า: **session นี้ egress proxy เข้า `wynos.online` ได้** จึง verify จริงได้ ไม่ใช่ฝากให้ Founder เปิดดู

| endpoint | ก่อน deploy | หลัง run #47 |
|---|---|---|
| `/` | 200, 1,523 bytes | 200, 1,523 bytes |
| `/main.dart.js` | 200, 4,267,817 bytes | 200, **4,255,895 bytes** |
| `/flutter_bootstrap.js` | 200, 13,716 bytes | 200 |
| `/firebase-messaging-sw.js` | **404** | **200, 4,878 bytes** |

**`main.dart.js` เล็กลง 11,922 bytes** — สอดคล้องกับที่ Beta4 ลบโค้ดออกมากกว่าที่เพิ่ม (ลบ stat ที่ 3 + `countByAuthor` call, ยุบ sheet 2 สำเนาเหลือ 1, ยุบ `CircleAvatar` 5 ชุดเหลือ `ClubAvatar`, ลบ avatar ซ้อนมุมใน recommended card)

**`/firebase-messaging-sw.js` 404 → 200 คือหลักฐานตรงที่สุดว่า Web Push infrastructure ขึ้น production จริง** — และเป็นเหตุผลที่ต้องเก็บ baseline ก่อน: ถ้าไม่เช็ค ไฟล์นี้เกือบไม่ได้ถูก commit ตั้งแต่แรก (ดู commit `21b810b`)

## ผลสุดท้าย — run #48 (`6de4a69`)

**SUCCESS.** verify จริงหลัง run #48:

| endpoint | ผล |
|---|---|
| `/` มี `<meta name="google-adsense-account" content="ca-pub-9156145951260801">` | ✅ กลับมาแล้ว |
| `/main.dart.js` | ✅ 200, 4,255,895 bytes (เท่า run #47 — cherry-pick แตะแค่ `index.html` ไม่แตะ Dart) |
| `/firebase-messaging-sw.js` | ✅ 200, 4,878 bytes |

production ตอนนี้มีทั้ง Beta4 และ AdSense tag ครบ

## ค้างอยู่ — ยังไม่ได้ทำ ต้อง Founder ทำเอง

1. **Edge Function ยังไม่ได้ deploy** — Beta4 แก้ `supabase/functions/send-push-notification/{_lib.ts,index.ts}` (เพิ่ม `notification_id` + collapse key กัน notification ซ้ำ) ต้องรัน `supabase functions deploy send-push-notification` ซึ่งต้องมี Supabase credential ที่ session นี้ไม่มี · **ไม่เร่งด่วน**: ของเดิมยังทำงานได้ปกติ แค่ยังไม่มี dedupe
2. **Push ยังไม่ทำงาน** จนกว่าจะทำ 7 ขั้นตอนใน `wynos-v1.0.0-beta4-notification-audit.md` §10 (Firebase project, VAPID key, 7 `--dart-define` ใน `deploy-web.yml`, `FCM_SERVICE_ACCOUNT` secret, Database Webhook) — โค้ด dormant อย่างปลอดภัย: build ที่ไม่มี config จะ no-op เหมือนก่อน Beta4 ทุกประการ
3. **QA บนอุปกรณ์จริง** — automated test พิสูจน์ layout/behaviour ได้ แต่ไม่ครอบคลุม safe area จริงของแต่ละรุ่น, notch, ความคมของภาพ

## Rollback Plan

ไม่มี database migration → rollback คือ deploy commit เดิมอย่างเดียว

* กลับไปก่อน Beta4: `main` @ `590106d` (run #45 เคย deploy sha นี้สำเร็จ)
* กลับไปก่อน AdSense restore: `main` @ `aa525bb` (run #47)
* ทั้งสองทางทำผ่าน `deploy-web.yml` โดยเลือก ref — ไม่ต้องแตะ database

**ข้อควรระวังตอน rollback:** `main` @ `590106d` **ไม่มี** AdSense tag เหมือนกัน ถ้า rollback ไปจุดนั้นต้อง cherry-pick `48eb03a` ซ้ำ

---

## Run #50 — `33784128418` · Firebase Web config เข้า production build

* Commit: `0ffcc15` · trigger: `workflow_dispatch` บน `main` · conclusion: **success** (17:22 → 17:24)
* Log ของ step "Build web bundle":

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

* ยืนยันกับ production หลัง deploy (ไม่เชื่อแค่ log ของ CI):

  | ตรวจอะไร | วิธี | ผล |
  |---|---|---|
  | service worker ถูกเสิร์ฟ | `curl -o /dev/null -w %{http_code} https://wynos.online/firebase-messaging-sw.js` | `200` |
  | config ถูก bake เข้า bundle จริง | `curl https://wynos.online/main.dart.js \| grep -c wynos-78e85` | `1` (พบ) |
  | AdSense ไม่หายอีก (regression ของ run #46) | `grep ca-pub-` บน `/` เทียบกับ `app/web/index.html` | ตรงกัน — `ca-pub-9156145951260801` |

* **ความหมาย:** `PushEnv.isWebPushConfigured == true` บน production เป็นครั้งแรก
  การ์ดขออนุญาตใน Notification settings จะไม่เป็น `unsupported` และขอ FCM token ได้จริง
* **ยังส่ง push ไม่ได้** — เหลือฝั่ง server 2 ชิ้น: `FCM_SERVICE_ACCOUNT` ใน Supabase Edge Function secrets
  และ Database Webhook บน `public.notifications` INSERT → `send-push-notification`

---

## 2026-09-04 — Push ทำงานจริงครั้งแรก (K-1 ปิด)

**13:17** — notification เด้งบนหน้าจอล็อกของ iPhone ขณะแอปปิดสนิท:
`WYN · from WYNOS Beta · Wynos.online รีโพสต์โพสต์ของคุณ` (และ `ถูกใจโพสต์ของคุณ`)

ฝั่ง server ยืนยันตรงกัน — `net._http_response` id 39–41:

```
200 · "OK sent=3"   06:17:02Z
200 · "OK sent=3"   06:17:00Z
200 · "OK sent=2"
```

ไม่มี `failed` สักรายการ

**บั๊กที่ต้องแก้ก่อนถึงจะถึงจุดนี้** (รายละเอียดใน notification audit §11):

| commit | บั๊ก |
|---|---|
| `a16b0ba` | `Topic` header 36 ตัว เกิน RFC 8030 §5.4 ที่กำหนด 32 — Apple ทิ้งเงียบหลัง FCM ตอบสำเร็จไปแล้ว |
| `264aedd` | `getNotificationSettings()` ค้างถาวรบน iOS web — เครื่องที่ค้างไม่เคยลงทะเบียน token |
| `5f88cfd` `b4bad59` | **service worker ไม่เคยมี Firebase config** — อ่านจาก query string ที่ไม่มีอยู่จริง `onBackgroundMessage` จึงไม่เคยถูกลงทะเบียน |

**การยืนยัน production ทำจากไฟล์ที่เสิร์ฟจริง ไม่ใช่จาก log ของ CI:**

```
curl https://wynos.online/firebase-messaging-sw.js
  → const BAKED = { apiKey: 'AIzaSyBBAeg…', projectId: 'wynos-78e85', … }
  → placeholder เหลือ 0 ตัว
  → onBackgroundMessage ยังอยู่
```

**`6805d1f`** — หัวข้อ notification เปลี่ยนจาก `WYN` เป็นชื่อคนที่ทำ เพราะ iOS
เขียน `from WYNOS Beta` ให้เองอยู่แล้ว บรรทัดเด่นที่สุดจึงถูกใช้ไปกับชื่อแอปซ้ำ
