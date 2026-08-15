# Bug Report — SELLER-004 (BUG-1)

Status: **fixed — ยืนยันแล้วโดย QA รอบ 2 (PASS, 2026-08-15)** — ดู `.wyn/tasks/approved/SELLER-004-store-management.md`'s "QA & Security Report — รอบ 2" สำหรับรายละเอียดการตรวจซ้ำอิสระเต็มรูปแบบ (Debug Output อยู่ท้ายไฟล์นี้)
Owner: AI Debug Engineer
Found by: AI QA & Security (SELLER-004 QA รอบ 1, 2026-08-15)
Severity: **Major (blocking)** — ทำให้หน้าร้านฝั่งลูกค้าใช้งานไม่ได้จริงบนมือถือทั่วไป

Bug: `StoreScreen` ฝั่งลูกค้า (`app/lib/features/zoky/presentation/store_screen.dart`) วาง banner (16:9 เต็มความกว้าง) + "ข้อมูลร้านค้า" section ใหม่ไว้ใน `Column` ที่ **ไม่ scroll ได้** ร่วมกับ `TabBar` + `Expanded(TabBarView)` — เมื่อร้านมี banner และข้อมูลร้าน (ที่อยู่/เบอร์/เวลาทำการ) ตามที่ SELLER-004 เพิ่งเปิดให้ seller กรอกได้ ความสูงส่วนหัวจะเกินความสูงจอบนมือถือขนาดทั่วไป ทำให้:

1. เกิด `RenderFlex overflowed ... on the bottom` จริง (แถบเหลือง-ดำใน debug build, เนื้อหาถูกตัดใน release build)
2. `Expanded(TabBarView)` ถูกบีบเหลือ **ความสูง 0.0** → **แท็บ "สินค้าทั้งหมด" และ "รีวิว" ไม่แสดงเนื้อหาใด ๆ เลย** (วัดได้: `ProductGridTile` count = 0) — ลูกค้ามองไม่เห็นสินค้าของร้านนั้นและกดซื้อไม่ได้เลย ทั้งที่หน้าร้านคือทางเข้าหลักของการขาย

นี่ไม่ใช่ปัญหาความสวยงามระดับ cosmetic overflow และไม่ใช่แค่ปัญหาบน viewport ของ widget test (800x600) ตามที่ Coding Output ระบุไว้เป็น "Known issue" — วัดจริงแล้วเกิดบนขนาดจอมือถือจริงที่ใช้กันทั่วไป

Reproduction (วัดจริงด้วย widget test ที่ QA เขียนขึ้นเอง ตั้ง `tester.view.physicalSize` ตามขนาดจอจริง `devicePixelRatio = 1.0` ไม่ใช่ค่า default 800x600):

1. สร้าง `Store` ที่มี `bannerUrl` ไม่ null + `address`/`contactPhone`/`businessHours` ครบ (ค่าที่ใช้เป็นข้อมูลจริงตามปกติ ไม่ใช่ค่าสุดขั้ว: ที่อยู่ไทยมาตรฐาน 65 ตัวอักษร `'123/45 หมู่ 6 ถนนพหลโยธิน แขวงจตุจักร เขตจตุจักร กรุงเทพมหานคร 10900'` — ต่ำกว่าเพดาน DB 300 ตัวอักษรมาก)
2. `pumpWidget(MaterialApp(home: StoreScreen(...)))` แล้ว `pumpAndSettle()`
3. ดัก `FlutterError.onError` เก็บ error ทุกตัว (ห้ามใช้ `tester.takeException()` เพราะมันกลืน exception ตัวเดียวและกลบ overflow ไว้ใต้ error ของ `Image.network`) แล้ววัด `tester.getSize(find.byType(TabBarView).first).height`

ผลวัดจริง (Flutter 3.47.0, `flutter test`):

