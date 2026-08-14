# Product Task — ZOKY-001

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS)

Feature: ZOKY Marketplace Foundation — ZOKY Bottom Nav tab, ZOKY Home (browse), Product Detail (view), Store page (view)

Goal: เปิดทางให้ผู้ใช้ WYN เข้าสู่ ZOKY Marketplace ได้จาก Bottom Navigation เดิม แล้วเรียกดูสินค้า/ร้านค้าได้จริง (Browse-only รอบนี้ — ยังไม่มี Cart/Checkout/Order ทำงานจริง ผูกกับ ZOKY-003) เป็นรากฐานให้ ZOKY-002 (Search), ZOKY-003 (Cart/Checkout/Order), ZOKY-004 (Review) ต่อยอดได้

Target User: ผู้ใช้ WYN Social เดิมที่อยากซื้อสินค้าผ่านแอปเดียวกันโดยไม่ต้องออกจากแอป — ตาม Founder's WYN PLATFORM master prompt (2026-08-14) ที่ขยาย WYN จาก Social app เดียวเป็น WYN Platform (ดู `.wyn/docs/product/zoky-platform-roadmap.md`)

Problem: WYN ตอนนี้เป็น Social app ล้วน (Home/Drop/Pop/Club/Profile/Search/Notification) ไม่มีทางซื้อ-ขายสินค้าในระบบเลย Founder ต้องการเพิ่ม ZOKY Marketplace เป็นส่วนที่สองของ WYN Platform โดยไม่แตะ/ทำลายฟีเจอร์ Social เดิมแม้แต่จุดเดียว

Requirements:

**Navigation**
- เพิ่ม Bottom Navigation tab ที่ 5 ชื่อ "ZOKY" ต่อจาก Home/Drop/Pop/Profile เดิมใน `RootShell` — **ห้ามเปลี่ยนลำดับ/ลบ/ย้าย tab เดิมทั้ง 4 อัน** (ตรงตามกฎ "ห้ามเปลี่ยน Navigation เดิมโดยไม่จำเป็น" ของ Founder)

**ZOKY Home**
- หน้า Marketplace Home ใหม่ (`ZokyHomeScreen`) ประกอบด้วย: Search Bar (placeholder รอบนี้ — ของจริงผูกกับ ZOKY-002 เหมือนที่ Home Search bar ของ WYN Social เป็น placeholder จนกว่าจะถึง WYN-009), ปุ่ม Cart (placeholder — เชื่อมจริงที่ ZOKY-003), ปุ่ม Orders (placeholder — เชื่อมจริงที่ ZOKY-003), Product Categories (แถว chip/grid หมวดหมู่), Banner/Promotions (placeholder เนื้อหาคงที่ — ไม่มีระบบจัดการ Banner จริงจนกว่าจะถึง WYN Admin), Recommended Products, Best Selling Products, New Products (3 section รายการสินค้า), Recommended Stores, Product Grid หลัก
- **"Recommended"/"Best Selling" รอบแรกนี้**: เหมือนที่ "แนะนำสำหรับคุณ" ของ Explore Clubs (WYN-015) ถูก defer เพราะไม่มี behavioral signal — Best Selling เรียงตามยอดขายจริงได้ (มี Order data ให้นับ) แต่ Order ยังไม่มีในระบบจนกว่า ZOKY-003 จะเสร็จ ดังนั้นรอบนี้ **Best Selling/Recommended จะว่างเปล่าหรือใช้ placeholder data ชั่วคราว** จนกว่าจะมี Order จริง — New Products ทำได้จริงทันที (เรียงตาม `created_at`)

**Product Detail**
- หน้า `ProductDetailScreen` แสดง: Product Images (carousel, มิเรอร์ pattern รูปหลายรูปของ `ClubPostCard` จาก WYN-014), Product Name, Price, Original Price + Discount (ถ้ามี), Stock, Product Variants (Color/Size — เลือกได้แต่ยังไม่ผูกกับ Cart จริงรอบนี้), Description, Rating, Reviews (แสดงถ้ามี — ระบบ Review จริงมาที่ ZOKY-004), Store Information (การ์ดสรุปร้านค้า แตะไป Store page)
- ปุ่ม "Add to Cart"/"Buy Now" **แสดงผลตาม Design แต่ยังไม่ทำงานจริงรอบนี้** (disabled หรือ SnackBar "เร็ว ๆ นี้" — มิเรอร์ pattern placeholder ของ Search bar ใน WYN-007 ตอนที่ WYN-009 ยังไม่เสร็จ) ผูกจริงที่ ZOKY-003

