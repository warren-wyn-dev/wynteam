# PRD (ร่าง) — ZOKY: จ่ายด้วย QR พร้อมเพย์ที่ยืนยันอัตโนมัติ + คืนเงินอัตโนมัติเมื่อยกเลิก

- สถานะ: **DRAFT — รอ Founder ตัดสินใจ (ดูหัวข้อ "สิ่งที่ Founder ต้องตัดสินใจ")**
- วันที่: 2026-10-22
- ผู้เขียน: AI Product Manager
- คำขอ Founder (2026-10-22): "ระบบจ่ายเงิน ที่ตัดอัตโนมัติ โดยใช้ QR พร้อมเพย์ และระบบคืนเงิน หากยกเลิก"
- โค้ดที่ตรวจ: `/home/user/wynteam-release` (branch `release/zoky-web-20261018` @ `e6f577dc` = production ของ zoky.wynos.online)
- ขอบเขตเอกสาร: นิยาม "ควรสร้างอะไร" เท่านั้น ไม่ใช่การอนุมัติให้ implement / migrate / deploy

## Founder Decision ที่ได้รับระหว่างเขียน (2026-10-22)

> "ตัด QR แบบแนบสลิปออก เงินต้องจ่ายผ่าน Stripe ทุกคน"

- ความหมายใน PRD นี้: **ยกเลิกช่องทาง QR พร้อมเพย์ของร้าน + แนบสลิป ทั้งฝั่งลูกค้าและร้าน** ทุกออเดอร์ของลูกค้า ZOKY ต้องจ่ายผ่าน Stripe (บัตร และ/หรือ Stripe PromptPay ที่ยืนยันอัตโนมัติ) และร้านต้องมีบัญชี Stripe Connect ที่ใช้งานได้จึงจะรับออเดอร์ได้
- คำตัดสินนี้มาถึง PM ผ่าน coordinator — **ต้องบันทึกใน `.wyn/company/DECISIONS.md` และ `.wyn/company/APPROVALS.md` ตามกติกา Founder Feedback** (PM ยังไม่ได้แก้ไฟล์ทั้งสอง เพราะงานนี้ได้รับอนุญาตให้เขียนเฉพาะ PRD) ถือเป็น **major product scope change** และเปลี่ยนเงื่อนไขร้านค้า
- ผลที่ต้องรู้ก่อน: **ร้านที่ยังไม่มี Stripe ready จะรับออเดอร์ไม่ได้ทันทีที่เปิดใช้** (ดูหัวข้อ "ผลกระทบต่อร้านที่ยังไม่อยู่บน Stripe")
- เดิม D1 ในร่างแรกถูกตอบแล้วด้วยคำตัดสินนี้ คำถามที่เหลือ/ใหม่อยู่ในหัวข้อ "สิ่งที่ Founder ต้องตัดสินใจ"

---

## Feature

ZOKY Auto PromptPay + Auto Refund

## Goal

1. ลูกค้าจ่ายด้วย QR พร้อมเพย์แล้ว **ระบบรู้เองว่าจ่ายแล้ว** — ไม่ต้องแนบสลิป ไม่ต้องให้ร้านตรวจเอง
2. เมื่อออเดอร์ที่จ่ายแล้วถูกยกเลิก **เงินคืนลูกค้าอัตโนมัติ** — ร้านไม่ต้องกดคืนเอง
3. (Founder 2026-10-22) **ทุกออเดอร์จ่ายผ่าน Stripe เท่านั้น** — ไม่มี QR ร้าน/สลิป/การยืนยันเงินเข้าด้วยมือ ซึ่งทำให้ทุกออเดอร์ที่จ่ายแล้วคืนเงินอัตโนมัติได้

## Target User

- ลูกค้า ZOKY (zoky.wynos.online)
- ร้านค้าบน WYNOS Merchant (merchant.wynos.online)
- WYNOS Admin (ดูสถานะ/แก้ปัญหาเมื่อการคืนเงินล้มเหลว)

## Problem

- ทางที่ลูกค้าเห็นชัดที่สุดตอนนี้คือ "QR พร้อมเพย์ของร้าน + แนบสลิป" ซึ่ง**ไม่ยืนยันอัตโนมัติจริง** ส่วนใหญ่ต้องรอร้านตรวจสลิป (ดู Current State ข้อ A2)
- พร้อมเพย์ที่ยืนยันอัตโนมัติมีอยู่แล้วแต่ "ซ่อน" อยู่ในปุ่ม "จ่ายด้วยบัตร" ของ Stripe และขึ้นกับว่าบัญชี Stripe ของร้านเปิด PromptPay แล้วหรือยัง
- เมื่อร้านยกเลิกออเดอร์ที่จ่ายแล้ว ระบบแค่ตั้งสถานะ "รอคืนเงิน" — **ร้านต้องกดคืนเงินเอง** ถ้าร้านลืม ลูกค้าไม่ได้เงินคืน
- มีช่องโหว่ที่ลูกค้าอาจจ่ายเงินสำเร็จหลังออเดอร์ถูกยกเลิกไปแล้ว และไม่มีการคืนเงินอัตโนมัติ (ดู Current State ข้อ C3)

---

## Current State (สิ่งที่มีอยู่จริงในโค้ด production)

