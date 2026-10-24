# ZOKY — Full-system QA & Security pass (2026-10-24)

ผู้ทดสอบ: AI QA & Security · โหมด: read-only ต่อ production (ไม่แตะ production, ไม่อ่าน secrets/env, ไม่ใช้ DB จริง, ไม่ push) · ใช้ข้อมูล synthetic เท่านั้น

## Feature
ZOKY ส่วนที่จะ ship รอบถัดไป:
- Web: `release/zoky-web-20261018` @ `eeeb5f5e` (worktree QA: `/home/user/wynteam-qafull`, detached) — ZOKY home, food list, storefront, basket/checkout แบบ PromptPay-only, order status, refund states, guest browse, merchant auto-refund UI
- Backend: `main` @ `f596e5f9` + PR #1237 `fix/zoky-refund-notice-dedupe` @ `195361e7` (worktree QA: `/home/user/wynteam-qamain`) — Stripe jobs/auto-refund migrations, stripe-webhook, merchant-stripe-refund, food-stripe-refund-worker, merchant-stripe-connect
- หมายเหตุ deploy: `food-stripe-checkout` / `food-stripe-cancel` ship จาก web SHA (release) ส่วน function อื่นและ SQL ship จาก main (`zoky-staging-e2e.yml`, `deploy-edge-functions.yml` มี guard กัน deploy 2 ตัวนี้จาก main)

## Environment
- Local เท่านั้น: Node 22.22.0, Next 16.3.5 (`next build` + `next start` ด้วย public env ปลอม `NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54399`), Deno 2.9.6, Postgres 16 local (ฐานข้อมูลชั่วคราวต่อ test; ลบทิ้งหลังรัน), Playwright 1.63 + Chromium 1194 (iPhone 13 profile, 320/375/414 px)
- Supabase API ใน browser ถูก mock ด้วย Playwright route (synthetic store/menu/order พร้อม XSS payload); ทุก request ออกนอกเครื่องถูก block; Stripe Checkout ถูก fulfill ด้วยหน้า mock
- ลบไฟล์ Playwright ชั่วคราวและหยุด dev server แล้ว; Postgres local เปิดอยู่ก่อนเริ่มงาน จึงคงสถานะเดิมไว้

## Test Cases / ผลรวม