| ขนาดจอ (logical px) | เคส | ผล | ความสูง TabBarView | ProductGridTile |
|---|---|---|---|---|
| 360x640 (Android เล็ก) | baseline ก่อน SELLER-004 (ไม่มี banner/ข้อมูล) | NO-OVERFLOW | 294.0 | 1 |
| 360x640 | banner + ข้อมูลจริง 3 ฟิลด์ | **overflow 169 px** | **0.0** | **0** |
| 375x667 (iPhone SE) | banner + ข้อมูลสั้น 3 ฟิลด์ | **overflow 50 px** | **0.0** | **0** |
| 390x844 (iPhone 14) | banner + ข้อมูลจริง 3 ฟิลด์ | NO-OVERFLOW | 38.6 (เหลือพื้นที่สินค้าแค่ ~39px) | 1 |
| 390x844 | banner + ข้อมูลจริง + `textScaler 1.3` (accessibility) | **overflow 125 px** | **0.0** | **0** |
| 430x932 (iPhone 15 Pro Max) | banner + ข้อมูลจริง + `textScaler 1.3` | **overflow 7.9 px** | **0.0** | **0** |
| 360x640 | ที่อยู่ยาว ~280 ตัวอักษร (ยังต่ำกว่าเพดาน DB 300) ไม่มี banner ด้วยซ้ำ | **overflow 366 px** | **0.0** | **0** |
| 390x844 | ที่อยู่ยาว ~280 ตัวอักษร ไม่มี banner | **overflow 102 px** | **0.0** | **0** |
| 667x375 / 844x390 (แนวนอน) | banner อย่างเดียว | **overflow 318 / 403 px** | **0.0** | **0** |

จุดสำคัญ: **แถว baseline (ร้านที่ไม่มีฟิลด์ใหม่เลย) ไม่ overflow ในทุกขนาดที่ทดสอบ** — ปัญหานี้เกิดขึ้นเฉพาะเมื่อใช้ฟีเจอร์ที่ SELLER-004 เพิ่งเพิ่มเข้ามา ซึ่งก็คือกรณีที่ทุกร้านจะเป็นหลังจากฟีเจอร์นี้ขึ้นจริง

Expected: ลูกค้าเปิดหน้าร้านที่มี banner + ข้อมูลร้านครบบนมือถือ 360x640/375x667 (หรือจอใหญ่กว่านั้นที่ตั้ง font ใหญ่) แล้วยังเห็น/เลื่อนดูรายการสินค้าและรีวิวได้ตามปกติ ไม่มี render overflow

Actual: ส่วนหัว (banner + header + info card) กิน `Column` จนหมด `Expanded(TabBarView)` เหลือความสูง 0 → รายการสินค้า/รีวิวหายไปทั้งหมด + เกิด RenderFlex overflow

Root Cause (วิเคราะห์เบื้องต้นโดย QA — ให้ Debug Engineer ยืนยันเองอีกครั้ง): โครงเดิมจาก ZOKY-001 คือ
```
Column([
  _buildHeader(...),          // ความสูงคงที่เล็กพอในตอนนั้น
  TabBar(...),
  Expanded(TabBarView(...)),  // กินพื้นที่ที่เหลือ
])
```
ส่วนหัวไม่เคยอยู่ในพื้นที่ scroll ได้เลยตั้งแต่แรก — ตอน ZOKY-001 ไม่มีปัญหาเพราะส่วนหัวเตี้ยและความสูงเกือบคงที่ (โลโก้+ชื่อ+description สั้น) SELLER-004 แทรกของสูงและ **ความสูงแปรผันตามข้อมูลผู้ใช้** เข้าไป 2 ก้อน (banner 16:9 = 56.25% ของความกว้างจอ ≈ 203px บนจอกว้าง 360, และ info card ที่ยาวได้ถึง 300+50+200 ตัวอักษร) ทำให้ส่วนหัวโตเกินจอได้ง่ายมาก ขณะที่ `Expanded` ยอมถูกบีบเหลือ 0 ก่อนที่ `Column` จะรายงาน overflow

Fix (แนวทางที่ QA แนะนำ — ต้องให้ AI Design ยืนยัน layout ก่อนลงมือ เพราะ Design spec ของ SELLER-004 จำกัดขอบเขตไว้ที่ "แทรก 2 จุด ห้ามแตะ TabBar/AppBar" ซึ่งไม่ครอบคลุมกรณีนี้):
- **แนวทาง A (แนะนำ)**: ทำให้ banner + header เลื่อนขึ้นไปพร้อมการ scroll โดยใช้ `NestedScrollView` + `SliverToBoxAdapter`/`SliverAppBar` + `SliverPersistentHeader` สำหรับ `TabBar` (pattern มาตรฐานของ Flutter สำหรับ "header + TabBar + TabBarView") — แก้ได้ทั้ง banner และ info card ที่ยาวเท่าไหร่ก็ได้ และแก้เคสแนวนอน/ฟอนต์ใหญ่ไปพร้อมกัน แต่กระทบโครง `build()` ของ `StoreScreen` มากที่สุด ต้องรัน regression suite เดิมของ ZOKY-001 ครบ
- **แนวทาง B (เล็กกว่า แต่แก้ไม่หมด)**: จำกัดความสูง banner ด้วย `ConstrainedBox(maxHeight: ...)` แทน `AspectRatio` ล้วน + `maxLines`/`overflow: TextOverflow.ellipsis` ให้ที่อยู่/เวลาทำการ — ลดโอกาสเกิด แต่ยังพังได้เมื่อ font scale ใหญ่หรือจอเตี้ยมาก และทำให้ข้อมูลบางส่วนถูกตัดหายไปจากสายตาลูกค้า
- **ห้ามแก้ด้วยการซ่อน banner/section บนจอเล็ก** (จะขัดกับ Acceptance Criteria ของ SELLER-004 ที่ต้องการให้ข้อมูลเหล่านี้ปรากฏจริงฝั่งลูกค้า)