### A. การรับเงิน

| # | สิ่งที่มี | หลักฐาน | สรุป |
|---|---|---|---|
| A1 | **QR พร้อมเพย์ของร้าน (static PromptPay, ตั้งยอดให้)** — server สร้าง QR จาก `food_stores.promptpay_id` + ยอดออเดอร์ เงินเข้าบัญชีพร้อมเพย์ของร้านตรง | `supabase/functions/food-payment-qr/index.ts`, `_lib.ts` (`buildPromptPayPayload`); เรียกจาก `web/lib/food-customer.ts` `fetchFoodPromptPayQr` (บรรทัด ~766); แสดงใน `web/components/food/wynos-food-developer-app.tsx` (~2871–2888, 3012–3018) | **ไม่มีการยืนยันอัตโนมัติ** — ระบบไม่รู้ว่าโอนแล้ว จนกว่าลูกค้าแนบสลิป |
| A2 | **แนบสลิป + ตรวจสลิปด้วย SlipOK** | `uploadFoodPaymentSlip`, `submitFoodPayment` ใน `web/lib/food-customer.ts` (~723–817); RPC `food_submit_payment` (`supabase/migrations_wynos_stripe_payment_core_v1.sql` ~245); `supabase/functions/food-verify-slip/index.ts` | auto_verified ได้**เฉพาะร้านเดียว**ที่ตรงกับ env `SLIPOK_RECEIVER_STORE_ID` (บรรทัด 85–86, 171) ร้านอื่นทั้งหมดตกเป็น `manual_review` = ร้านต้องตรวจเอง; ถ้าไม่ได้ตั้งค่า SlipOK ทุกออเดอร์เป็น manual |
| A3 | **Stripe Checkout บนบัญชี Stripe ของร้าน (Connect, direct charge)** | `supabase/functions/food-stripe-checkout/index.ts`; ปุ่ม "จ่ายด้วยบัตร — บัตร หรือพร้อมเพย์ผ่าน Stripe · ยืนยันสถานะอัตโนมัติ" ใน `wynos-food-developer-app.tsx` (~3038–3044) แสดงเฉพาะเมื่อ `stripe_payments_enabled = true` | ยืนยันอัตโนมัติผ่าน webhook (`supabase/functions/stripe-webhook/index.ts` → RPC `food_apply_stripe_event`) |
| A4 | **Stripe PromptPay** ไม่ได้ส่ง `payment_method_types` เอง ใช้ payment method configuration ของบัญชีร้าน | comment ใน `food-stripe-checkout/index.ts` บรรทัด 161–163; ตอน onboarding v2 ระบบพยายามเปิด PromptPay ให้ (`preferPromptPay` ใน `supabase/functions/merchant-stripe-connect/index.ts` ~210–237, 594–598); สถานะเก็บใน `food_stripe_accounts.promptpay_enabled` / `promptpay_status` (sync ใน `stripe-webhook` ~146–166, 247–248) | **คำตอบ: ใช่ ลูกค้าเลือกพร้อมเพย์ผ่าน Stripe ได้แล้ว** แต่เฉพาะร้านที่ Stripe พร้อม (`status='ready'`) และ PromptPay `available` ในบัญชีร้าน — ลูกค้าต้องกด "จ่ายด้วยบัตร" ก่อนจึงเห็นพร้อมเพย์ในหน้า Stripe; `food-stripe-checkout` select `promptpay_enabled` แต่**ไม่ได้ใช้** ตัดสินอะไร |
| A5 | หน้าร้านในฝั่ง Merchant แสดง "รับบัตรและ PromptPay" / "PromptPay จะเปิดให้อัตโนมัติเมื่อบัญชีรองรับ" | `web/components/merchant/merchant-payment-setup.tsx` ~243–250 | ร้านเห็นสถานะ แต่ไม่มีทางบังคับเปิด PromptPay เองจาก WYNOS |
| A6 | บันทึกวิธีจ่าย | `stripe-webhook/index.ts` ~428–429 ใช้ `payment_method_types[0]` | **ไม่ใช่วิธีที่ลูกค้าจ่ายจริง** (เป็นรายการแรกที่ session อนุญาต) — รายงานว่าออเดอร์ไหนจ่ายด้วยพร้อมเพย์จะไม่แม่น |

### B. ใครจ่ายค่าธรรมเนียม / เงินเข้าใคร

- Stripe เป็น **direct charge บนบัญชี Stripe ของร้าน** (header `Stripe-Account` ใน `food-stripe-checkout/index.ts` บรรทัด 31) → เงินเข้า balance Stripe ของร้าน แล้วโอนเข้าบัญชีธนาคารร้านตามรอบ payout (ร้านจะ "ready" ได้ต้องตั้ง payout อัตโนมัติ — `stripe-webhook/index.ts` ~238–240)
- ค่าธรรมเนียม Stripe ของ direct charge ปกติหักจากบัญชีร้าน — อัตราจริงสำหรับ PromptPay/บัตรในไทย **ต้องตรวจสอบกับ Stripe**
- GP ของ WYNOS = 0% ตอนนี้ (Founder 2026-10-11, `.wyn/company/DECISIONS.md` "GP v1") เก็บผ่าน application fee เมื่อเปิดใช้; QR/สลิปเข้าบัญชีร้านตรง **เก็บ GP ไม่ได้**
- WYNOS ไม่ได้ถือเงินลูกค้าในทางใดเลย