| Suite | ผล |
|---|---|
| Web `node --test web/tests/*.test.mjs` (release) | 367 pass / 0 fail |
| Web `tsc --noEmit` | pass |
| Web `eslint` | 0 errors, 17 warnings (unused vars) |
| Web `next build` (public env ปลอม) | pass |
| Deno `deno test --allow-read=.` ทุก function — main+PR #1237 | 153 pass / 0 fail |
| Deno ทุก function — release tree (รวม food-stripe-checkout/cancel ที่ ship จริง) | 125 pass / 0 fail |
| `deno check` entrypoints (8 ตัวบน main, 3 ตัวบน release) | pass |
| `supabase/check_schema_ordering.py` | OK |
| SQL suites food/merchant/stripe/admin-food/security-definer/view/search_path/admin-permissions/push routing (41 suites) | 40 pass / 1 fail (L5: ข้อผิดพลาดของ harness ไม่ใช่ bug ของ product) |
| — `food_stripe_auto_refund_test.sh` (รวม PR #1237 dedupe regression) | 239 assertions pass |
| Playwright smoke (mobile/a11y/XSS/payment/refund) | 53 checks: 49 pass, 2 fail จริง (S4 = H1), 2 false positive จาก heuristic ของ test (ตรวจซ้ำด้วย screenshot แล้วผ่าน) |
| Flutter | ข้ามตามที่สั่ง |

## Passed (ไฮไลต์)
- **Price/amount tampering**: `food_create_order` คิดราคาจาก `food_menu_items` + options ฝั่ง server, quantity clamp 1–99, ≤50 lines, ไม่มี `insert/update` grant บน `food_orders` สำหรับ client; checkout ใช้ `food_orders.total` จาก DB และ GP quote ต้องตรงยอด
- **Cross-user order access**: `food-stripe-checkout`, `food-stripe-cancel`, `food-payment-qr`, `food-verify-slip` ตรวจ `buyer_id === user.id`; RLS `food_orders`/`food_order_items`/`food_order_events` = merchant ของ store หรือ buyer เท่านั้น
- **Store A → Store B**: `food_transition_order`, `food_set_payment_status`, `merchant_set_refund_status`, `merchant_retry_stripe_refund` ใช้ `merchant_has_store_role(order.store_id, …)`; `merchant-stripe-refund`/`merchant-stripe-connect` ตรวจ membership ของ `merchant_account_id` ของ store นั้น (fail closed)
- **PromptPay-only direct-API**: release `food-stripe-checkout` บังคับ PromptPay เมื่อ policy on (ไม่ส่ง method = promptpay, `card` = 422 `promptpay_only`, policy error อื่น = 503 ไม่เดา); DB trigger `food_orders_require_stripe_ready` ปฏิเสธ order ของร้านที่ไม่มี PromptPay; `food_orders_payment_guard` บล็อก slip/manual paid และการแก้สถานะ payment/refund ของ order Stripe จาก client
- **Refund abuse**: refund จำกัดเต็มจำนวน, idempotency key ต่อ job, ลูกค้ายกเลิกหลังจ่ายไม่ได้ (D3; ยืนยันทั้ง SQL และ UI S6), merchant retry ทำได้เฉพาะ job ที่ failed
- **Webhook**: HMAC-SHA256 + tolerance 300s + constant-time compare; worker ต้องมี Vault cron key ตรวจผ่าน RPC ที่ให้ service_role เท่านั้น
- **Open redirect**: success/cancel URL ใช้ allowlist ตรงตัว (`zoky.wynos.online`, `food.wynos.online`) มี test ครอบ `evil` suffix/subdomain/port/scheme; `?next=` ใช้ `isSafeReturnPath`; web ไม่เชื่อ `?stripe=success`; `?order=` จำกัดเป็น `^WF\d{4,9}$`
- **XSS**: ชื่อร้าน/ที่อยู่/หมวด/ชื่อเมนู/รายละเอียด/โน้ตลูกค้า ที่มี `<img onerror>`/`<script>` แสดงเป็นข้อความทุกหน้า (guest home, storefront, order sheet) ไม่ execute; `dangerouslySetInnerHTML` มีแค่ boot script คงที่และ JSON-LD ที่ escape `<`
- **Secrets in client bundle**: สแกน `.next/static` แล้วไม่พบ `sk_`/`rk_`/`whsec_`/`sb_secret_`/service-role/JWT
- **Guest**: RPC ที่ anon เรียกได้มีแค่ catalog/share/policy/payment-options แบบ boolean (จำกัด 100 store ids); `food_public_catalog` ไม่ส่งข้อมูลการเงินของร้าน
- **Mobile/a11y smoke**: 320/375/414 px ไม่มี horizontal overflow, ไม่มีปุ่ม/ลิงก์ที่ไม่มีชื่อ, ไม่มี img ที่ไม่มี alt, ไม่มี input ที่ไม่มี label, `lang="th"`, มี h1; หน้า PromptPay-only, ร้าน "ยังไม่เปิดรับ", refund pending/awaiting customer/failed/refunded แสดงข้อความถูกต้อง; ไม่มี page error

## Failed / Findings

จำนวนตาม severity (หลัง re-test H1 / ZOKY-157): **CRITICAL 0 · HIGH 0 open (H1 RESOLVED) · MEDIUM 3 · LOW 8**

### H1 (HIGH → RESOLVED โดย ZOKY-157, re-test 2026-10-24 PASS) — โหมด Stripe-only "fail-open" บน web + `food-payment-qr` ไม่เช็ก policy → ลูกค้าเห็น QR พร้อมเพย์ส่วนตัวของร้านและปุ่มแนบสลิป
- Files:
  - `web/components/food/wynos-food-developer-app.tsx:3460-3463` (อ่าน policy ครั้งเดียวตอนโหลดแอป), `:2950-2960` (เรียก `fetchFoodPromptPayQr` เมื่อ `!stripeOnly`), `:3076`, `:3155`
  - `web/lib/food-payment-policy.ts:46-56` — error ใดๆ (timeout/5xx/offline) → `false` (legacy)
  - `supabase/functions/food-payment-qr/index.ts:56-87` (main) — ไม่ตรวจ `food_payment_policy_public`, คืน QR ของ `food_stores.promptpay_id` + `payeeName`
- Reproduction (Playwright S4, synthetic): login → `?order=WF0001` (order pending) → ให้ `rpc/food_payment_policy_public` ตอบ 500 ครั้งเดียว → หน้าชำระเงินแสดง QR ร้าน, "พร้อมเพย์ QA STORE 0800000000", ข้อความ "โอนเงินเข้าบัญชีร้านโดยตรงและแนบสลิปเป็นช่องทางสำรอง" และปุ่ม "แนบสลิปการโอน"; `food-payment-qr` ถูกเรียกจริง. Screenshot: `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/zoky-order-pending-policy-error.png` (เทียบ policy ปกติ: `.../zoky-order-pending-policy-on.png`)
- Direct API ก็ทำได้: `POST /functions/v1/food-payment-qr {orderId}` ด้วย token ของผู้ซื้อ ได้ QR ร้านแม้ policy on
- Expected: เมื่อ policy on ห้ามมีทางจ่ายนอก Stripe ทั้ง UI และ API (Founder 2026-10-22/23: "ตัด QR แบบแนบสลิปออก เงินต้องจ่ายผ่าน Stripe ทุกคน")
- Actual: ถ้า RPC policy ล้มเหลวชั่วคราวแค่ครั้งเดียว web จะใช้ legacy ทั้ง session ลูกค้าสแกน QR ร้านแล้วจ่ายได้ แต่ DB ปฏิเสธสลิป (`stripe_only_payments`) → order ยกเลิกเองใน 10 นาที เงินอยู่ในบัญชีส่วนตัวของร้าน ระบบคืนเงินอัตโนมัติไม่ครอบคลุม (เสียเงิน/เกิดข้อพิพาท) และเปิดเผย PromptPay ID ของร้าน
- Suggested fix: (1) `food-payment-qr` (และควรรวม `food-verify-slip`) เรียก `food_payment_policy_public` แล้วคืน 410/422 `stripe_only_payments` เมื่อ policy on, ถ้าอ่าน policy ไม่ได้ให้ fail closed (ยกเว้น PGRST202/42883 เหมือน `stripeOnlyFromPolicyResult`) (2) web: แยก "ไม่มี RPC" (PGRST202 → legacy) ออกจาก error อื่น (→ ไม่แสดงช่องทางจ่าย + ปุ่มลองใหม่/retry policy) แทนการตก legacy (3) เพิ่ม regression test ทั้ง deno และ node/Playwright

#### H1 re-test (ZOKY-157) — PASS
- Code under test: web `feat/zoky-stripe-only-web` @ `a8f6405f` (fix `859d4040`: `fetchFoodPaymentPolicyState` = `stripe_only`/`legacy`/`unavailable`; `unavailable` fail closed + แสดงข้อความขัดข้องและปุ่ม "ลองใหม่"; อ่าน policy ใหม่เมื่อเปิด order) และ backend PR #1238 `fix/zoky-slip-qr-policy-gate` @ `8d4298a2` (`food-payment-qr` และ `food-verify-slip` ปฏิเสธเมื่อ policy on = 409 `stripe_only_payments`, policy อ่านไม่ได้ = 503 `payment_policy_unavailable`, NULL/false/PGRST202/42883 = legacy)
- Web: `node --test tests/*.test.mjs` 368 pass / 0 fail · `tsc --noEmit` pass · eslint ไฟล์ที่แก้ 0 error · `next build` (public env ปลอม) pass
- Deno (PR #1238): `deno test --allow-read=.` 157 pass / 0 fail · `deno check` food-payment-qr, food-verify-slip pass
- Handler-level (import `index.ts` จริง, mock Supabase HTTP local, synthetic):

| policy RPC | food-payment-qr | food-verify-slip |
|---|---|---|
| `true` / `[{stripe_only:true}]` | 409 `stripe_only_payments`, ไม่อ่าน `food_stores` | 409, ไม่ download slip/ไม่เรียก SlipOK/ไม่บันทึก verification |
| `false` | 200 QR (legacy เดิม) | 200 `manual_review` (legacy เดิม) |
| `null` | 200 QR (legacy เดิม) | 200 `manual_review` |
| PGRST202 (ยังไม่มี function) | 200 QR (legacy) | 200 `manual_review` |
| 500 `57014` / 503 ไม่มี code | 503 `payment_policy_unavailable`, ไม่อ่าน `food_stores` | 503, ไม่บันทึก verification |
| baseline main (ก่อนแก้) | 200 QR ทุกกรณี (ยืนยัน H1 เดิม) | — |

- Playwright S4 บน production build (iPhone 13, order pending): 9/9 PASS

| policy RPC | ผล |
|---|---|
| 500 ครั้งแรก แล้ว `true` | ไม่เรียก `food-payment-qr`, ไม่มีสลิป/QR ร้าน, แสดง PromptPay ผ่าน Stripe (อ่าน policy 2 ครั้ง) |
| 500 ครั้งแรก แล้ว `false` | กลับเป็น legacy ถูกต้องหลังอ่านซ้ำ |
| 500 ตลอด / network fail ตลอด | fail closed: ไม่เรียก QR ร้าน, ไม่มีสลิป, แสดง "ระบบชำระเงินขัดข้องชั่วคราว…" + "ลองใหม่" (กดแล้วอ่าน policy ซ้ำและยังปิดอยู่), PromptPay ผ่าน Stripe ยังใช้ได้, ไม่มี overflow |
| PGRST202 / `false` / `null` | legacy flow เดิมครบ (QR ร้าน + แนบสลิป) — ไม่ regression |
| `true` | Stripe PromptPay เท่านั้น |

- Screenshots: `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/h1-retest-*.png`
- เงื่อนไข: ต้อง deploy `food-payment-qr` + `food-verify-slip` จาก PR #1238 ก่อนหรือพร้อมเปิด policy และ ship web `a8f6405f` (ฝั่ง web อย่างเดียวไม่ปิด direct-API)
- ความเสี่ยงที่เหลือ (LOW): L7, L8 ด้านล่าง

### M1 (MEDIUM, pre-existing) — ข้อมูลการเงิน/ภาษีของทุกร้านอ่านได้โดยผู้ใช้ที่ login ทุกคน
- Files: `supabase/migrations_wynos_food_customer_access_gate_v2.sql:25-34` (row policy ไม่จำกัด column), `supabase/migrations_wynos_food_merchant_v1.sql:341` (`grant select, update on table public.food_stores to authenticated` ทั้งตาราง), `web/lib/food-customer.ts:484-490` (`select("*")` ของร้านทั้งหมด)
- Repro (static): บัญชี permanent ใดก็ได้ `GET /rest/v1/food_stores?select=name,bank_account_number,bank_account_name,promptpay_id,tax_id,tax_address,phone` → ได้ทุกร้านที่ published; web ของลูกค้าดาวน์โหลดข้อมูลเหล่านี้ทุกครั้งที่เปิดแอป
- Expected: ลูกค้าเห็นเฉพาะข้อมูลหน้าร้าน (Stripe-only แล้วไม่จำเป็นต้องเห็นบัญชีธนาคาร/PromptPay ของร้าน)
- Suggested fix: column-level grant (revoke select ของ `bank_*`, `promptpay_*`, `payment_qr_path`, `tax_*` จาก authenticated แล้วให้ merchant อ่านผ่าน RPC/view ที่ตรวจ role) หรือทำ public view; web เปลี่ยน `select("*")` เป็นรายการ column; ต้องผ่าน approved migration + ตรวจ merchant UI ที่อ่านจากตารางนี้

### M2 (MEDIUM) — `wynos-maps-geocode` บน main ไม่มี origin ZOKY แต่ workflow ยังให้ deploy จาก main ได้
- Files: `supabase/functions/wynos-maps-geocode/index.ts:22-30` (main ไม่มี `https://zoky.wynos.online`; release มีที่บรรทัด 26), `.github/workflows/deploy-edge-functions.yml:82-91` (guard บล็อกแค่ `food-stripe-checkout|food-stripe-cancel`)
- Repro: dispatch `deploy-edge-functions.yml` function=`wynos-maps-geocode` จาก main → production geocode ปฏิเสธ origin ZOKY → ปักหมุด/ค้นหาที่อยู่บน zoky.wynos.online พัง
- Suggested fix: นำบรรทัด origin ZOKY เข้า main (PR เล็ก) หรือขยาย guard ให้ครอบ `wynos-maps-geocode` จนกว่าจะ reconcile

### M3 (MEDIUM, operational) — ไม่มีหน้า Admin สำหรับ refund jobs
- `public.admin_food_refund_jobs` (`supabase/migrations/20261023100000_food_stripe_jobs_auto_refund.sql:1257-1313`) ไม่มีผู้เรียกใน `web/` หรือ `admin/` (grep แล้วไม่พบ)
- ผลกระทบ: job `needs_attention`/`failed`/duplicate payment ที่ต้องให้คนคืนเงินที่ Stripe มองเห็นได้ผ่าน SQL เท่านั้น ข้อความลูกค้า "ติดต่อทีม ZOKY" จึงไม่มีเครื่องมือรองรับ
- Suggested fix: ทำหน้า read-only ใน ZOKY Admin (food:view) หรือ runbook + alert ก่อนเปิดใช้ policy

### L1 (LOW) — order ยอด 0 หรือต่ำกว่า ฿10 สร้างได้แต่จ่ายไม่ได้
- `food_create_order` (`supabase/migrations_wynos_food_order_options_v1.sql:442`) ใช้ `greatest(...,0)`; release `food-stripe-checkout/index.ts` ตรวจแค่ `amountSatang <= 0` → 0 = 422, 1–999 satang จะโดน Stripe ปฏิเสธ (THB ขั้นต่ำ ฿10) แล้วแสดง error ทั่วไป
- Fix: เมื่อ policy on ให้ปฏิเสธตอนสร้าง order ถ้า total < 10 พร้อมข้อความชัดเจน

### L2 (LOW) — ข้อความแจ้งเตือนยกเลิกยังบอก "ร้านจะคืนเงินให้คุณ"
- `supabase/migrations/20261008113000_food_unpaid_payment_timeout.sql:188` (และ `migrations_wynos_food_order_push_share_stats_v1.sql:74`) — order Stripe คืนเงินอัตโนมัติแล้ว ควรใช้ข้อความ "ระบบจะคืนเงินอัตโนมัติ/ตรวจอีเมลจาก Stripe"

### L3 (LOW) — merchant retry ได้ไม่จำกัด และแต่ละรอบรีเซ็ต `failed_notified_at`
- `supabase/migrations/20261023100000_food_stripe_jobs_auto_refund.sql:1124-1187` — retry ซ้ำทำให้ลูกค้าได้แจ้งเตือน "คืนเงินไม่สำเร็จ" ซ้ำทุกรอบที่ล้มเหลว (มี backoff 8 attempts จำกัดความถี่) → แนะนำจำกัด `requeue_count` (เช่น ≤3) แล้วส่งให้ Admin

### L4 (LOW, a11y, pre-existing) — viewport ปิด pinch-zoom
- meta viewport `maximum-scale=1, user-scalable=no` (ตรวจได้ทุกหน้า ZOKY) ขัด WCAG 1.4.4 → พิจารณาเปิด zoom หรือขอ Founder ยอมรับ

### L5 (LOW, test harness) — `supabase/tests/wynos_stripe_payment_core_test.sh:148` fail ในเครื่อง
- `FAIL: account api version` เกิดทั้งบน release และ main เพราะ role `service_role` ใน Postgres local ไม่มี `BYPASSRLS` (บน Supabase มี) → query ผ่าน RLS ได้ 0 แถว ไม่ใช่ bug ของ product; แก้ test ให้ `create role service_role bypassrls` หรือ `alter role`

### L7 (LOW, จาก fix ZOKY-157) — `food-verify-slip` ปฏิเสธสลิป legacy ที่ค้างอยู่ก่อน cut-over
- DB guard ยังยอมให้ปิด order สลิปที่ `submitted` ก่อน cut-over แต่ function ตอบ 409 เมื่อ policy on → order เหล่านั้นไม่ได้ตรวจอัตโนมัติ ร้านต้องยืนยันเอง (`food_set_payment_status` ยังทำได้) — ยอมรับได้ถ้าแจ้งร้าน/ทำ runbook

### L8 (LOW, residual) — PGRST202 ถูกตีความเป็น legacy ทั้ง web และ server
- ถ้า PostgREST schema cache ตอบ PGRST202 ชั่วคราวหลัง migration ทั้งสองฝั่งจะกลับเป็น legacy; DB guard ยังบล็อกสลิป/manual paid แต่ QR ร้านจะแสดงได้ → หลัง activate policy แล้วพิจารณาให้ PGRST202 fail closed

### L6 (LOW, process) — โค้ด drift ระหว่าง main กับ production
- `food-stripe-checkout`/`food-stripe-cancel`/`wynos-maps-geocode` บน main ต่างจากเวอร์ชัน release ที่ ship จริง (มี guard แล้วสำหรับ 2 ตัวแรก) → หลัง release ควร merge กลับ main เพื่อไม่ให้ test/รีวิวบน main ตรวจโค้ดที่ไม่ได้รันจริง

## Severity
CRITICAL 0 · HIGH 0 open (H1 resolved, re-test PASS) · MEDIUM 3 (M1–M3) · LOW 8 (L1–L8)

## Security Findings
- H1: bypass นโยบาย PromptPay-only ผ่าน `food-payment-qr` + web fail-open — RESOLVED (ZOKY-157, web `a8f6405f` + PR #1238 `8d4298a2`)
- M1: ข้อมูลบัญชีธนาคาร/PromptPay/เลขภาษีของร้านทุกร้านอ่านได้โดยผู้ใช้ทุกคนที่ login (privacy/PDPA)
- ไม่พบ: cross-user order access, cross-store merchant access, price tampering, secret ใน bundle, XSS, open redirect, การแก้สถานะ payment/refund ของ order Stripe จาก client

## สิ่งที่ยังไม่ได้ทดสอบ (ข้อจำกัด)
- Stripe test-mode จริง (Checkout/PromptPay/refund/webhook end-to-end) — ไม่มี credentials ตามกติกา; staging E2E ยังติด blocker
- RLS แบบ end-to-end บน schema food ครบชุด: repo ไม่มีวิธี build schema food ทั้งหมด (`schema.sql` ไม่รวม food; SQL tests ใช้ stub) → authz/RLS ตรวจด้วย static review + stub-based SQL tests
- Merchant web และ ZOKY Admin ใน browser (มีแค่ unit/source tests), Flutter, WebKit/iOS Safari จริง, screen reader, performance/Lighthouse
- Rate limit ตรวจแบบ static (5 orders/10 นาที, 3 pending/store, test-notification 3 วินาที) ไม่ได้ load test

## Recommendation
- H1 แก้แล้ว: merge PR #1238 และ deploy `food-payment-qr`/`food-verify-slip` ก่อนหรือพร้อมเปิด policy, ship web `a8f6405f`; แก้ M2 (PR เล็ก) ก่อน deploy edge ครั้งถัดไป; วางแผน M1 เป็น migration ที่ขออนุมัติแยก; M3 ก่อนเปิด policy ใน production
- MEDIUM/LOW ที่เหลือไม่ block release ตาม Release Gate (ไม่มี CRITICAL, ไม่มี HIGH ค้าง) แต่ควรติดตามเป็น task แยก

## Final Status
**PASS** (re-test 2026-10-24 หลัง ZOKY-157; รอบแรก FAIL จาก H1) — มีเงื่อนไข deploy PR #1238 พร้อม/ก่อน web `a8f6405f` และก่อนเปิด policy
