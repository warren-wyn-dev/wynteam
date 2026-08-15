# Product Task — ZOKY-004

Status: review (QA รอบ 1 — FAIL)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (รอบ 1 — FAIL) → AI Debug Engineer

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

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/zoky-004-review.md` — สรุป: `ReviewFormSheet` ใหม่ (modal bottom sheet มิเรอร์ `PopCommentSheet`) ใช้ทั้งเขียนใหม่/แก้ไข (pre-fill), `StarRatingInput` (ดาว 32px แตะเลือก ไม่มีค่าเริ่มต้นบังคับแตะเอง) และ `StarRatingDisplay` (read-only 16px, ปัดเศษเป็นจำนวนเต็ม ไม่ทำ half-star) เป็น widget ใหม่ทั้งคู่ — `ZokyOrderDetailScreen` เพิ่มปุ่ม "เขียนรีวิว"/"แก้ไขรีวิว" ต่อรายการสินค้าเมื่อ status delivered เท่านั้น — `ProductDetailScreen`'s ส่วน "รีวิว" (เดิม hard-code "ยังไม่มีรีวิว") แสดงคะแนนเฉลี่ย+รายการล่าสุด 3 รายการจริงเมื่อมีรีวิว คงข้อความเดิมเมื่อไม่มี, เพิ่ม `ProductReviewsScreen` ใหม่ (ดูทั้งหมด, infinite scroll) — `StoreScreen`'s Reviews tab รวมรีวิวทุกสินค้าในร้านพร้อมชื่อสินค้ากำกับ, Header rating เป็นค่าจริง — ตัดสินใจ edge case "ซื้อซ้ำหลายครั้งยังไม่รีวิว": Product Detail เปิดฟอร์มตรงถ้ามี order_item ที่มีสิทธิ์พอดี 1 รายการ ถ้ามากกว่านั้นพาไปหน้า Order List แทน (ไม่สร้าง picker UI ใหม่) — เตือน Coding 4 จุด: RLS insert ต้องตรวจ delivered-order ownership จริงผ่าน `exists` subquery (ไม่ใช้ RPC เพราะเป็น single-table write ธรรมดา), unique constraint บน `order_item_id` (ไม่ใช่ `user_id+product_id`), ค่าเฉลี่ยห้าม denormalize query สดเสมอ, update/delete policy แค่ `user_id = auth.uid()` ไม่ต้องเช็ค order status ซ้ำ

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- **Database** (`supabase/schema.sql`): เพิ่ม `reviews` (`order_item_id` unique references `order_items`, `product_id` references `products` on delete cascade, `rating` int 1-5 check constraint, `text_content` nullable, `created_at`/`updated_at`) — RLS: select เปิดให้ authenticated ทุกคน, insert `with check` ตรวจ `auth.uid() = user_id` **และ** `exists` subquery join `order_items`→`orders` ยืนยัน order_item_id/product_id ตรงกันจริง และ order เป็นของผู้ใช้เองสถานะ `delivered` เท่านั้น, update/delete แค่ `auth.uid() = user_id` (ไม่เช็ค order status ซ้ำตามที่ Design ระบุ) — ไม่มี RPC ใหม่ตามที่ Design ตัดสินใจ (single-table write, ไม่มี multi-row business logic)
- **Model**: `Review` (`app/lib/features/zoky/data/review.dart`) — `productName` nullable ใช้เฉพาะ context ที่ต้องระบุ (Store Reviews tab)
- **Repository** (`ZokyRepository` ขยายเพิ่ม): `fetchReviewableOrderItems`/`fetchReviewForOrderItem`/`addReview`/`editReview`/`deleteReview`/`fetchProductRating`/`fetchProductReviews`/`fetchStoreRating`/`fetchStoreReviews` — ค่าเฉลี่ยคำนวณจาก raw `rating` rows client-side ทุกครั้ง (ไม่มี denormalize/cache ตามคำเตือนของ Design)
- **UI**: `StarRatingInput`/`StarRatingDisplay` widget ใหม่ (`widgets/star_rating.dart`), `ReviewTile` (`widgets/review_tile.dart` — มิเรอร์ `PopCommentSheet`'s comment tile), `ReviewFormSheet` (`widgets/review_form_sheet.dart` — modal bottom sheet เขียน/แก้ไข/ลบ) — `ZokyOrderDetailScreen` เพิ่มปุ่มเขียน/แก้ไขรีวิวต่อรายการสินค้าเมื่อ status delivered — `ProductDetailScreen`'s ส่วนรีวิวเดิม (hard-code "ยังไม่มีรีวิว") ต่อคะแนนเฉลี่ย+รายการล่าสุด 3 รายการ+entry point ตามเงื่อนไข edge case ที่ Design ตัดสินใจ (1 รายการ = เปิดฟอร์มตรง, มากกว่า = พาไปหน้า Order List) — `ProductReviewsScreen` ใหม่ (ดูทั้งหมด, infinite scroll) — `StoreScreen`'s Reviews tab + header rating เป็นข้อมูลจริง

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. ตอนแรกสร้าง test repo หลายตัว (`RecordingZokyRepository`) inline ใน `testWidgets` callback ใน `product_detail_screen_test.dart`/`store_screen_test.dart`/`zoky_order_detail_screen_test.dart` (gotcha เดิมที่เคยบันทึกไว้แล้วหลายครั้ง) ทำให้ `flutter test` ล้มด้วย "A Timer is still pending" 9 ทดสอบ — ย้ายทั้งหมดเข้า `setUp()` เป็น named field ตามธรรมเนียม แก้แล้วผ่านหมด
2. Test ใหม่ "shows the average rating and review tiles when reviews exist" ล้มครั้งแรกเพราะ scroll ไปแค่ตำแหน่งคะแนนเฉลี่ย ("4.0 (2 รีวิว)") แล้วเช็คข้อความ ReviewTile ที่อยู่ลึกกว่านั้นทันทีโดยไม่ scroll เพิ่ม — พิสูจน์ด้วย debug test แยกต่างหาก (dump ทุก `Text` widget ที่ render อยู่ ณ จุดนั้น) ยืนยันว่าเนื้อหาส่วนที่ยังไม่ scroll ถึงไม่ถูก build เลย (sliver lazy-build range ตามที่ comment เดิมในไฟล์อธิบายไว้แล้วสำหรับ ProductDetailScreen) ไม่ใช่บั๊ก production — แก้โดยเพิ่ม `scrollToFind` อีกจุดก่อนเช็ค

Files Changed:
- แก้: `supabase/schema.sql` (เพิ่ม ZOKY-004 section ท้ายไฟล์), `app/lib/features/zoky/data/zoky_repository.dart`, `app/lib/features/zoky/presentation/{product_detail_screen,store_screen,zoky_order_detail_screen}.dart`
- ใหม่: `app/lib/features/zoky/data/review.dart`, `app/lib/features/zoky/presentation/product_reviews_screen.dart`, `app/lib/features/zoky/presentation/widgets/{star_rating,review_tile,review_form_sheet}.dart`
- test แก้: `app/test/{product_detail_screen_test,store_screen_test,zoky_order_detail_screen_test}.dart`, `app/test/support/recording_zoky_repository.dart` (ขยาย review fields+methods)
- test ใหม่: `app/test/{review_form_sheet_test,product_reviews_screen_test}.dart`

`flutter analyze`: สะอาด, `flutter test`: 253/253 ผ่าน (เพิ่มจาก 233 เดิม — WYN Social/ZOKY-001/002/003 เดิมทั้งหมดยังผ่านครบ ไม่มี regression)

Handoff: ส่งต่อ AI QA & Security (`/qa`)

---

## QA & Security Report — รอบ 1 (AI QA & Security)

**ผลสรุป: FAIL**

### สิ่งที่ตรวจอิสระ (ไม่เชื่อตัวเลขจาก Coding Output เฉยๆ)

1. **Re-sync ไป merged main เอง** — `git fetch origin main`, rebuild branch `claude/pwd-nxsvf5` บน `origin/main` (commit `135af7a`, PR #83) ใหม่ทั้งหมด
2. **รัน `flutter analyze` อิสระ**: No issues found
3. **รัน `flutter test` อิสระ**: 253/253 ผ่านทั้งหมด — ตรงกับตัวเลขที่ Coding รายงาน ยืนยันด้วยตัวเองแล้ว
4. **ไล่ diff เต็มระหว่าง Design merge (`6054f3d`) กับ Coding merge (`135af7a`)** ด้วย `git diff --stat` — ยืนยันว่ามีแค่ไฟล์ที่เกี่ยวกับ ZOKY-004 เท่านั้นที่ถูกแก้ (รวม `zoky_order_detail_screen.dart`/`product_detail_screen.dart`/`store_screen.dart` ที่ ZOKY-004 ตั้งใจแก้ตาม Design spec) ไม่มีไฟล์ WYN Social หรือ ZOKY-001/002/003 เดิมไฟล์ไหนถูกแตะเลย — ไม่มี regression scope creep

### พบช่องโหว่ความปลอดภัยจริง (Critical — จุดที่ block การ PASS รอบนี้)

**RLS `update` policy ของตาราง `reviews` ไม่ตรวจ delivered-order-ownership gate ซ้ำตอนแก้ไข ทำให้ผู้ใช้ retarget รีวิวของตัวเองไปยัง `product_id`/`order_item_id` ใด ๆ ก็ได้โดยไม่ต้องซื้อจริง**

อ่าน `supabase/schema.sql` (ZOKY-004 section) พบว่า:

```sql
create policy "Users can update their own reviews"
  on public.reviews
  for update
  to authenticated
  using (auth.uid() = user_id);
