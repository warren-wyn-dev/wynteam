# CTO Final Technical Review — ZOKY web rebrand + ย้ายโดเมน (ZOKY-113/114, ZOKY-135..138)

- Reviewer: WYN CTO (AI) | วันที่: 2026-10-18
- Branch: `feat/zoky-web-rebrand` @ `3ea034d` (9 commits บน `origin/main` `42a8f93`: `ffd3ac6` … `3ea034d`); remote branch = local HEAD, **ยังไม่มี PR**
- อ้างอิง: `AGENTS.md`, `docs/engineering/{WORKFLOW,DEFINITION_OF_DONE,SECURITY_RULES,GIT_WORKFLOW,WEB_STAGING}.md`, handoff `.wyn/tasks/active/ZOKY-113-114-web-rebrand-handoff.md`, bugs `.wyn/tasks/bugs/ZOKY-135..138`, Founder decisions 2026-10-18 (`docs/zoky-foundation:.wyn/company/DECISIONS.md`: Web first, โดเมน `zoky.wynos.online` อย่างเดียว, Next.js คงเดิม, ZOKY-135 อนุมัติแก้ origin โดยคง food, ZOKY-136 แก้ก่อน cutover)
- ขอบเขตการตรวจ: diff ทั้งหมดเทียบ `origin/main` (81 ไฟล์), CI/workflows ที่เกี่ยวข้อง — ไม่อ่าน env/secrets, ไม่เชื่อม DB จริง, ไม่ยิง request ไป production, ไม่ push/deploy, ไม่แก้ application code

## Verdict: **APPROVED WITH CONDITIONS**

โค้ดผ่านในเชิงสถาปัตยกรรมและความปลอดภัย: ไม่พบ CRITICAL/HIGH ในโค้ด. การเปลี่ยนแปลงเรียบง่าย (ใช้ Next.js `proxy.ts` เดิม, origin รวมที่ `web/lib/food-origin.ts` ที่เดียว, edge functions ใช้ exact allowlist), backward compatible กับเว็บปัจจุบัน และ rollback ได้. **แต่ยังขึ้น production ไม่ได้** จนกว่าจะทำเงื่อนไขก่อน merge (C1–C3) และแก้ release blocker เรื่อง production freeze กับเส้นทาง deploy ของ `wynos-maps-geocode` (ดู Release blockers)

## ผลตรวจที่รันจริง (worktree, ไม่มี env/secrets)

| Check | ผล |
|---|---|
| `npm run lint` | 0 errors (17 warnings เดิม) |
| `npm run typecheck` | ผ่าน |
| `node --test tests/*.test.mjs` | 344/344 pass |
| `npm run build` | ผ่าน (Proxy/Middleware อยู่ใน build) |
| `bash .github/scripts/test-auth-password-policy.sh` (fake curl, offline) | ผ่าน |
| `python3 tools/check_wynos_release_freeze.py` | PASS |
| `deno check/test` | ไม่ได้รันรอบนี้ (ไม่มี Deno); อ้างผล QA: 17 functions check ผ่าน, 118/118 tests |
| Playwright/browser E2E | ไม่ได้รันรอบนี้; อ้างผล QA: Food+Merchant Chromium 134/134 (local `next start`) |
| อ่านสถานะ GitHub (REST, read-only) | acceptance #1142–#1151 **open ทั้ง 10**; ไม่มี PR ของ branch นี้ |

## สิ่งที่ตรวจแล้วผ่าน (สรุป)

