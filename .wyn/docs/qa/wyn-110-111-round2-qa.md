# QA Report — WYN-110 (QA-WYN-110-001 fix) + WYN-111 (carousel center emphasis), รอบ 2

Owner: AI QA & Security
วันที่: 2026-09-05
Branch: `claude/home-button-ux-ui-design-cbjkzm`
Commit ที่ตรวจ: `7c2de18` (parents: `7c2bab4` → `de4b4b0`, ฐานที่ QA รอบ 1 เคยตรวจ)
Environment: `flutter test` / `flutter analyze` บน Linux, Flutter SDK `/opt/flutter-sdk/flutter`
(Flutter 3.48.0-1.0.pre-61 / Dart 3.13.2) — รันจริงทุกคำสั่งเอง ไม่เชื่อผลที่ Debug Engineer รายงานไว้

## Feature

1. **QA-WYN-110-001 fix** — แก้ infinite-scroll ยิง fetch หน้าถัดไปซ้ำหลายครั้งต่อการเลื่อน 1 ครั้ง ใน
   3 แท็บโปรไฟล์ (`profile_drop_grid_tab.dart`/`profile_redrops_tab.dart`/`profile_likes_tab.dart`) —
   ตั้ง `_isLoadingMore = true` แบบ synchronous ทันทีที่ตัดสินใจเลื่อนเรียก `_loadMore()`
2. **WYN-111** — carousel รูปภาพในโพสต์เลื่อนแบบ Threads: รูปตรงกลางเต็มขนาด (82% เดิม ไม่เปลี่ยน)
   รูปข้างเคียง scale ลงเหลือ 0.86 ไล่ระดับต่อเนื่องระหว่างลาก ผ่าน `Transform.scale` แบบ paint-only ใน
   `PostImageCarousel` (`core/widgets/post_media.dart`) ไม่แตะ `_CardSnapPhysics`/stride/caller เดิม

## ขอบเขตที่ตรวจสอบ (diff review, `git diff de4b4b0..HEAD`)

12 ไฟล์ ตรงกับที่อธิบายไว้ทุกจุด ไม่มีอะไรเกินขอบเขต:

- `app/lib/features/profile/presentation/widgets/{profile_drop_grid_tab,profile_redrops_tab,
  profile_likes_tab}.dart` — เพิ่มบรรทัดเดียว (`_isLoadingMore = true;`) + คอมเมนต์อธิบาย ที่เดียวกัน
  ทั้ง 3 ไฟล์ (โครงสร้างโค้ดเดิมเหมือนกันทุกไฟล์ตามที่รอบ 1 ระบุไว้) — อ่านเทียบกับ "Fix ที่เสนอ" ใน
  bug report แล้วตรงกันเป๊ะ ยืนยันด้วยการอ่าน `_loadMore()` เต็มฟังก์ชันว่า `finally` block ยัง reset
  `_isLoadingMore = false` เมื่อ mounted เหมือนเดิม (ไม่ค้าง true ถาวรกรณีปกติ)
- `app/lib/core/widgets/post_media.dart` — เพิ่ม `postCardPeekScale` (ค่าคงที่ 0.86), `_scaleFor()`
  (คำนวณ scale จากระยะห่าง scroll offset), `Transform.scale` รอบการ์ดใน `itemBuilder`, และ
  `setState({})` เพิ่มเติมใน `ScrollUpdateNotification` handler เพื่อ rebuild ต่อเนื่องระหว่างลาก —
  ยืนยันด้วย diff เต็มบรรทัดต่อบรรทัดว่า **ไม่มีการแตะ** `_CardSnapPhysics`, `_updateIndex`, `stride`
  calculation, หรือ `ScrollController`/physics assignment เดิมเลยแม้แต่บรรทัดเดียว
- `app/test/profile_likes_tab_test.dart`, `app/test/post_media_test.dart` — เทสต์ใหม่ของฝั่ง
  coding/debug เอง (ไม่แก้)
- `app/test/qa_wyn110_profile_scroll_header_test.dart` — ไฟล์ของ QA เอง แก้เพิ่มเติมโดย QA รอบนี้
  (ดูหัวข้อถัดไป)
