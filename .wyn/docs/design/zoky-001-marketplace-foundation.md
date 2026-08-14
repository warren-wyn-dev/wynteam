# Design Spec — ZOKY-001: Marketplace Foundation

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok/Shopee/Lazada/TikTok Shop โดยตรง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/ZOKY-001-marketplace-foundation.md`, `.wyn/docs/product/zoky-platform-roadmap.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `ClubPostImages`/`_ClubPostImagesState`'s `PageView.builder` carousel (WYN-014), `PopGridTile`/`DropGridTile` grid pattern (WYN-013), `HomeFeedScreen._buildSearchBar()`'s tap-to-navigate placeholder (WYN-007), `ExploreClubsScreen`'s `ChoiceChip` category filter row + `ClubDiscoveryCard` full-width row (WYN-015), `RootShell`'s `NavigationBar`/`IndexedStack` (WYN-007)

## ทิศทางภาพรวม: Browse-only รอบนี้ ต่อยอด pattern เดิมทุกจุด

ZOKY-001 เป็น task แรกของสาย ZOKY Marketplace — ยังไม่มี Cart/Checkout/Order ทำงานจริง (ผูกที่ ZOKY-003) จึงเน้นออกแบบเพื่อ "เรียกดู" ให้ครบและลื่นไหลก่อน ปุ่มที่ยังไม่ทำงานจริง (Add to Cart/Buy Now/Follow Store) ต้อง**แสดงผลแล้ว** เพื่อให้ Founder เห็นภาพรวมได้เต็มรูปแบบ และไม่ต้องแก้ layout อีกรอบตอน ZOKY-003 มาผูก logic จริง — ไม่มีหน้าจอไหนใน ZOKY-001 เป็นโครงสร้างใหม่ทั้งหมด ทุกจุดต่อยอดจาก component ที่มีอยู่แล้ว

---

## Screen 0: Bottom Nav tab ที่ 5 "ZOKY"

Components: เพิ่ม `NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'ZOKY')` ต่อจาก Home/Drop/Pop/Profile เดิมใน `RootShell` (ตำแหน่งที่ 5, index 4) — **ห้ามเปลี่ยนลำดับ/icon/label ของ 4 tab เดิมแม้แต่จุดเดียว**

เหตุผลเลือก `Icons.storefront_outlined`: สื่อความหมาย "ร้านค้า/Marketplace" ตรงตัวในภาษา Material Icons standard set (ไม่ต้องพึ่ง custom asset ใหม่ ตรงตาม convention เดิมของ 4 tab ที่ใช้ Material Icons ทั้งหมด) และไม่ซ้ำ/ไม่คล้าย icon ของ 4 tab เดิม (`home`/`grid_view`/`play_circle`/`person`)

`IndexedStack` เก็บ state เดิมของ ZOKY tab ไว้เหมือน 4 tab อื่น (ไม่ rebuild ทุกครั้งที่สลับกลับมา) — ไม่ต้องมี "reload-on-visit" key แบบ Profile tab เพราะ ZOKY Home ไม่มีข้อมูลที่เปลี่ยนจาก action ในแท็บอื่น (ต่างจาก Profile ที่ follower count เปลี่ยนได้จาก Drop/Pop)

---

## Screen 1: `ZokyHomeScreen`

Purpose: จุดเข้า Marketplace หลัก ให้เรียกดู Category/สินค้าแนะนำ/ร้านค้าแนะนำได้

