# WYNOS Food / Merchant — ผลส่งมอบ Development increment

ตรวจวันที่ 2026-10-13 บน branch `feat/food-production-hardening` เริ่มจาก `cf2e2cf9` และปรับฐานเข้ากับ main `42a8f937` ซึ่งเพิ่ม Admin modules และ production release freeze; Food banner/featured-store changes รวมเข้ากับงานนี้แล้ว

**ผล: ส่วนที่พัฒนารอบนี้ผ่านการตรวจรวมใน local/synthetic environment ยังไม่พร้อมประกาศเปิด Production** ไม่อ่าน Production Secrets/credential files ไม่ใช้ฐานข้อมูลจริง ไม่ deploy ไม่เปลี่ยนโดเมนหรือ environment จริง และไม่เรียกเงินจริง/คืนเงินจริง/payout จริง

## 1. ระบบเดิมมีอะไรแล้ว

Next.js/React/TypeScript สำหรับ Food/Merchant/Social/Maps, Admin แยก app และ Supabase Auth/Postgres/RLS/RPC/Deno Edge Functions เป็น backend ร่วมกัน มีร้าน/เมนู/stock/options/upload, manual acceptance/preparation/delivery, ประวัติ 24 ชั่วโมง, campaigns/coupons, Stripe/slip, GP รายร้านและรายงานการเงิน, Realtime/Web Push อยู่แล้ว ดู [Gap Analysis](WYNOS-FOOD-MASTER-GAP-ANALYSIS.md) สำหรับ source references และข้อจำกัดแต่ละระบบ

## 2. ปัญหาที่พบ

- Checkout retry หลังคำตอบหายหรือ quote/flag เปลี่ยนอาจสร้างออเดอร์ใหม่; การตรวจ Stripe session เดิมล้มเหลวเคยเดินหน้าสร้าง session ใหม่
- Pending refund/หลักฐานคืน GP ที่ไม่ครบอาจแสดงว่าคืนสำเร็จ; DB write failure และ Webhook ที่มาผิดลำดับต้องแยกจากผลของ provider
- Refund confirmation ต้องตรวจบัญชีและ PaymentIntent ของธุรกรรมเดิม รวมถึงกรณีร้านเปลี่ยนบัญชีรับเงินและ refund event มาก่อน paid event
- Minimum options, Busy Mode, consent flow และ operational metrics ยังขาดส่วนเชื่อมต่อ; ค่าธรรมเนียม 15 บาทยังไม่มี accounting ownership ที่ระบุครบ

## 3. พัฒนาเพิ่ม

- Checkout v3: server pricing เดิม + idempotency/transaction lock/owner lookup, expected-total check และค่าธรรมเนียม 15 บาทบนยอดอาหารก่อนลดที่ต่ำกว่า 60 บาท
- State guard, strict rejection reason, preparation-time RPC และ optional acceptance deadline ที่ไม่มีงานยกเลิก paid order อัตโนมัติ
- Busy Mode เพิ่ม prep/pause โดย reuse เวลา/availability เดิม ไม่ล้างการปิดร้านด้วยเหตุผลอื่น
- Merchant เสนอให้ลด/ลบรายการและลูกค้ายืนยัน/ปฏิเสธได้ สถานะยืนยันเป็น `accepted_pending_execution` ไม่เปลี่ยน items/เงินอัตโนมัติ
- Options validator ใช้ร่วม Food/Merchant; recovery เมื่อ Realtime reconnect/online/กลับหน้า และรวมคำขอ reload ที่ซ้อนกัน
- Metrics จำนวนออเดอร์ อัตรารับ/ยกเลิก เวลาเตรียม และเมนูขายดี ใช้ date range ของหน้า Finance เดิม ไม่คิด GP/ยอดเงินซ้ำ
- Refund/Checkout/Webhook safety ตาม transaction identity และผลจริงของ provider; rider calculator เฉพาะสูตรในอนาคต ไม่เปิด Rider
- เพิ่ม regression scripts ใน `web/package.json` และ CI โดยไม่สร้าง deployment workflow

## 4. ไฟล์ที่แก้

รายการเต็มอยู่ใน changed-files ของ Draft PR และ [Gap Analysis](WYNOS-FOOD-MASTER-GAP-ANALYSIS.md). กลุ่มหลักคือ:

