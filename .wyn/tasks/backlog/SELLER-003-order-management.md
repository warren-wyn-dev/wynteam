# Product Task — SELLER-003

Status: backlog
Owner: AI Product Manager

Feature: ZOKY Sellers by WYN — Order Management (ขยายสถานะ Order 3→8 + Seller Order List/Detail + status transition RPC ฝั่ง seller)

Goal: แทนที่ tab "คำสั่งซื้อ" ที่ยังเป็น `SellerComingSoonScreen` placeholder ด้วยหน้าจอจริงให้ seller ดู/จัดการคำสั่งซื้อของร้านตัวเอง และขยาย `orders.status` จาก 3 สถานะ (pending/delivered/cancelled ตาม ZOKY-003) เป็น 8 สถานะเต็มตาม master prompt Section 10 (Pending Payment/Paid/Seller Processing/Ready to Ship/Shipped/Delivered/Cancelled/Refunded) — เป็น task ที่แก้โค้ด/DB ที่ผ่าน QA แล้วมากที่สุดใน Phase 4 จึงต้องระบุ migration/backward-compat ให้ชัดเจนทุกจุด

Target User: Seller ที่มีร้านค้าแล้ว (ผ่าน SELLER-001) และมีคำสั่งซื้อจริงเข้ามา (ลูกค้าซื้อผ่าน ZOKY-003)

Problem: SELLER-001 ให้ seller เห็น "จำนวน" order ผ่าน Dashboard เท่านั้น (select policy ใหม่มีอยู่แล้ว) แต่ไม่มีหน้าจอให้ดู/จัดการ order แต่ละใบเลย และไม่มีทางเปลี่ยนสถานะได้เลยสักจุด (ไม่มี write policy/RPC ฝั่ง seller) — ในขณะเดียวกัน สถานะ Order ปัจจุบันมีแค่ 3 แบบ (pending/delivered/cancelled) ที่ ZOKY-003 ตั้งใจทำแบบย่อไว้ก่อนเพราะตอนนั้นยังไม่มี ZOKY Sellers by WYN ให้เป็นฝ่าย trigger สถานะกลาง (seller processing/shipped) — ตอนนี้ถึงจุดที่ seller app มีอยู่แล้วจริง (SELLER-001/002) จึงต้องเติมสถานะที่ขาดและมอบสิทธิ์ trigger ให้ seller

Requirements:

## 0. สถาปัตยกรรม/ขอบเขตที่ตัดสินใจแล้วก่อนเริ่ม (อ้างอิง DECISIONS.md 2026-08-15)