- **Redirect / open redirect**: `redirectToFood()` ใช้ origin คงที่ `https://zoky.wynos.online`, รับเฉพาะ path+query (path แบบ `//evil.com` ยังอยู่บน host zoky); matcher `food.wynos.online` ยกเว้น `/_next/*`, `/api/*` ถูกต้อง; `/s/:code` บน food → 307 → zoky แล้ว rewrite (middleware รันก่อน beforeFiles rewrites)
- **Auth origins**: `foodAuthOriginFor` คืน origin ปัจจุบันบน zoky/food (PKCE ไม่ข้าม origin), ส่ง Social host ไป zoky, localhost/preview ใช้ origin ตัวเอง; ไม่มีการรับปลายทางจาก input
- **Edge functions (ZOKY-135)**: `isFoodWebOrigin` = exact `Set.has` 2 ค่า, deny by default; `foodReturnOrigin` ไม่สะท้อน origin ที่ไม่อยู่ใน allowlist; auth/ownership/amount checks ไม่ถูกแตะ; geocode เพิ่ม 1 บรรทัด. **Backward compatible** กับเว็บปัจจุบัน (food origin ยังผ่าน, return URL กลับ food) → deploy ก่อนเว็บได้อย่างปลอดภัย
- **Service worker (ZOKY-136)**: cleanup worker เสิร์ฟเฉพาะ `food.wynos.online/sw.js` (rewrite ไม่ใช่ redirect), ไม่อ่าน payload, ไม่มี fetch handler, ไม่คุย Supabase, click เปิด URL คงที่; `sw.js` หลักแก้แค่ไอคอน
- **Auth allowlist (ZOKY-138)**: add-only, exact URLs, มี idempotency test
- **Regression Social/Merchant/Maps/Admin**: `food.css` (ใช้ร่วม Merchant/Maps) ไม่ถูกแก้ — สีใหม่อยู่ใน `food-app.css` scope `.fx-app`; Social เปลี่ยนแค่ปลายทาง legacy Food ใน `/auth/callback` และ `pushAppFor`; Merchant เปลี่ยนแค่ share URL → zoky; Maps ปุ่ม "สั่งอาหาร" → zoky และ geocode allowlist add-only; Admin (`admin/`, project Vercel แยก) ไม่มีไฟล์ถูกแก้และไม่มี reference ถึง `food.wynos.online`
- **Assets**: ไฟล์ใหม่ versioned `icons/zoky/*-v1`, ไม่ทับ `icons/food/*` → rollback ไอคอนได้

## Findings ตาม severity

CRITICAL: ไม่มี | HIGH (code): ไม่มี

### Release blockers (ไม่ใช่ defect ในโค้ด แต่ block go-live)

- **RB1 — Production freeze**: `wyn-158-production-deploy.yml` ต้อง `RELEASE_ALL_APPROVED` + run จาก `main` + environment `production` + acceptance **#1142–#1151 closed ครบ** — ตอนนี้ open ทั้ง 10 (เป็นงาน WYNOS Admin ไม่เกี่ยวกับ ZOKY). ZOKY จึง deploy ไม่ได้จนกว่า (ก) coordinated release ผ่านจริง หรือ (ข) Founder อนุมัติ freeze exception ที่บันทึกไว้ (= เปลี่ยน security/change-control policy, ต้องมี proposal + CTO review). **ห้ามปิด issue เพื่อให้ gate ผ่านโดยยังไม่ผ่าน acceptance จริง.** นอกจากนี้ deploy คือ deploy **ทั้ง `main`** — งานอื่นที่ merge หลัง production ล่าสุด (เช่น Food/Admin/Merchant PR #1125–#1138 ช่วง 2026-10-13 ถ้ายังไม่ขึ้น consumer web) จะขึ้นไปพร้อมกัน; DevOps ต้องเทียบ SHA ของ production deployment ปัจจุบันกับ `main` ก่อนขออนุมัติ
- **RB2 — `wynos-maps-geocode` deploy ผ่าน CI ไม่ได้**: `deploy-edge-functions.yml` ไม่มี option `wynos-maps-geocode` (มีแค่ `food-stripe-checkout`, `food-stripe-cancel` ฯลฯ). ถ้าไม่ deploy, การค้นหา/reverse ที่อยู่แบบ fallback จาก ZOKY จะ 403 (`invokePublicMapsGeocoder` คืน `null` → เงียบ แต่ฟังก์ชันหาย). ต้องเพิ่ม option ใน workflow (CI change เล็ก, ต้องได้รับอนุญาต) หรือ Founder deploy ด้วย CLI เองแล้วบันทึก

### MEDIUM

