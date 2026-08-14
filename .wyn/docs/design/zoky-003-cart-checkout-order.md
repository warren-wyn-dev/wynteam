# Design Spec — ZOKY-003: Cart & Checkout & Order

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout Shopee/Lazada/TikTok Shop โดยตรง, Touch target ≥44px, ห้ามสื่อสารสถานะด้วยสีอย่างเดียว)
อ้างอิง Product Spec: `.wyn/tasks/backlog/ZOKY-003-cart-checkout-order.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: Notification badge (WYN-012's bell icon), `StoreResultCard`/`ProductGridTile`/`ProductMiniCard` (ZOKY-001/002), `Semantics(button: true, excludeSemantics: true)` convention ทุก interactive element

## ทิศทางภาพรวม

Cart/Checkout/Order เป็น flow ใหม่ทั้งหมดที่ไม่เคยมี pattern ในโปรเจกต์นี้มาก่อน (quantity stepper, multi-screen form, order status badge) — ออกแบบให้เรียบง่ายที่สุดเท่าที่ยังครบฟังก์ชัน ไม่ยืมโครง UI จาก Shopee/Lazada โดยตรง แต่ยึด mobile commerce convention สากล (จัดกลุ่มตามร้าน, สรุปยอดก่อนยืนยันเสมอ) เหมือนที่ ZOKY-002 ยึด filter bottom sheet/sort menu เป็น convention สากลไม่ใช่การก็อปปี้แอปใดแอปหนึ่ง

**การตัดสินใจสำคัญ 2 จุดที่ Product spec ทิ้งไว้ให้ Design ตัดสินใจ:**

1. **Checkout แยกเป็น 2 หน้าจอ ไม่ใช่หน้าเดียวยาว** — `ZokyCheckoutAddressScreen` (กรอกที่อยู่) → กด "ถัดไป" → `ZokyCheckoutSummaryScreen` (สรุปยอด+ยืนยัน) เหตุผล: การรวมฟอร์มกรอกข้อมูล (ต้องการโฟกัส พิมพ์ผิดง่าย) กับปุ่มยืนยันเงินจริงไว้หน้าเดียวยาวเสี่ยงให้ผู้ใช้เลื่อนผ่านสรุปยอดไปกดยืนยันโดยไม่ทันเห็นยอดเงิน (โดยเฉพาะเมื่อมีหลายร้านสรุปยอดแยกกันซึ่งกินพื้นที่มาก) — แยก 2 หน้าจอบังคับให้เห็นสรุปยอดเต็มจอก่อนกดยืนยันเสมอ ใช้ `Navigator.push` ธรรมดา (ไม่ต้องมี `Stepper`/`PageView` ใหม่ ตรงกับ pattern เดิมของโปรเจกต์ที่ทุกหน้าจอเป็น route แยกกัน)
2. **Order status badge**: ใช้สี+icon+ข้อความคู่กันเสมอ (ไม่ใช่สีอย่างเดียว ตาม Accessibility rule) — `pending` = เทา/`onSurfaceVariant` + `Icons.hourglass_empty` + "รอดำเนินการ" (เป็นสถานะกลาง ไม่ใช่ success/error จึงไม่ใช้ Blue primary หรือสีสถานะ), `delivered` = เขียว (success ตาม convention เดิมของ design-principles.md) + `Icons.check_circle` + "ได้รับสินค้าแล้ว", `cancelled` = แดง (error/destructive ตาม convention เดิม) + `Icons.cancel` + "ยกเลิกแล้ว"

---

## Screen 1: `ProductDetailScreen` action bar (แก้จุดเดิมของ ZOKY-001)

Purpose: ทำปุ่ม Add to Cart/ซื้อเลย ให้ทำงานจริง

Components: ปุ่มเดิม 2 ปุ่มที่ตำแหน่งเดิม (`OutlinedButton` "เพิ่มลงตะกร้า" + `FilledButton` "ซื้อเลย") — เปลี่ยนแค่ `onPressed` จาก `_showComingSoon` เป็น:
- **"เพิ่มลงตะกร้า"**: เรียก `addToCart()` แล้วแสดง `SnackBar` สั้น "เพิ่มลงตะกร้าแล้ว" (ไม่ต้องนำทางออกจากหน้า ให้ผู้ใช้เลือกดูสินค้าต่อได้) พร้อม action "ดูตะกร้า" ใน SnackBar (`SnackBarAction`) เพื่อให้ไปต่อได้ทันทีถ้าต้องการ
- **"ซื้อเลย"**: เรียก `addToCart()` เหมือนกัน แล้ว `Navigator.push` ไปหน้า `ZokyCartScreen` ทันที (ตามที่ Product spec ระบุ — ไม่มี flow ซื้อด่วนแยกต่างหาก)
- ถ้ามี variant ให้เลือก (`_selectedVariant` ที่มีอยู่แล้วจาก ZOKY-001) ต้องส่ง selection นั้นไปเป็น snapshot text (เช่น "สี: แดง, ไซส์: M") แนบไปกับ cart item ด้วย — ยังเป็นข้อมูล preview/แสดงผลอย่างเดียวตามที่ Product spec ระบุ (ไม่กระทบ stock)
- ปุ่มทั้งสองต้อง disable (พร้อม label สื่อความหมาย "สินค้าหมด") เมื่อ `product.stock <= 0`

---

## Screen 2: `ZokyCartScreen`

Purpose: จัดการรายการในตะกร้าก่อนสั่งซื้อ

Components:
- AppBar: "ตะกร้าสินค้า"
- **จัดกลุ่มตามร้านค้า**: แต่ละกลุ่มมีหัวข้อร้าน (โลโก้เล็ก 24px + ชื่อร้าน, แตะได้เพื่อไป `StoreScreen`) ตามด้วยรายการสินค้าของร้านนั้น แล้วปิดท้ายด้วยแถว "รวมร้านนี้: ฿X" ชิดขวา — คั่นระหว่างกลุ่มร้านด้วย `Divider` หนา/พื้นหลังต่างสีเล็กน้อย ให้แยกกลุ่มชัดด้วยตา
- **`ZokyCartItemTile`** (widget ใหม่ — ไม่มี pattern เดิมให้ยืม): แถวแนวนอน — thumbnail 64×64 (`ClipRRect` + `Image.network`, ขนาดใหญ่กว่า `ProductMiniCard`'s 96px-width card เพราะที่นี่เป็น row ไม่ใช่ grid) + ชื่อสินค้า (ellipsis 2 บรรทัด) + variant selection snapshot text ถ้ามี (`bodySmall`, สีเทา) + ราคาต่อชิ้น ใต้ชื่อ + **quantity stepper** ชิดขวา (`Icons.remove`/`Icons.add` `IconButton` คั่นตัวเลขตรงกลาง, ปุ่มลบ (`Icons.delete_outline`) แยกต่างหากอีกไอคอนสำหรับลบทั้งแถว ไม่ใช่การกด `-` จนตัวเลขเป็น 0 เพราะกำกวมว่าจะลบหรือหยุดที่ 1)
- **Quantity stepper (component ใหม่ครั้งแรกในโปรเจกต์)**: `Row` มี 3 ส่วน — `IconButton(Icons.remove)` (disable เมื่อ quantity = 1), `Text('$quantity')` กว้างคงที่ตรงกลาง, `IconButton(Icons.add)` (disable เมื่อ quantity = product.stock ปัจจุบัน พร้อม tooltip "สินค้าคงเหลือ N ชิ้น") — ทุกปุ่มใช้ `IconButton` ขนาด default (48px) ผ่านเกณฑ์ touch target ≥44px อยู่แล้วโดยไม่ต้องปรับ
- Empty state: มิเรอร์ `SearchStateMessage` โครงเดียวกัน (icon `Icons.shopping_cart_outlined` ใหญ่ + ข้อความ "ตะกร้าของคุณว่างเปล่า" + ปุ่ม "เลือกซื้อสินค้า" กลับไป ZOKY Home)
- Bottom bar (bottom-anchored ตาม design-principles.md): แถบคงที่ด้านล่างแสดง "ยอดรวมทั้งหมด: ฿X" (ทุกร้านรวมกัน ก่อนหักค่าธรรมเนียม — ค่าธรรมเนียมคำนวณแยกทีหลังตอน Checkout เพราะเป็นต่อ Order/ต่อร้าน) + ปุ่ม `FilledButton` เต็มความกว้าง "ยืนยันคำสั่งซื้อ" → ไป Screen 3

Interaction: แตะ thumbnail/ชื่อสินค้า → `ProductDetailScreen` เดิม (ดูซ้ำได้ก่อนตัดสินใจ)

---

## Screen 3: `ZokyCheckoutAddressScreen`

Purpose: กรอกที่อยู่จัดส่ง (ใช้ร่วมกันทุก Order ในรอบ Checkout นี้ — คนละร้านส่งที่เดียวกันได้ตามปกติ ไม่ต้องกรอกซ้ำต่อร้าน)

Components:
- AppBar: "ที่อยู่จัดส่ง"
- 3 `TextField` เรียงแนวตั้ง: "ชื่อผู้รับ" (`labelText`, required), "เบอร์โทรศัพท์" (`keyboardType: TextInputType.phone`, required), "ที่อยู่จัดส่ง" (`maxLines: 3`, required) — ทุกช่อง error state แสดงทันทีที่กด "ถัดไป" ถ้าว่าง (มิเรอร์ error-state pattern ของฟอร์มเดิมในโปรเจกต์ เช่น Register/Edit Profile)
- ปุ่ม bottom-anchored เต็มความกว้าง "ถัดไป" → validate ฟอร์ม → ถ้าผ่านไป Screen 4 พร้อมส่งค่าที่อยู่ไปด้วย (ยังไม่สร้าง Order ที่ขั้นนี้)

---

## Screen 4: `ZokyCheckoutSummaryScreen`

Purpose: สรุปยอดแยกต่อร้านก่อนยืนยันจริง — จุดสุดท้ายก่อนตัดสินใจ

Components:
- AppBar: "สรุปคำสั่งซื้อ"
- แสดงที่อยู่จัดส่งที่กรอกไว้ (การ์ดสั้น ๆ ด้านบน พร้อมปุ่ม "แก้ไข" กลับไป Screen 3)
- **แยกเป็นการ์ดต่อร้าน** (1 การ์ด = 1 Order ที่กำลังจะถูกสร้าง): ชื่อร้าน, รายการสินค้าในร้านนั้นแบบย่อ (ชื่อ+จำนวน+ราคารวมต่อรายการ), เส้นคั่น, แล้วสรุป 3 บรรทัดชิดขวา: "ค่าสินค้า: ฿X" / "ค่าธรรมเนียมแพลตฟอร์ม (10%): ฿Y" / **"ยอดรวม: ฿Z"** (ตัวหนา ใหญ่กว่าบรรทัดอื่น) — เปอร์เซ็นต์ค่าธรรมเนียมที่แสดงต้องอ่านมาจากค่า config จริงที่ backend จะใช้คำนวณ ไม่ hardcode ข้อความ "10%" ในฝั่ง UI (ถ้า Founder ปรับ % ในอนาคต ต้องเปลี่ยนตามอัตโนมัติทั้งสองฝั่ง)
- ท้ายสุด: "ยอดรวมทั้งหมดทุกร้าน: ฿Total" ตัวใหญ่สุด
- ปุ่ม bottom-anchored เต็มความกว้าง "ยืนยันคำสั่งซื้อ" (`FilledButton`) — กดครั้งเดียว สร้าง Order ทุกร้านพร้อมกัน (1 RPC call เดียวตามที่ Product spec ระบุเรื่อง atomicity) ระหว่างรอผลลัพธ์ต้อง disable ปุ่มทันที+แสดง loading indicator ในปุ่ม (ป้องกันกดซ้ำสร้าง Order ซ้ำ — จุดสำคัญเพราะเป็นการเขียนเงิน/stock จริง)
- สำเร็จ → เปิดหน้า "สั่งซื้อสำเร็จ" แบบ dialog/snackbar สั้น ๆ แล้ว `Navigator.popUntil` กลับไป ZOKY Home (เคลียร์ Cart/Checkout stack ทั้งหมด ไม่ให้กดย้อนกลับไปเจอฟอร์ม Checkout เดิมที่ใช้ไปแล้ว)
- ล้มเหลว (เช่น stock ไม่พอกลางทาง) → แสดง error ชัดเจนระบุสินค้าที่มีปัญหา ไม่ปิดหน้า ให้ผู้ใช้กลับไปแก้ตะกร้าเอง (ไม่ auto-retry)

---

## Screen 5: `ZokyOrderListScreen`

Purpose: ดูประวัติคำสั่งซื้อทั้งหมด — แทนที่ SnackBar placeholder ของปุ่ม Orders ใน ZOKY Home

Components:
- AppBar: "คำสั่งซื้อของฉัน"
- `ListView` ของ **`OrderSummaryCard`** (widget ใหม่ — โครงมิเรอร์ `StoreResultCard` (ZOKY-002): แถวเต็มความกว้าง) แต่ละใบแสดง: thumbnail สินค้าชิ้นแรกของ Order (64×64) + ชื่อร้าน + "และอีก N ชิ้น" ถ้ามีมากกว่า 1 รายการ + วันที่สั่งซื้อ (`relativeTimeLabel` เดิมจากโปรเจกต์) + ยอดรวม + **status badge** (ตามกติกาสีที่ตัดสินใจไว้ข้างบน) มุมขวาบน
- เรียงใหม่สุดก่อน (`created_at desc`), infinite-scroll pagination เดียวกับ pattern เดิมทั่วโปรเจกต์
- Empty state: มิเรอร์ pattern เดิม (icon `Icons.receipt_long_outlined` + "ยังไม่มีคำสั่งซื้อ" + ปุ่มกลับไปเลือกซื้อสินค้า)

Interaction: แตะการ์ด → `ZokyOrderDetailScreen`

---

## Screen 6: `ZokyOrderDetailScreen`

Purpose: ดูรายละเอียด Order เดียว + จัดการสถานะ (ยกเลิก/ยืนยันรับสินค้า)

Components:
- AppBar: "รายละเอียดคำสั่งซื้อ" — status badge เดียวกับ Screen 5 แสดงเด่นใต้ AppBar
- การ์ดที่อยู่จัดส่ง (snapshot จากตอนสั่งซื้อ — ไม่ query ที่อยู่ปัจจุบันของผู้ใช้)
- รายการสินค้า (snapshot ชื่อ/ราคา/จำนวน ณ ตอนสั่งซื้อ — ใช้ thumbnail จาก `image_urls` ที่เก็บ snapshot ไว้ หรือถ้าไม่ snapshot รูปก็ query จาก `product_id` ปัจจุบันแทน เพราะรูปภาพเปลี่ยนไม่กระทบความถูกต้องทางบัญชีเหมือนราคา — **ราคา/ชื่อสินค้าต้อง snapshot เสมอ ไม่ query ปัจจุบัน**)
- สรุปยอด: ค่าสินค้า/ค่าธรรมเนียม/ยอดรวม (snapshot ค่าธรรมเนียม % ที่ใช้จริงตอนสั่งซื้อ ไม่ใช่ % ปัจจุบัน)
- ปุ่มที่แสดงเฉพาะ **`status == pending`** เท่านั้น (ซ่อนไปเลยเมื่อ delivered/cancelled ไม่ใช่แค่ disable — สถานะนั้นจบแล้วไม่มีอะไรให้ทำต่อ):
  - `OutlinedButton` สีแดง (destructive) "ยกเลิกคำสั่งซื้อ" → เปิด `AlertDialog` ยืนยันก่อนเสมอ (มิเรอร์ `ConfirmDeleteDialog` เดิม) เพราะเป็น action ที่ทำกลับไม่ได้และกระทบ stock จริง
  - `FilledButton` "ยืนยันได้รับสินค้าแล้ว" → เปิด `AlertDialog` ยืนยันก่อนเช่นกัน (เป็น action ปิด Order ถาวร ไม่มีทางย้อนกลับสถานะ)

---

## ZOKY Home integration (แก้จุดเดิม)

- **Cart icon**: แตะแล้วเปิด `ZokyCartScreen` แทนที่ `SnackBar` เดิม — เพิ่ม **badge ตัวเลข** มุมขวาบนไอคอน มิเรอร์โครงเป๊ะจาก notification bell badge (WYN-012, `home_feed_screen.dart`'s `_buildNotificationButton`): `Positioned` + `Container` วงกลม (`BorderRadius.circular(8)`, สี `colorScheme.primary`, ตัวเลขสีขาว 10px bold) แสดงเฉพาะเมื่อจำนวนรายการ > 0, ตัด "9+" เมื่อเกิน 9 เหมือนกัน — นับจำนวน **แถว** cart_items ไม่ใช่ผลรวม quantity (ตรงกับ convention ทั่วไปที่ badge = จำนวนชนิดสินค้า ไม่ใช่จำนวนชิ้นรวม)
- **Orders icon**: แตะแล้วเปิด `ZokyOrderListScreen` แทนที่ `SnackBar` เดิม (ไม่มี badge เพราะไม่มีแนวคิด "unread order")

---

## Design Rules

- Quantity stepper และ 2-screen Checkout flow เป็น pattern ใหม่ครั้งแรกในโปรเจกต์ — แต่ยึด mobile convention สากล ไม่ใช่ copy โครง Shopee/Lazada/TikTok Shop ตรง ๆ (ไม่มี "โค้ดส่วนลด" input, ไม่มี multi-payment-method selector, ไม่มี "ที่อยู่ที่บันทึกไว้" list — ตัดทุกอย่างที่ Product spec ไม่ได้ขอ)
- Order status badge ต้องมี icon+ข้อความคู่สีเสมอ ไม่ใช้สีอย่างเดียวสื่อความหมาย ตาม Accessibility rule เดิม
- สี/ตัวอักษร/spacing ทั้งหมดตาม `design-principles.md` เดิม — สีสถานะ (เขียว/แดง) ใช้ตาม convention ที่ระบุไว้แล้ว ไม่ประดิษฐ์สีใหม่
- ทุกปุ่มที่เป็น action ทำลาย/ปิดถาวร (ยกเลิก/ยืนยันรับสินค้า) ต้องมี confirm dialog ก่อนเสมอ มิเรอร์ `ConfirmDeleteDialog` เดิม
- ไม่มีหน้าจอไหนใน ZOKY-003 เป็น Bottom Nav tab ใหม่ (เข้าถึงผ่าน Cart/Orders icon ของ ZOKY Home และปุ่ม Add to Cart/ซื้อเลย ของ Product Detail เท่านั้น)

## Handoff: AI Coding —

1. `ZokyRepository` (หรือ repository ใหม่ `CartRepository`/`OrderRepository` แยกถ้าเหมาะสมกว่า — ให้ Coding ตัดสินใจตามขนาดโค้ด): เพิ่ม `addToCart`, `fetchCartItems`, `updateCartItemQuantity`, `removeCartItem`, `cartItemCount` (สำหรับ badge), และ RPC wrapper 3 ตัว — `createOrders(addressFields)` (atomic, คืนรายการ order ที่สร้างสำเร็จ หรือ throw พร้อมข้อความ stock ไม่พอ), `cancelOrder(orderId)`, `confirmOrderReceived(orderId)`
2. Database: ตาราง `cart_items`/`orders`/`order_items`/`platform_config` ใหม่ตามที่ Product spec ระบุ — RLS: `cart_items` client CRUD ได้เฉพาะแถวตัวเอง (`auth.uid() = user_id`), `orders`/`order_items` **ไม่มี insert/update policy ให้ client เลย** (สร้าง/แก้ผ่าน security-definer RPC เท่านั้น ตาม pattern WYN-014/WYN-006) select restricted เฉพาะเจ้าของ (`buyer_id = auth.uid()`) — RPC ทั้ง 3 ตัวต้องเป็น `security definer`, ตรวจสอบ ownership/สถานะเองเสมอ ไม่เชื่อค่าจาก client, และ `create_order` ต้องตรวจ+หัก stock ในธุรกรรมเดียวกับการสร้าง order (ป้องกัน race condition ตามที่ Product spec เตือนไว้)
3. Widget ใหม่: `ZokyCartItemTile`, quantity stepper (แยกเป็น widget ย่อยใช้ซ้ำได้ถ้าเหมาะสม), `OrderSummaryCard`, order status badge widget (ใช้ร่วมกันทั้ง Screen 5/6)
4. เขียน regression test ครอบคลุมทุก AC ใน Product spec โดยเฉพาะ: stock ไม่พอตอน checkout ต้องถูกปฏิเสธ (ไม่ใช่แค่ happy path), ยกเลิก/ยืนยันรับสินค้าได้เฉพาะเจ้าของ Order เอง, ปุ่มยกเลิก/ยืนยันหายไปทันทีเมื่อสถานะไม่ใช่ pending, ค่าธรรมเนียม snapshot ไม่เปลี่ยนตาม config ปัจจุบันย้อนหลัง, badge Cart อัปเดตถูกต้องหลัง add/remove
5. QA & Security ต้องตรวจเป็นพิเศษ: RPC `create_order` เป็น atomic จริง (single transaction ตรวจ+หัก stock ไม่ใช่ 2 query แยก), ไม่มี client-side path ไหนเขียน `orders`/`order_items` ตรงได้เลยนอกจาก RPC, ownership check ของ `cancel_order`/`confirm_order_received` ป้องกันแก้ Order คนอื่นได้จริง, ค่าธรรมเนียม snapshot ถูกต้อง

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-6 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/ZOKY-003-cart-checkout-order.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
