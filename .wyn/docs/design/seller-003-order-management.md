# Design Spec — SELLER-003: Order Management (ขยายสถานะ 3→8 + Seller Order List/Detail)

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout Shopee/Lazada/TikTok Shop โดยตรง, Touch target ≥44px, ห้ามสื่อสารสถานะด้วยสีอย่างเดียว)
อ้างอิง Product Spec: `.wyn/tasks/backlog/SELLER-003-order-management.md`
อ้างอิง Design เดิมที่แก้ต่อ: `.wyn/docs/design/zoky-003-cart-checkout-order.md` (เจ้าของ `OrderStatusBadge`/`ZokyOrderListScreen`/`ZokyOrderDetailScreen` เดิม — งานนี้ขยาย ไม่เขียนใหม่), `.wyn/docs/design/seller-001-foundation.md` (`SellerHomeShell` tab เดิม), `.wyn/docs/design/seller-002-product-management.md` (filter chip / list tile / repository pattern ที่ reuse)

## ทิศทางภาพรวม

งานนี้**ไม่มีทิศทาง visual ใหม่เลย** — เป็นการขยาย component ที่มีอยู่แล้ว (`OrderStatusBadge` 3→8 สถานะ) และประกอบหน้าจอ seller ใหม่จาก pattern ที่พิสูจน์แล้วครบทุกชิ้นจาก ZOKY-003/SELLER-002 (filter chip, list tile ทรง thumbnail+column+trailing, confirm dialog, bottom-anchored action bar) หลักการออกแบบคือ **เปลี่ยน/เพิ่มให้น้อยที่สุดเท่าที่ยังครบตาม Requirements** เพราะเป็น task ที่แก้โค้ด Customer-facing ที่ผ่าน QA แล้วมากที่สุดในโปรเจกต์

**การตัดสินใจสำคัญที่ Product spec ทิ้งไว้ให้ Design ตัดสินใจ:**

1. **สีของ 4 สถานะ "กำลังดำเนินการ" ใหม่ (`paid`/`seller_processing`/`ready_to_ship`/`shipped`)**: ใช้ `colorScheme.primaryContainer`/`onPrimaryContainer` (โทน Blue ที่เป็น seed color ของทั้งระบบอยู่แล้ว ไม่ใช่สีใหม่ — เป็น role มาตรฐานที่ Material 3 derive จาก seed `0xFF2D6CDF` เดิม) ทั้ง 4 สถานะใช้สีเดียวกันเพราะทั้งหมดอยู่ในกลุ่มความหมายเดียวกัน ("มีคนต้องดำเนินการต่อ ไม่ใช่จุดจบ") แยกความแตกต่างกันด้วย **icon+ข้อความ** เท่านั้น (ตรงตาม Accessibility rule เดิมที่บังคับอยู่แล้วว่าห้ามสื่อสารด้วยสีอย่างเดียว — ดังนั้นสีซ้ำกัน 4 สถานะไม่ใช่ปัญหา) เทียบเท่าแนวทาง progress-chip ของ mobile commerce ทั่วไปที่ badge "กำลังดำเนินการ" มักโทนเดียวกันตลอด timeline ต่างกันที่ label/icon — ไม่ใช่การลอก Shopee/Lazada เพราะไม่ได้ยืมโครง/เลย์เอาต์ใด ๆ มา แค่ยึดหลักสีความหมายสากล
2. **`refunded` ใช้โทนเทาเดียวกับ `pending_payment`** (ไม่ใช้แดงซ้ำกับ `cancelled`) — เหตุผล: `cancelled` (แดง/error) สื่อว่า "คำสั่งซื้อไม่สำเร็จตั้งแต่ต้น" ส่วน `refunded` เกิดขึ้นได้แม้ order เคยไปถึง `shipped`/`delivered` แล้ว (ขายสำเร็จแต่ภายหลังต้องคืนเงิน) ความหมายต่างกันจริง ใช้สีเทากลาง (final แต่ไม่ใช่ error โดยตรง) ตรงตามที่ Founder task ระบุแนวทาง "Cancelled/Refunded ควรใช้โทน gray/red-muted" — เลือกฝั่ง gray สำหรับ `refunded` เพื่อไม่ให้ 2 badge สีแดงถูกอ่านว่าเป็นความหมายเดียวกันโดยไม่ตั้งใจ แยกจาก `pending_payment` ด้วย icon/ข้อความคนละชุดเสมอ (badge ทั้งคู่ไม่มีทางแสดงติดกันในหน้าจอเดียวจริง — `pending_payment` ไม่เคยเกิดขึ้นจริงตาม Product spec)
3. **ไม่เพิ่ม Timeline/Stepper แสดงความคืบหน้า order รอบนี้** (Founder เปิดให้ Design ตัดสินใจ) — เหตุผล: (ก) ไม่มี Acceptance Criteria ข้อไหนต้องการ ถือเป็น scope เพิ่มที่ Product ไม่ได้ขอ (ข) นี่คือ task ที่มีความเสี่ยงสูงสุดใน Phase 4 อยู่แล้ว (แก้ RPC/constraint ที่ผ่าน QA แล้ว 4 จุด) เพิ่ม component ใหม่ที่ไม่จำเป็นจะเพิ่มพื้นผิวเสี่ยง regression โดยไม่มีประโยชน์ที่วัดได้ตอนนี้ (ค) badge 8 สถานะ + การ์ดข้อมูลจัดส่ง (ใหม่ในงานนี้) ให้ข้อมูลความคืบหน้าเพียงพอสำหรับ V1 อยู่แล้ว — **เสนอเป็น fast-follow task แยกในอนาคตถ้า Founder ต้องการ** ไม่ใช่การตัดทิ้งถาวร
4. **ปุ่ม "ทำเครื่องหมายคืนเงินแล้ว" ใช้ `OutlinedButton` โทนกลาง (ไม่ใช่สีแดง/error)** ต่างจากปุ่ม "ยกเลิกคำสั่งซื้อ" ที่เป็น error สีแดงเสมอ — เหตุผล: cancel เป็น action ทำลาย/ปิดถาวรที่ไม่ควรเกิดขึ้นบ่อย ส่วน refund แม้ก็เป็น final action เช่นกัน แต่ไม่ใช่ "ความผิดพลาด" (เป็น bookkeeping ปกติของธุรกิจ) การใช้สีแดงกับทุก action ที่กด "แค่ครั้งเดียวไม่ย้อนกลับ" จะทำให้ผู้ใช้ตื่นตระหนกเกินจำเป็นกับ action ที่เป็นเรื่องปกติทางบัญชี

