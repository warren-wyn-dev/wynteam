# ZOKY Roadmap — WYNOS Food → ZOKY (Web + iOS + Android)

> สถานะ: **DRAFT — PENDING FOUNDER APPROVAL** · เจ้าของ: AI Product Manager · วันที่: 2026-10-17
> PRD: `.wyn/tasks/backlog/ZOKY-100-zoky-customer-app.md` · Parity: `.wyn/docs/product/zoky-feature-parity.md`
> ข้อเสนอการตัดสินใจ: `.wyn/docs/product/zoky-decision-proposal.md`
>
> **ไม่เกี่ยวกับ** `.wyn/docs/product/zoky-platform-roadmap.md` (ZOKY Marketplace เดิม ปี 2026-08, ZOKY-001..005 / SELLER-001..005)

## หลักการ

- ทุก phase ไม่แตะ production จนกว่า freeze ปลดและผ่าน gate (`AGENTS.md` Release Gates, `docs/engineering/WYNOS-ADMIN-COMPLETE-BEFORE-DEPLOY.md`)
- ไม่คิดฟีเจอร์ใหม่ — แอปทำตาม parity matrix 96 รายการ
- เลข slice ด้านล่างเป็น **แผน** ยังไม่ได้สร้างไฟล์ task (สร้างเมื่อ Founder อนุมัติ ZOKY-100)
- ลำดับข้างล่างทำคู่ขนานได้เมื่อไม่มี dependency (เช่น brand คู่กับ architecture)

## Phases

| Phase | งาน (ID ที่วางแผน) | เจ้าของหลัก | ผลลัพธ์ | Gate/การอนุมัติ | แตะ production? |
|---|---|---|---|---|---|
| 0 | **ZOKY-101** ตรวจชื่อ + trademark + โดเมน | Founder (AI ช่วยรวบรวมข้อมูล) | ผลค้นหาเครื่องหมายการค้า (กรมทรัพย์สินทางปัญญา, App Store/Play มีแอปชื่อซ้ำไหม, social handles), ซื้อ `zoky.online` | Founder ตัดสินใจชื่อสุดท้าย + ซื้อโดเมน | ไม่ |
| 1 | **ZOKY-100** PRD (เอกสารนี้) | AI PM | PRD + parity + roadmap + decision proposal | Scope Gate: Founder อนุมัติ + ตอบ Q1–Q16 | ไม่ |
| 2 | **ZOKY-102** Brand identity | UI/UX | โลโก้, app icon (iOS/Android/maskable/PWA), สี (white 80–90% + rainbow accents 10–20%), ฟอนต์ไทย, น้ำเสียง copy, splash, ตัวอย่างหน้าจอสำคัญทั้ง iOS/Android/เว็บ | Founder อนุมัติ brand | ไม่ |
| 3 | **ZOKY-103** Architecture | Software Architect + CTO | Flutter app design (โฟลเดอร์ใหม่ เช่น `zoky_app/`, routing/state, map SDK, auth + deep link, push, local storage, error mapping, versioning), design ของ backend changes (Stripe origin/return URL, push routing ทั้ง order และ promo, maps origin), แผน domain cutover + rollback | Technical Gate + Founder อนุมัติ change ที่เป็น security/auth/infra | ไม่ (เอกสาร) |
| 4 | **ZOKY-104** Flutter scaffold + CI | Full-Stack + DevOps | แอปเปล่าที่ล็อกอินได้, Codemagic (iOS → TestFlight), GitHub Actions หรือ Codemagic (Android → Play internal), Firebase/APNs, Associated Domains/App Links (ทดสอบบนโดเมน staging) | Founder อนุมัติค่าใช้จ่าย + สมัคร Apple/Google developer accounts | ไม่ (TestFlight/internal ไม่ใช่ production web) — ยืนยัน Q16 |
| 5 | **Feature slices** (ด้านล่าง) | Full-Stack + UI/UX | ฟีเจอร์ครบตาม parity | Implementation Gate ต่อ slice | ไม่ |
| 6 | **ZOKY-112** QA & Security | QA & Security | test matrix iOS/Android, authn/authz, upload, deep-link abuse, payment, accessibility, parity sign-off 96 แถว | QA & Security Gate (ไม่มี CRITICAL; HIGH resolved/accepted) | ไม่ |
| 7 | TestFlight + Play internal testing | DevOps + Founder | Founder ทดสอบบน iPad, tester Android ทดสอบบนเครื่องจริง | Founder ยืนยันผลทดสอบ | ไม่ |
| 8 | **ZOKY-113** Web rebrand (code) + **ZOKY-114** domain cutover | Full-Stack + DevOps | ตาม rebrand checklist ด้านล่าง, staging บนโดเมนทดสอบ, แผนสื่อสารผู้ใช้ | Staging Gate | **ใช่** — รวมใน coordinated release หลังปลด freeze |
| 9 | **ZOKY-115** Store release | DevOps + AI PM | App Store / Play listing, privacy label/data safety, ส่ง review, staged rollout | Founder Gate (อนุมัติ production/public) → Production Gate | **ใช่** |

