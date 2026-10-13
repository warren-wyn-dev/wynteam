# WYNOS Food / Merchant — Master Development Gap Analysis

วันที่ตรวจ: 2026-10-13 · baseline ที่เริ่มตรวจ: `cf2e2cf9` · สถานะ: **Development increment ผ่านการตรวจรวม; ยังไม่ใช่ Production sign-off**

รายงานนี้แยกสิ่งที่พบใน source, สิ่งที่พัฒนาใน branch และสิ่งที่ทดสอบจริง ไม่ถือว่ามีไฟล์ migration เท่ากับ migration ถูกใช้บนระบบจริง ไม่ถือว่า source-contract test เท่ากับ flow ผ่าน browser, API และฐานข้อมูลครบวงจร

## 1. ขอบเขตและหลักฐาน

- ตรวจ checkout จริงของ `warren-wyn-dev/wynteam` ด้วย `git status`, source และ tests ที่อยู่ใน `web/`, `admin/`, `supabase/`, `.github/`, `.wyn/` และ `docs/`
- checkout เป็น sparse checkout; `app/pubspec.yaml` มีใน Git index แต่ Flutter source ไม่ได้อยู่ใน filesystem รอบนี้ นโยบาย [VERSION_CONTROL.md](../../.wyn/company/VERSION_CONTROL.md) พัก native/Flutter อยู่ จึงไม่แก้หรือทดสอบแพลตฟอร์มนั้น
- ไม่อ่าน `.env*`, credential files, Production Secrets หรือค่าของ API keys ไม่ dump environment ไม่เรียกฐานข้อมูลจริง ไม่เรียก Stripe account API และไม่ deploy
- ตรวจชื่อ environment variables จาก application source/workflow เท่านั้น
- ใช้ Master Prompt และข้อห้ามของ Founder เป็นขอบเขตของงาน การอนุญาตให้พัฒนาต่อไม่ถูกใช้เป็นการเปิด Payment/Payout/Rider จริงหรือข้าม release gate

## 2. Architecture ที่พบจากโค้ด

| ระบบ | โครงสร้างที่พบ | ขอบเขตข้อมูลและการเชื่อมต่อ |
|---|---|---|
| `food.wynos.online` | Next.js App Router / React / TypeScript ใน `web/app/food`, `web/components/food` | `web/proxy.ts` rewrite `/` ไป `/food`; customer library เรียก Supabase RPC/Edge Functions; browser Auth ใช้ configuration ที่มีอยู่ |
| `merchant.wynos.online` | Next.js app เดียวกับ Food ใน `web/app/merchant`, `web/components/merchant` | root rewrite ไป `/merchant`; client ใช้ `wynos-merchant-auth-v1`; สิทธิ์ร้านผ่าน memberships/RLS/RPC ไม่ใช้แค่ตัวกรองหน้าจอ |
| `admin.wynos.online` | Next.js app แยกใน `admin/` | Server Components/Actions และ SSR Supabase; `admin/lib/auth.ts` ตรวจ role และ per-system permissions ฝั่ง server; Food/Merchant/Maps มี RPC ที่ตรวจสิทธิ์ซ้ำ |
| `maps.wynos.online` | host redirect ไป `https://wynos.online/maps` | หน้า Maps อยู่ใน `web/`; Food ใช้ place/delivery/service-area RPC และ Edge geocoder เดิม ไม่มีบริการ Maps ใหม่ในงานนี้ |
| `wynos.online` | Social/account surfaces ใน `web/` | shared Supabase configuration แต่ข้าม origin ไม่เท่ากับมี session ร่วมอัตโนมัติ; browser account registry/PKCE กับ Merchant client ต้องรักษาการแยก session เดิม |
| Backend | Supabase Postgres + RLS + SQL RPC + Deno Edge Functions | การคิดราคา/รับออเดอร์ใช้ RPC; Stripe, slip verification, push และ timeout ใช้ Edge Functions ที่มีอยู่ |

หลักฐาน: [web/package.json](../../web/package.json), [admin/package.json](../../admin/package.json), [web/proxy.ts](../../web/proxy.ts), [browser.ts](../../web/lib/supabase/browser.ts), [merchant-browser.ts](../../web/lib/supabase/merchant-browser.ts), [admin/lib/auth.ts](../../admin/lib/auth.ts), [food-customer.ts](../../web/lib/food-customer.ts), [food-merchant.ts](../../web/lib/food-merchant.ts)

Dependency versions จาก manifests: `web` ประกาศ Next `^16.3.5`, React `19.2.8`, Supabase JS `^2.112.3`, Supabase SSR `^0.12.4`; `admin` ประกาศ Next `16.3.2`, React `19.2.8` ไม่เปลี่ยน framework หรือเพิ่ม dependency ในรอบนี้

ลำดับการปรับปรุง: shared SQL contracts ก่อน → Edge Functions ที่ใช้ contracts → Food/Merchant data libraries → component ที่เกี่ยวข้อง → Admin ที่จำเป็น → offline integration/regression → staging verification บนระบบที่แยกฐานข้อมูลจริง → การอนุมัติ Production

## 3. ฟังก์ชันเดิมที่มีอยู่แล้วและควรใช้ต่อ

