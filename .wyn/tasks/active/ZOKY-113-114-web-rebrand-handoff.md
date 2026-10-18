# Handoff — ZOKY-113 (Web rebrand) + ZOKY-114 (domain cutover, ส่วนโค้ด)

Status: implemented บน branch `feat/zoky-web-rebrand` (local commit เท่านั้น, ยังไม่ push/deploy) → ส่งต่อ AI QA & Security
Owner: AI Coding (Full-Stack) | Date: 2026-10-18
อ้างอิง: Founder decision 2026-10-18 "Web first" (`.wyn/company/DECISIONS.md` บน `docs/zoky-foundation`), แก้โดเมนเป็น **`zoky.wynos.online` อย่างเดียว** (Founder 2026-10-18, ไม่ใช้ `zoky.online`), ZOKY-100 AC 5–8, roadmap "Rebrand checklist", decision proposal D1/D2, `zoky-design-system.md`

## สิ่งที่เปลี่ยน

### โดเมน / routing (ZOKY-114 ส่วนโค้ด)
- `web/lib/food-origin.ts` (ใหม่): แหล่งเดียวของ origin — `FOOD_PRODUCTION_ORIGIN = https://zoky.wynos.online`, `FOOD_LEGACY_HOST = food.wynos.online`, `isFoodAppHost`, `foodAuthOriginFor`, `foodHomeUrlFor`
  - auth บน `zoky.wynos.online` และ `food.wynos.online` ใช้ origin ที่ผู้ใช้อยู่ (PKCE/session ไม่ข้าม origin; ถ้า rollback redirect โดเมนเดิมยังล็อกอินได้)
  - Food ที่เปิดจาก `wynos.online`/`www.wynos.online` ถูกส่งไป `zoky.wynos.online`; localhost/preview ใช้ origin ตัวเอง
- `web/proxy.ts`:
  - `zoky.wynos.online/` → rewrite `/food` (แบบเดียวกับ `food.wynos.online` เดิม); `/login`, `/signup*` → `/food/login`, `/food/signup`
  - **ทุก URL บน `food.wynos.online`** → `307` ไป `https://zoky.wynos.online` path+query เดิม (ยกเว้น `/_next/*`, `/api/*` เพื่อไม่ให้แท็บที่เปิดค้างพัง)
  - `wynos.online/food*` → `307` ไป `zoky.wynos.online` (`/food` → `/`)
  - matcher เพิ่ม `{ source: "/((?!_next/|api/).*)", has: host food.wynos.online }` (ตรวจแล้วว่าอยู่ใน middleware-manifest หลัง build)
  - ค่า `FOOD_MOVE_STATUS = 307`; เปลี่ยนเป็น 308 หลังยืนยัน (Q2) = แก้บรรทัดเดียว
- `web/next.config.ts`: rewrite `/s/:code` ย้ายจาก host `food.wynos.online` เป็น `zoky.wynos.online`
- `web/app/food/s/[code]/route.ts`: ใช้ `isFoodAppHost` + redirect ไป `zoky.wynos.online/?store=`
- `web/components/food/food-auth.tsx`, `web/app/food/auth/callback/page.tsx`: ใช้ helper กลางแทน `FOOD_PRODUCTION_ORIGIN` ที่ hardcode
- `web/app/auth/callback/page.tsx` (Social callback): legacy Food return ไป `zoky.wynos.online/` แทน `food.wynos.online/`
- `web/lib/push-notifications.ts`: `pushAppFor("zoky.wynos.online") = "food"` (คง food.wynos.online); `web/components/push-prompt.tsx` ใช้ `isFoodAppHost`
- `web/app/sitemap.xml/route.ts`, `web/app/robots.ts`: `zoky.wynos.online`
- `web/lib/food-share.ts` (`FOOD_SITE_URL`) → share URL/QR ของ Merchant (`foodStoreShareUrl`) และปุ่ม "สั่งอาหาร" ใน WYNOS Maps ชี้ `zoky.wynos.online` อัตโนมัติ

