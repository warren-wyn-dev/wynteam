# ZOKY-SEPARATION-001 — แยก Zoky ออกจาก WYNOS (ข้อเสนอ Change Control)

Status: **Proposed — รอ Founder อนุมัติรายระดับ ยังไม่เริ่มลงมือ**
Requested: Founder, 2026-11-12 ("เราแยกออกจากกันได้ไหม เป็น zoky.wynos.online" → "ทำทุกข้อเลย" = ครบ 3 ระดับ)
Change-control triggers: major architecture change, cloud/infra cost, production deployment, (ระดับ 3) destructive/major data migration + authentication architecture change
เอกสารนี้เป็นข้อเสนอเท่านั้น ไม่ใช่การอนุมัติให้ deploy, ย้ายโดเมน, สร้างโปรเจกต์ Vercel/Supabase หรือย้ายข้อมูล

## 1. สภาพปัจจุบัน (ตรวจจาก repo 2026-11-12; ยังไม่ได้ตรวจค่าตั้งใน Vercel/Supabase โดยตรง)

| ด้าน | ตอนนี้ |
|---|---|
| โค้ด | Zoky = `/food` และ `/merchant` ของ Next.js app `web` เดียวกับ WYNOS Social |
| Deploy | Vercel project `web` เดียว, deployment เดียวผูกหลายโดเมน (`wynos.online`, `zoky.`, `food.`, `merchant.`, `maps.` ฯลฯ — จาก `.wyn/logs/deployments/*`) |
| ฐานข้อมูล / Auth | Supabase production เดียว, WYNOS Account เดียว, `notifications` ร่วม, `push_tokens.app` แยก social/food/merchant |
| Push | Firebase/FCM โปรเจกต์เดียว |
| Admin | `zoky-admin` เป็นแอปแยก แต่ใช้ Supabase เดียวกัน |
| การพึ่งพากัน | UI ของ Zoky import `lib` ราว 30 โมดูล; ที่ใช้ร่วมกับ Social: `supabase/browser`, `auth-repository`, `account-registry`, `google-pwa-oauth`, `push-notifications`, `share`, `i18n/*`, `maps-*`, `signup-password-policy`, คอมโพเนนต์ `ui/*` และ `auth-flow/*` |

## 2. ระดับ 1 — แยก Vercel project (ข้อเสนอให้ทำก่อน)

**เป้าหมาย:** deploy/rollback Zoky ไม่กระทบ `wynos.online` และสลับกัน
**ทำอะไร:** สร้าง Vercel project ใหม่จาก repo เดิม (root `web`), ย้ายโดเมน `zoky.`, `food.`, `merchant.` ไปที่ project ใหม่, คัดลอก env vars (ที่ไม่ใช่ secret ผ่าน Dashboard; secret ให้ Founder ตั้งเอง), แยก workflow deploy ต่อ project
**ไฟล์ที่กระทบ (คาด):** `.github/workflows/*` (deploy-web, zoky-*), `web/vercel.json`, `web/proxy.ts` (host routing ยังใช้ได้), `web/next.config.ts` (headers ต่อโฮสต์), เอกสาร `.wyn/logs/deployments`
**ผู้ใช้เห็นอะไร:** ไม่เปลี่ยน (origin เดิม → แอปที่ติดตั้งแล้ว, service worker, push token ยังใช้ได้)
**ความเสี่ยง:** ช่วงย้ายโดเมนอาจสะดุดสั้นๆ; env ตกหล่น → build/runtime ผิด; โค้ดกลางที่แก้ผิดยังกระทบทั้งสองฝั่งเมื่อสองฝั่ง deploy โค้ดเดียวกัน
**ค่าใช้จ่าย:** จำนวน project/seat ตามแพ็กเกจ Vercel ปัจจุบัน — ต้องให้ Founder ยืนยัน (ผมยังไม่ทราบแพ็กเกจ)
**Rollback:** ย้ายโดเมนกลับ project เดิม (ไม่ลบ project เดิมจนกว่าจะเสถียร)

