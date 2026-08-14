# Product Task — ZOKY-002

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS)

Feature: ZOKY Search & Filter — ค้นหา Product/Store ด้วยชื่อ, กรองตาม Category/ช่วงราคา, เรียงลำดับผลลัพธ์

Goal: ทำให้ปุ่ม "ค้นหาสินค้า/ร้านค้า" ใน ZOKY Home (ที่เป็น placeholder ตั้งแต่ ZOKY-001) ทำงานจริง ให้ผู้ใช้หาสินค้า/ร้านค้าที่ต้องการเจอได้ ไม่ต้องไล่ดูทีละหน้า

Target User: ผู้ใช้ ZOKY ที่รู้ชื่อสินค้า/ร้านค้าที่ต้องการอยู่แล้ว หรืออยากกรองดูเฉพาะหมวดหมู่/ช่วงราคาที่สนใจ

Problem: ZOKY-001 ส่งมอบแค่ "เรียกดู" (Browse) — ปุ่มค้นหาใน ZOKY Home ทั้งหมดยังเป็น `SnackBar` "ฟีเจอร์นี้จะมาเร็ว ๆ นี้" ไม่มีทางค้นหาสินค้า/ร้านค้าจริงเลย และปุ่ม Category chip ก็ยังไม่ filter อะไรจริง

Requirements:

**ค้นหา** (อ้างอิง master prompt Section 5: "ค้นหา: Products, Stores, Categories")
- หน้าค้นหาใหม่ `ZokySearchScreen` เปิดจากการแตะ search bar ใน ZOKY Home (แทนที่ `SnackBar` placeholder เดิม) — ช่องค้นหาเดียวอยู่บนสุด ใช้ debounce 400ms เหมือน pattern เดิมของ `SearchScreen` (WYN-009)
- **ไม่รวมเข้ากับ `SearchScreen` ของ WYN Social เดิม** — เป็นหน้าจอแยกต่างหาก (`ZokySearchScreen`) เพราะเป็นคนละ entry point (Home's search bar ค้นหา User/Drop/Pop/Club ส่วน ZOKY Home's search bar ค้นหา Product/Store) reuse แค่ **pattern** เดียวกัน (debounce/TabBar/`SearchStateMessage`) ไม่ reuse instance เดียวกัน
- 2 แท็บ: **Product** (ค้นหาจากชื่อสินค้า, ILIKE case-insensitive เหมือน `ClubRepository.searchClubs`/`DropRepository.searchByCaption`) และ **Store** (ค้นหาจากชื่อร้าน) — ผลลัพธ์แสดงเป็น card แบบเดียวกับที่ใช้ใน ZOKY Home (reuse `ProductGridTile`/`StoreMiniCard` หรือออกแบบใหม่ให้เหมาะกับ list แนวตั้ง — ให้ Design ตัดสินใจ)
- **"Categories" ในหัวข้อค้นหาของ brief หมายถึง filter ไม่ใช่ full-text search แยก**: Category เป็นชุดค่าคงที่ 9 ค่าจาก ZOKY-001 อยู่แล้ว ไม่ต้องทำเป็นช่องค้นหาแยก ใช้เป็น filter chip ในแท็บ Product แทน (ดู Filter ด้านล่าง)