### แบรนด์ (ZOKY-113)
- Metadata/SEO (`web/app/food/layout.tsx`): title/applicationName/description/keywords/canonical/OpenGraph/Twitter/appleWebApp/JSON-LD = ZOKY + `zoky.wynos.online`; manifest `?v=20261018-zoky1`; apple-touch 180px; `themeColor`/`msapplication-TileColor` = `#f93384` (ต้น header gradient)
- Manifest (`web/app/food/manifest.ts` และ `web/public/food/manifest.webmanifest`): name/short_name `ZOKY`, description `ZOKY สั่งอาหาร (Public Beta)`, `#f93384`, ไอคอนใหม่
- Splash: gradient `#F93384 → #F72C7E (35%) → #EE226E` + wordmark ขาว (แทนโลโก้แดง + "WYNOS Food"); theme-color ชั่วคราวระหว่าง splash `#f93384`
- สี (`web/app/food/food-app.css`, เฉพาะ scope ลูกค้า Food): `--fx-red`/`--wf-red` → Pink Deep `#D61256` (ขาวบนพื้น 5.15:1 ผ่าน AA), dark/text → `#AF1341`, soft → `#FFF1F6`, line → `#F9C0DE`, เงา → `rgb(238 34 110 / x)`; เพิ่ม `--fx-danger: #B3261E` ใช้กับ `fx-closed-label`, `fx-status.is-danger`, `fx-checkout-address.is-error` (ชมพูไม่หมายถึง error) — `food.css` ไม่แตะ เพราะ Merchant/Maps import ร่วม
- Copy ลูกค้า: "WYNOS Food" → "ZOKY" ใน `wynos-food-developer-app.tsx`, `food-guest-browse.tsx`, `food-auth.tsx`, `food-promotion-center.tsx`, `food-delivery-map-picker.tsx`, `app/food/auth/callback`, login/signup titles, `lib/food-customer.ts`, `lib/food-share*.ts`, push prompt ฝั่ง Food; "แคมเปญ ZOKY", "ZOKY เลือกโปร…", "WYNOS Place ·" → "สถานที่ ·"; header ใช้ไอคอน ZOKY + "ZOKY"
- คงไว้ตั้งใจ: "WYNOS Account", "เปิด WYNOS Social", ลิงก์ "กลับ WYNOS", ข้อกำหนด "ของ WYNOS" (รอ Q1), ข้อความจอ PWA legacy ที่อ้าง "WYNOS Food รุ่นเก่า", storage keys `wynos-food-*`, ตาราง/RPC/bucket `food_*`, เลขออเดอร์ `WF`, ชื่อไฟล์/คอมโพเนนต์ภายใน
- Service worker `web/public/sw.js`: ไอคอนแจ้งเตือนโปร Food → ZOKY
- i18n: เพิ่มคำแปลอังกฤษของข้อความ ZOKY ใน `web/lib/i18n/en.ts` (ของเดิมคงไว้ให้ Merchant)

### Assets (ไฟล์ใหม่ versioned — ไม่ทับของเดิม, rollback ได้)
- `web/public/icons/zoky/`: `icon-32-v1.png`, `icon-192-v1.png`, `icon-512-v1.png`, `apple-touch-icon-180-v1.png` (ไม่มี alpha), `icon-512-maskable-v1.png` (wordmark อยู่ในวง safe zone 80%), `wordmark-white-v1.png`, `splash/launch-*.png` 19 ขนาด
- ต้นทาง: `design-reference/zoky/zoky-app-icon-1024.png` (ไอคอน full-bleed ที่ Founder เลือก 2026-10-17) และ `zoky_app/assets/images/zoky_wordmark.png` (wordmark ต้นฉบับ) — **ไม่ได้ใช้** `zoky_app/web/icons/*` และ `ios/.../AppIcon` เพราะยังเป็นไอคอน Flutter ค่าเริ่มต้น
- สร้างด้วย PIL: `web/tools/zoky113_generate_web_icons.py` (รันซ้ำได้)
- ข้อจำกัด: ไอคอนมาจาก raster 1024 (master vector A1 ยังไม่อนุมัติ — design Q3); favicon 32px อ่าน wordmark ได้พอใช้; maskable จุดในหมุดเป็นสีพื้น (เหมือน wordmark ต้นฉบับ) — ให้ UI/UX + Founder ตรวจด้วยตาบนเครื่องจริง

