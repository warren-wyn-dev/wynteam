# Design — SELLER-002 (ZOKY Sellers by WYN: Product Management)

อ้างอิง Product spec: `.wyn/tasks/backlog/SELLER-002-product-management.md` — แทนที่ tab "สินค้า" (`SellerComingSoonScreen`) ด้วยรายการสินค้าจริง, สร้าง/แก้ไข/ปิดการขายสินค้า, variant (สี/ขนาด), ปรับ stock ผ่าน RPC เท่านั้น

Design system เดิมทั้งหมด (Blue+White+Soft Gray seed `0xFF2D6CDF`, Material 3, Rounded Cards, ห้าม Liquid Glass) — ไม่มีจุดไหนใน SELLER-002 เป็น visual language ใหม่ ทุก component ต่อยอด/มิเรอร์จาก `app/`'s ZOKY Marketplace (Customer) และ `seller_app/`'s SELLER-001 ที่มีอยู่แล้ว

## ภาพรวม: reuse pattern อะไรจากที่ไหน

| Component ใหม่ | มิเรอร์จาก |
|---|---|
| `SellerProductListScreen`'s search box + debounce | `ZokySearchScreen`'s TextField+`Timer` 400ms (ZOKY-002) |
| `SellerProductListScreen`'s filter chip row | `ExploreClubsScreen._buildCategoryChips()`'s `ChoiceChip` แถวแนวนอน (WYN-015) |
| `SellerProductListTile` (แถวในลิสต์) | `OrderSummaryCard`'s "thumbnail + text column + trailing marker" โครง (ZOKY-003) |
| `ProductActiveBadge` | `OrderStatusBadge`'s "สี+icon+ข้อความคู่กันเสมอ" หลักการ (ZOKY-003) |
| `SellerProductFormScreen`'s multi-image picker | `CreateClubPostScreen`'s `pickMultiImage`+thumbnail row+ลบทีละรูป (WYN-014) |
| `SellerProductFormScreen`'s `_isEditing` shared create/edit pattern | `ReviewFormSheet`'s `existingReview` ternary ทั้งไฟล์ (ZOKY-004) |
| `SellerProductFormScreen`'s category dropdown | `ZokyProductResultsTab._openFilterSheet()`'s `FutureBuilder<List<Category>>` (ZOKY-002) |
| `StockAdjustmentSheet`'s delta stepper | `QuantityStepper`'s +/- `IconButton` โครง (ZOKY-003), ปรับจาก "จำนวนซื้อ" เป็น "delta ที่จะปรับ" |
| ปุ่ม "+ เพิ่มสินค้า" (FAB) | `ClubPostsTab`'s `FloatingActionButton` (icon `add` เดียว ไม่ extended) (WYN-014) |
| Empty/error state ทั่วไป | `SearchStateMessage` (WYN-009) |
| Confirm dialog (hard-delete จริง เช่น variant ที่เคยบันทึกแล้ว) | `confirmDeletePost` เดิม ใช้ตรง ๆ ไม่ต้องแก้ |
| Confirm dialog "ลบสินค้า" (soft-delete) | **ต้องสร้างใหม่** — ห้ามใช้ `confirmDeletePost` ตรง ๆ (ดูเหตุผลใน Dialog section) |

---

## Screen: SellerProductListScreen (แทนที่ tab "สินค้า" ของ `SellerHomeShell`, index 1)

Purpose: ให้ seller เห็น/ค้นหา/กรองสินค้าของร้านตัวเอง และเป็นทางเข้าไปสร้าง/แก้ไขสินค้า