**Store**
- หน้า `StoreScreen` แสดง: Store Logo, Store Name, Store Rating, Followers count (placeholder ตัวเลข — ระบบ Follow Store จริงเป็น open question ที่ Design ต้องตัดสินใจ ดู Risks), Product Count, Store Description, Products (grid), Best Sellers, Reviews
- ปุ่ม "Follow Store" **แสดงผลตาม Design แต่ยังไม่ทำงานจริงรอบนี้** (ดู Risks — ต้องออกแบบ data model ใหม่ก่อน)
- ปุ่ม "Chat Seller" **defer ทั้งหมดรอบนี้** — ไม่มีระบบ chat ในโปรเจกต์นี้เลย เป็นงานคนละขนาด (ดู Risks) ซ่อนปุ่มนี้ไปเลยรอบนี้ไม่ต้องแสดงเป็น placeholder ก็ได้ (ต่างจาก Add to Cart/Follow Store ที่ยังต้องโชว์ตำแหน่งไว้ตาม Design เพราะจะผูกจริงในรอบถัดไปที่ใกล้กว่า)

**Backend (Supabase)**
- ตารางใหม่เข้า `supabase/schema.sql` เดิม (ไม่แยก database): `categories` (id, name, ตายตัวคล้าย `clubCategories` แต่เป็น commerce category), `stores` (id, owner_id → profiles, name, description, logo_url, banner_url, created_at — **ยังไม่มี Seller approval workflow รอบนี้** เพราะ ZOKY Sellers by WYN คือ Phase 4 ที่ยังไม่เริ่ม ดู Risks), `products` (id, store_id, category_id, name, description, price, original_price nullable, stock, image_urls, created_at), `product_variants` (id, product_id, variant_type ('color'/'size'/...), variant_value, price_delta nullable, stock)
- RLS: อ่านได้ทุกคน (authenticated) เหมือน `clubs`/`drops`/`pops` (select-all-authenticated) เพราะเป็นเนื้อหาสาธารณะของ Marketplace ไม่ใช่เนื้อหาส่วนตัว — เขียน (insert/update/delete) **ยังไม่เปิดให้ client รอบนี้เลย** เพราะยังไม่มี Seller app/workflow ตัดสินใจสิทธิ์ให้ครบ (ดู Risks) — ใส่ seed/mock data ผ่าน migration หรือ Supabase Studio ตรง ๆ ระหว่างพัฒนา ไม่ใช่ผ่าน client insert

Acceptance Criteria:
- [ ] เปิดแอป → เห็น Bottom Nav 5 tab (Home/Drop/Pop/ZOKY/Profile) เรียงลำดับถูกต้อง ตำแหน่ง/พฤติกรรม 4 tab เดิมไม่เปลี่ยน
- [ ] แตะ ZOKY tab → เข้าหน้า ZOKY Home เห็น Categories/Banner-placeholder/Product sections/Product Grid ถูกต้อง
- [ ] แตะสินค้าใน Grid → เปิด Product Detail เห็นข้อมูลครบตาม Requirements
- [ ] แตะ Store Information ใน Product Detail → เปิด Store page เห็นข้อมูลครบตาม Requirements
- [ ] ปุ่ม Add to Cart/Buy Now/Follow Store แสดงผลถูกต้องตาม Design แต่ไม่ทำงานจริง (ไม่ crash เมื่อกด)
- [ ] WYN Social เดิมทั้งหมด (Home/Drop/Pop/Club/Profile/Search/Notification) ยังทำงานปกติ ไม่มี regression

Dependencies: WYN Social ทั้งหมด (Auth/Profile/Storage pattern) — ไม่ block โดย WYN-XXX task ใดที่ยังไม่เสร็จ เพราะเป็น feature module ใหม่แยกจาก Social เดิม

Priority: P0 ของสาย ZOKY — ต้องมีก่อนเพราะ ZOKY-002/003/004 ทั้งหมดต้องมี Product/Store ให้อ้างอิงก่อน