- **M1 — Redirect ของ `food.wynos.online` เปิดทันทีพร้อม deploy และ staging ตรวจส่วนที่เสี่ยงไม่ได้**: staging (`web-next-phase5-preview.yml`) อยู่บน `*.vercel.app` จึงทดสอบ host routing ของ zoky/food, Stripe **live** origin, การ match Auth redirect URL ของ zoky และ Push (staging ไม่มี Firebase) **ไม่ได้เลย** — รายการ "staging" ที่ QA ขอ (live-origin Stripe, Auth reset URL match, Android push cleanup) จริง ๆ ตรวจได้แค่บน production ที่ `zoky.wynos.online`. ถ้า deploy ครั้งเดียว ผู้ใช้ทุกคนถูกย้ายก่อนที่เราจะยืนยันว่า zoky ใช้งานได้. **CTO แนะนำ (ไม่ได้ implement)**: gate redirect ด้วย server-only env เช่น `ZOKY_LEGACY_FOOD_REDIRECT` (ค่าเริ่มต้น off = fail-safe), อ่านใน `proxy.ts` ตอน runtime:
  - off: `food.wynos.online` ทำงานแบบเดิมทุกอย่าง (root rewrite `/food`, `/login` `/signup*` aliases, `/s/:code` — คง host food ใน `next.config.ts` rewrite ไว้คู่กับ zoky, `/sw.js` ตัวจริง ไม่ใช่ cleanup worker); `zoky.wynos.online` เสิร์ฟ ZOKY เต็มรูปแบบ; `wynos.online/food*` → zoky ได้ทั้งสองโหมด
  - on: พฤติกรรมปัจจุบันของ branch (307 ทุก path + cleanup SW)
  - เพิ่ม proxy tests ทั้งสองโหมด; QA re-test; CTO re-review
  - ข้อแลกเปลี่ยน: Vercel ผูก env ต่อ deployment → การเปิด redirect = redeploy อีกครั้ง (ภายใต้ freeze = run `wyn-158` อีกรอบ; Founder อนุมัติล่วงหน้าเป็น "phase 2 หลัง smoke ผ่าน" ได้). ได้มาคือ (1) ตรวจ zoky บน production จริงโดยไม่กระทบผู้ใช้ food, (2) rollback เฉพาะ redirect = Vercel Instant Rollback ไป deployment phase 1 โดยไม่ต้องถอยแบรนด์. ทางเลือกที่ไม่ต้องแก้โค้ด: แยก commit redirect ไป merge ทีหลัง (deploy 2 ครั้งเท่ากัน แต่ยืดหยุ่นน้อยกว่า)
  - ถ้า Founder เลือก deploy ครั้งเดียว: เงื่อนไขขั้นต่ำคือ zoky ต้อง Valid Configuration + SSL บน Vercel ก่อน deploy, edge functions deploy แล้ว, Auth allowlist มี zoky แล้ว และพร้อม rollback ตาม M4
- **M2 — Merge เข้า `main` = แก้ Supabase Auth production ทันที**: `web-beta1-auth-password-policy.yml` job `apply` รันเมื่อ push เข้า `main` ที่แตะ `sync-auth-password-policy.sh` (และหลัง `WYN-158 Production Deploy` สำเร็จทุกครั้ง). การเปลี่ยนเป็นแบบเพิ่มอย่างเดียว ความเสี่ยงต่ำ และ**ควร**เกิดก่อน web deploy อยู่แล้ว แต่เป็น production config change ระหว่าง freeze → Founder ต้องอนุมัติ merge โดยรับรู้ว่าเป็นการเปลี่ยน Auth config นี้. ให้ attach domain `zoky.wynos.online` ใน Vercel **ก่อน** merge เพื่อไม่มีช่วงที่ redirect URL ของ subdomain ที่ยังไม่ถูก claim อยู่ใน allowlist. (pre-existing, ไม่ block: job `apply` ไม่มี `environment:` protection และ `workflow_dispatch` จาก branch ใดก็ apply ได้ — ส่ง DevOps ปรับภายหลัง)
- **M3 — Edge function deploy ไม่มี freeze gate (pre-existing)**: `deploy-edge-functions.yml` เป็น manual dispatch แต่ไม่มี `release_confirmation`, `environment: production` หรือ acceptance check และ `check_wynos_release_freeze.py` ไม่ครอบคลุม. ไม่ block branch นี้ แต่ต้องถือว่าการ dispatch 3 functions เป็น production change ที่ต้อง Founder Gate (บันทึก approval) และแนะนำ DevOps เพิ่ม environment protection ในงานแยก
- **M4 — แผน rollback ใน handoff ยังไม่ครอบคลุม host zoky**: Vercel Instant Rollback ไป build เก่า → `food.wynos.online` กลับมาใช้ได้ แต่ `zoky.wynos.online` จะเสิร์ฟ build เก่าที่ไม่รู้จัก host นี้ = **หน้า Social ที่ root**; ลิงก์/QR ที่ Merchant แชร์หลัง cutover, Stripe success/cancel ที่สร้างระหว่างนั้น และผู้ใช้ที่ bookmark zoky จะไปผิดที่. Runbook ต้องเพิ่ม: เมื่อ rollback ให้ตั้ง Vercel Domain redirect `zoky.wynos.online` → `food.wynos.online` (307) ทันที (ไม่ต้อง deploy) และห้ามถอด domain zoky ออก. นอกจากนี้ผลของ cleanup SW (unsubscribe push บน food origin) **ย้อนกลับไม่ได้** — หลัง rollback ผู้ใช้ที่ถูก cleanup ต้องเปิดแจ้งเตือนใหม่บน food

