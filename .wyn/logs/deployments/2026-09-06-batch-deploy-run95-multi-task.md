# Deployment — Batch deploy (`deploy-web.yml` run #95) — multiple tasks from multiple sessions

วันที่: 2026-09-06 23:37–23:41 UTC
Deploy โดย: AI Deploy & DevOps (orchestrated by this session, `session_012WhqiQtGqTNPE9BXr65dWr`)
อำนาจ: Founder อนุมัติผ่านคำถามแบบ popup ให้ deploy ทั้งชุดที่ merge เข้า `main` แล้วแต่ยังไม่ขึ้น production (ไม่ใช่แค่ WYN-126 งานเดียว) — เพราะ production ค้างอยู่ที่ commit `76856f7` (run #94, 2026-09-06 16:43 UTC) มาหลายชั่วโมง ระหว่างนั้นมีหลาย session อื่น merge งานเข้า `main` เพิ่มอีกจำนวนมาก

## Release

**ไม่ใช่ task เดียว** — deploy รอบนี้ครอบคลุมทุก commit ที่ merge เข้า `main` ตั้งแต่ run #94 (`76856f7`) ถึง run #95 (`15f34bf`) จากหลาย session พร้อมกัน ที่ระบุ task ID ได้ชัดเจน:

- **WYN-125** (Developer Account Allowlist) — schema/RPC ถูก apply แยกไปแล้วก่อนหน้านี้ (ดู `.wyn/logs/deployments/2026-09-06-wyn-125-developer-account-allowlist-deploy.md`) รอบนี้คือ client bundle ใหม่ที่มี `DeveloperAccessService` รวมอยู่ในโค้ด (ยังไม่มีฟีเจอร์ไหนเรียกใช้จริงนอกจาก WYN-126)
- **WYN-126** (Settings Version Label) — แสดง "V1.0.0 Beta4"/"V1.0.0 Beta5 [พัฒนาอยู่]" ท้ายหน้า Settings ตาม developer flag — implement โดยอีก session คู่ขนาน (ดู DECISIONS.md entry "WYN-126 ถูกทำซ้ำโดย 2 session พร้อมกัน")
- **WYN-113** (Invite-only Access Gate) — schema apply แยกไปแล้วก่อนหน้า (`wyn113-apply-invite-only-access-gate-schema.yml`)
- **WYN-118** (Club Events) — schema apply แยกไปแล้วก่อนหน้า (`wyn118-apply-club-events-schema.yml`)
- **WYN-110/111** (Profile scroll header, Carousel center emphasis) — ปิดงานแล้วตาม DECISIONS.md
- Restyle งานจำนวนมาก (Bookmarks, Image Viewer, Report/Block, Notifications/Chat empty states, Welcome/Onboarding, Settings, Search, Club, Profile, Drop ฯลฯ) จาก session อื่นที่ restyle ทั้งแอปตาม `design-reference/`
- iOS PWA status bar fix (`app/web/index.html`)
- Profile tabs bottom-padding fix

**Session นี้ไม่ได้ implement งานส่วนใหญ่ในลิสต์นี้เอง** — ทำเฉพาะ WYN-125 (schema+mechanism), เขียน design/coding พยายามทำ WYN-126 เองแต่พบว่าอีก session ทำเสร็จ+merge ไปก่อนแล้ว (เก็บของเขาไว้ ทิ้งของตัวเองทิ้ง) ส่วนที่เหลือทั้งหมดมาจาก session อื่นที่ merge เข้า `main` คู่ขนานกัน — deploy รอบนี้เป็นการ "ปล่อยของที่ค้างอยู่ทั้งหมด" ไม่ใช่ deploy เฉพาะงานของ session นี้

## Version

- Commit deploy: `15f34bf` (`main`) — ครอบคลุม commit ตั้งแต่หลัง `76856f7` (run #94) ทั้งหมด
- ตาม `.wyn/company/VERSION_CONTROL.md`: ยังคงเป็น **WYNOS v1.0.0 Beta4** สำหรับผู้ใช้ทั่วไป (ยังไม่มีฟีเจอร์ไหนถูกประกาศเป็น "Beta5 scope" อย่างเป็นทางการ — Beta5 ที่ปรากฏใน Settings เป็นแค่ label ที่บัญชีนักพัฒนาเห็น ยังไม่ผูกกับฟีเจอร์ใดที่ถูก gate จริง)

## QA Status

แต่ละ task ผ่าน QA ของตัวเองแยกกันมาก่อนแล้ว ก่อน merge เข้า `main` (ตรวจสอบจาก commit message/DECISIONS.md ของแต่ละ task):
- WYN-125: PASS (session นี้ตรวจเอง, 20/20 + full regression)
- WYN-126: PASS (อีก session ตรวจเอง, 1343/1343)
- WYN-113/118/110/111 และ restyle อื่นๆ: อ้างอิงจาก commit message ของแต่ละ PR ว่าผ่าน `flutter analyze`/`flutter test` ก่อน merge — **session นี้ไม่ได้ re-verify ทุก task ย้อนหลังเอง** เพราะไม่ใช่ผู้ implement

## Build Status

`deploy-web.yml` run [#95](https://github.com/warren-wyn-dev/wynteam/actions/runs/34067402875): **success** ครบทุก step (`flutter build web --release`, "Deploy to Vercel production")

## Deployment Target

Vercel project "web" → `https://wynos.online`

## Deployment Result

**สำเร็จ** — ยืนยันด้วย curl ตรงต่อ production หลัง deploy:

| Path | ผล |
|---|---|
| `/` | HTTP 200, `text/html`, มี `google-adsense-account` meta tag ครบ (ไม่ regression แบบเหตุการณ์ WYN-123/run #47 เดิม) |
| `/main.dart.js` | HTTP 200 — **build ใหม่จริง**: etag `658e8131ad0c9606aa8b7293fb544284` (เดิม `056455f332773ea024ebf998f28f73c3`), ขนาด 4,513,321 bytes (เดิม 4,359,625 bytes), `last-modified` ตรงกับเวลา deploy (23:41:13 GMT) |
| `/og-image.png` | HTTP 200, `image/png` (ไม่ถูก SPA rewrite ทับ) |
| `/favicon.png` | HTTP 200, `image/png` |
| `/manifest.json` | HTTP 200, `application/json` |

## Production Verification

**ยืนยันได้เองจริงแค่ระดับ**: เว็บขึ้น, static asset ไม่พัง, ได้ build ใหม่จริง (ไม่ใช่ cache เก่า), ไม่มี asset สำคัญหายไป (เทียบ pattern เดียวกับเหตุการณ์ AdSense tag หายของ WYN-123)

**ยังไม่ได้ยืนยัน**: ฟีเจอร์ใหม่แต่ละตัวทำงานถูกต้องจริงในเบราว์เซอร์ (โดยเฉพาะ WYN-126 version label — ต้องเปิดแอปจริงด้วยบัญชีทั่วไปเทียบกับ `@warren`/`@wynos_online` เพื่อยืนยันว่าเห็นข้อความต่างกันจริงตามที่ตั้งใจ, WYN-113 invite-only gate, WYN-118 club events, restyle ต่างๆ) — sandbox นี้ไม่มี browser automation ที่เชื่อมต่อ production ได้จริง ตามกติกา "Production Verification คือใครยืนยัน ยืนยันอะไร" (`.wyn/company/WORKFLOW.md`) **รอ Founder ทดลองใช้จริงก่อนถือว่างานแต่ละ task เสร็จสมบูรณ์**

## Rollback Plan

**AI ห้าม rollback เองโดยเด็ดขาด** ถ้าพบปัญหาภายหลัง ให้ Founder เลือก:

1. **เร็วที่สุด — Vercel Instant Rollback**: Vercel Dashboard → project "web" → Deployments → หา deployment ก่อนหน้า run #95 (ของ run #94, commit `76856f7`) → `⋯` → **Promote to Production**
2. **ผ่าน CI**: หา commit ที่มีปัญหาเจาะจง แล้ว `git revert` เฉพาะ commit นั้นบน `main` (ไม่ revert ทั้งชุด เพราะรวมงานหลาย task ที่ไม่เกี่ยวข้องกัน) → push → รัน `deploy-web.yml` ใหม่

**หมายเหตุ**: deploy รอบนี้รวมงานจากหลาย task พร้อมกัน — ถ้าเจอปัญหาให้ระบุให้ชัดว่าเกี่ยวกับ task ไหน ก่อนตัดสินใจ rollback (revert เจาะจง ดีกว่า rollback ทั้งชุดที่จะเสียงานอื่นที่ไม่เกี่ยวไปด้วย)

## สถานะ Task

- `.wyn/tasks/approved/WYN-126-settings-version-label.md` — deploy ขึ้น production แล้ว รอ Founder ทดลองเปิด Settings ด้วยบัญชีทั่วไปและ `@warren`/`@wynos_online` เพื่อยืนยันเห็นข้อความต่างกันจริงก่อนปิดเป็น completed
- `.wyn/tasks/approved/WYN-113-invite-only-access-gate.md`, `.wyn/tasks/approved/WYN-118-club-events.md` (ถ้ามี) — deploy ขึ้น production แล้วเช่นกัน รอ Founder ยืนยันแยกตามปกติ