- เอกสาร: `.wyn/docs/design/wyn-111-carousel-center-emphasis.md`,
  `.wyn/tasks/active/WYN-111-carousel-center-emphasis.md` (ใหม่),
  `.wyn/docs/qa/wyn-110-profile-scroll-header-qa.md`,
  `.wyn/tasks/bugs/WYN-110-{redundant-load-more-fetches,homedropcard-320px-action-row-overflow}.md`
  (ของรอบ 1 ที่ commit มาพร้อมกัน)

ยืนยันด้วย `git diff` แยกไฟล์ว่า **3 caller ของ `PostImageCarousel` ไม่ถูกแตะเลย**
(`home_feed_image_peek_carousel.dart`, `drop_image_gallery.dart`, `club_post_card.dart` — diff ว่าง
ทั้ง 3 ไฟล์) และ **`home_drop_card.dart` ไม่ถูกแตะเลย** (เกี่ยวกับ QA-WYN-110-002 ด้านล่าง)

## แก้ไฟล์เทสต์ของ QA เอง (`qa_wyn110_profile_scroll_header_test.dart`)

ตรวจสอบการวิเคราะห์ที่ Debug Engineer ทิ้งไว้ในหัวข้อ "Fix Applied — 2026-09-05" ของ bug report
independently: อ่าน Flutter framework source ตรง ๆ
(`flutter_test/lib/src/controller.dart:2417-2491`) ยืนยันว่า `scrollUntilVisible` แปลง `delta` เป็น
`moveStep = Offset(0, -delta)` สำหรับ `AxisDirection.down` และ `dragUntilVisible`'s docstring ระบุ
ชัดเจนว่า "a negative Offset.dy swipes up, revealing items below" — **สรุปว่าการวิเคราะห์ของ Debug
Engineer ถูกต้อง 100%**: `delta = -300` ที่ใช้เดิมเลื่อน**ถอยหลัง** ไม่ใช่เดินหน้า และรันซ้ำยืนยันแล้วว่า
ก่อนแก้ เทสต์ fail ที่ `StateError: Bad state: No element` บรรทัด `scrollUntilVisible(..., -300, ...)`
เป๊ะ ไม่ใช่ที่ `expect(...Calls, 2)` อีกต่อไป (พิสูจน์ว่า core fix ของบั๊กสำเร็จจริงแล้วก่อนหน้านี้)

แก้ `delta` จาก `-300` เป็น `300` ทั้ง 3 จุด (Posts/ReDrops/Likes) — หลังแก้พบบั๊กที่ 2 **ซ้อนอยู่ในเทสต์
ของ QA เอง** ที่ถูกบั๊กแรกบังไว้ตลอด: `expect(find.byType(HomeDropCard), findsNWidgets(pageSize + 2))`
เป็นการเช็คที่ผิดหลักการสำหรับ `CustomScrollView`/`SliverList.separated` ซึ่ง build widget แบบ lazy
(วัดได้จริง: เจอแค่ 4 widgets จาก 23 ที่คาดไว้ เพราะมีแค่แถวใน/ใกล้ viewport เท่านั้นที่ถูก mount) —
แก้เป็นเช็ค `findsOneWidget` ที่แถวสุดท้าย (พิสูจน์ไม่มี duplicate ที่ tail — ถ้า fetch ซ้ำจริงและไม่มี
dedup แถวซ้ำจะอยู่ติดกันในวิวพอร์ตเดียวกันตรงนี้พอดี) บวก scroll กลับไปเช็ค `findsOneWidget` ที่แถวแรก
ของ page 0 (พิสูจน์ไม่มี corruption ที่ head) — ไม่ลดความเข้มงวดของสิ่งที่พิสูจน์จริง เพราะ duplicate
`ValueKey` ยังถูกจับด้วย `tester.takeException()` ตลอดทั้งเทสต์เหมือนเดิม ลบ import
`home_drop_card.dart` ที่ไม่ใช้แล้วออกด้วย (`flutter analyze` เคยเตือน unused_import)

## Test Cases

### ยืนยัน QA-WYN-110-001 ปิดจริง — ไม่เชื่อเทสต์เดิมอย่างเดียว พยายาม break เพิ่ม

