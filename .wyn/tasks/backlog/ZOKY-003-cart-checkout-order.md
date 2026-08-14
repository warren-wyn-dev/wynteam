# Product Task — ZOKY-003

Status: backlog
Owner: AI Product Manager

Feature: ZOKY Cart & Checkout & Order — เพิ่มสินค้าลงตะกร้า, สั่งซื้อ, ดูประวัติ/สถานะคำสั่งซื้อ

Goal: ทำให้ปุ่ม "Add to Cart"/"ซื้อเลย" ใน `ProductDetailScreen` และปุ่ม Cart/Orders ใน ZOKY Home (ที่เป็น `SnackBar` placeholder มาตั้งแต่ ZOKY-001) ทำงานจริง ให้ผู้ใช้ซื้อสินค้าจบ flow ได้ครบวงจร (Browse → Cart → Checkout → Order)

Target User: ผู้ใช้ ZOKY ที่เจอสินค้าที่ต้องการแล้ว (ผ่าน ZOKY-001 Browse หรือ ZOKY-002 Search) และต้องการสั่งซื้อจริง

Problem: ZOKY-001/002 ส่งมอบแค่ "เรียกดู/ค้นหา" — ไม่มีทางซื้อสินค้าได้เลยแม้แต่ทางเดียว ปุ่ม Add to Cart/Buy Now ทั้งหมดยังเป็น SnackBar "เร็ว ๆ นี้"

Requirements:

**ขอบเขตที่ตัดสินใจแล้วก่อนเริ่ม** (อ้างอิง DECISIONS.md 2026-08-14 "ขยาย WYN เป็น WYN Platform" และ master prompt Section 8-10, 18):
- **ไม่มี payment gateway จริงรอบนี้** — ปุ่ม "ยืนยันคำสั่งซื้อ" สร้าง Order ตรง ๆ ทันที ไม่มีขั้นตอนเลือกช่องทางชำระเงิน (เทียบเท่า "เก็บเงินปลายทาง" โดยปริยาย แต่ไม่ต้องมี UI เลือกวิธีจ่ายเงินเพราะมีทางเดียว) — ห้ามเดา/สร้าง integration กับ payment provider ที่ไม่มีอยู่จริงในโปรเจกต์
- **ค่าธรรมเนียม `ZOKY_MARKETPLACE_FEE`**: เก็บเป็นแถว configuration ในตาราง `platform_config` (key-value เดียว ไม่ hard-code ทั้งใน Dart และ SQL หลายจุด) ค่าเริ่มต้น 10% ต่อ Order คำนวณและ **บันทึก snapshot ค่าธรรมเนียมไว้ในแต่ละ Order ตอนสร้าง** (ไม่ใช่คำนวณใหม่จากค่า config ปัจจุบันตอนแสดงผลย้อนหลัง) เพราะถ้า Founder ปรับ % ในอนาคต ประวัติ Order เก่าต้องไม่เปลี่ยนตาม
- **1 Order ต่อ 1 ร้านค้า**: ตะกร้าเดียวเก็บสินค้าจากได้หลายร้าน แต่ตอนกด "ยืนยันคำสั่งซื้อ" ระบบต้องแยกสร้าง Order แยกต่างหากทีละร้าน (มาตรฐานเดียวกับ marketplace หลายผู้ขายทั่วไป — ค่าส่ง/สถานะจัดส่งเป็นอิสระต่อร้าน) ไม่ใช่ Order เดียวรวมทุกร้าน
- **ที่อยู่จัดส่ง**: กรอกที่ Checkout เป็นฟอร์มข้อความอิสระรอบนี้ (ชื่อผู้รับ, เบอร์โทร, ที่อยู่ 1 ช่องข้อความยาว) เก็บเป็น snapshot ไว้ในแต่ละ Order โดยตรง **ไม่มีสมุดที่อยู่ (saved address book) รอบนี้** — ผู้ใช้กรอกใหม่ทุกครั้งที่ Checkout (บันทึกเป็น Known Issue เสนอ fast-follow)
- **สถานะ Order รอบนี้มี 3 สถานะเท่านั้น**: `pending` (รอดำเนินการ — สร้างเสร็จใหม่) → `delivered` (ได้รับสินค้าแล้ว) หรือ `cancelled` (ยกเลิก) — **ไม่มีสถานะ "ยืนยันแล้ว"/"จัดส่งแล้ว" แยกรอบนี้** เพราะยังไม่มี ZOKY Sellers by WYN (Phase 4) ที่จะเป็นฝ่าย trigger สถานะเหล่านั้นจริง การสร้างสถานะที่ไม่มีใครกดเปลี่ยนได้จะเป็น dead state — เก็บไว้ตัดสินใจตอนสร้าง Seller app จริง (บันทึกเป็น Known Issue ชัดเจน ไม่ใช่การซ่อนขอบเขตที่ตัดออก)
- **Stock หักจาก `products.stock` เท่านั้นรอบนี้** ไม่หักจาก `product_variants.stock` — เพราะ variant ปัจจุบัน (ZOKY-001) เป็น attribute-value แยกกัน (สี/ไซส์ คนละแถว) ไม่ใช่ SKU รวมที่มี stock ของตัวเองจริง หัก stock ที่ variant-level ต้องออกแบบ SKU matrix ใหม่ทั้งหมดซึ่งไม่ใช่ขอบเขตตอนนี้ — variant ที่เลือกใน Cart/Order ยังคงเป็นข้อมูล snapshot แสดงผลอย่างเดียว (เหมือน ZOKY-001)