## 3. ระดับ 2 — แยกโค้ด

**เป้าหมาย:** Zoky และ Social เป็นสองแอปที่ build ได้เองโดยไม่พึ่งกันแบบซ่อนเร้น
**ทำอะไร:** (ก) สกัดโค้ดกลางเป็นแพ็กเกจร่วมที่มีขอบเขตชัด (auth, supabase client, push, i18n, ui) (ข) ย้าย `app/food`, `components/food`, `lib/food-*`, `lib/merchant-*`, `lib/zoky-*` ไปแอป Zoky (ค) ลบ `/food` ออกจากแอป Social และลบโค้ด Social ออกจากแอป Zoky (ง) แยก test/CI ต่อแอป
**ประมาณการ:** หลายสัปดาห์ (ไม่ใช่ตัวเลขยืนยัน — ต้องให้ Architect ประเมินหลังทำ dependency map เต็ม)
**ความเสี่ยง:** regression ใน auth/push/share; ไฟล์ที่ชนกับ branch release จำนวนมาก (ดูประสบการณ์ merge รอบนี้: 46 ไฟล์ชน); ต้องมี regression suite ครบก่อนเริ่ม
**เงื่อนไขก่อนเริ่ม:** ระดับ 1 เสถียรแล้ว + `main` กับ release lineage ถูกรวมกัน (ตอนนี้ `main` ตามหลัง production — ดูข้อ 6)
**Rollback:** ทำเป็นขั้นเล็ก แต่ละขั้น revert ได้ด้วย PR เดียว

## 4. ระดับ 3 — แยกฐานข้อมูลและบัญชี

**เป้าหมาย:** Supabase คนละโปรเจกต์ บัญชีผู้ใช้ Zoky แยกจาก WYNOS Account
**ผลกระทบที่ต้องตัดสินใจ:** ผู้ใช้เดิมที่ใช้ WYNOS Account เดียวกันจะ (ก) ต้องสมัคร/ผูกบัญชี Zoky ใหม่ หรือ (ข) ย้ายบัญชี+ข้อมูลออเดอร์/ที่อยู่/ร้านค้า/การเงิน — ต้องมี migration ที่ review แล้ว, Stripe Connect, edge functions (`food-*`, `line-*`, `merchant-*`), webhook, LINE LIFF/OA, push tokens
**การเปลี่ยน authentication architecture + ข้อมูลส่วนบุคคล** → ต้อง Founder approve แยก, privacy policy ต้องอัปเดต, ห้ามแตะ production data โดยไม่มี approved migration
**ความเสี่ยง:** สูงสุด (ข้อมูลลูกค้าจริง, เงิน, การยืนยันตัวตน); อาจมี downtime; ย้อนกลับยาก
**เงื่อนไขก่อนเริ่ม:** มีเหตุผลทางธุรกิจ/กฎหมายชัดเจน + แผนย้ายข้อมูลที่ Database Engineer เขียนและ QA & Security ตรวจ + staging DB ที่แยกจริง
**Rollback:** ต้องออกแบบเป็น dual-run (เขียนทั้งสองฝั่งชั่วคราว) ก่อนตัดสลับ — ยังไม่มีแผนละเอียด

## 5. ลำดับที่เสนอ

1. ระดับ 1 (ก่อน promote build `claude/zoky-pwa-notifications-candidate` ถ้าเป็นไปได้ เพื่อให้ promote กระทบเฉพาะ Zoky)
2. รวม `main` กับ release lineage ให้เป็นสายเดียว
3. Dependency map เต็ม + Architecture review สำหรับระดับ 2
4. ระดับ 2 ทีละขั้น
5. ระดับ 3 เฉพาะเมื่อ Founder ยืนยันเหตุผลและอนุมัติแยกต่างหาก

## 6. ข้อสังเกตที่เกี่ยวข้อง