Files Changed (คาดการณ์): `app/lib/features/zoky/presentation/store_screen.dart` (+ อาจต้องแก้ `.wyn/docs/design/seller-004-store-management.md` ถ้า Design อนุมัติให้ปรับโครง)

Tests ที่ต้องเพิ่มตอนแก้ (regression memory): เพิ่มเคสใน `app/test/store_screen_test.dart` ที่
1. ตั้ง `tester.view.physicalSize = Size(360, 640)` (และ 375x667) `devicePixelRatio = 1.0`
2. render ร้านที่มี banner + address/contact/hours ครบ
3. ยืนยัน **ไม่มี** FlutterError ที่มีคำว่า `overflowed` (ต้องดักผ่าน `FlutterError.onError` เอง ไม่ใช่ `tester.takeException()` ที่กลืน exception เพียงตัวเดียว)
4. ยืนยัน `tester.getSize(find.byType(TabBarView).first).height > 0` และหา `ProductGridTile` เจอจริง

Regression Risk: ปานกลาง-สูง — `StoreScreen` เป็นโค้ดที่ผ่าน QA มาแล้วจาก ZOKY-001 และมี test suite เดิมหลายเคส (รวมเคส Products tab/Reviews tab/Share/Copy Link/rating header) ถ้าเลือกแนวทาง A ต้องรัน `app/` ทั้ง 265 เคสให้ผ่านครบและตรวจว่า TabBar ยังอยู่ตำแหน่งเดิมเชิงพฤติกรรม

Handoff to QA: หลังแก้ ให้ QA รอบ 2 ตรวจซ้ำด้วยตารางขนาดจอชุดเดียวกันข้างบนทั้งหมด (รวมเคส `textScaler 1.3` และแนวนอน) + รัน `app/`/`seller_app/` เต็มทั้งสองชุด

---

## Debug Output (AI Debug Engineer — 2026-08-15)

