# ZOKY Food Page (FoodHomeScreen) — CTO Final Review

> โดย WYN CTO | 2026-10-18 | branch `docs/zoky-foundation` @ `1f68a17` | ขอบเขต: `zoky_app/` หน้า Food (demo mode เท่านั้น)
> เป็น review แบบอ่านอย่างเดียว: ไม่ได้แก้ application code, ไม่ push, ไม่ deploy, ไม่ใช้ secrets/env และไม่ต่อ backend หรือฐานข้อมูลจริง

## 1. Verdict

**APPROVED WITH CONDITIONS** สำหรับหน้า Food ในฐานะ demo-mode UI slice บน branch นี้ ใช้เป็นฐานของงานถัดไป (ออกแบบหน้าร้าน/ค้นหา) ได้

- ไม่ใช่ staging/production approval เพราะยังไม่มี CI, signing และ backend wiring ทุกอย่างยังติด production freeze และต้องผ่าน Staging Gate กับ Founder Gate ตามปกติ
- ใน scope ของหน้า Food ไม่มี finding ระดับ CRITICAL หรือ HIGH ค้างอยู่ ZOKY-128..132 verified และปิดแล้ว
- ยังเปิดอยู่: ZOKY-133 (LOW), ZOKY-126 (LOW) และ ZOKY-134 (HIGH) ZOKY-134 อยู่นอก scope เพราะเกิดที่หน้าค้นหาและหน้าร้าน แต่**ไปถึงได้จากหน้า Food** ผ่านช่องค้นหา วงหมวดอาหาร และแถวร้าน จึงเป็นเงื่อนไขก่อน release (ข้อ 6)
- finding ใหม่ระดับ MEDIUM มี 2 ข้อ (F1, F2) ทั้งสองเกี่ยวกับโหมดรับเองที่ร้าน และต้องปิดก่อน production ไม่ block งานบน branch นี้

## 2. หลักฐานที่ตรวจจริง