- Order status ขยายเป็น 8 สถานะเป็นการตัดสินใจที่ Founder อนุมัติแล้วตั้งแต่ตอนรับ master prompt Section 10 เต็ม (บันทึกใน DECISIONS.md 2026-08-15 "Founder ส่งเนื้อหา Section 12-17 เต็มแล้ว...") และย้ำใน `.wyn/docs/product/zoky-platform-roadmap.md` Phase 4 — task นี้คือการ **ทำตามการตัดสินใจที่อนุมัติไว้แล้ว** ไม่ใช่การเสนอเปลี่ยนสถาปัตยกรรมใหม่ จึงไม่ต้องเปิด `APPROVAL_REQUIRED` ใหม่ (ต่างจาก WYN-004's table drop ที่เป็นการ "ทำลาย" ข้อมูล/โครงสร้างที่ไม่เคยถูกอนุมัติมาก่อน — งานนี้เป็น **schema evolution แบบ additive + data remap ที่ปลอดภัย** ไม่ลบตาราง/คอลัมน์ใด ๆ)
- **ไม่มี Supabase project จริงที่ deploy อยู่ในตอนนี้** (ทุก QA report ตั้งแต่ ZOKY-001 ยืนยันตรงกันว่าไม่มี live Postgres ให้ทดสอบ) — หมายความว่า **ไม่มีข้อมูล order จริงที่จะได้รับผลกระทบจากการ migrate สถานะรอบนี้เลย** ความเสี่ยงเชิง data-loss ของงานนี้จึงต่ำกว่าที่ชื่อ "migration" ทั่วไปสื่อถึงมาก — แต่ยังต้องเขียน migration SQL ให้ถูกต้องเป๊ะ เพราะจะเป็น script เดียวที่รันตอน deploy Supabase project จริงครั้งแรก (และเผื่อกรณีมี dev/staging Supabase ที่ engineer ในทีมเคยรัน schema.sql เดิมไปแล้วเอง)
- ไม่มี payment gateway จริงเหมือนเดิม (ตาม DECISIONS.md 2026-08-15 ข้อ 6) — Order/Finance คำนวณจาก `Order.total` เดิม ไม่เปลี่ยน
- ไม่มี Shipping Provider integration จริง — เพิ่มแค่ field ให้ seller กรอกเอง (free text) ตามที่ roadmap ระบุไว้แล้ว ("SELLER-003 จะเพิ่มช่อง Shipping Provider/Tracking Number/Shipment Status")
- ไม่แตะ RLS write policy ของ `orders`/`order_items` เลย (ยังคง select-only เหมือน SELLER-001 ตั้งใจไว้) — status transition ทั้งหมด (ทั้งฝั่ง buyer เดิมและฝั่ง seller ใหม่) ต้องผ่าน security-definer RPC เท่านั้น ตรงตามที่ roadmap doc ระบุไว้ตรง ๆ ("ยังไม่เพิ่ม write policy ให้ seller ตรง ๆ รอบนี้")

## 1. สถานะใหม่ 8 แบบ + ชื่อ/ความหมาย

อ้างอิงตรงตาม master prompt Section 10:

| ค่าใน DB (`orders.status`) | ความหมาย | ใครกดเปลี่ยนได้ |
|---|---|---|
| `pending_payment` | รอชำระเงิน | **ไม่มีใครกดเปลี่ยนเข้า/ออกสถานะนี้ได้จริงในรอบนี้** (ดูข้อ 2) |
| `paid` | ชำระเงินแล้ว (สถานะเริ่มต้นของ Order ใหม่ทุกใบรอบนี้) | ระบบตั้งอัตโนมัติตอนสร้าง Order |
| `seller_processing` | ร้านค้ากำลังเตรียมสินค้า | Seller (RPC ใหม่ `seller_start_processing`) |
| `ready_to_ship` | พร้อมจัดส่ง | Seller (RPC ใหม่ `seller_mark_ready_to_ship`) |
| `shipped` | จัดส่งแล้ว | Seller (RPC ใหม่ `seller_ship_order`, ต้องกรอก shipping provider + tracking number) |
| `delivered` | ได้รับสินค้าแล้ว | **Buyer เท่านั้น** (RPC เดิม `confirm_order_received` — แก้แค่เงื่อนไข source status) |
| `cancelled` | ยกเลิกแล้ว | Buyer (จาก `paid` เท่านั้น, RPC เดิม `cancel_order` แก้เงื่อนไข) หรือ Seller (จาก `paid`/`seller_processing`/`ready_to_ship`, RPC ใหม่ `seller_cancel_order`) |
| `refunded` | คืนเงินแล้ว (บันทึกทางบัญชีเท่านั้น ไม่มี payment gateway จริงให้คืนเงินอัตโนมัติ) | Seller เท่านั้น (RPC ใหม่ `seller_mark_refunded`, จาก `shipped`/`delivered` เท่านั้น) |

## 2. ทำไม `pending_payment` ไม่ถูกใช้จริงในรอบนี้ (ตัดสินใจชัดเจน ไม่ใช่ oversight)

ยึดเหตุผลเดียวกับที่ ZOKY-003 เคยใช้ตัดสินใจไม่สร้างสถานะกลางที่ "ไม่มีใครกดเปลี่ยนได้" (ดู ZOKY-003's Risks: สถานะที่ไม่มีใคร trigger ได้จะเป็น dead state) — ไม่มี payment gateway จริงในโปรเจกต์นี้เลย (ยืนยันจาก DECISIONS.md ซ้ำหลายครั้ง) จึงไม่มีกลไกใดจะเปลี่ยนสถานะจาก `pending_payment` ไปเป็น `paid` ได้จริง ถ้าสร้าง Order เริ่มต้นที่ `pending_payment` จะกลายเป็น order ที่ค้างตลอดกาลไม่มีทางไปต่อ

**การตัดสินใจ**: `create_orders()` RPC ยังคงสร้าง Order เสร็จแล้วตั้งสถานะเป็น **`paid` ทันที** (แทนที่ `pending` เดิม) — เทียบเท่า "เก็บเงินปลายทาง/ไม่มีขั้นตอนชำระเงินที่บล็อกการซื้อ" แบบเดียวกับที่ ZOKY-003 ทำไว้ตั้งแต่ต้น ไม่เปลี่ยนพฤติกรรมจริงของระบบเลย เปลี่ยนแค่ **ชื่อ** สถานะเริ่มต้นจาก `pending` เป็น `paid` ให้ตรงกับความหมายที่แท้จริงของมันมากขึ้น (เงินถูกจัดการเรียบร้อยแล้วในมุมมองระบบ ไม่มีอะไรค้างรอ)

`pending_payment` ยัง**คงอยู่ในค่าที่ DB constraint อนุญาต** (scaffold ไว้ตาม master prompt Section 10 เป๊ะ) เพื่อไม่ต้อง migrate schema อีกรอบเมื่อมี payment gateway จริงในอนาคต — แต่ไม่มี RPC ไหนสร้าง Order ที่สถานะนี้ในรอบนี้ และ UI (`OrderStatusBadge`) ต้องรองรับการแสดงผลสถานะนี้ไว้เผื่ออนาคต (ไม่ throw ถ้าเจอ) แม้จะไม่มีทางเกิดขึ้นจริงตอนนี้ก็ตาม — บันทึกเป็น Known Issue ชัดเจนใน Risks

## 3. Migration strategy ของสถานะเดิม (pending/delivered/cancelled) → ใหม่

- `delivered` และ `cancelled`: **คงชื่อเดิมเป๊ะ ไม่เปลี่ยน** — ทั้งสองค่ามีความหมายเหมือนเดิมทุกประการในโมเดลใหม่ (endpoint state ปลายทางเดียวกัน) ไม่ต้อง remap แถวที่มีอยู่แล้วเลย
- `pending` (เดิม) → **remap เป็น `paid`** — เพราะตามที่วิเคราะห์ไว้ในข้อ 2 แล้วว่า `pending` เดิมของ ZOKY-003 มีความหมายจริงคือ "สร้าง Order เสร็จแล้ว ไม่มีขั้นตอนจ่ายเงินค้าง" ซึ่งตรงกับนิยามของ `paid` ในโมเดลใหม่เป๊ะ ไม่ใช่ `pending_payment` (ที่แปลว่า "ยังไม่จ่ายเงิน" ซึ่งไม่ตรงกับความจริงของระบบนี้เลย)
- Migration SQL (เพิ่มท้าย `supabase/schema.sql` ตาม convention append-only เดิมของทุก task ก่อนหน้า ไม่แก้ `create table if not exists` block เดิมตรง ๆ):
  1. `update public.orders set status = 'paid' where status = 'pending';` — รันก่อนเปลี่ยน constraint เสมอ (เพราะถ้าเปลี่ยน constraint ก่อน ค่า `'pending'` ที่เหลืออยู่จะ fail ทันที เนื่องจาก `'pending'` ไม่ใช่ 1 ใน 8 ค่าใหม่) คำสั่งนี้ idempotent เองโดยธรรมชาติ (รันซ้ำกี่ครั้งก็ไม่มีผลหลังจากรอบแรก เพราะไม่มีแถว `status = 'pending'` เหลือให้ update อีก)
  2. เปลี่ยน CHECK constraint ของ `orders.status` จาก 3 ค่าเป็น 8 ค่า — **ห้าม hardcode สมมติชื่อ constraint เดิม** (เช่น `orders_status_check`) มาเขียน `drop constraint <ชื่อที่เดา>` ตรง ๆ โดยไม่ตรวจสอบก่อน แม้ Postgres จะมี naming convention ที่คาดเดาได้ (`{table}_{column}_check` สำหรับ column-level check แรกของคอลัมน์) แต่เพื่อความปลอดภัย (defense-in-depth ของ DDL ที่แก้ table ที่มีข้อมูลจริงอยู่แล้วในอนาคต) **ให้ Coding ตรวจสอบชื่อ constraint จริงจาก `information_schema.check_constraints`/`pg_constraint` ก่อน drop** (เช่นผ่าน PL/pgSQL DO block ที่ query แล้ว `execute format(...)`) แทนการ hardcode ชื่อ — ถ้าตรวจแล้วยืนยันว่าเป็น `orders_status_check` จริงตาม Postgres default naming ก็ใช้ชื่อนั้นได้ตรง ๆ แต่ต้อง verify ก่อนเชื่อ ไม่ใช่เดา
  3. เปลี่ยน default value ของคอลัมน์จาก `'pending'` เป็น `'paid'` (`alter column status set default 'paid'`) เพื่อความสอดคล้อง แม้จะไม่มี raw insert policy ให้ client ใช้ default นี้อยู่แล้วก็ตาม (ทำเพื่อความถูกต้องเชิง schema เท่านั้น)
  4. เพิ่มคอลัมน์ใหม่ `shipping_provider text` (nullable), `tracking_number text` (nullable) ผ่าน `add column if not exists`
- **ยืนยันชัดเจน: ไม่ต้องแก้ RLS policy ของ `reviews` เลย** — เพราะ gate เดิมอ้างอิง `o.status = 'delivered'` ตรง ๆ (ทั้ง insert policy และ update policy) และค่า `'delivered'` ไม่เปลี่ยนชื่อในโมเดลใหม่ ยืนยันจากการอ่าน `supabase/schema.sql` บรรทัด ~2028-2079 (ZOKY-004 section) ตรงแล้วว่าไม่มีจุดใดอ้างอิงถึง `'pending'`/สถานะกลางอื่นเลยนอกจาก `'delivered'` — เช่นเดียวกับ `ZokyRepository.fetchReviewableOrderItems()` (`app/lib/features/zoky/data/zoky_repository.dart`) ที่ filter `.eq('status', 'delivered')` ก็ไม่ต้องแก้เช่นกัน

## 4. Seller-facing status transitions — RPC ใหม่ (ไม่แก้ RPC เดิมของ buyer โดยตรง ยกเว้นเงื่อนไข source-status)

ทุกตัวเป็น security definer, ตรวจ ownership ผ่าน `exists (select 1 from public.stores where stores.id = orders.store_id and stores.owner_id = auth.uid())` (pattern เดียวกับ SELLER-001/002's ownership check ทุกจุด) — **ไม่มีตัวไหนแก้ locking/atomicity logic ของ `create_orders()` เดิมเลย** เพราะเป็นคนละฟังก์ชัน:

- `seller_start_processing(p_order_id uuid)`: `paid` → `seller_processing`
- `seller_mark_ready_to_ship(p_order_id uuid)`: `seller_processing` → `ready_to_ship`
- `seller_ship_order(p_order_id uuid, p_shipping_provider text, p_tracking_number text)`: `ready_to_ship` → `shipped` — บันทึก `shipping_provider`/`tracking_number` ในคำสั่งเดียวกัน (ทั้งสอง field บังคับกรอกที่ชั้น UI ก่อนกดยืนยัน แม้ DB จะไม่บังคับ not-null เพื่อไม่ปิดทางแก้ไขในอนาคตถ้าต้อง backfill)
- `seller_cancel_order(p_order_id uuid)`: จาก `paid`/`seller_processing`/`ready_to_ship` เท่านั้น → `cancelled` — **คืน stock กลับเข้า `products.stock`** (mirror logic เดียวกับ `cancel_order()` เดิมของ buyer เป๊ะ — loop `order_items` ที่ `product_id is not null` แล้วบวก quantity กลับ) เพราะ ณ จุดนี้สินค้ายังไม่ถูกส่งออกจากร้านจริง
- `seller_mark_refunded(p_order_id uuid)`: จาก `shipped`/`delivered` เท่านั้น → `refunded` — **ไม่คืน stock** (สินค้าออกจากร้านไปแล้วจริง การคืนสต็อกทางกายภาพเป็นกระบวนการ manual นอก scope ของ RPC นี้ — RPC นี้เป็นแค่ bookkeeping flag ว่า "คืนเงินแล้ว" เพราะไม่มี payment gateway จริงให้คืนเงินอัตโนมัติ ตามที่ระบุใน DECISIONS.md ว่า Payment/Finance ยังคำนวณจาก `Order.total` ธรรมดา)

แก้ RPC เดิม 2 ตัว (ต้องระมัดระวังเป็นพิเศษ — เป็นโค้ดที่ QA ตรวจ atomicity/security ผ่านแล้วรอบ ZOKY-003):
- `create_orders()`: จุดเดียวที่แก้คือค่า status ตอน insert จาก `'pending'` เป็น `'paid'` (1 บรรทัด) — **ห้ามแตะ locking (`for update order by id`), loop structure, หรือ business logic อื่นใดในฟังก์ชันนี้เลย** ตรงตามคำเตือนซ้ำที่ SELLER-002 เคยทำสำเร็จมาแล้วกับฟังก์ชันเดียวกันนี้ (เพิ่มแค่ `is_active` check โดยไม่แตะ locking) — ใช้ pattern เดียวกัน
- `cancel_order()` (buyer): เปลี่ยนเงื่อนไข WHERE จาก `status = 'pending'` เป็น `status = 'paid'` เท่านั้น (ไม่แตะ logic อื่น) — **เหตุผลที่ buyer ยกเลิกเองได้แค่ตอน `paid` เท่านั้น ไม่ใช่ตลอดจนถึง `ready_to_ship`**: เมื่อ seller เริ่ม `seller_processing` แล้ว แปลว่าร้านเริ่มลงมือเตรียมสินค้าจริงแล้ว การให้ buyer ยกเลิกเองต่อจากจุดนั้นจะสร้างความเสียหายที่ seller ควบคุมไม่ได้ (เสียเวลา/ต้นทุนที่เตรียมไปแล้ว) — มาตรฐานเดียวกับ marketplace ทั่วไป (เช่น Shopee) ที่ buyer ยกเลิกเองได้เฉพาะ "ก่อนร้านเริ่มดำเนินการ" หลังจากนั้นต้องติดต่อร้าน/seller เป็นคนกดยกเลิกแทน (`seller_cancel_order` รองรับกรณีนี้)
- `confirm_order_received()` (buyer): เปลี่ยนเงื่อนไข WHERE จาก `status = 'pending'` เป็น `status = 'shipped'` เท่านั้น (ไม่แตะ logic อื่น) — ตรงตาม flow ใหม่ที่ buyer ยืนยันรับสินค้าได้ก็ต่อเมื่อร้านจัดส่งแล้วจริงเท่านั้น

## 5. Seller Order List/Detail Screen ใหม่ใน `seller_app/`

- Tab "คำสั่งซื้อ" (index 2) ของ `SellerHomeShell` เปลี่ยนจาก `SellerComingSoonScreen` เป็น `SellerOrderListScreen` จริง — 2 tab ที่เหลือ (ร้านค้า/การเงิน) ยังเป็น placeholder เหมือนเดิม ไม่แตะ
- `SellerOrderListScreen`: แสดงเฉพาะ order ของร้านตัวเอง (ใช้ select RLS ที่ SELLER-001 เพิ่มไว้แล้ว ไม่มี write policy ใหม่) — filter chip ตามสถานะ (มิเรอร์ pattern filter chip จาก `SellerProductListScreen`/`ExploreClubsScreen`) เรียงใหม่สุดก่อน พร้อม pagination แบบเดียวกับ `ZokyOrderListScreen`
- `SellerOrderDetailScreen`: แสดงรายการสินค้า/ที่อยู่จัดส่ง/ข้อมูลผู้ซื้อ (ชื่อ+เบอร์โทรจาก `recipient_name`/`recipient_phone` snapshot เดิม)/ยอดรวม/สถานะปัจจุบัน (ใช้ status badge เวอร์ชัน duplicate ของ seller_app มิเรอร์ `OrderStatusBadge`'s "สี+icon+ข้อความคู่กันเสมอ" หลักการเดิม) — ปุ่ม action เปลี่ยนตามสถานะปัจจุบันเท่านั้น (แสดงเฉพาะปุ่มที่ transition ได้จริงจากสถานะนั้น ไม่ใช่ disable ปุ่มที่กดไม่ได้ — มิเรอร์ pattern เดียวกับที่ `ZokyOrderDetailScreen` ซ่อนทั้งแถบปุ่มเมื่อ Order ไม่ใช่ pending):
  - `paid`: "เริ่มเตรียมสินค้า" (→ seller_processing) + "ยกเลิกคำสั่งซื้อ" (→ cancelled, มี confirm dialog)
  - `seller_processing`: "พร้อมจัดส่ง" (→ ready_to_ship) + "ยกเลิกคำสั่งซื้อ"
  - `ready_to_ship`: ฟอร์มกรอก Shipping Provider + Tracking Number แล้วปุ่ม "ยืนยันจัดส่งแล้ว" (→ shipped, บังคับกรอกทั้งสองช่องก่อนกดได้) + "ยกเลิกคำสั่งซื้อ"
  - `shipped`: แสดง Shipping Provider/Tracking Number ที่กรอกไว้ (read-only) + ปุ่มรอง "ทำเครื่องหมายคืนเงินแล้ว" (→ refunded, มี confirm dialog อธิบายชัดว่าเป็นการบันทึกบัญชีเท่านั้น ไม่มีการโอนเงินคืนอัตโนมัติเพราะยังไม่มีระบบชำระเงินจริง) — ไม่มีปุ่มยกเลิกอีกต่อไป (buyer เป็นฝ่ายกด confirm รับสินค้าต่อไปเอง)
  - `delivered`: แสดง Shipping info read-only + ปุ่มรอง "ทำเครื่องหมายคืนเงินแล้ว" เช่นกัน (เผื่อกรณีลูกค้าขอคืนเงินหลังได้รับสินค้าแล้ว) — ไม่มีปุ่มอื่น
  - `cancelled`/`refunded`/`pending_payment`: ไม่มีปุ่ม action ใด ๆ (final state หรือ unreachable state)
- Data model: duplicate `Order` class เข้า `seller_app/` (ตาม pattern การ duplicate ที่ SELLER-001/002 ทำมาตลอด — เพิ่ม `shippingProvider`/`trackingNumber` field ด้วย), `OrderStatus` enum 8 ค่า, `SellerRepository` เมธอดใหม่ (`fetchStoreOrders` พร้อม filter สถานะ, `fetchStoreOrderItems`, `sellerStartProcessing`, `sellerMarkReadyToShip`, `sellerShipOrder`, `sellerCancelOrder`, `sellerMarkRefunded`)

## 6. Customer-facing UI ที่ต้องแก้ (โค้ดที่ผ่าน QA แล้วจาก ZOKY-003)

- `app/lib/features/zoky/data/order.dart`: `enum OrderStatus` ขยายเป็น 8 ค่า (`pendingPayment, paid, sellerProcessing, readyToShip, shipped, delivered, cancelled, refunded`), `orderStatusFromString` ขยาย switch ครบ 8 ค่า (ค่า default ที่จับไม่ได้ยังคงมีไว้เป็น fallback ป้องกัน แต่ไม่ควรเกิดขึ้นจริงเพราะ DB constraint บังคับอยู่แล้ว), เพิ่ม field `shippingProvider`/`trackingNumber` (nullable) ใน `Order` + `Order.fromMap` (ไม่ต้องแก้ query select เพราะใช้ `select('*, store:stores(name))` อยู่แล้ว คอลัมน์ใหม่มาโดยอัตโนมัติ)
- `app/lib/features/zoky/presentation/widgets/order_status_badge.dart`: ขยาย `_labels`/`_icons`/สี ให้ครบ 8 สถานะ (ยังคงหลักการ "สี+icon+ข้อความคู่กันเสมอ ไม่ใช้สีอย่างเดียว" เดิม) — เสนอ label: `pending_payment`="รอชำระเงิน", `paid`="ชำระเงินแล้ว", `seller_processing`="ร้านค้ากำลังเตรียมสินค้า", `ready_to_ship`="พร้อมจัดส่ง", `shipped`="จัดส่งแล้ว", `delivered`="ได้รับสินค้าแล้ว" (ไม่เปลี่ยน), `cancelled`="ยกเลิกแล้ว" (ไม่เปลี่ยน), `refunded`="คืนเงินแล้ว"
- `app/lib/features/zoky/presentation/zoky_order_detail_screen.dart`:
  - ปุ่ม "ยกเลิกคำสั่งซื้อ" แสดงเฉพาะ `status == OrderStatus.paid` เท่านั้น (เดิมคือ `pending`)
  - ปุ่ม "ยืนยันได้รับสินค้าแล้ว" แสดงเฉพาะ `status == OrderStatus.shipped` เท่านั้น (เดิมคือ `pending`) — ทั้งสองปุ่มยังคงอยู่ใน action bar เดียวกัน แต่ตอนนี้ไม่ได้โผล่พร้อมกันเสมอไป (ปุ่มยกเลิกอาจโผล่คนเดียวตอน `paid`, ปุ่มยืนยันรับอาจโผล่คนเดียวตอน `shipped`) — ต้องปรับ `_buildActionBar` ให้แสดงเฉพาะปุ่มที่ valid จากสถานะปัจจุบัน ไม่ใช่ show/hide ทั้งแถบแบบ all-or-nothing เหมือนเดิมอีกต่อไป
  - เงื่อนไข gate การรีวิว (`order.status == OrderStatus.delivered`) **ไม่ต้องแก้** — ยังใช้ `delivered` เหมือนเดิมถูกต้องอยู่แล้ว
  - เพิ่มการแสดงผล Shipping Provider/Tracking Number (read-only) เมื่อมีค่า (ไม่ null) — ผู้ซื้อควรเห็นเลขพัสดุเมื่อร้านจัดส่งแล้ว
- Test เดิมที่ reference `OrderStatus.pending` (`app/test/zoky_order_list_screen_test.dart`, `app/test/zoky_order_detail_screen_test.dart`) ต้องอัปเดตให้ตรงกับสถานะใหม่ (เปลี่ยนจาก `OrderStatus.pending` เป็น `OrderStatus.paid` ในจุดที่ทดสอบ "ยกเลิกได้", เพิ่มเคสใหม่สำหรับ `shipped` ที่ทดสอบ "ยืนยันรับได้") — เป็นส่วนหนึ่งของงานนี้ ไม่ใช่ regression ที่ต้องกันไว้

## 7. SELLER-001 Dashboard ที่ต้องแก้ (โค้ดที่ผ่าน QA แล้วจาก SELLER-001 — จุดที่ roadmap doc เดิมไม่ได้เอ่ยถึงตรง ๆ แต่ AI Product Manager ตรวจโค้ดจริงพบว่าต้องแก้ด้วย)

- `seller_app/lib/features/store/data/seller_repository.dart`'s `fetchOrderCounts()`: `.eq('status', 'pending')` (นับ "New Orders") ต้องเปลี่ยนเป็น `.eq('status', 'paid')` — เพราะ `paid` คือสถานะที่ seller ยังไม่ได้เริ่มดำเนินการอะไรเลย (เทียบเท่าความหมายเดิมของ "New Orders")
- `fetchSalesSummary()`/`fetchBestSellingProducts()` ที่ filter `.eq('status', 'delivered')`/`.eq('order.status', 'delivered')`: **ไม่ต้องแก้** — ยังถูกต้องตามเดิม (ยอดขายนับเมื่อลูกค้ายืนยันได้รับสินค้าแล้วเท่านั้น ความหมายไม่เปลี่ยน)

Acceptance Criteria:
- [ ] `orders.status` CHECK constraint อนุญาต 8 ค่า (`pending_payment`, `paid`, `seller_processing`, `ready_to_ship`, `shipped`, `delivered`, `cancelled`, `refunded`) — insert/update ค่านอกเหนือจากนี้ถูกปฏิเสธ
- [ ] Order ทุกใบที่มีอยู่แล้วในสถานะ `pending` (เดิม) ถูก migrate เป็น `paid` ก่อนเปลี่ยน constraint เสมอ (ลำดับ UPDATE ก่อน ALTER CONSTRAINT) — ไม่มี Order เก่าใบไหนตกหล่น/พังหลัง migration
- [ ] `delivered`/`cancelled` ของ Order เดิมไม่เปลี่ยนค่า ไม่ถูก touch โดย migration เลย
- [ ] `create_orders()` สร้าง Order ใหม่ด้วยสถานะเริ่มต้น `paid` (ไม่ใช่ `pending_payment`) — locking/atomicity/stock-check/is_active-check เดิมของ ZOKY-003/SELLER-002 ยังทำงานถูกต้องทุกจุด ไม่มี regression
- [ ] `cancel_order()` (buyer) ยกเลิกได้เฉพาะสถานะ `paid` เท่านั้น — พยายามยกเลิกตอน `seller_processing`/`ready_to_ship`/`shipped`/สถานะอื่นถูกปฏิเสธ
- [ ] `confirm_order_received()` (buyer) ยืนยันรับได้เฉพาะสถานะ `shipped` เท่านั้น — พยายามยืนยันตอนสถานะอื่นถูกปฏิเสธ
- [ ] `seller_start_processing`/`seller_mark_ready_to_ship`/`seller_ship_order`/`seller_cancel_order`/`seller_mark_refunded` ทำงานได้เฉพาะ source status ที่กำหนดไว้เท่านั้น (ตามตารางข้อ 4) เปลี่ยนสถานะอื่นถูกปฏิเสธ
- [ ] Seller A (ร้าน X) เรียก RPC ใหม่ทั้ง 5 ตัวกับ order ของร้าน Y ไม่ได้เลย (ownership check ผ่าน `stores.owner_id`) — ทดสอบ attack scenario ครบทุกตัว
- [ ] `seller_cancel_order` คืน stock กลับ `products.stock` ถูกต้อง (mirror `cancel_order` เดิม) — `seller_mark_refunded` ไม่คืน stock
- [ ] `seller_ship_order` บันทึก `shipping_provider`/`tracking_number` ถูกต้อง และบังคับกรอกทั้งสองช่องที่ชั้น UI ก่อนกดยืนยันจัดส่งได้
- [ ] Reviews (ZOKY-004): เขียน/แก้รีวิวยังทำงานถูกต้องเหมือนเดิมทุกประการ (gate บน `status = 'delivered'` ไม่เปลี่ยน) — regression test เดิมของ ZOKY-004 ผ่านครบไม่มีจุดใดพัง
- [ ] `ZokyOrderDetailScreen` (Customer): ปุ่มยกเลิกโผล่เฉพาะ `paid`, ปุ่มยืนยันรับโผล่เฉพาะ `shipped`, ไม่โผล่พร้อมกัน ไม่โผล่ผิดสถานะ, สถานะอื่นไม่มีปุ่มเลย
- [ ] `OrderStatusBadge` (Customer) แสดงครบทั้ง 8 สถานะถูกต้อง (สี+icon+ข้อความคู่กันเสมอ) รวมถึง `pending_payment`/`refunded` แม้จะไม่เกิดขึ้นจริงในรอบนี้ก็ต้องไม่ crash ถ้าเจอค่านี้
- [ ] `ZokyOrderListScreen`/`OrderSummaryCard` (Customer) ยังทำงานปกติกับสถานะใหม่ทั้ง 8 แบบ ไม่มี regression กับ Order เดิมที่เพิ่ง migrate
- [ ] Seller เห็น `SellerOrderListScreen` แทน placeholder เดิม, filter ตามสถานะทำงานถูกต้อง, เห็นเฉพาะ order ร้านตัวเอง (ทดสอบ cross-store ไม่เห็นของร้านอื่น)
- [ ] `SellerOrderDetailScreen` แสดงปุ่ม action ถูกต้องตามสถานะปัจจุบันเท่านั้น (ตามตารางข้อ 5) มี confirm dialog ก่อนยกเลิก/คืนเงินเสมอ
- [ ] SELLER-001 Dashboard's "New Orders" นับจาก `status = 'paid'` ถูกต้อง (ไม่ใช่ `pending` เดิมที่ไม่มีอยู่แล้ว) — "Sales/Revenue/Best Selling" ยัง filter `delivered` เหมือนเดิม ไม่มี regression
- [ ] WYN Social (`app/`'s non-ZOKY features), ZOKY-001/002 (Browse/Search), SELLER-002 (Product Management) เดิมทั้งหมดยังทำงานปกติ ไม่มี regression

Dependencies: SELLER-001 (Foundation — Approved, ต้องมี `seller_app/`/`SellerHomeShell`/RLS select policy ของ orders อยู่แล้ว), SELLER-002 (Product Management — Approved, `create_orders()` มีการแก้ล่าสุดจาก task นี้ที่ SELLER-003 ต้องต่อยอดอีกชั้น ไม่ใช่แก้ทับ), ZOKY-003 (Cart & Checkout & Order — Approved, เจ้าของ schema/RPC เดิมทั้งหมดที่ task นี้ขยาย), ZOKY-004 (Review — Approved, ต้องยืนยันไม่กระทบ)

Priority: P0 ของ Phase 4 — เป็น task ที่มีความเสี่ยงสูงสุดในสาย SELLER เพราะแก้โค้ด/DB ที่ผ่าน QA แล้วมากที่สุด (ZOKY-003's `orders` schema+3 RPC, SELLER-001's Dashboard query, ทางอ้อมต้องยืนยัน ZOKY-004's reviews ไม่กระทบ)

Risks:
- **แก้โค้ด/DB ที่ผ่าน QA แล้ว 4 จุดตรง ๆ**: (1) `orders.status` CHECK constraint + default value (ZOKY-003 schema) (2) `create_orders()` RPC (ZOKY-003, แก้ต่อจาก SELLER-002 อีกชั้น) (3) `cancel_order()`/`confirm_order_received()` RPC (ZOKY-003) (4) `fetchOrderCounts()` ใน SELLER-001's `SellerRepository` — ทุกจุดต้องรัน regression suite เดิมของ ZOKY-003/SELLER-001/SELLER-002 ครบทุกเคส ไม่ใช่แค่เคสใหม่ของ SELLER-003 เอง (มาตรฐานเดียวกับที่ SELLER-002 เคยทำสำเร็จกับ `create_orders()` มาแล้วครั้งหนึ่ง)
- **Migration SQL ต้องรันตามลำดับถูกต้องเป๊ะ**: ถ้าเปลี่ยน CHECK constraint ก่อน UPDATE remap ค่า `pending`→`paid` จะทำให้แถวเก่าที่ยังเป็น `pending` ละเมิด constraint ใหม่ทันที (schema.sql จะรันไม่ผ่านทั้งไฟล์) — เตือน Coding ให้เรียงลำดับ UPDATE ก่อน ALTER CONSTRAINT เสมอ
- **ห้ามเดาชื่อ CHECK constraint เดิม**: ต้อง verify ชื่อจริงจาก `information_schema`/`pg_constraint` ก่อน drop ไม่ hardcode assumption
- **`pending_payment`/`refunded` เป็นสถานะที่ RPC รอบนี้ไม่มีทาง trigger ได้จริง (`refunded` trigger ได้ผ่าน `seller_mark_refunded` แต่ `pending_payment` ไม่มีทาง trigger ได้เลยทั้งระบบ)** — เป็นข้อจำกัดที่ตั้งใจ (scaffold ไว้รอ payment gateway ในอนาคต) ไม่ใช่บั๊ก แต่ต้องบันทึกเป็น Known Issue ชัดเจนเหมือนที่ ZOKY-003 เคยบันทึกเรื่องสถานะย่อไว้
- **buyer ยกเลิกเองไม่ได้อีกต่อไปหลัง seller เริ่ม processing**: เป็นการเปลี่ยนพฤติกรรมจริงที่ผู้ใช้จะสัมผัสได้ (ต่างจาก ZOKY-003 เดิมที่ buyer ยกเลิกได้ตลอดจนกว่าจะ delivered/cancelled) — เป็นการตัดสินใจ UX ที่จำเป็นเพื่อให้ workflow ของ seller มีความหมาย ไม่ใช่ oversight แต่ควรแจ้ง Founder ทราบ (ระบุไว้ใน Recommendation ด้านล่างเป็นจุดที่เสนอให้ Founder รับทราบ ไม่ใช่ block งาน)
- **Seller ownership check ผิดจุดเดียวจะรั่วข้ามร้าน**: RPC ใหม่ 5 ตัวต้องตรวจ `exists (... stores.owner_id = auth.uid())` ให้ถูกต้องครบทุกตัว เหมือนบทเรียนซ้ำจาก ZOKY-004/SELLER-001/SELLER-002 — เตือน QA ตรวจ attack scenario ทุกตัวแยกกัน ไม่ตรวจรวมเป็นกลุ่มเดียว
- **ไม่มี live Supabase ให้ทดสอบ migration/RPC แบบ dynamic จริง**: เหมือนทุก task ก่อนหน้า ต้องตรวจด้วยการอ่าน SQL semantics — เพราะไม่มี order จริงในระบบ ความเสี่ยง data-loss ที่แท้จริงต่ำมาก แต่ความถูกต้องเชิงตรรกะของ migration SQL ยังต้องแม่นยำ 100% สำหรับตอน deploy จริงครั้งแรก

Recommendation:
1. เริ่ม Design ทันทีหลังจาก Product spec นี้ — จุดที่ต้องเน้นเป็นพิเศษคือ (a) migration SQL ต้องเรียงลำดับถูกต้อง (b) RPC ownership check ของ seller-side ทั้ง 5 ตัว (c) `ZokyOrderDetailScreen`'s action bar ต้องเปลี่ยนจาก all-or-nothing เป็น per-status logic
2. **แจ้ง Founder รับทราบ (ไม่ block งาน แค่แจ้งให้ทราบ)**: buyer จะยกเลิก order เองไม่ได้อีกต่อไปหลังจากร้านเริ่มเตรียมสินค้าแล้ว (เปลี่ยนจากเดิมที่ยกเลิกได้ตลอดจนกว่าจะ delivered/cancelled) — เป็นพฤติกรรมมาตรฐานของ marketplace ทั่วไป (Shopee/Lazada) แต่เป็นการเปลี่ยนแปลงที่ผู้ใช้จะสัมผัสได้จริง
3. Coding ต้อง sync branch ใหม่ก่อนแก้ `create_orders()`/`cancel_order()`/`confirm_order_received()` และรัน regression ของ ZOKY-003/ZOKY-004/SELLER-001/SELLER-002 อิสระให้ครบก่อนส่ง QA — เคสเดิมที่เคย pass ต้องยัง pass เป๊ะทุกเคส
4. เน้น QA ตรวจ 2 เรื่องเป็นพิเศษ: (a) migration SQL ที่ remap `pending`→`paid` ต้องรันสำเร็จโดยไม่ทำลาย Order เก่าที่ `delivered`/`cancelled` (b) reviews (ZOKY-004) ไม่ได้รับผลกระทบใด ๆ จากการเปลี่ยนสถานะรอบนี้ (verify `status = 'delivered'` reference ทุกจุดไม่เปลี่ยน)

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) Migration SQL script (ลำดับ UPDATE → verify constraint name → DROP → ADD CONSTRAINT → เปลี่ยน default → เพิ่มคอลัมน์ shipping) (2) RPC ใหม่ 5 ตัวฝั่ง seller + แก้ RPC เดิม 3 ตัว (3) `SellerOrderListScreen`/`SellerOrderDetailScreen` (filter chip, per-status action button, shipping info form) (4) `OrderStatusBadge`/`ZokyOrderDetailScreen` เวอร์ชันขยาย 8 สถานะฝั่ง Customer (5) status badge เวอร์ชัน duplicate ของ seller_app มิเรอร์หลักการเดิม — ใช้ Design system เดิมทั้งสองแอป (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass) reuse pattern จาก `SellerProductListScreen`/`ConfirmDeleteDialog`/`OrderStatusBadge` เดิมให้มากที่สุด — เมื่อ Design/Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น %

## Design Output

Status: **Design เสร็จแล้ว** — เขียนที่ `.wyn/docs/design/seller-003-order-management.md`

สรุปการตัดสินใจหลัก:
1. **`OrderStatusBadge` ขยายจาก 3→8 สถานะแบบขยาย map เดิม ไม่เขียนใหม่** (ทั้ง `app/` และ duplicate ใหม่ใน `seller_app/`) — 4 สถานะ "กำลังดำเนินการ" (`paid`/`seller_processing`/`ready_to_ship`/`shipped`) ใช้โทน Blue (`primaryContainer`/`onPrimaryContainer`, role มาตรฐานจาก seed เดิม ไม่ใช่สีใหม่) แยกกันด้วย icon+ข้อความเท่านั้นตาม Accessibility rule เดิม, `delivered`/`cancelled` คงสีเดิมเป๊ะ (เขียว/แดง), `refunded` ใช้โทนเทาเดียวกับ `pending_payment` (ไม่ใช้แดงซ้ำ `cancelled` เพื่อไม่ให้อ่านผิดว่าความหมายเดียวกัน) — default fallback ของค่าที่จับไม่ได้แม็พไปที่ `pendingPayment`
2. **ตัดสินใจไม่เพิ่ม Timeline/Stepper แสดงความคืบหน้า order รอบนี้** — ไม่มี AC ต้องการ, เป็น task เสี่ยงสูงสุดของ Phase 4 อยู่แล้ว (แก้ RPC/constraint ที่ผ่าน QA แล้ว 4 จุด) ไม่ควรเพิ่มพื้นผิว regression ที่ไม่จำเป็น — badge 8 สถานะ + การ์ดข้อมูลจัดส่งใหม่ให้ข้อมูลเพียงพอสำหรับ V1 แล้ว เสนอเป็น fast-follow แยกในอนาคตถ้า Founder ต้องการ
3. **`ZokyOrderDetailScreen` (Customer)**: action bar เปลี่ยนจาก all-or-nothing (`status == pending`) เป็น per-button visibility จริง — ปุ่มยกเลิกเฉพาะ `paid`, ปุ่มยืนยันรับเฉพาะ `shipped`, สถานะกลาง (`seller_processing`/`ready_to_ship`) และสถานะจบ (`delivered`/`cancelled`/`refunded`) ไม่มีปุ่มเลย — ข้อความ confirm dialog เดิมทั้งสองปุ่ม**ไม่ต้องแก้** (ยังถูกต้อง 100% กับพฤติกรรมใหม่) — เพิ่มการ์ด "ข้อมูลการจัดส่ง" (read-only) แสดงเมื่อร้านกรอก shipping provider/tracking แล้ว
4. **`ZokyOrderListScreen` (Customer) ไม่มีการเปลี่ยนแปลงโครงสร้างเลย** — ได้ประโยชน์จาก `OrderStatusBadge` ที่ขยายแล้วผ่าน `OrderSummaryCard` โดยอัตโนมัติ — ตัดสินใจไม่เพิ่ม filter chip ตามสถานะฝั่งนี้รอบนี้ (ไม่ใช่ AC ที่ขอ, ลด regression surface บนหน้าจอที่ผ่าน QA แล้ว)
5. **`SellerOrderListScreen`/`SellerOrderListTile` ใหม่**: มิเรอร์ `SellerProductListScreen`'s filter chip row (8 chip ตาม label เดียวกับ badge, ไม่มี `pending_payment` เพราะ trigger ไม่ได้จริง) + error/empty state pattern, `SellerOrderListTile` มิเรอร์ `OrderSummaryCard` สลับ "ชื่อร้าน" เป็น "ผู้ซื้อ: {recipientName}" (seller รู้ร้านตัวเองอยู่แล้ว)
6. **`SellerOrderDetailScreen` ใหม่**: มิเรอร์การ์ดที่อยู่/รายการสินค้า/สรุปยอดของ `ZokyOrderDetailScreen` เป๊ะ (ตัดแถวรีวิวออก เพราะ buyer-only) — ปุ่ม action ตาม transition ที่อนุญาตต่อสถานะเท่านั้น (`paid`→เริ่มเตรียม+ยกเลิก, `seller_processing`→พร้อมจัดส่ง+ยกเลิก, `ready_to_ship`→ฟอร์ม tracking+ยืนยันจัดส่ง+ยกเลิก, `shipped`/`delivered`→ทำเครื่องหมายคืนเงินแล้วเดี่ยว ๆ, `cancelled`/`refunded`/`pending_payment`→ไม่มีปุ่มเลย) — "เริ่มเตรียมสินค้า"/"พร้อมจัดส่ง" ไม่มี confirm dialog (ไม่ทำลาย), "ยกเลิก"/"คืนเงิน" มี confirm dialog เสมอ (ปุ่มคืนเงินใช้ `OutlinedButton` โทนกลางไม่ใช่แดง เพราะไม่ใช่ error เป็นบันทึกบัญชีปกติ) — สำเร็จแล้ว reload หน้าเดิมไม่ pop มิเรอร์ `ZokyOrderDetailScreen`
7. Data model ใหม่ใน `seller_app/`: duplicate `Order`(+`shippingProvider`/`trackingNumber`)/`OrderStatus`(8 ค่า)/`OrderItem` ตาม pattern duplicate เดิมจาก SELLER-001/002

Handoff: ส่งต่อ AI Coding (`/code`) — รายละเอียดครบทุก Screen/Widget/Data Model/Repository method/Migration sequencing ที่ต้อง implement อยู่ใน `.wyn/docs/design/seller-003-order-management.md` ทั้งหมด (รวม "เตือน Coding" 6 ข้อท้ายเอกสารที่ย้ำจุดเสี่ยงจาก Product spec's Risks — โดยเฉพาะ per-status action bar test coverage, ห้ามแตะ locking ของ `create_orders()`, ownership check ของ RPC ใหม่ 5 ตัว, และลำดับ migration SQL)