### LOW

- **L1 — ชื่อสินค้า Stripe เปลี่ยนเป็น `ZOKY #<order>`** (`food-stripe-checkout/index.ts`) แต่ handoff checklist ข้อ 5 และ "ยังไม่ได้ทำ" ข้อ 2 ยังเขียนว่าคงไว้จนตัดสิน Q10, และข้อความอนุมัติ ZOKY-135 ครอบคลุมแค่ origin + success/cancel URL. ทางเทคนิคปลอดภัย (ไม่มีโค้ดใด parse ชื่อสินค้า — ตรวจด้วย grep) และสอดคล้องกับ D1 (ลูกค้าเห็น ZOKY ตลอด flow). CTO แนะนำ **คง `ZOKY #`** แต่ต้องให้ Founder ยืนยัน (หรือสั่ง revert เป็น `WYNOS Food #`) และแก้ handoff ให้ตรง. หมายเหตุ: statement descriptor/บัญชี connected ไม่เปลี่ยน, test mode return URL default เป็น ZOKY
- **L2 — `docs/engineering/WEB_STAGING.md` ล้าสมัย**: ยังเขียนว่า merge = deploy production อัตโนมัติ (ไม่จริงหลัง freeze). แก้เป็นเอกสารแยก
  - Status: แก้แล้วบน branch นี้ (ระบุ `wyn-158` manual gated deploy)
- **L3 — ZOKY-136 residual risk**: push ที่ถึง worker เก่าก่อน browser ตรวจ update (~ถึง 24 ชม.) ยังแสดงเนื้อหาได้; sign-out บน ZOKY ฆ่า subscription ของ food ไม่ได้. การปิดแบบเต็มต้อง migration (origin column) หรือ PM/Founder ตัดสินเรื่อง revoke food tokens ตอน sign-out. ต้องให้ Founder รับความเสี่ยงนี้อย่างชัดเจน + มีในแผนสื่อสาร AC9
- **L4 — ผลกระทบผู้ใช้ช่วง cutover (ยอมรับได้ แต่ต้องสื่อสาร)**: login ที่ค้าง PKCE บน food จะล้มเหลว 1 ครั้ง; session/ตะกร้า/ร้านโปรดใน localStorage ไม่ตามมา; PWA ที่ติดตั้งจาก food จะเปิด ZOKY ในเบราว์เซอร์ ต้องติดตั้งใหม่
- **L5 — ZOKY-137 icon bevel ยังเปิด** (รอ master vector A1/Q3); โปสเตอร์ QR ใน Merchant ยังมีหัว "WYNOS Food" แต่ URL เป็น zoky (Q1/Q10) — ต้องให้ Founder ยอมรับว่าเปิดตัวได้ทั้งแบบนี้หรือรอ

## เงื่อนไขก่อน merge (Required)

- **C1** Founder ยืนยันชื่อสินค้า Stripe `ZOKY #…` (หรือสั่ง revert) และ AI Coding แก้ handoff ข้อ 5 / "ยังไม่ได้ทำ" ข้อ 2 ให้ตรง (L1)
  - Status: **resolved by Founder decision 2026-10-18** — คงชื่อสินค้า Stripe `ZOKY #<order>`; handoff ข้อ 5 / "ยังไม่ได้ทำ" ข้อ 2 แก้ให้ตรงแล้ว
- **C2** Founder ตัดสินเรื่อง gate redirect (M1): (ก) ทำ env flag แบบ 2 phase ตามที่แนะนำ → implement + QA re-test + CTO re-review ก่อน merge, หรือ (ข) deploy ครั้งเดียวโดยรับเงื่อนไขขั้นต่ำใน M1 อย่างชัดเจน
  - Status: **resolved by Founder decision 2026-10-18** — เลือก (ก) 2 phase; AI Coding implement flag `ZOKY_LEGACY_FOOD_REDIRECT` ใน `web/proxy.ts` (ค่าเริ่มต้น off) + proxy tests ทั้งสองโหมด + runbook phase 1/2 ใน handoff แล้ว → **รอ AI QA re-test + CTO re-review**