```
Bug: StoreScreen ฝั่งลูกค้าวาง banner 16:9 + section "ข้อมูลร้านค้า" (SELLER-004) ไว้ใน Column ที่ scroll ไม่ได้ ร่วมกับ TabBar + Expanded(TabBarView) → ส่วนหัวสูงเกินจอมือถือจริง ทำให้ Expanded ถูกบีบเหลือ 0.0 แท็บสินค้า/รีวิวไม่แสดงอะไรเลย

Reproduction (ทำเองก่อนแก้ ไม่ได้เชื่อ bug report เฉย ๆ):
  เขียน widget test ที่ตั้ง tester.view.physicalSize เป็นขนาดจอมือถือจริง (devicePixelRatio = 1.0), ดัก FlutterError.onError เก็บ error ทุกตัวเอง (ไม่ใช้ tester.takeException()), แล้ววัด tester.getSize(find.byType(TabBarView)).height + นับ ProductGridTile ที่ถูก layout จริง
  ผลวัดเองก่อนแก้ (Flutter 3.47.0) — ยืนยันบั๊กตรงตามที่ QA รายงานทุกเคส:
    | ขนาดจอ / เคส                                  | overflow      | TabBarView | ProductGridTile |
    | 360x640 banner + ที่อยู่/เบอร์/เวลาทำการ       | 129 px        | 0.0        | 0 |
    | 375x667 banner + ข้อมูลสั้น                    | 50 px         | 0.0        | 0 |
    | 390x844 banner + ข้อมูล + textScaler 1.3      | 73 px         | 0.0        | 0 |
    | 430x932 banner + ข้อมูล + textScaler 1.3      | ไม่ overflow   | 44.1       | 1 |
    | 360x640 ที่อยู่ 280 ตัวอักษร ไม่มี banner       | 166 px        | 0.0        | 0 |
    | 667x375 แนวนอน banner อย่างเดียว               | 318 px        | 0.0        | 0 |
    | 390x844 banner + ข้อมูล (textScaler 1.0)      | ไม่ overflow   | 78.6       | 1 |
    | 360x640 baseline (ไม่มี banner/ข้อมูล)          | ไม่ overflow   | 294.0      | 1 |
  ตัวเลข overflow ต่างจากตาราง QA เล็กน้อยในบางแถวเพราะ fixture คนละชุด (description/จำนวนฟิลด์ที่กรอกต่างกัน) แต่อาการตรงกันทุกเคส และแถว baseline ยืนยันเหมือนกันว่าไม่พังก่อน SELLER-004
  ยืนยันเพิ่มเติมว่าเหตุที่ test เดิม 265/265 เขียว: `tester.takeException()` คืน exception ได้ทีละตัว และไฟล์เทสต์นี้ใช้มันอยู่แล้วเพื่อกลืน error ของ Image.network → RenderFlex overflow ถูกกลบไว้ข้างใต้เงียบ ๆ (ตอนรัน red run เห็น "A RenderFlex overflowed by 288 pixels" โผล่จากเทสต์เดิมที่เคยเขียวด้วยซ้ำ)

Root Cause (ยืนยันเองจากโค้ดจริง ไม่ได้ลอกจาก bug report):
  โครงจาก ZOKY-001 คือ Column([header, TabBar, Expanded(TabBarView)]) ที่ไม่มีพื้นที่ scroll เลย — header เดิมเตี้ยและความสูงเกือบคงที่จึงไม่มีปัญหา SELLER-004 แทรกของที่ความสูง "แปรผันตามข้อมูลของ seller" เข้าไป 2 ก้อน (banner 16:9 = 56.25% ของความกว้างจอ + info card ที่ยาวได้ถึง 300+50+200 ตัวอักษร และโตอีกเมื่อ textScaler > 1) — Expanded จะยอมหดเหลือ 0 ก่อนที่ Column จะรายงาน overflow เสมอ อาการที่ผู้ใช้เจอ (เนื้อหาหายทั้งแท็บ) จึงรุนแรงกว่าคำว่า "overflow N px"

Fix (แนวทาง A ตามที่ QA แนะนำ — Founder อนุมัติให้ปรับโครง header/TabBar ได้ในรอบนี้):
  1. เปลี่ยน body ของ StoreScreen จาก Column เป็น NestedScrollView
     - headerSliverBuilder: SliverToBoxAdapter(banner + _buildHeader เดิม ไม่แก้เนื้อหาข้างใน) + SliverPersistentHeader(pinned) ที่ถือ TabBar ตัวเดิม (แท็บ/ไอคอน/ข้อความเดิมทุกตัว)
     - body: TabBarView ตัวเดิม
     → ส่วนหัวเลื่อนหายไปได้ ไม่มี Column บีบใครอีก, TabBar ปักหมุดอยู่บนสุดเสมอ, tab content ได้ความสูงเต็มจอที่เหลือ
  2. ครอบ SliverPersistentHeader ด้วย SliverOverlapAbsorber + ใส่ SliverOverlapInjector ที่หัวของแต่ละแท็บ (pattern มาตรฐานของ NestedScrollView) — เจอตอนวัดเองว่าถ้าไม่ทำ แถวสินค้าแถวแรกจะไหลไปอยู่ "ใต้" TabBar ที่ปักหมุดและกดไม่โดน (test 'products are still tappable' จับได้จริง)
  3. แต่ละแท็บเปลี่ยนจาก GridView.builder/ListView.builder เป็น CustomScrollView + SliverGrid/SliverList (padding/empty state/loading state/ProductGridTile/ReviewTile เหมือนเดิมทุกอย่าง) เพื่อให้ใส่ SliverOverlapInjector ได้
  ไม่แตะ data layer, ไม่แตะ supabase/schema.sql, ไม่แตะ AppBar/Share/Copy Link, banner + section "ข้อมูลร้านค้า" ยัง conditional เหมือนเดิมทุกประการ

  Minor issue #1 ของ QA (image bytes ไม่ถูกล้างหลังบันทึกสำเร็จ) แก้ด้วยในรอบนี้: `SellerStoreScreen._save()` ล้าง _logoBytes/_bannerBytes (+ extension) หลัง onStoreUpdated สำเร็จ — ปลอดภัยเพราะ preview fallback ไปที่ widget.store.logoUrl/bannerUrl ที่ parent เพิ่งอัปเดตให้แล้ว (SellerHomeShell._store) กดบันทึกซ้ำจึงไม่อัปโหลดรูปเดิมซ้ำเป็น orphan อีก
  Minor issue #2 (ลบโลโก้/แบนเนอร์ออกไม่ได้) **ไม่แก้ในรอบนี้** — ต้องแก้ทั้ง repository (ส่ง null ให้คอลัมน์), UI (ปุ่มลบ + ยืนยัน), และควรลบไฟล์ใน bucket ด้วย = ฟีเจอร์ใหม่ ไม่ใช่ bug fix เล็ก บันทึกเป็น fast-follow ไว้ใน .wyn/tasks/backlog/SELLER-004-store-management.md

Files Changed:
  - app/lib/features/zoky/presentation/store_screen.dart (โครง body + 2 tab builder + _StoreTabBarHeaderDelegate ใหม่)
  - app/test/store_screen_test.dart (+11 regression test, เทสต์เดิม 15 เคสไม่แก้เลย)
  - seller_app/lib/features/store/presentation/seller_store_screen.dart (ล้าง image bytes หลังบันทึกสำเร็จ)

Tests (red→green proof):
  - ก่อนแก้: 16 passed / 10 failed (เทสต์ใหม่ 10 ใน 11 เคส FAIL — เคสที่ผ่านคือ 390x844 textScaler 1.0 ซึ่งตรงกับตาราง QA ที่ระบุว่าเคสนั้น "ไม่ overflow แต่เหลือพื้นที่แค่ ~39px")
  - หลังแก้: app/ 276/276 ผ่าน (265 เดิม + 11 ใหม่), seller_app/ 67/67 ผ่าน, `flutter analyze` สะอาดทั้ง 2 แอป
  - เทสต์ใหม่ assert "ความสูงจริง" ไม่ใช่ "ไม่มี exception": TabBarView ต้องสูง > 0 **และ** >= ครึ่งหนึ่งของความสูงจอ (จับเคส 38.6px/44.1px ที่เคยหลุดไปได้ด้วย) + ProductGridTile ต้องถูก layout จริง + ไม่มี FlutterError ที่มีคำว่า 'overflowed' ตลอดทั้งเทสต์ (รวมช่วง drag/tap ไม่ใช่แค่ตอน pump แรก)

Regression Risk: ปานกลาง — โครง build() ของ StoreScreen เปลี่ยนจริง แต่พฤติกรรมที่ ZOKY-001/ZOKY-004 QA เคยอนุมัติถูกคุมด้วยเทสต์เดิมทั้ง 15 เคสที่ไม่ได้แก้แม้แต่บรรทัดเดียว (แท็บสินค้า/รีวิว, กดสินค้าเข้า ProductDetailScreen, empty state ทั้งสองแท็บ, rating header, Share/Copy Link, Follow SnackBar, ไม่มีปุ่มแชท, ร้านที่ไม่มี banner/ข้อมูลต้อง render เหมือนก่อน SELLER-004) — ผ่านครบทุกเคส
  จุดที่เปลี่ยนพฤติกรรมโดยตั้งใจ (ต้องให้ QA ตรวจ): ตอนนี้ทั้งหน้า scroll ได้ ส่วนหัวเลื่อนหายไปพร้อมการ scroll และ TabBar ปักหมุดอยู่บนสุด — ค่าที่วัดได้หลังแก้ (ยังไม่เลื่อนหน้าจอเลย):
    | 390x844 banner + ข้อมูลครบ (จอทั่วไป)          | TabBarView 152.6 | เห็นสินค้าทันที ไม่ต้องเลื่อน (มีเทสต์คุม) |
    | 430x932 + textScaler 1.3                      | TabBarView 118.1 | เห็นสินค้าทันที |
    | 360x640 baseline (ร้านไม่มีฟิลด์ใหม่)           | TabBarView 368.0 | ดีกว่าเดิม (เดิม 294.0) |
    | 360x640 / 667x375 ที่ร้านมี banner + ข้อมูลครบ  | ส่วนหัวสูงเกิน 1 หน้าจอ | ต้องเลื่อนลงราว 1 หน้าจอจึงเห็นแท็บ/สินค้า |
  เคสสุดท้ายคือพฤติกรรมปกติของหน้าที่ scroll ได้ (แบบเดียวกับหน้าร้านของ marketplace ทั่วไป) ไม่ใช่ 0-height เดิมที่เลื่อนยังไงก็ไม่เจอสินค้า — เทสต์ใหม่ยืนยันว่าเมื่อเลื่อนแล้ว TabBarView ได้ความสูงอย่างน้อยครึ่งจอทุกเคส และกดสินค้า/สลับแท็บได้จริง

Handoff to QA: พร้อมให้ QA รอบ 2 ตรวจซ้ำด้วยตารางขนาดจอชุดเดิมทั้งหมด (รวม textScaler 1.3 และแนวนอน) + รัน app/ 276 เคส และ seller_app/ 67 เคสเต็มทั้งสองชุด
```