- `web/components/food/{wynos-food-developer-app,food-guest-browse,food-order-modification}.tsx`
- `web/components/merchant/{wynos-merchant-app,merchant-finance,merchant-busy-mode,merchant-order-modification,merchant-order-performance}.tsx`
- `web/lib/{food-customer,food-merchant,food-checkout-intent,food-option-rules,food-rider-pricing,order-recovery,order-modification,merchant-order-performance}.ts`
- Edge Functions `food-stripe-checkout`, `merchant-stripe-refund`, `stripe-webhook` และ refund helpers/tests
- Migrations 6 ไฟล์, SQL regression scripts, web tests, `web/package.json`, `.github/workflows/web-next-ci.yml` dictionary `web/lib/i18n/en.ts` และรายงาน 2 ไฟล์

## 5. Database

เตรียม additive migrations ตามลำดับ ยังไม่ apply บนฐานข้อมูลจริง:

1. `20261013045900_food_checkout_integrity.sql`: feature flags, checkout request keys, fee/pricing snapshots และ v3 RPCs
2. `20261013045901_food_option_minimum.sql`: minimum option validation ใน resolver เดิม
3. `20261013050000_food_order_operations.sql`: busy/fulfillment/deadline/reason/consent records และ guards
4. `20261013050100_food_stripe_event_integrity.sql`: monotonic settled identity และ refund-failure event processing
5. `20261013050101_food_stripe_historical_account.sql`: original account/PaymentIntent ownership และ out-of-order refund guard
6. `20261013050200_food_merchant_performance.sql`: read-only metrics RPC

ต้องยืนยัน legacy migration sequence โดยเฉพาะ WYN-213 permissions และ Stripe/GP dependencies ก่อนใช้บน isolated staging. CLI ยังไม่พร้อมขณะสร้างไฟล์ จึงใช้ชื่อ timestamp โดยตรงและทดสอบ SQL จริง ไม่อ้างว่า CLI สร้าง migration ให้

## 6. API

เพิ่ม `food_checkout_features`, `food_resolve_checkout_request`, `food_quote_order_v3`, `food_create_order_v3`, `food_order_operations_features`, `food_reject_order`, `food_adjust_preparation_time`, `merchant_set_food_busy_mode`, `merchant_food_acceptance_overdue`, `merchant_propose_food_order_modification`, `food_respond_order_modification`, `merchant_order_performance` และ service-only `food_record_stripe_refund_failure`

รักษา v1/v2 และ signature ของ `food_transition_order`/`food_apply_stripe_event`; ปรับ validation/guards ให้เข้มขึ้น. UI rejection fallback ไป legacy พร้อมเหตุผลเฉพาะเมื่อ additive RPC ไม่มี ไม่ fallback เมื่อ network/auth failure. Edge refund เพิ่มสถานะ reconciliation โดยไม่อ้างว่าผล provider สำเร็จเท่ากับ order/GP ledger สำเร็จแล้ว

## 7. Development ที่ทดสอบได้

หลัง apply dependencies/new migrations ในฐานข้อมูล development ที่ใช้ข้อมูลจำลอง สามารถเปิด flags ทีละตัวให้ developer ที่มีสิทธิ์ร้านจริงเพื่อทดสอบ v3 checkout, options, Busy Mode, proposal/consent และ metrics. ในรอบนี้ยืนยัน backend/client behavior ผ่าน local PostgreSQL/mocks/static render; ยังไม่ได้ยืนยัน signed-in browser → API → DB → Stripe flow ของฟีเจอร์ใหม่ครบวงจร

## 8. ฟีเจอร์ที่ยังปิด

`checkout_v3`, `small_order_fee`, `menu_min_select`, `busy_mode`, `order_modifications`, `acceptance_timeout_reporting`, `merchant_performance` default OFF/developer-only. `auto_accept`, `customer_pickup`, `wynos_rider` มีโครงสร้างสำรองแต่ไม่มี operational executor และไม่สามารถเปิด transaction path ด้วย flag เพียงอย่างเดียว

Order modification execution/replacement/repricing/refund/extra charge ยังไม่มี. Acceptance deadline เป็น metadata เท่านั้น ไม่มี SLA ที่เดาหรือ paid auto-cancellation. เมื่อใช้ developer-only flag ผ่าน service webhook ที่ไม่มี user identity จะยังไม่สร้าง acceptance deadline จนกว่าจะกำหนด rollout scope อย่างชัดเจน

## 9. ผลทดสอบจริง