## ผลทดสอบ (รันจริงใน worktree)
- `npm ci`: สำเร็จ
- `npm run lint`: 0 errors (17 warnings เดิม)
- `npm run typecheck`: ผ่าน
- `node --test tests/*.test.mjs`: 338 pass / 0 fail (baseline origin/main 332 pass) — เพิ่ม `tests/food-origin.test.mjs` และเขียน proxy tests ใน `tests/maps-host-redirect.test.mjs` ใหม่เป็น behavior tests (redirect ทุก path ใน AC6, rewrite, auth paths)
- `npm run build`: ผ่าน
- Local smoke (`next start` + Host header, ไม่มี Supabase env): `food.wynos.online/`, `/s/<code>`, `/?order=WF0001&stripe=success`, `/food/auth/callback?code=…` → 307 ไป zoky พร้อม path+query; `wynos.online/food?promo=CODE` → `zoky.wynos.online/?promo=CODE`; `zoky.wynos.online/` 200 title "ZOKY • สั่งอาหาร", theme-color `#f93384`, canonical zoky; sitemap zoky
- Playwright source-assertion specs (`wynos-food-developer-preview`, `wynos-merchant`, chromium-desktop, local dev server): 63 pass, 4 fail เพราะเครื่องนี้ไม่มี browser binary (ไม่ใช่ regression) — **ไม่ได้รัน E2E บนเบราว์เซอร์จริง** และไม่ได้ทดสอบกับ production

## Production freeze guard (commit 42a8f93)
- `tools/check_wynos_release_freeze.py` (CI job ใน `ci.yml`) ตรวจเฉพาะโครงสร้าง workflow — branch นี้ไม่แตะ `.github/` จึง **CI ไม่ block**
- การ deploy production ถูกล็อกที่ `wyn-158-production-deploy.yml` (workflow_dispatch เท่านั้น ไม่มี push trigger): ต้องเลือก `release_confirmation = RELEASE_ALL_APPROVED`, รันจาก `main`, ผ่าน GitHub Environment `production` (reviewer approval) และ issue acceptance #1142–#1151 ต้อง **closed ครบ** (`.github/scripts/require-wynos-final-release-ready.sh`) — ดังนั้น merge เข้า main จะ **ไม่ deploy เอง** (หมายเหตุ: `docs/engineering/WEB_STAGING.md` ยังเขียนว่า merge = deploy อัตโนมัติ ซึ่งล้าสมัยหลัง freeze)
- งานนี้ไม่ได้ bypass/แก้ guard