```

ไม่มี `with check` clause แนบมาด้วย — วิเคราะห์ตาม Postgres RLS semantics จริง (ยืนยันจาก [เอกสารทางการของ Postgres](https://www.postgresql.org/docs/current/sql-createpolicy.html)): เมื่อ `for update` policy ไม่มี `with check` ระบุไว้ Postgres จะใช้ `using` expression เดิมเป็นทั้งตัวกรอง "แถวเก่าที่แก้ได้" **และ** ตัวตรวจ "แถวใหม่หลังแก้ต้องผ่านเงื่อนไขเดียวกัน" — ซึ่งในที่นี้คือแค่ `auth.uid() = user_id` เท่านั้น **ไม่มีการตรวจซ้ำเลยว่า `order_item_id`/`product_id` ใหม่ที่ client ส่งมายังคงอ้างอิงถึง order ที่ตัวเองเป็นเจ้าของและ status ยัง `delivered` อยู่จริง** ต่างจาก insert policy ที่มี `exists` subquery ตรวจครบ

**Attack scenario ที่ยืนยันได้จากการอ่านโค้ด (ยังไม่มี Supabase project จริงให้รันทดสอบสด แต่ policy semantics ยืนยันได้แน่นอนจาก SQL ตรง ๆ)**:
1. User A ซื้อสินค้า X จริงและได้รับแล้ว (`delivered`) → เขียนรีวิว 5 ดาวให้ order_item ของสินค้า X ได้ถูกต้องผ่าน insert policy (ผ่าน gate ปกติ)
2. User A เรียก `zokyRepository.editReview(...)` แต่ตรงไปที่ Supabase client โดยตรงส่ง payload ที่แก้ `product_id`/`order_item_id` ของรีวิวเดิมนั้นให้กลายเป็นสินค้า Y ที่ User A **ไม่เคยซื้อเลย** (หรือแม้แต่ order_item ของ **ผู้ใช้อื่น** ที่ยังไม่มีใครรีวิว เพราะ `order_item_id` unique ทั่วทั้งตาราง ไม่ scope ต่อ user)
3. `update` policy ตรวจแค่ `auth.uid() = user_id` (คงเดิม ไม่เปลี่ยน) → ผ่านทั้ง `using` (แถวเก่า) และ implicit-`with check` (แถวใหม่) เพราะเงื่อนไขเดียวกันไม่ครอบคลุม `product_id`/`order_item_id` เลย → **update สำเร็จ**
4. ผลคือ สินค้า Y ได้รีวิวปลอมที่ไม่มีการซื้อขายจริงรองรับเลย — **ขัดกับ Requirement ข้อแรกสุดของ ZOKY-004 โดยตรง** ("รีวิวผูกกับ Order สถานะ `delivered` เท่านั้น ตรวจฝั่ง server เสมอ กัน fake review") และขัด Acceptance Criteria ข้อ 2 ("ผู้ใช้ที่ไม่มี Order สถานะ delivered ของสินค้านั้น... เขียนรีวิวสินค้านั้นไม่ได้ — ตรวจฝั่ง server")

**Root cause ที่แท้จริง**: comment ของ Design/Coding ในไฟล์ ("Editing/deleting a review never re-checks the order's status -- ... there's nothing left to re-verify beyond plain ownership") ตั้งสมมติฐานถูกแค่ครึ่งเดียว — จริงอยู่ที่ **order status** ไม่มีทาง regress กลับจาก delivered ได้ แต่ไม่ได้พิจารณาว่า `order_item_id`/`product_id` **ของแถว reviews เอง** เปลี่ยนแปลงได้อย่างอิสระผ่าน update โดยไม่มี gate ใด ๆ เลย ซึ่งเป็นคนละเรื่องกับ order status

**Severity**: Critical/blocking — เป็นช่องโหว่ที่ทำลาย security guarantee หลักของทั้งฟีเจอร์ (ป้องกัน fake review) ไม่ใช่แค่ edge case เล็กน้อย

**ข้อเสนอแก้ (ส่งต่อ Debug ตัดสินใจ implementation รายละเอียดเอง)**: เพิ่ม `with check` ให้ update policy ที่ทำ `exists` subquery แบบเดียวกับ insert policy เป๊ะ — รับประกันว่าแถวหลังแก้ (ไม่ว่าจะแก้ field ไหนก็ตาม) ยังต้องอ้างอิง order_item ที่ตัวเองเป็นเจ้าของและ status delivered อยู่เสมอ (ไม่จำเป็นต้อง lock ห้ามเปลี่ยน order_item_id/product_id เป๊ะ ๆ เพราะ Postgres RLS เทียบ OLD vs NEW ค่าในนโยบายเดียวไม่ได้โดยตรง — การตรวจซ้ำแบบเดียวกับ insert ก็เพียงพอปิดช่องโหว่นี้แล้ว เพราะยังคงบังคับว่าค่าใหม่ต้องเป็นการซื้อจริงที่เป็นเจ้าของเสมอ)

### สิ่งที่ตรวจแล้วผ่าน (ไม่พบปัญหา)

1. **RLS `insert` policy ตรวจ delivered-order-ownership gate ถูกต้องจริง** — อ่าน SQL ยืนยัน `exists` subquery join `order_items`→`orders` ตรวจ `oi.id = order_item_id`, `oi.product_id = product_id`, `o.buyer_id = auth.uid()`, `o.status = 'delivered'` ครบทุกเงื่อนไข — จำลอง attack scenario "User A พยายามรีวิว order_item ของ User B" และ "User A พยายามรีวิว order_item ของตัวเองที่ยัง pending" ยืนยันว่าถูกปฏิเสธถูกต้องทั้งคู่
2. **Unique constraint `order_item_id`**: ยืนยันว่าเป็น DB-level constraint จริง (`unique` บนคอลัมน์) ไม่ใช่แค่ app-level check — ป้องกัน 1 order_item ถูกรีวิวซ้ำสองครั้งได้จริงไม่ว่า client จะพยายามข้าม UI ยังไงก็ตาม
3. **ซื้อสินค้าเดิมซ้ำใน Order ใหม่ที่ delivered แล้ว รีวิวรอบใหม่ได้จริง**: ไล่โค้ด `fetchReviewableOrderItems` ยืนยันว่า scope เป็นระดับ order_item ไม่ใช่ product เฉย ๆ ถูกต้องตาม Requirements
4. **ค่าเฉลี่ยคะแนนคำนวณสดจริง ไม่ denormalize/cache**: อ่าน `fetchProductRating`/`fetchStoreRating` ยืนยันว่า query raw `rating` rows ทุกครั้งไม่มี state เก็บค่าเฉลี่ยไว้เลย — และ `ProductDetailScreen`/`ZokyOrderDetailScreen` เรียก `setState`/`_load()` รีเฟรชทันทีหลังรีวิวเปลี่ยนแปลงจริง
5. **`delete` policy ปลอดภัย** — `using (auth.uid() = user_id)` เพียงพอสำหรับ delete (ไม่มี "new row" ให้ retarget แบบ update ได้ ปัญหาข้างต้นใช้ไม่ได้กับ delete)
6. **ปุ่มเขียน/แก้ไขรีวิวใน `ZokyOrderDetailScreen` แสดงเฉพาะ delivered จริง**: ทำ **red→green regression proof อิสระ** — ลบเงื่อนไข `order.status == OrderStatus.delivered` ออกชั่วคราวจากบรรทัด `if (order.status == OrderStatus.delivered && item.productId != null)` แล้วรัน `flutter test test/zoky_order_detail_screen_test.dart` พบว่า test "does not show a review entry point while an order is still pending" พังจริงตามคาด (แดง) คืนโค้ดกลับแล้ว rerun ยืนยันผ่านครบ 12/12 (เขียว) — ยืนยันว่า test คลุมจริง ไม่ใช่ test ที่ผ่านโดยบังเอิญ
7. **Edge case entry point ที่ Design ตัดสินใจ (1 รายการรีวิวได้ = เปิดฟอร์มตรง, มากกว่า 1 = พาไปหน้า Order List)**: ไล่โค้ด `_buildReviewEntryPoint` ใน `ProductDetailScreen` ตรงตามที่ Design ระบุ มี test คลุมทั้งสอง branch
8. **AC ข้อ 6-7 (การแสดงผล rating summary/review list ใน ProductDetailScreen/StoreScreen)**: ไล่โค้ดตรงกับ Design ทุกจุด มี test คลุม

### Minor finding (ไม่ block แต่บันทึกไว้)

`StoreScreen`'s Reviews tab (`_buildReviewsTab`) เรียก `fetchStoreReviews` ครั้งเดียวตอน `initState` ด้วย limit เริ่มต้น (`reviewsPageSize` = 20) โดยไม่มี infinite-scroll/pagination ต่อ — ร้านที่มีรีวิวมากกว่า 20 รายการจะเห็นแค่ 20 รายการแรกโดยไม่มีทางเลื่อนดูเพิ่ม (ต่างจาก `ProductReviewsScreen` ที่ทำ infinite scroll ไว้ครบ) — Design spec ไม่ได้ระบุ pagination UI ของ Store tab ไว้ชัดเจน (แค่ระบุ repo method signature รองรับ `limit`/`offset`) จึงไม่ถือเป็น gap ที่ block แต่ควรบันทึกเป็น fast-follow เดียวกับ known issues อื่น ๆ ของสายนี้

### Acceptance Criteria ที่ block

AC ข้อ 2 และข้อ 5 ("ผู้ใช้ที่ไม่มี Order สถานะ delivered ของสินค้านั้น... เขียนรีวิวสินค้านั้นไม่ได้ — ตรวจฝั่ง server", "แก้ไข/ลบรีวิวของตัวเองได้ แก้/ลบรีวิวของคนอื่นไม่ได้ (RLS ป้องกัน)") ยังไม่ผ่านสมบูรณ์ในส่วนของการ "แก้ไข" — RLS ป้องกันแค่ไม่ให้แก้ไขรีวิว**ของคนอื่น** แต่ไม่ได้ป้องกันการแก้ไขรีวิว**ของตัวเอง**ให้ไปอ้างอิงการซื้อที่ไม่มีอยู่จริง

**Final Status: FAIL** — ส่งต่อ AI Debug Engineer พร้อม bug report ที่ `.wyn/tasks/bugs/ZOKY-004-review-update-rls-gap.md`
