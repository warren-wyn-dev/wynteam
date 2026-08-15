# Product Task — SELLER-002

Status: backlog
Owner: AI Product Manager

Feature: ZOKY Sellers by WYN — Product Management (list/create/edit/hide, variants, stock)

Goal: แทนที่ "สินค้า" tab ที่เป็น `SellerComingSoonScreen` placeholder ด้วยหน้าจอจัดการสินค้าจริง ให้ seller สร้าง/แก้ไข/ซ่อนสินค้าของร้านตัวเองได้ พร้อม variant (สี/ขนาด) และปรับ stock ได้อย่างปลอดภัย — เป็นฐานให้ SELLER-003 (Order Management) ทดสอบ end-to-end flow ด้วยสินค้าจริงที่ seller สร้างเอง แทนที่จะพึ่งข้อมูล seed จาก Supabase Studio เหมือนที่ ZOKY-001 ถึง ZOKY-004 ทำมาตลอด

Target User: Seller ที่มีร้านค้าแล้ว (ผ่าน SELLER-001's "สมัครร้าน")

Problem: SELLER-001 สร้างร้านได้แต่ไม่มีสินค้าให้ขายเลย (`products`/`product_variants` มีแค่ select-all-authenticated policy ไม่มี insert/update/delete policy ให้ client ตั้งแต่ ZOKY-001 — ทุกสินค้าที่มีอยู่ตอนนี้ถูก seed ผ่าน Supabase Studio ตรง ๆ) Seller tab "สินค้า" ยังเป็น placeholder "เร็ว ๆ นี้" อยู่

Requirements:

**1. แทนที่ tab "สินค้า"**
- `SellerHomeShell` tab ที่ 2 ("สินค้า", index 1) เปลี่ยนจาก `SellerComingSoonScreen` เป็น `SellerProductListScreen` จริง — 4 tab ที่เหลือ (คำสั่งซื้อ/ร้านค้า/การเงิน) ยังเป็น placeholder เหมือนเดิมจนกว่า SELLER-003/004/005 จะเติม ไม่แตะ 3 tab นั้น

**2. รายการสินค้าของร้าน (`SellerProductListScreen`)**
- แสดงเฉพาะสินค้าของร้านตัวเอง (`store_id` = ร้านของ seller ที่ sign-in อยู่) — ไม่มีทางเห็นสินค้าร้านอื่นแม้พยายาม query ตรง ๆ (ต้องพิสูจน์ด้วย RLS)
- Filter chip: ทั้งหมด / กำลังขาย (`is_active = true`) / ปิดการขาย (`is_active = false`) / สินค้าหมด (`stock = 0`)
- ค้นหาภายในร้านตัวเอง: match ชื่อสินค้า หรือ SKU (ILIKE, เรียกผ่าน `.ilike()` ตรงเหมือน ZOKY-002 ไม่ผ่าน `.or()` string — บทเรียนตรงจาก ZOKY-002/ZOKY-004)
- แต่ละแถวแสดง: รูปแรก (thumbnail), ชื่อ, ราคา, stock รวม (products.stock), badge สถานะ (กำลังขาย/ปิดการขาย), แตะเพื่อแก้ไข
- ปุ่ม "+ เพิ่มสินค้า" เปิด `CreateProductScreen`

**3. สร้างสินค้าใหม่ (`CreateProductScreen`)**
- ฟิลด์: ชื่อ (บังคับ, 1-200 ตัวอักษร ตาม constraint เดิมของ `products.name`), รูปภาพ (บังคับอย่างน้อย 1 รูป สูงสุด 10 รูป ตาม constraint เดิม `products_image_urls_length`, รูปแรก = thumbnail หลัก), ราคา (บังคับ, >= 0), ราคาก่อนลด (ไม่บังคับ, ถ้ามีต้อง >= ราคาจริงตาม constraint เดิม), หมวดหมู่ (เลือกจาก `categories` table เดิม — **บังคับเลือก 1 หมวดในฟอร์มสร้างสินค้าใหม่** แม้คอลัมน์ `category_id` จะ nullable ในระดับ DB ก็ตาม เพื่อคุณภาพ discovery/filter ของฝั่งลูกค้าที่ ZOKY-002 ทำไว้แล้ว — สินค้าเดิมที่ seed ผ่าน Studio ไม่ถูกกระทบ), คำอธิบาย (ไม่บังคับ), stock เริ่มต้น (บังคับ, จำนวนเต็ม >= 0, default 0), SKU (ไม่บังคับ, free text, ไม่บังคับ unique ในรอบนี้)
- Variant (สี/ขนาด): เพิ่มได้หลายแถวต่อ type เดิม (`product_variants.variant_type` = `'color'` หรือ `'size'`, `variant_value` เช่น "แดง"/"M", `price_delta` ไม่บังคับ, `stock` ต่อ variant) — **ยึด data model แบบ flat list ต่อ type เดิมจาก ZOKY-001 ตรง ๆ ไม่ทำเป็น combination matrix ใหม่ (เช่น "แดง-M" เป็น SKU เดียว)** เพราะ ZOKY-001's Product Detail แสดง variant เป็น chip แยกสองกลุ่ม (สี/ขนาด) แบบ preview-only อยู่แล้ว เปลี่ยน data model ตอนนี้จะกระทบ UI ฝั่งลูกค้าที่ผ่าน QA แล้วโดยไม่จำเป็น — variant เป็น optional ทั้งหมด (สินค้าไม่มี variant ก็สร้างได้ปกติ)
- กด "สร้างสินค้า" → insert `products` row (+ `product_variants` rows ถ้ามี) → กลับไปหน้ารายการเห็นสินค้าใหม่ทันที

**4. แก้ไข/ลบสินค้า (`EditProductScreen`)**
- แก้ไขได้ทุกฟิลด์ยกเว้น stock (ดูข้อ 5 — stock แก้ผ่านช่องทางแยกเท่านั้น) — ชื่อ/รูปภาพ/ราคา/ราคาก่อนลด/หมวดหมู่/คำอธิบาย/SKU ใช้ RLS update ธรรมดา scope ด้วย ownership (ไม่ใช่ operation ที่ต้อง atomic ข้ามตาราง เหมือนที่ Product spec ของ ZOKY-003 แยกไว้ชัดเจนระหว่าง "cart/product write ธรรมดา" กับ "order write ที่ต้อง RPC")
- **การตัดสินใจ Delete: Soft-delete เท่านั้น (ไม่มี hard-delete ในรอบนี้)** — เหตุผล:
  1. `order_items.product_id` เป็น `on delete set null` (ไม่ใช่ `cascade`) อยู่แล้วตั้งแต่ ZOKY-003 และ `order_items` เก็บ snapshot ชื่อ/ราคา/รูปไว้ครบ (`product_name`/`unit_price`/`image_url`) — ดังนั้นแม้ hard-delete จะไม่ทำลาย order history ที่แสดงผลได้จริง แต่จะทำให้ order เก่าเสียลิงก์กลับไปหน้าสินค้าจริงถาวร และ `Best Selling Products` ของ SELLER-001 Dashboard ยัง reference `product_name` จาก `order_items` ตรง ๆ (ไม่ join `products` สด) จึงไม่กระทบอยู่แล้วไม่ว่าจะ soft/hard delete — แต่ **cart_items.product_id เป็น `on delete cascade`** หมายความว่า hard-delete จะลบสินค้าออกจากตะกร้าของลูกค้าคนอื่นแบบเงียบ ๆ ทันทีโดยไม่มีการแจ้งเตือน ต่างจาก soft-delete ที่ยังให้ cart/checkout แสดง error ที่สื่อความหมายได้ว่า "สินค้าไม่พร้อมจำหน่ายแล้ว"
  2. Seller ต้องการ "หยุดขายชั่วคราว" บ่อยกว่า "ลบถาวร" จริง ๆ (สินค้าหมดฤดูกาล, พักสต็อก) — soft-delete รองรับทั้งสองเคสด้วยกลไกเดียว ส่วน hard-delete ทำคืนไม่ได้เลยถ้ากดผิด
  3. Implementation: เพิ่มคอลัมน์ `products.is_active boolean not null default true` — ปุ่ม "ลบสินค้า" ใน `EditProductScreen` และ toggle ใน list เป็นกลไกเดียวกัน (`is_active = false`) ไม่แยก "delete" กับ "disable" เป็นสองสถานะ เพื่อความง่ายและปลอดภัยของ order history ในรอบแรก — ปุ่ม "ลบสินค้า" มี confirm dialog อธิบายชัดว่า "สินค้านี้จะถูกซ่อนจากลูกค้าทันที ประวัติคำสั่งซื้อเดิมไม่ได้รับผลกระทบ กู้คืนได้ภายหลังผ่านตัวกรอง 'ปิดการขาย' ในรายการสินค้า" — ไม่มี hard-delete option ในรอบนี้ (fast-follow ในอนาคตถ้าต้องการ "ลบถาวร" เฉพาะสินค้าที่ไม่เคยมี `order_items` อ้างอิงเลย)
  4. **ไม่มี DELETE RLS policy ให้ `products` เลยในรอบนี้** (ตรงตามเหตุผลข้างต้น) — มีแค่ insert/update
- `product_variants`: **hard-delete ได้จริง** (ต่างจาก products) เพราะไม่มี FK ใดใน `cart_items`/`order_items` ชี้กลับมาที่ `product_variants.id` เลย (`variant_selection` เป็น free-text snapshot ไม่ใช่ FK ตั้งแต่ ZOKY-003) — ลบแถว variant ที่ไม่ขายแล้วออกจากฟอร์มแก้ไขได้ตรง ๆ ปลอดภัย

**5. จัดการ stock**
- **Stock แก้ไม่ได้ผ่านฟอร์ม Edit สินค้าทั่วไป** — ต้องผ่านช่องทาง "ปรับสต็อก" แยกเฉพาะ (ปุ่ม +/- หรือ stepper ต่อสินค้า/ต่อ variant ใน `EditProductScreen` หรือหน้าย่อย) ที่ส่ง **delta** (จำนวนที่จะเพิ่ม/ลด) ไม่ใช่ค่าตัวเลขสัมบูรณ์
- เหตุผล (race condition): ถ้า client อ่านค่า stock ปัจจุบันมาคำนวณเองแล้วส่งค่าใหม่กลับไปด้วย raw UPDATE ธรรมดา จะเกิด lost-update race ได้จริงถ้ามีสอง request แก้ stock พร้อมกัน (เช่น seller เปิดแอปสองเครื่อง หรือ double-tap) — และยิ่งสำคัญกว่านั้นคือ stock ของ `products` ถูกหักแบบ atomic โดย `create_orders()` RPC (ZOKY-003, ล็อกแถวด้วย `for update` ก่อนหัก) อยู่แล้ว ถ้า seller ปรับ stock ด้วย raw UPDATE ที่ไม่ atomic พร้อมกับที่มีลูกค้ากำลัง checkout พอดี อาจเกิด stock ไม่ตรงความจริงได้
- **การปรับ stock ต้องทำผ่าน RPC (security definer) 2 ตัวใหม่**: `adjust_product_stock(product_id, delta)` และ `adjust_variant_stock(variant_id, delta)` — แต่ละตัวตรวจ ownership (`exists` join กลับ `stores.owner_id = auth.uid()`) แล้วทำ `update ... set stock = stock + delta where id = ...` เป็นคำสั่งเดียว (atomic ในตัวเองจาก Postgres row-level lock ของ UPDATE statement เดียว ไม่ต้อง read-then-write ฝั่ง client) — CHECK constraint เดิม (`stock >= 0`) ปฏิเสธ transaction ถ้าลดจนติดลบ (RPC ควร catch แล้วคืน error ที่สื่อความหมาย เช่น "สต็อกไม่พอ" แทนที่จะโยน Postgres error ดิบ) — ไม่ต้องกังวลเรื่อง deadlock กับ `create_orders()`'s multi-row `for update` เพราะ RPC นี้แตะแค่ 1 แถวเสมอ (ไม่ใช่หลายแถวพร้อมกันแบบ checkout จึงไม่มี lock-ordering ที่จะ deadlock กันเอง — อย่างมากก็แค่รอคิวถ้าแถวเดียวกันถูกล็อกอยู่)
- แนะนำ Coding พิจารณาใช้ column-level privilege (`revoke update (stock) on products from authenticated` + `grant update` เฉพาะคอลัมน์อื่น, ทำแบบเดียวกันกับ `product_variants.stock`) เป็น defense-in-depth เสริมจาก RLS ปกติ เพื่อบังคับว่าคอลัมน์ stock แก้ได้ทางเดียวคือผ่าน RPC เท่านั้น (RPC เป็น security definer จึงข้าม column privilege ของ caller ได้) — เป็นคำแนะนำ ไม่ใช่ hard requirement ถ้า Coding ประเมินว่าซับซ้อนเกินจำเป็นในรอบแรก ให้บังคับที่ชั้น UI/Dart แทน (ไม่ expose ช่องกรอก stock แบบตั้งค่าตรง ๆ ที่ไหนเลยนอกจากตอนสร้างสินค้าใหม่ที่ไม่มี concurrent access ให้ race)
- **สินค้าใหม่ (create)**: stock เริ่มต้นตั้งค่าตรง ๆ ผ่าน insert (ไม่มี concurrent access ที่จะ race กับแถวที่ยังไม่มีอยู่ จึงไม่ต้องผ่าน RPC)

**6. Database — RLS/schema changes**
- `products`: เพิ่มคอลัมน์ `is_active boolean not null default true`, `sku text` (nullable) — เพิ่ม insert policy (`with check` ตรวจ `exists (select 1 from stores where stores.id = products.store_id and stores.owner_id = auth.uid())`) และ update policy (`using` + `with check` เดียวกัน — สองฝั่งตามบทเรียนตรงจาก ZOKY-004's update-policy-gap ที่เคยเป็นช่องโหว่ Critical) — **ไม่มี delete policy** (soft-delete only ตามข้อ 4)
- `product_variants`: เพิ่ม insert/update/delete policy scope ผ่าน `exists` join สองชั้น (`product_variants.product_id → products.store_id → stores.owner_id = auth.uid()`) ทั้งสามคำสั่ง (`using`+`with check` ให้ update ตามหลักการเดียวกัน)
- เพิ่ม storage bucket ใหม่ `product-images` (**public**, ต่างจาก `club-media` เพราะ `products` เป็น select-all-authenticated ไม่มี privacy boundary อยู่แล้วเหมือน `drop-images`/`pop-videos`) — path convention `{store_id}/{timestamp}-{n}.*`, insert/update/delete storage policy scope ด้วย `exists` join กลับ `stores.owner_id = auth.uid()` ผ่าน folder path เดียวกับที่ `club-media` ใช้ตรวจ `club_role` จาก `(storage.foldername(name))[1]`
- เพิ่ม RPC `adjust_product_stock`/`adjust_variant_stock` ตามข้อ 5
- **แก้ไข `create_orders()` RPC ของ ZOKY-003 เพิ่ม 1 เงื่อนไข**: ต้องตรวจ `products.is_active = true` ในขั้นตอนเดียวกับที่ตรวจ/ล็อก stock อยู่แล้ว (ไม่งั้นสินค้าที่ seller "ลบ" (ซ่อน) ไปแล้วแต่ลูกค้าเผลอมีอยู่ในตะกร้าเดิมจะยังสั่งซื้อผ่านได้ ขัดกับเจตนาของ soft-delete ตรง ๆ) — **นี่คือการแก้โค้ด RPC ที่ผ่าน QA แล้วของ ZOKY-003 จึงต้องระมัดระวังเป็นพิเศษ**: เพิ่มแค่เงื่อนไขเดียวในจุดตรวจสอบเดิม ไม่แตะ locking order/logic ที่ QA ตรวจสอบละเอียดไปแล้ว (ล็อก `for update order by id` ก่อนตรวจ stock) และต้อง regression-test ทุกเคสของ ZOKY-003 เดิมซ้ำให้ครบ (ไม่ใช่แค่เคสใหม่)
- **ZOKY-001/ZOKY-002 (customer-facing browse/search ที่ผ่าน QA แล้ว) ต้องเพิ่ม filter `is_active = true`** ในทุก query ที่ดึงรายการสินค้าให้ลูกค้าเห็น (`ZokyRepository`'s fetch methods, `ZokySearchScreen`'s product search) — เพราะ RLS select policy ของ `products` เป็น select-all-authenticated ใช้ร่วมกันทั้งฝั่งลูกค้าและฝั่ง seller (seller ต้องเห็นสินค้า inactive ของตัวเองในรายการจัดการได้ จึง filter `is_active` ที่ query-level ของ Dart แทนที่จะทำที่ RLS) — **เป็นการแก้โค้ด/query ของ task ที่ผ่าน QA แล้ว (ZOKY-001/002) ที่จำเป็นต้องทำ ไม่ใช่การมองข้าม** เพราะ `is_active` default `true` ทำให้สินค้าเดิมทั้งหมดยังแสดงผลเหมือนเดิมทุกประการ ไม่เกิด regression ที่มองเห็นได้ — เตือน Coding ให้รัน regression test เดิมของ ZOKY-001/002 ครบทุกเคสหลังแก้

Acceptance Criteria:
- [ ] tab "สินค้า" แสดง `SellerProductListScreen` จริงแทน placeholder เดิม 4 tab ที่เหลือยังเป็น placeholder เหมือนเดิม ไม่ crash
- [ ] Seller เห็นเฉพาะสินค้าร้านตัวเองใน list ไม่เห็นของร้านอื่นแม้พยายาม query ตรง ๆ (ตรวจฝั่ง server/RLS)
- [ ] Filter (ทั้งหมด/กำลังขาย/ปิดการขาย/สินค้าหมด) และค้นหา (ชื่อ/SKU) ทำงานถูกต้อง scope เฉพาะร้านตัวเอง
- [ ] สร้างสินค้าใหม่สำเร็จพร้อมรูปภาพ/ราคา/หมวดหมู่/stock เริ่มต้น/variant (ถ้ามี) ครบตาม validation ที่กำหนด (ชื่อ 1-200 ตัวอักษร, รูปภาพ 1-10 รูป, ราคาก่อนลด >= ราคาจริง, stock >= 0)
- [ ] แก้ไขสินค้าได้ทุกฟิลด์ยกเว้น stock (ไม่มีช่องกรอก stock ตรง ๆ ในฟอร์ม edit)
- [ ] กด "ลบสินค้า" → `is_active = false` → สินค้าหายจากหน้า ZOKY Home/Search ของลูกค้าทันที (ZOKY-001/002 filter `is_active`) แต่ยังปรากฏใน seller's product list ภายใต้ filter "ปิดการขาย" และยัง toggle กลับมาขายใหม่ได้
- [ ] **ไม่มี DELETE RLS policy ให้ `products`** (ยืนยันว่าไม่มีทาง hard-delete ผ่าน client) — มีแค่ insert/update
- [ ] `product_variants` ลบแถวได้จริง (hard-delete) ต่อ ownership ของตัวเองเท่านั้น
- [ ] ปรับ stock (+/-) ผ่าน RPC เท่านั้น ไม่มีทาง set stock เป็นค่าสัมบูรณ์ผ่าน raw update จาก client — ทดสอบ concurrent adjustment 2 request พร้อมกันไม่ทำให้ stock ผิดพลาด (lost update)
- [ ] ปรับ stock ให้ติดลบถูกปฏิเสธด้วย error message ที่สื่อความหมาย ไม่ crash
- [ ] Seller A (ร้าน X) ไม่สามารถ insert/update/adjust-stock ของสินค้า/variant ร้าน Y ได้เลยแม้พยายามส่ง id ตรง ๆ (RLS + RPC ownership check ทั้งคู่ต้องปฏิเสธ)
- [ ] Insert/Update policy ของ `products`/`product_variants` มีทั้ง `using`+`with check` ครบ (ป้องกัน retarget `store_id`/`product_id` ไปร้านอื่น)
- [ ] `create_orders()` (ZOKY-003) ปฏิเสธการสั่งซื้อสินค้าที่ `is_active = false` แม้จะยังค้างอยู่ในตะกร้าของลูกค้าก็ตาม — ทดสอบ regression ครบทุกเคสเดิมของ ZOKY-003 ไม่มี regression
- [ ] ZOKY-001 (Home/Product Detail/Store) และ ZOKY-002 (Search) ไม่แสดงสินค้าที่ `is_active = false` เลย — regression test เดิมของทั้งสอง task ยังผ่านครบ (เพราะ default `is_active = true`)
- [ ] Storage bucket `product-images` เป็น public, seller อัปโหลดได้เฉพาะ path ของร้านตัวเอง (ownership check ผ่าน folder path)
- [ ] WYN Social (`app/`) และ SELLER-001 (auth/dashboard/nav) เดิมทั้งหมดยังทำงานปกติ ไม่มี regression

Dependencies: SELLER-001 (Foundation — Approved, ต้องมี `seller_app/`/`SellerHomeShell`/`SellerRepository` อยู่แล้ว), ZOKY-001 (schema `products`/`product_variants`/`categories` — Approved), ZOKY-003 (RPC `create_orders()` ที่ต้องแก้เพิ่ม 1 เงื่อนไข — Approved)

Priority: P0 ของ Phase 4 ถัดจาก SELLER-001 — ตาม roadmap (`SELLER-002 ทำก่อน SELLER-003 เพราะต้องมีสินค้าที่ seller คุมเองได้ก่อนถึงจะทดสอบ order flow แบบ end-to-end จริงได้`)

Risks:
- **แก้โค้ดของ task ที่ผ่าน QA แล้ว 2 จุด** (ZOKY-001/002's fetch queries, ZOKY-003's `create_orders()` RPC) — มีความเสี่ยง regression สูงกว่าปกติเพราะไม่ใช่ diff เฉพาะไฟล์ใหม่ล้วน ต้องรัน regression suite เดิมของทั้งสาม task ครบทุกเคส ไม่ใช่แค่เคสใหม่ของ SELLER-002 เอง
- **Column-level stock write protection เป็นทางเลือกไม่บังคับ**: ถ้า Coding เลือกไม่ implement column-level GRANT/REVOKE (บังคับที่ชั้น Dart/UI แทน) ยังมีความเสี่ยงทางทฤษฎีที่ raw RLS update policy จะยอมให้แก้ stock ตรง ๆ ถ้ามี bug ในโค้ด Dart ที่เผลอส่ง field `stock` เข้าไปในคำสั่ง update ทั่วไป — เตือน QA ให้ตรวจทั้งสองชั้น (RLS policy + Dart call site) ว่าไม่มีจุดไหนส่ง absolute stock value ผ่าน raw update เลย
- **Variant stock ไม่ถูกบังคับใช้ที่ checkout จริง**: `create_orders()` ยังหักจาก `products.stock` เท่านั้น (ไม่หัก `product_variants.stock`) เหมือนที่ ZOKY-003 ตั้งใจไว้ตั้งแต่ต้น (variant ยัง preview-only ที่จุดซื้อจริง) — seller จะเห็น/ปรับ stock ต่อ variant ได้ในแอปนี้ แต่ตัวเลขที่ "หักจริง" ตอนลูกค้าซื้อยังอิงจาก stock รวมของสินค้า (`products.stock`) เท่านั้น — เป็น known limitation ที่สืบทอดจาก ZOKY-003 ไม่ใช่บั๊กใหม่ที่ SELLER-002 สร้างขึ้น แนะนำ fast-follow ในอนาคตเมื่อ variant selection กลายเป็นตัวเลือกซื้อจริง (ไม่ใช่แค่ preview) ถึงจะคุ้มค่าที่จะ refactor `create_orders()` ให้หักจาก variant stock ด้วย
- **บังคับเลือกหมวดหมู่ตอนสร้างสินค้าใหม่ทั้งที่ DB column nullable**: เป็นการตัดสินใจ UX ของ Product ไม่ใช่ DB constraint ใหม่ — สินค้าที่ seed ผ่าน Studio ก่อนหน้า (บางรายการอาจไม่มีหมวดหมู่) ไม่ถูกกระทบและไม่ต้อง backfill
- **SKU ไม่บังคับ unique**: อาจมีสินค้าซ้ำ SKU กันได้ในรอบนี้ (ยอมรับความเสี่ยงนี้เพื่อความง่าย ไม่ block การส่งมอบ) — เพิ่ม unique constraint ต่อร้านได้ในอนาคตถ้าจำเป็นจริง

Recommendation:
1. เริ่ม Design ทันทีหลังจาก Product spec นี้ — จุดที่ต้องเน้นเป็นพิเศษคือ RLS ownership pattern (`using`+`with check` ครบทุก update policy ตามบทเรียน ZOKY-004) และ RPC atomic stock adjustment (บทเรียน ZOKY-003)
2. Coding ต้อง sync branch ใหม่ก่อนแก้ `create_orders()` และรัน `flutter test`/regression ของ ZOKY-001/002/003 อิสระให้ครบก่อนส่ง QA — ไม่ใช่แค่ยืนยันตัวเลขรวมผ่าน แต่ต้องยืนยันว่าเคสเดิมที่เคย pass ยัง pass เป๊ะทุกเคส (มาตรฐานเดียวกับที่ QA ทำมาตลอดทุก task)
3. เน้น QA ตรวจ RLS ownership ของ `products`/`product_variants` และ RPC ownership check ของ `adjust_product_stock`/`adjust_variant_stock` ด้วย attack scenario ข้าม store แบบเดียวกับที่เคยพบช่องโหว่จริงใน ZOKY-004

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) `SellerProductListScreen` (filter chips/search/list row/empty state) (2) `CreateProductScreen`/`EditProductScreen` (ฟอร์ม+รูปภาพหลายรูป+variant editor) (3) กลไก "ปรับสต็อก" (+/- stepper หรือ dialog แยก) (4) confirm dialog ของ "ลบสินค้า" ที่สื่อความหมาย soft-delete ชัดเจน — ใช้ Design system เดิมของ `seller_app/` (Blue+White+Soft Gray, seed `0xFF2D6CDF`, Material 3) reuse pattern จาก `CreateStoreScreen`/`CreateDropScreen`/`ReviewFormSheet` ที่ทำได้ (โครง/pattern เดียวกัน ไม่ประดิษฐ์ visual language ใหม่) — เมื่อ Design/Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น %

## Design Output

Status: **Design เสร็จแล้ว** — เขียนที่ `.wyn/docs/design/seller-002-product-management.md`

สรุปการตัดสินใจหลัก:
1. **`SellerProductFormScreen` เดียวใช้ร่วมกันทั้งสร้าง/แก้ไข** (พารามิเตอร์ `existingProduct` nullable) แทนการแยกเป็น `CreateProductScreen`/`EditProductScreen` สองคลาส — มิเรอร์ pattern `ReviewFormSheet`'s `existingReview` ที่มีอยู่แล้วในโปรเจกต์ (ZOKY-004) ตรง ๆ ไม่ duplicate โครง TextField/validation
2. **`SellerProductListScreen`**: search box (debounce 400ms มิเรอร์ `ZokySearchScreen`) + filter chip row 4 ตัว (ทั้งหมด/กำลังขาย/ปิดการขาย/สินค้าหมด มิเรอร์ `ExploreClubsScreen`) + `SellerProductListTile` (โครงมิเรอร์ `OrderSummaryCard`) + FAB "+" (มิเรอร์ `ClubPostsTab`) — แยก empty state 2 แบบ (ร้านไม่มีสินค้าเลย มี CTA vs filter/search ไม่พบ ไม่มี CTA)
3. **รูปภาพหลายรูป**: มิเรอร์ `CreateClubPostScreen`'s `pickMultiImage`+thumbnail row+ลบทีละรูปเป๊ะ (จำกัด 10, รูปแรก = thumbnail หลัก, ไม่มี drag-reorder รอบนี้)
4. **`StockAdjustmentSheet` ใหม่**: delta stepper เท่านั้น (มิเรอร์โครง `QuantityStepper` ปรับความหมาย) ไม่มีช่องกรอกค่าสัมบูรณ์ที่ไหนเลย บังคับใช้ atomic RPC constraint ของ Product spec ที่ชั้น UI ด้วย
5. **`ProductActiveBadge` ใหม่**: มิเรอร์หลักการ "สี+icon+ข้อความคู่กันเสมอ" ของ `OrderStatusBadge` (2 สถานะ: กำลังขาย/ปิดการขาย — ไม่ผูกกับ stock=0 เพราะเป็นคนละมิติ)
6. **Confirm dialog "ลบสินค้า" ต้องสร้างใหม่ (`confirmHideProduct`) ห้าม reuse `confirmDeletePost` ตรง ๆ** เพราะ body ข้อความเดิม ("ลบแล้วไม่สามารถกู้คืนได้") เป็นเท็จสำหรับ soft-delete — ส่วน variant hard-delete (ของจริง ลบถาวรจริง) ยัง reuse `confirmDeletePost` เดิมได้ตรง ๆ เพราะข้อความตรงกับความจริง
7. **หมวดหมู่บังคับเฉพาะโหมดสร้าง ไม่บังคับโหมดแก้ไข** (กันสินค้าเก่าที่ seed ผ่าน Studio ไม่มีหมวดหมู่แก้ไขฟิลด์อื่นไม่ได้)
8. Data model ใหม่ใน `seller_app/`: duplicate `Product`(+`isActive`/`sku`)/`ProductVariant`/`Category` ตาม pattern การ duplicate class name เดิมจาก SELLER-001's `Store`

Handoff: ส่งต่อ AI Coding (`/code`) — รายละเอียดครบทุก Screen/Widget/Dialog/Data Model/Repository method ที่ต้อง implement อยู่ใน `.wyn/docs/design/seller-002-product-management.md` ทั้งหมด (รวม "เตือน Coding" 6 ข้อท้ายเอกสารที่ย้ำจุดเสี่ยงจาก Product spec's Risks ที่กระทบ UI/UX โดยตรง)

---

## Coding Output (AI Coding)

Implementation:
- **Database (`supabase/schema.sql`, section ใหม่ "SELLER-002" ท้ายไฟล์)**: เพิ่ม `products.is_active`/`products.sku` column (`alter table ... add column if not exists`), insert/update policy ให้ `products` (`with check`/`using`+`with check` ครบ join กลับ `stores.owner_id = auth.uid()` — **ไม่มี delete policy** ตามที่ Product spec กำหนด), insert/update/delete policy ให้ `product_variants` (join 2 ชั้น `product_variants.product_id → products.store_id → stores.owner_id`), RPC ใหม่ 2 ตัว `adjust_product_stock`/`adjust_variant_stock` (security definer, รับ `p_delta int`, ตรวจ ownership ก่อนเสมอ, ทำ `update ... set stock = stock + p_delta ... returning stock` เป็นคำสั่งเดียวแล้วเช็คผลลัพธ์ `< 0` ค่อย raise `'INSUFFICIENT_STOCK'` ให้ exception rollback statement เดียวกัน — ไม่พึ่ง CHECK constraint ดิบ), storage bucket ใหม่ `product-images` (public, path `{store_id}/{timestamp}-{n}.*`, insert/update/delete policy scope ผ่าน `exists` join กลับ `stores.owner_id` จาก `(storage.foldername(name))[1]`)
- **แก้ `create_orders()` RPC ของ ZOKY-003 (จุดเสี่ยงที่ 1)**: เพิ่มแค่ `p.is_active` เข้า select list ของ loop เดิม + เพิ่ม `if not v_item.is_active then raise exception ...` 1 บล็อกก่อนเช็ค stock เดิม — **ไม่แตะ locking (`for update order by id`), ไม่แตะ insert/update/delete statement ใด ๆ ที่มีอยู่แล้ว** เป็น diff 5 บรรทัดในฟังก์ชันที่ยาวกว่า 100 บรรทัด ตรงตามคำเตือนของ Product spec เป๊ะ — ข้อความ error เป็น plain text (ไม่ใช่ `'PRODUCT_INACTIVE:<name>'` แบบมี prefix เหมือน `INSUFFICIENT_STOCK`) เพราะไม่มี AC ไหนต้องการข้อความเฉพาะเจาะจงฝั่งลูกค้า จึง fallthrough ไปที่ `rethrow`/generic catch เดิมของ `ZokyCheckoutSummaryScreen` โดยไม่ต้องแก้ไฟล์ Dart ฝั่ง Customer เลยแม้แต่บรรทัดเดียว
- **แก้ `ZokyRepository` (`app/`, จุดเสี่ยงที่ 2)**: เพิ่ม `.eq('is_active', true)` ให้ `fetchProduct`/`fetchNewProducts`/`fetchProducts`/`fetchStoreProducts`/`searchProducts`/`countStoreProducts` (6 จุดที่ query ตาราง `products` ให้ลูกค้าเห็น) — **ไม่แตะ `_storeProductIds`** (ใช้ aggregate รีวิวข้ามสินค้าทั้งร้าน ไม่ใช่การแสดงรายการสินค้าโดยตรง จึงไม่อยู่ในขอบเขตของ AC ข้อนี้) — diff ทั้งไฟล์มีแค่การเพิ่ม filter เดียวซ้ำ ๆ ไม่มีการ refactor โครงสร้างใด ๆ
- **`seller_app/lib/features/product/`**: Data model ใหม่ (`Product`+`isActive`/`sku`, `ProductVariant`+`VariantType`+`VariantInput`, `Category` — duplicate ตรงจาก `app/` ตาม pattern SELLER-001), `SellerRepository` เมธอดใหม่ 8 ตัว (`fetchCategories`/`fetchProductVariants`/`fetchProducts`/`createProduct`/`updateProduct`/`setProductActive`/`adjustProductStock`/`adjustVariantStock`), widget ใหม่ 4 ตัว (`ProductActiveBadge`, `SellerProductListTile`, `ProductVariantEditor`, `StockAdjustmentSheet`), screen ใหม่ 2 ตัว (`SellerProductListScreen`, `SellerProductFormScreen` — ใช้ร่วมกันทั้งสร้าง/แก้ไขตาม Design), dialog ใหม่ (`confirmHideProduct`) + duplicate `confirmDeletePost`/`SearchStateMessage` เข้า `seller_app/lib/core/widgets/` — `SellerHomeShell`'s tab index 1 เปลี่ยนจาก `SellerComingSoonScreen(label: 'สินค้า')` เป็น `SellerProductListScreen` จริง
- **การค้นหาชื่อ/SKU**: Design/Product ระบุ "`.ilike()` ตรง ไม่ผ่าน `.or()` string" ซึ่งเดิมมาจากบริบทที่ ZOKY-002 ค้นแค่คอลัมน์เดียว แต่ SELLER-002 ต้อง match "ชื่อ **หรือ** SKU" (2 คอลัมน์) — ตัดสินใจ **เรียก `.ilike()` แยกทีละคอลัมน์ (name, แล้ว sku) แล้ว merge/dedupe ผลลัพธ์ฝั่ง Dart** แทนที่จะสร้าง `.or()` filter DSL string ที่ต้อง escape อักขระพิเศษเอง (คอมม่า/วงเล็บ) ตรงตามเจตนาของ pattern เดิมเป๊ะ (ไม่มีจุดไหนเรียก `.or()` เลยทั้งไฟล์) — เหมาะสมเพราะ catalog ของร้านเดียวเล็กพอที่จะ query ไม่ paginate ที่ DB แล้ว paginate ฝั่ง client ได้โดยไม่มีปัญหา performance รอบนี้
- **Column-level GRANT/REVOKE สำหรับ `stock`**: ไม่ implement ตามที่ Product spec ระบุว่าเป็นทางเลือกไม่บังคับ — บังคับใช้ที่ชั้น Dart/UI แทน (`StockAdjustmentSheet`/`ProductVariantEditor` เป็นจุดเดียวที่เรียก `adjustProductStock`/`adjustVariantStock`, `updateProduct`/`createProduct` ไม่เคยส่ง field `stock` ของแถวที่มี id อยู่แล้วเข้า raw update เลย)

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. `seller_home_shell_test.dart`'s เทสต์เดิม ("the 4 not-yet-built tabs...") ต้องแก้เพราะ behavior เปลี่ยนไปตามที่ task นี้ตั้งใจ (ไม่ใช่ regression) — แก้เหลือ 3 tab ที่ยังเป็น placeholder จริง + เพิ่มเทสต์ใหม่ยืนยัน "สินค้า" แสดง `SellerProductListScreen` จริงแทน — เป็นการอัปเดต assertion ให้ตรงกับ intended behavior ใหม่ ไม่ใช่การลบ coverage ทิ้ง
2. `RecordingSellerRepository` ที่มี `adjustProductStockResult` custom ถูกสร้าง inline ใน `testWidgets` callback ตอนเขียนเทสต์ครั้งแรก (gotcha "Timer is still pending" เดิมจาก ZOKY-002/ZOKY-004/SELLER-001 — GoTrueClient's auto-refresh Timer ของ `SupabaseClient` ใหม่ที่สร้างขึ้นใน constructor ของ repository) — ย้ายเข้า `setUp()` เป็น `stockRepo` แยกจาก `repo` เดิม
3. `StockAdjustmentSheet`'s success SnackBar ทำให้ `pumpAndSettle()` รอ timer ไม่จบ (gotcha เดิมจาก `zoky_checkout_summary_screen_test.dart`) — แก้เป็น bounded pump loop (5 ครั้ง) แทน

Files Changed:
- แก้ (เสี่ยงสูง, โค้ดที่ผ่าน QA แล้ว): `supabase/schema.sql` (`create_orders()` RPC — ZOKY-003), `app/lib/features/zoky/data/zoky_repository.dart` (ZOKY-001/002)
- ใหม่: `seller_app/lib/features/product/` ทั้งโฟลเดอร์ (data + presentation + widgets), `seller_app/lib/core/widgets/confirm_delete_dialog.dart`/`confirm_hide_product_dialog.dart`/`search_state_message.dart`
- แก้ (ขยาย ไม่ทำลาย): `seller_app/lib/features/shell/presentation/seller_home_shell.dart` (tab สินค้า), `seller_app/lib/features/store/data/seller_repository.dart` (เมธอดใหม่ 8 ตัว + enum/exception ใหม่), `seller_app/lib/core/text_utils.dart` (เพิ่ม `normalizeOptionalText`), `seller_app/pubspec.yaml`/`.lock` (เพิ่ม `image_picker`)
- แก้ test เดิม: `seller_app/test/seller_home_shell_test.dart`, `seller_app/test/support/recording_seller_repository.dart` (ขยาย ไม่ลบ method เดิม)
- ใหม่: `seller_app/test/seller_product_list_screen_test.dart` (6 เทสต์), `seller_app/test/seller_product_form_screen_test.dart` (9 เทสต์), `seller_app/test/stock_adjustment_sheet_test.dart` (5 เทสต์)
- ไม่แตะไฟล์ UI ฝั่ง Customer (`app/lib/features/zoky/presentation/`) เลยแม้แต่บรรทัดเดียว — จุดเดียวที่แก้ใน `app/` คือ query layer ของ `zoky_repository.dart`

Tests:
- `seller_app/`: `flutter analyze` สะอาด, `flutter test`: **38/38 ผ่าน** (เพิ่มจาก 17 เดิมของ SELLER-001)
- `app/`: `flutter analyze` สะอาด, `flutter test`: **255/255 ผ่านเท่าเดิม** (sync `origin/main` ใหม่ก่อนเริ่ม, รันซ้ำอิสระหลังแก้ `zoky_repository.dart`/`schema.sql` — ไม่มี regression เพราะ `RecordingZokyRepository` override ทุกเมธอดที่แก้เป็น canned data ทั้งหมด ไม่เคยเรียก query จริงที่มี `.eq('is_active', true)` ใหม่เลย)
- **RLS/RPC ใหม่ทั้งหมด (products/product_variants insert-update policy, adjust_product_stock/adjust_variant_stock, product-images storage policy, create_orders()'s is_active check) ตรวจสอบด้วยการอ่าน SQL semantics เท่านั้น** ไม่มี dynamic test เพราะไม่มี Supabase project จริง deploy อยู่ในสภาพแวดล้อมนี้ — ตรงตาม convention เดิมของ ZOKY-003/004/SELLER-001 ทุกจุดที่เคยทำมา

Build: `flutter build apk`/`flutter build ios` ยังไม่ได้ทำ — สภาพแวดล้อมนี้ไม่มี Android SDK/Xcode ให้ build จริง (เหมือนสถานะเดิมทุก task ก่อนหน้า)

Known Issues:
- Concurrent stock adjustment (2 request พร้อมกัน) และ cross-store ownership attack scenario ของ RPC/RLS ใหม่ ยืนยันด้วยการอ่าน Postgres semantics เท่านั้น (row-level lock ของ single `UPDATE` statement, `exists` join ownership gate) ไม่มี live backend ให้ทดสอบจริงแบบ ZOKY-003 เดิม — เตือน QA ให้ตรวจจุดนี้ละเอียดเป็นพิเศษ
- Negative price/initial stock ที่ผู้ใช้พิมพ์เอง (ไม่ผ่าน `_canSubmit`'s client-side gate ที่เพิ่งเพิ่ม สำหรับ price >= 0) ยังพึ่ง DB CHECK constraint เป็นด่านสุดท้ายสำหรับ initial stock ติดลบ (แสดง generic error "สร้างสินค้าไม่สำเร็จ" แทน inline validation เฉพาะเจาะจง) — ไม่ crash ตรงตาม AC แต่ยังไม่ใช่ UX ที่ดีที่สุด บันทึกเป็น fast-follow ที่เสนอได้
- Variant stock ยังไม่ถูกหักจริงตอน checkout (`create_orders()` หักจาก `products.stock` เท่านั้น) — เป็น known limitation ที่สืบทอดจาก ZOKY-003 ตามที่ Product spec ระบุไว้แล้ว ไม่ใช่บั๊กใหม่

Handoff: ส่งต่อ AI QA & Security (`/qa`) — **เน้นตรวจ 2 จุดที่แก้โค้ดเดิมที่ผ่าน QA แล้วเป็นพิเศษ**: (1) `create_orders()` RPC — ยืนยันว่า locking/deadlock-prevention เดิม (`for update order by id`) ไม่ถูกกระทบเลย และ regression ทุกเคสเดิมของ ZOKY-003 ยังผ่านครบ (2) `ZokyRepository` — ยืนยันว่า `is_active` filter ใหม่ไม่กระทบพฤติกรรมเดิมที่ QA เคยตรวจผ่านมาแล้วของ ZOKY-001/002 นอกจากนี้ตรวจ RLS ownership ของ `products`/`product_variants` (insert/update ครบ `using`+`with check`, ไม่มี delete policy ให้ `products`) และ RPC ownership check ของ `adjust_product_stock`/`adjust_variant_stock` ด้วย attack scenario ข้าม store แบบเดียวกับที่เคยพบช่องโหว่จริงใน ZOKY-004
