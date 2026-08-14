# Product Task — ZOKY-002

Status: active (Design เสร็จแล้ว รอ Coding)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (รอ)

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