### C. การยกเลิกและการคืนเงิน

| # | สถานการณ์ | หลักฐาน | สิ่งที่เกิดขึ้นตอนนี้ |
|---|---|---|---|
| C1 | **ลูกค้ายกเลิกเอง** | RPC `food_cancel_order` (`supabase/migrations_wynos_food_customer_access_gate_v2.sql` ~234–280); UI `cancel()` ใน `wynos-food-developer-app.tsx` ~2942 | ยกเลิกได้**เฉพาะตอนยังไม่จ่าย** (`pending_acceptance` + `payment_status in (pending, issue)`) จ่ายแล้วยกเลิกเองไม่ได้ ต้องติดต่อร้าน → **ไม่มีกรณีคืนเงินจากลูกค้ายกเลิก** |
| C2 | **ร้านยกเลิก** (ได้ทุกขั้นจนถึง "กำลังส่ง") | `food_transition_order` (`supabase/migrations_wynos_merchant_core_completion_v1.sql` ~537–606) | ถ้าจ่ายแล้ว → ตั้ง `refund_status='pending'` เท่านั้น ลูกค้าได้แจ้งเตือน "ร้านจะคืนเงินให้คุณ" (`20261008113000_food_unpaid_payment_timeout.sql` ~184–188) |
| C3 | **ร้านกดคืนเงิน (Stripe)** | `supabase/functions/merchant-stripe-refund/index.ts`; UI ปุ่ม "คืนเงินผ่าน Stripe" ใน `web/components/merchant/merchant-core-panels.tsx` ~450, 495–496; `requestStripeRefund` ใน `web/lib/merchant-core.ts` ~348 | **คืนเงินผ่าน Stripe เป็นแบบร้านต้องกดเอง (merchant-initiated) ไม่อัตโนมัติ**; คืนเต็มจำนวนเท่านั้น; มี idempotency key `wynos-refund-<order>`; ใช้ได้เฉพาะ origin `https://merchant.wynos.online` (บรรทัด 43) |
| C4 | **ร้านคืนเงินเอง (QR/สลิป)** | `merchant_set_refund_status` (`migrations_wynos_merchant_core_completion_v1.sql` ~434; รุ่นที่ห้าม Stripe อยู่ใน `migrations_wynos_stripe_payment_core_v1.sql` ~292) | ร้านโอนคืนเองนอกระบบ แล้วกดยืนยัน — **ระบบตรวจไม่ได้ว่าโอนคืนจริง** หมายเหตุ: มี 2 เวอร์ชันของฟังก์ชันนี้ในไฟล์ migration ระดับ root เวอร์ชันหนึ่งไม่มีเงื่อนไขกัน Stripe — **ต้องให้ทีมตรวจว่าเวอร์ชันไหนอยู่บน production** |
| C5 | **ยืนยันผลคืนเงิน** | `stripe-webhook/index.ts` ~441–462 | รองรับ `charge.refunded` (เต็มจำนวน), `refund.created/updated` (สำเร็จ + ยอดเต็ม), `refund.failed` (แค่ log, **ไม่อัปเดตสถานะออเดอร์**); การคืนบางส่วนเป็น `noop` |

### D. หมดเวลาชำระเงิน (10 นาที)

- `food_orders.payment_due_at` = สร้างออเดอร์ + 10 นาที (`supabase/migrations/20261008113000_food_unpaid_payment_timeout.sql`)
- cron ทุก 1 นาที เรียก `supabase/functions/food-unpaid-timeout/index.ts` → ถ้ามี Stripe session ต้อง **expire session ที่ Stripe ก่อน** แล้วจึงเรียก `food_timeout_cancel`; ถ้า Stripe ตอบว่าจ่ายแล้วจะไม่ยกเลิก (defer) — มี test `web/tests/food-payment-timeout.test.mjs`
- สลิปที่ส่งทันเวลา (`submitted`) ไม่ถูกยกเลิก; ส่งสลิปหลังหมดเวลาถูก trigger `food_guard_late_slip` ปฏิเสธ
- **QR พร้อมเพย์ของร้าน (A1) ไม่มีวันหมดอายุ** ลูกค้ายังโอนตาม QR ได้แม้ออเดอร์ถูกยกเลิกแล้ว → เงินเข้าร้านโดยไม่มีออเดอร์ และไม่มีทางคืนอัตโนมัติ

### E. ช่องโหว่ที่พบ (ต้องแก้ใน feature นี้)