User Flow:
1. เปิด tab "สินค้า" (ครั้งแรกหลัง sign-in หรือสลับ tab กลับมา) → โหลดรายการสินค้าของร้านตัวเอง filter "ทั้งหมด" เรียง `created_at` ใหม่→เก่า
2. พิมพ์ในช่องค้นหา → debounce 400ms → รีเซ็ต pagination แล้วค้นหาใหม่ (ชื่อ/SKU) scope เฉพาะร้านตัวเอง
3. แตะ filter chip → รีเซ็ต pagination แล้วโหลดใหม่ตามเงื่อนไข
4. Scroll ถึงใกล้ท้ายลิสต์ → โหลดหน้าถัดไป (infinite scroll)
5. แตะแถวสินค้า → เปิด `SellerProductFormScreen(existingProduct: product)` → กลับมาแล้ว refresh ลิสต์เสมอ (ไม่ว่าจะแก้ไข/ลบ/ปรับ stock อะไรไปหรือไม่ก็ตาม — เหมือน `ZokyOrderListScreen._openOrder`'s pattern ที่ reload หลัง push กลับมาเสมอโดยไม่เช็ค return value ก่อน เพราะ reload ที่ไม่จำเป็นไม่มีต้นทุนที่มองเห็นได้ ต่างจากเสี่ยง stale data ถ้าลืมเช็ค)
6. แตะปุ่ม "+" (FAB) → เปิด `SellerProductFormScreen(existingProduct: null)` → กลับมาแล้ว refresh เหมือนกัน
7. Pull-to-refresh → รีเซ็ตกลับหน้าแรกของ filter/search ปัจจุบัน

Components (บนลงล่าง):
- `AppBar(title: Text('สินค้า'))` — ไม่มีปุ่มย้อนกลับ (เป็น tab ไม่ใช่ pushed route)
- ช่องค้นหา: `TextField` ทรงมน (`OutlineInputBorder` วงกลม, prefixIcon แว่นขยาย, hintText "ค้นหาชื่อสินค้า/SKU") — suffixIcon ปุ่มล้างคำค้นเมื่อพิมพ์แล้ว (มิเรอร์ `ZokySearchScreen`'s clear-button ตรง ๆ) อยู่ใต้ AppBar โดยตรง (ต่างจาก `ZokySearchScreen` ที่ใส่คำค้นไว้ใน AppBar title เพราะหน้านี้ AppBar ต้องคงคำว่า "สินค้า" ไว้เป็น tab label เดิม)
- Filter chip row: `ChoiceChip` 4 ตัวแนวนอน scroll ได้ (ทั้งหมด / กำลังขาย / ปิดการขาย / สินค้าหมด) เลือกได้ทีละหนึ่ง มิเรอร์ `ExploreClubsScreen`'s category chip row เป๊ะ (spacing/padding เดียวกัน)
- เนื้อหาหลัก: `RefreshIndicator` ครอบ `ListView.separated` ของ `SellerProductListTile` (`Divider(height: 1)` คั่น มิเรอร์ `ZokyOrderListScreen`)
- `FloatingActionButton(icon: Icons.add, tooltip: 'เพิ่มสินค้า')` มุมขวาล่าง (มิเรอร์ `ClubPostsTab`)

Interactions: ดู User Flow — ทุกจุดที่เปลี่ยน filter/query ต้อง cancel debounce timer เดิมก่อนเสมอ (บทเรียนตรงจาก WYN-009's debounce-cancel gotcha)

States:
- Loading ครั้งแรก: `CircularProgressIndicator` กึ่งกลาง
- Loading เพิ่ม (pagination): spinner แถวท้ายลิสต์ (มิเรอร์ `ZokyOrderListScreen`)
- Empty แบบสัมบูรณ์ (filter="ทั้งหมด" + query ว่าง + ร้านไม่มีสินค้าเลยสักชิ้น): ไอคอน `Icons.inventory_2_outlined` ขนาด 56 (มิเรอร์ `SearchStateMessage`) + ข้อความ "ยังไม่มีสินค้าในร้านเลย เริ่มเพิ่มสินค้าชิ้นแรกกันเถอะ" + `FilledButton` "+ เพิ่มสินค้า" ใต้ข้อความ (ทำหน้าที่เดียวกับ FAB แต่เป็น CTA ในเนื้อหาเพื่อความชัดเจนตอน onboarding ครั้งแรก — ไม่ใช่การเพิ่ม action ใหม่ที่ขัดกับ FAB เดิม)
- Empty แบบ filter/ค้นหาแล้วไม่พบ (filter≠"ทั้งหมด" หรือมีคำค้น): `SearchStateMessage` ข้อความ "ไม่พบสินค้าที่ตรงกับตัวกรอง" หรือ "ไม่พบสินค้าสำหรับ \"query\"" **ไม่มีปุ่ม CTA** (มิเรอร์ `ZokyProductResultsTab`'s empty-result convention ที่ไม่มีปุ่มเพิ่มเติมเมื่อเป็นผลจากการกรอง/ค้นหา)
- Error (โหลดครั้งแรกล้มเหลว): ข้อความ error + `TextButton` "ลองใหม่" กึ่งกลาง (มิเรอร์ `ZokyProductResultsTab`'s error state)

Responsive Behavior: มือถือ portrait คอลัมน์เดียวเต็มความกว้างจอเสมอ (ตาม convention ทั้งโปรเจกต์ ไม่มี layout พิเศษสำหรับจอกว้าง/แนวนอนในรอบนี้)

Accessibility: filter chip แต่ละตัวมี label ตามข้อความอยู่แล้วจาก `ChoiceChip` (Material default accessible), ปุ่มล้างคำค้นมี `Semantics` label "ล้างคำค้นหา" (มิเรอร์ `ZokySearchScreen`), FAB มี `tooltip` "เพิ่มสินค้า" ทำหน้าที่ accessible label ด้วย (Material default)

Design Rules: ไม่มี Bottom Nav ใหม่ ไม่มี AppBar action เพิ่มเติมนอกเหนือจากที่ระบุ — สีตาม design-principles.md เดิมทั้งหมด

Handoff: `SellerRepository` เมธอดใหม่ `fetchProducts({required String storeId, ProductStatusFilter filter = ProductStatusFilter.all, String query = '', required int page})` คืน `List<Product>` (ILIKE เรียกตรงผ่าน `.ilike()` ไม่ผ่าน `.or()` string ตามที่ Product spec เตือน) — เพิ่ม `fetchCategories()` (reuse pattern เดียวกับ `ZokyRepository.fetchCategories()` แต่ duplicate เข้า `seller_app/` เพราะคนละ binary)

---

## Widget: `SellerProductListTile`

Purpose: หนึ่งแถวในลิสต์สินค้าของ `SellerProductListScreen`

Components: มิเรอร์โครง `OrderSummaryCard` (leading thumbnail 64x64 rounded + text column ขยาย + trailing marker) —
- Thumbnail: `product.imageUrls.first` (`ClipRRect` borderRadius 8, `Image.network`, `fit: BoxFit.cover`)
- แถวบน: ชื่อสินค้า (`titleSmall`, ellipsis 1 บรรทัด) ชิดซ้าย + `ProductActiveBadge` ชิดขวา (ดูด้านล่าง)
- แถวกลาง: ราคาปัจจุบัน (`titleSmall`, สี Primary, ตัวหนา, `thaiBahtLabel`) — ถ้ามี `originalPrice` ใส่ราคาก่อนลดขีดฆ่าสีเทาต่อท้าย (มิเรอร์ `ProductDetailScreen`'s price block)
- แถวล่าง: stock text — "เหลือ N ชิ้น" สีเทา หรือ "หมด" สีแดงถ้า `stock == 0` (มิเรอร์ `ProductDetailScreen`'s stock text เป๊ะ ไม่ประดิษฐ์ข้อความใหม่)

Interactions: ทั้งแถวเป็น tap target เดียว (`InkWell`) เปิด `SellerProductFormScreen` โหมดแก้ไข

Accessibility: `Semantics` label รวม "ชื่อสินค้า, ราคา บาท, สถานะกำลังขาย/ปิดการขาย, เหลือ N ชิ้น/หมด" (มิเรอร์ `OrderSummaryCard`'s รูปแบบ label รวม)

Handoff: ใช้ `Product` model (ดู Data Model ท้ายเอกสาร)

---

## Widget: `ProductActiveBadge` (ใหม่)

Purpose: badge สถานะ `is_active` — ต้องเป็น 2 สถานะเสมอ (ไม่ผูกกับ stock เพราะ active กับ stock=0 เป็นคนละมิติกัน สินค้า active แต่หมดสต็อกได้ปกติ)

Components: มิเรอร์ `OrderStatusBadge` เป๊ะ (สี+icon+ข้อความ pill เดียวกันเสมอ ไม่สื่อสารด้วยสีอย่างเดียว) —
- `is_active = true`: พื้นเขียวอ่อน (`Colors.green.shade100`/`shade800`) + `Icons.check_circle` + "กำลังขาย"
- `is_active = false`: พื้นเทา (`colorScheme.surfaceContainerHighest`/`onSurfaceVariant`) + `Icons.visibility_off` + "ปิดการขาย"

Accessibility: `Semantics` label "สถานะสินค้า: กำลังขาย/ปิดการขาย" (มิเรอร์ `OrderStatusBadge`)

Handoff: widget ใหม่ใน `seller_app/lib/features/product/presentation/widgets/product_active_badge.dart`

---

## Screen: `SellerProductFormScreen` (ใช้ร่วมกันทั้งสร้างและแก้ไข)

Purpose: สร้างสินค้าใหม่ หรือแก้ไขสินค้าเดิม (ทุกฟิลด์ยกเว้น stock) ในหน้าเดียว

**การตัดสินใจ Design**: ใช้ widget เดียว พารามิเตอร์ `existingProduct` (nullable) แทนที่จะแยกเป็น `CreateProductScreen`/`EditProductScreen` สองคลาส — มิเรอร์ pattern `ReviewFormSheet`'s `existingReview` ตรง ๆ (established convention เดียวกันในโปรเจกต์สำหรับฟอร์มสร้าง/แก้ไขเนื้อหาเดียวกัน) ไม่ต้อง duplicate โครง TextField/validation ทั้งชุดสองไฟล์

User Flow:
- **โหมดสร้าง** (`existingProduct == null`): มาจาก FAB หรือปุ่ม CTA ของ empty state → กรอกฟิลด์ทั้งหมดรวม stock เริ่มต้น → "สร้างสินค้า" → insert `products` (+ `product_variants` ถ้ามี) → `Navigator.pop(true)`
- **โหมดแก้ไข** (`existingProduct != null`): มาจากการแตะแถวสินค้า → ฟิลด์ทุกอันขึ้นค่าเดิม **ยกเว้น stock ที่ไม่มีช่องกรอกเลย** (มีการ์ด "สต็อกปัจจุบัน" + ปุ่ม "ปรับสต็อก" แทน) → "บันทึกการแก้ไข" → update `products` (+ diff `product_variants`) → `Navigator.pop(true)`

Components:
- `AppBar`: `leading` ปุ่มปิด (`Icons.close`, มิเรอร์ `CreateDropScreen`) + `title` "เพิ่มสินค้า"/"แก้ไขสินค้า" ตาม `_isEditing` + `actions` ปุ่ม `TextButton` "สร้างสินค้า"/"บันทึกการแก้ไข" (spinner 16x16 ระหว่าง submit มิเรอร์ `CreateDropScreen`'s "แชร์" ปุ่มเป๊ะ)
- **รูปภาพ**: แถว thumbnail แนวนอน (มิเรอร์ `CreateClubPostScreen._buildImageRow()` เป๊ะ — 80x80 rounded, ปุ่ม X ลบมุมขวาบน) + ปุ่ม `OutlinedButton.icon` "แนบรูปสินค้า" (`pickMultiImage`, จำกัด 10, disable เมื่อครบ) — **รูปแรกในลิสต์เสมอคือ thumbnail หลัก** สื่อสารด้วยข้อความกำกับเล็ก ๆ ใต้แถวรูป "รูปแรกจะเป็นรูปหน้าปกสินค้า" (ไม่มี drag-to-reorder ในรอบนี้ — ผู้ใช้ลบแล้วเพิ่มใหม่ตามลำดับที่ต้องการแทน เป็น known scope cut ที่ตั้งใจเพื่อไม่เพิ่มความซับซ้อนของ picker เกินจำเป็น)
- `TextField` ชื่อสินค้า (label "ชื่อสินค้า", `maxLength: 200`, บังคับ)
- `TextField` ราคา (label "ราคา", `keyboardType: number`, บังคับ, >= 0)
- `TextField` ราคาก่อนลด (label "ราคาก่อนลด (ไม่บังคับ)", `keyboardType: number`) — inline error ใต้ช่องถ้า < ราคาจริงตอน submit ("ราคาก่อนลดต้องมากกว่าหรือเท่ากับราคาจริง")
- `DropdownButtonFormField<Category>` หมวดหมู่ (label "หมวดหมู่") — โหลดผ่าน `FutureBuilder<List<Category>>` (มิเรอร์ `ZokyProductResultsTab._openFilterSheet()`'s pattern) — **โหมดสร้าง: บังคับเลือก** (submit disable จนกว่าจะเลือก) — **โหมดแก้ไข: ไม่บังคับ** (สินค้าเก่าที่ seed ผ่าน Studio บางรายการไม่มีหมวดหมู่ ไม่ควร block การบันทึกฟิลด์อื่นเพราะเรื่องนี้ — ตรงตาม Product spec ที่ระบุว่าบังคับเฉพาะ "ตอนสร้างสินค้าใหม่" เท่านั้น)
- `TextField` คำอธิบาย (multiline, ไม่บังคับ)
- `TextField` SKU (label "SKU (ไม่บังคับ)")
- **โหมดสร้างเท่านั้น**: `TextField` stock เริ่มต้น (label "จำนวนสินค้าเริ่มต้น", `keyboardType: number`, integer >= 0, default แสดง "0" เป็น placeholder ไม่ใช่ prefill เป็นค่า)
- **โหมดแก้ไขเท่านั้น**: การ์ด "สต็อกปัจจุบัน: N ชิ้น" (read-only, `bodyMedium`) + `TextButton` "ปรับสต็อก" เปิด `StockAdjustmentSheet` scope สินค้าทั้งชิ้น
- **Variant editor** (`ProductVariantEditor` — ดูด้านล่าง)
- `FilledButton` เต็มความกว้าง "สร้างสินค้า"/"บันทึกการแก้ไข" (ปุ่มหลักซ้ำกับ AppBar action เพื่อให้เอื้อมถึงง่ายด้วยนิ้วโป้งตาม design-principles.md's "Bottom-anchored primary action")
- **โหมดแก้ไขเท่านั้น**: `TextButton` สีแดงท้ายฟอร์ม — ข้อความ **"ลบสินค้า"** ถ้า `is_active == true` (เปิด confirm dialog แล้ว toggle เป็น `false`) หรือ **"เปิดขายอีกครั้ง"** ถ้า `is_active == false` (toggle เป็น `true` ตรง ๆ ไม่ต้อง confirm เพราะไม่ทำลายอะไร — มิเรอร์ `ReviewFormSheet`'s delete `TextButton` ตำแหน่ง/สไตล์ท้ายฟอร์มเป๊ะ)

Interactions: submit disable จนกว่าฟิลด์บังคับครบ (ชื่อ + ราคา + รูปอย่างน้อย 1 + หมวดหมู่ถ้าเป็นโหมดสร้าง) — validation ราคาก่อนลดเช็คตอน submit ไม่ real-time (กันกวนตอนพิมพ์ยังไม่ครบ)

States:
- Uploading รูปภาพระหว่าง submit: ปุ่ม submit เป็น spinner + ข้อความ "กำลังอัปโหลดรูปภาพ..." ใต้ปุ่ม (มิเรอร์ `_isSharing`/`_isCropping` spinner pattern ของ `CreateDropScreen`)
- Error submit: ข้อความ error สีแดงใต้ปุ่ม "สร้าง/บันทึกสินค้าไม่สำเร็จ ลองใหม่อีกครั้ง" (มิเรอร์ `CreateDropScreen`/`CreateStoreScreen` wording เป๊ะ)
- Field validation error: ข้อความสั้นสีแดงใต้ field ที่ผิด (ราคาก่อนลด, ชื่อเกิน 200 ตัวอักษร)

Responsive Behavior: `SingleChildScrollView` + keyboard-aware bottom padding (`MediaQuery.viewInsets.bottom`, มิเรอร์ `ReviewFormSheet`) กันฟอร์มยาวถูกคีย์บอร์ดบัง

Accessibility: พื้นที่แตะรูป "แนบรูปสินค้า" มี `Semantics` label ชัดเจน (มิเรอร์ `CreateDropScreen`'s image area label), ปุ่ม X ลบรูปแต่ละรูปต้องมี `Semantics` label "ลบรูปที่ N" (จุดนี้ pattern เดิมของ `CreateClubPostScreen` **ไม่มี** Semantics label ให้ปุ่ม X — เป็นช่องว่างที่สืบทอดมา แนะนำ Coding เพิ่มให้ครบในจุดใหม่นี้แม้จะ mirror โครงสร้าง visual เดิมก็ตาม เพราะการ mirror "หน้าตา/พฤติกรรม" ไม่รวมถึงการ mirror gap ที่ไม่ตั้งใจ) — ปุ่ม/field อื่นทั้งหมดมี label ผ่าน `InputDecoration.labelText` อัตโนมัติอยู่แล้ว

Design Rules: ไม่มีสีใหม่ ไม่มี layout ใหม่ — ทุก `TextField`/`DropdownButtonFormField` ใช้ Material 3 outlined style ค่าเริ่มต้นของธีมเดิม

Handoff: `SellerRepository` เมธอดใหม่ —
- `createProduct({required storeId, required name, required price, originalPrice, categoryId, description, sku, required initialStock, required List<Uint8List> images, required List<String> imageExtensions, required List<VariantInput> variants})` → insert `products`+`product_variants` (อัปโหลดรูปเข้า `product-images` bucket ก่อน insert แถว เพื่อไม่ชน constraint แบบเดียวกับที่ WYN-014 เจอปัญหา "อัปโหลดก่อน insert" มาแล้ว)
- `updateProduct({required productId, name, price, originalPrice, categoryId, description, sku, required List<String> imageUrls, required List<Uint8List> newImages, required List<String> newImageExtensions, required List<VariantInput> variants})` → update ทุกฟิลด์ยกเว้น stock/is_active, diff variant (insert ใหม่/update เดิม/hard-delete ที่ถูกเอาออก)
- `setProductActive(productId, bool isActive)` → RLS update ธรรมดา (ไม่ผ่าน RPC เพราะไม่ใช่ atomic cross-table)
- `fetchCategories()` (ใช้ร่วมกับ list screen's filter)

---

## Widget: `ProductVariantEditor`

Purpose: ส่วนหนึ่งของ `SellerProductFormScreen` ให้เพิ่ม/แก้/ลบ variant (สี/ขนาด) แบบ flat list ต่อ type ตรงตาม data model เดิมของ ZOKY-001 (ไม่ทำ combination matrix ใหม่)

Components:
- หัวข้อ "ตัวเลือกสินค้า (ไม่บังคับ)" + สอง `OutlinedButton.icon` เคียงกัน "+ เพิ่มสี" / "+ เพิ่มขนาด" (แต่ละปุ่มเพิ่มแถว variant เปล่าเข้ากลุ่ม type นั้น)
- แถวต่อ variant หนึ่งแถว: `TextField` ค่า (เช่น "แดง"/"M", บังคับถ้าจะเก็บแถวนี้) + `TextField` price delta (ไม่บังคับ, `keyboardType: number`) + ช่อง stock:
  - **โหมดสร้าง**: `TextField` stock เริ่มต้นของ variant นั้น (integer >= 0)
  - **โหมดแก้ไข**: ข้อความ read-only "สต็อก: N" + `IconButton` เล็ก (`Icons.tune`) เปิด `StockAdjustmentSheet` scope variant นั้นโดยเฉพาะ
  - `IconButton` ถังขยะท้ายแถวลบ variant ออก

Interactions/ยืนยัน:
- ลบ **variant แถวใหม่ที่ยังไม่เคยบันทึก** (ไม่มี `id` จริง): ลบออกจากลิสต์ทันที ไม่ต้อง confirm (แก้คืนได้ง่ายด้วยการกดเพิ่มใหม่ก่อนกด "บันทึก")
- ลบ **variant ที่มีอยู่แล้วจริงใน DB** (`existingProduct` ไม่ null และแถวนี้มี `id`): เปิด `confirmDeletePost(context, itemLabel: 'ตัวเลือกสินค้า')` **ใช้ dialog เดิมตรง ๆ ไม่ต้องสร้างใหม่** เพราะ variant hard-delete เป็นการลบถาวรจริงตามที่ Product spec ยืนยัน (`product_variants` ไม่มี FK ผูกกับ `cart_items`/`order_items` เลย) — ข้อความ "ลบแล้วไม่สามารถกู้คืนได้" ของ dialog เดิมตรงกับความจริง 100% ต่างจากกรณีลบสินค้าทั้งชิ้น (soft-delete) ที่ต้อง dialog ใหม่

States: ไม่มี validation บังคับ (variant ทั้งหมด optional) — ถ้าใส่ค่าแต่ไม่กรอกช่อง "ค่า" (variant_value) ให้ตัดแถวนั้นทิ้งเงียบ ๆ ตอน submit แทนการ error (ผู้ใช้กดเพิ่มแถวแล้วเปลี่ยนใจไม่กรอกก็ไม่ควรถูก block)

Accessibility: `IconButton` ถังขยะ/ปุ่มปรับสต็อกเล็กต้องมี `tooltip`/`Semantics` label ("ลบตัวเลือกนี้", "ปรับสต็อกของ [ค่า variant]")

Handoff: ส่ง `List<VariantInput>` (local form state, ไม่ persist จนกว่าจะกด submit) กลับให้ `SellerProductFormScreen` รวมส่งเข้า `createProduct`/`updateProduct`

---

## Screen: `StockAdjustmentSheet` (modal bottom sheet ใหม่)

Purpose: จุดเดียวที่ปรับ stock ได้จริงในทั้งแอป — ส่ง **delta** เท่านั้น ไม่มีทาง set ค่าสัมบูรณ์ (ตาม race-condition constraint ของ Product spec)

User Flow: เปิดจากปุ่ม "ปรับสต็อก" (ระดับสินค้า) หรือไอคอนปรับสต็อกต่อแถว variant ใน `SellerProductFormScreen` โหมดแก้ไข → เห็นสต็อกปัจจุบัน + ตัวปรับ delta (เริ่มที่ 0) → กด +/- (หรือพิมพ์ตัวเลขตรง) จนได้ delta ที่ต้องการ → กด "ยืนยัน" → เรียก RPC → สำเร็จ: อัปเดตตัวเลข "สต็อกปัจจุบัน" ในชีตทันที รีเซ็ต delta กลับเป็น 0 (ชีต**ไม่ปิดอัตโนมัติ**เพื่อให้ปรับซ้ำได้สะดวกถ้าต้องการ ต่างจาก `ReviewFormSheet` ที่ปิดทันทีเพราะเป็น one-shot action ส่วนการปรับสต็อกมักทำหลายครั้งติดกัน เช่น รับของเข้าคลังทีละล็อต) → ผู้ใช้กดปิดชีตเองเมื่อเสร็จ (ปุ่ม X มุมบนหรือลากลง)

Components:
- ข้อความ "สต็อกปัจจุบัน: N ชิ้น" (`titleMedium`)
- Delta stepper: `IconButton` "-" / ตัวเลข delta แสดงเครื่องหมาย (+3/−2/0) / `IconButton` "+" (มิเรอร์โครง `QuantityStepper` เป๊ะ ปรับความหมายจาก "จำนวนที่จะซื้อ" เป็น "จำนวนที่จะปรับ") — ปุ่ม "-" disable เมื่อ `สต็อกปัจจุบัน + delta` แตะ 0 (เป็น UX hint ฝั่ง client เท่านั้น ไม่ใช่ security boundary — RPC/CHECK constraint ฝั่ง server คือของจริงเสมอ)
- `FilledButton` "ยืนยันการปรับสต็อก" (disable เมื่อ `delta == 0`)

States:
- Submitting: ปุ่มยืนยัน disable + spinner
- สำเร็จ: `SnackBar` "ปรับสต็อกสำเร็จ" + อัปเดตตัวเลขในชีตทันที
- ล้มเหลวเพราะสต็อกไม่พอ (RPC ปฏิเสธ CHECK constraint): `SnackBar` **"สต็อกไม่พอ"** (ข้อความเฉพาะเจาะจง ไม่ใช่ Postgres error ดิบ — Coding ต้อง catch แล้วแปลความหมาย)
- ล้มเหลวเหตุอื่น (เครือข่าย ฯลฯ): `SnackBar` "ปรับสต็อกไม่สำเร็จ ลองใหม่อีกครั้ง" (generic เดียวกับ pattern ทั่วโปรเจกต์)

Responsive Behavior: `SafeArea` + `viewInsets.bottom` padding (มิเรอร์ `ReviewFormSheet`)

Accessibility: `Semantics` ประกาศค่าปัจจุบันรวม delta เช่น "สต็อกปัจจุบัน 12 ชิ้น จะปรับเป็น 15 ชิ้น" เมื่อ delta ≠ 0 (ช่วย screen reader เข้าใจผลลัพธ์ก่อนกดยืนยันจริง)

Design Rules: **ห้ามมีช่องกรอกตัวเลขสต็อกแบบสัมบูรณ์ที่ไหนในชีตนี้เด็ดขาด** — มีแต่ delta stepper เท่านั้น (บังคับใช้ requirement ที่สำคัญที่สุดของ SELLER-002)

Handoff: `SellerRepository.adjustProductStock(String productId, int delta)` / `adjustVariantStock(String variantId, int delta)` — ทั้งคู่เรียก RPC `adjust_product_stock`/`adjust_variant_stock` เท่านั้น (ห้ามมี raw `.update({'stock': ...})` เรียกตรงจาก Dart ที่ไหนเลยในทั้งแอป) โยน exception ชนิดที่แยกแยะได้ระหว่าง "สต็อกไม่พอ" กับ error อื่น ๆ ให้ UI เลือกข้อความถูกจุด

---

## Dialog: soft-delete confirm ("ลบสินค้า" ที่แท้จริงคือปิดการขาย)

**เหตุผลที่ต้องสร้างฟังก์ชันใหม่แทนการ reuse `confirmDeletePost` ตรง ๆ**: `confirmDeletePost`'s body ข้อความคงที่คือ "ลบแล้วไม่สามารถกู้คืนได้" — ประโยคนี้ **เท็จ** สำหรับ SELLER-002 เพราะเป็น soft-delete ที่กู้คืนได้จริงผ่านตัวกรอง "ปิดการขาย" การ reuse ตรง ๆ จะสื่อสารข้อมูลผิดกับ seller โดยตรง (ต่างจากปุ่มลบ variant ด้านบนที่ reuse ได้เพราะเป็นความจริง 100%)

Components: ฟังก์ชันใหม่ `confirmHideProduct(BuildContext context, {required String productName})` โครง `AlertDialog` เดียวกับ `confirmDeletePost` เป๊ะ (สไตล์/ปุ่มเหมือนกัน) แต่เปลี่ยนเนื้อหา:
- Title: "ลบสินค้า \"$productName\"?" (คงคำว่า "ลบ" ตามชื่อปุ่มที่ Product spec กำหนดไว้ตรง ๆ)
- Body: **"สินค้านี้จะถูกซ่อนจากลูกค้าทันที ประวัติคำสั่งซื้อเดิมไม่ได้รับผลกระทบ กู้คืนได้ภายหลังผ่านตัวกรอง 'ปิดการขาย' ในรายการสินค้า"** (ข้อความตรงตาม Product spec เป๊ะ ไม่ตัดทอน)
- Actions: `TextButton` "ยกเลิก" / `TextButton` "ลบสินค้า" (คืนค่า `true`/`false` แบบเดียวกับ `confirmDeletePost`)

Handoff: ฟังก์ชันใหม่ที่ `seller_app/lib/core/widgets/confirm_hide_product_dialog.dart` — เรียกจาก `SellerProductFormScreen`'s "ลบสินค้า" `TextButton` เมื่อ `is_active == true` เท่านั้น (กรณี "เปิดขายอีกครั้ง" ไม่ต้องผ่าน dialog นี้เลย — toggle ตรง + `SnackBar` "เปิดขายสินค้านี้แล้ว")

---

## Data Model (ใหม่ ใน `seller_app/`)

มิเรอร์ pattern การ duplicate class name เดิมจาก SELLER-001 (`Store` model) — คนละ Flutter binary จาก `app/` จึงต้อง duplicate จริง ไม่ share package:

- `seller_app/lib/features/product/data/product.dart` — `Product` (duplicate โครงจาก `app/lib/features/zoky/data/product.dart` เพิ่ม 2 ฟิลด์ใหม่: `bool isActive`, `String? sku`)
- `seller_app/lib/features/product/data/product_variant.dart` — `ProductVariant`/`VariantType` (duplicate ตรงจาก `app/`'s เดิม ไม่มีฟิลด์เพิ่ม)
- `seller_app/lib/features/product/data/category.dart` — `Category` (duplicate ตรง)

---

## Responsive Behavior (ภาพรวม)

ทุกหน้าจอของ SELLER-002 เป็น mobile-first คอลัมน์เดียวเต็มความกว้างจอ ไม่มี layout พิเศษสำหรับแท็บเล็ต/แนวนอนในรอบนี้ (สอดคล้องกับทุก task ก่อนหน้าในโปรเจกต์) ฟอร์มทุกหน้ารองรับ dynamic type (ขยายขนาดตัวอักษรระบบ) ผ่าน `Theme.of(context).textTheme` ที่ใช้อยู่แล้วทั้งโปรเจกต์ ไม่ fix ขนาดตัวอักษรด้วยพิกเซลตายตัวยกเว้นจุดที่ระบุไว้ชัดเจนแล้ว (เช่น badge เล็ก 12px ที่มิเรอร์ `OrderStatusBadge` เดิม)

## Accessibility (ภาพรวม)

- Contrast ratio ตาม design-principles.md เดิม (AA ขั้นต่ำ) — สีเขียว/เทา/แดงของ `ProductActiveBadge`/stock text ใช้ shade เดียวกับที่ `OrderStatusBadge`/`ProductDetailScreen` ผ่านมาตรฐานนี้แล้ว
- ทุก interactive element มี label ที่ screen reader อ่านได้ (ระบุจุดที่ต้องเพิ่มใหม่ในหัวข้อ Accessibility ของแต่ละ Screen ด้านบน โดยเฉพาะปุ่ม X ลบรูปที่เป็นช่องว่างสืบทอดมาจาก `CreateClubPostScreen`)
- ไม่มีจุดไหนสื่อสารสถานะด้วยสีอย่างเดียว (badge/stock text ทุกจุดมี icon หรือข้อความกำกับเสมอ)

## เตือน Coding (จาก Product spec's Risks — ย้ำจุดที่กระทบ UI/UX โดยตรง)

1. **ห้ามมีช่องกรอก stock แบบสัมบูรณ์ที่ไหนเลยนอกจากตอนสร้างสินค้าใหม่** (ที่ยังไม่มี concurrent access ให้ race) — ทุกจุดปรับ stock ของสินค้า/variant ที่มีอยู่แล้วต้องผ่าน `StockAdjustmentSheet`'s delta stepper เท่านั้น
2. **RLS insert/update policy ของ `products`/`product_variants` ต้องมีทั้ง `using`+`with check`** (บทเรียนตรงจาก ZOKY-004's Critical gap) — ไม่ใช่แค่ UI concern แต่ QA จะตรวจจุดนี้เป็นพิเศษ Design ระบุไว้ที่นี่เพื่อให้ Coding ไม่มองข้าม
3. **หมวดหมู่บังคับเฉพาะโหมดสร้าง ไม่บังคับโหมดแก้ไข** — อย่าทำให้สินค้าเก่าที่ seed ผ่าน Studio (ไม่มีหมวดหมู่) แก้ไขฟิลด์อื่นไม่ได้เพราะ validation หมวดหมู่ที่เข้มเกินจำเป็น
4. **ปุ่ม "ลบสินค้า"/"เปิดขายอีกครั้ง" เป็นกลไกเดียวกัน (`is_active` toggle)** ไม่ใช่สองระบบแยกกัน — ข้อความ/dialog เปลี่ยนตามสถานะปัจจุบันเท่านั้น
5. **variant hard-delete ≠ product soft-delete** — ใช้ dialog คนละตัวกันตามที่ระบุไว้ชัดเจนข้างต้น อย่าใช้ `confirmHideProduct` กับ variant หรือ `confirmDeletePost` กับสินค้าทั้งชิ้น
6. เขียน regression test ครอบคลุม: 4 tab อื่นของ `SellerHomeShell` ยังทำงานปกติ, filter/search scope เฉพาะร้านตัวเอง (พิสูจน์ด้วย 2 ร้านจำลอง), stock adjustment ไม่ยอมให้ติดลบ, category ไม่บังคับตอนแก้ไข, variant delete ถูก dialog ต่างกันตามที่ระบุ

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement: (1) `SellerProductListScreen` + `SellerProductListTile` + `ProductActiveBadge` (2) `SellerProductFormScreen` (shared create/edit) + `ProductVariantEditor` (3) `StockAdjustmentSheet` (4) `confirmHideProduct` dialog ใหม่ (5) Data model `Product`/`ProductVariant`/`Category` ใหม่ใน `seller_app/` (6) `SellerRepository` เมธอดใหม่ทั้งหมดที่ระบุไว้ในแต่ละ Screen's Handoff (7) `SellerHomeShell`'s tab index 1 เปลี่ยนจาก `SellerComingSoonScreen(label: 'สินค้า')` เป็น `SellerProductListScreen` จริง — ดู Product spec `.wyn/tasks/backlog/SELLER-002-product-management.md` สำหรับ Database/RLS/RPC schema, Acceptance Criteria, และ Risks ฉบับเต็ม (โดยเฉพาะ RLS ownership pattern และ atomic stock RPC ที่เป็นหัวใจความปลอดภัยของ task นี้) — เมื่อ Coding/QA เสร็จให้ merge เข้า `main` ทันทีตามที่ Founder อนุญาตให้ทำงานต่อเนื่องอัตโนมัติ (DECISIONS.md 2026-08-14) แล้วรายงานความคืบหน้ากลับเป็น %