## Feature slices (Phase 5)

แต่ละ slice เป็น vertical slice ที่ทดสอบได้จริงบน TestFlight/internal (อ้าง ID จาก parity matrix):

| Slice | ขอบเขต | Parity IDs | ขึ้นกับ |
|---|---|---|---|
| **ZOKY-105** Auth + shell + ที่อยู่ | ล็อกอินอีเมล/Google, สมัคร, ลืมรหัส, ออกจากระบบ, nav, สถานะพื้นฐาน, จอเข้าใช้ไม่ได้, การ์ดโปรไฟล์, รายการ/ฟอร์มที่อยู่, แผนที่ปักหมุด, GPS, ค้นหาสถานที่ | A02–A06, B03–B07, J01, J02, J05–J07, M01 | ZOKY-104, R7 design |
| **ZOKY-106** หน้าหลัก + หน้าร้าน | directory, ค้นหา, แบนเนอร์, ตัวกรอง, ร้านแนะนำ/ใกล้/ยอดนิยม/สั่งอีกครั้ง, การ์ดร้าน, คลิกโฆษณา, หน้าร้าน, สต็อก, เมนูแนะนำ, ค้นหาเมนู, รีวิวร้าน | C01–C05, C07–C12, C16, D01–D11 | ZOKY-105 |
| **ZOKY-107** เมนู + ตะกร้า + checkout + สร้างออเดอร์ | item sheet, ตะกร้า, quote, สิทธิ์ลูกค้าใหม่, แคมเปญ, ตรวจตะกร้า, checkout, โค้ดส่วนลด, สร้างออเดอร์ | E01–E09, F01–F08 | ZOKY-106 |
| **ZOKY-108** ชำระเงิน | นับถอยหลัง, QR, บัญชี, สลิป, สถานะ; Stripe เมื่อ backend fix พร้อม | G01–G04, G07 (P0); G05–G06 (รอ R1) | ZOKY-107, R1 |
| **ZOKY-109** ออเดอร์ + ติดตาม + รีวิว | รายการ, realtime, stepper, หลักฐานส่ง, ยกเลิก, สั่งอีกครั้ง, โทรร้าน, รีวิว | H01–H09, I01–I02 | ZOKY-108 |
| **ZOKY-110** แจ้งเตือน + deep links + แชร์ | FCM, push ออเดอร์/โปรโมชัน, แตะแจ้งเตือน, แชร์ร้าน, Universal/App Links, เปิดออเดอร์จากลิงก์ | K01–K04, D12–D13, H10 | ZOKY-109, R2 |
| **ZOKY-111** Guest + โปรโมชัน + ที่เหลือ | guest browse/ตะกร้า guest, ศูนย์โปรโมชัน, ตั้งค่าโปรโมชัน, splash, pull-to-refresh, ร้านโปรด, เก็บโค้ด, เติมจังหวัดอัตโนมัติ, ตรวจส่งถึง, เสนอสถานที่, ข้อความ, ลิงก์ Social/LINE, ประวัติ | A01, A07, A08, B01–B02, C06, C13–C15, J03, J04, J08, L01, M02, M03 | ZOKY-110, คำตอบ Q1/Q7/Q8 |

ตรวจแล้ว: 7 slices ครอบคลุม 96 แถวของ parity matrix ครบ ไม่ซ้ำ (16 + 23 + 17 + 7 + 11 + 7 + 15)

## Rebrand checklist (ZOKY-113 / ZOKY-114)

### เว็บ (โค้ด) — ทำบน branch, ไม่ deploy ระหว่าง freeze