| ส่วน | สิ่งที่พบและหลักฐาน | ข้อจำกัดที่ต้องตรวจเพิ่ม |
|---|---|---|
| ร้านค้า | เวลาเปิด-ปิดแบบโครงสร้าง, วันหยุด, ปิดชั่วคราว, readiness/publish guard, ตำแหน่งร้าน/รับอาหาร และ suspend; `migrations_wynos_merchant_production_readiness_v1.sql`, `food-store-availability.ts` | ความถูกต้องของค่าเวลาร้านจริงและ clock/device ต้องตรวจใน staging |
| เมนู | หมวดหมู่, options JSON, ราคาตัวเลือกจาก server, required/max-select, sold-out/stock, image storage และ EXIF removal; `migrations_wynos_food_order_options_v1.sql`, `migrations_wynos_food_customer_stock_v1.sql`, `food-merchant.ts` | ก่อนรอบนี้ min-select มากกว่า 1 ยังไม่ครบ; upload lifecycle/iPhone whole-row drag ต้อง browser QA |
| Orders | manual accept, ETA, ready, delivery proof, cancel/refund obligation, order events; `migrations_wynos_merchant_core_completion_v1.sql` | ต้องป้องกัน direct writes ที่ข้าม state machine และทดสอบ race กับ payment |
| Merchant permissions | WYN-213 `migrations_wynos_merchant_access_hardening_v1.sql` แทน historical helper ที่เคยมี developer bypass ด้วย actual memberships และ mapped legacy staff roles | ต้องยืนยัน migration ordering/definition บน staging; synthetic new-ops role stub ไม่รับรอง hardened helper ทั้งชุด |
| Merchant tabs | ใหม่ / กำลังเตรียม / จัดส่ง / เสร็จแล้ว; `wynos-merchant-app.tsx` | คง vocabulary/UI เดิม; ไม่ใช้แท็บเพิ่มเพื่อแทนสถานะ backend |
| History | เสร็จแล้วใช้ 24 ชั่วโมงจาก delivered/cancelled timestamp; หน้าประวัติแยก query ร้านและ pagination; `isRecentCompletedOrder`, `merchant-order-history.tsx` | เป็นการกรองการแสดงผล ไม่ลบข้อมูล; live data/จำนวนมากยังไม่ทดสอบรอบนี้ |
| Checkout | `food_quote_order` / `food_quote_order_v2`, create/scheduled variants, server menu validation, campaign snapshots, rate limit | rate limit ไม่ใช่ idempotency; RPC เดิมต้องอยู่เพื่อ compatibility |
| Promotions | best-campaign selection, fixed/percent/item/delivery conditions, platform/store funding, coupon/redemption/quotas; `migrations_wynos_merchant_campaign_center_v1.sql`, `20261008161000_food_admin_coupons.sql` | ต้องทดสอบ concurrency/eligibility ผ่าน SQL ไม่ใช่ source regex อย่างเดียว |
| ลูกค้าใหม่ | migration `20261009230000_food_first_order_100_40.sql`: ค่าอาหารขั้นต่ำ 100 ลด 40 ร้านรับผิดชอบทั้งหมด; กติกา anti-reuse ใช้ buyer-global eligibility และ locks จาก migration ก่อนหน้า | docs rollout เก่าบางไฟล์ยังกล่าว 120/20; source ปัจจุบัน 100/40 เป็นหลัก ต้องอัปเดต runbook ก่อน release |
| Payment | Stripe Checkout direct connected-account charge, manual bank/slip path, server-side verification, webhooks signature, event dedup | source ไม่พิสูจน์ provider readiness ในประเทศไทยหรือการตั้งค่า endpoint จริง |
| Finance | per-store GP history/order snapshot, application fee, merchant finance, platform settlement, Stripe payout ledger; `20261011140000_merchant_gp_v1.sql`, `20261011140100_merchant_gp_finance_lines.sql` | ไม่ใช่ ledger แบบ double-entry ครบทุก transaction; settlement/reconciliation correctness ต้องยืนยันเพิ่มเติม |
| GP เดิม | migration อ้างการตัดสินใจ Founder 2026-10-11: ถ้าไม่มี rate row เป็น 0%; base เป็นอาหารหลังส่วนลดที่ร้านออก ไม่รวม delivery; super admin ตั้งอัตรา | รักษา behavior นี้ ไม่สร้างอัตรา GP ใหม่หรือใช้ 0% เพื่อสมมติ readiness ของร้าน |
| Delivery | merchant delivery, pinned location/radius/fee calculation, proof และ dropoff/direct | ไม่มี operational rider service ที่ทดสอบได้; ไม่เปิด Rider ในรอบนี้ |
| Notifications | Postgres notifications, Supabase Realtime, Web Push/service worker, merchant reminders | push ไม่รับประกัน delivery; ต้อง reload authoritative state เมื่อ reconnect/กลับหน้า |
| Admin | เมนู Food/Merchant เดิมมี orders, ร้าน, approve/suspend, coupon/campaign, GP/finance/audit | financial permissions/refund support และ AI Secretary action approval ต้องตรวจเพิ่มก่อนขยาย |

## 4. Gap Analysis และความเสี่ยง