1. **จ่ายสำเร็จหลังยกเลิก (Stripe)**: `food_cancel_order` (ลูกค้า) และ `food_transition_order` (ร้านยกเลิกออเดอร์ที่ยังไม่จ่าย) **ไม่ได้ expire Stripe Checkout session** ถ้าลูกค้ายังเปิดหน้า Stripe ค้างไว้แล้วจ่าย webhook จะตั้ง `payment_status='paid'` บนออเดอร์ที่ `cancelled` (เงื่อนไขใน `food_apply_stripe_event` ไม่เช็ค `status`, `migrations_wynos_stripe_payment_core_v1.sql` ~199–212) และไม่ตั้ง `refund_status` → เงินค้างโดยไม่มีใครรู้
2. การคืนเงินล้มเหลว (`refund.failed`) ไม่สะท้อนในออเดอร์/ไม่แจ้งใคร
3. ไม่มีตัวจับ "ออเดอร์ยกเลิกแล้วแต่ยังค้างคืนเงิน" (refund pending นาน)
4. ไม่มีหน้า Admin สำหรับการคืนเงิน (ระบุเป็น "เร็วๆ นี้" — `.wyn/company/DECISIONS.md` ~2214; `docs/engineering/WYNOS-ADMIN-MASTER-GAP-ANALYSIS.md` D2)

---

## สรุป: มีแล้ว vs ยังขาด

| เรื่อง | มีแล้ว | ยังขาด |
|---|---|---|
| QR พร้อมเพย์ยืนยันอัตโนมัติ | ได้ผ่าน Stripe PromptPay เฉพาะร้านที่ Stripe พร้อมและ PromptPay active | ปุ่ม/ประสบการณ์ "จ่ายด้วยพร้อมเพย์" ที่ชัดเจน, การแสดงว่าร้านไหนรองรับ, บันทึกวิธีจ่ายจริง, นโยบายสำหรับร้านที่ยังไม่มี Stripe PromptPay |
| ไม่ต้องแนบสลิป | Stripe ไม่ต้องแนบ | ร้านที่ไม่มี Stripe ยังต้องใช้สลิป |
| หมดเวลา 10 นาที | ทำงานแล้ว ปลอดภัยกับ Stripe | QR ของ Stripe ต้องหมดอายุสอดคล้องกับ 10 นาที (ตรวจกับ Stripe) |
| คืนเงินเมื่อยกเลิก | ร้านกดคืนผ่าน Stripe ได้, webhook ยืนยันผล | **คืนอัตโนมัติทันทีเมื่อยกเลิก**, จัดการคืนเงินล้มเหลว, คืนเมื่อจ่ายหลังยกเลิก, มุมมอง Admin |

---

## Requirements

> หลักการ: ใช้ของเดิม (Stripe Connect direct charge, webhook, idempotency, timeout worker) — ไม่เปลี่ยนผู้ให้บริการชำระเงิน ไม่ให้ WYNOS ถือเงิน ไม่เพิ่มฟีเจอร์นอกคำขอ

### User Stories

**ลูกค้า**
- US-C1: ในฐานะลูกค้า ฉันต้องการเห็นตัวเลือก "จ่ายด้วยพร้อมเพย์ (ยืนยันอัตโนมัติ)" ชัดเจน สแกนด้วยแอปธนาคาร แล้วออเดอร์เปลี่ยนเป็น "ชำระเงินแล้ว" เองโดยไม่ต้องแนบสลิป
- US-C2: ในฐานะลูกค้า ถ้าออเดอร์ที่ฉันจ่ายแล้วถูกยกเลิก ฉันต้องการได้เงินคืนเข้าช่องทางเดิมโดยไม่ต้องขอ และเห็นสถานะ "กำลังคืนเงิน" → "คืนเงินแล้ว" พร้อมแจ้งเตือน
- US-C3: ในฐานะลูกค้า ถ้าฉันจ่ายเงินหลังออเดอร์ถูกยกเลิก/หมดเวลา ฉันต้องได้เงินคืนอัตโนมัติ
- US-C4: ในฐานะลูกค้า ถ้าการคืนเงินมีปัญหา ฉันต้องเห็นข้อความที่เข้าใจได้และช่องทางติดต่อ

**ร้านค้า**
- US-M1: ในฐานะร้าน ฉันต้องการรู้ว่าร้านฉันรับพร้อมเพย์อัตโนมัติได้หรือยัง และถ้ายังต้องทำอะไร
- US-M2: ในฐานะร้าน เมื่อฉันยกเลิกออเดอร์ที่จ่ายแล้ว (ผ่าน Stripe) ระบบคืนเงินให้ลูกค้าทันทีโดยฉันไม่ต้องกดปุ่มคืนเงินอีกครั้ง และฉันเห็นผลคืนเงินในออเดอร์และหน้าการเงิน
- US-M3: ในฐานะร้าน ฉันต้องถูกแจ้งเตือนเมื่อการคืนเงินล้มเหลว (เช่น ยอดใน Stripe ของร้านไม่พอ)

**Admin**
- US-A1: ในฐานะ WYNOS Admin ฉันต้องการเห็นรายการคืนเงินที่ค้าง/ล้มเหลว เพื่อติดตามกับร้าน (อ่านอย่างเดียวใน P1 — การกดคืนเงินจาก Admin ต้องให้ Founder ตัดสิน)

### Functional Requirements