- [ ] `web/app/food/layout.tsx`: `metadataBase`, `title`, `applicationName`, `description`, `keywords`, `alternates.canonical`, `openGraph` (url/siteName/title/description/images), `twitter`, `appleWebApp.title`, `startupImage` (launch images ใหม่), `msapplication-*`, `themeColor`, JSON-LD (`name`, `alternateName`, `url`), wordmark ใน splash, ฟอนต์ถ้า brand เปลี่ยน
- [ ] `web/app/food/manifest.ts`: `name`, `short_name`, `description` ("Public Beta"), `background_color`, `theme_color`, icons; bump query version ของ manifest
- [ ] Assets ใหม่แบบ versioned ใน `web/public/icons/` (32/192/512/maskable + `splash/launch-*.png`) — ไม่เขียนทับไฟล์เดิมเพื่อ rollback ได้
- [ ] Copy ใน `web/components/food/wynos-food-developer-app.tsx` (brand header, loading, denied, error, toast, การ์ด Social, "แคมเปญ WYNOS", "WYNOS เลือกโปรที่ประหยัดที่สุด", "สั่งจริงกับ WYNOS Food", "ติดตั้ง WYNOS Food", "ขายอาหารบน WYNOS Food", ข้อความที่อยู่ "ข้อมูลนี้เป็นของ WYNOS Food", "WYNOS Place", ปุ่มบันทึก, ยกเลิกโดยลูกค้า "ใน WYNOS Food")
- [ ] Copy ใน `food-guest-browse.tsx`, `food-auth.tsx` (หน้า login/signup/terms, ข้อความ "WYNOS Account" ตาม Q1), `food-promotion-center.tsx`, `food-delivery-map-picker.tsx` (ข้อความพื้นที่บริการ — เฉพาะโหมด Food), `web/app/food/auth/callback/page.tsx`
- [ ] `web/lib/food-customer.ts`: ข้อความ error (`foodCustomerError`), fallback ชื่อผู้รีวิว, ข้อความ Stripe ("Stripe ยังไม่ได้เปิดใช้งานบน WYNOS")
- [ ] `web/lib/food-share.ts`: `FOOD_SITE_URL`, title/text ของการแชร์; `web/lib/food-share-preview.ts`: `siteName`, รูป fallback (`/icons/food/icon-512.png`)
- [ ] `FOOD_PRODUCTION_ORIGIN` ใน `food-auth.tsx` และ `web/app/food/auth/callback/page.tsx` + ตรรกะ host ที่ถือว่าเป็นโดเมน Food
- [ ] `web/proxy.ts`: เพิ่ม `zoky.online` (และ `www.zoky.online`) ใน host map + `/login`/`/signup` redirect; เปลี่ยน `food.wynos.online` และ `wynos.online/food*` เป็น redirect ไป `zoky.online` คง path+query; ปรับ `matcher`
- [ ] `web/app/food/s/[code]/route.ts`: ตรวจ host ใหม่ ให้ redirect ไป `zoky.online/?store=`
- [ ] `web/public/sw.js`: ไอคอนแจ้งเตือน Food, route การแตะ
- [ ] **ห้ามเปลี่ยน** storage keys `wynos-food-*`, ชื่อตาราง/RPC/bucket `food_*`, รูปแบบเลขออเดอร์ (จนกว่า Q9)
- [ ] จุดที่ Social/Merchant ลิงก์มา Food: ทางลัด Food ในหน้า Social (WYN-195/212, `web/lib/food-area-memory.ts`), เมนูด้านข้าง, Merchant share card/QR poster (`foodStoreShareUrl`) — ชี้ `zoky.online` (ตาม Q1/Q10)
- [ ] อัปเดต tests ที่ assert ข้อความ/URL (`web/tests/*food*`, `web/tests/browser/wynos-food-*.spec.ts`)

### Infra / ระบบภายนอก — ต้องได้รับอนุมัติก่อนทุกข้อ