| ความสำคัญ | ช่องว่าง/ปัญหาที่ตรวจพบ | แนวทางในรอบนี้ / งานต่อ |
|---|---|---|
| HIGH | checkout retry/double tap ไม่มี request key ที่ server รับรองใน RPC เดิม | เพิ่ม v3 RPC + request-key storage/unique key/transaction lock โดย RPC เก่าไม่ถูกลบ; default feature OFF |
| HIGH | ข้อกำหนดค่าอาหารก่อนลดต่ำกว่า 60 ต้องมี fee 15 ยังไม่ครบใน legacy pricing | เพิ่ม fee calculation/snapshot ใน v3; ไม่คิดจากยอดหลังลดหรือรวม delivery; default OFF |
| HIGH | ผู้รับค่าธรรมเนียม 15 บาทและ settlement/tax treatment ยังไม่ระบุ | ยังไม่เปิด `small_order_fee`; ต้องยืนยันเจ้าของรายได้และปรับ finance/receipt ก่อนเปิดจริง |
| HIGH (แก้ใน branch) | refund request 2xx/pending เคยถูกบันทึก GP ว่าคืนเต็มแล้ว | edge handler ตรวจ customer status และ fee evidence แยก; synthetic handler/helper tests ผ่าน; provider sandbox และ async reconciliation ยังต้องทำ |
| HIGH (แก้ใน branch) | refund handler เคยไม่ตรวจ DB write error และเขียน pending ทับ webhook ที่ refunded | conditional writes และ reconciliation flags ผ่าน synthetic tests; provider response ไม่ถูกย้อนให้กลายเป็น failed เพราะ local write error |
| HIGH (แก้ใน branch) | `refund.failed` ถูก normalize เป็น `noop` ใน webhook เดิม ทำให้ order pending ค้าง | เพิ่ม service-only atomic refund-failure RPC พร้อม ledger account/payment/refund ownership และ event dedup ใน `20261013050100_food_stripe_event_integrity.sql`; disposable SQL suite ผ่าน |
| HIGH (แก้ใน branch) | late failed/paid webhook ทำให้ ledger state หรือ settled transaction identity ถอยได้ | เพิ่ม monotonic ledger/order identity guards; SQL regression ตรวจทั้ง status และ payment-intent/session identity; ต้องยืนยัน runtime webhook รอบสุดท้าย |
| HIGH (แก้ใน branch) | lost response + re-quote/promo eligibility หรือ flag toggle ทำให้ clientออก request key ใหม่ได้ | retain unresolved key/version และ owner-scoped lookup ที่ใช้ create lock เดียวกัน; client regression/SQL lookup own-user/cross-user/flag-OFF ผ่าน; ไม่ถือว่าครอบคลุม ambiguous legacy request |
| HIGH (แก้ใน branch) | client consent status เคยคาด `accepted_pending_execution` แต่ SQL ใช้ `consented_not_applied` | SQL/client ใช้ canonical `accepted_pending_execution` ตรงกัน; final SQL ops suite ผ่าน; consent ยังคงไม่ execute การเปลี่ยนเงิน/items |
| HIGH (แก้ใน branch) | transient failure ตอนตรวจ Checkout เดิมเคยออก session ใหม่ได้ ทั้งที่ session เดิมอาจยังชำระได้ | edge fail closed 503 ไม่ POST/เขียน ledger เมื่อ outcome ไม่ชัด; ต่อ attempt เฉพาะ expired+unpaid ที่ยืนยันแล้ว; actual-handler mocks 7 tests ผ่าน |
| HIGH | การยืนยันแก้ order/ยอดเงินจริงไม่มี consent + financial reconciliation workflow ที่ครบ | เพิ่ม proposal/response storage ที่ไม่ apply เงิน/items; price-changing/replacement execution ยังปิด |
| MEDIUM | required/max options มีแล้ว แต่ min-select มากกว่า 1 และ recovery behavior ยังขาด | normalize/validate rules ร่วมและ SQL resolver; coalesced refresh เมื่อ reconnect/online/visible |
| MEDIUM | merchant acceptance timeout กับ unpaid payment timeout เป็นคนละเหตุการณ์ | เก็บ optional acceptance metadata/reporting; ไม่กำหนด duration และไม่ยกเลิก paid order อัตโนมัติ |
| MEDIUM | auto-accept, busy-mode และ fulfillment extension ยังไม่ครบ | เพิ่มโครงสร้าง default OFF; executor/UX/role/metrics ต้อง incremental ต่อ |
| MEDIUM (เพิ่มใน branch) | รายงาน average prep, acceptance/cancel rate และ popular menus ยังไม่ครบ | เพิ่ม read-only operational report และ role/flag tests; เงิน/GP/net ใช้ finance aggregation เดิม; settlement/provider correctness ยังต้องทดสอบแยก |
| MEDIUM | ไม่มีหลักฐาน capacity/load/reconnect/device QA ครบของระบบที่จะเปิดใช้ | ต้องทำ staging performance/device/cross-store tests ด้วยข้อมูลจำลอง |

severity นี้ใช้ประเมิน release impact จาก source และ synthetic tests ไม่อ้างว่ามี exploit เกิดขึ้นใน Production

## 5. Incremental implementation ใน branch

### Checkout integrity

- [20261013045900_food_checkout_integrity.sql](../../supabase/migrations/20261013045900_food_checkout_integrity.sql): additive `food_development_features`, `food_checkout_requests`, `small_order_fee`, `pricing_rule_version`, v3 quote/create RPC, request-payload conflict detection และ transaction locks
- [food-checkout-intent.ts](../../web/lib/food-checkout-intent.ts): เก็บ UUID + fingerprint แยก user เท่านั้น ไม่เก็บ address/contact/cart ใน persistence ของ intent
- unresolved intent คง UUID/version เดิมแม้ quote/cart/flag เปลี่ยน; authenticated lookup คืนเฉพาะ order ของ caller ก่อน create เพื่อ recover lost response โดยไม่ออก order ใหม่
- Food data layer/component แสดงและใช้ backend quote เมื่อ flag อนุญาต; ไม่สร้าง pricing copy ใน Merchant/Admin
- ใช้ promo resolver เดิมและรักษา best-campaign behavior ไม่เปิด stacking rule ใหม่

### Orders / Merchant operations

