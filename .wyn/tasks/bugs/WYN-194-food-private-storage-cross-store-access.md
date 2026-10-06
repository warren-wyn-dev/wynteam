# Bug Report — WYN-194 — WYNOS Food storage is shared across stores

Status: released — verified on production 2026-10-06
Owner: AI Debug Engineer
Severity: CRITICAL เมื่อมีร้านที่ 2 (สลับ QR รับเงิน) / ตอนนี้มีร้านเดียว ผลกระทบจริงยังเป็นศูนย์
Founder: "แก้ปัญหาให้หน่อย แล้วQA" (2026-10-03)

Bug:
1. `food-private` (`migrations_wynos_food_customer_access_gate_v2.sql`) ใช้ `food_has_merchant_access(null)` ซึ่งเป็นจริงสำหรับสมาชิกร้าน**ใดก็ได้** → อ่าน/อัปโหลด/แก้/ลบ สลิปโอนเงินและรูปส่งของของทุกร้าน
2. `food-public` (`migrations_wynos_food_merchant_v1.sql`) เขียน/แก้/ลบได้ทุก path ด้วยเงื่อนไขเดียวกัน → ร้าน B เขียนทับรูป PromptPay QR ของร้าน A (`stores/<A>/payment/...`) ให้ลูกค้าโอนเงินผิดบัญชีได้
Reproduction: บัญชีเจ้าของร้าน B สร้าง signed URL ของ `delivery/<order ร้าน A>/...` หรือ `upload(..., upsert)` ทับ `stores/<A>/payment/<file>` → สำเร็จ
Root Cause: storage policy ตรวจแค่ "เป็น merchant สักร้าน" ไม่ผูก path กับร้านเจ้าของไฟล์
Fix: `supabase/migrations_wynos_food_storage_store_isolation_v1.sql`
- private read: ร้านเห็นเฉพาะ `delivery/<order>/` และสลิป `<buyer>/slips/<order>/` (หรือ `payment_slip_path`) ของออเดอร์ในร้านตัวเอง; ลูกค้าเหมือนเดิม
- private upload: ร้านอัปโหลดได้เฉพาะ `delivery/<order>/<file>` ของออเดอร์ร้านตัวเองที่ `out_for_delivery` ด้วยบทบาทส่งของ; ลูกค้าเหมือนเดิม
- private update/delete: ไม่มีใครแก้/ลบผ่าน API ได้แล้ว ทั้งร้านและลูกค้า (QA M2: ลูกค้าเคยเปลี่ยนสลิปหลังร้านยืนยันเงินเข้าได้); client upload แบบ `upsert:false` อยู่แล้ว
- public write: เฉพาะ `stores/<store_id>/...` โดย owner/admin/manager ของร้านนั้น; public read เหมือนเดิม
- developer bypass ใน migration รุ่นแรกถูกถอดออกภายหลังโดย WYN-213; effective production helper ณ 2026-10-06 ต้องมี membership/legacy staff role ของร้านจริง
Files Changed: migration ใหม่ + `web/tests/browser/wynos-merchant.spec.ts`
Tests: local PostgreSQL 16 + RLS stubs — owner A เห็นเฉพาะไฟล์ร้าน A, owner B เฉพาะร้าน B, ลูกค้าเห็นของตัวเองครบ; B อัปโหลดเข้าออเดอร์ A / ทับ-ลบ-เพิ่ม QR ของ A → ถูกปฏิเสธ; คนส่ง A อัปโหลดออเดอร์ที่ยังไม่ออกส่ง / nested path / store media → ถูกปฏิเสธ; ร้านลบหลักฐาน → 0 แถว; contract test ผ่าน 3 projects
Regression Risk: กลาง — merchant/customer media ทั้งหมด; ไฟล์ food-public เดิมที่ไม่อยู่ใต้ `stores/<id>/` แก้ไม่ได้แล้ว (อ่านได้ตามเดิม)
Rollback: re-run policies เดิมจาก 2 ไฟล์ข้างบน
Tests (เพิ่ม): `supabase/tests/wynos_food_delivery_storage_test.sh`
Handoff to QA: ใช่ — QA round 1 ผ่านส่วน WYN-194, M2 แก้แล้ว

Production verification (2026-10-06):
- ตรวจ effective policies/functions ใน Supabase production แล้ว: private reads ผูกกับ order/store, merchant delivery upload ผูกกับ order ร้านตัวเองและสถานะ out_for_delivery, private evidence ไม่มี update/delete policy, public media write ผูกกับ stores/<store_id>/.
- ตรวจ effective food_store_media_writable(), merchant_has_store_role() และ food_has_merchant_access() แล้วไม่พบ developer cross-store bypass.
- ข้อความเดิมที่ว่า migration ยังไม่ apply production เป็นสถานะเก่าและถูกปิดด้วย verification นี้.