**R1 — จ่ายด้วยพร้อมเพย์อัตโนมัติ (P0)**
- R1.1 หน้าชำระเงินมีตัวเลือก "พร้อมเพย์ · ยืนยันอัตโนมัติ" แยกจาก "บัตร" เมื่อร้าน `stripe_payments_enabled` และ PromptPay ของบัญชีร้าน active
- R1.2 ตัวเลือกพร้อมเพย์เปิด Stripe Checkout ที่จำกัดให้เป็นพร้อมเพย์ (หรือแสดง QR ใน ZOKY — Architect เลือกวิธี) บนบัญชีร้านเดิม (direct charge)
- R1.3 ยืนยันการจ่ายผ่าน webhook ที่ตรวจลายเซ็นเท่านั้น ห้ามเชื่อ redirect `?stripe=success` จาก client
- R1.4 บันทึกวิธีจ่ายจริง (card / promptpay) จาก PaymentIntent/Charge แทน `payment_method_types[0]`
- R1.5 ร้านที่ Stripe พร้อมแต่ PromptPay ยังไม่ active → แสดงเฉพาะบัตร และตามคำตัดสิน Founder (D1) สำหรับ QR/สลิปเดิม

**R2 — คืนเงินอัตโนมัติเมื่อยกเลิก (P0)**
- R2.1 เมื่อออเดอร์ที่ `payment_provider='stripe'` และ `payment_status='paid'` ถูกยกเลิก (ไม่ว่าโดยร้าน หรือโดยลูกค้าถ้า Founder เปิดสิทธิ์ใน D3) ระบบ server สร้าง Stripe refund เต็มจำนวนเองโดยไม่ต้องให้ร้านกด
- R2.2 ใช้ idempotency key ต่อออเดอร์ (ต่อยอด `wynos-refund-<order>` เดิม) — ห้ามคืนซ้ำ
- R2.3 refund ถูกสร้างบนบัญชี Stripe ที่รับเงินจริง (`food_stripe_payments.stripe_account_id`) และ livemode ตรงกัน (pattern เดียวกับ `merchant-stripe-refund`)
- R2.4 ถ้ามี GP > 0 ให้คืน application fee ตามคำตัดสิน GP v1 (`refund_application_fee`)
- R2.5 สถานะ `refund_status`: pending → refunded (จาก webhook) หรือ failed (จาก `refund.failed` / error) — **`refund.failed` ต้องอัปเดตออเดอร์และแจ้งร้าน**
- R2.6 การยกเลิกต้องสำเร็จเสมอแม้ Stripe ล่มชั่วคราว — refund ต้องถูก retry อัตโนมัติ (มีงาน retry/reconcile) ไม่ใช่ทิ้งไว้
- R2.7 ปุ่ม "คืนเงินผ่าน Stripe" เดิมของร้านคงไว้เป็นทาง retry/สำรอง (ไม่ทำให้คืนซ้ำเพราะ idempotency)

**R3 — กันเงินค้างจากการจ่ายหลังยกเลิก (P0)**
- R3.1 เมื่อลูกค้าหรือร้านยกเลิกออเดอร์ที่ยังไม่จ่ายแต่มี Stripe session เปิดอยู่ ต้อง expire session ก่อน/พร้อมการยกเลิก (แบบเดียวกับ `food-unpaid-timeout`)
- R3.2 ถ้า webhook "paid" มาถึงออเดอร์ที่ `cancelled` แล้ว → บันทึกว่าจ่ายแล้ว + คืนเงินอัตโนมัติทันที ห้ามเปลี่ยนออเดอร์กลับเป็นใช้งาน และแจ้งลูกค้า/ร้าน

**R4 — การมองเห็นสถานะ (P0 สำหรับลูกค้า/ร้าน, P1 สำหรับ Admin)**
- R4.1 ลูกค้าเห็น "กำลังคืนเงิน" / "คืนเงินแล้ว" / "คืนเงินมีปัญหา — ติดต่อร้าน" ในหน้าออเดอร์ + แจ้งเตือน
- R4.2 ร้านเห็นผลคืนเงินในออเดอร์และหน้าการเงิน (มีอยู่แล้วบางส่วน `merchant-finance.tsx`)
- R4.3 (P1) Admin เห็นรายการคืนเงินค้าง > X ชั่วโมง และล้มเหลว (อ่านอย่างเดียว)

### Non-functional

- Security: refund/expire ทำฝั่ง server เท่านั้น ด้วย service role; ไม่มี endpoint ที่ลูกค้าเรียกให้คืนเงินตามยอดที่ client ส่ง; ตรวจสิทธิ์ร้าน/ลูกค้าฝั่ง server; ห้าม log ข้อมูลส่วนบุคคล/secret
- Auditability: ทุกการคืนเงินมี `food_order_events` + `stripe_refund_id`
- Mobile-first, ภาษาไทย, ข้อความสถานะเข้าใจง่าย
- ไม่กระทบ flow QR/สลิปเดิมจนกว่า Founder ตัดสิน D1

---

## Acceptance Criteria

**การจ่าย**
- AC1: ร้านที่ Stripe ready + PromptPay active: ลูกค้าเห็นตัวเลือกพร้อมเพย์ จ่ายสำเร็จ → ภายใน ≤ 1 นาทีหลัง Stripe ส่ง webhook ออเดอร์เป็น `paid` โดยไม่มีสลิปและไม่มีการกดของร้าน
- AC2: redirect success อย่างเดียว (ไม่มี webhook) ไม่ทำให้ออเดอร์เป็น `paid`
- AC3: ร้านที่ PromptPay ไม่ active ไม่แสดงตัวเลือกพร้อมเพย์อัตโนมัติ
- AC4: ออเดอร์ที่จ่ายด้วยพร้อมเพย์ถูกบันทึกวิธีจ่ายเป็น promptpay
- AC5: หมด 10 นาทีโดยไม่จ่าย → session หมดอายุที่ Stripe แล้วออเดอร์ถูกยกเลิก (พฤติกรรมเดิมไม่ถดถอย)