- [20261013050000_food_order_operations.sql](../../supabase/migrations/20261013050000_food_order_operations.sql): state transition guard, explicit rejection RPC, busy-mode/optional acceptance metadata, fulfillment snapshot และ consent proposal tables/RPCs
- default merchant delivery; pickup/rider reservation ถูก guard ไม่ให้ใช้ path ที่ยังไม่ implement
- proposal รองรับ quantity reduction/removal และ customer accept/reject; accepted consent ไม่เท่ากับ items/total เปลี่ยนแล้ว ไม่สร้าง financial transaction ใหม่
- auto-accept มีโครงสร้างแต่ไม่มี executor; acceptance overdue report ไม่ auto-cancel paid order
- Merchant cancellation UI เรียก `rejectFoodOrder` โดยต้องมีเหตุผล; fallback ไป legacy transition เฉพาะ missing-RPC error เพื่อ rollout compatibility ไม่ fallback เมื่อ permission/server error

### Menu options / recovery

- [food-option-rules.ts](../../web/lib/food-option-rules.ts): normalizer และ minimum/maximum/required validation ใช้ร่วม Food/Merchant
- [order-recovery.ts](../../web/lib/order-recovery.ts): reload เมื่อ reconnect/online/กลับหน้า พร้อม coalescing, ไม่รัน refresh ซ้อนและ cleanup เมื่อออกหน้า
- คง Food home/search/banner/filter/store list เดิม ไม่เพิ่ม category icon row; คง Merchant tabs และ iPhone whole-row drag; ต้องตรวจ UI ด้วย browser ต่อ
- [merchant-busy-mode.tsx](../../web/components/merchant/merchant-busy-mode.tsx) เพิ่ม UI off/prep/pause เฉพาะ flag และ manage-store permission; ใช้ค่าช่วง prep/เวลา pause ที่ผู้ใช้กรอกและยืนยัน ไม่มีเวลา default ที่เดาเอง
- [food-order-modification.tsx](../../web/components/food/food-order-modification.tsx), [merchant-order-modification.tsx](../../web/components/merchant/merchant-order-modification.tsx) เพิ่ม proposal/consent UI; SQL/client status contract align แล้ว ยังต้อง integrated regression หลัง SQL ขั้นสุดท้าย

### Merchant operational report

- [20261013050200_food_merchant_performance.sql](../../supabase/migrations/20261013050200_food_merchant_performance.sql) เพิ่ม `merchant_order_performance`: order/completed/cancel counts, average prep พร้อม sample count, acceptance rate, merchant-cancel rate และ top menus
- [merchant-order-performance.tsx](../../web/components/merchant/merchant-order-performance.tsx) อยู่ใน Merchant Finance และใช้ date range เดียวกัน; ไม่เพิ่ม primary menu หรือสร้าง logic เงินซ้ำ
- cohort เป็น order-created date ตาม Bangkok; acceptance denominator ไม่นับ unpaid ที่ยังไม่ส่ง slip; top menus นับ delivered+paid เท่านั้น; historical names ใช้ snapshot
- cancellation attribution ใช้ current active memberships และ event actor ที่ไม่ใช่ buyer ไม่ใช่ historical role snapshot; unknown/no samples แสดงค่าที่ไม่ทราบ ไม่สร้างสถิติปลอม
- backend require actual manager/legacy owner membership เพิ่มจาก canonical role helper จึงไม่พึ่ง historical developer bypass; default feature OFF

### Refund safety

- [merchant-stripe-refund/index.ts](../../supabase/functions/merchant-stripe-refund/index.ts): ใช้ Stripe idempotency key เดิม; pending/requires_action ไม่ถือว่าคืนสำเร็จ; failed/canceled ไม่ตอบ success
- network timeout/unknown response ไม่เขียน financial failure โดยเดา เพราะ provider อาจรับคำขอไปแล้ว
- conditional order write ไม่ถอย `refunded`; DB persistence ที่ไม่สำเร็จตอบ `orderRecordPending` เพื่อ reconciliation
- GP reversal ต้องมี matching platform application-fee object กับ charged account/charge/THB/amount/full refunded amount; partial/unknown/pending proof ตอบ `gpRecordPending` แทนลงยอดว่าคืนแล้ว
- GET charge/application-fee เป็นการอ่านเพื่อยืนยันผล ไม่เปิด transaction/payout ใหม่; รอบนี้ provider calls ถูกจำลองทั้งหมด
- ยังต้องมี async GP refund reconciliation สำหรับ refund ที่สำเร็จหลัง API ตอบ pending และ failed-refund retry policy โดยไม่ใช้ key ใหม่เพื่อหลบ idempotency เดิม
- [20261013050100_food_stripe_event_integrity.sql](../../supabase/migrations/20261013050100_food_stripe_event_integrity.sql) เพิ่ม webhook refund-failure RPC และ monotonic financial state/settled identity guards
- [20261013050101_food_stripe_historical_account.sql](../../supabase/migrations/20261013050101_food_stripe_historical_account.sql) pin settled events กับ original ledger account; source/SQL test ครอบคลุม active-account remap แล้ว refund กลับบัญชีเดิมโดยไม่ปะปนบัญชีใหม่
- refund confirmation ต้อง match nonnull original PaymentIntent; legacy order ที่ไม่มี settled ledger ใช้ canonical order PaymentIntent ที่ทราบได้เท่านั้น ถ้า identity ไม่ชัดต้อง reconcile แทนเดา
- refund event ที่มาก่อน paid event ถูก reject/rollback ให้ webhook ตอบ 500 และ provider retry ภายหลัง ไม่สร้าง refunded ledger ขณะที่ order pending; ยังต้องมี monitoring/reconciliation เมื่อ paid event ไม่มาหรือ provider หมดช่วง retry
- [food-stripe-checkout/index.ts](../../supabase/functions/food-stripe-checkout/index.ts) ไม่ออก Checkout ใหม่เมื่ออ่าน ledger/ตรวจ session เดิมไม่สำเร็จ; open/unpaid ใช้ session เดิม, paid/refunded ปฏิเสธ payment ใหม่, retry attempt ใหม่เฉพาะ verified expired/unpaid

