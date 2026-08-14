# Design Spec — ZOKY-002: Search & Filter

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout ของ Instagram/TikTok/Shopee/Lazada/TikTok Shop โดยตรง — filter bottom sheet ด้านล่างเป็น mobile UX convention ทั่วไป ไม่ใช่การก็อปปี้ layout เฉพาะของแอปคู่แข่งเจ้าใดเจ้าหนึ่ง)
อ้างอิง Product Spec: `.wyn/tasks/backlog/ZOKY-002-search-and-filter.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `SearchScreen`'s query box + debounce 400ms + `TabBar` (WYN-009), `SearchStateMessage` (WYN-009), `ProductGridTile`/`ChoiceChip` category row (ZOKY-001)

## ทิศทางภาพรวม: หน้าจอใหม่แยกจาก WYN Social Search แต่ยืม pattern เดิมทั้งหมด

`ZokySearchScreen` ไม่ reuse instance ของ `SearchScreen` เดิม (คนละ entry point ตาม Product spec) แต่ทุก interaction pattern (debounce, TabBar, empty/loading state) ต้องเหมือนกันเป๊ะเพื่อความคุ้นเคย — จุดใหม่จริงมีแค่ filter bottom sheet และ `StoreResultCard`

---

## Screen 1: `ZokySearchScreen`

Purpose: ค้นหา+กรอง+เรียง Product/Store

Components:
- AppBar: query `TextField` เต็มความกว้าง (autofocus ตอนเปิดหน้า) มิเรอร์ query box บนสุดของ `SearchScreen` (WYN-009) debounce 400ms เดียวกันเป๊ะ
- **TabBar 2 แท็บ**: `Tab(icon: Icons.inventory_2_outlined, text: 'สินค้า')` / `Tab(icon: Icons.storefront_outlined, text: 'ร้านค้า')` (ไอคอนร้านค้าใช้ตัวเดียวกับ ZOKY Bottom Nav tab เพื่อความสอดคล้อง)
- แถวควบคุมใต้ TabBar (แสดงเฉพาะแท็บ "สินค้า" เท่านั้น เพราะ Store ไม่มี category/price ให้กรอง): ปุ่ม **"ตัวกรอง"** (`OutlinedButton.icon(Icons.tune)`, แสดง badge ตัวเลขจำนวน filter ที่ active ถ้ามี) + ปุ่ม **"เรียงลำดับ"** (`OutlinedButton.icon(Icons.sort)` เปิด `showMenu` แบบ dropdown ธรรมดา ไม่ใช่ bottom sheet เพราะตัวเลือกสั้นแค่ 3 อัน)
- ผลลัพธ์แท็บ "สินค้า": `GridView` 2 คอลัมน์ ของ `ProductGridTile` เดิมจาก ZOKY-001 ตรง ๆ (ราคาสำคัญที่สุดตอนเลือกซื้อ ต้องเห็นชัดแบบเดียวกับ ZOKY Home's main grid ไม่ใช่ list แถวเล็ก ๆ)
- ผลลัพธ์แท็บ "ร้านค้า": `ListView` แนวตั้งของ `StoreResultCard` (ใหม่ — แถวเต็มความกว้าง มิเรอร์โครงของ `ClubDiscoveryCard` (WYN-015) ทุกประการ: โลโก้วงกลม 40px ซ้าย + ชื่อร้าน (ตัวหนา) + "· N สินค้า" + คำอธิบายสั้น 1 บรรทัด ellipsis — ต่างจาก `StoreMiniCard` เดิมที่เป็นการ์ดแนวตั้งแคบ 96px ไม่เหมาะกับ list ผลค้นหาที่ต้องการรายละเอียดมากกว่า)
- Empty/loading state: มิเรอร์ `SearchStateMessage` เดิมของ WYN-009 ตรง ๆ ทั้ง 2 แท็บ ("พิมพ์ชื่อสินค้าเพื่อค้นหา"/"พิมพ์ชื่อร้านค้าเพื่อค้นหา" ตอนยังไม่พิมพ์, "ไม่พบสินค้า/ร้านค้าสำหรับ..." ตอนค้นหาแล้วไม่เจอ)
- Infinite-scroll pagination เดียวกับ pattern ของ `SearchDropResultsTab`/`ClubRepository.searchClubs` (debounce เดิมของ query box อยู่แล้ว ไม่ต้อง debounce ซ้ำตอน scroll)

Interaction: แตะการ์ดสินค้า → `ProductDetailScreen` เดิม, แตะการ์ดร้านค้า → `StoreScreen` เดิม (ทั้งคู่ reuse หน้าเดิมของ ZOKY-001 ตรง ๆ ไม่มีหน้าใหม่)

---

## Screen 2: Filter Bottom Sheet (แท็บ "สินค้า" เท่านั้น)

Purpose: กรอง Category + ช่วงราคา

Components: `showModalBottomSheet` (พื้นทึบ ไม่ blur ตามกติกาห้าม Liquid Glass) ความสูงพอดีเนื้อหา (ไม่ full-screen):
- หัวข้อ "ตัวกรอง" + ปุ่ม "ล้างตัวกรอง" (text button มุมขวา แสดงเฉพาะเมื่อมี filter active)
- **Category**: แถว `ChoiceChip` แนวนอน scroll ได้ ("ทั้งหมด" + 9 หมวดหมู่เดิมจาก `clubCategories`-เทียบเท่าของ ZOKY — คือ `categories` table ที่ seed ไว้แล้วใน ZOKY-001) เลือกได้ทีละอัน มิเรอร์ pattern เดิมของ `ExploreClubsScreen`/ZOKY Home เป๊ะ
- **ช่วงราคา**: 2 ช่อง `TextField` (`keyboardType: TextInputType.number`) เคียงกัน label "ราคาต่ำสุด"/"ราคาสูงสุด" คั่นด้วยเส้น "–" ตรงกลาง (เลือกใช้ text field คู่แทน `RangeSlider` เพราะผู้ใช้ที่รู้ช่วงราคาที่ต้องการอยู่แล้วพิมพ์ตัวเลขตรง ๆ ได้แม่นยำกว่า และไม่ต้องรู้ range สูงสุด-ต่ำสุดของสินค้าทั้งระบบล่วงหน้าแบบที่ slider ต้องมี — ทั้งคู่ optional ใส่แค่ต่ำสุดหรือสูงสุดอย่างเดียวก็ได้)
- ปุ่ม "แสดงผลลัพธ์" (`FilledButton`, เต็มความกว้าง, bottom-anchored ตาม design-principles.md) ปิด sheet แล้ว apply filter ทันที

Accessibility: ทุก touch target ≥44px ตาม design-principles.md, `TextField` มี `labelText` ชัดเจนสำหรับ screen reader

---

## Screen 3: Sort Menu (แท็บ "สินค้า" เท่านั้น)

Components: `showMenu` แบบ dropdown ธรรมดา (ไม่ใช่ bottom sheet เพราะแค่ 3 ตัวเลือก) ต่อจากปุ่ม "เรียงลำดับ": "ใหม่ล่าสุด" (ค่าเริ่มต้น) / "ราคา: ต่ำ → สูง" / "ราคา: สูง → ต่ำ" — เลือกแล้ว apply ทันทีไม่ต้องกด "ตกลง" ซ้ำ (ต่างจาก Filter ที่ต้องกด "แสดงผลลัพธ์" เพราะ Filter มีหลายค่าต้องตั้งพร้อมกัน แต่ Sort เป็นค่าเดียวเปลี่ยนแล้ว apply ได้เลยไม่มี ambiguity)

---

## ZOKY Home integration (แก้จุดเดิม)

- **Search bar**: แตะแล้วเปิด `ZokySearchScreen` แทนที่ `SnackBar` "เร็ว ๆ นี้" เดิม
- **Category chip**: แตะแล้วเปิด `ZokySearchScreen` พร้อม `initialCategory` ตั้งค่าไว้แล้ว (Filter sheet ไม่ต้องเปิดอัตโนมัติ แค่ผลลัพธ์กรองไว้แล้วตั้งแต่เข้าหน้า) แทนที่ `SnackBar` เดิม

---

## Design Rules

- ทุกจุดของ ZOKY-002 reuse pattern เดิม 100% ที่ทำได้: debounce query box, `TabBar`, `SearchStateMessage`, `ChoiceChip` category row, `ProductGridTile` — จุดใหม่จริงมีแค่ `StoreResultCard` และ Filter bottom sheet/Sort menu (เป็น interaction pattern ใหม่ครั้งแรกในโปรเจกต์ แต่เป็น mobile convention สากล ไม่ใช่ branding ของแอปคู่แข่งเจ้าใดเจ้าหนึ่ง)
- สี/ตัวอักษร/spacing ทั้งหมดตาม `design-principles.md` เดิม
- ไม่มีหน้าจอไหนใน ZOKY-002 เป็น Bottom Nav tab ใหม่ (`ZokySearchScreen` เข้าถึงผ่าน search bar/category chip ของ ZOKY Home เท่านั้น)

## Handoff: AI Coding —

1. `ZokyRepository` ต้องมี `searchProducts({query, category, minPrice, maxPrice, sortBy, page})` และ `searchStores({query, page})` — ILIKE บน `name` เหมือน `ClubRepository.searchClubs`, sort ผ่าน `.order()` ตรง ๆ (`created_at desc` default, `price asc`/`price desc` ตัวเลือก), filter ผ่าน `.gte()`/`.lte()`/`.eq('category_id', ...)` ต่อเมื่อมีค่า
2. Widget ใหม่: `StoreResultCard` (มิเรอร์ `ClubDiscoveryCard` โครง), Filter bottom sheet widget, Sort dropdown menu
3. เขียน regression test ครอบคลุมทุก AC: ค้นหาสินค้า/ร้านค้าได้ถูกต้อง (case-insensitive), กรอง Category/Price ถูกต้อง, เรียงลำดับทั้ง 3 แบบถูกต้อง, category chip จาก ZOKY Home ส่ง filter มาถูกต้อง, tap-through ไป Product Detail/Store เดิม, regression กับ ZOKY-001/WYN Social เดิมทั้งหมด
4. QA & Security ต้องตรวจ: ILIKE query ไม่มีช่องโหว่ (เทียบ pattern เดิมของ `ProfileRepository.searchProfiles`'s known Minor เรื่อง unescaped filter string — ตรวจว่า ZOKY-002 ไม่พลาดจุดเดียวกัน), price range filter ไม่ throw เมื่อใส่ค่าที่ไม่ใช่ตัวเลข/ค่าติดลบ, regression เต็มรูปแบบ

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement Screen 1-3 ข้างต้น — ดู Product spec `.wyn/tasks/backlog/ZOKY-002-search-and-filter.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