## สิ่งที่ยังไม่ได้ทำ (ต้องอนุมัติแยก/งานถัดไป)
1. ~~**Edge functions (BLOCKER ของการจ่ายบัตร)**~~ — **แก้โค้ดแล้ว (ZOKY-135, commit 574f12e, Founder อนุมัติ 2026-10-18)** เหลือ QA re-test + deploy ตาม gate ก่อนหรือพร้อม cutover (ดูข้อ 6 ใน checklist)
2. ข้อความแบรนด์ฝั่ง database/edge function (เช่น `WYNOS Food #WF…` ใน Stripe, trigger แจ้งเตือนลูกค้า, ชื่อแคมเปญ) — migration แยกหลังปลด freeze
3. Merchant/Admin/Social labels ยังเป็น "WYNOS Food" (รอ Q1/Q10) รวมถึงหัวโปสเตอร์ QR ใน `merchant-share-card.tsx` (URL เปลี่ยนเป็น zoky แล้ว แต่หัวข้อยังเขียน "WYNOS Food") และทางลัด Social (`home-food-shortcut.tsx`, drawer) ซึ่งลิงก์ `/food` บน wynos.online → redirect ไป ZOKY อยู่แล้ว
4. การแยก `--fx-red` ทุกจุดเป็น `--zk-action-primary/--zk-brand/--zk-error` แบบเต็ม, แก้ success/muted contrast, `userScalable:false` (design Q6) — ทำเฉพาะเปลี่ยนค่า token + แยก danger 3 จุด
5. OG image 1200×630 (A16) — ยังใช้ไอคอน 512 แบบ `summary` เหมือนเดิม
6. จอแนะนำสำหรับ PWA ที่ติดตั้งจาก `food.wynos.online` (PRD edge case 3): server redirect ทุก path ทำให้ PWA เดิมเปิด ZOKY ในหน้าต่างเบราว์เซอร์แทน standalone — ผู้ใช้ต้องติดตั้งใหม่ ต้องมีแผนสื่อสาร (AC9)
7. Login ที่ค้างระหว่าง cutover (`food.wynos.online/food/auth/callback?code=` → zoky) จะ exchange ไม่ได้เพราะ PKCE verifier อยู่บน origin เดิม → ผู้ใช้กดล็อกอินใหม่ (ยอมรับได้ช่วงสั้น); session/ตะกร้า/ร้านโปรดในเครื่องไม่ตามมา (R4)
8. ไม่ได้รัน browser E2E; QA ต้องทดสอบบน staging preview

## Founder / DevOps checklist สำหรับ go-live (ทุกข้อต้องได้รับอนุมัติก่อน — AI ไม่ได้ทำ)

1. **Vercel**: เพิ่ม domain `zoky.wynos.online` ใน Consumer Web project (roadmap ระบุ `prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`; ยืนยันกับ secret `VERCEL_PROJECT_ID` ของ `wyn-158-production-deploy.yml`) — ทำใน Dashboard (Project → Settings → Domains) หรือทำ workflow แบบ `.github/workflows/admin-attach-domain.yml` (ตัวนั้นผูก Admin project `prj_Ca3S…` + `admin.wynos.online` เท่านั้น ใช้ตรง ๆ ไม่ได้) — คง `food.wynos.online` ไว้ใน project (ต้องเสิร์ฟ redirect ตลอดไป, R5)
2. **DNS**: เป็น subdomain ของ `wynos.online` แบบเดียวกับ `food.wynos.online` (WYN-211): ถ้า `wynos.online` ใช้ Vercel DNS ไม่ต้องทำเพิ่ม; ถ้า DNS อยู่ที่ผู้ให้บริการอื่น เพิ่ม `CNAME zoky → cname.vercel-dns.com` (หรือค่าที่ Vercel แสดง) แล้วรอ verified + SSL; ห้ามแก้ record ของ `food`/`merchant`/`maps`; คงการต่ออายุ `wynos.online`
3. **Supabase Auth** (URL Configuration → Redirect URLs, เพิ่ม — **ไม่ลบของ food.wynos.online** ช่วงเปลี่ยนผ่าน):
   - `https://zoky.wynos.online/food/auth/callback` (Google OAuth, exact)
   - `https://zoky.wynos.online/auth/callback?next=%2Ffood` หรือ pattern `https://zoky.wynos.online/auth/callback**` (ยืนยันอีเมลตอนสมัคร Food — `getEmailConfirmationRedirectUrl("/food")`)
   - `https://zoky.wynos.online/reset-password**` (รีเซ็ตรหัส `?returnTo=/food/login`)
   - Site URL: คง `https://wynos.online` (ใช้ร่วมกับ Social); อีเมล template ยังแบรนด์ WYNOS (R11/Q1)
   - [x] ZOKY-138 (5e0bec5): `.github/scripts/sync-auth-password-policy.sh` เพิ่ม 3 URL ของ zoky แบบ exact (`/food/auth/callback`, `/auth/callback?next=%2Ffood`, `/reset-password?returnTo=%2Ffood%2Flogin`) — **คำเตือน:** workflow `web-beta1-auth-password-policy.yml` รัน `apply` เมื่อ push เข้า `main` ที่แก้ script นี้ → merge = PATCH Supabase Auth production ทันที (เพิ่มอย่างเดียว); ต้องตรวจบน staging ว่า reset URL ที่มี query match จริง ถ้าไม่ match ให้เพิ่ม `https://zoky.wynos.online/reset-password**`