## 6. Database / API change inventory

| ส่วน | เปลี่ยนแปลง | Compatibility / release requirement |
|---|---|---|
| Checkout SQL | feature flags, request key table, fee/pricing snapshots, v3 RPC | v1/v2 เดิมอยู่; default OFF; ต้อง apply/test migration sequence บน disposable DB ก่อน staging |
| Order ops SQL | busy/acceptance/fulfillment/rejection/consent records, guards/RPC | state vocabulary/payment status เดิมอยู่; additions default inert; trigger ต้องทดสอบกับทุก legacy writer |
| Options SQL | resolver min-select validation | ต้อง test legacy required/max-only option JSON และ malformed values |
| Stripe SQL | monotonic ledger/order identity, refund failure RPC, historical account + exact refund PaymentIntent guard | existing webhook RPC signature คงเดิม; service-role only; early refund rollback/retry แทนเดา state |
| Performance SQL | read-only `merchant_order_performance(uuid,date,date)` | manager/legacy owner only, default OFF; finance money calculation เดิมไม่ถูกทำซ้ำ |
| Refund Edge | existing POST endpoint; additive `orderRecordPending` | response เดิม `status`, `refundId`, `gpRecordPending` ยังอยู่; failed provider response เป็น error ที่ UI existing catch รับได้ |
| Realtime client | additive callback/recovery | backend authoritative fetch เดิม; event duplicate/reconnect ไม่สร้างออเดอร์/transaction |

ไม่มีการ apply migration สู่ staging/Production, reset/drop database จริง, เปลี่ยน production variables, เปลี่ยนโดเมน หรือ deploy ในรอบนี้

ไฟล์ migration ใหม่ทั้ง 6 ไฟล์ตามลำดับ: `20261013045900_food_checkout_integrity.sql`, `20261013045901_food_option_minimum.sql`, `20261013050000_food_order_operations.sql`, `20261013050100_food_stripe_event_integrity.sql`, `20261013050101_food_stripe_historical_account.sql`, `20261013050200_food_merchant_performance.sql` ผล apply ใน QA เป็น disposable PostgreSQL เท่านั้น

API ใหม่: `food_checkout_features`, `food_resolve_checkout_request`, `food_quote_order_v3`, `food_create_order_v3`, `food_reject_order`, `food_adjust_preparation_time`, `merchant_set_food_busy_mode`, `merchant_food_acceptance_overdue`, `food_order_operations_features`, `merchant_propose_food_order_modification`, `food_respond_order_modification`, `food_record_stripe_refund_failure`, `merchant_order_performance`; replace canonical menu resolver และ harden `food_transition_order`/`food_apply_stripe_event` โดยคง signatures เดิม

## 7. Development / Feature Flags

| Flag / capability | ค่าเริ่มต้น | ความสามารถที่พร้อมให้ทดสอบ / ขอบเขตที่ยังปิด |
|---|---|---|
| `checkout_v3` | OFF, developer-only | v3 quote/create + idempotency บน disposable development fixtures หลัง migration; legacy checkout ยังเป็น default |
| `small_order_fee` | OFF, developer-only | สูตร subtotal-before-discount `<60 →15`, `>=60 →0`; ห้ามเปิดเงินจริงก่อนยืนยัน fee ownership/finance |
| `menu_min_select` | OFF, developer-only | minimum editor ยังไม่เปิดทั่วไป; SQL resolver คุม menu fields ที่บันทึกแล้วโดยรักษา legacy required/max semantics |
| `busy_mode` | OFF, developer-only | โครงสร้างพักรับ/เพิ่ม prep; ต้อง UX/customer availability integration และ browser QA |
| `merchant_performance` | OFF, developer-only | operational metrics ใน Finance date range เดิม; actual membership required; เงินใช้ finance summary เดิม |
| `order_modifications` | OFF, developer-only | proposal + consent tracking; ไม่ execute repricing, partial refund, charge increase หรือ replacement |
| `acceptance_timeout_reporting` | OFF, developer-only | รายงาน metadata deadline ที่ตั้งชัดเจน; ไม่มี cancellation job |
| `auto_accept` | OFF | reserved config; executor ยังไม่มีและร้าน default false |
| `customer_pickup` | OFF | reserved mode; operational path ยัง block |
| `wynos_rider` | OFF | reserved mode; ไม่เปิด Rider หรือสมมติ rider compensation |
| public Food rollout | existing gate | ค่า runtime UNKNOWN; ไม่อ่าน/เปลี่ยนจริง |

ค่าข้างต้นเป็น migration defaults ไม่ใช่ผลอ่าน production settings การทำ dev enablement ต้องใช้ synthetic development DB เท่านั้น

Rider fee ที่ต้องรักษาในอนาคต: 2 กม.แรก 10 บาท; ระยะเกินปัดขึ้นทุก 100 เมตรเพิ่ม 0.50 บาท; ราคาสุดท้ายปัดขึ้นเงินบาทเต็ม ยังไม่มีการเปิด executor หรือค่าตอบแทนในรอบนี้

## 8. Automated QA matrix ตาม Master Prompt ทั้ง 19 ข้อ

สถานะ `มี test เดิม` หมายถึงพบไฟล์และตรวจ assertion ไม่ได้หมายถึงรันแล้ว ตารางนี้เป็น baseline/แผนรันทดสอบ ต้องอ่านผลรันจริงในหัวข้อถัดไปแยกกัน