| ตรวจ | ผล | ขอบเขต |
|---|---|---|
| `npm run typecheck` | PASS | web หลังรวมทุก module |
| `npm run lint` | PASS: 0 errors / 17 warnings เดิม | ไม่อ้างว่า warning-free |
| `npm run build` | PASS | clean environment ไม่มี Supabase/Stripe config หรือ `.env` จริง |
| `npm run test:food-hardening` | PASS 9 files | runtime client/helper/mocks และบาง static rendering |
| `npm run test:stripe` | PASS 5 files | actual mocked Checkout/refund handlers + source contracts |
| `npm run test:notifications` | PASS 9 files | recovery/history/notification regressions เดิม |
| `npm run test:i18n` | PASS 6 files | English coverage รวม 90 exact strings / 5 templates ใหม่ |
| Deno check Edge Functions ที่แก้ 3 ตัว | PASS | Deno 2.9.6 ไม่ start handler จริง |
| Deno checkout/refund helper tests | PASS 14 cases | ไม่เรียก provider |
| Deno webhook tests | PASS 6 cases | source contracts ไม่ใช่ signed HTTP E2E |
| Checkout integrity / Order operations / Merchant performance / Stripe core SQL suites | PASS | PostgreSQL 17.11 ข้อมูลจำลอง: gates, concurrency, rollback, roles, identity, events, consent |
| Existing options/stock/access/finance/GP/Admin finance/campaign/coupon/readiness/delivery storage SQL regressions | PASS | isolated fixture schemas; ไม่ใช่ deployment schema audit |
| Food/Merchant Chromium Android/Desktop | PASS 134 checks | source checks + browser fixtures ก่อน final Merchant rerun |
| Merchant final browser matrix | PASS 120 checks | Chromium Android/Desktop และ WebKit iPhone หลัง integration; มี actual touch/DOM cases |
| Food/Merchant หลังรวม main | PASS 134 checks | Chromium Desktop + WebKit iPhone; รักษา main banners/featured stores และงานนี้ |
| `python3 supabase/check_schema_ordering.py`, `git diff --check` | PASS | schema source ordering / whitespace |

คำสั่ง SQL ใช้ `PSQL=/tmp/wynos-local-psql bash supabase/tests/<suite>.sh` ชี้ Unix socket ของ PostgreSQL local ที่ไม่รับ TCP. แต่ละ suite สร้างและลบเฉพาะฐานข้อมูลจำลองของตัวเอง. New scripts ใช้ `PSQL` override หรือ CI PostgreSQL service ได้ ห้ามชี้ไป production

ไม่ได้ทดสอบ real iPhone/OS Push, provider sandbox,เงินจริง, signed-in complete E2E, load/capacity, backup restore หรือ remote preview. Hosted preview ใช้ production Supabase ตาม config จึงไม่ได้รันบน URL นั้น

## 10. ความเสี่ยงและขั้นก่อน Production

- ยังต้อง financial reconciliation สำหรับ async GP refunds, failed/unknown provider outcomes และ paid/refund events ที่ provider retry หมดช่วง; ledger เดิมยังไม่ใช่ double-entry ledger ครบทุก transaction
- ต้องออกแบบ provider adapter และ modification execution ตาม provider capability/approval ไม่เปลี่ยนยอดที่ลูกค้ายังไม่ยินยอม
- ต้องยืนยันเจ้าของรายได้/settlement/tax ของค่าธรรมเนียม 15 บาทก่อนเปิด flag โดยรักษาเกณฑ์ 60/15 และโปรโมชัน 100/40 ตามที่กำหนด
- Stripe Thailand/Connect configuration ของบัญชี WYNOS ยังไม่มี official account-specific confirmation; ไม่รับรอง marketplace payout readiness จาก source หรือเอกสารทั่วไป
- ต้องทดสอบ migrations กับ dependencies ทั้งชุดใน isolated staging, complete order/payment/refund/realtime flows, merchant isolation, financial reconciliation และ monitoring/rollback
- คงแท็บ Merchant 4 แท็บ, 24 ชั่วโมง/history, whole-row iPhone drag, vertical radio options และ Food home เดิม; Admin modules ใหม่ใน main มี RPC/editor ของบางความสามารถ แต่ยังไม่ใช่หลักฐานว่า catalog ทุกส่วนพร้อมหรือมี Production QA ครบ
- คง production release freeze/manual gates จาก main และส่งเป็น Draft PR เพื่อ review เท่านั้น ไม่เรียก deploy workflow หรือเปิดเงินจริง

GitHub CI รอบแรกพบ missing English coverage และ metrics negative-assertion output บน CI wrapper; แก้แล้วและ local rerun ผ่าน. ผล CI ทั้งชุดของ updated candidate ต้องอ่านจาก PR ไม่ใช้ผล local แทนคำว่า CI green.