**การคืนเงิน**
- AC6: ร้านยกเลิกออเดอร์ Stripe ที่จ่ายแล้ว → มีการสร้าง refund อัตโนมัติ 1 ครั้ง โดยร้านไม่ต้องกดอะไรเพิ่ม; ลูกค้าเห็น "กำลังคืนเงิน" แล้ว "คืนเงินแล้ว" เมื่อ webhook ยืนยัน
- AC7: เรียกยกเลิก/คืนเงินซ้ำ (double click, retry, webhook ซ้ำ) → Stripe มี refund เดียว
- AC8: Stripe ตอบ error/timeout ตอนสร้าง refund → ออเดอร์ยังถูกยกเลิก, `refund_status` ไม่หายไป, ระบบ retry อัตโนมัติจนสำเร็จหรือถึงขีดจำกัดแล้วตั้ง `failed` + แจ้งร้าน (และ Admin ใน P1)
- AC9: `refund.failed` → `refund_status='failed'`, ลูกค้าเห็นข้อความ "คืนเงินมีปัญหา", ร้านได้แจ้งเตือน
- AC10: ลูกค้ายกเลิกออเดอร์ที่ยังไม่จ่ายขณะมี Stripe session เปิด → session ถูก expire; ถ้า Stripe รายงานว่าจ่ายแล้วระหว่างนั้น การยกเลิกต้องไม่ทิ้งเงินค้าง (คืนอัตโนมัติ หรือไม่ยกเลิก — ตาม design)
- AC11: webhook `paid` มาถึงออเดอร์ที่ `cancelled` → คืนเงินอัตโนมัติ + ออเดอร์ยังเป็น `cancelled`
- AC12: ผู้ใช้อื่น/ร้านอื่นสั่งคืนเงินออเดอร์ที่ไม่ใช่ของตนไม่ได้ (authorization server-side)
- AC13: ข้อมูลใน log ไม่มี secret, ชื่อ/เบอร์/ที่อยู่ลูกค้า

---

## Edge Cases

| กรณี | พฤติกรรมที่ต้องการ |
|---|---|
| QR หมดอายุ | QR/Checkout ต้องหมดอายุไม่เกินเส้นตาย 10 นาทีของออเดอร์ (ระยะหมดอายุ QR ของ Stripe PromptPay **ต้องตรวจสอบกับ Stripe**) ลูกค้าเห็นปุ่มสร้างใหม่ถ้ายังไม่หมดเวลาออเดอร์ |
| จ่ายหลังหมดเวลา/หลังยกเลิก | คืนเงินอัตโนมัติเต็มจำนวน (R3.2) |
| จ่ายสำเร็จก่อนเส้นตายแต่ webhook มาช้า | worker เดิม defer ไม่ยกเลิก (คงไว้) |
| จ่ายซ้ำ (เปิด 2 แท็บ / 2 session) | session เดิมถูก reuse (`food-stripe-checkout` ~133–148) ถ้ายังเกิด charge ที่ 2 ต้องคืน charge ส่วนเกินอัตโนมัติ — กลไกให้ Architect ออกแบบ |
| จ่ายทั้ง Stripe และโอนตาม QR ร้าน+สลิป | มีกันบางส่วนแล้ว (`food_submit_payment` บังคับยกเลิก Stripe session ก่อน) แต่ QR ร้านจ่ายได้ตลอด → ขึ้นกับ D1 |
| คืนเงินบางส่วน (เช่น ของหมด 1 รายการ) | **ไม่อยู่ในคำขอ** — ระบบปัจจุบันคืนเต็มจำนวนเท่านั้น และ webhook ไม่บันทึกการคืนบางส่วน; ถ้ามีคนคืนบางส่วนผ่าน Stripe Dashboard ต้องไม่ทำให้สถานะผิด (แสดงเป็น "ต้องตรวจสอบ") — ให้ Founder ตัดสินใน D4 |
| คืนเงินล้มเหลว (ยอด Stripe ร้านไม่พอ / payout ไปแล้ว / บัญชีร้านถูกจำกัด) | ตั้ง failed + แจ้งร้าน + retry ตามนโยบาย; ใครรับผิดชอบเงินต้อง Founder ตัดสิน (D5); พฤติกรรมเมื่อ balance ร้านติดลบ **ต้องตรวจสอบกับ Stripe** |
| ร้านไม่มี Stripe หรือ PromptPay ไม่ active | ไม่มีพร้อมเพย์อัตโนมัติ — ตาม D1 (ใช้ QR+สลิปเดิม / บัตรเท่านั้น / ปิดรับออเดอร์) |
| ร้านยกเลิกหลังส่งแล้ว (out_for_delivery) | ปัจจุบันยกเลิกได้ → คืนเงินอัตโนมัติเหมือนกัน (เว้นแต่ Founder ตัดสินต่าง) |
| ร้านเปลี่ยน/ตัดบัญชี Stripe หลังรับเงิน | คืนเงินบนบัญชีที่รับเงินจริงเสมอ; ถ้าบัญชีใช้ไม่ได้ → failed + Admin |
| test mode vs live mode ไม่ตรงกัน | ปฏิเสธเหมือนเดิม (`stripe_environment_mismatch`) |
| ออเดอร์ QR/สลิปที่จ่ายแล้วถูกยกเลิก | คืนอัตโนมัติไม่ได้ (เงินอยู่บัญชีพร้อมเพย์ร้าน) — คง flow ร้านโอนคืนเอง + ยืนยัน (C4) และแสดงลูกค้าว่า "ร้านจะโอนคืน" |