- [ ] ซื้อ `zoky.online` (Founder) และตั้ง DNS → Vercel
- [ ] เพิ่ม domain ใน Vercel Consumer Web project (`prj_bzoZIUdyxaRvXiSLG1uSfjDsyS5a`) — ตรวจโควตา/ข้อจำกัดของ Vercel plan ปัจจุบัน
- [ ] Redirect `food.wynos.online` → `zoky.online` (307 ก่อน แล้ว 308 หลังยืนยัน — Q2); คงการต่ออายุ `wynos.online` และ cert ของ subdomain เดิมไว้ตลอด
- [ ] Supabase Auth: เพิ่ม redirect URLs (`https://zoky.online/food/auth/callback` หรือ path ใหม่, ปลายทางยืนยันอีเมล/รีเซ็ตรหัส) + URL scheme/Universal Link ของแอป; คงของเดิมไว้ช่วงเปลี่ยนผ่าน
- [ ] Google OAuth: authorized origins/redirects ของเว็บ, OAuth client iOS (bundle ID) และ Android (package + SHA-1/SHA-256), consent screen (ใช้ร่วมกับ WYNOS Social — Q1)
- [ ] Stripe: `success_url`/`cancel_url` และ origin check ใน `supabase/functions/food-stripe-checkout/index.ts` และ `food-stripe-cancel/index.ts`, ชื่อสินค้า `WYNOS Food #…`, branding/statement descriptor ของบัญชี (ใช้ร่วมกับ Merchant — ตรวจผลกระทบ)
- [ ] Edge functions: เพิ่ม `https://zoky.online` ใน `ALLOWED_ORIGINS` ของ `wynos-maps-geocode`; ตรวจ edge function อื่นที่ hardcode โดเมน
- [ ] Push: FCM web config สำหรับ origin ใหม่, `send-push-notification` routing token แอปใหม่, `send-food-promotion` รองรับ iOS/Android
- [ ] อีเมล: template ของ Supabase Auth (ยืนยัน/รีเซ็ต) ใช้ร่วมกับ Social — ตัดสินว่าจะเขียนแบบกลาง ๆ หรือคงแบรนด์ WYNOS (Q1); ยืนยันนโยบาย "ไม่มี email notification ของออเดอร์"
- [ ] ข้อความใน database (trigger แจ้งเตือนลูกค้า, ชื่อผู้รีวิว fallback, ชื่อแคมเปญที่มีคำว่า WYNOS) — ต้องเป็น migration แยก (หลังปลด freeze)
- [ ] Apple: App ID + Associated Domains, APNs key, ไฟล์ `/.well-known/apple-app-site-association` บน `zoky.online`
- [ ] Android: ไฟล์ `/.well-known/assetlinks.json` บน `zoky.online`, upload key/Play App Signing ของแอปใหม่ (แยกจาก `io.wyn.wyn`)
- [ ] SEO: Google Search Console property ใหม่ + Change of Address, sitemap/robots, canonical
- [ ] เอกสารกฎหมาย: Terms/Privacy ที่ใช้ชื่อ ZOKY (หรืออ้าง WYNOS) + URL สาธารณะสำหรับ store listing
- [ ] App Store Connect / Play Console: ชื่อ ZOKY, คำอธิบายไทย, screenshots, หมวด Food & Drink, privacy policy/support URL, Privacy Nutrition Label / Data safety, age rating, ข้อมูลติดต่อ, บัญชีทดสอบสำหรับ reviewer

### ลำดับ cutover ที่แนะนำ (รายละเอียดให้ Architect/DevOps ยืนยัน)

1. เตรียม `zoky.online` ให้เสิร์ฟแอปได้คู่กับโดเมนเดิม (ยังไม่ redirect) + Supabase/Stripe/OAuth รองรับทั้งสองโดเมน
2. Smoke test บน `zoky.online` (ล็อกอิน, สั่ง, จ่าย, ลิงก์แชร์)
3. เปิด redirect 307 จาก `food.wynos.online` + แจ้งผู้ใช้
4. เฝ้าดู 1–2 สัปดาห์ แล้วเปลี่ยนเป็น 308 (ถาวร)
5. Rollback: ปิด redirect ใน `proxy.ts`/Vercel → `food.wynos.online` กลับมาเสิร์ฟเหมือนเดิม (ข้อมูลไม่เปลี่ยน)

## Risk register

