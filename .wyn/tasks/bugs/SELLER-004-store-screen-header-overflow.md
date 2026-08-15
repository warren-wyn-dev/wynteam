# Bug Report — SELLER-004 (BUG-1)

Status: open (รอ AI Debug Engineer)
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
