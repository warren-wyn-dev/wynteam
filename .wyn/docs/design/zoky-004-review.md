# Design — ZOKY-004 (Review)

อ้างอิง Product spec: `.wyn/tasks/backlog/ZOKY-004-review.md` — เติมส่วนรีวิวที่ `ProductDetailScreen`/`StoreScreen` (ZOKY-001) เตรียม UI ไว้แล้วแต่ hard-code ว่างเปล่า ให้ทำงานจริง ผูกกับ Order สถานะ `delivered` (ZOKY-003)

Design system เดิมทั้งหมด: Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass — reuse component ที่มีอยู่แล้ว (`AvatarCircle`, `ConfirmDeleteDialog`/`confirmDeletePost`, `relativeTimeLabel`, comment-sheet pattern จาก `PopCommentSheet`/`DropDetailScreen` (WYN-005/006), `OrderStatusBadge` โครง badge)

## ประเด็นที่ต้องตัดสินใจก่อนออกแบบ (Product spec ปล่อยให้ Design ตัดสินใจ)

**Product Detail's entry point เขียนรีวิว เมื่อผู้ใช้มีของที่ซื้อซ้ำหลายครั้งยังไม่รีวิว**: Product spec ระบุว่า Product Detail ต้องมีจุดเข้าถึงฟอร์มเขียนรีวิวถ้ามีสิทธิ์ แต่รีวิวผูกกับ `order_item` ไม่ใช่ product เฉย ๆ — ถ้าผู้ใช้ซื้อสินค้าเดิมหลายครั้ง (หลาย Order ที่ delivered แล้ว) และยังไม่รีวิวมากกว่า 1 order_item จะเลือกไม่ได้ว่าจะรีวิวอันไหนจาก Product Detail โดยตรง **ตัดสินใจ**: ถ้ามี order_item ที่มีสิทธิ์รีวิวได้พอดี **1 รายการ** → ปุ่ม "เขียนรีวิว" เปิดฟอร์มตรงให้ order_item นั้นเลย ถ้ามี **มากกว่า 1 รายการ** → แสดงข้อความลิงก์ "คุณมีสินค้าที่ยังไม่ได้รีวิว ไปที่คำสั่งซื้อของคุณ" พาไปหน้า `ZokyOrderListScreen` แทน (ไม่สร้าง picker UI ใหม่รอบนี้ เพราะเป็น edge case ที่พบไม่บ่อย — ซื้อสินค้าเดิมซ้ำหลายรอบโดยไม่รีวิวเลยสักครั้ง) — จุดเข้าถึงหลักที่แนะนำผู้ใช้เสมอคือ Order Detail's per-item ตามที่ Product ระบุไว้ชัดเจนแล้ว

---

## Screen: ReviewFormSheet (modal bottom sheet ใหม่)

Purpose: ให้ผู้ใช้ให้คะแนน 1-5 ดาว + เขียนข้อความรีวิว (ไม่บังคับ) สำหรับ order_item ที่ตัวเองซื้อและได้รับแล้ว — ใช้หน้าเดียวกันทั้งเขียนใหม่และแก้ไขรีวิวเดิม (pre-fill ค่าเดิมถ้าแก้ไข)

User Flow:
1. เปิดจาก `ZokyOrderDetailScreen`'s ปุ่ม "เขียนรีวิว" ต่อรายการสินค้า (เมื่อ order status = delivered และ order_item นั้นยังไม่เคยรีวิว) หรือปุ่ม "แก้ไขรีวิว" (ถ้ารีวิวไปแล้ว) หรือจาก Product Detail's entry point ตามที่ตัดสินใจไว้ข้างบน
2. เลือกดาว (แตะดาวที่ต้องการ, บังคับเลือกอย่างน้อย 1 ดาวก่อนกดส่งได้) → พิมพ์ข้อความ (ไม่บังคับ) → กด "ส่งรีวิว"/"บันทึกการแก้ไข"
3. สำเร็จ → ปิด sheet, แสดง SnackBar ยืนยัน, หน้าที่เรียกมา refresh สถานะ (Order Detail แสดง "รีวิวแล้ว" แทนปุ่มเขียน, Product Detail refresh รายการรีวิว)
4. ถ้าเป็นการแก้ไข → มีปุ่ม "ลบรีวิว" แยกต่างหาก (สีแดง/error, ผ่าน `confirmDeletePost` เหมือน comment ของ WYN Social) อยู่ล่างสุดของ sheet