**Cart** (อ้างอิง master prompt Section 8):
- ตาราง `cart_items` เดียว (ไม่มีตาราง `carts` แยก — 1 ผู้ใช้มี 1 ตะกร้าโดยปริยาย ไม่มี attribute ระดับตะกร้าที่ต้องเก็บ เช่นเดียวกับที่ `saves` ไม่มี "collection" ห่ออีกชั้น) แต่ละแถวคือ 1 รายการ (product_id + variant selection snapshot + quantity)
- กด "Add to Cart" ใน `ProductDetailScreen` → เพิ่มลง `cart_items` จริง (ถ้ามีอยู่แล้วสำหรับ product+variant selection เดียวกัน ให้เพิ่ม quantity แทนสร้างแถวใหม่)
- กด "ซื้อเลย" (Buy Now) → เพิ่มลงตะกร้าเหมือน Add to Cart แล้วพาไปหน้า Cart ทันที (ไม่แยก flow ซื้อด่วนออกจาก Cart รอบนี้ — ลดความซับซ้อน)
- หน้า Cart ใหม่ (`ZokyCartScreen`) เปิดจากปุ่ม Cart icon ใน ZOKY Home (แทนที่ SnackBar placeholder เดิม) — Cart icon มี badge ตัวเลขจำนวนรายการ (มิเรอร์ pattern notification badge จาก WYN-012)
- แสดงรายการ **จัดกลุ่มตามร้านค้า** พร้อม subtotal ต่อร้าน, ปรับ quantity (+/-) ได้ (จำกัดไม่เกิน stock ปัจจุบันของสินค้า), ลบรายการได้
- ตะกร้าว่างเปล่า → ข้อความ empty state พร้อมปุ่มกลับไปเรียกดูสินค้า