- `main` ไม่มีโค้ด Zoky rebrand (`99bd951da`) ที่ production ใช้อยู่ — ประวัติสองสายแยกกัน (merge รอบนี้ต้อง `--allow-unrelated`-style และชน 46 ไฟล์)
- `*.vercel.app` preview ไม่ใช่โฮสต์ Zoky ตามโค้ด (`isFoodAppHost`) จึงทดสอบการ์ดติดตั้งบน preview ไม่ได้ — แยก project แล้วควรมี preview domain ของ Zoky

## 7. สิ่งที่ต้องให้ Founder ตัดสิน

| # | เรื่อง | ตัวเลือก |
|---|---|---|
| D1 | อนุมัติระดับ 1 | อนุมัติ / ไม่อนุมัติ / ขอข้อมูลเพิ่ม |
| D2 | ค่าใช้จ่าย Vercel project เพิ่ม | ยืนยันแพ็กเกจและงบ |
| D3 | ระดับ 2 | อนุมัติให้เริ่ม dependency map + architecture review (ยังไม่ใช่ implement) |
| D4 | ระดับ 3 | ระบุเหตุผลทางธุรกิจ/กฎหมาย และนโยบายผู้ใช้เดิม (สมัครใหม่ vs ย้ายบัญชี) |

## 8. สิ่งที่ยังไม่ได้ตรวจ

ค่าตั้ง Vercel (รายการโดเมน, env, แพ็กเกจ), ค่าตั้ง Supabase/Firebase, จำนวนผู้ใช้/ข้อมูลจริง, การใช้งาน cookie ข้าม subdomain

## 9. คำตัดสินของ Founder (2026-11-12)

| # | คำตอบ | ผลต่องาน |
|---|---|---|
| D1 ระดับ 1 | **อนุมัติให้เตรียมแผนลงมือ** | เขียน runbook (หัวข้อ 10) — ยังไม่สร้าง project ไม่ย้ายโดเมน ต้องขออนุมัติอีกครั้งก่อนลงมือจริง |
| D2 ค่าใช้จ่าย | **ต้องรู้ตัวเลขก่อน** | ดึงจาก Vercel API ไม่ได้ (billing 404, ไม่เห็นแพ็กเกจ) → Founder เปิด Dashboard → Settings → Billing ดูแพ็กเกจและราคาต่อ project/seat ปัจจุบัน แล้วยืนยันงบ ห้ามเริ่มระดับ 1 ก่อนยืนยัน |
| D3 ระดับ 2 | **รอระดับ 1 เสร็จก่อน** | ไม่เริ่ม dependency map/architecture review จนกว่าระดับ 1 เสถียร |
| D4 ระดับ 3 | **แยกข้อมูลตามกฎหมาย/ความปลอดภัย** | ต้องมี (1) ระบุข้อกำหนดที่ต้องปฏิบัติตาม (เช่น PDPA — Founder/ที่ปรึกษากฎหมายยืนยัน) (2) แผนย้ายข้อมูลที่ Database Engineer เขียน + QA & Security ตรวจ (3) อัปเดต privacy policy (ตอนนี้เป็น placeholder) (4) ยังไม่มี task implement จนกว่าจะอนุมัติแยก |

ข้อสังเกตด้านแพ็กเกจ (ต้องตรวจจริง ไม่ใช่ข้อเท็จจริงที่ยืนยันแล้ว): ถ้าทีม `warren14` อยู่แพ็กเกจ Hobby เงื่อนไขของแพ็กเกจนั้นห้ามใช้เชิงพาณิชย์ ซึ่ง Zoky รับชำระเงินอยู่ — Founder ควรตรวจหน้า Billing และเงื่อนไขการใช้งานปัจจุบัน

## 10. Runbook ระดับ 1 (ร่าง — ยังไม่ได้ลงมือ)

**ก่อนเริ่ม (gate):** D2 ยืนยันงบแล้ว + Founder อนุมัติ "ลงมือ" อีกครั้ง + ไม่มี release ค้างระหว่างทาง