| # | เคส | Coverage ที่พบ / เพิ่ม | งานที่ยังต้องยืนยัน |
|---|---|---|---|
| 1 | สร้าง order สำเร็จ | `wynos_food_order_options_test.sh`, options/stock/checkout SQL tests | customer browser → quote → create → payment → merchant ใน staging |
| 2 | กดสร้างซ้ำ | เดิมมี rate-limit; เพิ่ม checkout v3 request key/lock | concurrent same key + changed payload, cross-tab/reload และ scheduled variants |
| 3 | ร้านรับ | `wynos_merchant_finance_test.sh`, order RPC/state tests | browser click พร้อม payment race/role matrix |
| 4 | ร้านปฏิเสธ | เพิ่ม `food_reject_order` และ `food_order_operations_test.sh` | required reason/UI, paid → pending refund ไม่ claim returned |
| 5 | ร้านไม่ตอบในเวลา | unpaid timeout source tests เดิม + optional acceptance deadline/report | การแจ้งเตือน/overdue; ไม่มี paid auto-cancel และยังไม่กำหนด SLA |
| 6 | stock หมดหลังลงตะกร้า | `wynos_food_customer_stock_test.sh` | price/stockเปลี่ยนระหว่าง quote กับ create และ concurrent stock decrement |
| 7 | ลูกค้าปฏิเสธ modification | เพิ่ม proposal/response SQL tests | browser request/response UI; accepted consent ไม่ mutate order/เงิน |
| 8 | discount 40 | `food-first-order-merchant-funded.test.mjs` source contracts; migrations 100/40 | SQL boundary 99.99/100, delivery excluded, merchant funded |
| 9 | ใช้สิทธิ์ซ้ำ | global buyer lock/redemption เดิม; SQL first-order QA workflow | concurrent stores/two sessions + cancelled-unpaid vs paid/refunded eligibility |
| 10 | fee 15 ก่อนลด `<60` | เพิ่ม v3 SQL fee calculation | 59.99/60, addon subtotal, delivery/discount ไม่เปลี่ยนฐาน; finance owner gate |
| 11 | status ผิดลำดับ | transition RPC เดิม; เพิ่ม DB guard | direct privileged writer, same-state retry, terminal resurrection/refund race |
| 12 | webhook ซ้ำ | `wynos_stripe_payment_core_test.sh`; event unique/idempotency | signed duplicate HTTP + late/out-of-order payment/refund/payout events |
| 13 | Realtime หลุด | เพิ่ม `order-recovery.test.mjs`, `food-realtime-subscriptions.test.mjs` | browser offline/reconnect, channel resubscribe และ cross-app refresh |
| 14 | ข้ามร้าน | `wynos_merchant_access_hardening_test.sh`, role/RLS scripts | PostgREST direct API, realtime isolation, inactive member และ staff roles |
| 15 | payment/refund fail | เพิ่ม 9 actual-handler synthetic tests + 8 helper tests; source checksเดิม | provider sandbox async refund + full webhook SQL transition + GP reconciliation |
| 16 | ซ่อน terminal >24h | `merchant-order-history-feedback.test.mjs` executes predicate (23h, 24h, future, cancelled) | browser clock/update/terminal timestamp fixtures |
| 17 | ย้อนดู history | history source contracts scoped/paginated | real browser pagination/search หลัง item พ้น 24h |
| 18 | GP/net | `merchant_gp_v1_test.sh`, merchant/admin finance scripts; GP quote helper | payment/refund evidence, missing GP quote, partial/delayed fee return, payouts vs entitlement |
| 19 | flag ปิดได้จริง | เพิ่ม SQL feature default/off/nondeveloper tests | legacy no-migration fallback, OFF toggle บน staging ไม่เปิด financial path |

## 9. ผลการทดสอบจริงและข้อจำกัด

ผลที่ QA agent รันแล้วใน workspace ณ เวลาบันทึกรายงาน:

| คำสั่ง | ผล | พิสูจน์อะไร / ไม่พิสูจน์อะไร |
|---|---|---|
| `node supabase/functions/merchant-stripe-refund/_lib.test.ts` | **PASS 8 tests** | executes helper classification/fee verification; ไม่ใช้ provider/DB |
| `node web/tests/food-refund-safety.test.mjs` | **PASS 9 tests** | executes actual edge handler ผ่าน Node TS stripping + VM โดย auth/query/fetch เป็น synthetic boundaries; pending/fail/DB failure/webhook race/GP evidence/role/read failure |
| `node web/tests/food-checkout-payment-safety.test.mjs` | **PASS 7 tests** | executes actual Checkout edge handler กับ synthetic auth/SQL/provider; unknown retrieval ไม่สร้าง payment ใหม่, known expired เท่านั้น retry ได้ |
| `node web/tests/food-checkout-integrity.test.mjs` | **PASS 8 tests** | retained intent, re-quote/flag toggle recovery, v3 routing/expected totals และ legacy quote fallback boundaries |
| `node web/tests/merchant-busy-mode.test.mjs` | **PASS 9 tests** | capability, explicit prep/deadline, role fail-closed และ React static render; ยังไม่ใช่ actual browser/backend BusyMode flow |
| `cd web && npm run test:stripe` | **PASS 5 files (root final QA)** | source contracts ของ payment/timeout/promo และ actual mocked refund/Checkout handlers; file count ไม่ใช่จำนวน scenario |
| `cd web && npm run test:food-hardening` | **PASS 9 files (root final QA)** | checkout/options/recovery/subscriptions/modification/busy/performance/rider-pricing/rejection; uses synthetic fixtures ไม่มี provider/live DB |
| `node web/tests/stripe-payment-core.test.mjs` | **PASS 14 tests** | assertions ส่วนใหญ่เป็น source-contract; ไม่ถือว่า Stripe payment success จริง |
| `node web/tests/merchant-order-history-feedback.test.mjs` | **PASS 4 tests** | terminal predicate + scoped history contracts; ไม่ใช่ signed-in merchant browser flow |
| `node web/tests/merchant-order-screen.test.mjs` | **PASS 6 tests** | push VM + wake/sound/reminder source contracts; ไม่ทดสอบ OS push จริง |
| `node web/tests/food-option-rules.test.mjs` | **PASS 8 tests** | executes options min/max/required normalization/validation ด้วย legacy/malformed fixtures |
| `node web/tests/order-recovery.test.mjs` | **PASS 6 tests** | executes recovery scheduling/coalescing/dispose ด้วย fake browser events; ไม่มี actual websocket |
| `node web/tests/food-realtime-subscriptions.test.mjs` | **PASS 5 tests** | mock subscription/filter/status callback และ menu save boundaries; ไม่มี real RLS/network |