**Checkout & Order** (อ้างอิง master prompt Section 9-10, 18):
- จากหน้า Cart กด "ยืนยันคำสั่งซื้อ" → กรอกฟอร์มที่อยู่จัดส่ง (ชื่อผู้รับ/เบอร์โทร/ที่อยู่) → แสดงสรุปยอด **แยกต่อร้าน** (ราคาสินค้ารวม + ค่าธรรมเนียม platform ที่คำนวณ ณ ขณะนั้น + ยอดรวม) → กดยืนยันอีกครั้ง → ระบบสร้าง Order แยกทีละร้าน (transaction เดียวจบ ไม่สร้างบาง order สำเร็จบาง order ไม่สำเร็จ), หัก stock, ลบ cart_items ที่สั่งซื้อไปแล้วออกจากตะกร้า
- **ต้องตรวจ stock ฝั่ง server ตอนสร้าง Order เท่านั้น ไม่เชื่อค่าจาก client** (ถ้าสินค้าหมด/เหลือไม่พอระหว่างที่ค้างอยู่ในตะกร้า ต้องปฏิเสธและแจ้งผู้ใช้ ไม่ใช่สร้าง Order ที่หัก stock ติดลบ) — ใช้ security-definer RPC เดียวกับ pattern ที่พิสูจน์แล้วจาก WYN-014 (club role RPC) และ WYN-006 (`increment_pop_view_count`) ไม่ใช่ raw insert ผ่าน RLS ธรรมดา เพราะต้องมี business logic (คำนวณยอด/หัก stock/สร้างหลาย order พร้อมกันแบบ atomic) ที่เชื่อถือได้ฝั่งเดียว
- หน้า Order List ใหม่ (`ZokyOrderListScreen`) เปิดจากปุ่ม Orders ใน ZOKY Home (แทนที่ SnackBar placeholder เดิม) — แสดงคำสั่งซื้อทั้งหมดของผู้ใช้ ใหม่สุดก่อน พร้อม badge สถานะ (รอดำเนินการ/ได้รับแล้ว/ยกเลิกแล้ว)
- หน้า Order Detail ใหม่ (`ZokyOrderDetailScreen`) — รายการสินค้าในออเดอร์นั้น (snapshot ชื่อ/ราคา/จำนวน ณ ตอนสั่งซื้อ ไม่ใช่ query สินค้าปัจจุบันซ้ำ เพราะราคา/ชื่อสินค้าอาจเปลี่ยนไปแล้วหลังสั่งซื้อ), ที่อยู่จัดส่ง, ยอดรวม+ค่าธรรมเนียม, สถานะปัจจุบัน
- ปุ่ม **"ยกเลิกคำสั่งซื้อ"** ใน Order Detail — กดได้เฉพาะสถานะ `pending` เท่านั้น คืน stock กลับเข้า `products.stock` (ผ่าน RPC ตรวจสอบว่าเป็นเจ้าของ Order เองและสถานะยัง pending เท่านั้น)
- ปุ่ม **"ยืนยันได้รับสินค้าแล้ว"** ใน Order Detail — กดได้เฉพาะสถานะ `pending` เท่านั้น (ตามที่ตัดสินใจไว้ข้างบนว่าไม่มีสถานะกลาง) เปลี่ยนเป็น `delivered` — จำเป็นสำหรับ ZOKY-004 (Review) ที่ต้องมี Order สถานะ Delivered ถึงจะรีวิวได้

Acceptance Criteria:
- [ ] กด "Add to Cart" ใน Product Detail → รายการเข้าตะกร้าจริง, กดซ้ำสินค้าเดิม+variant เดิม → quantity เพิ่มแทนสร้างแถวใหม่
- [ ] กด "ซื้อเลย" → เข้าตะกร้าแล้วพาไปหน้า Cart ทันที
- [ ] ปุ่ม Cart ใน ZOKY Home เปิด `ZokyCartScreen` จริง พร้อม badge จำนวนรายการถูกต้อง
- [ ] หน้า Cart จัดกลุ่มตามร้าน, ปรับ quantity/ลบรายการได้, ปรับ quantity เกิน stock ปัจจุบันไม่ได้
- [ ] Checkout กรอกที่อยู่ → เห็นสรุปยอดแยกต่อร้าน (รวมค่าธรรมเนียม) ก่อนยืนยัน
- [ ] ยืนยันคำสั่งซื้อสำเร็จ → สร้าง Order แยกทีละร้านจริง, stock ของสินค้าที่สั่งซื้อลดลงถูกต้อง, cart_items ที่สั่งซื้อไปถูกลบออกจากตะกร้า
- [ ] สั่งซื้อสินค้าที่ stock ไม่พอ (เช่น คนอื่นซื้อตัดหน้าระหว่างที่ค้างในตะกร้า) → ระบบปฏิเสธพร้อมข้อความชัดเจน ไม่สร้าง Order ที่ stock ติดลบ
- [ ] ปุ่ม Orders ใน ZOKY Home เปิด `ZokyOrderListScreen` จริง แสดงคำสั่งซื้อทั้งหมดของผู้ใช้เอง (ไม่เห็นของคนอื่น)
- [ ] Order Detail แสดงรายการ/ที่อยู่/ยอดรวม/สถานะถูกต้อง ตรงกับตอนสั่งซื้อ (snapshot ไม่เปลี่ยนตามราคาปัจจุบัน)
- [ ] ยกเลิก Order ได้เฉพาะสถานะ pending เท่านั้น และ stock คืนกลับถูกต้อง
- [ ] ยกเลิก/ยืนยันรับสินค้า Order ของคนอื่นไม่ได้ (RLS/RPC ป้องกัน)
- [ ] WYN Social เดิมทั้งหมด และ ZOKY-001/002 (Browse/Search) เดิม ยังทำงานปกติ ไม่มี regression

