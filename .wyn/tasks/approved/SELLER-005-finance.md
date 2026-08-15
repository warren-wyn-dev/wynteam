# Product Task — SELLER-005

Status: backlog
Owner: AI Product Manager

Feature: ZOKY Sellers by WYN — Finance (Gross Sales / ZOKY Fee / Net Revenue / Balance / Transaction History / Payout — คำนวณจากข้อมูลที่มีอยู่แล้ว ไม่มี Payment Gateway จริง)

Goal: แทนที่ tab "การเงิน" ที่ยังเป็น `SellerComingSoonScreen` placeholder ด้วยหน้าจอการเงินจริง ให้ seller เห็นรายได้/ค่าธรรมเนียม/ยอดสุทธิที่ชัดเจน ตรวจสอบย้อนหลังได้ทีละคำสั่งซื้อ — เป็น task สุดท้าย (5/5) ของ Phase 4 (ZOKY Sellers by WYN) ปิดจบวงจร Dashboard (SELLER-001) → Product (SELLER-002) → Order (SELLER-003) → Store (SELLER-004) → **Finance (SELLER-005)**

Target User: Seller ที่มีร้านค้าแล้ว (SELLER-001) และมีคำสั่งซื้อที่จบ flow จริงแล้ว (ผ่าน SELLER-003's 8-state order lifecycle)

Problem: SELLER-001 Dashboard ให้ seller เห็นแค่ยอดขายคร่าว ๆ 3 ช่วงเวลา (วันนี้/เดือนนี้/ทั้งหมด) จากผลรวม `orders.total` ของ order ที่ `delivered` เท่านั้น — ไม่มีการแยกว่าเท่าไหร่คือค่าธรรมเนียมแพลตฟอร์ม เท่าไหร่คือยอดสุทธิที่ seller ได้จริง ไม่มีรายการย้อนหลังทีละคำสั่งซื้อให้ตรวจสอบ และไม่มีแนวคิดเรื่อง "ยอดคงเหลือสะสม" เลย — tab "การเงิน" ยังเป็น placeholder "เร็ว ๆ นี้" มาตั้งแต่ SELLER-001

Requirements:

## 0. ขอบเขต/สถาปัตยกรรมที่ตัดสินใจแล้วก่อนเริ่ม (อ้างอิง DECISIONS.md, roadmap doc)

- **ไม่มี Payment Gateway จริง** (ยืนยันซ้ำจาก DECISIONS.md 2026-08-15 ข้อ 6 และ roadmap doc "ขอบเขตที่ยืนยันแล้วว่ายังไม่ทำ") — Finance ทั้งหมดคำนวณจาก `orders.subtotal`/`fee_percent`/`fee_amount`/`total` ที่ snapshot ไว้แล้วตั้งแต่ ZOKY-003 เท่านั้น ไม่มีการเชื่อมต่อธนาคาร/payment provider ใด ๆ
- **ไม่ต้องสร้างตาราง/คอลัมน์ใหม่ในรอบนี้** — ข้อมูลที่มีอยู่แล้วพอคำนวณ Gross Sales/ZOKY Fee/Net Revenue/Balance ได้ครบ (ดูข้อ 2) เพราะ ZOKY-003 ออกแบบให้ทุก Order snapshot `subtotal`+`fee_percent`+`fee_amount`+`total` ไว้ตั้งแต่ตอนสร้างแล้ว ไม่ต้อง query ย้อนหลังจาก `platform_config` (ค่าที่แก้ในอนาคตจะไม่กระทบ Order เก่า ตามที่ ZOKY-003 ตั้งใจไว้) — ตรงตามที่ roadmap doc ระบุไว้ตรง ๆ ว่า SELLER-005 "ใช้ fee config เดิมจาก ZOKY-003" ไม่ใช่สร้างระบบใหม่
- **ไม่แตะ RLS เดิมเลย** — `orders`/`order_items` select policy ของ seller ที่ SELLER-001 เพิ่มไว้แล้ว (`exists (... stores.owner_id = auth.uid())`) เพียงพอสำหรับทุก query ของ Finance ทั้งหมด (อ่านอย่างเดียว ไม่มี write ใด ๆ ในหน้านี้เลย) — งานนี้เป็น **read-only feature ล้วน**
- **ห้ามแก้ `SellerRepository`'s เมธอดเดิมที่ SELLER-001 สร้างไว้และผ่าน QA แล้ว** (`fetchOrderCounts`/`fetchSalesSummary`/`fetchBestSellingProducts`) — Dashboard ต้องยังทำงาน/แสดงตัวเลขเหมือนเดิมทุกประการ ไม่มี regression เพิ่มเมธอดใหม่แยกต่างหากสำหรับ Finance เท่านั้น (ยอมรับ query ซ้ำซ้อนเล็กน้อยระหว่าง Dashboard/Finance เพื่อแลกกับความเสี่ยง regression เป็นศูนย์บนโค้ดที่ QA ผ่านแล้ว — เหตุผลเดียวกับที่ SELLER-002/003 เคยเลือกไม่แตะฟังก์ชันเดิมโดยไม่จำเป็น)

## 1. โมเดลตัวเลข: Gross Sales / ZOKY Fee / Net Revenue (สูตรที่ต้องใช้ตรงกันทุกจุด)

อ้างอิงจากกลไกจริงที่ ZOKY-003 implement ไว้ใน `create_orders()`: ตอน checkout ผู้ซื้อเห็นและยืนยันจ่าย **`total` = `subtotal` (ราคาสินค้ารวม) + `fee_amount` (ค่าธรรมเนียมแพลตฟอร์ม ที่คำนวณจาก `subtotal * fee_percent / 100` ตอนสร้าง Order)** — ค่าธรรมเนียมถูกคิดเพิ่มเข้าไปในยอดที่ผู้ซื้อจ่าย ไม่ใช่หักออกจากยอดที่ seller ได้ตรง ๆ ในขั้นตอน checkout แต่ในทางบัญชีของ seller แล้ว ค่าธรรมเนียมนี้คือส่วนที่ ZOKY เก็บไว้เป็นรายได้แพลตฟอร์ม ไม่ใช่ของ seller เพราะฉะนั้นนิยามที่ตรงและสอดคล้องกับ Dashboard เดิมทุกจุดคือ:

- **Gross Sales (ยอดขายรวม)** = ผลรวม `orders.total` ของ order สถานะ `delivered` — **ตัวเลขเดียวกันเป๊ะกับที่ SELLER-001 Dashboard เรียกว่า "Sales/Revenue" อยู่แล้ว** (ไม่ใช่ตัวเลขใหม่ที่ขัดแย้งกัน — Finance แค่แตกรายละเอียดเพิ่มจากตัวเลขเดิมที่ seller คุ้นเคยแล้ว)
- **ZOKY Fee (ค่าธรรมเนียมแพลตฟอร์ม)** = ผลรวม `orders.fee_amount` ของ order สถานะ `delivered`
- **Net Revenue (ยอดสุทธิที่ seller ได้รับจริง)** = Gross Sales − ZOKY Fee = ผลรวม `orders.subtotal` ของ order สถานะ `delivered` (เท่ากันทางคณิตศาสตร์เป๊ะ เพราะ `total = subtotal + fee_amount` เสมอ) — แสดงทั้งสองทาง (สูตรลบ และผลรวม subtotal ตรง ๆ) ต้องได้ค่าตรงกัน ใช้เป็น cross-check ระหว่าง Design/Coding/QA ได้
- ทั้ง 3 ตัวเลขคำนวณแยกตาม **3 ช่วงเวลาเดียวกับ Dashboard เดิม**: วันนี้ / เดือนนี้ / ทั้งหมด (ใช้ `created_at` เป็นตัวแบ่งช่วงเหมือน `fetchSalesSummary` เดิมทุกประการ — ดู Known Issue ข้อ 1 ใน Risks เรื่องข้อจำกัดของการใช้ `created_at` แทน "วันที่ delivered จริง")

## 2. สถานะไหนนับเป็นรายได้ (ตัดสินใจให้สอดคล้องกับ Dashboard เดิม)

- **นับเฉพาะ `delivered` เท่านั้น** เข้า Gross Sales/ZOKY Fee/Net Revenue/Balance — ตรงกับที่ `fetchSalesSummary`/`fetchBestSellingProducts` (SELLER-001) ใช้เกณฑ์นี้อยู่แล้ว **ไม่เปลี่ยนเกณฑ์เดิม** — เหตุผลเดิม: ลูกค้ายืนยันได้รับสินค้าแล้วเท่านั้นถึงจะถือว่าธุรกรรมจบสมบูรณ์จริง
- **`shipped` (จัดส่งแล้ว แต่ยังไม่ delivered) ไม่นับเข้า Gross/Net/Balance** — แต่ต้องแสดงแยกต่างหากเป็น **"รายได้ระหว่างทาง (รอผู้ซื้อยืนยันรับสินค้า)"**: 1 ตัวเลขสรุป (ผลรวม `subtotal` ของ order `shipped` ของร้านตัวเอง + จำนวน order) ไม่ต้องแตก Gross/Fee/Net แยกสามตัวเลข (ลดความซับซ้อนของ UI ให้ seller เข้าใจง่ายว่า "นี่คือเงินที่กำลังจะเข้า ไม่ใช่เข้าแล้ว") — วางไว้เป็น section แยกชัดเจนจาก Balance การ์ดหลัก ป้องกันไม่ให้ seller เข้าใจผิดว่าเป็นเงินที่ใช้ได้แล้ว
- **`paid`/`seller_processing`/`ready_to_ship`/`pending_payment`/`cancelled`/`refunded` ไม่นับเป็นรายได้ที่ "รอเข้า" เลย** (ต่างจาก `shipped`) — เหตุผล: 4 สถานะแรกยังห่างจากการส่งมอบสำเร็จเกินไป (มีโอกาสถูกยกเลิกได้ตลอดจนถึง `ready_to_ship`) การนับเป็น "รอเข้า" จะทำให้ seller คาดหวังเงินที่อาจไม่เกิดขึ้นจริง ส่วน `cancelled`/`refunded` ชัดเจนอยู่แล้วว่าไม่ใช่รายได้

## 3. Order ที่เคย `delivered` แล้วถูกเปลี่ยนเป็น `refunded` ภายหลัง (SELLER-003's `seller_mark_refunded`, source `shipped`/`delivered`)

นี่คือจุดที่กระทบ **trust** ของ seller โดยตรงถ้าไม่สื่อสารให้ถูกต้อง (ตามที่ Founder เน้นย้ำ) — ต้องออกแบบให้ชัดเจน ไม่ใช่ปล่อยให้ตัวเลขหายไปเงียบ ๆ:

- ทุก query ของข้อ 1-2 เป็น **query สดกรอง `status = 'delivered'` ตรง ๆ ทุกครั้งที่เปิดหน้า** (หลักการเดียวกับ `fetchSalesSummary`/rating ของ ZOKY-004 — "ทุกค่าคำนวณจาก query สดทุกครั้ง ไม่ cache") — ดังนั้น order ที่เพิ่งถูกเปลี่ยนจาก `delivered` เป็น `refunded` จะ **หลุดออกจากตัวส่วน Gross/Fee/Net/Balance โดยอัตโนมัติในการโหลดครั้งถัดไป** เพราะไม่ตรงเงื่อนไข `status = 'delivered'` อีกต่อไป — นี่คือพฤติกรรมที่ถูกต้องตามธุรกิจ (คืนเงินแล้ว ไม่ควรนับเป็นรายได้อีก) แต่ **ต้องไม่ปล่อยให้หายไปเงียบ ๆ โดยไม่มีคำอธิบาย**
- แก้ปัญหาด้วย **Transaction History (ข้อ 4)**: แสดงทั้ง order ที่ `delivered` (นับรวม) และ `refunded` (ไม่นับรวมแล้ว แต่ยังโชว์ในประวัติ พร้อม label "คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ" ชัดเจน ตัดเส้นทับตัวเลข/ใช้สีเทาต่างจากรายการที่นับจริง) — seller ตรวจสอบย้อนหลังได้เสมอว่าทำไมยอดถึงลดลง ไม่ใช่คำถามค้างคาใจ

## 4. Transaction History (รายการย้อนหลังทีละคำสั่งซื้อ)

- แสดงเฉพาะ order ของร้านตัวเองที่สถานะ `delivered` หรือ `refunded` เท่านั้น (2 สถานะเดียวที่เกี่ยวข้องกับการคำนวณ Balance — สถานะอื่นไม่ต้องโผล่ในนี้ ดูได้จาก tab "คำสั่งซื้อ" อยู่แล้วถ้าต้องการ) เรียงใหม่สุดก่อน มี pagination (มิเรอร์ `ordersPageSize = 20` เดิมจาก SELLER-003)
- แต่ละแถวแสดง: วันที่ (created_at), เลข/อ้างอิง order, ชื่อผู้ซื้อ (`recipient_name` เหมือนที่ `SellerOrderListTile` ใช้), subtotal/fee_amount/net (= subtotal) ต่อรายการ, สถานะ (delivered=นับรวม / refunded=ไม่นับรวม+label อธิบาย)
- แตะรายการ → เปิด `SellerOrderDetailScreen` เดิมจาก SELLER-003 ตรง ๆ (reuse หน้าจอเดิม ไม่สร้างหน้า detail ใหม่ซ้ำ — Order Detail มีข้อมูลครบอยู่แล้วรวม shipping/สถานะ)
- Empty state: "ยังไม่มีประวัติรายรับ" เมื่อยังไม่มี order `delivered`/`refunded` เลย

## 5. Balance (ยอดคงเหลือ — คำนวณ ไม่ใช่เงินจริง)

- **Balance = Net Revenue สะสมทั้งหมด (all-time)** = ผลรวม `subtotal` ของทุก order สถานะ `delivered` ของร้านตัวเอง ณ ขณะนี้ (คำนวณสดทุกครั้ง ไม่หักด้วยอะไรเลยเพราะไม่มี Payout จริงเกิดขึ้นได้เลยรอบนี้ — ดูข้อ 6) — **ตัวเลขเดียวกับ "Net Revenue ทั้งหมด" ในข้อ 1** แสดงซ้ำในรูปแบบการ์ดเด่น (Balance card) เพื่อให้ seller เห็นภาพรวมได้เร็วที่สุดโดยไม่ต้องไล่อ่านตาราง 3 ช่วงเวลา
- **ต้องมีข้อความกำกับ Balance card ชัดเจนทุกครั้งที่แสดง** (ไม่ใช่แค่ครั้งแรก) ทำนองว่า **"ยอดนี้เป็นตัวเลขคำนวณจากคำสั่งซื้อที่ลูกค้าได้รับสินค้าแล้วเท่านั้น ไม่ใช่เงินในบัญชีธนาคารจริง เนื่องจากยังไม่มีระบบชำระเงิน/โอนเงินเชื่อมต่อ"** — ห้ามใช้คำที่สื่อว่า "พร้อมถอน"/"ยอดเงินในบัญชี" ตรง ๆ (เช่น ห้ามใช้คำว่า "ยอดเงินคงเหลือในบัญชี" เฉย ๆ โดยไม่มีคำอธิบายกำกับ) — นี่คือความเสี่ยงด้าน trust/legal ที่ Founder เน้นย้ำโดยตรง ต้องปฏิบัติตามเป๊ะ ไม่ใช่แค่ทางเลือก

## 6. Payout (ปุ่ม "ถอนเงิน")

- **ปุ่มต้องแสดงอยู่เสมอ ไม่ซ่อน** (seller ควรรู้ว่ามี feature นี้อยู่ในอนาคต ไม่ใช่หายไปจากหน้าจอเฉย ๆ) — แต่ **ต้อง disable** (กดไม่ได้จริง ไม่ทำอะไรเลย ไม่ trigger flow ใด ๆ เพราะไม่มี backend รองรับ)
- แตะปุ่มที่ disable แล้ว (หรือมีปุ่ม/ไอคอน "ⓘ" ข้าง ๆ) ต้องแสดงคำอธิบายชัดเจน (dialog/bottom sheet สั้น ๆ) ว่า **"ยังไม่รองรับการถอนเงินในเวอร์ชันนี้ เนื่องจากยังไม่มีระบบชำระเงิน (Payment Gateway) เชื่อมต่อกับแพลตฟอร์ม ยอดคงเหลือที่แสดงเป็นตัวเลขคำนวณเพื่อการติดตามเท่านั้น"** — ไม่ใช่แค่ disable เฉย ๆ โดยไม่มีคำอธิบาย (ตรงตามที่โจทย์ระบุ: "ต้อง disable + ข้อความอธิบายชัดเจน ไม่ใช่ซ่อนไปเฉยๆ")
- **ไม่มี Payout History จริงในรอบนี้** (ไม่มี transaction การถอนเงินใด ๆ เกิดขึ้นได้เลย เพราะปุ่มถูก disable ตลอด) — ถ้า master prompt Section 17 พูดถึง "Payout History" ให้ตีความว่าเป็น**ส่วนขยายในอนาคตเมื่อมี Payment Gateway จริง** ไม่ใช่สิ่งที่ทำได้ในรอบนี้ — บันทึกเป็น Known Issue ชัดเจน ไม่ใช่การมองข้าม (เหตุผลเดียวกับ SELLER-001's Balance/Payout placeholder เดิม)

## 7. ค่าธรรมเนียมแพลตฟอร์มปัจจุบัน (ข้อมูลเสริม)

- แสดงบรรทัดเล็ก ๆ (ไม่ใช่การ์ดใหญ่) บอกอัตราค่าธรรมเนียมปัจจุบันที่อ่านจาก `platform_config` (`key = 'zoky_marketplace_fee_percent'`) เช่น "ค่าธรรมเนียมแพลตฟอร์มปัจจุบัน: 10%" พร้อมข้อความกำกับ **"อัตรานี้ใช้กับคำสั่งซื้อใหม่เท่านั้น ไม่กระทบยอดของคำสั่งซื้อเก่าที่บันทึกอัตราไว้แล้วตอนสั่งซื้อ"** (ย้ำหลักการ snapshot ของ ZOKY-003 ให้ seller เข้าใจว่าทำไมยอดในประวัติไม่เปลี่ยนแม้ % จะถูกปรับ) — `platform_config` มี select policy ให้ authenticated user ทุกคนอ่านได้อยู่แล้ว ไม่ต้องเพิ่ม RLS

## 8. Export/CSV — **Defer ไปเป็น fast-follow ไม่ทำรอบนี้**

- ไม่มีการอ้างอิงถึง export/รายงานใน scope ที่ roadmap doc ระบุไว้ (Section 17/18 ของ master prompt ที่บันทึกสรุปไว้เน้น Gross/Fee/Net/Balance/Payout History เท่านั้น) — Transaction History ในหน้าจอ (ข้อ 4) ให้ข้อมูลตรวจสอบย้อนหลังได้แล้วในระดับที่เพียงพอสำหรับ V1
- เหตุผลที่ defer: (1) ทุก task ของ Phase 4 ที่ผ่านมายึดหลัก "ขอบเขตเล็กที่สุดเท่าที่ยังมีประโยชน์จริง" เสมอ (SELLER-001's Dashboard ไม่ทำ Balance/Payout, ZOKY-003 ไม่ทำ saved address book) — export ไฟล์เป็นงานคนละขนาด (ต้องคิดเรื่อง format/ช่วงเวลาที่เลือกได้/การส่งไฟล์ในแอป mobile) ที่ไม่ได้ถูกขอชัดเจน (2) ยังไม่มีการใช้งานจริงจาก seller คนไหนเลยที่จะยืนยันว่าจำเป็นจริง — เสนอเก็บเป็น fast-follow ถ้า Founder หรือ seller จริงร้องขอหลังใช้งาน

## 9. Screen/Repository ที่ต้องทำ (สรุปทางเทคนิคสำหรับ Design/Coding)

- Tab "การเงิน" (index 4) ของ `SellerHomeShell` เปลี่ยนจาก `const SellerComingSoonScreen(label: 'การเงิน')` เป็น `SellerFinanceScreen` จริง (ชื่อคลาสเสนอ ให้ Design ยืนยัน/ปรับได้)
- `SellerRepository` เพิ่มเมธอดใหม่ (ไม่แก้ของเดิม): เมธอดคำนวณ Gross/Fee/Net ทั้ง 3 ช่วงเวลา, เมธอดคำนวณรายได้ระหว่างทาง (`shipped`), เมธอดดึง Transaction History แบบ paginate (`delivered`+`refunded`, อาจขยาย `fetchStoreOrders`'s filter ให้รับหลายสถานะ หรือสร้างเมธอดใหม่แยก — ให้ Design/Coding ตัดสินใจรูปแบบที่ implement สะดวกที่สุดโดยไม่กระทบ signature เดิมของ `fetchStoreOrders`), เมธอดอ่าน `platform_config`'s ค่าปัจจุบัน
- ทุกเมธอดใหม่คำนวณสดทุกครั้งที่เรียก ไม่ cache/denormalize (หลักการเดียวกับทุกจุดใน `SellerRepository` ที่มีอยู่แล้ว)

Acceptance Criteria:
- [ ] Tab "การเงิน" แสดง `SellerFinanceScreen` จริงแทน `SellerComingSoonScreen` เดิม
- [ ] Gross Sales/ZOKY Fee/Net Revenue แยก 3 ช่วงเวลา (วันนี้/เดือนนี้/ทั้งหมด) คำนวณถูกต้องจาก order สถานะ `delivered` ของร้านตัวเองเท่านั้น
- [ ] Gross Sales ของ Finance ตรงกับตัวเลข Sales/Revenue ของ SELLER-001 Dashboard เป๊ะในช่วงเวลาเดียวกัน (ไม่ใช่ตัวเลขคนละชุดที่ทำให้ seller สับสน)
- [ ] Net Revenue = Gross Sales − ZOKY Fee ถูกต้องทุกช่วงเวลา และเท่ากับผลรวม `subtotal` โดยตรง (cross-check สองทางตรงกัน)
- [ ] "รายได้ระหว่างทาง" (order `shipped`) แสดงแยกจาก Balance/Net Revenue หลัก ไม่ถูกนับรวมเข้าไปในตัวเลขหลัก
- [ ] Balance = ผลรวม Net Revenue สะสมทั้งหมด (all-time) คำนวณสดทุกครั้งที่เปิดหน้า/pull-to-refresh
- [ ] Order ที่เปลี่ยนจาก `delivered` เป็น `refunded` หลุดออกจาก Gross/Fee/Net/Balance โดยอัตโนมัติในการโหลดครั้งถัดไป และปรากฏใน Transaction History พร้อม label "คืนเงินแล้ว — ไม่นับรวม" ชัดเจน ไม่หายไปเงียบ ๆ
- [ ] Transaction History แสดงเฉพาะ order `delivered`/`refunded` ของร้านตัวเอง เรียงใหม่สุดก่อน มี pagination, แตะรายการเปิด `SellerOrderDetailScreen` เดิมได้ถูกต้อง
- [ ] Seller A (ร้าน X) มองไม่เห็นข้อมูลการเงิน/ประวัติ order ของร้าน Y เลย แม้พยายาม query ตรง ๆ (พึ่ง RLS select policy เดิมจาก SELLER-001 — ไม่มี write ใด ๆ ในหน้านี้ที่ต้องเพิ่ม RLS ใหม่)
- [ ] ปุ่ม "ถอนเงิน/Payout" แสดงอยู่เสมอ ไม่ถูกซ่อน แต่กดไม่ได้จริง (disabled) และมีข้อความอธิบายชัดเจนว่ายังไม่รองรับเพราะไม่มี Payment Gateway
- [ ] ทุกจุดที่แสดง Balance มีข้อความกำกับชัดเจนว่าเป็นตัวเลขคำนวณ ไม่ใช่เงินในบัญชีธนาคารจริง — ไม่มีจุดไหนใช้คำที่สื่อว่า "พร้อมถอน"/"เงินในบัญชี" โดยไม่มีคำอธิบายกำกับ
- [ ] แสดงอัตราค่าธรรมเนียมแพลตฟอร์มปัจจุบันถูกต้องจาก `platform_config` พร้อมข้อความอธิบายว่าไม่กระทบยอดคำสั่งซื้อเก่า
- [ ] ไม่มี Export/CSV ใด ๆ ในหน้าจอนี้ (ยืนยัน scope ตามที่ตัดสินใจ defer)
- [ ] `fetchOrderCounts`/`fetchSalesSummary`/`fetchBestSellingProducts` (SELLER-001) ไม่ถูกแก้ไข — SELLER-001 Dashboard ยังคำนวณ/แสดงผลถูกต้องเหมือนเดิมทุกประการ ไม่มี regression
- [ ] SELLER-002/003/004, ZOKY Marketplace Customer เดิมทั้งหมด, WYN Social เดิมทั้งหมด ยังทำงานปกติ ไม่มี regression
- [ ] ไม่มี schema/RLS ใหม่ถูกเพิ่มเข้า `supabase/schema.sql` เลย (ยืนยันเป็น read-only feature ล้วนบนข้อมูล/policy ที่มีอยู่แล้ว)

Dependencies: SELLER-001 (Foundation — Approved, ต้องมี `SellerRepository`/Dashboard/RLS select policy ของ orders อยู่แล้ว), SELLER-003 (Order Management — Approved, ต้องมี 8-state order lifecycle + `Order` model ที่มี `subtotal`/`feePercent`/`feeAmount`/`total` ครบอยู่แล้ว ถึงจะคำนวณ Finance ได้ถูกต้อง) — **ไม่ dependency กับ SELLER-004** (Store Management กำลังอยู่ระหว่าง QA รอบ 2 — Finance ไม่แตะข้อมูลโปรไฟล์ร้าน (โลโก้/ที่อยู่/เบอร์ติดต่อ) เลย ทำคู่ขนานกันได้โดยไม่ต้องรอ SELLER-004 ผ่าน QA ก่อน)

Priority: P0 — เป็น task สุดท้าย (5/5) ของ Phase 4 (ZOKY Sellers by WYN) เมื่อ SELLER-005 ผ่าน QA จะถือว่า Phase 4 เสร็จสมบูรณ์ครบวงจรทั้งสาย (Foundation → Product → Order → Store → Finance)

Risks:
- **Trust/Legal risk เรื่อง Balance ไม่ใช่เงินจริง (ความเสี่ยงหลักที่ต้องระวังที่สุดของ task นี้)**: ถ้าสื่อสารไม่ชัดว่า "Balance" เป็นตัวเลขคำนวณ ไม่ใช่เงินในบัญชีธนาคารจริง seller อาจเข้าใจผิดว่ามีเงินพร้อมถอนแล้วจริง ๆ นำไปสู่ความไม่พอใจ/ข้อร้องเรียน หรือแม้แต่ปัญหาด้านกฎหมายถ้ามีการอ้างอิงตัวเลขนี้เป็นหลักฐานทางการเงิน — ต้องกำกับข้อความอธิบายไว้ **ทุกจุด** ที่แสดง Balance ไม่ใช่แค่ครั้งแรกที่ seller เห็น (เช่น first-time tooltip แล้วหายไป) ต้องอยู่ถาวรบนหน้าจอหรือเข้าถึงได้ง่ายทุกครั้ง (Requirements ข้อ 5-6 ระบุไว้แล้วว่าเป็นข้อบังคับ ไม่ใช่ทางเลือก)
- **Order ที่ delivered แล้วถูก refund ภายหลัง ทำให้ตัวเลขลดลงแบบไม่มีคำเตือนล่วงหน้า**: ถ้า Transaction History (ข้อ 4) ไม่แสดงรายการ refunded ให้เห็นชัดเจนคู่กับ delivered seller จะสับสนว่า "เงินหายไปไหน" — บรรเทาแล้วด้วย AC เฉพาะ (ต้องเห็นทั้งสองสถานะพร้อม label อธิบาย) แต่ยังเป็นจุดที่ QA ต้องเน้นตรวจเป็นพิเศษ
- **`created_at` ไม่ใช่วันที่ "delivered จริง"**: ทั้ง `fetchSalesSummary` เดิม (SELLER-001) และตัวเลขใหม่ของ SELLER-005 แบ่งช่วงเวลา (วันนี้/เดือนนี้) ด้วย `orders.created_at` (วันที่สร้าง Order) ไม่ใช่วันที่สถานะเปลี่ยนเป็น `delivered` จริง — เพราะ schema ไม่มีคอลัมน์ `delivered_at` เก็บไว้เลย เป็นข้อจำกัดที่ **สืบทอดมาจาก SELLER-001 อยู่แล้ว ไม่ใช่สิ่งที่ SELLER-005 สร้างใหม่** แต่สำคัญกว่าตอนที่เป็น Finance เพราะเกี่ยวกับความแม่นยำทางบัญชีโดยตรง — order ที่สร้างวันที่ 1 แต่เพิ่งถูกยืนยันรับสินค้าวันที่ 10 จะถูกนับเข้า "ยอดวันนี้/เดือนนี้" ของวันที่ 1 ไม่ใช่วันที่ 10 — เสนอเป็น **fast-follow**: เพิ่มคอลัมน์ `delivered_at` (nullable, additive migration, บันทึกตอน `confirm_order_received()` รัน) เพื่อความแม่นยำ ไม่ทำในรอบนี้เพื่อคงขอบเขต "อ่านข้อมูลที่มีอยู่แล้วเท่านั้น ไม่แก้ schema" ตามที่ตัดสินใจไว้ในข้อ 0
- **Payout ปุ่ม disable ตลอดกาลจนกว่าจะมี Payment Gateway จริง**: เป็น scope ที่ใหญ่กว่ามาก (ต้องมี bank transfer integration, KYC/verification ของ seller, ฯลฯ) ไม่ใช่แค่ "เปิดปุ่ม" — ต้องแจ้ง Founder รับทราบชัดเจนว่านี่เป็นงานคนละขนาดในอนาคต ไม่ใช่สิ่งที่ทำต่อจาก SELLER-005 ได้ทันที
- **ไม่มี live Supabase project ให้ทดสอบ aggregation แบบ dynamic จริง**: เหมือนทุก task ก่อนหน้าตั้งแต่ ZOKY-001 — ตรวจด้วยการอ่าน query logic/สูตรคำนวณแทน

Recommendation:
1. เริ่ม Design ทันที — เป็น task สุดท้ายของ Phase 4 ความเสี่ยงด้าน data-integrity ต่ำกว่า SELLER-003 มาก (read-only ล้วน ไม่มี RPC/write ใหม่) แต่ความเสี่ยงด้าน **การสื่อสาร/UX copy** สูงที่สุดในสาย SELLER ทั้งหมด (เรื่อง Balance ไม่ใช่เงินจริง) — เน้น Design ให้ความสำคัญกับข้อความกำกับมากกว่าการจัดวาง UI สวยงาม
2. ยึดขอบเขตเล็กที่สุดตามที่ระบุ: ไม่ทำ Export/CSV, ไม่เพิ่มคอลัมน์ `delivered_at`, ไม่เปิด Payout จริง — ทั้งสามเป็น fast-follow ที่ต้องขอ Founder ตัดสินใจแยกในอนาคตถ้าต้องการ (โดยเฉพาะ Payout ที่เป็น major scope ใหม่)
3. เมื่อ SELLER-005 ผ่าน QA และ merge เข้า `main` แล้ว **Phase 4 (ZOKY Sellers by WYN) จะเสร็จสมบูรณ์ครบทั้ง 5 task** — แนะนำแจ้ง Founder ให้ทราบและรอการตัดสินใจว่าจะเริ่ม Phase 5 (เชื่อม Customer ↔ Seller ↔ Backend) ต่อทันทีหรือหยุดพักตรวจสอบภาพรวม Phase 4 ก่อน (ตามที่ Founder เคยเลือกหยุดพักระหว่าง Phase ก่อนหน้านี้ที่ ZOKY Marketplace Customer เสร็จ)
4. เน้น QA ตรวจ 2 เรื่องเป็นพิเศษ: (a) สูตร Gross−Fee=Net ตรงกับผลรวม subtotal จริงในทุก edge case (ไม่มี order เลย/มีแต่ order ที่ refunded ทั้งหมด/มีทั้ง delivered และ refunded ปนกัน) (b) ข้อความกำกับ Balance/Payout ครบทุกจุดที่ Requirements ระบุไว้ ไม่มีจุดไหนหลุดคำเตือน

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) `SellerFinanceScreen` layout — Balance card เด่น (พร้อมข้อความกำกับถาวร), การ์ด Gross/Fee/Net แยก 3 ช่วงเวลา, การ์ด "รายได้ระหว่างทาง" แยกต่างหาก, บรรทัดอัตราค่าธรรมเนียมปัจจุบัน (2) ปุ่ม Payout แบบ disabled + dialog/bottom sheet อธิบาย (3) Transaction History list (delivered/refunded, label แยกชัดเจน, pagination, tap-through ไปหน้า `SellerOrderDetailScreen` เดิม) (4) Empty state เมื่อยังไม่มีรายรับเลย — ใช้ Design system เดิมทั้งสองแอป (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass) reuse pattern จาก `SellerDashboardScreen`/`SellerOrderListScreen`/`OrderStatusBadge` ให้มากที่สุด — เมื่อ Design/Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น %

## Design Output

Status: **Design เสร็จแล้ว** — เขียนที่ `.wyn/docs/design/seller-005-finance.md`

หมายเหตุสี: ใช้ Design system ที่ implement จริงตอนนี้เท่านั้น (Blue seed `0xFF2D6CDF`, Material 3 default roles) — **ไม่ใช้** Cyan/Orange จาก `.wyn/docs/design/ds-001-color-system.md` เพราะ DS-001 ยังไม่ถูก apply เข้าโค้ดจริงในหน้าจอไหนเลยของทั้งสองแอป (จะอัปเดตพร้อมกันเป็นชุดตอน DS-001 rollout จริงในอนาคต)

สรุปการตัดสินใจหลัก:
1. **โครงหน้าจอเป็น `ListView` เดียว** รวม summary cards (Balance/Breakdown/In-transit/Fee rate) กับ Transaction History paginate ไว้ในสโครลเดียว — reuse scroll-listener pattern จาก `SellerOrderListScreen._onScroll` เป๊ะ, pull-to-refresh รีโหลดทุกอย่างพร้อมกัน
2. **Error state ใช้ explicit "ลองใหม่"** (มิเรอร์ `SellerOrderListScreen`) แทน silent-fail แบบ `SellerDashboardScreen` เดิม เพราะเป็นข้อมูลการเงินที่ต้องเชื่อถือได้ ไม่ใช่ข้อมูลเสริม
3. **ปุ่ม "ถอนเงิน" แสดงเสมอ สไตล์ muted/เทา (ไม่ใช้สี primary) แต่ `onPressed` ใช้งานได้จริงเสมอ** — เปิด bottom sheet อธิบายทุกครั้งที่แตะ (ไม่ใช่ literal Flutter `disabled` เพราะปุ่มที่ `onPressed: null` จะไม่มีทาง trigger คำอธิบายให้ screen reader/ผู้ใช้เห็นได้เลย) — ไม่มี flow ถอนเงินจริงถูก trigger ไม่ว่ากรณีใด ข้อความอธิบายเป็นคำต่อคำจาก Product spec ห้ามเปลี่ยน
4. **คำว่า "ยอดคงเหลือ"/Balance ใช้แค่จุดเดียวในหน้าจอ (Balance card)** พร้อม disclaimer ถาวรติดกับตัวเลขเสมอ (คำต่อคำจาก Product spec) — การ์ด "สรุปยอดขาย" ช่วง "ทั้งหมด" ใช้คำว่า "สุทธิ (Net Revenue)" แทน เพื่อไม่ต้องแปะ disclaimer เต็มซ้ำหลายจุดจนหน้าจอรก แต่ยังคงความหมายเดียวกันทางคณิตศาสตร์
5. **ตัวเลือกช่วงเวลา (วันนี้/เดือนนี้/ทั้งหมด) ใช้ `SegmentedButton`** แทนตาราง 9 ตัวเลขพร้อมกัน (3 ช่วง × Gross/Fee/Net) — ลดความแน่นบนจอมือถือ, ค่าเริ่มต้น "วันนี้"
6. **แถวค่าธรรมเนียม (Fee) ใช้สีเทากลาง ไม่ใช่สีแดง** (เหตุผลเดียวกับปุ่ม "ทำเครื่องหมายคืนเงินแล้ว" ของ SELLER-003 — เป็นรายการบัญชีปกติ ไม่ใช่ error) ใส่เครื่องหมาย "−" นำหน้าเพื่อไม่สื่อสารด้วยสีอย่างเดียว
7. **`SellerTransactionTile` ใหม่**: ไม่มี thumbnail, ไม่ query `order_items` (ต่างจาก `SellerOrderListTile`) — แสดงสูตร "ยอดขาย − ค่าธรรมเนียม = สุทธิ" เป็นบรรทัดเดียวต่อแถว, แถว `refunded` ขีดทับ+สีเทา+ข้อความ "คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ" กำกับเสมอ (ไม่ใช่สีอย่างเดียว), reuse `OrderStatusBadge` เดิมตรง ๆ ไม่แก้
8. **Repository**: เสนอเมธอดใหม่ 4 ตัวใน `SellerRepository` (`fetchFinanceBreakdown`/`fetchInTransitSummary`/`fetchTransactionHistory`/`fetchPlatformFeePercent`) — ไม่แก้เมธอดเดิม 4 ตัวที่ผ่าน QA แล้วเลย (`fetchOrderCounts`/`fetchSalesSummary`/`fetchBestSellingProducts`/`fetchStoreOrders`) — `allTime.net` จาก `fetchFinanceBreakdown` ใช้เป็นค่า Balance ตรง ๆ ไม่ query ซ้ำซ้อน — **หมายเหตุประสานงาน**: `seller_repository.dart` กำลังอยู่ระหว่าง QA รอบ 2 ของ SELLER-004 คู่ขนาน AI Coding ต้อง sync กับ `main` ล่าสุดก่อนเริ่ม

Handoff: ส่งต่อ AI Coding (`/code`) — รายละเอียดครบทุก Screen/Widget/Repository method/Test coverage ที่ต้อง implement อยู่ใน `.wyn/docs/design/seller-005-finance.md` ทั้งหมด (รวม "เตือน Coding" 7 ข้อท้ายเอกสารที่ย้ำจุดเสี่ยงจาก Product spec's Risks — โดยเฉพาะข้อความ disclaimer ต้องตรงคำต่อคำ, cross-check สูตร Gross−Fee=Net ทุก edge case, ปุ่มถอนเงินห้าม trigger network call ใด ๆ)

## QA Output

Status: **PASS (รอบ 1)** — ทดสอบเมื่อ 2026-08-15 หลัง sync branch `claude/pwd-nxsvf5` ตรงกับ `origin/main` ที่ commit `bd68eee` (PR #116)

### สรุปขอบเขตที่ตรวจ

`git diff` เทียบ commit ก่อน PR #116 (`3f6de4e`, หลัง SELLER-004 QA รอบ 2 PASS) ยืนยันไฟล์ที่เปลี่ยนแปลงทั้งหมดอยู่ใน `seller_app/`/`.wyn/` เท่านั้น (10 ไฟล์, +1585/-15) — **ไม่แตะ `supabase/schema.sql` และ `app/` เลยแม้แต่บรรทัดเดียว**:
- ใหม่: `seller_app/lib/features/finance/presentation/seller_finance_screen.dart`, `.../widgets/seller_transaction_tile.dart`, test 3 ไฟล์, `.wyn/docs/design/seller-005-finance.md`
- แก้ (additive เท่านั้น): `seller_app/lib/features/store/data/seller_repository.dart` (+เมธอดใหม่ 4 ตัว + class `FinancePeriodTotals`/`SellerFinanceBreakdown`), `seller_app/lib/features/shell/presentation/seller_home_shell.dart` (1 บรรทัด tab), `seller_app/test/seller_home_shell_test.dart`, `seller_app/test/support/recording_seller_repository.dart`

### (1) สูตร Gross − Fee = Net ทุก edge case

- `git diff` ยืนยัน `fetchFinanceBreakdown()` เป็นเมธอดใหม่ทั้งหมด (pure addition) ไม่แตะ `fetchSalesSummary()`/`fetchOrderCounts()`/`fetchBestSellingProducts()`/`fetchStoreOrders()` เดิมแม้แต่บรรทัดเดียว
- ตรวจ query: `select('total, subtotal, fee_amount, created_at').eq('store_id', storeId).eq('status', 'delivered')` — กรองที่ระดับ DB จริง ไม่ใช่ client-side filter ทีหลัง ดังนั้น:
  - ร้านไม่มี order เลย → rows ว่าง → ทุกค่า (`gross`/`fee`/`net`) เป็น 0 ทั้ง 3 ช่วงเวลา — ถูกต้อง (ยืนยันด้วย widget test "empty state" ที่เช็ค `find.text('฿0')`)
  - order ทั้งหมด `refunded` → query กรอง `status='delivered'` ไม่คืน row เหล่านี้เลย → breakdown เป็น 0 ทั้งหมดถูกต้อง (refunded ไม่มีทางรั่วเข้ามาในผลรวม เพราะไม่เคยถูก select เข้ามาตั้งแต่ต้น)
  - ผสม `delivered`+`refunded` → เฉพาะแถว `delivered` เท่านั้นที่ query คืนมา ยืนยันด้วย widget test เฉพาะ (`populatedRepo` มี refunded order ที่ subtotal สูงกว่า delivered โดยตั้งใจ เพื่อพิสูจน์ว่าถ้าโค้ดบัคแล้วไปคำนวณจาก transaction list แทน ค่าจะเพี้ยนทันที — ผลจริง: ค่า breakdown ไม่ถูกกระทบเลย)
  - ร้านมี order เดียว → gross=total, fee=fee_amount, net=subtotal ตรงตามสูตร
- ยืนยัน invariant `total = subtotal + fee_amount` ไม่ใช่แค่ convention ฝั่ง client แต่ถูก **enforce ที่ระดับ RPC** — อ่าน `create_orders()` (schema.sql, security definer) พบ `update ... set subtotal = v_subtotal, fee_amount = v_fee_amount, total = v_subtotal + v_fee_amount` เป็นค่าเดียวที่เขียนได้ และ `orders` **ไม่มี insert/update/delete policy ให้ client เลย** (comment ในโค้ดยืนยันตรง ๆ) — client ไม่มีทาง insert/update ค่าที่ขัดแย้งกับ invariant นี้ได้ไม่ว่ากรณีใด ดังนั้น Net = Gross − Fee ถูกต้องทางคณิตศาสตร์เสมอ ไม่ใช่แค่ "ปกติจะถูก"

### (2) Disclaimer คำต่อคำ

เทียบ const string ในโค้ดกับ Product spec ทีละตัวอักษร:
- Balance card (`_balanceDisclaimer`, Requirements #5): ตรงคำต่อคำ 100%
- Payout bottom sheet (`_payoutExplanation`, Requirements #6): ตรงคำต่อคำ 100% (รวม concat ของ 3 string literal ต่อกันแล้วอ่านเป็นประโยคเดียวถูกต้อง)
- Fee rate line (`_feeRateDisclaimer`, Requirements #7): ตรงคำต่อคำ 100%
- Semantics label ปุ่มถอนเงิน ("ปุ่มถอนเงิน ยังไม่พร้อมใช้งานในเวอร์ชันนี้ แตะเพื่อดูรายละเอียด") ตรงกับ Design spec คำต่อคำ
- grep ยืนยันไม่มีคำว่า "พร้อมถอน"/"เงินในบัญชี" ที่ไหนในไฟล์ทั้งสองเลยนอกเหนือจาก disclaimer ที่มีคำอธิบายกำกับ

### (3) delivered → refunded ต้องหลุดจากยอดจริง

- ทุก query ของ Finance (`fetchFinanceBreakdown`/`fetchInTransitSummary`/`fetchTransactionHistory`) เป็น query สดทุกครั้งที่เรียก **ไม่มี cache/denormalize ใด ๆ เลย** — เมื่อ `seller_mark_refunded` (RPC จาก SELLER-003) เปลี่ยนสถานะ order จาก `delivered` → `refunded` แล้ว การเรียก `fetchFinanceBreakdown` ครั้งถัดไป (เช่น pull-to-refresh หรือเปิดหน้าใหม่) จะไม่นับ order นั้นเข้า Gross/Fee/Net/Balance อีกต่อไปโดยอัตโนมัติ เพราะ query กรอง `status='delivered'` ที่ระดับ DB
- Order นั้นยังปรากฏใน Transaction History เพราะ `fetchTransactionHistory` กรอง `status in ('delivered','refunded')` — `SellerTransactionTile` แสดง label "คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ" คู่กับสูตรที่ขีดทับเสมอ ไม่ใช่สื่อด้วยสี/ขีดทับอย่างเดียว (ยืนยันด้วย widget test เฉพาะทั้งสไตล์และข้อความ)
- ยืนยันว่า `SellerFinanceScreen` ไม่ auto-reload หลังกลับจาก `SellerOrderDetailScreen` (design ตัดสินใจไว้ตรง ๆ ว่าเป็น read-only screen) — พฤติกรรมนี้สอดคล้องกับ AC ที่ระบุ "การโหลดครั้งถัดไป" ไม่ใช่ "ทันทีที่ action เกิด" — Pull-to-refresh/เปิดหน้าใหม่ยังคงสะท้อนค่าใหม่ถูกต้องเสมอเพราะไม่มี cache

### (4) ปุ่ม "ถอนเงิน" กดได้จริงเสมอ ไม่ trigger payout จริง

- `grep -n "onPressed"` ยืนยันไม่มี `onPressed: null` ที่ไหนในไฟล์ finance ทั้งสอง — ปุ่มถอนเงิน `onPressed: _showPayoutInfo` เสมอ
- `grep -n "rpc\|\.insert(\|\.update(\|\.delete("` บนทั้งสองไฟล์ finance คืนค่าว่าง — **ไม่มีการเรียก network write method ใดๆ เลยทั้งไฟล์** ปุ่มเปิดแค่ `showModalBottomSheet` แสดงคำอธิบายแล้วปิดด้วย `Navigator.pop`
- Widget test ยืนยันเพิ่มเติมว่าหลังกดปุ่ม+ปิด bottom sheet แล้ว `sellerStartProcessingCalls`/`sellerCancelOrderCalls`/`sellerMarkRefundedCalls` ยังเป็น 0 ทั้งหมด

### (5) RLS/ownership scoping

- `git diff` ยืนยัน `supabase/schema.sql` ไม่ถูกแตะเลย — SELLER-005 ไม่เพิ่ม policy ใหม่ใด ๆ
- ทุกเมธอดใหม่ query ผ่าน `orders`/`platform_config` เดิม — select policy ของ `orders` (SELLER-001) `exists (select 1 from stores where stores.id = orders.store_id and stores.owner_id = auth.uid())` เป็นด่านความปลอดภัยจริง ไม่ใช่ `.eq('store_id', ...)` ฝั่ง client (comment ในโค้ดยืนยันหลักการนี้ตรง ๆ เหมือนทุกเมธอดอื่นใน `SellerRepository`)
- Widget test คู่ 2-store isolation (store A / store B) ยืนยันว่า `storeId` ที่ส่งเข้าทุกเมธอดใหม่ตรงกับร้านที่ screen ถูกสร้างมาให้เท่านั้น ไม่มีการรั่วไหลข้าม instance — เป็น pattern เดียวกับ SELLER-002/003 ที่ผ่าน QA แล้ว (การพิสูจน์ authorization จริงอยู่ที่ RLS server-side ไม่ใช่ client filter)

### (6)-(7) ไม่แตะ schema/`app/` และไม่แตะเมธอดเดิม 4 ตัว

- ยืนยันด้วย `git diff 3f6de4e..bd68eee` ตรง ๆ ทั้งสองข้อ — ไม่มีการเปลี่ยนแปลงใด ๆ ต่อ `supabase/schema.sql`, `app/`, หรือ signature/body ของ `fetchOrderCounts`/`fetchSalesSummary`/`fetchBestSellingProducts`/`fetchStoreOrders`

### (8) ไล่ Requirements/Design Components/Acceptance Criteria ทีละบรรทัด

ไล่ครบทั้ง 3 หัวข้อเทียบกับโค้ดจริงทีละข้อ — ผ่านครบทุกข้อ รวม AC ที่เป็นความเสี่ยงหลัก (disclaimer ครบทุกจุด, Net=Gross−Fee cross-check, refunded ไม่หายเงียบ, ปุ่มถอนเงินไม่ trigger flow จริง, RLS ไม่มี gap, ไม่มี schema/RLS ใหม่, เมธอดเดิมไม่ถูกแก้)

### (9) Full test suites อิสระ (หลัง sync main ใหม่)

- `seller_app/`: **87/87 ผ่าน** — `flutter analyze` สะอาด
- `app/`: **276/276 ผ่าน** — `flutter analyze` สะอาด
- ตรงกับตัวเลขที่ Coding รายงาน ไม่มี regression ใด ๆ

### ข้อสังเกตที่ไม่ block การอนุมัติ

ไม่มี automated test เปรียบเทียบผลลัพธ์ `fetchSalesSummary()` กับ `fetchFinanceBreakdown()` โดยตรงตามที่ Design spec's "เตือน Coding" ข้อ 4 แนะนำไว้ (เพราะไม่มี live Supabase project ให้ทดสอบ dynamic ได้จริง เหมือนทุก task ก่อนหน้าตั้งแต่ ZOKY-001) — ยืนยันความถูกต้องแทนด้วยการอ่าน query/aggregation logic ของทั้งสองเมธอดเทียบกันบรรทัดต่อบรรทัด: ทั้งคู่ใช้ filter เดียวกันทุกประการ (`store_id`+`status='delivered'`) และ time-window logic เดียวกันทุกประการ (เทียบ year/month/day กับ `DateTime.now()`) ต่างกันแค่จำนวนคอลัมน์ที่ select เพิ่ม — คณิตศาสตร์รับประกันว่า `gross` ของทั้งสองเมธอดเท่ากันเสมอสำหรับร้าน/เวลาเดียวกัน เสนอเป็น fast-follow เพิ่ม test นี้เมื่อมี live Supabase project จริง

## Final Status: PASS

อนุมัติเข้า `.wyn/tasks/approved/` — SELLER-005 (Finance) ผ่าน QA รอบเดียว **Phase 4 (ZOKY Sellers by WYN) เสร็จสมบูรณ์ครบทั้ง 5 task แล้ว** (SELLER-001 Foundation → SELLER-002 Product Management → SELLER-003 Order Management → SELLER-004 Store Management → SELLER-005 Finance) — ส่งต่อ AI Deploy & DevOps เมื่อมี infra จริง รอ Founder ตัดสินใจทิศทาง Phase 5 ต่อไป