Risks:
- **Store Follow ต้อง data model ใหม่ ไม่ reuse `follows` เดิม**: ระบบ Follow ของ WYN Social (WYN-008) เป็น user-to-user เท่านั้น Store ไม่ใช่ profile จึงต้องมีตาราง `store_follows` แยก — เสนอ **ไม่สร้างตารางนี้รอบนี้** ปุ่ม Follow Store แสดงผลอย่างเดียว (visual only เหมือนปุ่ม Follow ของ Pop ตอน WYN-006 ก่อน WYN-008 จะทำให้ทำงานจริง) แล้วผูก data จริงเป็น task แยกทีหลัง
- **Chat Seller เป็นงานคนละขนาด**: ไม่มี messaging system ในโปรเจกต์นี้เลย เสนอซ่อนปุ่มนี้ไปก่อนรอบนี้ทั้งหมด ไม่ทำแม้แต่ placeholder
- **Seller เขียนข้อมูลลง `stores`/`products` เองไม่ได้รอบนี้**: เพราะ ZOKY Sellers by WYN (Phase 4) ยังไม่เริ่ม — ข้อมูลสาธิต/ทดสอบรอบนี้ต้อง seed ผ่าน Supabase Studio/migration ตรง ๆ ไม่ใช่ผ่าน UI ผู้ใช้จริง เมื่อ Phase 4 เริ่มจะต้องเพิ่ม RLS insert/update policy ให้ Seller เขียนข้อมูลร้าน/สินค้าตัวเองได้ (คล้าย pattern RPC-over-raw-RLS ของ WYN-014)
- **"Best Selling"/"Recommended" ยังไม่มีข้อมูลจริงรองรับ**: ต้องรอ ZOKY-003 (Order) ให้มี sales data ก่อนถึงจะ rank ได้จริง — รอบนี้ใช้ placeholder/ว่างเปล่าไปก่อน เหมือนที่ Explore Clubs (WYN-015) defer "แนะนำสำหรับคุณ"
- **Product Variants (Color/Size) ยังไม่ผูกกับ Stock/Price จริงในการคำนวณ Cart**: เพราะ Cart ยังไม่มีในรอบนี้ — UI เลือก variant ได้ แต่แค่ preview ไม่ใช่ transactional state ที่ต้องคำนวณราคาสุดท้ายจริงจนกว่าจะถึง ZOKY-003