| ตรวจ | ผล |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` (ทั้งชุด) | All tests passed: 1024 passed, 14 skipped (เป็น open-bug repro, screenshot ที่ต้องมี env และ won't-fix ZOKY-124), wall time ~3 นาที 17 วินาที (Home review ~151 วินาที ช้าลงราว 30%) |
| Dependencies | ไม่มีการเพิ่ม package ใน `pubspec.yaml` ระหว่าง `58f9bd3..HEAD` |
| Network / secrets | ไม่มี network call ใหม่ ข้อมูลมาจาก Demo repository ทั้งหมด (`DemoStoreRepository`, `DemoHomeContentRepository`, `DemoAddressRepository`) และไม่มีไฟล์ env/key ในส่วนที่เปลี่ยน |
| เงื่อนไขจาก Home review | C1 (sync docs) `ff8cb3d`, C2 (ตัด nav alternates) `2619219` และ C3 (ลบ legacy Home body และ `StoreFilter` ซ้ำ) ทำแล้ว ส่วน C4 (ช่องว่าง model สำหรับ Supabase) ยังเปิดอยู่และยังเป็น entry criteria ของ ZOKY-106 |

สิ่งที่ยังไม่ได้ตรวจ: การรันบนเครื่อง iOS/Android จริง, VoiceOver/TalkBack แบบ manual, frame timing บนเครื่อง Android ระดับล่าง และ web preview ในเบราว์เซอร์จริง

## 3. ไฟล์ที่ review

- `lib/features/food/**`: `food_home_screen.dart`, `collected_promos_controller.dart`, `widgets/` (header, address button, mode toggle, search field, category row, coupon section, store row, cart button)
- `lib/features/fulfillment/fulfillment_mode_controller.dart`
- `lib/core/widgets/zoky_line_icon.dart` (ใหม่), `zoky_3d_icon.dart` (เพิ่ม ticket และตัด nav glyph), `zoky_state_view.dart` (`glyph`), `zoky_chip.dart` (`unselectedStyle`), `zoky_glossy_heart_button.dart` (`icon`, `onTap`)
- `lib/features/address/**` (sheet, controller, demo repo), `lib/features/store/store_screen.dart` (`fulfillmentMode`), `lib/features/search/store_search_screen.dart` (`category`), `lib/app/app_dependencies.dart`, `lib/main.dart`, `catalog_models.dart` และ demo store data
- Tests: `test/food_home_screen_test.dart`, `test/food_header_icons_test.dart`, `test/semantics_tap_action_test.dart`, `test/qa/food_page_qa_test.dart`, `test/qa/food_page_retest_qa_test.dart`, `test/qa/zoky132_retest_qa_test.dart`

## 4. การตรวจตามหัวข้อ

### 4.1 Architecture fit — ผ่าน
- ตรงกับ architecture §3–6: state ใช้ `ChangeNotifier` ธรรมดา (`FulfillmentModeController`, `CollectedPromosController`, `DeliveryAddressController`) ส่งต่อผ่าน `AppDependencies` (InheritedWidget) ไม่มี state library หรือ router ใหม่
- ข้อมูลใหม่ผ่าน `abstract interface class` + Demo impl (`HomeContentRepository.fetchFoodCategories`, `AddressRepository`) ตาม §6.1 และไม่มี `Supabase.instance` ในโค้ด feature
- `supportsPickup` เป็นค่าเริ่มต้น `false` และเอกสารระบุว่าเป็น open contract item ซึ่งถูกต้อง เพราะไม่มีร้านใดอ้างว่ารับเองได้ถ้าไม่มีข้อมูล
- Home v1 คงเดิม: diff ของ `lib/features/home` จาก `ff8cb3d` มีแค่การลบ legacy body (C3), เปลี่ยนไอคอนเป็นแบบวาดเอง (ZOKY-128), เพิ่ม semantics `onTap` (ZOKY-132) และให้การ์ด hero กับปุ่ม "ค้นหาของอร่อย" เปิดหน้า Food ตามที่ Founder ชี้แจงไว้ใน DECISIONS 2026-10-18

### 4.2 ความเรียบง่ายและ duplication — ผ่าน มี cleanup เล็กน้อย
- ไม่มี abstraction เกินจำเป็น widget แยกตามส่วนของหน้า และ reuse ของเดิมจริง เช่น `ZokyChip`, `ZokyGlossyHeartButton`, `ZokyHomeSectionHeader`, `ZokyStoreCover`, `ZokyDemoBadge` และ `ZokyStateView`
- legacy `StoreFilter`/`_filtered` ใน Home ถูกลบแล้ว จึงเหลือ C04 filter ชุดเดียว
- ดู L1–L4 ในข้อ 5 (โค้ดซ้ำใน coupon card, logic ที่อยู่บน widget class และ helper ที่ไม่ได้ใช้)

### 4.3 Correctness และ state/race — ผ่าน
- request counter แยกต่อแหล่ง (`_storesRequest`, `_categoriesRequest`) ทิ้ง response เก่าที่มาช้ากว่า มี `mounted` guard ครบ และมี test ทั้งฝั่ง dev และ QA ("older directory response never overwrites a newer one", "retry tapped twice")
- ถ้า refresh ล้มเหลว list เดิมยังอยู่และแสดง SnackBar ส่วน retry จากหน้า error แสดง skeleton (ZOKY-131)
- สลับเป็นโหมด pickup แล้ว filter "ส่งฟรี" กลับไปเป็น "ทั้งหมด" (`_onModeChanged`) และมี test ครอบทุกลำดับการสลับ
- `DeliveryAddressController.load()` ไม่ทำซ้ำเมื่อโหลดแล้ว และ retry ได้หลัง error ส่วน `select()` ไม่รับที่อยู่ที่อยู่นอกรายการ
- ข้อสังเกต: F1 (pickup context หายเมื่อออกจากหน้า Food), L5 (ชีตคูปองระหว่างโหลด) และ L9 (sort ด้วย distance ดิบ)

### 4.4 Accessibility — ผ่านในระดับ widget test ต้อง spot check บนเครื่องจริง
- ลำดับการอ่านตรงกับลำดับบนจอ เพราะทุก sliver มี `OrdinalSortKey` (ZOKY-130) หน้ามี route name แม้ไม่มี title ที่มองเห็น
- ทุกปุ่มที่ใช้ `excludeSemantics` มี `onTap` แล้ว (ZOKY-132) และ test semantics-tap เทียบกับ finger-tap ผ่านบน Home, Food และชีต
- state ถูก expose ครบ: mode chips และตัวเลือกใน filter sheet ใช้ `selected` + `inMutuallyExclusiveGroup`, ปุ่มเก็บโค้ดใช้ `toggled`, ตอน header พับเกินครึ่งจะ `ExcludeSemantics` + `IgnorePointer`, และ reduced motion ปิด `AnimatedContainer`
- tap target ≥44pt, contrast บันทึกไว้ใน doc comment (≥4.5:1 สำหรับข้อความ) และ text scale ถึง 2.0 ไม่ overflow
- ที่ยังเหลือคือ ZOKY-133 #2/#3 (placeholder ถูกตัดและขนาดป้ายหมวดไม่เท่ากันเมื่อตัวอักษรใหญ่) ระดับ LOW และยังไม่ได้ทดสอบ VoiceOver/TalkBack จริง (เงื่อนไข P4)

### 4.5 Performance — ผ่าน
- รายการร้านใช้ `SliverList.builder` (lazy) header และ chips เป็น `SliverPersistentHeader` และ rebuild scope ของ address, mode toggle และคูปองจำกัดด้วย `ListenableBuilder`
- การเปลี่ยนโหมดใช้ `setState` ทั้งหน้า ซึ่งรับได้เพราะ `applyFilter` เป็น O(n) บนรายการขนาดเล็ก
- ข้อควรวัด (L7): ส่วนที่พับใน header ใช้ `Opacity` ค่ากลางทุก frame ขณะ scroll ทับไอคอน 3D ที่มี `MaskFilter.blur` ส่วน coupon row ใช้ `IntrinsicHeight` แต่จำกัดไว้ 4 การ์ด จึงรับได้

### 4.6 Founder decisions — ทำตาม ยกเว้น F1/F2
| Decision (DECISIONS 2026-10-18) | สถานะ |
|---|---|
| Home v1 คงเดิม, Food เป็นหน้าเต็มจอที่ push ทับ shell | ตรง |
| Pickup เป็นแค่ UI toggle ด้วยข้อมูลตัวอย่าง ไม่มี backend | ตรงในหน้า Food: ไม่มีการสร้างออเดอร์ ตะกร้าเป็น placeholder และ `supportsPickup` default false แต่ดู F2 (ก่อนใช้ข้อมูลจริง) |
| Pickup: หัว header เป็น "รับเองที่ร้าน ▾" และแตะแล้วยังเปิดรายการที่อยู่ | ตรง |
| Pickup: ซ่อนคูปอง/ป้าย/ตัวกรอง "ส่งฟรี" | ตรงในหน้า Food (`filtersFor`, `couponStores`, `_promo` ในแถวร้าน) **แต่ไม่ตรงในหน้าค้นหาและหน้าร้านที่เปิดจากหน้า Food** → F1 |
| ป้าย "ตัวอย่าง" ต้องมีเสมอ | ตรง: แถวร้าน, การ์ดคูปอง, ที่อยู่ demo (ไม่ถูกตัดข้อความ, ZOKY-129) และมี test "demo labelling" |
| ไม่มีคะแนน/ETA/โปรปลอม | ตรง: คะแนนแสดงเมื่อ `ratingCount > 0`, ETA แสดงเมื่อมี `etaMin/Max` (ไม่มี fallback 15/30), ระยะทางที่ผิดปกติถูกซ่อน และคูปองมาจากโปรของร้านเท่านั้น |

### 4.7 Test quality — ดี แต่หนัก
- ครอบคลุมดี: ลำดับ, header actions, address, pickup (filter, coupon, label, store page fee), race, refresh, states, layout matrix, semantics order และ tap equivalence, hostile data และไอคอนที่ไม่พึ่ง font
- open bug ถูก reproduce ไว้ด้วย `skip: true` พร้อม bug id (ZOKY-133 #1, ZOKY-134) ซึ่งถูกต้องตาม QA pattern
- debt: `food_home_screen_test.dart` ยาว 1361 บรรทัด และกลุ่ม "ZOKY-131" ซ้ำกับ `qa/food_page_retest_qa_test.dart` (เช่น pickup fee และ cart ทับเก็บโค้ด) ส่วน landscape cases ของ ZOKY-120 re-test ยังอยู่ (เช่น `568x320`) แม้แอปล็อกแนวตั้งแล้ว ตอนนี้มี tag `qa-heavy` ใน `dart_test.yaml` แล้ว ซึ่งช่วยได้

## 5. Findings ตามระดับความรุนแรง

### CRITICAL — ไม่มี

### HIGH — ไม่มีใน scope
- (carried, นอก scope) **ZOKY-134**: การ์ดใน grid ผลค้นหา, ปุ่ม "เพิ่ม" และแถบตะกร้าในหน้าร้านไม่มี semantics tap action ไปถึงได้จากหน้า Food จึงเป็นเงื่อนไข P1

### MEDIUM
- **F1 — Pickup context หายเมื่อออกจากหน้า Food** (ควรเปิดเป็น bug ZOKY-135 ให้ QA)
  - ช่องค้นหาและวงหมวดอาหารเปิด `StoreSearchScreen(repository, …)` โดยไม่ส่งโหมด (`food_home_screen.dart` `_openSearch`/`_openCategory`) ผลคือในโหมดรับเองที่ร้าน หน้าค้นหายังแสดงร้านที่ไม่รับ pickup, แสดง "ค่าส่ง" และป้ายโปร "ส่งฟรี" (`zoky_store_card.dart` ~l.137 และ ~l.224, เช่น demo-store-2) และเปิด `StoreScreen` ด้วยค่าเริ่มต้นเป็น delivery (แสดงค่าส่ง) ซึ่งขัดกับ Founder decision "โหมดรับเองซ่อนป้าย ส่งฟรี"
  - ต้นเหตุเชิงออกแบบ: `StoreScreen` รับ `fulfillmentMode` เป็นค่า snapshot ผ่าน constructor ทั้งที่แอปมี `AppDependencies.fulfillmentMode` อยู่แล้ว จึงมีแหล่งความจริงสองแหล่ง
  - สิ่งที่ต้องแก้: ให้ `StoreSearchScreen` และ `StoreScreen` อ่านและ listen `AppDependencies.of(context).fulfillmentMode` เอง แล้วลบพารามิเตอร์ `fulfillmentMode` ใช้กฎเดียวกับหน้า Food (pickup = ร้าน `supportsPickup`, ซ่อนค่าส่ง/ETA/โปรส่งฟรี) โดยดึง logic เป็น pure function ตัวเดียว (ดู L3) ทำพร้อม ZOKY-133 #1 และ ZOKY-134 ในงานออกแบบหน้าร้าน/ค้นหา
- **F2 — Pickup toggle กับข้อมูลจริง**
  - backend ยังไม่มี field pickup (`supportsPickup` เป็น open contract item) เมื่อเปลี่ยนเป็น Supabase repository ทุกร้านจะเป็น `false` และโหมดรับเองจะแสดง "ยังไม่มีร้านในพื้นที่นี้" ซึ่งทำให้เข้าใจผิด และ toggle จะสื่อว่ามีบริการที่ยังไม่มีจริง
  - สิ่งที่ต้องแก้ก่อนต่อข้อมูลจริง: ซ่อน toggle (และ `FulfillmentModeController` ล็อกเป็น delivery) ด้วย flag ที่ผูกกับ demo mode หรือ config จนกว่างาน pickup backend จะผ่าน workflow ครบ (PM → Architect → Database → Full-Stack → QA และ migration ได้รับ Founder approval)

### LOW
- **L1 — โค้ดซ้ำใน `ZokyFoodCouponCard`**: branch compact และปกติ copy คอลัมน์ข้อความกับ semantics (ราว 55 บรรทัด) ไว้ทั้งคู่ ควรแยกเป็น private widget `_CouponCopy` ตัวเดียว
- **L2 — DI ปนกัน**: `FoodHomeScreen` รับ `StoreRepository` ผ่าน constructor แต่ดึง `homeContentRepository` และ controllers จาก `AppDependencies` ภายใน state (`_loadCategories` resolve deps ใน async method) ควรเลือกแบบเดียว ส่วน `_mode` bind ครั้งเดียวใน `didChangeDependencies` จึงไม่ rebind ถ้า `AppDependencies` ถูกแทนที่ (กระทบเฉพาะ test)
- **L3 — Logic ล้วนอยู่บน widget class**: `StoreFilter`, `filtersFor`, `applyFilter` (static บน `FoodHomeScreen`) และ `couponStores` ควรย้ายไปไฟล์ pure Dart (เช่น `features/food/domain/store_filters.dart`) ก่อนที่หน้าค้นหาหรือ "ร้านทั้งหมด" จะใช้ซ้ำ และใช้ร่วมกับ F1
- **L4 — โค้ดตายและ doc ที่ไม่ตรง**: `ZokyFoodAddressButton.textHeightFor` ไม่ถูกเรียก (คำนวณซ้ำกับ `ZokyFoodHeader.rowHeightFor`); doc ของ `ZokyGlossyHeartButton.icon` เขียนว่า "orders shortcut" แต่จริงคือคูปอง; doc ของ `address_sheet.dart` เขียนว่า "opened from the Home address row" แต่ตอนนี้เปิดจาก Food header; fallback `'อาหาร'` ใน `ZokyFoodStoreRow._category` ไม่ได้อยู่ใน `ZokyStrings`; และในโหมด pickup hint ของปุ่มที่อยู่ยังเป็น "เลือกที่อยู่จัดส่ง" (ยอมรับได้ตาม Founder แต่ควรให้ PM ยืนยัน copy)
- **L5 — ชีตคูปองระหว่างโหลด**: ถ้าแตะไอคอนคูปองใน header ก่อน directory โหลดเสร็จ ชีตจะแสดง "ยังไม่มีโค้ดส่วนลด" (`_stores ?? const []` เป็น snapshot) และไม่อัปเดตเมื่อโหลดเสร็จ ควรแสดง loading/skeleton หรือส่งข้อมูลแบบ listenable
- **L6 — `liveRegion: true` บนปุ่มตะกร้า**: ถูกต้องเมื่อจำนวนเปลี่ยน แต่ต้องตรวจบนเครื่องว่าไม่ประกาศซ้ำตอน rebuild/scroll (รวมใน P4)
- **L7 — Performance ของ header ตอนพับ**: `Opacity` ค่ากลางทำ saveLayer ทุก frame ทับไอคอน 3D ที่มี blur ควรวัดบน Android ระดับล่าง ถ้า jank ให้ใช้ `FadeTransition` หรือ fade เฉพาะข้อความ
- **L8 — ไอคอนสองระบบ**: `ZokyLineIcon` (20 glyphs วาดเอง) เกิดจากกระบวนการ refresh preview ที่ copy แค่ `main.dart.js` ทำให้ font ค้าง ต้นเหตุจริงอยู่ที่ขั้นตอน deploy preview ซึ่งควรแก้ให้ copy ทั้ง `build/web` ขณะที่หน้าร้านและหน้าค้นหายังใช้ font icons อยู่ ยอมรับตาม ZOKY-128 แต่ไม่ควรเพิ่ม glyph วาดเองนอกจากที่จำเป็น และให้หน้าร้านใหม่เลือกระบบเดียว
- **L9 — Sort ใช้ distance ดิบ**: `applyFilter` sort ด้วย `distanceKm` ดิบ ขณะที่การแสดงผลและ filter ใช้ค่าที่ sanitize แล้ว ค่าติดลบจึงขึ้นก่อน ให้ปิดพร้อม ZOKY-126 #8 (validate/clamp ที่ repository boundary)
- **ZOKY-133** (LOW, open): #1 ETA ในหน้าร้านโหมด pickup (รวมกับ F1), #2 placeholder ถูกตัดเมื่อตัวอักษรใหญ่, #3 ขนาดป้ายหมวดไม่เท่ากัน (รอ Design ตัดสิน)
- **ZOKY-126** (LOW, open): ตามเดิม

## 6. เงื่อนไขก่อน production (ต้องเป็นจริงทุกข้อ)

| # | เงื่อนไข | Owner | เมื่อไร |
|---|---|---|---|
| **P1** | ZOKY-134 แก้แล้วและ QA verified หรือ Founder ยอมรับความเสี่ยงเป็นลายลักษณ์อักษร เนื่องจากหน้า Food ลิงก์ไปหน้าค้นหาและหน้าร้าน ข้อนี้จึงใช้กับ release ใดก็ตามที่มีหน้า Food ด้วย | Full-Stack + QA | ก่อน release หน้าร้าน/ค้นหา (และหน้า Food) |
| **P2** | F1 + ZOKY-133 #1: โหมด pickup มีผลสม่ำเสมอในหน้าค้นหาและหน้าร้าน อ่านจาก controller เดียว ไม่มีป้ายส่งฟรี ค่าส่ง หรือ ETA ในโหมด pickup | Full-Stack + QA | ในงานออกแบบหน้าร้าน/ค้นหา |
| **P3** | F2: build ที่ใช้ข้อมูลจริงต้องซ่อน pickup toggle จนกว่างาน pickup backend จะผ่าน workflow และ gates ครบ (รวม migration ที่ Founder อนุมัติ) ห้ามมี UI ที่สื่อว่า pickup ใช้ได้จริงก่อนหน้านั้น | Architect + Full-Stack | ก่อน ZOKY-105/106 wiring |
| **P4** | Device screen-reader spot check บน VoiceOver (iOS) และ TalkBack (Android): ลำดับการอ่าน (ZOKY-130), การ activate ทุกปุ่ม (ZOKY-132), selected/toggled ของ mode chips, filter sheet และปุ่มเก็บโค้ด, header ที่พับต้องไม่ถูกอ่าน, live region ของตะกร้า (L6) และ Voice Access "show numbers" บันทึกผลใน QA report | QA & Security | ก่อน Staging Gate |
| **P5** | วัด frame timing ตอน scroll หน้า Food บน Android ระดับล่าง (L7) ไม่มี jank ที่เห็นได้ | QA + Full-Stack | ก่อน Staging Gate |
| **P6** | เงื่อนไข real data จาก Home review C4 ยังมีผล (ETA/location, rating validation, promo formatter ตัวเดียวจาก raw `promo_*`, error contract) และเพิ่ม: คูปองต้อง map จาก `promo_name`/`promo_type`/`promo_min_subtotal` จริง, persist `CollectedPromosController` ต่อ user (ZOKY-105) และหมวดอาหารต้องมีแหล่งข้อมูลที่ PM/Founder กำหนด (ตอนนี้เป็น demo) | Architect + Full-Stack + Database | entry criteria ZOKY-106 |
| **P7** | Gate มาตรฐาน: CI, staging deploy และ verification, rollback plan, Founder approval ของ production deployment และการยกเลิก production freeze | DevOps + Founder | ก่อน production |

## 7. Tech-debt ที่แนะนำ (ไม่ block)

1. L1, L3, L4: cleanup เล็ก ๆ ทำพร้อม F1 ได้ในคราวเดียว
2. Test suite: ตัด landscape cases ที่ไม่ใช้แล้ว, รวมกลุ่ม ZOKY-131 ที่ซ้ำระหว่าง dev และ QA tests, แยก `food_home_screen_test.dart` ตามส่วน (header/pickup/list/states) และรันชุด `qa-heavy` ใน pre-merge/nightly
3. L8: แก้ขั้นตอน refresh web preview ให้ copy ทั้ง `build/web` และบันทึกไว้ใน runbook
4. L5, L2: ทำพร้อม ZOKY-106 เมื่อมี latency จริง

## 8. ความเสี่ยงที่เหลือ

- ยังไม่ได้ทดสอบบนเครื่องจริงหรือด้วย screen reader แบบ manual ผลทั้งหมดมาจาก widget tests และการอ่านโค้ด ซึ่งไม่ได้ยืนยันว่าไม่มี regression นอกเหนือจาก tests ที่รันผ่าน
- Pickup เป็น major scope change ที่ยังไม่มี backend contract ถ้าไม่มี P3 จะเสี่ยงต่อการสื่อสารกับผู้ใช้ผิด
- branch `docs/zoky-foundation` สะสม commit จำนวนมาก ควรแบ่ง PR และ merge ตาม `docs/engineering/GIT_WORKFLOW.md` เมื่อ Founder อนุมัติ