Components (บนลงล่าง):
- **Top row**: Search bar placeholder (มิเรอร์ `HomeFeedScreen._buildSearchBar()` เป๊ะ — `Material` + `InkWell` ทรงยาแคปซูล, icon แว่นขยาย + ข้อความ "ค้นหาสินค้า/ร้านค้า" แทนที่ "ค้นหา" เดิม) แตะแล้วเปิด `SnackBar` "เร็ว ๆ นี้" รอบนี้ (ของจริงผูกที่ ZOKY-002 เหมือนที่ Home Search ผูกที่ WYN-009) — ปุ่ม Cart icon (`Icons.shopping_cart_outlined`) และปุ่ม Orders icon (`Icons.receipt_long_outlined`) ชิดขวา ทั้งสองแตะแล้วแสดง `SnackBar` "เร็ว ๆ นี้" เหมือนกัน (ผูกจริงที่ ZOKY-003)
- **Category row**: แถว `ChoiceChip` แนวนอน scroll ได้ มิเรอร์ `ExploreClubsScreen._buildCategoryChips()` เป๊ะ (ไม่มี "ทั้งหมด" chip เพราะ ZOKY Home ไม่ filter หน้ารวม — แตะ category แล้วพาไปหน้า Search ผลกรอง category นั้น แต่ Search ยังไม่ทำงานจริงรอบนี้ จึงแตะแล้วแสดง `SnackBar` "เร็ว ๆ นี้" เหมือนกัน)
- **Banner section**: การ์ดมุมมนกว้างเต็มจอ height คงที่ 140px (เหมือน `ClubPage`'s cover pattern จาก WYN-014) พื้นหลังสีตัน (ไม่มีรูปจริงรอบนี้ — เป็น placeholder เนื้อหาคงที่ "โปรโมชั่นเร็ว ๆ นี้" ไม่ต้องมี carousel เพราะยังไม่มี Banner data model จริง)
- **"แนะนำสำหรับคุณ" section**: label หัวข้อ + `Text` รอง "เร็ว ๆ นี้" แทนรายการสินค้า (ไม่มี Product grid จริงเพราะยังไม่มี behavioral signal — ตรงตาม Product spec's Risks) — **ไม่ซ่อน section นี้ไปเลย** (ต่างจาก "Club ของฉัน" ของ WYN-015 ที่ซ่อนเมื่อว่าง) เพราะรอบนี้ทุกคนจะว่างเหมือนกันหมด การซ่อนทั้ง section จะทำให้ดูเหมือนฟีเจอร์หายไปแทนที่จะสื่อว่า "กำลังจะมา"
- **"ขายดี" (Best Selling) section**: เหมือน "แนะนำสำหรับคุณ" — label + "เร็ว ๆ นี้" placeholder (ไม่มี Order data ให้ rank จริงจนกว่าจะถึง ZOKY-003)
- **"สินค้าใหม่" (New Products) section**: label หัวข้อ + `ListView` แนวนอน ของ `ProductMiniCard` (ใหม่ — มิเรอร์ `ClubMiniCard` ของ WYN-014 ทุกประการ: ขนาด/สัดส่วนเดียวกัน แต่แสดงรูปสินค้า+ชื่อ+ราคาแทนไอคอน Club+ชื่อ+จำนวนสมาชิก) เรียงตาม `created_at` ใหม่ไปเก่า จำกัด 10 ชิ้น — Empty state ถ้ายังไม่มีสินค้าเลย: `Text` "ยังไม่มีสินค้าในระบบ" กึ่งกลาง (Marketplace เพิ่งเริ่ม ไม่มี Seller เขียนข้อมูลเองได้จนกว่าจะถึง Phase 4 ตามที่ Product ระบุ)
- **"ร้านค้าแนะนำ" (Recommended Stores) section**: label หัวข้อ + `ListView` แนวนอน ของ `StoreMiniCard` (ใหม่ — มิเรอร์ `ClubMiniCard` โครงเดียวกัน: โลโก้วงกลม + ชื่อร้าน + จำนวนสินค้า) — รอบนี้เรียงตาม `created_at` เหมือนกัน (ไม่มี rating/sales จริงให้ rank) Empty state เดียวกับ New Products
- **Product Grid หลัก**: label "สินค้าทั้งหมด" + `GridView` 2 คอลัมน์ ของ `ProductGridTile` (ใหม่ — มิเรอร์โครงของ `PopGridTile`/`DropGridTile`: รูปสินค้าเต็ม tile + ราคาซ้อนมุมล่างซ้ายบนพื้นทึบ (ไม่ใช้ gradient/blur ตามกติกาห้าม Liquid Glass) — ต่างจาก `PopGridTile`/`DropGridTile` ตรงที่ต้องมีราคาแสดงเสมอเพราะเป็น Marketplace ไม่ใช่ content feed) infinite-scroll pagination (มิเรอร์ debounce/pagination pattern เดิมของ `SearchDropResultsTab`)

Interaction: แตะการ์ดสินค้าใด ๆ (New Products/Grid) → เปิด `ProductDetailScreen` — แตะการ์ดร้านค้า → เปิด `StoreScreen`

Accessibility: ทุกการ์ด `Semantics` label รวม "ชื่อสินค้า, ราคา บาท" หรือ "ชื่อร้าน, จำนวนสินค้า ชิ้น" ตาม pattern เดิมของ `ClubDiscoveryCard`

---

## Screen 2: `ProductDetailScreen`

Purpose: ดูรายละเอียดสินค้าครบก่อนตัดสินใจซื้อ (ซื้อจริงยังทำไม่ได้รอบนี้)

Components:
- AppBar โปร่งใสซ้อนบนรูป (มิเรอร์ pattern ของ `DropDetailScreen`/`ClubPage`'s cover) หรือ AppBar ทึบธรรมดาก็ได้ถ้ารูปมีหลายอัตราส่วนไม่แน่นอน — เลือกใช้ **AppBar ทึบธรรมดา** เพื่อความสม่ำเสมอกับหน้าอื่นทั้งหมดในแอป (ไม่มีหน้าไหนใน WYN Social ใช้ AppBar โปร่งใสซ้อนรูปเลย ไม่ควรเริ่มทำแบบใหม่ที่นี่)
- **Image carousel**: มิเรอร์ `ClubPostImages`/`_ClubPostImagesState` เป๊ะ (`PageView.builder` + dot indicator ด้านล่าง) สัดส่วน 1:1 (เหมือน Drop) เพราะสินค้าส่วนใหญ่ถ่ายเป็นสี่เหลี่ยมจัตุรัสได้ชัดเจนกว่า
- **Price block**: ราคาปัจจุบันตัวใหญ่ตัวหนา สี Primary Blue, ถ้ามี `originalPrice` แสดงเป็น `Text` ขีดฆ่าสีเทาข้าง ๆ + ป้าย % ส่วนลด (Chip สีแดงอ่อนตาม convention "ราคา/ส่วนลด" มาตรฐาน ไม่ใช่ primary blue เพราะเป็น status สื่อความหมายพิเศษต่างหาก)
- Product Name, Stock (ข้อความเล็กสีเทา "เหลือ N ชิ้น" หรือ "หมด" สีแดงถ้า 0)
- **Variants** (ถ้ามี): `ChoiceChip` แถวสำหรับแต่ละ `variant_type` (เช่น สี → chip สี, ไซส์ → chip ตัวอักษร) เลือกได้ 1 ค่าต่อ type แต่**ไม่กระทบราคา/สต๊อกที่แสดงจริงรอบนี้** (preview state เท่านั้น ตาม Product spec's Risks)
- Description (ข้อความเต็ม ไม่ตัด ellipsis เหมือน caption ของ Drop)
- Rating summary (ดาว + ตัวเลขเฉลี่ย + จำนวนรีวิว) — ถ้ายังไม่มีรีวิวเลย แสดง "ยังไม่มีรีวิว" แทนดาว 0 ดวง (Reviews จริงมาที่ ZOKY-004 — รอบนี้เป็น UI ที่รองรับไว้ก่อนเฉย ๆ จะว่างเปล่าเสมอ)
- **Store info card**: แถวเดียวมิเรอร์ `ClubDiscoveryCard` โครง (โลโก้วงกลม + ชื่อร้าน + rating เล็ก) ทั้งแถวเป็น tap target เดียวเปิด `StoreScreen`
- **Bottom action bar**: คงที่ด้านล่างจอ (เหมือน `Bottom-anchored primary action` ตาม design-principles.md) มี 2 ปุ่มเคียงกัน: "เพิ่มลงตะกร้า" (Secondary/outlined button) + "ซื้อเลย" (Primary button เต็ม) — ทั้งคู่แตะแล้วแสดง `SnackBar` "เร็ว ๆ นี้ — ระบบตะกร้าอยู่ระหว่างพัฒนา" รอบนี้ ไม่ disable เป็นสีเทา (เพราะปุ่มไม่ได้ "ใช้ไม่ได้ถาวร" แค่ยังไม่เปิดใช้งาน — สื่อสารด้วยข้อความชัดเจนกว่าสีจาง ตรงตามกติกา accessibility "ไม่สื่อสารข้อมูลด้วยสีอย่างเดียว")

Interaction: แตะ Store info card → `StoreScreen`

Accessibility: ปุ่มเพิ่มลงตะกร้า/ซื้อเลย มี `Semantics` label ชัดเจนแม้จะยังไม่ทำงานจริง (ไม่ใช่ปุ่มที่ screen reader ข้ามไปเฉย ๆ)

---

## Screen 3: `StoreScreen`

Purpose: ดูภาพรวมร้านค้า สินค้าทั้งหมดของร้าน

Components:
- Header: โลโก้วงกลมใหญ่ (มิเรอร์ `ViewProfileScreen`'s avatar header ขนาด/ตำแหน่ง) + ชื่อร้าน + rating + "Followers: N" (placeholder ตัวเลข 0 เสมอรอบนี้) + "สินค้า: N ชิ้น" + Description
- **ปุ่ม "ติดตามร้าน" (Follow Store)**: `OutlinedButton` เต็มความกว้าง ใต้ header (มิเรอร์ตำแหน่ง/ขนาดปุ่ม Follow ของ `ViewProfileScreen` เป๊ะ) แตะแล้วแสดง `SnackBar` "เร็ว ๆ นี้" รอบนี้ (ต้อง data model ใหม่ตามที่ Product ระบุใน Risks — **ไม่ทำ toggle state สลับ Following/ติดตามแล้ว เพราะไม่มี data จริงให้ persist**)
- **ปุ่ม "แชทกับร้านค้า" (Chat Seller)**: **ไม่แสดงเลยรอบนี้** ตามที่ Product ระบุใน Risks ("defer ทั้งหมด ซ่อนไปเลยไม่ต้องแสดง placeholder") — ต่างจาก Follow Store/Add to Cart ตรงที่ไม่มีปุ่ม visual-only เลย เพราะยังไม่มี concept "แชท" ในแอปเลยแม้แต่จุดเดียวให้สื่อสารว่า "เร็ว ๆ นี้" อย่างมีความหมาย
- **TabBar 2 แท็บ**: "สินค้าทั้งหมด" (Product grid, มิเรอร์ `ProductGridTile` เดียวกับ ZOKY Home) / "รีวิว" (มิเรอร์โครง comment list ของ `ClubPostDetailScreen`'s comment thread — ว่างเปล่าเสมอรอบนี้ แสดง "ยังไม่มีรีวิว") — **ไม่มีแท็บ "ขายดี" แยก** เพราะซ้ำซ้อนกับ "สินค้าทั้งหมด" ที่ยังไม่มี sales data ให้ sort ต่างกันจริงรอบนี้ (ต่างจาก ZOKY Home ที่มี section "ขายดี" เป็น placeholder เพราะเป็นหน้ารวมภาพรวมทั้ง Marketplace ที่ต้องมีหัวข้อครบตาม spec แต่ Store page เป็นข้อมูลของร้านเดียว TabBar ที่มีแท็บว่างเปล่าซ้ำ ๆ 2 อันจะดูรกเกินจำเป็น)

Interaction: แตะสินค้าใน grid → `ProductDetailScreen`

Accessibility: ปุ่ม "ติดตามร้าน" มี `Semantics` label "ติดตามร้าน [ชื่อร้าน]"

---

## Design Rules

- ทุกจุดของ ZOKY-001 reuse widget/pattern เดิม 100% ที่ทำได้ (carousel, grid tile shape, search-bar-placeholder, category chip, mini-card): จุดใหม่ที่ต้องสร้างจริงมีแค่ `ProductMiniCard`, `StoreMiniCard`, `ProductGridTile` (ทั้งสามมิเรอร์โครงจาก `ClubMiniCard`/`PopGridTile` ตรง ๆ ปรับแค่เนื้อหาข้อมูลที่แสดง)
- ปุ่มที่ยังไม่ทำงานจริง (Cart/Orders/Search/Add to Cart/ซื้อเลย/ติดตามร้าน) **ต้องแสดงผลเสมอ ไม่ใช่ซ่อน** และสื่อสารด้วยข้อความ "เร็ว ๆ นี้" ที่ชัดเจนเมื่อแตะ ยกเว้น "แชทกับร้านค้า" ที่ไม่มีปุ่มเลยตามเหตุผลที่ระบุไว้ใน Screen 3
- สี/ตัวอักษร/spacing ทั้งหมดตาม `design-principles.md` เดิม ไม่มีทิศทางใหม่ — ราคาสินค้าใช้สี Primary Blue เดียวกับปุ่มหลัก ไม่ใช้สีพิเศษแยกสำหรับ "ราคา" (ยกเว้นป้ายส่วนลด/ราคาก่อนลดที่ใช้ convention สีแดง/เทาตามมาตรฐาน e-commerce ทั่วไปที่ผู้ใช้คุ้นเคยอยู่แล้ว ไม่ถือเป็นการ "ลอก Layout" เพราะเป็น convention สื่อความหมาย ไม่ใช่โครงสร้างหน้าจอ)
- ไม่มีหน้าจอไหนใน ZOKY-001 เป็น Bottom Nav tab ใหม่นอกจาก tab ZOKY เอง (Product Detail/Store เข้าถึงผ่านการแตะการ์ดเสมอ เหมือน pattern ClubPage ของ WYN-014)

## Handoff: AI Coding —

1. **Navigation**: เพิ่ม `NavigationDestination` ตัวที่ 5 ใน `RootShell` ตามที่ระบุใน Screen 0 — เพิ่ม `ZokyHomeScreen` เป็น tab ที่ 5 ใน `IndexedStack` — **ห้ามแก้ 4 tab เดิมแม้แต่บรรทัดเดียว**
2. **Backend**: สร้างตาราง `categories`/`stores`/`products`/`product_variants` ตามที่ Product spec ระบุ RLS select-all-authenticated เหมือน `clubs`/`drops`/`pops` ไม่มี insert/update/delete policy ให้ client เลยรอบนี้ (Seller เขียนเองไม่ได้จนกว่าจะถึง Phase 4) — seed ข้อมูลตัวอย่างผ่าน Supabase Studio/migration เพื่อทดสอบ UI
3. Widget ใหม่ที่ต้องสร้าง: `ProductMiniCard`, `StoreMiniCard`, `ProductGridTile` (มิเรอร์ `ClubMiniCard`/`PopGridTile` ตรง ๆ), `ZokyHomeScreen`, `ProductDetailScreen`, `StoreScreen`
4. ปุ่มที่ยังไม่ทำงานจริงทั้งหมด (Search bar/Cart/Orders/Category chip tap/Add to Cart/ซื้อเลย/ติดตามร้าน) ใช้ `SnackBar` ข้อความ "เร็ว ๆ นี้" เดียวกัน (constant string ใช้ร่วมกัน ไม่พิมพ์ซ้ำหลายที่ต่างข้อความกัน)
5. เขียน regression test ครอบคลุม: Bottom Nav 5 tab เรียงถูกต้อง + 4 tab เดิมยังทำงานปกติไม่มี regression, ZOKY Home แสดงทุก section ตาม spec, Empty state ของ New Products/Recommended Stores เมื่อไม่มีข้อมูล, แตะการ์ดสินค้า/ร้านค้าเปิดหน้าถูกต้อง, ปุ่ม placeholder ทั้งหมดกดแล้วไม่ crash
6. QA & Security ต้องตรวจ RLS ของตารางใหม่ทั้ง 4 ไม่มี insert/update/delete policy ใด ๆ เปิดให้ client เลย (เพราะยังไม่มี Seller workflow ตัดสินใจสิทธิ์), regression กับ Bottom Nav 4 tab เดิมทั้งหมด (Home/Drop/Pop/Profile ต้องทำงานเหมือนเดิมทุกประการ)

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 0-3 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/ZOKY-001-marketplace-foundation.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