---

## Dependencies

- Stripe Connect accounts ของร้านต้อง ready และเปิด PromptPay ได้ (ฝั่ง Stripe)
- Stripe webhook endpoint ต้อง subscribe event ที่จำเป็นเพิ่ม เช่น `refund.failed`, `charge.refunded`, `checkout.session.async_payment_succeeded` (Founder ตั้งค่าใน Stripe Dashboard — **ต้องตรวจสอบรายการ event ที่ subscribe อยู่จริง**)
- Software Architect: กลไก auto-refund (trigger จาก DB → edge function หรือ worker แบบ `food-unpaid-timeout`), retry/reconcile, การ expire session ตอนยกเลิก
- Database Engineer: migration additive (ไม่ destructive) สำหรับสถานะ/คิวคืนเงิน และแก้ `food_apply_stripe_event` กรณี paid-after-cancel
- UI/UX: ตัวเลือกพร้อมเพย์บนหน้าชำระเงิน ZOKY และสถานะคืนเงิน (ลูกค้า/ร้าน)
- QA & Security: ทดสอบใน Stripe test mode เท่านั้น ด้วย synthetic data
- Production freeze / release gates เดิม — edge functions ที่กระทบ: `food-stripe-checkout`, `stripe-webhook`, `merchant-stripe-refund`, `food-unpaid-timeout`, (ใหม่) worker คืนเงิน

## Priority

**P0 (ต้องมีถึงจะถือว่าทำตามคำขอ)**
1. R2 คืนเงินอัตโนมัติเมื่อร้านยกเลิกออเดอร์ Stripe ที่จ่ายแล้ว + retry + idempotency + จัดการ `refund.failed`
2. R3 กันเงินค้าง: expire session ตอนยกเลิก และคืนอัตโนมัติเมื่อจ่ายหลังยกเลิก/หมดเวลา
3. R1.1–R1.3 ตัวเลือก "พร้อมเพย์ · ยืนยันอัตโนมัติ" ที่ชัดเจนสำหรับร้านที่ Stripe PromptPay active
4. R4.1–R4.2 ลูกค้าและร้านเห็นสถานะคืนเงิน + แจ้งเตือน

**P1**
- R1.4 บันทึกวิธีจ่ายจริง (card/promptpay) สำหรับรายงาน
- R4.3 หน้า Admin อ่านอย่างเดียว: คืนเงินค้าง/ล้มเหลว
- ช่วยร้านที่ PromptPay ยัง pending/inactive ให้เปิดได้ (ข้อความ/ลิงก์ใน merchant setup)
- คืน charge ซ้ำอัตโนมัติ (double payment)

**P2**
- Reconcile จาก Stripe แบบรายวัน (เทียบออเดอร์ cancelled+paid ที่ยังไม่ refund)
- คืนเงินบางส่วน (เฉพาะถ้า Founder อนุมัติใน D4)
- Admin สั่งคืนเงินได้เอง (เฉพาะถ้า Founder อนุมัติ — เป็นการเปลี่ยน payment authority)

## Risks

| ความเสี่ยง | ระดับ | หมายเหตุ |
|---|---|---|
| คืนเงินซ้ำ/คืนผิดออเดอร์ = เสียเงินจริง | สูง | บังคับ idempotency + ล็อกแถว + test |
| เงินค้างจากจ่ายหลังยกเลิก (มีอยู่แล้วตอนนี้ — E1) | สูง | P0 |
| ยอดในบัญชี Stripe ร้านไม่พอคืน (payout ไปแล้ว) → refund ล้มเหลวหรือ balance ติดลบ | สูง | พฤติกรรม/ความรับผิดชอบ **ต้องตรวจสอบกับ Stripe** + Founder ตัดสิน D5 |
| Stripe PromptPay ในไทย: การรองรับต่อบัญชี Connect, วงเงินต่อรายการ, ค่าธรรมเนียม, ระยะหมดอายุ QR, การคืนเงิน (รองรับหรือไม่/ระยะเวลาคืนเข้าบัญชีลูกค้า/ช่องทางที่คืน) | สูง | **ต้องตรวจสอบกับ Stripe ทั้งหมด** — repo ยืนยันได้แค่ว่าโค้ดอ่านสถานะ `promptpay` จาก payment method configuration และพยายามเปิดให้ ไม่ได้ยืนยันว่าบัญชีร้านจริงได้ active |
| ค่าธรรมเนียม Stripe เมื่อคืนเงิน (ร้านเสียค่าธรรมเนียมเดิมหรือไม่) | กลาง | **ต้องตรวจสอบกับ Stripe**; กระทบร้านโดยตรง → D2 |
| Webhook มาช้า/ซ้ำ/ไม่มา | กลาง | มี dedupe (`food_stripe_webhook_events`) แล้ว ต้องมี reconcile (P2) |
| ร้านส่วนใหญ่อาจยังไม่มี Stripe ready → ประโยชน์จำกัด | กลาง | ต้องดูตัวเลขร้านจริง (ไม่ได้ตรวจ — ห้ามเชื่อม DB จริง) |
| เวอร์ชัน `merchant_set_refund_status` บน production ไม่ชัด (C4) | กลาง | ทีมต้องตรวจด้วย read-only workflow `food-payment-integrity-readonly-check.yml` |
| ติด production freeze / ต้องผ่าน Founder Gate | — | ตาม `AGENTS.md` |