รันเทสต์เดิม 3 ตัว (กลุ่ม "4.") ยืนยันผ่านหลังแก้ delta ตามข้างต้น แล้วเพิ่มกลุ่ม "7." ใหม่ 3 testWidgets
ในไฟล์เดียวกัน โดยใช้ fake repo แยกอิสระของตัวเอง (ไม่ปนกับกลุ่ม 4) เพื่อลอง break guard fix ด้วยวิธีที่
ต่างจากที่เทสต์เดิมครอบคลุมไว้:

1. **Fast fling** (`tester.fling(..., Offset(0,-3000), 8000)`) — velocity สูงกว่า `tester.drag()` มาก
   synthesize pointer-move event หลายเฟรมต่อเนื่อง
2. **ลากหลายครั้งติดกันโดยไม่รอ settle** — 4 ครั้ง ครั้งละ `tester.pump()` เดียว (ไม่ใช่
   `pumpAndSettle()`) ระหว่างกลาง จำลองผู้ใช้ปัดนิ้วรัว ๆ
3. **สลับทิศทางกลางคัน** — ลากลงผ่าน threshold (-4000) แล้วลากขึ้นทันที (+1000) ก่อนเฟรมถัดไปจะเกิด
   (ไม่มี `pump()` คั่นระหว่าง 2 การลาก)

ทั้ง 3 กรณี: `fetchByAuthorCalls == 2` พอดี (page 0 + page 1 ครั้งเดียว) ไม่มี exception — **ไม่พบ
over-fetch หลุดออกมาในทุกกรณีที่ลองพยายาม break เพิ่มเติม**

### WYN-111 (เป็นฟีเจอร์ใหม่ ตรวจเต็มรูปแบบ)