ผลเพิ่มเติมจากไฟล์ log ที่ root QA ส่งและ QA agent เปิดตรวจจริง รวม final SQL rerun หลังแก้ independent-review findings:

| Suite / artifact | ผลที่พบ | ขอบเขตและข้อจำกัด |
|---|---|---|
| `supabase/tests/food_checkout_integrity_test.sh` · `/tmp/wynos-checkout-test.log` | **PASS suite** | disposable PostgreSQL; legacy RPC boundary stub + actual new migration/min resolver; ไม่ใช่ full deployed stack |
| `supabase/tests/wynos_stripe_payment_core_test.sh` · `/tmp/wynos-stripe-db-final.log` | **PASS suite** | actual SQL migrations, original account remap, wrong/null/legacy PI guards, early-refund rollback/retry, late state/identity, service-only mutation; ไม่เรียก Stripe |
| `supabase/tests/food_order_operations_test.sh` · `/tmp/wynos-ops-db-final.log` | **PASS suite** | state/reason/prep/busy/consent RLS+audits, unapplied items/money และ paid overdue ไม่ยกเลิก |
| `supabase/tests/food_merchant_performance_test.sh` · `/tmp/wynos-metrics-db.log` | **PASS suite** | operational counts/rates/top menus, unknown samples, 366-day bounds, manager/legacy owner isolation และไม่ใช้ broad table grants |
| `supabase/tests/wynos_merchant_access_hardening_test.sh` · `/tmp/wynos-access-db.log` | **PASS suite** | actual WYN-213 hardening SQL regression; ไม่ยืนยัน deployment schema จริง |
| `supabase/tests/wynos_food_customer_stock_test.sh` · `/tmp/wynos-stock-db.log` | **PASS suite** | existing stock behavior regression บน local throwaway fixtures |
| `supabase/tests/wynos_merchant_finance_test.sh` · `/tmp/wynos-finance-db.log` | **PASS suite** | existing WYN-210 finance summary regression; ไม่ใช่ real payouts/settlement reconciliation |
| `supabase/tests/wynos_platform_campaigns_test.sh` · `/tmp/wynos-platform-campaigns.log` | **PASS suite** | actual first-order 100/40 migration, merchant cost/cancellation/server-redemption integration |
| `cd web && npm run build` · `/tmp/wynos-web-build.log` | **PASS build** | clean credential-free environmentตาม root QA; ไม่ใช่ deploy หรือ live API smoke |
| Chromium Food/Merchant Playwright · `/tmp/wynos-browser-qa.log` | **PASS 134 tests** | local Android/desktop projects; source assertions และ browser fixtures ผสม ไม่ใช่ authenticated order/payment E2E |
| WebKit Merchant source checks · `/tmp/wynos-webkit-qa.log` | **63 passed** | รอบแรก runtime 4 cases launch ไม่ได้เพราะ host library; ผล source checks ไม่ใช่ browser runtime evidence |
| WebKit iPhone runtime rerun · `/tmp/wynos-webkit-runtime.log` | **PASS 4 tests** | หลังแก้ host library: public auth surface, payment-onboarding surface, native touch reorder/cancel, compact switch target ผ่านใน local WebKit emulator; ไม่ใช่ real-device/push หรือ merchant signed-in transaction E2E |

Final QA: TypeScript ผ่าน, Lint 0 errors / 17 warnings เดิม, clean-environment build ผ่าน (`/tmp/wynos-web-build-final.log`), Deno 2.9.6 check Edge Functions ที่แก้ทั้ง 3 ตัวผ่าน, Deno helper tests 14 ผ่าน และ webhook source contracts 6 ผ่าน. Merchant Playwright หลัง integration ผ่าน 120 checks บน Chromium Android/Desktop และ WebKit iPhone (`/tmp/wynos-merchant-browser-final.log`); เป็น source checks + browser fixtures ไม่ใช่ authenticated order/payment E2E. ไม่ใช้ผลนี้เพื่ออ้างว่าผ่าน provider/staging/Production

ยังไม่ได้ทำ: provider sandbox transaction, remote browser QA, staging/Production HTTP smoke, deployment version reconciliation, production schema/flags/secrets, live financial reports, load test และ recovery/restore test

Playwright configuration [web/playwright.config.ts](../../web/playwright.config.ts) ระบุว่า hosted preview ใช้ production Supabase จึง **ไม่รัน hosted browser suites ในรอบนี้** แม้ URL จะชื่อ preview; local fixtures ที่ตัด network/data จริงเท่านั้นที่อยู่ใน scope

Supabase docs ที่ตรวจผ่าน docs connector ยืนยันว่า `.update()` ไม่คืน modified rows โดย default ต้อง `.select()` และ `.maybeSingle()` ยอม zero/one row; refund fix ตรวจทั้ง error และ affected rows แล้ว การอ่าน changelog public ผ่าน shellไม่สำเร็จเพราะ session proxy ไม่พร้อม จึงไม่อ้างว่าทบทวน changelogครบ