Components:
- `StarRatingInput` (widget ใหม่) — แถวดาว 5 ดวงขนาดใหญ่ (32px) แตะดาวที่ N เพื่อเลือกคะแนน N (แตะดาวที่ 3 = เลือก 3 ดาว, ดาวที่ 1-3 เติมสี ที่เหลือ outline) ไม่มี half-star, ไม่มีค่าเริ่มต้น (ต้องแตะเลือกเองเสมอแม้ตอนเขียนใหม่ — ป้องกันส่งรีวิวโดยไม่ได้ตั้งใจเลือกดาว)
- `TextField` multiline (maxLines: 4, ไม่บังคับกรอก) hint "เล่าประสบการณ์การใช้สินค้านี้ (ไม่บังคับ)"
- ปุ่ม "ส่งรีวิว" (`FilledButton`, disable จนกว่าจะเลือกดาว, disable+แสดง loading ระหว่างส่งป้องกันกดซ้ำ — มิเรอร์ pattern เดียวกับ ZOKY-003's Checkout ยืนยันคำสั่งซื้อ)
- ปุ่ม "ลบรีวิว" (`TextButton`, สี error, แสดงเฉพาะโหมดแก้ไข) → `confirmDeletePost(context, itemLabel: 'รีวิว')` ก่อนลบจริงเสมอ

Interactions:
- แตะดาว → อัปเดตค่าที่เลือกทันที (ไม่มี debounce, เป็น local state ล้วน)
- ส่งไม่สำเร็จ (เช่น network error) → SnackBar แจ้ง error, sheet ไม่ปิด, ข้อความที่พิมพ์ไว้ยังอยู่ (มิเรอร์ pattern `PopCommentSheet._sendComment`'s catch block ที่เก็บ text ไว้ให้ retry ได้)
- ลบสำเร็จ → ปิด sheet, SnackBar ยืนยัน, caller refresh

States: loading (ระหว่างส่ง/ลบ — disable ปุ่มทั้งหมด), error (SnackBar ชั่วคราว ไม่ block UI), success (ปิด sheet)

Responsive Behavior: `showModalBottomSheet(isScrollControlled: true)` + `SafeArea` เหมือน `PopCommentSheet` — เนื้อหาสั้น ไม่ต้อง `FractionallySizedBox` บังคับสัดส่วนหน้าจอ (ปล่อยให้สูงตามเนื้อหา + คีย์บอร์ด)

Accessibility: ดาวแต่ละดวงมี `Semantics(label: "ให้ N ดาว")`, ปุ่มส่ง/ลบมี label ชัดเจนไม่ใช้ไอคอนเปล่า

Design Rules: ใช้ดาวสีเหลือง/ทอง (`Colors.amber`) ตามมาตรฐาน rating UI ทั่วไป (ไม่ใช้ primary blue เพราะดาวเป็น convention สากลที่ผู้ใช้คุ้นเคยอยู่แล้ว การเปลี่ยนสีจะสร้างความสับสนมากกว่าคงความสอดคล้อง design system)

Handoff: state management แบบ `StatefulWidget` ธรรมดา ไม่มี library เพิ่ม — repository เมธอดใหม่ `submitReview({required orderItemId, required productId, required rating, String? textContent})` (ใช้ upsert หรือ insert/update แยกตามว่ามีรีวิวอยู่แล้วหรือไม่ — ให้ Coding ตัดสินใจ pattern ที่เข้ากับ RLS ที่จะเขียน) และ `deleteReview(reviewId)`

---

## Screen: ZokyOrderDetailScreen — ส่วนเพิ่มต่อรายการสินค้า

Purpose: จุดเข้าถึงหลักในการเขียน/แก้ไขรีวิวต่อ order_item ตามที่ Product spec ระบุ

User Flow: อยู่ในหน้า Order Detail เดิม (ZOKY-003) — เมื่อ `order.status == OrderStatus.delivered` แต่ละแถวสินค้าใน "รายการสินค้า" card เพิ่มแถวย่อยด้านล่าง: ถ้ายังไม่เคยรีวิว order_item นั้น → ปุ่ม `TextButton.icon(Icons.star_border, 'เขียนรีวิว')` เปิด `ReviewFormSheet` โหมดเขียนใหม่; ถ้ารีวิวไปแล้ว → แถวแสดงดาวที่ให้ไว้ (read-only, ใช้ widget `StarRatingDisplay`) + `TextButton('แก้ไขรีวิว')` เปิด `ReviewFormSheet` โหมดแก้ไข (pre-fill)

Components: เพิ่ม `StarRatingDisplay` (widget ใหม่, read-only, ขนาดเล็ก 16px, รับ `double rating` แสดงดาวเต็ม/ดาวเปล่าโดยปัดเศษเป็นจำนวนเต็มที่ใกล้ที่สุด — ไม่ทำ half-star fill รอบนี้เพื่อความง่าย) วางต่อท้ายแต่ละแถวสินค้าใน order items card ที่มีอยู่แล้ว

Interactions: ปุ่มเขียน/แก้ไขรีวิวเปิด sheet ผ่าน `showModalBottomSheet` — ปิดแล้ว `await` ผลลัพธ์ → ถ้าสำเร็จ (สร้าง/แก้ไข/ลบ) ให้ re-fetch review status ของ order_item นั้น (ไม่ต้อง reload ทั้งหน้า)

States: เมื่อ order status ไม่ใช่ delivered (pending/cancelled) → ไม่แสดงส่วนรีวิวเลย (ตรงตามที่ Product spec ระบุ "ต้องมี Order ที่ Delivered แล้วถึงจะรีวิวได้")

Responsive Behavior/Accessibility: ตามมาตรฐานเดิมของหน้านี้ (ไม่มีจุดพิเศษเพิ่ม)

Design Rules: ปุ่ม "เขียนรีวิว"/"แก้ไขรีวิว" ใช้ `TextButton` ขนาดเล็กสอดคล้องกับความสำคัญรอง (ไม่ใช่ primary action ของหน้านี้ ต่างจากปุ่ม "ยกเลิก"/"ยืนยันรับสินค้า" ที่เป็น bottom action bar หลัก)

Handoff: repository เมธอดใหม่ `fetchReviewForOrderItem(orderItemId)` คืนค่า `Review?` (null = ยังไม่เคยรีวิว)

---

## Screen: ProductDetailScreen — ส่วนรีวิวที่มีอยู่แล้ว (แทนที่ hard-code)

Purpose: แสดงคะแนนเฉลี่ย+รายการรีวิวจริงของสินค้านั้น แทนข้อความ "ยังไม่มีรีวิว" ที่ตายตัว (ZOKY-001 เตรียมตำแหน่งไว้แล้วที่ระหว่าง "รายละเอียดสินค้า" กับ Store card)

User Flow: เปิดหน้า Product Detail ปกติ → ส่วน "รีวิว" (header เดิม) แสดง: ถ้ามีรีวิว ≥ 1 → คะแนนเฉลี่ย (ดาว + ตัวเลขทศนิยม 1 ตำแหน่ง + "(N รีวิว)") ต่อด้วยรายการรีวิวล่าสุดสูงสุด 3 รายการ (ใหม่สุดก่อน) + ปุ่ม "ดูรีวิวทั้งหมด" ถ้ามีมากกว่า 3 (เปิด `ProductReviewsScreen` ใหม่แสดงครบทุกรายการ แบบ infinite scroll เดียวกับ pattern `ZokyHomeScreen`'s product grid) — ถ้าไม่มีรีวิวเลย → คงข้อความ "ยังไม่มีรีวิว" เดิมไว้ (ไม่เปลี่ยน)

Components:
- Rating summary row: `StarRatingDisplay(rating: avg)` + `Text('${avg.toStringAsFixed(1)} ($count รีวิว)')`
- รายการรีวิว: `ReviewTile` (widget ใหม่ — มิเรอร์ `PopCommentSheet`'s comment tile โครงเป๊ะ: `AvatarCircle` + ชื่อผู้รีวิว + `relativeTimeLabel` + `StarRatingDisplay` เล็ก + ข้อความ ถ้ามี)
- Entry point เขียนรีวิว (ถ้ามีสิทธิ์ตามที่ตัดสินใจไว้ข้างบน) — วางใต้ list ก่อน "ดูรีวิวทั้งหมด"

Interactions: แตะ "ดูรีวิวทั้งหมด" → เปิด `ProductReviewsScreen(productId)` เต็มจอ — ไม่มี interaction อื่นบนหน้านี้ (แก้ไข/ลบรีวิวตัวเองทำที่ Order Detail เท่านั้น ไม่ทำซ้ำที่นี่ เพื่อลด entry point ที่ทำงานเดิมซ้ำสองที่)

States: loading (แสดง `CircularProgressIndicator` เล็กระหว่างโหลดรีวิว, ไม่บล็อกส่วนอื่นของหน้าที่โหลดเสร็จแล้ว — fetch แยก async เหมือน pattern เดิมที่ไม่มีใน ZOKY-001 rating เพราะตอนนั้นยังไม่มี data), error (silent-fail แสดง "ยังไม่มีรีวิว" เหมือนไม่มีข้อมูล แทนที่จะโชว์ error เต็มหน้า — ไม่ critical พอจะรบกวนผู้ใช้ที่มาดูสินค้า)

Responsive Behavior: `ReviewTile` ใช้ `Row`+`Expanded` เหมือน comment tile เดิม ไม่ overflow บนจอแคบ

Accessibility: เหมือน comment tile เดิม (มี label ชัดเจนต่อ avatar/ดาว)

Design Rules: ใช้ widget เดียวกันกับที่ Store Reviews tab ใช้ (`ReviewTile`) เพื่อความสม่ำเสมอ

Handoff: repository เมธอดใหม่ `fetchProductRating(productId)` คืน `(double average, int count)`, `fetchProductReviews(productId, {limit})` คืน `List<Review>`

---

## Screen: ProductReviewsScreen (ใหม่)

Purpose: แสดงรีวิวทั้งหมดของสินค้าชิ้นเดียว เมื่อมีมากกว่า 3 รายการ (แทนที่จะยัดทั้งหมดไว้ใน Product Detail ที่ยาวอยู่แล้ว)

User Flow: เปิดจาก Product Detail's "ดูรีวิวทั้งหมด" → แสดง rating summary เดิมด้านบนคงที่ + `ListView.builder` ของ `ReviewTile` ทั้งหมด (infinite scroll ถ้าจำนวนมาก มิเรอร์ pattern `ZokyRepository.ordersPageSize` จาก ZOKY-003)

Components: `AppBar(title: Text('รีวิวทั้งหมด'))`, rating summary row (เดิม), `ListView.builder` ของ `ReviewTile`

Interactions/States: เหมือน Product Detail's ส่วนรีวิว (loading/empty ไม่ควรเกิดเพราะเปิดจากที่มีรีวิวอยู่แล้วเท่านั้น)

Responsive Behavior/Accessibility: ตามมาตรฐานเดิมของ list screen ทั่วไปในโปรเจกต์ (มิเรอร์ `ZokyOrderListScreen`)

Design Rules: ไม่มีจุดพิเศษ

Handoff: reuse `fetchProductReviews(productId, {limit, offset})` แบบ paginate

---

## Screen: StoreScreen — Reviews tab (แทนที่ hard-code) + Header rating

Purpose: แสดงรีวิวรวมของทุกสินค้าในร้าน + คะแนนเฉลี่ยรวมที่ header (ปัจจุบัน placeholder ทั้งคู่)

User Flow: เปิดแท็บ "รีวิว" ใน Store → แสดงรายการรีวิวของทุกสินค้าในร้านนั้น ใหม่สุดก่อน พร้อมชื่อสินค้ากำกับแต่ละรีวิว (เพราะรวมจากหลายสินค้าต่างจาก Product Detail ที่รู้ context สินค้าอยู่แล้ว) — Header ด้านบนของ `StoreScreen` (ที่ตอนนี้เป็น placeholder rating) แสดงคะแนนเฉลี่ยรวมจริง + จำนวนรีวิวรวม

Components: `ReviewTile` เดิม + เพิ่ม prop ไม่บังคับ `productName` (แสดงเป็น chip/label เล็กเหนือข้อความรีวิว เมื่อไม่ null) — Header rating แทนที่ placeholder ด้วย `StarRatingDisplay` + ตัวเลข เหมือน Product Detail

States: ไม่มีรีวิวเลยทั้งร้าน → คงข้อความ "ยังไม่มีรีวิว" เดิมที่ `_buildReviewsTab` มีอยู่แล้ว, Header ไม่มีรีวิวเลย → แสดง "ยังไม่มีรีวิว" แทนดาว 0 ดวง (ตาม pattern เดียวกับ Product Detail ที่ ZOKY-001 design ไว้แล้ว)

Responsive Behavior/Accessibility: เหมือน `ReviewTile` เดิม

Design Rules: เรียงตาม `created_at desc` เดียวกันทุกที่ที่แสดงรีวิว (consistency)

Handoff: repository เมธอดใหม่ `fetchStoreRating(storeId)` คืน `(double average, int count)`, `fetchStoreReviews(storeId, {limit, offset})` คืน `List<Review>` (join `reviews` → `products` ที่ `store_id` ตรงกัน, เรียง `created_at desc`) — `Review` model ต้องมี `productName` field (nullable ใช้เฉพาะ context นี้ หรือ join แยกต่างหากแล้ว map เข้า ให้ Coding เลือก pattern ที่เข้ากับ query จริง)

---

## เตือน Coding (สำคัญ — เก็บจาก Product spec's Risks)

1. **RLS insert policy ของ `reviews` ต้องตรวจ delivered-order ownership จริงฝั่ง server** — `exists` subquery join `order_items`→`orders` ตรวจ `orders.buyer_id = auth.uid()` และ `orders.status = 'delivered'` และ `order_items.product_id = new.product_id` (กัน client ส่ง product_id ไม่ตรงกับ order_item จริง) — ไม่ต้องใช้ security-definer RPC เพราะเป็น single-table write ธรรมดาที่ RLS `with check` แสดงเงื่อนไขได้ตรงไปตรงมา
2. **Unique constraint `(order_item_id)`** บนตาราง `reviews` กัน 1 order_item ถูกรีวิวซ้ำสองครั้ง (unique ไม่ใช่ `(user_id, product_id)` เพราะซื้อซ้ำต้องรีวิวได้อีกตามที่ Product ตัดสินใจไว้)
3. **คะแนนเฉลี่ยห้าม denormalize/snapshot** — ใช้ `avg()`/`count()` query สดทุกครั้งที่แสดงผล (ต่างหลักการจาก ZOKY-003's fee snapshot โดยตั้งใจ — อย่าสับสนสอง pattern)
4. **update/delete policy**: `user_id = auth.uid()` ตรงไปตรงมา ไม่ต้องเช็ค order status ซ้ำ (แก้ไข/ลบรีวิวที่เคยผ่านเงื่อนไข insert แล้วไม่ต้องเช็คซ้ำว่า order ยัง delivered อยู่ไหม เพราะสถานะ order เปลี่ยนกลับไม่ได้อยู่แล้วตาม ZOKY-003's 3-state design)

Handoff: ส่งต่อ AI Coding (`/code`)