Recommendation:
1. เริ่ม ZOKY-001 ทันทีตามที่ Founder สั่งในลำดับ Phase 2-3 ของ master prompt
2. **Store Follow/Chat Seller เป็น visual-only หรือซ่อนไปก่อนตามที่ระบุใน Risks** — ไม่ทำ data model เพิ่มในรอบนี้เพื่อไม่ให้ scope บวมเกินไป
3. **Seed ข้อมูล Product/Store ตัวอย่างผ่าน Supabase Studio** สำหรับทดสอบ/สาธิตรอบนี้ ไม่ต้องรอ Seller app จริง

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) ZOKY tab icon/ตำแหน่งใน Bottom Nav (2) ZOKY Home layout (Categories/Banner/Product sections/Grid) (3) Product Detail screen (4) Store screen — ต้องตัดสินใจ resolution ของ Store Follow/Chat Seller ตาม Risks ข้างต้น ใช้ Design system เดิม (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass) reuse component เดิมให้มากที่สุด (carousel รูปหลายรูปจาก `ClubPostCard`, grid tile จาก `PopGridTile`/`DropGridTile`, search bar placeholder pattern จาก WYN-007)

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/zoky-001-marketplace-foundation.md` — สรุป: 4 หน้าจอ/ส่วน (Bottom Nav tab ที่ 5, ZOKY Home, Product Detail, Store) ต่อยอดจาก component เดิมเกือบทั้งหมด — จุดใหม่ที่ต้องสร้างจริงมีแค่ `ProductMiniCard`/`StoreMiniCard`/`ProductGridTile` (มิเรอร์โครงจาก `ClubMiniCard`/`PopGridTile` ตรง ๆ) — ZOKY tab ใช้ `Icons.storefront_outlined` ต่อท้าย 4 tab เดิมไม่แทรกกลาง — ZOKY Home มีครบทุก section ตาม Product spec แต่ "แนะนำสำหรับคุณ"/"ขายดี" เป็น label + "เร็ว ๆ นี้" (ไม่ซ่อน section ต่างจาก pattern ของ WYN-015 เพราะทุกคนจะว่างเหมือนกันหมดตอนนี้ ซ่อนไปเลยจะดูเหมือนฟีเจอร์หายไป) — ปุ่มที่ยังไม่ทำงานจริงทั้งหมด (Search/Cart/Orders/Category tap/Add to Cart/ซื้อเลย/ติดตามร้าน) ต้องแสดงผลเสมอ+`SnackBar` "เร็ว ๆ นี้" ยกเว้น "แชทกับร้านค้า" ที่**ไม่แสดงเลย**เพราะไม่มี concept แชทในแอปให้สื่อสารอย่างมีความหมาย — เตือน Coding 1 จุดเสี่ยง: ตาราง `categories`/`stores`/`products`/`product_variants` ใหม่ต้อง RLS select-all-authenticated แต่**ห้ามมี insert/update/delete policy ให้ client เลยรอบนี้** (ไม่มี Seller workflow ตัดสินใจสิทธิ์จนกว่าจะถึง Phase 4)

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- Database (`supabase/schema.sql`): เพิ่มตาราง `categories` (seed ค่าคงที่ 9 หมวดหมู่ผ่าน `insert ... on conflict do nothing` ตรงใน schema เพราะเป็นชุดค่าตายตัวเหมือน enum แต่ต้องเป็น FK table จริงให้ `products.category_id` อ้างอิงได้), `stores`, `products` (มี CHECK ครบ: ราคาไม่ติดลบ, original_price ≥ price, stock ไม่ติดลบ, image_urls อย่างน้อย 1 รูป), `product_variants` (variant_type จำกัดแค่ `'color'/'size'` ตาม scope, unique constraint กัน variant ซ้ำ) — ทุกตาราง RLS แค่ select-all-authenticated (`using (true)`) เหมือน `clubs`/`drops`/`pops` **ไม่มี insert/update/delete policy ให้ client เลย** ตรงตามที่ Design เตือนไว้ (Seller workflow เป็น Phase 4 ในอนาคต)
- Models: `Category`, `Store` (join กับ product count แบบเดียวกับ `Club.memberCount`), `Product` (join ชื่อ store/category ผ่าน embed เดียว ไม่ต้อง 2-hop), `ProductVariant`, และ `ZokyRepository` (fetchCategories/fetchStore/fetchRecommendedStores/fetchProduct/fetchNewProducts/fetchProducts-paginated/fetchStoreProducts/fetchProductVariants)
- Navigation (`RootShell`): เพิ่ม `ZokyHomeScreen` เป็น tab ที่ 5 (index 4, **หลัง** Profile ไม่ใช่ก่อน — แก้ไขจากที่ทำผิดลำดับตอนแรกที่แทรกไว้ก่อน Profile) เพิ่ม `NavigationDestination` ใหม่ 1 อัน (`Icons.storefront_outlined`) 4 tab เดิมไม่ถูกแก้แม้แต่บรรทัดเดียว
- UI: `ZokyHomeScreen` (search/cart/orders placeholder, category chips จาก `fetchCategories`, banner คงที่, 2 section "เร็ว ๆ นี้", New Products+Recommended Stores เป็น horizontal `ProductMiniCard`/`StoreMiniCard` list, main grid เป็น `CustomScrollView`+`SliverGrid` infinite-scroll ของ `ProductGridTile`), `ProductDetailScreen` (carousel มิเรอร์ `ClubPostImages`, ราคา+ส่วนลด, variant chips preview-only ต่อ type, รีวิวว่างเปล่าเสมอเพราะยังไม่มีระบบ Review, การ์ดร้านค้าเปิด `StoreScreen`, action bar คงที่ด้านล่างมี Add to Cart/Buy Now), `StoreScreen` (header มิเรอร์ `ViewProfileScreen`, ปุ่มติดตามร้าน placeholder, TabBar 2 แท็บ สินค้า/รีวิว ไม่มีปุ่ม Chat Seller เลยตามที่ Design ระบุ) — widget ใหม่ 4 ตัว: `ProductMiniCard`/`StoreMiniCard` (มิเรอร์ `ClubMiniCard`), `ProductGridTile` (มิเรอร์ `PopGridTile` แต่ badge เป็นราคาแทน duration), `ProductImages` (มิเรอร์ `ClubPostImages`) — เพิ่ม `thaiBahtLabel()` helper ใน `core/text_utils.dart` (thousand separator, ตัดทศนิยมถ้าเป็นจำนวนเต็ม) — ปุ่ม placeholder ทั้งหมดใช้ constant เดียว `zokyComingSoonMessage` (reuse ข้อความ "ฟีเจอร์นี้จะมาเร็ว ๆ นี้" ที่ `ClubPage` ใช้อยู่แล้ว ไม่ประดิษฐ์คำใหม่)

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. **`RootShell` แทรก ZOKY ผิดตำแหน่ง**: ใส่ไว้ก่อน `ViewProfileScreen` ตอนแรก (กลายเป็น index 3 แทน Profile) ทั้งที่ Design spec ระบุชัดว่า "ตำแหน่งที่ 5, index 4" (หลัง Profile) — จับได้เองระหว่างเขียนโค้ดก่อนรัน test แก้ทันที
2. **`FutureBuilder<Store?>.hasData` bug จริงใน `StoreScreen`**: `AsyncSnapshot.hasData` นิยามเป็น `data != null` ไม่ใช่ตรวจ connection state — เมื่อ future resolve เป็น `null` จริง (ร้านไม่พบ) `hasData` จะเป็น false ตลอดไป ทำให้ `CircularProgressIndicator` หมุนไม่จบ (animation ทำให้ `pumpAndSettle()` timeout ค้างตลอดกาล) พบตอนเขียน widget test เอง แก้โดยเช็ค `snapshot.connectionState != ConnectionState.done` แทน — ยืนยันด้วย red→green regression proof แยกต่างหาก (ดู Tests)
3. **`ProductGridTile` ไม่โชว์ชื่อสินค้าเป็น text ที่กดได้** (ตั้งใจตาม Design — badge ราคาเท่านั้น ชื่อเป็น Semantics-only) — แก้ test ที่เขียนผิดสมมติฐานตอนแรก (พยายาม `find.text(productName)` แทนที่จะ `find.byType(ProductGridTile)`) ไม่ใช่บั๊ก production
4. **Test viewport (800×600) กับภาพ 1:1 ที่ด้านบนหน้า Product Detail**: `AspectRatio(1)` ทำให้รูปสูง ~800px เกิน viewport ทั้งหมด ทำให้เนื้อหาด้านล่าง (ราคา/ชื่อ/variant/ร้านค้า) ไม่ถูกสร้างเข้า element tree จนกว่าจะ scroll เข้าใกล้ (lazy sliver child inflation) — แก้ด้วย `tester.scrollUntilVisible` เหมือน pattern ที่ established ไว้แล้วใน `drop_detail_screen_test.dart`/`drop_comment_delete_test.dart` (ดู `.wyn/learning/PATTERNS.md`) และเจอเพิ่มว่า `scrollUntilVisible`'s minimal-movement บางครั้งหยุดที่ขอบพอดีจนกดไม่แม่น ต้อง drag เพิ่มอีกเล็กน้อยหลังจากนั้น

Files Changed:
- `supabase/schema.sql` (ตารางใหม่ 4 ตัว + RLS + seed categories)
- ใหม่: `app/lib/features/zoky/data/{category,store,product,product_variant,zoky_repository}.dart`, `app/lib/features/zoky/presentation/{zoky_home_screen,product_detail_screen,store_screen,zoky_strings}.dart`, `app/lib/features/zoky/presentation/widgets/{product_mini_card,store_mini_card,product_grid_tile,product_images}.dart`
- แก้: `app/lib/features/root/presentation/root_shell.dart` (tab ที่ 5), `app/lib/core/text_utils.dart` (เพิ่ม `thaiBahtLabel`)
- test ใหม่: `app/test/{zoky_home_screen_test,product_detail_screen_test,store_screen_test,text_utils_test}.dart`, `app/test/support/recording_zoky_repository.dart`

Reason: implement ตาม Product spec + Design spec ของ ZOKY-001 ครบตามขอบเขต Browse-only — เชื่อม ZOKY เข้ากับ Bottom Nav โดยไม่แตะ 4 tab เดิม reuse component เดิมของ WYN Social ให้มากที่สุดตามที่ Design กำหนด (มีแค่ 4 widget ใหม่จริง ๆ)

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 191/191 ผ่านทั้งหมด (เพิ่มจาก 162 เดิม — 29 เทสต์ใหม่: 12 ใน `zoky_home_screen_test.dart`, 9 ใน `product_detail_screen_test.dart`, 8 ใน `store_screen_test.dart` (รวมยืนยันว่าไม่มีปุ่ม Chat Seller เลย), 5 ใน `text_utils_test.dart` สำหรับ `thaiBahtLabel`)
- **ทำ red→green regression proof จริง 1 จุด** (Gap #2 ข้างต้น): เปลี่ยน `StoreScreen`'s check กลับเป็น `if (!snapshot.hasData)` ชั่วคราว → รัน `store_screen_test.dart --plain-name "shows \"ไม่พบร้านค้านี้\""` → **FAIL จริง** (`pumpAndSettle timed out` เพราะ spinner หมุนไม่จบ) → revert กลับเป็น `connectionState != ConnectionState.done` → รัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด 191/191

Known Issues:
- Explore/Search ยังไม่มีจริง (Category chip/Search bar เป็น placeholder ทั้งหมด — ผูกจริงที่ ZOKY-002)
- Add to Cart/Buy Now/ติดตามร้าน แสดงผลแต่ไม่ทำงานจริง (ผูกจริงที่ ZOKY-003 และ task แยกสำหรับ Store Follow data model)
- "แนะนำสำหรับคุณ"/"ขายดี" เป็น placeholder ล้วน ไม่มีข้อมูลจริงจนกว่าจะมี Order data (ZOKY-003)
- `fetchPopularClubs`-แบบเดียวกัน: `fetchRecommendedStores`/main grid pagination ยังไม่ scale (แต่ grid ใช้ `.range()` จริงต่างจาก Club's fetch-all-then-sort เพราะไม่ต้อง sort ตาม field ที่ query ไม่ได้)
- Seller เขียนข้อมูล `stores`/`products` เองไม่ได้จนกว่าจะถึง Phase 4 — ทดสอบ/สาธิตต้อง seed ผ่าน Supabase Studio

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ ZOKY-001 ก่อนอนุมัติ — เน้นตรวจเป็นพิเศษ: (ก) RLS ของตารางใหม่ทั้ง 4 ไม่มี insert/update/delete policy ใดๆ เปิดให้ client จริง (ข) Bottom Nav 5 tab เรียงลำดับถูกต้อง (Home/Drop/Pop/Profile/ZOKY) และ 4 tab เดิมไม่มี regression (ค) ปุ่ม placeholder ทั้งหมดกดแล้วไม่ crash และไม่มีปุ่ม Chat Seller ปรากฏเลยจริง (ง) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัด (จ) regression กับ WYN Social เดิมทั้งหมด (Home/Drop/Pop/Club/Profile/Search/Notification)

---

## QA & Security Report — รอบ 1 (AI QA & Security)

**ผลสรุป: PASS**

### สิ่งที่ตรวจอิสระ (ไม่เชื่อตัวเลขจาก Coding Output เฉยๆ)

1. **Re-sync ไป merged main เอง** — `git fetch origin main`, rebuild branch `claude/pwd-nxsvf5` บน `origin/main` (commit `0cedef9`, PR #71) ใหม่ทั้งหมด
2. **รัน `flutter analyze` อิสระ**: No issues found
3. **รัน `flutter test` อิสระ**: 191/191 ผ่านทั้งหมด — ตรงกับตัวเลขที่ Coding รายงาน ยืนยันด้วยตัวเองแล้ว

### ตรวจ RLS ของตารางใหม่ทั้ง 4 ตัว

อ่าน `supabase/schema.sql` (ZOKY-001 section) ทีละตาราง ยืนยันว่า `categories`/`stores`/`products`/`product_variants` ทุกตัว `enable row level security` แล้วมี **แค่ policy เดียว** ต่อตาราง (`for select ... using (true)`) — ไม่มี insert/update/delete policy ใดๆ เลยแม้แต่ตัวเดียว หมายความว่า client (แม้จะ authenticated) เขียนข้อมูลลงตารางเหล่านี้ไม่ได้เลยจริง ๆ (RLS ปิดกั้นทุก operation ที่ไม่มี policy รองรับโดย default) — ตรวจ CHECK constraint ครบด้วย: `products_price_nonnegative`, `products_original_price_gte_price`, `products_stock_nonnegative`, `products_image_urls_length` (1-10 รูป), `product_variants` จำกัด `variant_type` แค่ `'color'/'size'` + unique constraint กัน variant ซ้ำ — seed ข้อมูล `categories` 9 หมวดหมู่ใช้ `insert ... on conflict (name) do nothing` ตรงใน schema (เป็น reference data แบบ enum ไม่ใช่ user data จึงไม่ขัดกับกฎ "ไม่มี insert policy ให้ client" เพราะรันตอน migrate ไม่ใช่ผ่าน client)

### ตรวจ Bottom Nav 5 tab ไม่กระทบ 4 tab เดิม

อ่าน `root_shell.dart` ยืนยันว่า `tabs` list เรียงตรงกับ `destinations` list เป๊ะ: `[Home(0), Drop(1), Pop(2), Profile(3), ZokyHomeScreen(4)]` — ZOKY อยู่ index 4 (หลัง Profile) ตรงตาม Design spec "ตำแหน่งที่ 5, index 4" ไม่ใช่ index 3 ตามที่ Coding เคยพลาดตอนแรกแล้วแก้เอง — `_onDestinationSelected`'s `if (index == 3 && _index != 3) _profileVisitKey++` ยังชี้ไปที่ Profile ถูกต้อง (Profile ไม่ถูกเลื่อน index) — ตรวจ diff ของ PR #71 ทั้งหมดยืนยันว่านอกจาก `root_shell.dart` (+9 บรรทัด เพิ่ม import/tab ใหม่ล้วน ไม่มีการลบ/แก้บรรทัดเดิม) กับ `text_utils.dart` (+18 บรรทัด เพิ่ม `thaiBahtLabel` ล้วน) แล้ว ไม่มีไฟล์ WYN Social เดิมไฟล์ไหนถูกแตะเลย — ทุกไฟล์ใหม่อยู่ใต้ `app/lib/features/zoky/` ทั้งหมด

### ตรวจปุ่ม placeholder และ Chat Seller

`grep` หา `zokyComingSoonMessage` ยืนยันว่าทั้ง 3 หน้าจอ (ZokyHomeScreen/ProductDetailScreen/StoreScreen) เรียก SnackBar ข้อความเดียวกันจริงจาก constant เดียว (`zokyComingSoonMessage = 'ฟีเจอร์นี้จะมาเร็ว ๆ นี้'`, reuse ข้อความเดิมของ `ClubPage`) ไม่มีข้อความกระจัดกระจาย — `grep` หา "แชท"/"Chat" ทั้งโฟลเดอร์ `zoky/` ยืนยันว่าไม่มี widget ปุ่ม Chat Seller อยู่เลยแม้แต่จุดเดียว (เจอแค่ comment อธิบายเหตุผลที่ไม่ทำ) มี test `never shows a Chat Seller button` ยืนยันด้วยโค้ดจริงด้วย

### ตรวจ `FutureBuilder<Store?>` bug ที่ Coding แก้เอง

อ่าน `store_screen.dart` ยืนยันเหตุผลถูกต้อง: `AsyncSnapshot.hasData` นิยามเป็น `data != null` ไม่ใช่เช็ค connection state จริง เมื่อ future resolve เป็น `null` (ร้านไม่พบจริง) `hasData` จะเป็น false ตลอดไป ทำให้ CircularProgressIndicator หมุนไม่จบ — การแก้ด้วย `snapshot.connectionState != ConnectionState.done` ถูกต้องแล้ว

### ไล่ Requirements/Design Components/Acceptance Criteria ทีละบรรทัด

ไล่ครบทั้ง 3 หัวข้อเทียบกับโค้ดจริง — ผ่านเกือบทั้งหมด **ยกเว้น 1 จุด** (ดู Finding ด้านล่าง)

**AC ทุกข้อผ่าน**: Bottom Nav 5 tab เรียงถูกต้อง ไม่กระทบ 4 tab เดิม / ZOKY Home มี Categories/Banner-placeholder/Product sections/Grid ครบ / แตะสินค้าเปิด Product Detail / แตะ Store Info เปิด Store page / ปุ่ม Add to Cart/Buy Now/ติดตามร้าน แสดงผลถูกต้องไม่ crash / WYN Social เดิมไม่มี regression (191/191)

### Finding — Minor (ไม่ block)

**`ProductDetailScreen`/`StoreScreen` ไม่แสดง "Rating" เลย ทั้งที่ Product Requirements และ Design Components ระบุไว้ตรง ๆ ทั้งคู่**: Product spec's Product Detail Requirements ระบุ "...Stock, Product Variants..., Description, **Rating**, Reviews..." และ Store Requirements ระบุ "Store Logo, Store Name, **Store Rating**, Followers count..." — Design spec's Screen 2/3 ก็ระบุ "Rating" แยกจาก "Reviews" ไว้ตรง ๆ เช่นกัน (`"...Description, Rating, Reviews (แสดงถ้ามี...)"` / `"...ชื่อร้าน + rating + 'Followers: N'..."`) แต่โค้ดจริง (`grep` ยืนยันแล้ว) **ไม่มีคำว่า rating/ดาว/คะแนน อยู่ในไฟล์ ZOKY-001 เลยแม้แต่จุดเดียว** — ทั้ง `Product`/`Store` model ไม่มี field `rating` เลยด้วยซ้ำ ไม่ใช่แค่ UI ไม่แสดง

เหตุผลที่ไม่ block: (1) ไม่มี AC บรรทัดไหนทดสอบค่า rating ตรง ๆ (2) ไม่มี data source ให้ rating จริงรอบนี้เลย (ไม่มีตาราง reviews/ratings ในรอบนี้ ระบบ Review จริงมาที่ ZOKY-004) การแสดงตัวเลขปลอมจะแย่กว่าไม่แสดง (3) ในหน้า Product Detail ข้อความ "ยังไม่มีรีวิว" ที่มีอยู่แล้วสื่อความหมายครอบคลุมถึงการไม่มี rating โดยอ้อมได้ในระดับหนึ่ง — แต่ในหน้า Store header ไม่มีแม้แต่การสื่อความหมายทางอ้อมนี้เลย เป็นจุดที่ควรปรับปรุงมากกว่า

**หมายเหตุสำคัญ**: นี่คือครั้งที่ 5 ในโปรเจกต์นี้ของ pattern เดียวกัน (WYN-005×2, WYN-007, WYN-015, ตอนนี้ ZOKY-001) — "spec ระบุ component ไว้ตรง ๆ ทั้ง Product และ Design แต่ Coding ข้ามไปเงียบ ๆ โดยไม่บันทึกเป็น scope cut ที่ตั้งใจ" ต่างจาก WYN-015 (ที่ระดับรุนแรงลดลงเพราะยังมีทางออกอื่น) ครั้งนี้กลับไม่มีการบันทึกเหตุผลไว้เลยว่าทำไมถึงตัด Rating ออก (ต่างจาก "แนะนำสำหรับคุณ"/"ขายดี" ที่ Coding บันทึกเหตุผลไว้ชัดเจนใน Known Issues ว่าไม่มีข้อมูลรองรับ) — **คำแนะนำ**: เพิ่ม placeholder ข้อความสั้น ๆ เช่น "ยังไม่มีคะแนน" ในหน้า Store header เป็น fast-follow เล็ก ๆ (ไม่จำเป็นต้องรอ ZOKY-004) เพื่อให้ตรงกับ spec ที่ระบุตำแหน่งไว้ อย่างน้อยก็ในระดับ "แสดงตำแหน่งไว้ว่างเปล่าอย่างมีความหมาย" เหมือนที่ทำกับ Recommended/Best Selling section แล้ว

### Red→Green Regression Proof อิสระ (จุดที่ต่างจาก Coding เอง)

Coding ทำ proof ที่ `StoreScreen`'s `FutureBuilder<Store?>.hasData` bug — QA เลือกทำ proof คนละจุด: **`Product.discountPercent`'s เปอร์เซ็นต์ส่วนลด**
1. แก้ `product.dart`'s `discountPercent` จาก `(originalPrice! - price) / originalPrice!` (ถูกต้อง) เป็น `(originalPrice! - price) / price` (ผิด — หารด้วยราคาปัจจุบันแทนราคาเดิม, บั๊กคลาสสิกที่คำนวณ % ส่วนลดผิดสูตร) ชั่วคราว
2. รัน `flutter test test/product_detail_screen_test.dart --plain-name "shows price, discount badge"` → **FAIL จริง** (คาดหวัง `-25%` แต่คำนวณผิดได้ค่าอื่น)
3. Revert กลับสูตรเดิม
4. รัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด 191/191

### Regression กับ WYN Social เดิมทั้งหมด

191/191 tests ครอบคลุม Drop/Pop/Home/Follow/Search/Profile/Notification/Club Core/Club Discovery เดิมทั้งหมดผ่านหมด ไม่มี regression — ยืนยันเพิ่มเติมด้วยการอ่าน diff ของ PR ว่าไม่มีไฟล์ WYN Social เดิมไฟล์ไหนถูกแก้ไข logic นอกจาก `root_shell.dart`'s เพิ่ม tab ใหม่ (ไม่แก้ของเดิม)

### สรุป

ZOKY-001 ผ่าน QA รอบ 1 — **PASS** พบ 1 finding ระดับ Minor (ไม่ block ตามเหตุผลข้างต้น แต่เป็น pattern ที่เกิดซ้ำเป็นครั้งที่ 5 ควรให้ความสำคัญกับ pre-submission checklist ของ Coding มากขึ้น) อนุมัติเข้า `approved/`