อาศัยเทสต์ของ coding เองใน `post_media_test.dart` (128 บรรทัดใหม่, กลุ่ม "WYN-111: the card in front
reads larger") ซึ่งวัด**ขนาดที่ render จริง** (`tester.getRect`) ไม่ใช่แค่ค่า `Transform.scale` ที่
source เขียนไว้ — ตรวจอ่านโค้ดเทสต์เต็มแล้วเห็นว่าครอบคลุม:

1. ก่อนลาก: การ์ดหน้าเต็มขนาด 82% เดิม การ์ดถัดไปเล็กกว่าแล้วตาม `postCardPeekScale`
2. กลางลาก (drag ค้างไว้ครึ่งทาง stride): การ์ดขาออก/เข้า อยู่ระหว่าง full/peek ไม่กระโดด
3. หลัง settle: มีการ์ดเต็มขนาดพอดี 1 ใบเสมอ ที่เหลือ recede
4. Flick ข้ามหลายการ์ด: การ์ดหน้ายังเด่นชัดกว่าที่เหลือ

รวมกับรัน 5 เทสต์เดิมของ carousel (82% width, snap boundary, flick-one-card, index reporting, last-card
stop) ซ้ำ — **ผ่านทั้งหมดโดยไม่ต้องแก้แม้แต่บรรทัดเดียว** พิสูจน์ว่า physics เดิมไม่ถูกกระทบจริงตามที่
design spec อ้าง

อ่าน diff `_scaleFor`/`itemBuilder` เทียบกับ design rules แล้วยืนยัน: `distance == 0` → scale ตรง 1.0
เป๊ะ (ไม่มีการขยายเกิน 82% เดิม), ไล่ระดับเชิงเส้นจริงผ่าน `.clamp(0.0, 1.0)`, ห่อด้วย `Transform.scale`
ไม่ใช่เปลี่ยน `width`/`SizedBox` ที่ประกาศไว้ (จึงไม่กระทบ stride ที่ physics คำนวณ) ตรงตาม Design Rules
ทุกข้อ

**Responsive**: `qa_round2_ui_regression_test.dart` (`QA-R2-22`, มีอยู่แล้ว) รัน `HomeDropCard` ที่มี
`imageCount: 3` (ผ่าน carousel ใหม่นี้) ที่ 320/360/390/430px × textScale 1.0/1.3 × 4 aspect ratio —
รันซ้ำทั้งหมดผ่านสะอาด ไม่มี overflow จากการเปลี่ยนแปลงของ WYN-111 เลยที่ความกว้างใดเลย (`Transform.scale`
เป็น paint-only และ scale สูงสุดคือ 1.0 พอดี — ไม่มีทางเกินกรอบที่ layout จองไว้แต่แรก จึงไม่มีความเสี่ยง
overflow จากงานนี้โดยธรรมชาติของวิธีทำ)

**Reuse 3 จุดโดยไม่แก้ call site**: ยืนยันด้วย `git diff de4b4b0..HEAD --stat` ว่า
`home_feed_image_peek_carousel.dart`, `drop_image_gallery.dart`, `club_post_card.dart` **ไม่ปรากฏใน
diff เลย** (ว่างทั้ง 3 ไฟล์) — อ่านทั้ง 3 ไฟล์แล้วยืนยันว่าทุกจุดยัง guard `imageUrls.length <= 1` ก่อน
เรียก `PostImageCarousel` เหมือนเดิม (WYN-111 ไม่กระทบเงื่อนไขนี้) และไม่มี wrapper ใดที่จะขัดกับ
`Transform.scale` ใหม่ (ไม่มี `ClipRect`/fixed-size ที่ scale สูงสุด 1.0 จะชนขอบ)

### Regression suite เต็ม

รันทั้งสองรอบ (ก่อน/หลังแก้ไฟล์เทสต์ของ QA เอง) — ไม่พบ regression ใหม่นอกเหนือจากที่ระบุ

## Passed

- QA-WYN-110-001: ยืนยันปิดจริงด้วยเทสต์เดิม (กลุ่ม 4, 3 แท็บ) + เทสต์ break-more ใหม่ 3 ตัว (กลุ่ม 7:
  fast fling / ลากติดกันไม่รอ settle / สลับทิศทางกลางคัน) — ทุกกรณี fetch หน้าถัดไปครั้งเดียวพอดี
- `_loadMore()`'s `finally` ยัง reset `_isLoadingMore = false` ปกติ, `CircularProgressIndicator` ท้าย
  list ยังทำงานถูกต้อง (ยืนยันผ่าน `scrollUntilVisible(find.byType(CircularProgressIndicator), ...)`
  ในเทสต์เดิมกลุ่ม 4)
- ไม่มี duplicate `ValueKey`/exception ใหม่ในทุกกรณีที่ทดสอบ (rapid drag, fling, reversal)
- WYN-111: การ์ดหน้าเต็มขนาด 82% เดิมเป๊ะ, การ์ดข้างเคียง scale ลงจริงตาม `postCardPeekScale` (0.86),
  ไล่ระดับต่อเนื่องระหว่างลากไม่กระตุก, snap/fling/`onIndexChanged` ทำงานเหมือนเดิมทุกประการ (5 เทสต์
  เดิมผ่านไม่ต้องแก้)
- Responsive 320/360/390/430px: ไม่มี overflow ใหม่จาก WYN-111 ที่ความกว้างใดเลย
- Reuse ถูกต้องใน 3 จุด (Home feed/Drop Detail/Club) โดยไม่แก้ call site เลยแม้แต่บรรทัดเดียว
- `flutter analyze`: **0 issues**
- `flutter test` เต็มชุด (หลังแก้ไฟล์เทสต์ของ QA เอง): **1163/1164 ผ่าน**

## Failed

ไม่มีบั๊กใหม่ที่เกิดจาก commit `7c2bab4`/`7c2de18` นี้ — บั๊กเดียวที่ยัง fail คือของเดิมที่ทราบอยู่แล้ว
(ดูหัวข้อถัดไป)

## Severity

- QA-WYN-110-002 (`HomeDropCard` ล้น 3px ที่ 320px): **Low** — ยังไม่ถูกแก้ (ยืนยันซ้ำในรอบนี้ว่ายัง
  reproduce ได้เป๊ะเหมือนรอบ 1) แต่ **นอกขอบเขตของทั้ง WYN-110 และ WYN-111** ยืนยันแล้วว่า
  `home_drop_card.dart` ไม่ถูกแตะโดย commit ทั้ง 2 นี้เลย (`git diff de4b4b0..HEAD` ว่างเปล่าสำหรับ
  ไฟล์นี้) — ไม่ block การอนุมัติตามที่ตกลงไว้

## Reproduction Steps (QA-WYN-110-002, คงเดิมจากรอบ 1 — อ้างอิงไว้ให้ครบ ไม่ใช่บั๊กใหม่)

pump `HomeDropCard` เดี่ยว ๆ ที่ความกว้าง 320px ด้วยโพสต์ที่ like/comment เป็น 0 → เกิด
`RenderFlex overflowed by 3.0 pixels on the right` ที่ `home_drop_card.dart:534` (action row) ทุกครั้ง
ยืนยันซ้ำผ่าน `qa_wyn110_profile_scroll_header_test.dart` กลุ่ม "6." เฉพาะเคส 320px

## Expected

Action row ต้องพอดีภายใน 320px เหมือนความกว้างอื่น ไม่มี overflow

## Actual

ล้นขวา 3.0 pixels ที่ 320px เท่านั้น (360/390/430px ผ่านสะอาด) — บั๊กเดิม ไม่เกี่ยวกับงานที่ตรวจรอบนี้

## Security Findings

- ไม่พบ secret/API key/credential หลุดใน diff ทั้งหมด (`git diff de4b4b0..HEAD | grep -iE
  "api[_-]?key|secret|password|token"` ไม่พบสิ่งใดนอกจากข้อความอธิบายในเอกสาร .md ของรอบ 1 เอง)
- ไม่มีการเปลี่ยนแปลง authentication/authorization logic เลยในทั้ง 2 งาน (`git diff --name-only` ไม่มี
  ไฟล์ที่เกี่ยวกับ auth/login/session/permission/RLS/policy เลยแม้แต่ไฟล์เดียว)
- ไม่มี user data ใหม่ถูก log หรือแสดงผลผิดที่ — การเปลี่ยนแปลงทั้งหมดจำกัดอยู่ที่ (ก) guard ของ
  pagination state ภายใน widget เดียวกัน และ (ข) paint-only `Transform.scale` ของรูปภาพที่แสดงอยู่แล้ว

## Recommendation

1. ทั้ง 2 งาน (QA-WYN-110-001 fix + WYN-111) พร้อมส่งต่อ AI Deploy & DevOps
2. QA-WYN-110-002 ยังรอ PM/Founder ตัดสินใจเปิด task แยก (ไม่ block งานนี้) — คงคำแนะนำเดิมจากรอบ 1
3. บันทึกบทเรียนกระบวนการ: ไฟล์เทสต์ของ QA เองก็ต้องรีวิว/รันจริงซ้ำทุกครั้งเช่นกัน ไม่ใช่แค่เชื่อว่า
   เขียนไว้ถูกตั้งแต่รอบก่อน — รอบนี้พบว่าไฟล์เทสต์ของ QA เองมีบั๊ก 2 ชั้นซ้อนกัน (ทิศทาง `delta` ผิด
   บังบั๊กที่ 2 คือ assertion นับ widget ที่ไม่ถูกหลักการสำหรับ lazy-built list ไว้)

## Final Status: **PASS**

ทั้ง QA-WYN-110-001 (ยืนยันปิดจริงด้วยเทสต์เดิม + เทสต์ break-more ใหม่ 3 แบบ ไม่พบ over-fetch หลงเหลือ
เลย) และ WYN-111 (ฟีเจอร์ใหม่ทำงานถูกต้องครบตาม design spec, ไม่กระทบ physics/reuse/responsive เดิม)
ผ่านการทดสอบจริงครบทุกหัวข้อที่ได้รับมอบหมาย `flutter analyze` สะอาด (0 issues) `flutter test` เต็มชุด
1163/1164 ผ่าน (เคสเดียวที่เหลือคือ QA-WYN-110-002 ซึ่งเป็นบั๊กเดิมนอกขอบเขต ไม่ได้เกิดจากงานนี้ และตกลง
กันไว้แล้วว่าไม่ block) ย้าย `.wyn/tasks/active/WYN-110-profile-scroll-header.md` และ
`.wyn/tasks/active/WYN-111-carousel-center-emphasis.md` ไปที่ `.wyn/tasks/approved/` แล้ว — ส่งต่อ AI
Deploy & DevOps