1. **ตรวจเตรียม (อ่านอย่างเดียว):** รายการโดเมนปัจจุบันของ project `web` (9 โดเมน: `wynos.online`, `www.`, `zoky.`, `food.`, `merchant.`, `maps.`, `tiles.`, `geo.`, `routing.`), env vars ที่ตั้งไว้, deploy workflow ที่ผูกกับ project (`deploy-web.yml`, `zoky-*.yml`, `wyn-158-production-deploy.yml`)
2. **จัดกลุ่มโดเมน:**
   - Zoky project ใหม่: `zoky.`, `food.`, `merchant.`
   - project เดิม (WYNOS): `wynos.online`, `www.`, `maps.`, `tiles.`, `geo.`, `routing.` (Maps เป็นของ WYNOS — ยืนยันกับ Founder ก่อน)
3. **env vars (ชื่อที่โค้ดอ้างถึง ไม่ใช่ค่า):** `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_URL`, `NEXT_PUBLIC_FIREBASE_*` (API_KEY, APP_ID, MESSAGING_SENDER_ID, PROJECT_ID, AUTH_DOMAIN, STORAGE_BUCKET, VAPID_KEY), `NEXT_PUBLIC_LIFF_ID_FOOD`, `NEXT_PUBLIC_LIFF_ID_MERCHANT`, `ZOKY_MERCHANT_FLUTTER_ENABLED`, `ZOKY_LEGACY_FOOD_REDIRECT`; ฝั่ง Maps (`WYNOS_GEO_ORIGIN`, `WYNOS_ROUTING_ORIGIN`, `WYNOS_ORS_API_KEY`, `WYNOS_MAPS_UPSTREAM_TOKEN`) ใช้กับ `/maps` ซึ่ง Zoky เรียกผ่าน `lib/maps-*` — ต้องตัดสินว่า Zoky project ต้องมีด้วยหรือไม่ ค่าที่เป็น secret ให้ Founder ตั้งใน Dashboard เอง ห้ามส่งในแชท/commit
4. **สร้าง project + build ทดสอบ:** ไม่ผูกโดเมน, build เป็น preview/`--skip-domain`, ตรวจ `/`, `/food`, `/merchant`, `/line`, `/api/push-config` ด้วยโฮสต์จริงผ่าน header/bypass ที่ Founder อนุมัติ
5. **ปรับ workflow:** แยก workflow deploy ต่อ project (ห้ามให้ workflow เดียว deploy ทั้งสองโดยไม่ตั้งใจ) และอัปเดต environment protection ของ GitHub ให้ครอบทั้งสอง project
6. **ย้ายโดเมน (หน้าต่างบำรุงรักษาที่ Founder เลือก):** ทีละโดเมน เริ่มจาก `food.` (ความเสี่ยงต่ำสุด) ตรวจ 200/redirect/header ทุกโดเมนหลังย้าย
7. **หลังย้าย:** ตรวจ push (ส่งแจ้งเตือนทดสอบ), LINE LIFF endpoint, Stripe return URL, OAuth redirect (Google) และแอปที่ติดตั้งแล้ว (origin เดิม ไม่ควรหลุด); เฝ้า runtime errors 24 ชม.
8. **Rollback:** ย้ายโดเมนกลับ project เดิม (คง project เดิม + deployment ล่าสุดไว้ ไม่ลบ); deployment อ้างอิงปัจจุบัน `dpl_5Z1Uk1fNNG1dBcJDN5ZzWWsnTGUv` (build PWA ที่ promote 2026-11-12), ก่อนหน้า `dpl_7B62FanBFc9pmqqzH2sK4xcDZuVa`

**จุดเสี่ยงที่ต้องตรวจก่อนลงมือ:** OAuth redirect URI / Supabase Auth Site URL ที่ผูกกับโดเมน, LINE LIFF endpoint, Stripe webhook/return URL, Firebase authorized domains (ค่าเหล่านี้ผูกกับโดเมน ไม่ใช่ project — ถ้าไม่เปลี่ยนโดเมนก็ไม่ควรกระทบ แต่ยังไม่ได้ยืนยันกับการตั้งค่าจริง)
