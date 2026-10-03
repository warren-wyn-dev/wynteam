# Bug Report — WYN-194

Status: bugs — รอ Founder ตัดสินใจ (security policy)
Owner: AI Debug Engineer
Severity: HIGH เมื่อมีร้านที่ 2 (ตอนนี้มีร้านเดียว ผลกระทบจริงยังเป็นศูนย์)

Bug: storage policies ของ bucket `food-private` (`migrations_wynos_food_customer_access_gate_v2.sql`) ใช้ `public.food_has_merchant_access(null)` ซึ่งคืน true สำหรับสมาชิก/พนักงานของร้าน**ใดก็ได้** จึงอ่าน อัปโหลด แก้ และลบไฟล์ทั้ง bucket ได้ รวมถึงสลิปโอนเงินและรูปส่งของของลูกค้าร้านอื่น
Reproduction: บัญชีที่เป็นพนักงานร้าน A ขอ signed URL ของ `delivery/<order ร้าน B>/...` หรือ `<buyer_id>/slips/...` ของออเดอร์ร้าน B → ได้
Root Cause: policy ตรวจแค่ "เป็น merchant" ไม่ได้ตรวจว่าไฟล์เป็นของออเดอร์ในร้านตัวเอง
Fix (เสนอ): ผูก path กับออเดอร์ → `food_has_merchant_access(o.store_id)` ผ่าน `food_orders` (delivery/<order_id>/, และ slip path ที่อ้างใน `food_orders.payment_slip_path`)
Files Changed: —
Tests: ต้องมี test พนักงานร้าน A เข้าถึงไฟล์ร้าน B ไม่ได้
Regression Risk: กลาง (merchant/customer media ทั้งหมด)
Handoff to QA: หลัง Founder อนุมัติแก้ security policy; ต้องแก้ก่อนเปิดรับร้านที่ 2
