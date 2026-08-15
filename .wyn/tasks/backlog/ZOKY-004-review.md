# Product Task — ZOKY-004

Status: backlog
Owner: AI Product Manager

Feature: ZOKY Product Review — ให้ผู้ซื้อให้คะแนน+เขียนรีวิวสินค้าหลังได้รับของแล้ว แสดงคะแนนเฉลี่ยที่ Product Detail/Store

Goal: เติมส่วน "รีวิว" ที่ `ProductDetailScreen`/`StoreScreen` (ZOKY-001) เตรียม UI ไว้แล้วแต่ hard-code "ยังไม่มีรีวิว" ให้ทำงานจริง และให้ผู้ซื้อที่ Order ของตัวเองถึงสถานะ `delivered` แล้ว (ZOKY-003) เขียนรีวิวสินค้านั้นได้จริง

Target User: ผู้ใช้ ZOKY ที่มี Order สถานะ `delivered` (กดปุ่ม "ยืนยันได้รับสินค้าแล้ว" ใน ZOKY-003) และผู้ใช้ทั่วไปที่ต้องการอ่านรีวิวก่อนตัดสินใจซื้อ

Problem: ปัจจุบันไม่มีทางให้คะแนน/รีวิวสินค้าได้เลย ผู้ซื้อรายอื่นไม่มีข้อมูลช่วยตัดสินใจ และ UI ที่เตรียมไว้ตั้งแต่ ZOKY-001 (`ProductDetailScreen` บรรทัด "รีวิว"/"ยังไม่มีรีวิว", `StoreScreen`'s Reviews tab) ยังเป็นข้อความ hard-code ว่างเปล่าเสมอ

Requirements:

**ขอบเขตที่ตัดสินใจแล้วก่อนเริ่ม** (อ้างอิง DECISIONS.md 2026-08-14 "ขยาย WYN เป็น WYN Platform" และ master prompt Section 11):
- **รีวิวผูกกับ Order ที่ delivered เท่านั้น** — เงื่อนไขเขียนรีวิวได้คือ ผู้ใช้ต้องเป็นเจ้าของ Order ที่มี `order_items` ของสินค้านั้นอยู่ และ Order นั้นมีสถานะ `delivered` (ตรงตามที่ roadmap ระบุไว้ "ต้องมี Order ที่ Delivered แล้วถึงจะรีวิวได้") — ป้องกัน fake review จากคนที่ไม่เคยซื้อจริง ตรวจฝั่ง server เสมอ (RLS/RPC) ไม่เชื่อ client
- **1 รีวิวต่อ 1 order_item เท่านั้น** — รีวิวผูกกับ "การซื้อครั้งนั้น" ไม่ใช่ผูกกับ product เฉย ๆ เพื่อกันรีวิวซ้ำหลายรอบจาก order เดียวกัน แต่ถ้าซื้อสินค้าเดิมซ้ำในอีก Order ที่ delivered แล้วอีกครั้ง รีวิวรอบใหม่ได้อีก 1 ครั้ง (เหมือน marketplace ทั่วไป — ยิ่งซื้อบ่อยยิ่งรีวิวได้เพิ่ม ไม่ใช่ข้อจำกัด)
- **คะแนน (rating) 1-5 ดาว บังคับกรอกเสมอ + ข้อความรีวิวเป็นตัวเลือก** (ไม่บังคับพิมพ์ข้อความ ให้กดแค่ดาวอย่างเดียวจบได้ เหมือน marketplace ทั่วไปที่ conversion สูงกว่าถ้าไม่บังคับพิมพ์) — **ไม่มีรูปภาพประกอบรีวิวรอบนี้** (ต้องมี storage bucket ใหม่+moderation flow ที่ยังไม่ออกแบบ เก็บเป็น Known Issue เสนอ fast-follow)
- **แก้ไข/ลบรีวิวของตัวเองได้ภายหลัง** (ไม่ล็อกถาวรหลังส่ง — มาตรฐานเดียวกับที่ WYN Social ให้แก้/ลบ post/comment ตัวเองได้) ผ่าน RLS ปกติ (`user_id = auth.uid()`) ไม่ต้องใช้ RPC พิเศษเหมือน order (การแก้ไขรีวิวไม่มี business logic ซับซ้อนแบบ stock/fee)
- **คะแนนเฉลี่ย (average rating) คำนวณสดจาก `reviews` ตอน query แสดงผลเสมอ** (ต่างจาก ZOKY-003 ที่ fee ต้อง snapshot — คะแนนเฉลี่ยควรอัปเดตทันทีเมื่อมีรีวิวใหม่/แก้ไข/ลบ ไม่ใช่ค่าคงที่ที่ freeze ไว้ ณ จุดใดจุดหนึ่ง) — ใช้ aggregate query (`avg`/`count`) ไม่ต้องสร้างคอลัมน์ denormalized แยกเก็บยอดรวมรอบนี้ เพราะจำนวนรีวิวต่อสินค้ายังไม่มากพอที่ performance จะเป็นปัญหา
- **ไม่มีระบบ "โหวตว่ารีวิวนี้มีประโยชน์"/reply จากร้านค้าตอบรีวิวรอบนี้** — เป็น Section เพิ่มเติมของ master prompt ที่ไม่ critical กับ MVP รอบนี้ เก็บเป็น Known Issue

**Product Detail Integration**:
- แทนที่ข้อความ hard-code "ยังไม่มีรีวิว" ด้วยคะแนนเฉลี่ย (ดาว + ตัวเลขทศนิยม 1 ตำแหน่ง + จำนวนรีวิว) เมื่อมีรีวิวอย่างน้อย 1 รายการ — ถ้ายังไม่มีรีวิวเลย คงข้อความ "ยังไม่มีรีวิว" เดิมไว้ (ตามที่ ZOKY-001 design เตรียมไว้แล้ว)
- แสดงรายการรีวิวล่าสุดของสินค้านั้น (ชื่อ+avatar ผู้รีวิว, ดาว, ข้อความ, เวลาแบบ relative — มิเรอร์ pattern comment ของ WYN Social)
- ถ้าผู้ใช้ปัจจุบันมีสิทธิ์รีวิวสินค้านี้ได้ (มี order_item ที่ delivered แล้วและยังไม่เคยรีวิว order_item นั้น) → แสดงปุ่ม/จุดเข้าถึงฟอร์มเขียนรีวิว
- ถ้าผู้ใช้เคยรีวิว order_item นั้นไปแล้ว → แสดงรีวิวของตัวเองพร้อมทางแก้ไข/ลบ แทนปุ่มเขียนใหม่

**Store Reviews Tab Integration**:
- แทนที่ `_buildReviewsTab`'s "ยังไม่มีรีวิว" hard-code ด้วยรายการรีวิวรวมของสินค้าทุกชิ้นในร้านนั้น (join reviews → products ที่ store_id ตรงกัน) เรียงใหม่สุดก่อน พร้อมชื่อสินค้ากำกับแต่ละรีวิว (เพราะรวมจากหลายสินค้า)
- Store header's rating (ปัจจุบัน placeholder) แสดงคะแนนเฉลี่ยรวมของทุกสินค้าในร้าน

**จุดเข้าถึงจาก Order** (ตามที่ roadmap ระบุ "ต้องมี Order ที่ Delivered แล้วถึงจะรีวิวได้"):
- `ZokyOrderDetailScreen` (ZOKY-003) เมื่อสถานะ `delivered` → แต่ละรายการสินค้าใน order (`order_items`) มีปุ่ม/จุดเข้าถึง "เขียนรีวิว" ต่อรายการ (ไม่ใช่รีวิวรวมทั้ง order เพราะอาจมีหลายสินค้าต่างกัน) — ถ้ารีวิว item นั้นไปแล้วให้แสดงว่ารีวิวแล้ว (เช่น badge/ข้อความ) แทนปุ่มเขียนใหม่ แทนที่จะซ่อนไปเงียบ ๆ

Acceptance Criteria:
- [ ] ผู้ใช้ที่มี Order สถานะ `delivered` เขียนรีวิว (ดาว 1-5 + ข้อความไม่บังคับ) ให้กับสินค้าใน order_item นั้นได้จริง ผ่าน `ZokyOrderDetailScreen`
- [ ] ผู้ใช้ที่ไม่มี Order สถานะ delivered ของสินค้านั้น (หรือยังเป็น pending/cancelled) เขียนรีวิวสินค้านั้นไม่ได้ — ตรวจฝั่ง server (RLS/RPC) ไม่ใช่แค่ซ่อนปุ่มฝั่ง UI
- [ ] เขียนรีวิว order_item เดิมซ้ำสองครั้งไม่ได้ (unique constraint ระดับ order_item)
- [ ] ซื้อสินค้าเดิมอีกรอบใน Order ใหม่ที่ delivered แล้ว → รีวิวรอบใหม่สำหรับ order_item ใหม่ได้อีกครั้งจริง
- [ ] แก้ไข/ลบรีวิวของตัวเองได้ แก้/ลบรีวิวของคนอื่นไม่ได้ (RLS ป้องกัน)
- [ ] `ProductDetailScreen` แสดงคะแนนเฉลี่ย+จำนวนรีวิว+รายการรีวิวจริงเมื่อมีรีวิว, แสดง "ยังไม่มีรีวิว" เมื่อไม่มีรีวิวเลย (ไม่ crash ทั้งสองกรณี)
- [ ] `StoreScreen`'s Reviews tab แสดงรีวิวรวมของทุกสินค้าในร้านจริง พร้อมชื่อสินค้ากำกับ, Store header's rating แสดงคะแนนเฉลี่ยรวมจริง
- [ ] คะแนนเฉลี่ยคำนวณสดถูกต้อง (เพิ่ม/แก้ไข/ลบรีวิว → ค่าเฉลี่ยที่แสดงผลเปลี่ยนตามทันที ไม่ค้างค่าเก่า)
- [ ] WYN Social เดิมทั้งหมด และ ZOKY-001/002/003 เดิม ยังทำงานปกติ ไม่มี regression

Dependencies: ZOKY-003 (Cart & Checkout & Order — Approved, ต้องมี Order สถานะ delivered จริงถึงจะทดสอบ/ใช้งานได้)

Priority: P1 ของสาย ZOKY — task สุดท้ายของ ZOKY Marketplace Customer-facing scope (Phase 2-3 ตาม roadmap) ต่อจาก ZOKY-003

Risks:
- **Fake/spam review ถ้าเงื่อนไข delivered-order ไม่ถูกบังคับฝั่ง server จริง**: ต้องเน้น Coding/QA เป็นพิเศษว่า insert policy/RPC ของ `reviews` ต้องตรวจสอบ `exists` join กลับไปที่ `orders`/`order_items` ที่ `buyer_id = auth.uid()` และ `status = 'delivered'` เสมอ ไม่เชื่อ `order_item_id` ที่ client ส่งมาเฉย ๆ
- **ไม่มีรูปภาพประกอบรีวิว/โหวตมีประโยชน์/ร้านตอบรีวิวรอบนี้**: ไม่ block แต่เสนอเป็น fast-follow ตามที่ระบุใน Requirements
- **คะแนนเฉลี่ยคำนวณสดทุกครั้ง**: ต้องเตือน Coding ว่าห้าม cache/denormalize ค่าเฉลี่ยแบบ snapshot เหมือน ZOKY-003's fee (คนละหลักการกัน) — พลาดจุดนี้จะทำให้คะแนนไม่อัปเดตหลังมีรีวิวใหม่

Recommendation:
1. เริ่ม ZOKY-004 ทันทีตามลำดับ roadmap — เป็น task สุดท้ายที่ปิด ZOKY Marketplace Customer-facing scope ให้ครบวงจร Browse→Cart→Checkout→Order→Review
2. ใช้ RLS ธรรมดา (ไม่ใช่ security-definer RPC) สำหรับ insert/update/delete ของ `reviews` ได้ เพราะเงื่อนไข "มี order_item ที่ delivered เป็นของตัวเอง" แสดงเป็น RLS policy ด้วย `exists` subquery ตรงไปตรงมาได้ ไม่มี multi-table business logic ที่ต้อง atomic แบบ ZOKY-003 (ต่างจาก order ที่ต้องหัก stock/สร้างหลายแถวพร้อมกัน)
3. เน้น Coding ให้เขียน RLS policy ของ `reviews` ให้ตรวจ "delivered order เป็นของตัวเองจริง" ครบทุก path (insert ต้องตรวจ, select เปิดให้ทุกคนอ่านได้เหมือน content อื่นของ WYN Social)

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) ฟอร์มเขียนรีวิว (ดาว 1-5 + ข้อความ optional) เข้าถึงจาก `ZokyOrderDetailScreen`'s order_item ที่ delivered (2) การแสดงรีวิวใน `ProductDetailScreen` (คะแนนเฉลี่ย+รายการ) (3) `StoreScreen`'s Reviews tab (รวมรีวิวทุกสินค้าในร้าน) (4) จุดแก้ไข/ลบรีวิวของตัวเอง — reuse component เดิมให้มากที่สุด (comment list pattern จาก WYN Social ถ้ามี, `ConfirmDeleteDialog` สำหรับลบรีวิว, star-rating widget ใหม่ที่ยังไม่เคยมีในโปรเจกต์นี้ให้ออกแบบใหม่โดยยึด design system เดิม) ใช้ Design system เดิม (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass)