4. **Google OAuth**: login ใช้ Supabase `signInWithOAuth` → Authorized redirect URI ของ Google คือ callback ของ Supabase (ไม่เปลี่ยน); ตรวจว่า Authorized JavaScript origins มีรายการโดเมนหรือไม่ ถ้ามี `https://food.wynos.online` ให้เพิ่ม `https://zoky.wynos.online`; ถ้า browser API key ของ Firebase/Google Cloud จำกัด HTTP referrer ให้เพิ่ม `zoky.wynos.online/*`
5. **Stripe**: Checkout success/cancel ถูกสร้างใน edge function (ข้อ 6) ไม่ต้องลงทะเบียนโดเมนใน Dashboard; ชื่อสินค้า/branding/statement descriptor ใช้ร่วมกับ Merchant — คงไว้จนกว่าจะตัดสิน Q10
6. **Edge functions — [x] แก้โค้ดแล้ว (ZOKY-135: 574f12e + 738d481) / [ ] QA re-test / [ ] deploy ก่อนหรือพร้อม web** (deploy 3 functions: `food-stripe-checkout`, `food-stripe-cancel`, `wynos-maps-geocode` ผ่าน `deploy-edge-functions.yml` หลังผ่าน gate — AI ไม่ได้ deploy). รายการเดิมที่แก้แล้ว:
   - `supabase/functions/food-stripe-checkout/index.ts:69` — live mode รับเฉพาะ `Origin === https://food.wynos.online` → **ต้องรับ `https://zoky.wynos.online`** (มิฉะนั้นจ่ายบัตรบน ZOKY ได้ 403 `live_stripe_origin_required`)
   - `supabase/functions/food-stripe-checkout/index.ts:152-153` — `success_url`/`cancel_url` = `food.wynos.online/?order=…` (ยังใช้ได้ผ่าน redirect 307 แต่ควรเปลี่ยนเป็น zoky); `:155` ชื่อสินค้า `WYNOS Food #…` (Q10)
   - `supabase/functions/food-stripe-cancel/index.ts:71` — origin check เดียวกัน (ยกเลิกออเดอร์ที่จ่ายบัตรบน ZOKY จะ 403)
   - `supabase/functions/wynos-maps-geocode/index.ts:22-30` (`ALLOWED_ORIGINS`, บรรทัด 26 คือ food) — เพิ่ม `https://zoky.wynos.online` (ไม่งั้นค้นหาที่อยู่ fallback ผ่าน geocode จาก ZOKY ได้ 403)
   - ตรวจแล้วไม่พบ hardcode โดเมน Food ใน edge function อื่น (`merchant-stripe-*` ใช้ `merchant.wynos.online` ไม่เกี่ยว)