Dependencies: ZOKY-001 (Marketplace Foundation — Approved, ต้องมี Product/Store/stock อยู่แล้ว), ZOKY-002 (Search & Filter — Approved, ไม่ใช่ dependency ตรงแต่เป็นทางเข้าถึงสินค้าอีกทาง)

Priority: P1 ของสาย ZOKY — ต่อจาก ZOKY-002 ตามลำดับ roadmap (`.wyn/docs/product/zoky-platform-roadmap.md`) เป็น task ที่ใหญ่ที่สุดและมีความเสี่ยง data-integrity สูงที่สุดของสายนี้ (เงิน/stock/transaction หลายตาราง)

Risks:
- **สถานะ Order แบบย่อ (3 สถานะ ไม่มี "จัดส่งแล้ว" แยก) เป็นข้อจำกัดที่ตั้งใจ ไม่ใช่บั๊ก** — ต้องบันทึกไว้ชัดเจนใน Known Issues ว่าเมื่อ ZOKY Sellers by WYN (Phase 4) เริ่มจริง จะต้องออกแบบสถานะเพิ่ม (confirmed/shipped) และ migration/RPC ใหม่ที่ผูกกับสิทธิ์ของ Seller
- **Race condition ตอนหลาย order พร้อมกันแย่ง stock เดียวกัน**: ต้องพึ่งพา DB-level atomicity ของ RPC (single transaction, ตรวจ+หัก stock ในคำสั่งเดียวกันไม่ใช่ 2 query แยก) ไม่ใช่ตรวจที่ Flutter แล้วค่อยเขียนทีหลัง (time-of-check-to-time-of-use gap) — เตือน Design/Coding เป็นพิเศษ
- **ไม่มี saved address book**: ผู้ใช้ต้องกรอกที่อยู่ใหม่ทุกครั้ง — ไม่ block แต่เสนอเป็น fast-follow
- **ไม่มี Seller เห็น Order ของร้านตัวเองรอบนี้**: เป็นขอบเขตของ Phase 4 (ZOKY Sellers by WYN) ไม่ใช่รอบนี้ — ผู้ซื้อเห็น Order ตัวเองเท่านั้น
- **ค่าธรรมเนียมต้อง snapshot ไม่ query จาก config สดตอนแสดงผล** — พลาดจุดนี้จะทำให้ยอดในประวัติ Order เปลี่ยนย้อนหลังเมื่อ Founder ปรับ % ในอนาคต ต้องเตือน Coding ให้ชัดเจน

Recommendation:
1. เริ่ม ZOKY-003 ทันทีตามลำดับ roadmap — เป็น task ที่ทำให้ ZOKY Marketplace มีรายได้จริงเป็นครั้งแรก (ค่าธรรมเนียม)
2. **ยึด 1 Order ต่อ 1 ร้าน, สถานะ 3 แบบ, ไม่มี payment gateway จริง** ตามเหตุผลที่ระบุไว้ใน Requirements ทั้งหมด — เป็นขอบเขตที่ตัดสินใจแล้วเพื่อให้ส่งมอบได้จริงรอบนี้โดยไม่ต้องเดา Seller app/payment provider ที่ยังไม่มี
3. เน้น Coding ให้ทำ RPC ที่ atomic จริง (ตรวจ+หัก stock+สร้าง order หลายร้าน+snapshot ค่าธรรมเนียม ในธุรกรรมเดียว) เป็นจุดสำคัญที่สุดของ task นี้

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) `ZokyCartScreen` (จัดกลุ่มตามร้าน, quantity stepper, ลบ, empty state) (2) Checkout flow (ฟอร์มที่อยู่ → สรุปยอดแยกต่อร้าน → ยืนยัน) (3) `ZokyOrderListScreen` (การ์ดสรุปพร้อม badge สถานะ) (4) `ZokyOrderDetailScreen` (รายการ/ที่อยู่/ยอดรวม/ปุ่มยกเลิก+ยืนยันรับสินค้าตามสถานะ) (5) Cart badge บน ZOKY Home icon — reuse component เดิมให้มากที่สุด (notification badge pattern จาก WYN-012, card/list pattern จาก Order history ที่ไม่เคยมีมาก่อนในโปรเจกต์นี้ให้ออกแบบใหม่โดยยึด design system เดิม) ใช้ Design system เดิม (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass)