| ID | ความเสี่ยง | ผลกระทบ | แนวทางลด |
|---|---|---|---|
| R1 | `food-stripe-checkout`/`food-stripe-cancel` ตรวจ `Origin === https://food.wynos.online` ใน live mode และ hardcode success/cancel URL | แอปและโดเมนใหม่จ่ายบัตรไม่ได้ | Architect ออกแบบการยืนยันแหล่งที่มาแบบใหม่ (การตรวจ origin เป็น defense-in-depth; auth จริงคือ JWT + ownership) ให้ QA & Security review; success/cancel เป็น Universal Link ของ `zoky.online` |
| R2 | `send-food-promotion` ส่งเฉพาะ `platform = web`; routing ของ `send-push-notification` สำหรับแอปใหม่ยังไม่ยืนยัน | แอปไม่ได้ push โปรโมชัน/อาจไม่ได้ push ออเดอร์ | ออกแบบค่า `push_tokens.app`/`platform` ของแอป ZOKY ใน ZOKY-103, เพิ่ม test แบบเดียวกับ `_lib.test.ts` |
| R3 | App Store reject (4.8 Sign in with Apple, 5.1.1(v) ลบบัญชี, privacy label) | ส่ง store ไม่ผ่าน | ตอบ Q3/Q4 ก่อนส่ง review; เตรียมบัญชีทดสอบในพื้นที่ (บัญชีนักพัฒนา) ให้ reviewer สั่งได้ |
| R4 | ย้ายโดเมนแล้ว session, localStorage (ตะกร้า/ร้านโปรด/โค้ด), PWA, web push ไม่ตามมา | ผู้ใช้เว็บต้องล็อกอิน/ติดตั้ง/เปิดแจ้งเตือนใหม่ | แผนสื่อสาร, จอแนะนำบน PWA เดิม, เลือกช่วงเวลาที่ออเดอร์น้อย |
| R5 | ลิงก์และ QR ที่ร้านพิมพ์ใช้ `food.wynos.online` | ถ้าโดเมนเดิมหมดอายุ ลิงก์ตายทั้งหมด | คง redirect ตลอดไป, ต่ออายุ `wynos.online`, Merchant สร้าง QR ใหม่ด้วยโดเมนใหม่หลัง cutover |
| R6 | "ZOKY" อาจชนเครื่องหมายการค้า/ชื่อแอปที่มีอยู่; โดเมนยังไม่ซื้อ | ต้องเปลี่ยนชื่อภายหลัง (แพงมากหลังขึ้น store) | ZOKY-101 ก่อนทำ brand; ซื้อโดเมนเร็ว |
| R7 | Maps: `/api/maps/*` เป็น Next.js server route, `wynos-maps-geocode` มี Origin allowlist, เงื่อนไขการใช้ tiles บนมือถือ | ค้นหา/ปักหมุดในแอปไม่ทำงาน | Architect เลือกเส้นทางเรียก (URL เต็มของเว็บ หรือ edge function) + ตรวจ license/usage policy ของ tile provider |
| R8 | Parity drift: ตรรกะ client (เวลาเปิดร้าน Asia/Bangkok, key ตะกร้า, ระยะทาง, ที่อยู่ไทย, ข้อความ error) ต้องเขียนซ้ำใน Dart และเว็บยังพัฒนาต่อ (scope freeze release เพิ่มฟีเจอร์ Food อีก) | พฤติกรรมเว็บกับแอปไม่ตรงกัน | fixture/golden test ร่วม (input/output เดียวกันทั้ง TS/Dart), กติกา "ทุก PR ที่แก้ Food customer ต้องระบุผลต่อแอป", ทบทวน parity matrix ทุก release |
| R9 | Founder มีแค่ iPad, ไม่มี Mac/เครื่อง Android | ทดสอบ iPhone layout ได้จำกัด, Android ไม่มีคนทดสอบ, signing iOS บน cloud | กำหนด tester Android (Q15), ใช้ screenshot test บน CI, เก็บ signing ใน secret store ของ CI เท่านั้น |
| R10 | Production freeze | backend fixes (R1, R2, R7) apply ไม่ได้ | เตรียมทุกอย่างบน branch/staging, รวมเข้า coordinated release |
| R11 | อีเมล Auth ใช้ร่วมกับ WYNOS Social | ลูกค้า ZOKY ได้อีเมลแบรนด์ WYNOS | ตัดสินใน Q1; ถ้าต้องแยก ต้องเป็นงาน auth แยก |
| R12 | ต้นทุนดูแลสองโค้ดเบส (Next.js + Flutter) สำหรับฟีเจอร์เดียวกัน | งานซ้ำทุกฟีเจอร์ในอนาคต | ยอมรับเป็นต้นทุนของการมีแอป native ตามที่ Founder เลือก; ให้ server เป็นแหล่งความจริงของกติกาธุรกิจ |