## 10. Stripe / Thailand และเงื่อนไขก่อน Production

ตรวจ documentation ผ่าน Stripe documentation search connector เท่านั้น ไม่เรียก account enumeration, balance, API keys หรือ financial APIs

สิ่งที่เอกสารที่คืนมายืนยันได้:

- [PromptPay payments](https://docs.stripe.com/payments/promptpay): THB, customer-initiated, Connect support, **ไม่รองรับ manual capture**, รองรับ refund/partial refund
- เอกสารเดียวกันระบุว่าการคืน PromptPay อาจต้องให้ลูกค้าระบุ bank information ผ่านการติดต่อของ Stripe; ไม่ใช่การคืนสำเร็จทันที และการใช้ QR เดิมซ้ำอาจทำให้มี excess payment ที่ต้อง manual resolution
- [Connect charges](https://docs.stripe.com/connect/charges) อธิบาย direct/destination/separate charges/transfers และบทบาท `on_behalf_of`; [payment method Connect support](https://docs.stripe.com/payments/payment-methods/payment-method-connect-support) อธิบาย capability/account-method readiness
- โค้ด WYNOS ปัจจุบันใช้ direct connected-account charge (`Stripe-Account` header) + application fee ไม่ใช่ destination charge หรือ separate transfer

**ยังยืนยันไม่ได้จากผลค้นรอบนี้:** Thailand-specific country/controller/account/API-v2 availability, เงื่อนไขสัญญา platform/merchant, cross-border payout และ eligibility ของ Stripe configuration ที่ WYNOS ใช้ ผล search ไม่คืนหลักฐานประเทศที่เพียงพอ จึงไม่สรุปว่า Accounts v2 หรือการแบ่งจ่ายทุกรูปแบบใช้ได้ในไทย ต้องได้ official confirmation และทดสอบ provider sandbox ก่อน production gate

ข้อกำหนดห้ามเพิ่ม Email Notifications ยังคงมีผล ไม่มีการเพิ่ม application email แต่ provider PromptPay refund อาจใช้ email ที่ Stripe ส่งเองตามเอกสาร ต้องให้ Founder ประเมินข้อจำกัดนี้ก่อนเลือกเปิด flow นั้น

ชื่อ config ที่พบใน source (ไม่ตรวจค่า): `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`/`SUPABASE_SECRET_KEYS`, `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_V2_WEBHOOK_SECRET`; push/Maps/deploy มี configuration เดิมใน workflows ห้ามนำ secrets มาใส่ browser/log/test

ขั้นก่อนเปิดจริง:

1. Resolve HIGH financial state/reconciliation findings และรัน SQL concurrency/account-isolation/GP suite ด้วย disposable PostgreSQL
2. ยืนยัน API/migration ordering ของ existing files กับ new additive migrations โดยเฉพาะ WYN-213 access hardening ก่อน new operations; ทดสอบ apply ซ้ำ/backward compatibility ห้าม reset database จริง
3. ยืนยัน fee ownership/GP/settlement และ provider Thailand capability โดยไม่เปลี่ยนกติกา 100/40, 60/15 หรือค่าส่งที่กำหนด
4. ผ่าน typecheck/lint/build และ browser fixtures ของ Food/Merchant/Admin ที่เกี่ยวข้อง; คง iPhone drag, options radio, upload states, 24h/history behavior
5. ทดสอบ complete synthetic staging flow create → paid webhook → accept → prepare → ready → merchant delivery → complete และ rejection/cancel/refund/duplicate/reconnect paths
6. ตรวจ staging deployment/backend/schema/flags ให้ตรง reviewed artifact, monitoring/rollback runbook และ alert/reconciliation queue ที่ไม่ส่ง email
7. รับ Founder Production release approval แยกต่างหาก ก่อน deploy/migrate/enable flags/payment/payout; ไม่ถือว่าการพัฒนาเสร็จเท่ากับเปิดจริงได้

### งานต่อที่ยังไม่ได้ implement ครบ

Payment-provider adapter/interface ที่ครอบคลุม checkout/refund/webhook normalization, full auditable transaction ledger, asynchronous fee-refund reconciliation, partial/order-modification financial execution, replacement rules, integration/QA ของ metrics/consent/busy-mode UI, auto-accept executor, acceptance SLA policy และ capacity/device QA ต้องพัฒนาต่อเป็น module พร้อม tests ไม่สร้างระบบซ้ำหรือเปิดสิ่งที่ยังไม่พร้อม

AI Secretary ใช้ audit/event/read-only summaries ที่มีอยู่ได้ในอนาคต แต่ไม่เพิ่มสิทธิ์ทำ transaction/แก้ risky settings และไม่เพิ่ม primary Admin menu ซ้ำในรอบนี้

## Latest main integration

ระหว่างทำงาน main เพิ่ม Admin control centers จาก PR #1125 (`c47e0f7c`, head `7a8fdae2`). ตรวจ catalog, server permission checks และ read-only delivery preview จาก source แล้ว: เป็นลิงก์ไปเครื่องมือเดิมและรายการรอพัฒนา ไม่ใช่ live switches หรือหลักฐาน backend readiness. ไม่แก้ Admin files เหล่านี้หรือรัน one-time release workflow; branch นี้ใช้ latest main เป็นฐานและไม่สร้างเมนูหลักซ้ำ. Admin Rider calculator เป็น simulation แยกจาก pricing/payment จริง; ก่อนเปิด Rider ต้องรวมการคิดราคาผ่าน backend กลาง.