**Filter & Sort** (อ้างอิง master prompt Section 5: "Filter: Price, Rating, Sales, Newest — Sort: Recommended, Best Selling, Price Low→High, Price High→Low, Newest")
- **ทำได้จริงรอบนี้**: Category filter (chip แนวนอน, ใช้ 9 ค่าเดิมจาก ZOKY-001, เฉพาะแท็บ Product), Price range filter (ต่ำสุด-สูงสุด), Sort ตาม **Newest** (ค่าเริ่มต้น), **Price Low→High**, **Price High→Low** — ทั้งหมดนี้มีข้อมูลจริงรองรับอยู่แล้ว (`created_at`, `price` เป็น column จริงที่ query/sort ได้ตรง ๆ)
- **Defer รอบนี้ (ไม่มีข้อมูลจริงรองรับ)**: Rating filter/sort (ไม่มีตาราง reviews/ratings จนกว่าจะถึง ZOKY-004), Sales/Best Selling sort (ไม่มีตาราง orders จนกว่าจะถึง ZOKY-003), Recommended sort (ไม่มี behavioral signal — เหตุผลเดียวกับที่ ZOKY-001 defer "แนะนำสำหรับคุณ" ใน ZOKY Home) — ทั้งสามนี้เหตุผลเดียวกับที่ระบุไว้แล้วใน ZOKY-001's Known Issues ทุกประการ ไม่ใช่เรื่องใหม่
- Category filter chip ที่แตะจาก ZOKY Home เดิม (เคยเป็น `SnackBar` placeholder) ให้เปิด `ZokySearchScreen` พร้อม category นั้นเลือกไว้แล้วทันที แทนที่จะเป็นแค่ placeholder เหมือนเดิม

Acceptance Criteria:
- [ ] แตะ search bar ใน ZOKY Home → เปิด `ZokySearchScreen`
- [ ] พิมพ์ค้นหาในแท็บ Product → เจอสินค้าที่ชื่อตรงกับคำค้น (case-insensitive)
- [ ] พิมพ์ค้นหาในแท็บ Store → เจอร้านค้าที่ชื่อตรงกับคำค้น (case-insensitive)
- [ ] กรอง Category ในแท็บ Product ได้ถูกต้อง (เฉพาะสินค้าหมวดนั้น)
- [ ] กรอง Price range ได้ถูกต้อง (สินค้าที่ราคาอยู่นอกช่วงไม่ปรากฏ)
- [ ] เรียงลำดับ Newest/Price Low→High/Price High→Low ได้ถูกต้องตามที่เลือก
- [ ] แตะ Category chip ใน ZOKY Home → เปิด `ZokySearchScreen` พร้อม filter category นั้นไว้แล้ว
- [ ] แตะผลลัพธ์สินค้า/ร้านค้า → เปิด `ProductDetailScreen`/`StoreScreen` เดิมของ ZOKY-001 ถูกต้อง
- [ ] WYN Social เดิมทั้งหมด (Home/Drop/Pop/Club/Profile/Search/Notification) และ ZOKY-001 (Browse) เดิม ยังทำงานปกติ ไม่มี regression

Dependencies: ZOKY-001 (Marketplace Foundation — Approved, dependency หลักเพราะต้องมี Product/Store/`ProductGridTile`/`StoreMiniCard`/`ProductDetailScreen`/`StoreScreen` อยู่แล้ว)

Priority: P1 ของสาย ZOKY — ต่อจาก ZOKY-001 ตามลำดับ roadmap (`.wyn/docs/product/zoky-platform-roadmap.md`)

Risks:
- **Rating/Sales/Recommended filter-sort defer เหตุผลเดียวกับ ZOKY-001 ทุกประการ**: ไม่มีข้อมูลจริงรองรับจนกว่าจะถึง ZOKY-003 (Order → Sales)/ZOKY-004 (Review → Rating) — ไม่ใช่ความเสี่ยงใหม่ เป็น pattern เดิมที่ยืนยันแล้วจาก ZOKY-001
- **Price range filter ต้อง UI ที่ใช้งานง่ายบนมือถือ**: เสนอ `RangeSlider` หรือช่องกรอกตัวเลข 2 ช่อง (ต่ำสุด/สูงสุด) — ให้ Design ตัดสินใจโดยพิจารณาจาก design-principles.md (Touch target ≥44px)
- **ค้นหา Store ไม่มี Category ให้กรอง**: Store ไม่มี column category (ตาราง `stores` ของ ZOKY-001 ไม่มี category_id ต่างจาก `products`) — Category filter chip แสดงเฉพาะแท็บ Product เท่านั้น ไม่แสดงในแท็บ Store