- **C3** Founder อนุมัติ merge โดยรับรู้ว่า merge = เพิ่ม redirect URLs ของ zoky ใน Supabase Auth production ทันที (M2) และทำหลัง attach domain zoky ใน Vercel แล้ว; PR ต้องผ่าน CI + staging preview (UI/brand) ตาม `WEB_STAGING.md`

ก่อน go-live (ไม่ block merge): RB1, RB2, runbook rollback ตาม M4, Founder รับความเสี่ยง L3–L5

## Go-live runbook (ตามลำดับ)

### (a) สิ่งที่ Founder ต้องทำใน dashboard

1. **Vercel** (ก่อน merge): Consumer Web project → Settings → Domains → เพิ่ม `zoky.wynos.online`; ยืนยันว่าเป็น project เดียวกับ secret `VERCEL_PROJECT_ID` ของ `wyn-158` (handoff อ้าง `prj_bzoZ…`); **คง** `food.wynos.online`; รอ Valid Configuration + SSL. ระหว่างนี้ zoky จะแสดง build ปัจจุบัน (หน้า Social) จนกว่าจะ deploy — ยอมรับได้ช่วงสั้น
2. **DNS**: ถ้า `wynos.online` ใช้ Vercel DNS ไม่ต้องทำ; ถ้าไม่ใช่ เพิ่ม `CNAME zoky →` ค่าที่ Vercel แสดง; ห้ามแตะ record `food`/`merchant`/`maps`/`admin`
3. **Supabase Auth** (หลัง merge): URL Configuration → ตรวจว่ามี 3 รายการ zoky (`/food/auth/callback`, `/auth/callback?next=%2Ffood`, `/reset-password?returnTo=%2Ffood%2Flogin`) และรายการ food ยังอยู่; Site URL คง `https://wynos.online`. ถ้า smoke รีเซ็ตรหัสจาก zoky ตกไปที่ Site URL ให้เพิ่ม `https://zoky.wynos.online/reset-password**`
4. **Google Cloud / Firebase**: OAuth client → ถ้า Authorized JavaScript origins มี `https://food.wynos.online` ให้เพิ่ม `https://zoky.wynos.online` (redirect URI ของ Supabase ไม่เปลี่ยน); browser API key ที่จำกัด HTTP referrer → เพิ่ม `zoky.wynos.online/*` (ไม่งั้น Push บน zoky ใช้ไม่ได้)
5. **Stripe**: ไม่ต้องลงทะเบียนโดเมน; ไม่มีงานยกเว้นตัดสิน C1
6. **เตรียม rollback**: รู้ตำแหน่ง Vercel → Deployments → Instant Rollback และ Domains → Redirect `zoky.wynos.online` → `food.wynos.online` (ใช้เมื่อ rollback เท่านั้น)

### (b) การอนุมัติที่ Founder ต้องให้ (บันทึกใน DECISIONS/APPROVALS)