## Recommendation

1. ทำ P0 บนโครงสร้าง Stripe เดิม (direct charge เข้าร้าน) — ไม่เปลี่ยนผู้ให้บริการ ไม่ให้ WYNOS ถือเงิน
2. ให้ "คืนเงินอัตโนมัติ" ใช้กับ**ออเดอร์ที่จ่ายผ่าน Stripe เท่านั้น** เพราะเงิน QR/สลิปอยู่ในบัญชีพร้อมเพย์ร้าน ระบบดึงคืนไม่ได้
3. แก้ช่องโหว่ E1 (จ่ายหลังยกเลิก) ก่อนหรือพร้อมกับงานนี้ เพราะเป็นความเสี่ยงที่มีอยู่แล้วบน production
4. ก่อนเริ่ม implement ให้ Founder/ทีมตรวจกับ Stripe ในหัวข้อ "ต้องตรวจสอบกับ Stripe" และตรวจว่าร้านจริงกี่ร้านมี PromptPay active

## สิ่งที่ Founder ต้องตัดสินใจ

- **D1 — ร้านที่ยังไม่มีพร้อมเพย์อัตโนมัติ (Stripe):** (ก) ยังให้ใช้ QR ร้าน + แนบสลิปเหมือนเดิม *(แนะนำในช่วงแรก)* (ข) ให้จ่ายได้เฉพาะบัตร (ค) ร้านต้องเปิดพร้อมเพย์อัตโนมัติก่อนถึงจะรับออเดอร์ได้ — ข้อ ค เป็นการเปลี่ยนเงื่อนไขร้านค้าอย่างมาก
- **D2 — ค่าธรรมเนียมตอนคืนเงิน:** ถ้า Stripe ไม่คืนค่าธรรมเนียมให้ ใครรับ? (ก) ร้าน (เป็นแบบนี้อยู่แล้วตาม direct charge) (ข) WYNOS ช่วยออก — ข้อ ข คือค่าใช้จ่ายของบริษัท
- **D3 — ลูกค้ายกเลิกเองหลังจ่ายแล้วได้ไหม?** ตอนนี้ไม่ได้ (ต้องติดต่อร้าน) (ก) คงเดิม — คืนอัตโนมัติเฉพาะร้านยกเลิก/จ่ายหลังยกเลิก *(แนะนำ ไม่ขยาย scope)* (ข) ให้ลูกค้ายกเลิกได้ก่อนร้านรับออเดอร์ แล้วคืนอัตโนมัติ
- **D4 — คืนเงินบางส่วน:** (ก) ยังไม่ทำ คืนเต็มจำนวนเท่านั้น *(แนะนำ — ไม่อยู่ในคำขอ)* (ข) ทำ
- **D5 — คืนเงินไม่สำเร็จ (เงินในบัญชีร้านไม่พอ):** (ก) แจ้งร้านให้แก้ + Admin ติดตาม (ข) WYNOS สำรองจ่ายคืนลูกค้าก่อน — ข้อ ข WYNOS รับความเสี่ยงเงินเอง
- **D6 — ร้านยกเลิกหลัง "กำลังส่ง" แล้ว:** ยังคืนเงินเต็มอัตโนมัติไหม? (ก) คืนเต็ม *(แนะนำ — ตรงกับพฤติกรรมปัจจุบันที่ตั้งรอคืนเงิน)* (ข) ให้ร้านตัดสินเอง

## Handoff

- ถัดไป: Founder ตอบ D1–D6 → CTO review → Software Architect ออกแบบ auto-refund/retry/expire-on-cancel → UI/UX + Database → Full-Stack → QA & Security (Stripe test mode, synthetic data) → CTO final → Staging → Founder Gate
- ต้องตรวจสอบกับ Stripe ก่อน design เสร็จ: PromptPay availability/limits/fees/QR expiry/refund support สำหรับ Connect ในไทย, ค่าธรรมเนียมเมื่อคืนเงิน, balance ติดลบเมื่อคืนหลัง payout
- ข้อจำกัดของการวิเคราะห์นี้: อ่านจากโค้ดใน repo เท่านั้น ไม่ได้เชื่อม DB/Stripe จริง ไม่ทราบว่าร้านจริงกี่ร้านมี PromptPay active และไม่ทราบว่า migration ระดับ root ไฟล์ไหนถูก apply ล่าสุดบน production
- ยังไม่ได้สร้าง task ใน `.wyn/tasks/backlog/` และยังไม่ได้ commit (ตามคำสั่ง)
