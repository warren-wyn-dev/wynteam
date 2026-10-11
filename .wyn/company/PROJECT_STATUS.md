# WYN Project Status (ผลตรวจสอบ repository)

> ตรวจสอบล่าสุด: 2026-10-11 จาก codebase, manifests, Git history (ถึง PR #1094), CI/CD workflows, decision records และ deployment logs ใน repository

## 1. Repository

- Repository: `warren-wyn-dev/wynteam`
- โครงการมี consumer web, Flutter app, native Android, admin panel, Supabase backend, automated tests และ CI/CD
- Git history และ branch เปลี่ยนต่อเนื่องตาม task/PR; ให้ใช้ `git status`, `git log` และ GitHub เป็นข้อมูลปัจจุบันแทนการตรึงชื่อ branch หรือจำนวน commit ไว้ในเอกสารนี้

## 2. ผลิตภัณฑ์และ Framework

แต่ละแพลตฟอร์มพัฒนาและตั้งชื่อเวอร์ชันแยกกัน (Founder decision 2026-09-27): **Wynos Web Beta 1**, **Wynos Android v1.0.0 Beta 1**, **Wynos iOS v1.0.0 Beta 1**

### WYNOS Web (`web/`) — โฟกัสหลักปัจจุบัน

- Next.js 16 App Router + React 19 + TypeScript + TanStack Query + `@supabase/ssr`
- production: `https://wynos.online` บน Vercel
- รองรับภาษาไทย/อังกฤษ (WYN-189) และธีมสว่าง/เข้ม/ตามระบบ (WYN-188)
- ระบบหลักในเว็บ:
  - **Social:** Home feed, Drop/Post, Pop, Quote/Redrop, comment, bookmarks, drafts, trending, search, suggested, hashtag/mention
  - **Profile และ Account:** profile, followers, settings, account switching, private account
  - **Club:** club, channels, invite, poll, events, chat actions (WYN-135) และ announcements (WYN-137)
  - **Chat:** DM แบบ Threads-style (WYN-159) และ Wynii chat
  - **Notifications:** Web Push ตามประเภท, Quiet Hours, delivery tracking/retry และ Realtime (ยังไม่มี Email Notifications)
  - **WYNOS Food (`/food`):** ร้านอาหาร/เมนู, ตะกร้า, checkout, ชำระเงินด้วย Stripe และ QR/slip, ยกเลิกออเดอร์ที่ไม่ชำระภายใน 10 นาที, คูปองที่ admin สร้าง, promo push ที่เคารพ opt-out และ quiet hours 22:00–08:00, แคมเปญออเดอร์แรก 100/40 ที่ร้านเป็นผู้ออกส่วนลดพร้อม re-consent และ guest browsing แบบยังไม่ต้องใช้ GPS (ขอ GPS ตอนสั่งแบบ delivery) จาก PR #1075
  - **Merchant (`/merchant`):** สมัคร/ล็อกอินร้านค้า, จัดการร้าน/ออเดอร์, รายงานยอดขาย, order reminders, campaigns, Stripe Connect Accounts v2 และ refund
  - **WYNOS Maps (`/maps`):** แผนที่, สถานที่ (Overture Places import), saved places, place photos, geocode, directions/navigation (openrouteservice routing)

### WYNOS App (`app/`) — พักการพัฒนา

- Flutter/Dart app สำหรับ Web, Android และ iOS (production สำหรับผู้ใช้ทั่วไปคือ v1.0.0 Beta4)
- **Founder สั่งพักการพัฒนายาวตั้งแต่ 2026-09-19** ห้ามเริ่มงานใหม่ใน `app/` โดยไม่ถาม Founder ก่อน
- ยังมี CI job (Flutter analyze/test) เพื่อป้องกัน regression

### Wynos Android Native (`android/`) — พักการพัฒนา

- **Founder สั่งพักการพัฒนาตั้งแต่ 2026-10-10** ห้ามเริ่มงานใหม่ใน `android/` หรือสั่ง Android release โดยไม่ถาม Founder ก่อน
- Kotlin + Jetpack Compose (ไม่ใช้ TWA/PWA/WebView) และใช้ backend เดียวกับเว็บ (Founder decision 2026-09-27)
- applicationId `io.wyn.wyn`; สถานะตาม `docs/engineering/ANDROID_NATIVE_PLAN.md`: M0 เสร็จ, M1 เสร็จยกเว้น Google sign-in
- release process อยู่ที่ `docs/engineering/ANDROID_RELEASE.md`

### WYN Admin (`admin/`)

- Next.js 16 App Router + React 19 + TypeScript + Tailwind CSS + shadcn/ui primitives
- ใช้ Supabase project เดียวกันผ่าน `@supabase/ssr`
- WYN-219 (LIVE 2026-10-11): เมนูจัดกลุ่มตามระบบ WYNOS (Account, Social, Food, Merchant, Maps) และสิทธิ์แยกตามระบบ ระดับ view/edit (`public.admin_permissions`); super admin คนเดียวคือ `@wynos_s` ให้สิทธิ์ผ่านหน้า **ระบบ → Team Permissions**; Audit Log ดูได้เฉพาะ super admin
- พื้นที่ admin: dashboard, users, moderation, reports, announcements, audit log, Team Permissions, **food** (เช่น coupons), **merchants** และ **maps** (places)
- มี manual Vercel deployment workflow แยก

### Design Reference (`design-reference/`, `prototypes/`)

- เก็บ prototype, product UI references, design philosophy และ specification
- เป็น reference ไม่ใช่ production runtime package

## 3. Backend และ Database (`supabase/`)

- PostgreSQL schema หลักอยู่ที่ `supabase/schema.sql`; migrations ใหม่อยู่ที่ `supabase/migrations/` (ตั้งชื่อแบบ timestamp) ส่วน `supabase/migrations_*.sql` เป็นรูปแบบเดิม
- migrations ล่าสุดเป็นงาน Food: unpaid payment timeout, admin coupons, promo notifications/cron, first-order merchant-funded 100/40 และ public guest catalog (`20261010120000_food_public_guest_catalog.sql`)
- มี RLS, RPC/functions, views, indexes และ SQL/RLS regression tests (`supabase/tests/`)
- Supabase Edge Functions (17 ตัว):
  - **Payment:** `food-stripe-checkout`, `food-stripe-cancel`, `stripe-webhook`, `merchant-stripe-connect`, `merchant-stripe-refund`, `food-payment-qr`, `food-verify-slip`, `food-unpaid-timeout`
  - **Notification:** `send-push-notification`, `send-food-promotion`, `send-posting-activity`, `send-daily-follow-suggestions`, `send-web-reactivation`, `send-web-reactivation-push`
  - **อื่น ๆ:** `validate-upload`, `location-search`, `wynos-maps-geocode`
- `schema.sql` อาจ drift จาก production ได้; migration ที่แตะ view ต้องทำตาม `.wyn/docs/engineering/checklist-db-migration-touching-a-view.md` และตรวจนิยามจริงจาก production ก่อน
- การเปลี่ยน authentication/security architecture หรือ destructive database structure ยังต้องได้รับอนุมัติจาก Founder ตาม `.wyn/company/RULES.md`

## 4. Authentication และ Access Control

- ใช้ Supabase Auth; เปิด Google และ email/password ตาม release notes และ password policy/recovery email ผ่าน workflow ที่บันทึกไว้
- Apple และ phone/SMS ยังปิด/พักไว้ตาม configuration และ Founder decisions ปัจจุบัน
- WYNOS Food ให้ guest ดูร้าน/เมนูผ่าน public catalog แบบ least-privilege ได้; การสั่งซื้อและชำระเงินยังต้องล็อกอิน
- Admin ตรวจสิทธิ์ฝั่ง server: เข้าได้เมื่อเป็น admin/moderator หรือได้สิทธิ์ WYN-219 อย่างน้อยหนึ่งระบบ; RPC/view/policy ของ admin ทุกระบบตรวจ `internal.has_admin_permission(system, level)` แทน `platform_role` (step 2 ครบทุกระบบ 2026-10-10)
- ฟีเจอร์ใหม่ของ Web Beta2 ต้องอยู่หลัง developer gate (`useBeta2Feature` / `is_developer_account()` ทั้งฝั่ง UI และ server) จนกว่า Founder จะอนุมัติ release ดู `docs/engineering/WEB_BETA2.md`
- ณ ตอนนี้ `BETA2_RELEASED` ใน `web/lib/beta2.ts` เปิดครบทั้ง `chatThreads`, `clubChatActions` และ `clubAnnouncements` ให้ทุกบัญชี (Founder decision 2026-09-30)

## 5. Tests และ CI

GitHub Actions มีประมาณ 88 workflows; CI หลักที่รันบน pull request และ push:

**`.github/workflows/ci.yml`**
1. **Flutter** — `flutter analyze`, `flutter test` และ push reliability regression
2. **Admin (Next.js)** — ESLint, Next type generation และ TypeScript typecheck
3. **Supabase Edge Functions (Deno)** — `deno check` และ `deno test`
4. **schema.sql ordering** — `python3 supabase/check_schema_ordering.py`
5. **Supabase PostgreSQL integration** — รัน SQL/RLS regression scripts ที่ดูแลอยู่บน PostgreSQL

**`.github/workflows/web-next-ci.yml` (Consumer Web)** — lint, TypeScript, regression tests ของ follow, feed, account switch/cache isolation, navigation performance, people search, notifications/Push, shared links, Android App Links, photo location/upload type, Maps, Thai/English และ Beta2 gate, Stripe Connect v2, club/draft, production build และ license/font guard

workflows อื่นที่สำคัญ: browser QA ของ merchant/web, visual gate (`wynos-visual-gate.yml`), per-PR staging ของเว็บ (`docs/engineering/WEB_STAGING.md`) และ workflows apply migration แยกตาม task

ข้อจำกัด:

- Admin CI ยังไม่รัน `next build` เพราะ build-time Supabase environment variables ไม่ควรอยู่ใน CI ทั่วไป
- automated tests ไม่แทน QA บนอุปกรณ์จริงและ production verification

## 6. Deployment

- `.github/workflows/wyn-158-production-deploy.yml` — deploy WYNOS Web (Next.js) ไป Vercel production; manual `workflow_dispatch`
- `.github/workflows/deploy-admin.yml` — deploy admin ไป Vercel; manual
- `.github/workflows/deploy-edge-functions.yml` — ตรวจและ deploy Edge Function ที่เลือก; manual
- `.github/workflows/android-release.yml` — build Android release bundle; manual (พักตาม decision 2026-10-10)
- `.github/workflows/deploy-web.yml` — deploy Flutter Web แบบเดิม (app track ที่พักไว้)
- schema/migration workflows แยกตาม task และต้องปฏิบัติตาม approval/deployment records
- production deployment ต้องผ่าน QA และได้รับคำสั่ง/อนุมัติตาม `.wyn/company/WORKFLOW.md`; ห้ามถือว่า merge เท่ากับ deploy
- deployment log ล่าสุดใน `.wyn/logs/deployments/` ลงวันที่ 2026-09-22; งานช่วง 2026-10 (Maps, Food, Merchant, Stripe Connect v2) ยังไม่มี deployment log ในโฟลเดอร์นี้ ต้องตรวจสถานะ production จริงจาก workflow runs ก่อนสรุปว่า live แล้ว

## 7. Version ปัจจุบัน

| Track | Production (ผู้ใช้ทั่วไป) | กำลังพัฒนา | Source of truth |
|---|---|---|---|
| WYNOS Web | **Web Beta1** (launch baseline 2026-09-26, PR #725) | **Web Beta2** เฉพาะ developer accounts | `.wyn/company/WEB_VERSION_CONTROL.md` |
| WYNOS App (Flutter) | **v1.0.0 Beta4** | Beta5 (developer-only) — **พักการพัฒนา** ตั้งแต่ 2026-09-19 | `.wyn/company/VERSION_CONTROL.md` |
| Wynos Android (native) | ยังไม่มี production release | v1.0.0 Beta 1 — **พักการพัฒนา** ตั้งแต่ 2026-10-10 | `docs/engineering/ANDROID_NATIVE_PLAN.md` |

- `RELEASE_NOTES.md` เก็บ current release summary และ historical Beta1 snapshot
- Owner เท่านั้นที่ประกาศ version ใหม่หรือสั่ง rollback; agent ห้ามเปลี่ยน version/rollback เอง

## 8. Task Tracking Snapshot

Snapshot ณ 2026-10-11 จาก `.wyn/tasks/`:

| สถานะ | จำนวนไฟล์ `WYN-*.md` |
|---|---:|
| backlog | 9 |
| active | 0 |
| review | 0 |
| qa | 0 |
| bugs | 38 |
| approved | 106 |
| completed | 78 |

ข้อสังเกต:

- จำนวนไฟล์เป็น inventory ไม่ใช่หลักฐานว่า production state ตรงกับชื่อโฟลเดอร์ทุกไฟล์ (audit 2026-10-10 ย้ายงาน active ที่เสร็จแล้วไป completed ดู `.wyn/docs/qa/active-tasks-audit-2026-10-10.md`; WYN-219 ปิด 2026-10-11)
- งาน Food/Merchant/Maps หลายชิ้นติดตามด้วย branch/PR โดยตรงและอาจไม่มี task file
- พบ legacy duplicate ID เช่น `WYN-024` มากกว่าหนึ่งไฟล์ใน `bugs/`; ห้าม rename/delete โดยไม่มี audit เพราะอาจมี commit, PR และ log อ้างอิงชื่อเดิม
- ก่อนเลือกงานใหม่ให้เทียบ task file กับ Git history, PR, QA record และ deployment log แล้วค่อยย้ายสถานะ
- security-related bugs (เช่น RLS, role bypass, RPC exposure และ identity leak) ควรถูก triage ก่อน UX backlog แต่การเปลี่ยน security architecture ต้องขอ Founder อนุมัติ

## 9. Known Documentation Drift

- `app/README.md` ยังเป็น snapshot ระยะแรก ใช้เป็น setup/history reference เท่านั้น
- `.wyn/logs/deployments/` และ `.wyn/company/DECISIONS.md` ยังไม่มีบันทึกของงาน Food/Merchant/Maps/Stripe Connect v2 ช่วง 2026-10
- task folders มีทั้ง historical records และสถานะงานจริง; ห้ามสรุปจากจำนวนไฟล์อย่างเดียว
- production truth ต้องตรวจจาก deployment logs, workflow runs และ production verification ไม่ใช่จาก code merge เพียงอย่างเดียว

## 10. จุดเริ่มต้นสำหรับ Agent รอบถัดไป

1. อ่านเอกสารบังคับทั้งหมดใน `AGENTS.md`
2. ตรวจ `.wyn/company/CONTEXT.md`, `.wyn/company/DECISIONS.md`, `.wyn/company/VERSION_CONTROL.md` และ `.wyn/company/WEB_VERSION_CONTROL.md`
3. งานเว็บใหม่ต้องอยู่หลัง Beta2 developer gate ตาม `docs/engineering/WEB_BETA2.md`; ห้ามเริ่มงานใน `app/` หรือ `android/` โดยไม่ถาม Founder
4. หา Product/Design spec และ task file ที่ตรงกับงาน
5. ตรวจ Git/PR/deployment state จริงก่อนเปลี่ยนสถานะ task
6. ทำ smallest safe change, รัน checks ที่เกี่ยวข้อง และส่ง QA ก่อน production