Recommendation:
1. เริ่ม ZOKY-002 ทันทีตามลำดับ roadmap
2. **แยกหน้าค้นหาเป็น `ZokySearchScreen` ใหม่ ไม่รวมเข้า `SearchScreen` เดิมของ WYN Social** — เหตุผลอยู่ใน Requirements (คนละ entry point คนละ content domain)
3. **ทำแค่ Newest/Price sort + Category/Price filter รอบนี้** ตัด Rating/Sales/Recommended ออกตามเหตุผลใน Risks

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) `ZokySearchScreen` layout (query box + TabBar 2 แท็บ Product/Store) (2) Category filter chip row ในแท็บ Product (3) Price range filter UI (4) Sort control (Newest/Price Low→High/Price High→Low) — reuse component เดิมให้มากที่สุด (`ProductGridTile`/`ProductMiniCard`/`StoreMiniCard`, `ChoiceChip` category pattern จาก ZOKY-001, debounce+`SearchStateMessage` pattern จาก WYN-009) ใช้ Design system เดิม (Blue+White+Soft Gray, Rounded Cards, ห้าม Liquid Glass)

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/zoky-002-search-and-filter.md` — สรุป: `ZokySearchScreen` ใหม่ (ไม่ reuse instance ของ `SearchScreen` เดิม) มี query box+debounce 400ms+TabBar 2 แท็บ (สินค้า/ร้านค้า) มิเรอร์ pattern ของ WYN-009 เป๊ะ — แท็บสินค้าแสดงผลเป็น `GridView` ของ `ProductGridTile` เดิม (ราคาต้องเห็นชัด) มีปุ่ม "ตัวกรอง" (เปิด bottom sheet: Category chip + ช่วงราคา 2 ช่อง text field ไม่ใช้ RangeSlider เพราะแม่นยำกว่าเมื่อผู้ใช้รู้ตัวเลขที่ต้องการ) และปุ่ม "เรียงลำดับ" (dropdown menu 3 ตัวเลือก apply ทันที) — แท็บร้านค้าแสดงเป็น `ListView` ของ `StoreResultCard` ใหม่ (มิเรอร์ `ClubDiscoveryCard` โครงแถวเต็มความกว้าง ต่างจาก `StoreMiniCard` เดิมที่เป็นการ์ดแคบ) — ZOKY Home's search bar/category chip ที่เคย `SnackBar` placeholder เปลี่ยนไปเปิด `ZokySearchScreen` จริง (category chip ส่ง `initialCategory` มาด้วย) — เตือน Coding 1 จุด: ต้องตรวจ ILIKE query ไม่มีช่องโหว่แบบเดียวกับ Minor ที่เคยพบใน `ProfileRepository.searchProfiles` (WYN-009)

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- `ZokyRepository`: เพิ่ม `searchProducts({query, categoryId, minPrice, maxPrice, sortBy, page})` (`.ilike('name', '%$query%')` เรียกตรง ไม่ผ่าน `.or()` string ป้องกัน Minor แบบเดียวกับที่เคยพบใน `ProfileRepository.searchProfiles`, filter เพิ่มเข้าไปแบบมีเงื่อนไข `.eq`/`.gte`/`.lte` เฉพาะเมื่อมีค่า, sort ผ่าน `switch` เลือก `.order()` ตาม `ProductSortBy`), `searchStores({query, page})` (ILIKE + count เหมือน `fetchRecommendedStores`) — เพิ่ม `ProductSortBy` enum และ `searchPageSize` constant
- `ZokySearchScreen` ใหม่ — query box+debounce 400ms+TabBar 2 แท็บ มิเรอร์ `SearchScreen` (WYN-009) เป๊ะตามที่ Design ระบุ ไม่ reuse instance เดียวกัน
- `ZokyProductResultsTab`: filter (ปุ่ม "ตัวกรอง" เปิด bottom sheet Category chip + ราคาต่ำสุด/สูงสุด) + sort (ปุ่ม "เรียงลำดับ" เปิด `showMenu` 3 ตัวเลือก apply ทันที) + `GridView` ของ `ProductGridTile` เดิม + infinite-scroll
- `ZokyStoreResultsTab`: `ListView` ของ `StoreResultCard` ใหม่ (มิเรอร์ `ClubDiscoveryCard` โครงแถวเต็มความกว้าง) + infinite-scroll — ไม่มี filter เพราะ Store ไม่มี category column
- `ZOKY Home`: search bar และ category chip เปลี่ยนจาก `SnackBar` placeholder เป็นเปิด `ZokySearchScreen` จริง (category chip ส่ง `initialCategory` เข้าไป pre-filter ทันที)
- reuse `SearchStateMessage` เดิมของ WYN-009 ตรง ๆ (import ข้าม feature folder) แทนที่จะสร้าง widget ซ้ำ ตามกติกา "ห้ามเขียนระบบซ้ำ"

Gaps ที่ Coding พบและแก้เองก่อนส่ง QA:
1. **RecordingXRepository built inline** — เขียน `emptyRepo` ไว้ inline ใน testWidgets callback ของเทสต์ "shows 'ไม่พบสินค้า'..." ตอนแรก ทำให้เจอ "Timer is still pending" error (gotcha เดิมที่เคยบันทึกไว้ใน `.wyn/learning/PATTERNS.md`) — ย้ายเข้า `setUp()` เป็น named `late` field ตามธรรมเนียมที่ established ไว้แล้ว แก้ทันทีก่อนส่ง QA

Files Changed:
- แก้: `app/lib/features/zoky/data/zoky_repository.dart` (searchProducts/searchStores/ProductSortBy ใหม่), `app/lib/features/zoky/presentation/zoky_home_screen.dart` (search bar/category chip เปิด ZokySearchScreen จริง)
- ใหม่: `app/lib/features/zoky/presentation/zoky_search_screen.dart`, `app/lib/features/zoky/presentation/widgets/{zoky_product_results_tab,zoky_store_results_tab,store_result_card}.dart`
- test ใหม่: `app/test/zoky_search_screen_test.dart`
- test แก้: `app/test/zoky_home_screen_test.dart` (อัปเดต 2 เทสต์เดิมที่ทดสอบ placeholder ให้ตรงกับพฤติกรรมจริงใหม่), `app/test/support/recording_zoky_repository.dart` (เพิ่ม searchProducts/searchStores override + recorded-args fields)

Reason: implement ตาม Product spec + Design spec ของ ZOKY-002 ครบตามขอบเขต — ค้นหา/กรอง/เรียงลำดับ Product/Store ได้จริง reuse component เดิม (ProductGridTile, SearchStateMessage, debounce/TabBar pattern) เกือบทั้งหมด จุดใหม่จริงมีแค่ StoreResultCard และ filter bottom sheet/sort menu

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 200/200 ผ่านทั้งหมด (เพิ่มจาก 191 เดิม — 9 เทสต์ใหม่ใน `zoky_search_screen_test.dart` ครอบคลุม empty-state ทั้ง 2 แท็บ, debounced search ทั้ง 2 แท็บ, empty-result state, initialCategory pre-fill, filter sheet apply, sort menu apply, tap-through ไป ProductDetailScreen/StoreScreen)
- **ทำ red→green regression proof จริง 1 จุด**: เปลี่ยน `_category = widget.initialCategory` เป็น `_category = null` ชั่วคราวใน `zoky_product_results_tab.dart` จำลองบั๊กที่ category chip ไม่ pre-filter → รัน `zoky_search_screen_test.dart --plain-name "opening with an initialCategory"` → **FAIL จริง** → revert → รัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด 200/200

Known Issues:
- Rating filter/sort, Sales/Best Selling sort, Recommended sort ไม่ทำรอบนี้ตามที่ Product ตัดสินใจ (ไม่มีข้อมูลจริงรองรับจนกว่าจะถึง ZOKY-003/ZOKY-004 — เหตุผลเดียวกับ ZOKY-001's Known Issues)
- Price filter ยอมรับแค่ตัวเลขเต็ม/ทศนิยม ผ่าน `double.tryParse` ไม่มี validation UI แจ้งเตือนถ้าพิมพ์ค่าที่ parse ไม่ได้ (เงียบ ๆ แค่ไม่ apply filter นั้น) — ยอมรับได้เพราะไม่ crash และผลลัพธ์ยังถูกต้อง (แค่ไม่กรอง)
- ยังไม่ทดสอบกับ Supabase project จริง (ILIKE/gte/lte/order ผสมกันในคำสั่งเดียว) — ตรวจได้แค่ระดับ code review เหมือนทุก feature ก่อนหน้าที่ยังไม่มี infra จริง

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ ZOKY-002 ก่อนอนุมัติ — เน้นตรวจเป็นพิเศษ: (ก) `.ilike()` เรียกตรงไม่ผ่าน `.or()` string ยืนยันไม่มีช่องโหว่แบบเดียวกับ Minor เดิมของ WYN-009 (ข) `ZokySearchScreen` เป็นหน้าแยกจริงไม่ปนกับ `SearchScreen` เดิม ไม่กระทบ WYN Social search (ค) filter/sort ส่งพารามิเตอร์ถูกต้องครบทุก field (ง) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัด (จ) regression กับ ZOKY-001/WYN Social เดิมทั้งหมด

---

## QA & Security Report — รอบ 1 (AI QA & Security)

**ผลสรุป: PASS**

### สิ่งที่ตรวจอิสระ (ไม่เชื่อตัวเลขจาก Coding Output เฉยๆ)

1. **Re-sync ไป merged main เอง** — `git fetch origin main`, rebuild branch `claude/pwd-nxsvf5` บน `origin/main` (commit `2e64957`, PR #75) ใหม่ทั้งหมด
2. **รัน `flutter analyze` อิสระ**: No issues found
3. **รัน `flutter test` อิสระ**: 200/200 ผ่านทั้งหมด — ตรงกับตัวเลขที่ Coding รายงาน ยืนยันด้วยตัวเองแล้ว

### ตรวจ ILIKE safety และการแยกจาก WYN Social Search

อ่าน `zoky_repository.dart` ยืนยันว่า `.ilike('name', '%$query%')` ทั้ง `searchProducts`/`searchStores` เรียกเป็น method โดยตรงบน query builder ไม่ได้ถูกประกอบเป็น string แล้วส่งผ่าน `.or()` เหมือนที่เคยเป็น Minor ใน `ProfileRepository.searchProfiles` (WYN-009) — ปลอดภัยเพราะ `.ilike()` โดยตรงถูก parameterize โดย query builder เอง ไม่ใช่ raw string interpolation เข้า filter DSL — อ่าน `git show <commit> --stat` ของ PR #75 ยืนยันว่า**ไม่มีไฟล์ไหนใต้ `app/lib/features/search/` (WYN-009) ถูกแก้ไขเลยแม้แต่บรรทัดเดียว** (มีแค่ import `SearchStateMessage` มาใช้ ไม่ใช่แก้ไฟล์นั้น) — ยืนยันว่า `ZokySearchScreen` เป็นหน้าแยกจริงตามที่ Design ตั้งใจ ไม่มีทางกระทบ `SearchScreen` เดิมของ WYN Social

### ไล่ Requirements/Design Components/Acceptance Criteria ทีละบรรทัด

ไล่ครบทั้ง 3 หัวข้อเทียบกับโค้ดจริง (`zoky_search_screen.dart`, `zoky_product_results_tab.dart`, `zoky_store_results_tab.dart`, `store_result_card.dart`, `zoky_repository.dart`) — **ผ่านครบทุกข้อ ไม่พบ gap**

**AC ทุกข้อผ่าน**: search bar ใน ZOKY Home เปิด `ZokySearchScreen` / ค้นหา Product/Store ตามชื่อ case-insensitive ถูกต้อง (ILIKE) / กรอง Category เฉพาะแท็บ Product ถูกต้อง (Store ไม่มี column ให้กรองตามที่ระบุใน Risks) / กรองช่วงราคาถูกต้อง / เรียงลำดับ Newest/Price Low→High/Price High→Low ถูกต้องตามที่เลือก (ยืนยันด้วย red→green proof ด้านล่าง) / category chip จาก ZOKY Home ส่ง `initialCategory` มา pre-filter ถูกต้อง (Filter sheet ไม่เปิดอัตโนมัติตามที่ Design ตั้งใจ) / แตะผลลัพธ์เปิด `ProductDetailScreen`/`StoreScreen` เดิมถูกต้อง / ไม่มี regression กับ WYN Social/ZOKY-001 (200/200)

ตรวจ Design Components เพิ่มเติม: ปุ่ม "ตัวกรอง"/"เรียงลำดับ" แสดงเฉพาะแท็บ Product จริง (อยู่ใน `ZokyProductResultsTab`'s build เอง ไม่ใช่ global ใน AppBar — ถูกจุดตามที่ Design ตั้งใจ), Sort menu apply ทันทีไม่ต้องกดยืนยันซ้ำ (ตรงตาม Design's เหตุผลเรื่อง "ค่าเดียวไม่มี ambiguity"), Filter sheet ต้องกด "แสดงผลลัพธ์" ก่อน apply (ตรงตาม Design's เหตุผลเรื่อง "หลายค่าต้องตั้งพร้อมกัน"), ปุ่ม "ล้างตัวกรอง" แสดงเฉพาะเมื่อมี filter active จริง, ไม่มี Rating/Sales/Recommended sort option ปรากฏใน Sort menu เลย (ตรวจโค้ดยืนยันมีแค่ 3 ตัวเลือกตามที่ Product/Design ตัดสินใจ)

### Red→Green Regression Proof อิสระ (จุดที่ต่างจาก Coding เอง)

Coding ทำ proof ที่ category-chip pre-filter wiring — QA เลือกทำ proof คนละจุด: **Sort menu's PopupMenuItem value ↔ label ผูกถูกคู่จริง**
1. สลับ `value` ของ `PopupMenuItem` สองตัว (`priceLowToHigh`/`priceHighToLow`) ให้ label ผูกผิดคู่ชั่วคราว (label "ราคา: ต่ำ → สูง" ชี้ไปที่ `priceHighToLow` แทน) จำลองบั๊กเมนูเรียงลำดับผูกผิด
2. รัน `flutter test test/zoky_search_screen_test.dart --plain-name "choosing a sort option"` → **FAIL จริง** (คาดหวัง `priceLowToHigh` แต่ได้ `priceHighToLow`)
3. Revert กลับคู่เดิม
4. รัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด 200/200

### Regression กับ ZOKY-001/WYN Social เดิมทั้งหมด

200/200 tests ครอบคลุม Drop/Pop/Home/Follow/Search/Profile/Notification/Club Core/Club Discovery/ZOKY-001 (Browse) เดิมทั้งหมดผ่านหมด ไม่มี regression — ยืนยันเพิ่มเติมด้วยการอ่าน diff ของ PR #75 ว่าแก้ไขเฉพาะไฟล์ใต้ `app/lib/features/zoky/` และ `zoky_home_screen.dart` (search bar/category chip wiring ที่ตั้งใจ) เท่านั้น

### สรุป

ZOKY-002 ผ่าน QA รอบ 1 — **PASS** ไม่พบ finding ใด ๆ (ทั้ง Blocking และ Minor) รอบนี้ — เป็นครั้งแรกในสาย ZOKY ที่ QA ไม่พบข้อสังเกตอะไรเลย อนุมัติเข้า `approved/`