1. C1 ชื่อสินค้า Stripe
2. C2 แนวทาง redirect (2 phase ด้วย flag หรือ deploy ครั้งเดียว)
3. ให้ push/เปิด PR และ C3 อนุมัติ merge (= Supabase Auth allowlist change)
4. RB2: เพิ่ม `wynos-maps-geocode` ใน `deploy-edge-functions.yml` (หรือ Founder deploy ด้วย CLI เอง)
5. RB1: เส้นทางปลด freeze — รอ coordinated release (acceptance #1142–#1151 ผ่านจริง) หรือ freeze exception ที่มี proposal; และรับรู้ว่าทุกอย่างบน `main` ขึ้นไปด้วย
6. Production deploy edge functions 3 ตัว (`food-stripe-checkout`, `food-stripe-cancel`, `wynos-maps-geocode`)
7. Production web deploy (`wyn-158`, `RELEASE_ALL_APPROVED` + reviewer approval ใน environment `production`); ถ้าเลือก 2 phase: อนุมัติ phase 2 (เปิด redirect) หลัง smoke phase 1 ผ่าน
8. ยอมรับความเสี่ยง L3–L5 และแผนสื่อสารผู้ใช้ (AC9)
9. หลังเฝ้าดู 1–2 สัปดาห์: ตัดสิน 307 → 308 (Q2)

### (c) ขั้นตอนของ agent / CI

1. AI Coding: แก้ handoff ตาม C1; (ถ้า C2 = flag) implement flag + tests → AI QA re-test → CTO re-review
2. DevOps (งานแยก): เพิ่ม `wynos-maps-geocode` ใน workflow; ภายหลังเสนอ environment protection ให้ `deploy-edge-functions.yml` และ job `apply` ของ Auth policy; แก้ `WEB_STAGING.md`
3. เปิด PR (หลังได้รับอนุญาต) → CI + `web-next-phase5-preview` เขียว; ตรวจ UI/แบรนด์/contrast/ไอคอนบน staging URL (host routing, live Stripe, Push ตรวจบน staging ไม่ได้)
4. หลัง Vercel domain พร้อม → merge ตามอนุมัติ → ยืนยัน job `apply` สำเร็จ และ status `wynos/auth-policy` = success
5. Deploy edge functions 3 ตัวผ่าน `deploy-edge-functions.yml` (**ก่อนเว็บ**) → ยืนยันว่าเว็บปัจจุบันบน `food.wynos.online` ยังจ่ายบัตร/ยกเลิก/ค้นหาที่อยู่ได้ (บัญชี developer)
6. DevOps เทียบ SHA production ปัจจุบันกับ `main` แล้วรายงาน delta ให้ Founder; เมื่อ freeze ปลดตาม RB1 → run `wyn-158` (ตัว workflow ตรวจ `wynos.online` routes, maps health, push-config ให้แล้ว)
7. Smoke บน production ทันทีหลัง deploy (บัญชี developer):
   - `zoky.wynos.online`: หน้าแรก title/theme ZOKY, login Google + อีเมล, สมัคร + ยืนยันอีเมล, รีเซ็ตรหัส, สั่ง + Stripe live success/cancel กลับ zoky, ยกเลิกออเดอร์บัตร, ค้นหาที่อยู่ (geocode), `/s/<code>`, `/?store=`, `/?order=`, `/?promo=`, link preview LINE, เปิด Push บน Android/iOS PWA, ติดตั้ง PWA
   - redirect (เมื่อเปิด): `food.wynos.online/*` และ `wynos.online/food*` → 307 path+query; `food.wynos.online/sw.js` = cleanup worker
   - regression: `merchant.wynos.online` (ออเดอร์, แชร์ร้าน = URL zoky), `wynos.online/maps` (ปุ่มสั่งอาหาร → zoky), Social `/`, `admin.wynos.online` เปิดได้
8. ถ้า 2 phase: ตั้ง env เปิด redirect → run `wyn-158` อีกครั้งตามอนุมัติ → smoke ข้อ redirect
9. ส่งแผนสื่อสาร (ล็อกอินใหม่, ติดตั้ง PWA ใหม่, เปิดแจ้งเตือนใหม่); เฝ้าดู 1–2 สัปดาห์: Vercel 4xx/5xx บน zoky/food, edge function `live_stripe_origin_required` 403, อัตรา Stripe success, จำนวน dead token ที่ถูกลบ; บันทึก deployment record

### Rollback

- เว็บ: Vercel Instant Rollback ไป deployment ก่อนหน้า (หรือ deployment phase 1 ถ้าเลือก 2 phase) **และ** ตั้ง Vercel Domain redirect `zoky.wynos.online` → `food.wynos.online` (M4); ถาวร = revert merge commit แล้ว deploy ตาม gate
- คงไว้ตลอดช่วงเปลี่ยนผ่าน: edge functions ที่รับทั้งสอง origin, Supabase redirect URLs ทั้งสองโดเมน, domain ทั้งสองใน Vercel — rollback จึงไม่ทำให้ login/จ่ายเงินพัง และไม่มีการเปลี่ยน database
- ย้อนไม่ได้: cleanup ของ service worker/push บน food origin (ผู้ใช้ต้องเปิดแจ้งเตือนใหม่)

## สิ่งที่ยังไม่ได้ตรวจ / ข้อจำกัด

ไม่ได้ทดสอบกับ Supabase/Stripe/Vercel/Google จริง, ไม่ได้รัน Deno และ browser E2E ในรอบ CTO (อ้างผล QA), ไม่ได้ตรวจ SHA ของ production deployment ปัจจุบัน, ไม่ได้ตรวจด้วยตาบนอุปกรณ์จริง (ไอคอน/splash/contrast). ไม่อ้างว่าไม่มี regression — หลักฐานคือผล test ข้างต้นและการ review diff