---

## ภาพรวม: reuse pattern อะไรจากที่ไหน

| Component ใหม่/แก้ไข | มิเรอร์จาก |
|---|---|
| `OrderStatusBadge` 8 สถานะ (ทั้ง `app/` และ duplicate ใหม่ใน `seller_app/`) | `OrderStatusBadge` เดิม (ZOKY-003) — ขยาย map ไม่เขียนใหม่ |
| `SellerOrderListScreen`'s filter chip row (8 ตัว) | `SellerProductListScreen._buildFilterChips()` (SELLER-002) |
| `SellerOrderListTile` | `OrderSummaryCard` (ZOKY-003) — สลับ "ชื่อร้าน" เป็น "ชื่อผู้ซื้อ" เพราะ seller รู้อยู่แล้วว่าเป็นร้านตัวเอง |
| `SellerOrderListScreen`'s empty/error/pagination state | `SellerProductListScreen`'s error-state pattern (มี try/catch + `_error`, robust กว่า `ZokyOrderListScreen` เดิมที่ไม่มี error handling) |
| `SellerOrderDetailScreen`'s ข้อมูลผู้รับ/รายการสินค้า/สรุปยอด | `ZokyOrderDetailScreen._buildContent()` (ZOKY-003) เป๊ะ ตัดส่วนรีวิวออก (buyer-only) |
| `SellerOrderDetailScreen`'s confirm dialog (ยกเลิก/คืนเงิน) | `ZokyOrderDetailScreen._confirmDialog()` โครงเดียวกัน |
| การ์ดข้อมูลจัดส่ง (Shipping Provider/Tracking) — ทั้งฝั่งลูกค้าและร้านค้า | โครงการ์ดที่อยู่จัดส่งเดิม (`_buildContent`'s "ที่อยู่จัดส่ง" Card) |
| ฟอร์มกรอก Shipping Provider/Tracking (โหมด `ready_to_ship`) | `ZokyCheckoutAddressScreen`'s required `TextField` + validate-on-submit pattern (ZOKY-003) |

---

## Widget: `OrderStatusBadge` (ขยายจาก 3→8 สถานะ)

Purpose: Shared status pill ที่ใช้ร่วมกันทุกจุดที่แสดงสถานะ Order — ต้องรองรับครบ 8 ค่าโดยไม่ crash แม้บางค่า (`pending_payment`) จะไม่เกิดขึ้นจริงในรอบนี้

User Flow: N/A (presentational widget ไม่มี interaction)

Components: refactor `_labels`/`_icons`/สี switch เดิม (map-based อยู่แล้ว) ให้ครบ 8 entry แทนที่จะเขียนใหม่ทั้งไฟล์ — ตารางสี/icon/label ที่ต้องใช้:

| `OrderStatus` (Dart enum) | ค่าใน DB | Label | Icon | Background | Foreground |
|---|---|---|---|---|---|
| `pendingPayment` | `pending_payment` | "รอชำระเงิน" | `Icons.hourglass_empty` | `colorScheme.surfaceContainerHighest` | `colorScheme.onSurfaceVariant` |
| `paid` | `paid` | "ชำระเงินแล้ว" | `Icons.payments` | `colorScheme.primaryContainer` | `colorScheme.onPrimaryContainer` |
| `sellerProcessing` | `seller_processing` | "ร้านค้ากำลังเตรียมสินค้า" | `Icons.inventory_2` | `colorScheme.primaryContainer` | `colorScheme.onPrimaryContainer` |
| `readyToShip` | `ready_to_ship` | "พร้อมจัดส่ง" | `Icons.outbox` | `colorScheme.primaryContainer` | `colorScheme.onPrimaryContainer` |
| `shipped` | `shipped` | "จัดส่งแล้ว" | `Icons.local_shipping` | `colorScheme.primaryContainer` | `colorScheme.onPrimaryContainer` |
| `delivered` | `delivered` | "ได้รับสินค้าแล้ว" (ไม่เปลี่ยน) | `Icons.check_circle` (ไม่เปลี่ยน) | `Colors.green.shade100` (ไม่เปลี่ยน) | `Colors.green.shade800` (ไม่เปลี่ยน) |
| `cancelled` | `cancelled` | "ยกเลิกแล้ว" (ไม่เปลี่ยน) | `Icons.cancel` (ไม่เปลี่ยน) | `colorScheme.errorContainer` (ไม่เปลี่ยน) | `colorScheme.onErrorContainer` (ไม่เปลี่ยน) |
| `refunded` | `refunded` | "คืนเงินแล้ว" | `Icons.currency_exchange` | `colorScheme.surfaceContainerHighest` | `colorScheme.onSurfaceVariant` |

`Semantics` label คงรูปแบบเดิมเป๊ะ: `'สถานะคำสั่งซื้อ: $label'` (excludeSemantics: true) — ไม่ต้องแก้โครง `Container`/`Row`/padding/borderRadius ใด ๆ นอกจากขยาย map

Interactions: ไม่มี (stateless)

States: `orderStatusFromString()` ต้องขยาย switch ครบ 8 ค่า — **default fallback (ค่าที่จับไม่ได้) ให้แม็พไปที่ `OrderStatus.pendingPayment`** (เดิม fallback ไปที่ `pending` ซึ่งไม่มีอยู่แล้ว) เพราะเป็นสถานะเดียวที่สื่อความหมาย "ไม่รู้ว่าอยู่ขั้นตอนไหน" ตรงที่สุด และ DB constraint บังคับอยู่แล้วว่าค่านี้จะไม่เกิดขึ้นจริงในทางปฏิบัติ — fallback นี้เป็นแค่ defense-in-depth ไม่ควรถูกเรียกใช้จริง

Responsive Behavior: ไม่เปลี่ยน (pill ขนาดเดิม พอดีกับทุกจุดที่ใช้อยู่แล้ว — มุมขวาบนของการ์ด, ใต้ AppBar)

Accessibility: icon+ข้อความคู่กันครบทั้ง 8 สถานะ (ไม่มีสถานะไหนสื่อสารด้วยสีอย่างเดียว) — contrast ผ่าน AA อยู่แล้วเพราะ `primaryContainer`/`onPrimaryContainer` เป็น role คู่ที่ Material 3 ออกแบบมาให้ผ่านมาตรฐานนี้เสมอ (เหมือน `errorContainer`/`onErrorContainer` ที่ใช้อยู่แล้ว)

Design Rules: ไม่มีสีใหม่นอกระบบ (ทุกสีเป็น role ที่มีอยู่แล้วใน `ColorScheme` ที่ derive จาก seed `0xFF2D6CDF` เดิม หรือสี success/error ที่เคยผ่าน QA แล้ว) — โครงสร้าง map เดิม (`_labels`/`_icons` + switch สี) ยังคงรูปแบบเดิม แค่ขยายรายการ ไม่ refactor เป็นสถาปัตยกรรมใหม่ (ลดความเสี่ยง regression)

Handoff:
- `app/lib/features/zoky/presentation/widgets/order_status_badge.dart`: ขยาย `_labels`/`_icons`/สี switch ตามตารางข้างต้นครบ 8 เคส
- `app/lib/features/zoky/data/order.dart`: `enum OrderStatus` ขยาย 8 ค่า, `orderStatusFromString()` ขยาย switch ครบ 8 เคส + fallback → `pendingPayment`
- **duplicate ใหม่**: `seller_app/lib/features/order/presentation/widgets/order_status_badge.dart` — โค้ด/ตาราง/ข้อความเดียวกันทุกประการ (ตาม pattern duplicate ที่ SELLER-001/002 ทำมาตลอดเพราะคนละ Flutter binary)

---

## Screen: `ZokyOrderDetailScreen` (Customer — แก้ไขจาก ZOKY-003)

Purpose: ดูรายละเอียด Order เดียว + จัดการสถานะ (ยกเลิก/ยืนยันรับสินค้า) — เปลี่ยนจาก action bar แบบ all-or-nothing (แสดงเมื่อ `status == pending` เท่านั้น) เป็น per-button visibility ตามสถานะจริง

User Flow:
1. `status == paid`: เห็นเฉพาะปุ่ม "ยกเลิกคำสั่งซื้อ" (ไม่มีปุ่มยืนยันรับสินค้า)
2. `status == shipped`: เห็นเฉพาะปุ่ม "ยืนยันได้รับสินค้าแล้ว" (ไม่มีปุ่มยกเลิก)
3. สถานะอื่นทั้งหมด (`pending_payment`/`seller_processing`/`ready_to_ship`/`delivered`/`cancelled`/`refunded`): **ไม่มี action bar เลย** (`bottomNavigationBar` เป็น `null` เหมือนเดิมตอน delivered/cancelled) — สถานะกลาง (`seller_processing`/`ready_to_ship`) ไม่มีอะไรให้ buyer ทำได้แล้ว เพราะร้านเริ่มเตรียมสินค้าไปแล้วจริง (ตามเหตุผลที่ Product spec ระบุไว้ใน Requirements ข้อ 4)

Components:
- โครงเดิมทั้งหมดคงอยู่ (status badge บนสุด, การ์ดที่อยู่จัดส่ง, การ์ดรายการสินค้า, สรุปยอด) — **ไม่แก้ layout ที่มีอยู่แล้วนอกจากจุดที่ระบุ**
- **เพิ่มใหม่**: การ์ด "ข้อมูลการจัดส่ง" (แสดงเฉพาะเมื่อ `order.shippingProvider != null` — เช่นเดียวกับตอน `shipped`/`delivered`/`refunded`) วางถัดจากการ์ดที่อยู่จัดส่ง โครงเดียวกับการ์ดที่อยู่ (header `labelLarge` + 2 บรรทัด): "ขนส่งโดย: {shippingProvider}" / "เลขพัสดุ: {trackingNumber}" — read-only เสมอ (buyer แก้ไม่ได้)
- `_buildActionBar` เปลี่ยนจาก Row คงที่ 2 ปุ่มเสมอ เป็น Row ที่ประกอบปุ่มตามเงื่อนไข: ปุ่มยกเลิกใส่เมื่อ `status == OrderStatus.paid`, ปุ่มยืนยันรับใส่เมื่อ `status == OrderStatus.shipped` — ถ้าไม่มีปุ่มใดเข้าเงื่อนไขเลย method นี้คืนค่า (หรือ caller ไม่เรียก) แล้ว `build()`'s `bottomNavigationBar` เป็น `null`

Interactions:
- ปุ่ม "ยกเลิกคำสั่งซื้อ": เงื่อนไขแสดงเปลี่ยนจาก `pending`→`paid` เท่านั้น — **ข้อความ confirm dialog เดิมไม่ต้องแก้** ("ยกเลิกแล้วไม่สามารถกู้คืนได้ ระบบจะคืนสินค้ากลับเข้าสต็อก" — ยังถูกต้อง 100% เพราะ `cancel_order()` ที่แก้ยังคืน stock เหมือนเดิม)
- ปุ่ม "ยืนยันได้รับสินค้าแล้ว": เงื่อนไขแสดงเปลี่ยนจาก `pending`→`shipped` — **ข้อความ confirm dialog เดิมไม่ต้องแก้** ("เมื่อยืนยันแล้วจะไม่สามารถยกเลิกคำสั่งซื้อนี้ได้อีก" — ยังเป็นจริงอยู่ เพราะ `cancel_order()` ต้องการ `status == paid` อยู่ดี ไม่ว่าจะยืนยันรับหรือไม่ก็ยกเลิกไม่ได้แล้วตั้งแต่ `shipped`)
- เงื่อนไข gate การรีวิว (`order.status == OrderStatus.delivered`) **ไม่แก้** — ยังถูกต้องเหมือนเดิม

States: การ์ดข้อมูลจัดส่งซ่อนสนิทเมื่อไม่มีค่า (ไม่แสดงการ์ดเปล่า) — ทุก state (loading/not-found) เดิมไม่เปลี่ยน

Responsive Behavior: ไม่เปลี่ยน (`ListView` + `SafeArea` bottom-anchored action bar เดิม)

Accessibility: ไม่เปลี่ยน (ปุ่มยังผ่าน Material default accessible label, การ์ดใหม่ใช้ `Text` ธรรมดาเหมือนการ์ดที่อยู่เดิมที่ไม่มี `Semantics` พิเศษ — สอดคล้อง pattern เดิมของการ์ดข้อมูล/สรุปในหน้านี้)

Design Rules: การเปลี่ยนพฤติกรรมนี้ (buyer ยกเลิกเองไม่ได้แล้วหลังร้านเริ่มเตรียมสินค้า) เป็นการเปลี่ยนแปลงที่ผู้ใช้จะสัมผัสได้จริงตามที่ Product spec ระบุไว้ใน Risks — Design ไม่เพิ่มคำอธิบาย/tooltip ใหม่อธิบายเหตุผลนี้ใน UI รอบนี้ (ไม่ใช่ AC ที่ต้องมี ป้องกัน scope เพิ่มที่ไม่จำเป็น) เพราะสถานะที่ปุ่มหายไปมี badge สถานะกำกับชัดเจนอยู่แล้วว่าร้านเริ่มดำเนินการแล้ว

Handoff:
- `app/lib/features/zoky/presentation/zoky_order_detail_screen.dart`: แก้ `bottomNavigationBar` ternary + `_buildActionBar` ตามที่ระบุ, เพิ่มการ์ดข้อมูลจัดส่งแบบมีเงื่อนไข
- `app/lib/features/zoky/data/order.dart`: เพิ่ม field `shippingProvider`/`trackingNumber` (`String?`) + `Order.fromMap` อ่านจากคอลัมน์ใหม่ (query เดิม `select('*, store:stores(name))` ได้คอลัมน์ใหม่มาอัตโนมัติ ไม่ต้องแก้ query)
- Test เดิม (`app/test/zoky_order_detail_screen_test.dart`): อัปเดตตามที่ Product spec ระบุ (เปลี่ยน `OrderStatus.pending`→`OrderStatus.paid` ในเคส "ยกเลิกได้", เพิ่มเคส `shipped` สำหรับ "ยืนยันรับได้", **เพิ่มเคสใหม่ที่ Product spec ไม่ได้เอ่ยชัดแต่จำเป็นต่อ AC**: เคส `seller_processing`/`ready_to_ship` ต้องยืนยันว่า **ไม่มีปุ่มไหนแสดงเลยทั้งคู่** — เพราะเป็นจุดตัดสินใจ Design ใหม่ที่ Product spec's AC พูดถึงแค่ "ปุ่มยกเลิกโผล่เฉพาะ paid, ปุ่มยืนยันโผล่เฉพาะ shipped" แต่ไม่ได้ย้ำ 2 สถานะกลางตรง ๆ)

---

## Screen: `ZokyOrderListScreen` (Customer — ไม่มีการเปลี่ยน layout)

Purpose: ยืนยันว่าหน้าจอนี้ไม่ต้องแก้โครงสร้างใด ๆ — ได้ประโยชน์จาก `OrderStatusBadge`/`OrderSummaryCard` ที่ขยายแล้วโดยอัตโนมัติผ่าน `OrderSummaryCard`'s ที่ import widget เดิม

User Flow: เหมือนเดิมทุกประการ (infinite-scroll, เรียงใหม่สุดก่อน, แตะการ์ดเปิด detail)

Components/Interactions/States/Responsive/Accessibility: **ไม่มีการเปลี่ยนแปลง** — `OrderSummaryCard` เรียก `OrderStatusBadge(status: order.status)` อยู่แล้ว รับสถานะใหม่ทั้ง 8 แบบได้ทันทีโดยไม่ต้องแก้โค้ดจุดนี้เลย

Design Rules: **ตัดสินใจไม่เพิ่ม filter chip ตามสถานะในหน้านี้รอบนี้** (แม้ `SellerOrderListScreen` ฝั่งใหม่จะมี) — เหตุผล: Product spec's AC ของฝั่ง Customer ระบุแค่ "ยังทำงานปกติกับสถานะใหม่ทั้ง 8 แบบ ไม่มี regression" ไม่ได้ขอ filter ใหม่ ผู้ซื้อทั่วไปมักมีจำนวน order น้อยกว่าที่ seller ต้องจัดการมาก การเพิ่ม filter UI ที่ไม่ถูกขอจะเป็นการเพิ่มพื้นผิว regression บนหน้าจอที่ผ่าน QA แล้วโดยไม่จำเป็น — เสนอเป็นงานแยกในอนาคตถ้า Founder ต้องการ

Handoff: ยืนยันไม่มีไฟล์ให้ Coding แก้ในสกรีนนี้ (ตรวจสอบด้วย regression test เดิมเท่านั้น)

---

## Screen: `SellerOrderListScreen` (ใหม่ — แทนที่ tab "คำสั่งซื้อ" index 2 ของ `SellerHomeShell`)

Purpose: ให้ seller เห็น/กรอง order ของร้านตัวเองเท่านั้น เป็นทางเข้าไปจัดการสถานะแต่ละใบ

User Flow:
1. เปิด tab "คำสั่งซื้อ" (ครั้งแรกหรือสลับกลับมา) → โหลด order ของร้านตัวเอง filter "ทั้งหมด" เรียง `created_at` ใหม่→เก่า
2. แตะ filter chip → รีเซ็ต pagination แล้วโหลดใหม่ตามสถานะที่เลือก
3. Scroll ใกล้ท้ายลิสต์ → โหลดหน้าถัดไป (infinite scroll)
4. แตะแถว order → เปิด `SellerOrderDetailScreen(orderId: order.id)` → กลับมาแล้ว **reload เสมอ** (มิเรอร์ `SellerProductListScreen._openForm`'s pattern ที่ reload โดยไม่เช็ค return value เพราะ order อาจถูกเปลี่ยนสถานะไปแล้วระหว่างอยู่ในหน้า detail)
5. Pull-to-refresh → รีเซ็ตกลับหน้าแรกของ filter ปัจจุบัน

Components (บนลงล่าง):
- `AppBar(title: Text('คำสั่งซื้อ'))` — ไม่มีปุ่มย้อนกลับ (tab ไม่ใช่ pushed route)
- Filter chip row: `ChoiceChip` **8 ตัว** แนวนอน scroll ได้ มิเรอร์ `SellerProductListScreen._buildFilterChips()` เป๊ะ (`SizedBox(height: 48)` + `ListView` horizontal + padding เดียวกัน) — label ใช้ข้อความเดียวกับ `OrderStatusBadge`'s label เป๊ะเพื่อความสอดคล้อง (ผู้ใช้เห็น badge คำว่าอะไรก็หา filter คำเดียวกันเจอ):
  1. "ทั้งหมด" (ไม่ filter)
  2. "ชำระเงินแล้ว" (`paid`)
  3. "ร้านค้ากำลังเตรียมสินค้า" (`seller_processing`)
  4. "พร้อมจัดส่ง" (`ready_to_ship`)
  5. "จัดส่งแล้ว" (`shipped`)
  6. "ได้รับสินค้าแล้ว" (`delivered`)
  7. "ยกเลิกแล้ว" (`cancelled`)
  8. "คืนเงินแล้ว" (`refunded`)

  **ไม่มีตัวเลือก `pending_payment`** ในรายการ filter (สถานะนี้ไม่มีทาง trigger ได้จริงตาม Product spec — filter ที่กรองแล้วไม่มีทางเจอผลลัพธ์เป็นแค่ noise ในรายการ ไม่ใช่ helpful filter) — ถ้าอนาคตมี payment gateway จริงแล้วสถานะนี้เกิดขึ้นได้ ค่อยเพิ่ม chip กลับมา
- เนื้อหาหลัก: `RefreshIndicator` ครอบ `ListView.separated` ของ `SellerOrderListTile` (`Divider(height: 1)` คั่น)

Interactions: ทุกจุดเปลี่ยน filter ต้อง reset `_page`/`_hasMore` เหมือน `SellerProductListScreen`/`ZokyOrderListScreen` เดิม

States:
- Loading ครั้งแรก: `CircularProgressIndicator` กึ่งกลาง
- Loading เพิ่ม (pagination): spinner แถวท้ายลิสต์
- Empty แบบสัมบูรณ์ (filter="ทั้งหมด" + ร้านไม่มี order เลย): ไอคอน `Icons.receipt_long_outlined` (มิเรอร์ `ZokyOrderListScreen`'s empty icon) + ข้อความ **"ยังไม่มีคำสั่งซื้อเข้ามา"** (ข้อความใหม่ บริบท seller ต่างจาก buyer's "ยังไม่มีคำสั่งซื้อ") — **ไม่มีปุ่ม CTA** (ต่างจาก `SellerProductListScreen`'s empty state ที่มีปุ่ม "+ เพิ่มสินค้า" เพราะ order ไม่ใช่สิ่งที่ seller "สร้างเอง" ได้ ไม่มี action ให้ทำต่อจากหน้านี้)
- Empty แบบ filter แล้วไม่พบ: `SearchStateMessage` ข้อความ "ไม่พบคำสั่งซื้อในสถานะนี้" ไม่มีปุ่ม CTA (มิเรอร์ `SellerProductListScreen`'s filtered-empty convention)
- Error (โหลดครั้งแรกล้มเหลว): ข้อความ error + `TextButton` "ลองใหม่" กึ่งกลาง (มิเรอร์ `SellerProductListScreen`'s error state — เลือก pattern นี้แทน `ZokyOrderListScreen` เดิมที่ไม่มี error handling explicit เพราะเป็น convention ที่ใหม่กว่า/robust กว่าใน `seller_app/` เอง)

Responsive Behavior: มือถือ portrait คอลัมน์เดียวเต็มความกว้างจอ (ตาม convention เดิมทั้งโปรเจกต์)

Accessibility: filter chip มี label จาก `ChoiceChip` อัตโนมัติ, `SellerOrderListTile` มี `Semantics` label รวม (ดูด้านล่าง)

Design Rules: ไม่มี Bottom Nav ใหม่ ไม่มี AppBar action เพิ่มเติม — ไม่แตะ tab "ร้านค้า"/"การเงิน" (ยังเป็น `SellerComingSoonScreen` เหมือนเดิม)

Handoff: `SellerRepository` เมธอดใหม่ `fetchStoreOrders({required String storeId, OrderStatus? filter, required int page})` คืน `List<Order>` (select ผ่าน RLS select policy ที่ SELLER-001 เพิ่มไว้แล้ว ไม่มี write policy ใหม่ให้ query นี้) — เรียง `created_at desc`, page size คงที่มิเรอร์ `SellerRepository.productsPageSize`/`ZokyRepository.ordersPageSize` (เสนอ `SellerRepository.ordersPageSize = 20`)

---

## Widget: `SellerOrderListTile` (ใหม่)

Purpose: หนึ่งแถวในลิสต์ order ของ `SellerOrderListScreen`

Components: มิเรอร์โครง `OrderSummaryCard` (ZOKY-003) เป๊ะ (leading thumbnail 64×64 + text column ขยาย + trailing marker) — **ความต่างจุดเดียวที่ตั้งใจ**: แถวบนแสดง **"ผู้ซื้อ: {recipientName}"** แทน "ชื่อร้าน" (seller รู้อยู่แล้วว่าเป็นร้านตัวเอง ชื่อร้านซ้ำซ้อนไม่มีประโยชน์ ส่วนชื่อผู้ซื้อคือข้อมูลที่ discriminate แต่ละแถวได้จริง) —
- Thumbnail: สินค้าชิ้นแรกของ order (64×64 `ClipRRect`+`Image.network`, เหมือน `OrderSummaryCard`)
- แถวบน: "ผู้ซื้อ: {order.recipientName}" (`titleSmall`, ellipsis) ชิดซ้าย + `OrderStatusBadge` (seller_app duplicate) ชิดขวา
- แถวกลาง: "{ชื่อสินค้าชิ้นแรก} และอีก N ชิ้น" ถ้ามีมากกว่า 1 รายการ (เหมือน `OrderSummaryCard` เป๊ะ)
- แถวล่าง: วันที่สั่งซื้อ (`relativeTimeLabel`) + ยอดรวม (`thaiBahtLabel`, สี Primary ตัวหนา — เหมือน `OrderSummaryCard`)

Interactions: ทั้งแถวเป็น tap target เดียว (`InkWell`) เปิด `SellerOrderDetailScreen`

Accessibility: `Semantics` label รวม "ผู้ซื้อ {recipientName}, สถานะ {statusLabel}, ยอดรวม {total} บาท" (มิเรอร์ `OrderSummaryCard`/`SellerProductListTile`'s รูปแบบ label รวม)

Handoff: `seller_app/lib/features/order/presentation/widgets/seller_order_list_tile.dart` — ใช้ `Order`/`OrderItem` model (seller_app duplicate, ดู Data Model ท้ายเอกสาร)

---

## Screen: `SellerOrderDetailScreen` (ใหม่)

Purpose: ดูรายละเอียด order 1 ใบ + เปลี่ยนสถานะผ่านปุ่ม action ที่ตรงกับ transition ที่อนุญาตจากสถานะปัจจุบันเท่านั้น

User Flow: เปิดจาก `SellerOrderListTile` → โหลด order+items → เห็นรายละเอียด+ปุ่ม action ตามสถานะปัจจุบัน → กดปุ่ม action → (มีฟอร์ม/confirm dialog ตามชนิด action) → สำเร็จ → **`_load()` ใหม่ในหน้าเดิม ไม่ pop กลับ** (มิเรอร์ `ZokyOrderDetailScreen`'s pattern ที่เรียก `_load()` หลัง cancel/confirm สำเร็จแทนการ pop — ให้ seller เห็นสถานะ/ปุ่มใหม่ทันทีในหน้าเดียวกัน)

Components:
- `AppBar(title: Text('รายละเอียดคำสั่งซื้อ'))`
- Status badge (seller_app `OrderStatusBadge` duplicate) ใต้ AppBar — มิเรอร์ตำแหน่ง/สไตล์ `ZokyOrderDetailScreen` เป๊ะ
- การ์ด "ข้อมูลผู้รับ" — **มิเรอร์การ์ด "ที่อยู่จัดส่ง" ของ `ZokyOrderDetailScreen` เป๊ะทุกประการ** (ข้อมูลชุดเดียวกัน: `recipientName`/`recipientPhone`/`shippingAddress` snapshot เดิม — seller ต้องเห็นข้อมูลเดียวกับที่ buyer กรอกไว้ตอน checkout)
- การ์ด "รายการสินค้า" — มิเรอร์ `ZokyOrderDetailScreen._buildContent()`'s items list เป๊ะ (thumbnail+ชื่อ+variant+ราคา×จำนวน+lineTotal) **ตัดส่วนแถวรีวิว (`_buildReviewRow`) ออกทั้งหมด** (รีวิวเป็นฟีเจอร์ buyer-only ตาม ZOKY-004 ไม่เกี่ยวกับ seller)
- การ์ดสรุปยอด — มิเรอร์ `_summaryRow` เป๊ะ (ค่าสินค้า/ค่าธรรมเนียม/ยอดรวม)
- **การ์ด "ข้อมูลการจัดส่ง" (read-only)**: แสดงเมื่อ `order.shippingProvider != null` (สถานะ `shipped`/`delivered`/`refunded`) — โครง/ข้อความเดียวกับการ์ดฝั่ง Customer ที่เพิ่มใหม่ข้างต้นเป๊ะ ("ขนส่งโดย: X" / "เลขพัสดุ: Y")
- **การ์ด "กรอกข้อมูลการจัดส่ง" (ฟอร์มแก้ไขได้)**: แสดงเฉพาะเมื่อ `status == readyToShip` เท่านั้น — 2 `TextField` เรียงแนวตั้ง: "ผู้ให้บริการขนส่ง" (`labelText`, required) / "เลขพัสดุ" (`labelText`, required) — error state แสดงทันทีที่กด "ยืนยันจัดส่งแล้ว" ถ้าว่าง (มิเรอร์ `ZokyCheckoutAddressScreen`'s required-field validate-on-submit pattern เป๊ะ)
- Action area (bottom-anchored, `SafeArea`+`Padding` มิเรอร์ `ZokyOrderDetailScreen._buildActionBar` เป๊ะ) — เปลี่ยนเนื้อหาตามสถานะปัจจุบัน (ไม่ใช่ disable ปุ่มที่กดไม่ได้ แต่ไม่แสดงเลย):
  - `paid`: `FilledButton` "เริ่มเตรียมสินค้า" + `OutlinedButton` (error) "ยกเลิกคำสั่งซื้อ"
  - `sellerProcessing`: `FilledButton` "พร้อมจัดส่ง" + `OutlinedButton` (error) "ยกเลิกคำสั่งซื้อ"
  - `readyToShip`: `FilledButton` "ยืนยันจัดส่งแล้ว" (disable จนกว่าทั้งสองช่องของฟอร์มด้านบนไม่ว่าง) + `OutlinedButton` (error) "ยกเลิกคำสั่งซื้อ"
  - `shipped`: `OutlinedButton` โทนกลาง (ไม่ใช่ error) "ทำเครื่องหมายคืนเงินแล้ว" เดี่ยว ๆ (ไม่มีปุ่มอื่น — buyer เป็นฝ่ายกดยืนยันรับสินค้าเอง)
  - `delivered`: `OutlinedButton` โทนกลาง "ทำเครื่องหมายคืนเงินแล้ว" เดี่ยว ๆ เช่นกัน (เผื่อกรณีลูกค้าขอคืนเงินหลังได้รับสินค้าแล้ว)
  - `cancelled`/`refunded`/`pendingPayment`: **ไม่มี action bar เลย** (`bottomNavigationBar` เป็น `null` — final/unreachable state)

Interactions:
- "เริ่มเตรียมสินค้า"/"พร้อมจัดส่ง": **ไม่มี confirm dialog** (ไม่ใช่ action ทำลาย เป็นการดำเนินความคืบหน้าปกติไปข้างหน้า ตรงตาม Product spec ที่ระบุ confirm dialog เฉพาะยกเลิก/คืนเงินเท่านั้น) → เรียก RPC ตรง ๆ → สำเร็จ `_load()` ใหม่, ล้มเหลว `SnackBar` ข้อความเฉพาะ ("เริ่มเตรียมสินค้าไม่สำเร็จ ลองใหม่อีกครั้ง" / "อัปเดตสถานะไม่สำเร็จ ลองใหม่อีกครั้ง")
- "ยืนยันจัดส่งแล้ว": validate ฟอร์มก่อน (ทั้งสองช่องไม่ว่าง) → เรียก `sellerShipOrder(orderId, provider, tracking)` → สำเร็จ `_load()` ใหม่, ล้มเหลว `SnackBar` "ยืนยันจัดส่งไม่สำเร็จ ลองใหม่อีกครั้ง"
- "ยกเลิกคำสั่งซื้อ": เปิด `AlertDialog` ยืนยันก่อนเสมอ (มิเรอร์ `_confirmDialog` ของ `ZokyOrderDetailScreen` เป๊ะ) — title "ยกเลิกคำสั่งซื้อ?" / body **เนื้อหาเดียวกับฝั่ง buyer** "ยกเลิกแล้วไม่สามารถกู้คืนได้ ระบบจะคืนสินค้ากลับเข้าสต็อก" (ยังถูกต้อง เพราะ `seller_cancel_order` คืน stock เหมือน `cancel_order` เป๊ะ) → เรียก `sellerCancelOrder` → สำเร็จ `_load()` ใหม่, ล้มเหลว `SnackBar` "ยกเลิกคำสั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง"
- "ทำเครื่องหมายคืนเงินแล้ว": เปิด `AlertDialog` ยืนยันก่อนเสมอ — title "ทำเครื่องหมายคืนเงินแล้ว?" / body **ต้องระบุชัดว่าเป็นบันทึกบัญชีเท่านั้น** (ตามที่ Product spec บังคับตรง ๆ): **"การกระทำนี้เป็นการบันทึกบัญชีเท่านั้น ระบบยังไม่มีการโอนเงินคืนอัตโนมัติ กรุณาดำเนินการคืนเงินจริงให้ลูกค้าด้วยตนเองก่อนยืนยัน"** → เรียก `sellerMarkRefunded` → สำเร็จ `_load()` ใหม่, ล้มเหลว `SnackBar` "บันทึกการคืนเงินไม่สำเร็จ ลองใหม่อีกครั้ง"
- ทุก action ระหว่างรอผลลัพธ์: disable ปุ่มที่กด + แสดง spinner ในปุ่มนั้น (มิเรอร์ `_isSubmitting` pattern ของ `ZokyOrderDetailScreen`/`StockAdjustmentSheet` เป๊ะ — ปุ่มอื่นในแถบเดียวกันก็ disable ไปด้วยกันกันกดซ้อน)

States:
- Loading initial: `CircularProgressIndicator` กึ่งกลาง
- Not found: "ไม่พบคำสั่งซื้อนี้" (มิเรอร์ `ZokyOrderDetailScreen`)
- Submitting: ดูข้างต้น
- Field validation error (ฟอร์มจัดส่ง): ข้อความสั้นสีแดงใต้ field ที่ว่าง (มิเรอร์ `ZokyCheckoutAddressScreen`)

Responsive Behavior: `ListView` + `SafeArea` bottom-anchored action bar (มิเรอร์ `ZokyOrderDetailScreen` เป๊ะ) — คอลัมน์เดียวมือถือ

Accessibility: `TextField` ทั้งสองของฟอร์มจัดส่งมี label ผ่าน `InputDecoration.labelText` อัตโนมัติ, ปุ่ม action ทุกปุ่มเป็น Material `FilledButton`/`OutlinedButton` ธรรมดา (label เป็นข้อความอยู่แล้ว ไม่ต้องเพิ่ม `Semantics` พิเศษ — สอดคล้อง convention เดิมของ `ZokyOrderDetailScreen`'s action bar ที่ไม่มี `Semantics` เพิ่มเติมเช่นกัน)

Design Rules: มี `FilledButton` (primary) ได้สูงสุด 1 ปุ่มต่อสถานะเสมอ (ไม่มีสถานะไหนมี 2 primary action แข่งกัน) — "ยกเลิกคำสั่งซื้อ" เป็น `OutlinedButton` สีแดง (error) เสมอเมื่อปรากฏ, "ทำเครื่องหมายคืนเงินแล้ว" เป็น `OutlinedButton` โทนกลาง (ไม่ใช่แดง) ตามเหตุผลใน "การตัดสินใจสำคัญ" ข้อ 4 ด้านบน

Handoff: `SellerRepository` เมธอดใหม่:
- `fetchStoreOrder(String orderId)` → `Order?`
- `fetchStoreOrderItems(String orderId)` → `List<OrderItem>`
- `sellerStartProcessing(String orderId)` → `Future<void>` (RPC `seller_start_processing`)
- `sellerMarkReadyToShip(String orderId)` → `Future<void>` (RPC `seller_mark_ready_to_ship`)
- `sellerShipOrder(String orderId, String shippingProvider, String trackingNumber)` → `Future<void>` (RPC `seller_ship_order`)
- `sellerCancelOrder(String orderId)` → `Future<void>` (RPC `seller_cancel_order`)
- `sellerMarkRefunded(String orderId)` → `Future<void>` (RPC `seller_mark_refunded`)

ทุกเมธอด RPC ด้านบนควรโยน exception ที่ UI แยกแยะได้ระหว่าง "สถานะไม่ถูกต้อง (RPC ปฏิเสธ transition)" กับ error อื่น ๆ ถ้าเป็นไปได้ (มิเรอร์ `InsufficientStockException` pattern ของ SELLER-002) — ถ้า Coding เห็นว่าไม่คุ้มค่าที่จะแยก exception type ใหม่รอบนี้ (เพราะ UI แค่โชว์ SnackBar ข้อความทั่วไปพอ ไม่ต้องข้อความเฉพาะเจาะจงแบบ "สต็อกไม่พอ") ให้ใช้ generic catch พร้อม SnackBar ตามที่ระบุใน Interactions ก็เพียงพอ — ไม่บังคับต้องสร้าง exception class ใหม่ถ้าไม่จำเป็นจริง

---

## SellerHomeShell (แก้ไขจุดเดิม)

Screen: `SellerHomeShell` — เปลี่ยนเฉพาะ tab index 2

Purpose: เปิดใช้งาน `SellerOrderListScreen` จริงแทน placeholder

Handoff: `seller_app/lib/features/shell/presentation/seller_home_shell.dart` — แก้บรรทัดเดียว: `const SellerComingSoonScreen(label: 'คำสั่งซื้อ')` → `SellerOrderListScreen(store: widget.store, sellerRepository: widget.sellerRepository)` (มิเรอร์วิธีที่ SELLER-002 แก้ tab index 1 ทุกประการ) — tab index 3 ("ร้านค้า") และ 4 ("การเงิน") **ไม่แตะ** ยังเป็น `SellerComingSoonScreen` เหมือนเดิม

---

## Data Model (ส่วนที่แก้/เพิ่มใหม่)

**`app/` (Customer, แก้ของเดิม):**
- `app/lib/features/zoky/data/order.dart`: `enum OrderStatus` ขยาย 8 ค่า (`pendingPayment, paid, sellerProcessing, readyToShip, shipped, delivered, cancelled, refunded`), เพิ่ม field `shippingProvider`/`trackingNumber` (`String?`, nullable) ใน `Order` + `Order.fromMap`

**`seller_app/` (ใหม่ทั้งหมด — duplicate ตาม pattern เดิมจาก SELLER-001/002 เพราะคนละ Flutter binary):**
- `seller_app/lib/features/order/data/order.dart` — `Order`/`OrderStatus`/`orderStatusFromString` duplicate ตรงจาก `app/`'s เวอร์ชันใหม่ (รวม `shippingProvider`/`trackingNumber`)
- `seller_app/lib/features/order/data/order_item.dart` — `OrderItem` duplicate ตรงจาก `app/`'s เดิม (ไม่มีฟิลด์เพิ่ม)

---

## Responsive Behavior (ภาพรวม)

ทุกหน้าจอ/widget ใหม่ของ SELLER-003 เป็น mobile-first คอลัมน์เดียวเต็มความกว้างจอ ไม่มี layout พิเศษสำหรับแท็บเล็ต/แนวนอนในรอบนี้ (สอดคล้อง convention ทั้งโปรเจกต์) — ฟอร์มกรอก Shipping Provider/Tracking รองรับ dynamic type ผ่าน `Theme.of(context).textTheme` เดียวกับทุกฟอร์มในโปรเจกต์

## Accessibility (ภาพรวม)

- Contrast ratio ตาม design-principles.md เดิม (AA ขั้นต่ำ) — ทุกสีของ `OrderStatusBadge` 8 สถานะเป็น role มาตรฐานของ `ColorScheme`/สี success-green/error-red ที่ผ่านมาตรฐานนี้แล้วจาก ZOKY-003
- ไม่มีจุดไหนสื่อสารสถานะด้วยสีอย่างเดียว — badge ทุกสถานะมี icon+ข้อความกำกับเสมอ แม้สถานะที่ใช้สีเดียวกัน (4 สถานะ "กำลังดำเนินการ") ก็แยกด้วย icon/ข้อความชัดเจน
- ปุ่ม action ทุกจุด ≥44px touch target (Material `FilledButton`/`OutlinedButton` default สูงเกิน 44px อยู่แล้วตาม convention เดิม)

## เตือน Coding (จาก Product spec's Risks — ย้ำจุดที่กระทบ UI/UX โดยตรง)

1. **Action bar เป็น per-status ไม่ใช่ all-or-nothing อีกต่อไป** ทั้งฝั่ง Customer (`ZokyOrderDetailScreen`) และ Seller (`SellerOrderDetailScreen`) — เขียน test แยกทีละสถานะให้ครบ ไม่ใช่แค่ทดสอบว่า "มีปุ่ม" หรือ "ไม่มีปุ่มเลย" 2 เคสแบบเดิม
2. **`create_orders()`/`cancel_order()`/`confirm_order_received()` แก้แค่เงื่อนไข source-status/ค่า status เริ่มต้น** — ห้ามแตะ locking (`for update order by id`)/loop structure ใด ๆ (ย้ำจากที่ Product spec เตือนแล้ว, มาตรฐานเดียวกับที่ SELLER-002 เคยทำสำเร็จกับฟังก์ชันเดียวกันนี้มาแล้วครั้งหนึ่ง)
3. **RPC ใหม่ 5 ตัวฝั่ง seller ต้องตรวจ ownership ผ่าน `stores.owner_id = auth.uid()` ให้ครบทุกตัว** — เตือน QA ตรวจ attack scenario แยกทีละ RPC ไม่ตรวจรวมเป็นกลุ่มเดียว (บทเรียนซ้ำจาก ZOKY-004/SELLER-001/SELLER-002)
4. **Migration SQL ต้องเรียง UPDATE (`pending`→`paid`) ก่อน ALTER CONSTRAINT เสมอ** และห้ามเดาชื่อ constraint เดิม (ต้อง query `information_schema`/`pg_constraint` ก่อน drop) — รายละเอียดเต็มอยู่ใน Product spec ข้อ 3 แล้ว Design ไม่มีการตัดสินใจเพิ่มเติมในจุดนี้ (เป็น backend/DB concern ล้วน ไม่กระทบ UI)
5. **`SellerRepository.fetchOrderCounts()` (SELLER-001 Dashboard)**: เปลี่ยน `.eq('status', 'pending')` → `.eq('status', 'paid')` เท่านั้น — ไม่มีการเปลี่ยนแปลง UI ใด ๆ ที่ Dashboard (label "คำสั่งซื้อใหม่" คงเดิม ความหมายเดิมทุกประการ แค่ชื่อสถานะที่ query เปลี่ยน)
6. เขียน regression test ครอบคลุม: `OrderStatusBadge` ทั้ง 8 สถานะไม่ crash, `ZokyOrderDetailScreen`/`SellerOrderDetailScreen` action bar ถูกต้องครบทุกสถานะ (รวม `cancelled`/`refunded`/`pendingPayment` ไม่มีปุ่มเลย), `SellerOrderListScreen`'s filter scope เฉพาะร้านตัวเอง (พิสูจน์ด้วย 2 ร้านจำลอง แบบเดียวกับ SELLER-002), RLS/RPC ownership cross-store attack scenario ครบ 5 RPC ใหม่, ยืนยัน ZOKY-004's reviews ไม่กระทบ (gate ยังเป็น `status = 'delivered'` เดิม)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement:
1. Migration SQL (ลำดับ UPDATE→verify constraint name→DROP→ADD CONSTRAINT→เปลี่ยน default→เพิ่มคอลัมน์ shipping) ตาม Product spec ข้อ 3 ทุกประการ — ไม่มีการตัดสินใจ Design เพิ่มเติม
2. RPC ใหม่ 5 ตัวฝั่ง seller + แก้ RPC เดิม 3 ตัว (`create_orders`/`cancel_order`/`confirm_order_received`) ตาม Product spec ข้อ 4
3. `OrderStatusBadge` ขยาย 8 สถานะ (ทั้ง `app/` และ duplicate ใหม่ใน `seller_app/`) ตามตารางสี/icon/label ข้างต้น
4. `ZokyOrderDetailScreen`/`Order` model (Customer) แก้ per-status action bar + เพิ่มการ์ดข้อมูลจัดส่ง
5. `SellerOrderListScreen` + `SellerOrderListTile` + `SellerOrderDetailScreen` ใหม่ทั้งหมดใน `seller_app/` ตามที่ระบุ + `SellerHomeShell`'s tab index 2
6. Data model ใหม่ใน `seller_app/`: `Order`/`OrderStatus`/`OrderItem` duplicate
7. `SellerRepository` เมธอดใหม่ทั้งหมดที่ระบุไว้ในแต่ละ Screen's Handoff + แก้ `fetchOrderCounts()`
8. Test เดิมของ ZOKY-003 (`app/test/zoky_order_list_screen_test.dart`, `app/test/zoky_order_detail_screen_test.dart`) อัปเดตตาม Product spec + เพิ่มเคสสถานะกลางตามที่ระบุใน Handoff ของ `ZokyOrderDetailScreen` ข้างต้น

ดู Product spec `.wyn/tasks/backlog/SELLER-003-order-management.md` สำหรับ Database/RLS/RPC schema เต็ม, Acceptance Criteria, และ Risks ฉบับเต็ม (โดยเฉพาะ migration sequencing และ ownership check pattern ที่เป็นหัวใจความปลอดภัยของ task นี้) — เมื่อ Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น %
