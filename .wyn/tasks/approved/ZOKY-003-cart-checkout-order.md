# Product Task — ZOKY-003

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS)

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

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/zoky-003-cart-checkout-order.md` — สรุป: Product Detail's ปุ่ม Add to Cart/ซื้อเลย เปลี่ยนจาก `_showComingSoon` เป็นเรียก `addToCart()` จริง (ซื้อเลย = เพิ่มลงตะกร้าแล้วพา push ไป Cart ทันที) — `ZokyCartScreen` ใหม่จัดกลุ่มตามร้าน มี `ZokyCartItemTile` ใหม่ (thumbnail 64px + quantity stepper 3 ส่วน `-`/ตัวเลข/`+` + ปุ่มลบแยกต่างหาก) — **Checkout แยก 2 หน้าจอ** (`ZokyCheckoutAddressScreen` กรอกที่อยู่ → `ZokyCheckoutSummaryScreen` สรุปยอดแยกต่อร้าน+ยืนยัน) แทนหน้าเดียวยาว เพื่อบังคับให้เห็นยอดเงินเต็มจอก่อนกดยืนยันเสมอ — ปุ่มยืนยันคำสั่งซื้อต้อง disable+โชว์ loading ทันทีที่กดป้องกันกดซ้ำ — `ZokyOrderListScreen`/`ZokyOrderDetailScreen` ใหม่ ใช้ `OrderSummaryCard` (มิเรอร์ `StoreResultCard`) และ order status badge widget ร่วมกัน (สี+icon+ข้อความคู่กันเสมอ ไม่ใช้สีอย่างเดียว: pending=เทา/hourglass, delivered=เขียว/check, cancelled=แดง/cancel) — ปุ่มยกเลิก/ยืนยันรับสินค้าใน Order Detail แสดงเฉพาะสถานะ pending เท่านั้นและต้องมี confirm dialog ก่อนเสมอ (มิเรอร์ `ConfirmDeleteDialog`) — Cart icon ใน ZOKY Home เพิ่ม badge จำนวนรายการ มิเรอร์โครง notification bell badge (WYN-012) เป๊ะ — เตือน Coding เรื่อง RPC ต้อง atomic จริง (single transaction ตรวจ+หัก stock) และค่าธรรมเนียม % ต้อง snapshot ไม่ query ค่า config สดตอนแสดงผล

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- **Database** (`supabase/schema.sql`): เพิ่ม `platform_config` (key-value, seed `zoky_marketplace_fee_percent = '10'`, select-all-authenticated ไม่มี write policy ให้ client), `cart_items` (RLS CRUD เฉพาะแถวตัวเอง, `variant_selection` เป็น `text not null default ''` ไม่ใช่ nullable เพื่อให้ unique constraint `(user_id, product_id, variant_selection)` ทำงานถูกต้องแม้ไม่มี variant), `orders` (status 3 ค่า pending/delivered/cancelled, snapshot `fee_percent`/`fee_amount`, **ไม่มี insert/update/delete policy ให้ client เลย**), `order_items` (snapshot `product_name`/`unit_price`/`image_url` ณ ตอนสั่งซื้อ, `product_id` เป็น `on delete set null` ไม่ใช่ cascade เพื่อให้ Order ยังอยู่แม้สินค้าถูกลบ, select ผ่าน join กลับไปที่ `orders.buyer_id`) — RPC 3 ตัว security definer: `create_orders` (ล็อก products ที่เกี่ยวข้องทั้งหมดด้วย `for update` เรียงตาม id ก่อนตรวจ/หัก stock ในธุรกรรมเดียว ป้องกัน race condition ตามที่ Product/Design เตือนไว้, แยกสร้าง Order ทีละร้าน, raise `INSUFFICIENT_STOCK:<ชื่อสินค้า>` เมื่อ stock ไม่พอ), `cancel_order` (เฉพาะเจ้าของ+สถานะ pending คืน stock), `confirm_order_received` (เฉพาะเจ้าของ+สถานะ pending)
- **Models**: `CartItem`, `Order`/`OrderStatus`, `OrderItem` (`app/lib/features/zoky/data/`)
- **Repository** (`ZokyRepository` เดิม ขยายเพิ่มแทนแยกไฟล์ใหม่ เพราะขนาดยังจัดการได้): `fetchCartItems`/`addToCart`/`updateCartItemQuantity`/`removeCartItem`/`cartItemCount`, `createOrders`/`fetchOrders`/`fetchOrder`/`fetchOrderItems`/`cancelOrder`/`confirmOrderReceived`/`fetchMarketplaceFeePercent` — `InsufficientStockException` แปลงจาก RPC's `INSUFFICIENT_STOCK:` prefix (มิเรอร์ `UsernameTakenException` pattern จาก `auth_repository.dart`)
- **UI**: `ProductDetailScreen`'s ปุ่ม Add to Cart/ซื้อเลย ทำงานจริง (disable+เปลี่ยนข้อความเป็น "สินค้าหมด" เมื่อ `stock <= 0`) — `ZokyCartScreen` ใหม่ (จัดกลุ่มตามร้าน, `QuantityStepper`/`ZokyCartItemTile` widget ใหม่) — `ZokyCheckoutAddressScreen`+`ZokyCheckoutSummaryScreen` ใหม่ (2 หน้าจอแยกตาม Design) — `ZokyOrderListScreen`+`ZokyOrderDetailScreen` ใหม่ (`OrderSummaryCard`/`OrderStatusBadge` widget ใหม่) — Cart icon บน ZOKY Home เพิ่ม badge มิเรอร์ `_buildNotificationButton` (WYN-012) เป๊ะ, fetch แบบ silent-fail เหมือนต้นแบบ

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. **บั๊กจริงที่ทำให้ `ZokyCartScreen` ทั้งหน้าว่างเปล่าทันทีที่ตะกร้ามีสินค้า**: `_buildBottomBar`'s `Column` (label "ยอดรวมทั้งหมด" + ราคา) ไม่ได้ระบุ `mainAxisSize: MainAxisSize.min` — ค่าเริ่มต้น `MainAxisSize.max` ภายใต้ loose height constraint ของ `Scaffold.bottomNavigationBar` ทำให้การคำนวณความสูงของทั้ง `Scaffold` พังเงียบ ๆ จนตัว `body`/`Scrollable` ได้ความสูง 0 (ไม่มี exception ใด ๆ ถูกโยนเลย ไม่ใช่ RenderFlex overflow แบบปกติที่คุ้นเคย) วินิจฉัยได้จากการเช็ค `Scrollable.size` โดยตรง แก้ด้วยการเพิ่ม `mainAxisSize: MainAxisSize.min` — บันทึกเป็น pattern ใหม่ใน `.wyn/learning/PATTERNS.md` เพราะเป็นรูปแบบบั๊กที่ไม่เคยเจอมาก่อนในโปรเจกต์นี้ (ไม่ทิ้งร่องรอย exception ให้ตามรอยเลย)
2. Test file 2 ไฟล์ (`zoky_cart_screen_test.dart`, `zoky_order_detail_screen_test.dart`) ต้องเพิ่ม `tester.takeException()` หลัง `pumpAndSettle()` ทุกจุดที่มี `Image.network` (ตามธรรมเนียมเดิมของโปรเจกต์) — พลาดไปตอนแรกทำให้ NetworkImageLoadException ที่คาดไว้อยู่แล้วกลาย เป็น unhandled exception กระทบ test ถัดไปในไฟล์เดียวกัน
3. `RecordingZokyRepository` ถูกสร้าง inline ใน testWidgets callback อีกครั้ง (gotcha เดิมที่เคยบันทึกไว้แล้วหลายครั้ง — ครั้งนี้เกิดตอนแก้ test ให้จำลอง error case) ย้ายเข้า `setUp()` ตามธรรมเนียม
4. `on success shows a confirmation SnackBar and pops back to the first route` test push `ZokyCheckoutSummaryScreen` ผ่าน helper `buildSummary()` ที่ห่อด้วย `MaterialApp` ของตัวเองอีกชั้น ทำให้ route ที่ push เข้าไปมี Navigator ซ้อนแยกต่างหาก (ไม่ใช่ Navigator เดียวกับหน้า "open") — `Navigator.of(context).popUntil((route) => route.isFirst)` จากข้างในจึงกลายเป็น no-op เงียบ ๆ (route ปัจจุบันของ Navigator ชั้นในมองว่าตัวเองเป็น `isFirst` อยู่แล้ว) แก้โดย push `ZokyCheckoutSummaryScreen` โดยตรงแทนการห่อผ่าน helper ที่มี `MaterialApp` ซ้อน — เป็นบั๊กของ test เอง ไม่ใช่ production code (ยืนยันด้วย debug print ตรวจ `canPop()`/`route.isFirst`/`route.settings` ก่อนสรุป)

Files Changed:
- แก้: `supabase/schema.sql` (เพิ่ม ZOKY-003 section ท้ายไฟล์), `app/lib/features/zoky/data/zoky_repository.dart`, `app/lib/features/zoky/presentation/{product_detail_screen,zoky_home_screen}.dart`
- ใหม่: `app/lib/features/zoky/data/{cart_item,order,order_item}.dart`, `app/lib/features/zoky/presentation/{zoky_cart_screen,zoky_checkout_address_screen,zoky_checkout_summary_screen,zoky_order_list_screen,zoky_order_detail_screen}.dart`, `app/lib/features/zoky/presentation/widgets/{quantity_stepper,zoky_cart_item_tile,order_status_badge,order_summary_card}.dart`
- test แก้: `app/test/{product_detail_screen_test,zoky_home_screen_test}.dart`, `app/test/support/recording_zoky_repository.dart` (ขยาย cart/order fields+methods)
- test ใหม่: `app/test/{zoky_cart_screen_test,zoky_checkout_address_screen_test,zoky_checkout_summary_screen_test,zoky_order_list_screen_test,zoky_order_detail_screen_test}.dart`
- บทเรียนใหม่: `.wyn/learning/PATTERNS.md` (Column mainAxisSize.max ใต้ Scaffold.bottomNavigationBar)

`flutter analyze`: สะอาด, `flutter test`: 233/233 ผ่าน (เพิ่มจาก 203 เดิม — WYN Social/ZOKY-001/ZOKY-002 เดิมทั้งหมดยังผ่านครบ ไม่มี regression)

Handoff: ส่งต่อ AI QA & Security (`/qa`)

---

## QA & Security Report — รอบ 1 (AI QA & Security)

**ผลสรุป: PASS**

### สิ่งที่ตรวจอิสระ (ไม่เชื่อตัวเลขจาก Coding Output เฉยๆ)

1. **Re-sync ไป merged main เอง** — `git fetch origin main`, rebuild branch `claude/pwd-nxsvf5` บน `origin/main` (commit `f7f6259`, PR #79) ใหม่ทั้งหมด
2. **รัน `flutter analyze` อิสระ**: No issues found
3. **รัน `flutter test` อิสระ**: 233/233 ผ่านทั้งหมด — ตรงกับตัวเลขที่ Coding รายงาน ยืนยันด้วยตัวเองแล้ว

### ตรวจ RPC `create_orders` ต้อง atomic จริง (จุดสำคัญที่สุดของ task นี้)

อ่านโค้ด SQL ยืนยันครบทุกจุด: `perform 1 from public.products where id in (select product_id from cart_items where user_id = auth.uid()) order by id for update;` ล็อกสินค้าที่เกี่ยวข้อง**ทั้งหมด** (ทุกร้านรวมกัน ไม่ใช่แค่ร้านแรก) ก่อนเริ่ม loop สร้าง Order เลย — เรียงตาม `id` จริง (ป้องกัน deadlock เมื่อ checkout สองรายการพร้อมกันมีสินค้าที่ทับซ้อนกันบางส่วน) — เพราะ lock ถูกถือไว้ตั้งแต่ต้นจนจบธุรกรรมเดียวกัน การอ่าน `p.stock` ในแต่ละ loop หลังจากนั้นจึงเห็นค่าล่าสุดที่รับประกันได้ว่าไม่มี transaction อื่นมาแก้ไขระหว่างกลาง (ไม่ใช่ query แยกแล้วเขียนทีหลังที่มีช่องให้ time-of-check-to-time-of-use race) — ทั้งฟังก์ชันเป็น PL/pgSQL function ธรรมดา (ไม่มี explicit transaction control) จึงรันอยู่ใน transaction เดียวของการเรียก RPC ครั้งนั้นเสมอ ถ้า `raise exception 'INSUFFICIENT_STOCK:...'` เกิดขึ้นระหว่างสร้าง Order ร้านที่ 2 ของตะกร้าที่มี 3 ร้าน **Order ร้านที่ 1 ที่สร้างไปแล้วในธุรกรรมเดียวกันจะถูก rollback ไปด้วยทั้งหมด** ตรงตาม AC "transaction เดียวจบ ไม่สร้างบาง order สำเร็จบาง order ไม่สำเร็จ" — วิเคราะห์ concurrent scenario (สินค้าเหลือ 1 ชิ้น 2 request แย่งกันซื้อพร้อมกัน): request แรกที่ได้ lock ก่อนจะเห็น stock=1 ผ่านและหักเหลือ 0 สำเร็จ, request ที่สองต้องรอ lock ปลดล็อกก่อน (blocked โดย Postgres เอง) แล้วเมื่อได้ lock จะเห็น stock=0 จริง (ไม่ใช่ค่าเก่าตอนเริ่ม) ทำให้ถูกปฏิเสธด้วย `INSUFFICIENT_STOCK` ถูกต้อง ไม่มีทาง stock ติดลบได้เลย

### ตรวจ RLS ของ orders/order_items

อ่าน schema.sql ยืนยันว่า `orders`/`order_items` มีแค่ select policy (`auth.uid() = buyer_id` และ join กลับไปที่ `orders.buyer_id` ตามลำดับ) **ไม่มี insert/update/delete policy ให้ client เลยแม้แต่ policy เดียว** — grep หาคำว่า `for insert`/`for update`/`for delete` ในส่วน ZOKY-003 ของไฟล์ยืนยันว่าไม่มีจริง ต่างจาก `cart_items` ที่มี CRUD policy ครบ 4 ตัวตามที่ตั้งใจ (เพราะ cart ไม่ต้อง atomic เท่า order)

### ตรวจ `cancel_order`/`confirm_order_received` ownership+status

อ่าน SQL ทั้งสองฟังก์ชันยืนยันว่า WHERE clause กรอง `buyer_id = auth.uid() and status = 'pending'` เสมอ ไม่เชื่อค่าที่ client ส่งมาเลย (รับแค่ `p_order_id` พารามิเตอร์เดียว) — จำลอง attack scenario: user A เรียก `cancel_order(<order ของ user B>)` → `not exists (...)` เป็นจริงเพราะ `buyer_id` ไม่ตรง → raise exception 'Order not found or cannot be cancelled' ปฏิเสธถูกต้อง (ข้อความไม่บอกด้วยซ้ำว่า Order มีอยู่จริงหรือเปล่า ป้องกัน information leak เรื่อง Order id ของคนอื่นด้วย) — `confirm_order_received` ใช้ `if not found` หลัง `update ... where id = ... and buyer_id = auth.uid() and status = 'pending'` แบบเดียวกัน ผลลัพธ์เหมือนกัน

### ตรวจค่าธรรมเนียม snapshot

grep หา `fetchMarketplaceFeePercent` ทั้งโปรเจกต์ยืนยันว่าถูกเรียกใช้**เฉพาะใน `ZokyCheckoutSummaryScreen`** (ก่อนสร้าง Order จริง เพื่อแสดงยอดประมาณการเท่านั้น) — `ZokyOrderListScreen`/`ZokyOrderDetailScreen` ใช้ `order.feePercent`/`order.feeAmount` ที่มาจาก `Order.fromMap` (อ่านจาก DB column ตรง ๆ) เท่านั้น ไม่มีจุดไหนใน UI ที่ query `platform_config` สดมาคำนวณยอดในหน้าประวัติ Order ย้อนหลังเลย ถูกต้องตามที่ Requirements/Risks เตือนไว้

### ตรวจ 1 Order ต่อ 1 ร้านค้า

อ่านโค้ด `create_orders` ยืนยันว่า loop `for v_store_id in select distinct p.store_id from cart_items ci join products p ... where ci.user_id = auth.uid()` วนสร้าง Order ใหม่ 1 ใบต่อ 1 `v_store_id` — ตะกร้าที่มีสินค้าจาก 3 ร้านจะสร้าง 3 Order แยกกันจริงตามจำนวนร้านที่แตกต่างกัน ไม่ใช่ Order เดียวรวม

### ตรวจปุ่มยกเลิก/ยืนยันรับสินค้าซ่อนตามสถานะ

อ่าน `zoky_order_detail_screen.dart`'s `build()` ยืนยันว่า `bottomNavigationBar: (order != null && order.status == OrderStatus.pending) ? _buildActionBar(context) : null` — ปุ่มทั้งคู่หายไปทั้งแถบจริง (ไม่ใช่แค่ disable) เมื่อสถานะเป็น `delivered`/`cancelled` ตรวจ test 3 ตัว (`shows Cancel/Confirm Received buttons when status is pending`, `hides ... when status is delivered`, `hides ... when status is cancelled`) ครอบคลุมครบทั้ง 3 สถานะจริง

### ไล่ Requirements/Design Components/Acceptance Criteria ทีละบรรทัด

ไล่ครบทั้ง 3 หัวข้อเทียบกับโค้ดจริงทั้ง 6 หน้าจอ (`product_detail_screen.dart`, `zoky_cart_screen.dart`, `zoky_checkout_address_screen.dart`, `zoky_checkout_summary_screen.dart`, `zoky_order_list_screen.dart`, `zoky_order_detail_screen.dart`) — **AC ทั้ง 12 ข้อผ่านครบ**:
- Add to Cart เข้าตะกร้าจริง + กดซ้ำ product+variant เดิมเพิ่ม quantity แทนสร้างแถวใหม่ (ยืนยันจาก `addToCart()`'s select-existing-then-update-or-insert logic)
- ซื้อเลย เข้าตะกร้า+พาไป Cart ทันที
- Cart icon เปิด `ZokyCartScreen` จริง badge ตัวเลขถูกต้อง (นับจำนวนแถว ไม่ใช่ผลรวม quantity ตรงตาม convention มาตรฐาน)
- Cart จัดกลุ่มตามร้าน/ปรับ quantity/ลบได้/quantity ปรับเกิน stock ปัจจุบันไม่ได้ (`QuantityStepper`'s `max: product.stock` ที่มาจากข้อมูล product สดตอน fetch ไม่ใช่ค่าค้างตอน add-to-cart)
- Checkout เห็นสรุปยอดแยกต่อร้าน+ค่าธรรมเนียมก่อนยืนยันจริง (2 หน้าจอแยกตาม Design)
- ยืนยันสำเร็จสร้าง Order แยกทีละร้าน/หัก stock/ลบ cart_items ที่สั่งไป (ตรวจแล้วทั้งหมดในฟังก์ชันเดียวกัน)
- stock ไม่พอถูกปฏิเสธไม่สร้าง Order ติดลบ (ตรวจ atomicity แล้วข้างต้น)
- Orders icon เปิด `ZokyOrderListScreen` เห็นแค่ของตัวเอง (RLS+client filter สองชั้น)
- Order Detail แสดง snapshot ถูกต้องไม่ query ราคาปัจจุบันซ้ำ (`order_items.product_name`/`unit_price` เป็น column จริงไม่ใช่ join)
- ยกเลิกได้เฉพาะ pending คืน stock ถูกต้อง (ตรวจ SQL แล้ว)
- ยกเลิก/ยืนยัน Order คนอื่นไม่ได้ (ตรวจ attack scenario แล้ว)
- ไม่มี regression (233/233)

ตรวจ Design Components เพิ่มเติม: order status badge มีสี+icon+ข้อความคู่กันเสมอจริง (`OrderStatusBadge`'s `_labels`/`_icons` map ครบ 3 สถานะ ไม่มีจุดไหนสื่อความหมายด้วยสีอย่างเดียว), ปุ่มยกเลิก/ยืนยันรับสินค้ามี confirm dialog ก่อนเสมอจริง (`_confirmDialog` helper ใน `ZokyOrderDetailScreen` เรียกก่อนทั้งสอง action), Checkout แยก 2 หน้าจอจริงตามที่ Design ตัดสินใจ (ไม่ใช่หน้าเดียวยาว), Cart badge มิเรอร์โครง notification bell badge (WYN-012) เป๊ะจริง (เทียบโค้ด `_buildCartButton` กับ `_buildNotificationButton` บรรทัดต่อบรรทัด — โครงสร้าง `Stack`+`Positioned`+`Container` เหมือนกันทุกประการ)

### Red→Green Regression Proof อิสระ (verify บั๊กที่ Coding เจอและแก้เอง)

ทำ red→green proof อิสระของตัวเองสำหรับบั๊ก `mainAxisSize: MainAxisSize.min` ที่ Coding รายงานว่าพบและแก้เอง:
1. ลบ `mainAxisSize: MainAxisSize.min` ออกจาก `_buildBottomBar`'s `Column` ใน `zoky_cart_screen.dart` ชั่วคราว
2. รัน `flutter test test/zoky_cart_screen_test.dart` → **FAIL จริง 9 จาก 11 test** (ตรงกับที่ Coding อธิบายว่าทั้งหน้าจอว่างเปล่าเมื่อตะกร้ามีสินค้า — ยืนยันว่าไม่ใช่แค่คำกล่าวอ้างลอย ๆ)
3. `git checkout -- app/lib/features/zoky/presentation/zoky_cart_screen.dart` คืนค่าเดิม
4. รัน `flutter test test/zoky_cart_screen_test.dart` อีกครั้ง → **11/11 ผ่านครบ**
5. รัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด 233/233

### Regression กับ ZOKY-001/ZOKY-002/WYN Social เดิมทั้งหมด

233/233 tests ครอบคลุม Drop/Pop/Home/Follow/Search/Profile/Notification/Club Core/Club Discovery/ZOKY-001 (Browse)/ZOKY-002 (Search) เดิมทั้งหมดผ่านหมด ไม่มี regression — ยืนยันเพิ่มเติมด้วย `git show f7f6259 --stat` ว่าไฟล์ที่แก้ทั้งหมด 27 ไฟล์อยู่ใต้ `app/lib/features/zoky/`, `app/test/` (เฉพาะไฟล์ ZOKY), `supabase/schema.sql` (เพิ่มท้ายไฟล์อย่างเดียว ไม่มี ALTER/DROP ตารางเดิม), และเอกสารกำกับดูแล (`CONTEXT.md`/`PATTERNS.md`/task file) เท่านั้น — ไฟล์เดียวที่แก้ไขนอกโฟลเดอร์ ZOKY ตรงตามที่ตั้งใจคือ `product_detail_screen.dart`/`zoky_home_screen.dart` (ทั้งคู่เป็นไฟล์ ZOKY-001 ที่ต้องแก้เพื่อเชื่อมปุ่มเข้ากับ Cart จริงตามขอบเขตงาน)

### Minor finding (ไม่ block)

**ไม่มี regression test ครอบคลุมวงจร Cart badge refresh หลัง checkout สำเร็จแบบ end-to-end** (ZOKY Home → เปิด Cart → Checkout → ยืนยันสำเร็จ → กลับมา ZOKY Home แล้ว badge ต้องลดลง/หายไป) — ตรวจโค้ดแล้วเชื่อว่าทำงานถูกต้องจริง (`_openCart()`'s `await Navigator.push(...)` จะ resolve เมื่อ route ของ `ZokyCartScreen` ถูก pop ออกจาก stack ไม่ว่าจะ pop ทีละขั้นหรือถูก `popUntil` ข้ามไปพร้อมกันจากหน้า Checkout Summary ก็ตาม เป็นพฤติกรรมมาตรฐานของ Flutter Navigator ไม่ใช่จุดเสี่ยงเฉพาะโปรเจกต์นี้) แต่ยังไม่มี automated test พิสูจน์ end-to-end จริง — ไม่ block เพราะเป็น UX polish ไม่ใช่ AC ที่ระบุไว้ตรง ๆ (AC เขียนแค่ "badge ตัวเลขจำนวนรายการถูกต้อง" ตอนเปิดหน้า Cart ซึ่งมี test ครอบคลุมแล้ว) เสนอเป็น fast-follow item เดียวกับ pattern ที่เคยพบใน WYN-012/WYN-013 (badge-refresh-after-return cycle ไม่มี regression test ถาวร)

### สรุป

ZOKY-003 ผ่าน QA รอบ 1 — **PASS** พบ Minor 1 จุดไม่ block การอนุมัติ — เป็น task ที่มีความเสี่ยง data-integrity สูงที่สุดเท่าที่เคยทำในโปรเจกต์นี้ (เงิน/stock/transaction หลายตาราง) แต่ atomicity/security ของ RPC ทั้ง 3 ตัวถูกต้องครบทุกจุดที่ตรวจ อนุมัติเข้า `approved/`
