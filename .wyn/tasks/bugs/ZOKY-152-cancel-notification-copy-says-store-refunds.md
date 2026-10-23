# Bug Report — ZOKY-152

Status: bugs (still open, LOW, Re-test 2 2026-10-23: the text in internal.food_order_status_notify is unchanged; acceptable to defer with a CTO/PM decision)
Owner: AI Debug Engineer
Severity: LOW (Thai copy)

Bug: The existing `internal.food_order_status_notify` still sends "ออเดอร์ #… ถูกร้านยกเลิก · ร้านจะคืนเงินให้คุณ" when a store cancels a paid order. For Stripe-paid orders the refund is now automatic, so this contradicts the in-app "ระบบกำลังคืนเงิน…อัตโนมัติ", and for PromptPay the customer must also answer Stripe's email (ZOKY-147). The merchant-side failure copy only names the Stripe balance as a cause.
Reproduction: `DB=qa7`: `select reason from public.notifications` after any store cancel of a Stripe-paid order.
Fix: for payment_provider='stripe', send "ระบบจะคืนเงินเต็มจำนวนให้อัตโนมัติ (ชำระด้วยพร้อมเพย์: กรุณาตรวจอีเมลจาก Stripe)". This needs an additive trigger or notify change, which is out of the "no RPC redefinition" rule, so it needs a CTO call.