7. **Freeze lift + production deploy**: Founder อนุมัติปลด freeze สำหรับ release นี้ (หรือรวมใน coordinated release), ปิด acceptance #1142–#1151, merge PR หลัง QA/CTO review + staging เขียว, แล้วรัน `wyn-158-production-deploy.yml` ด้วย `RELEASE_ALL_APPROVED` + production reviewer approval
   - ลำดับที่แนะนำ: (a) ข้อ 1–4 + edge functions ข้อ 6 → (b) deploy web (redirect เปิดทันทีเมื่อ deploy) → (c) smoke: `zoky.wynos.online` ล็อกอิน Google/อีเมล, รีเซ็ตรหัส, สั่ง + จ่าย Stripe success/cancel, `/s/<code>`, `/?store=`, `/?order=`, `/?promo=`, link preview LINE; `food.wynos.online/*` และ `wynos.online/food*` → 307 path+query → (d) แจ้งผู้ใช้ (ล็อกอินใหม่, ติดตั้ง PWA ใหม่, เปิดแจ้งเตือนใหม่) → (e) เฝ้าดู 1–2 สัปดาห์ แล้วตัดสิน 308
   - ถ้าต้องการเปิด `zoky.wynos.online` ก่อนโดยยังไม่ redirect (roadmap ขั้น 1) ให้สั่ง AI แยก commit redirect ของ `food.wynos.online` ออก — ตอนนี้ deploy ครั้งเดียวเปิดทั้งคู่
8. **Rollback**:
   - เร็วที่สุด: Vercel Instant Rollback ไป production deployment ก่อนหน้า → `food.wynos.online` เสิร์ฟแอปเดิมทันที (assets เดิมใน `/icons/food/*` ยังอยู่, ไม่มีการเปลี่ยนข้อมูล database)
   - ถาวร: revert merge commit ของ branch นี้บน main แล้ว deploy ตาม gate
   - คง Supabase redirect URLs ของทั้งสองโดเมน และ edge function ที่รับทั้งสอง origin ไว้ตลอดช่วงเปลี่ยนผ่าน เพื่อให้ rollback ไม่ทำให้ login/จ่ายเงินพัง
   - ห้ามถอด domain `food.wynos.online` ออกจาก Vercel (ลิงก์/QR เก่าจะตาย)

## รอบแก้ QA findings (AI Coding, 2026-10-18, Founder อนุมัติ 2026-10-18)
- [x] ZOKY-135 (HIGH) edge functions รับ `zoky.wynos.online` + คง `food.wynos.online` (exact allowlist), success/cancel ใช้ origin ที่อยู่ใน allowlist ไม่งั้น ZOKY, ชื่อสินค้า `ZOKY #…` — 574f12e, 738d481
- [x] ZOKY-136 (MEDIUM) `food.wynos.online/sw.js` ไม่ redirect แล้ว เสิร์ฟ cleanup worker (unsubscribe push + ลบ cache + unregister) — bdcd0a1; residual risk ดูในไฟล์ bug (push ก่อน browser ตรวจ update ยังแสดงได้, server-side ต้อง migration — ยังไม่ทำ)
- [x] ZOKY-138 (LOW) Auth allowlist sync เพิ่ม zoky — 5e0bec5 (freeze guard PASS; ดูคำเตือน merge = apply production ในข้อ 3)
- [~] ZOKY-137 (LOW) แก้เฉพาะ focus ring ใน address form (selector อื่นใน food.css ไม่มี component ใช้) — 15fc1e3; ไอคอน bevel ยังเปิด (รอ A1/Q3)
- ผลตรวจ: lint 0 errors, typecheck ผ่าน, unit 344/344, build ผ่าน, Auth policy offline test ผ่าน, local smoke `food.wynos.online/sw.js` = cleanup worker; **ไม่มี Deno ในเครื่อง** — `deno check/test` ไม่ได้รัน (CI รัน)
- ยังไม่ push / deploy

## Handoff ถัดไป
AI QA & Security: ทดสอบ redirect (AC6), auth origin, open-redirect (redirect ใช้ host คงที่ ไม่รับ input เป็นปลายทาง), contrast ของสีใหม่, ไอคอน/splash บน iPhone/Android จริงบน staging preview → CTO final review → Founder
