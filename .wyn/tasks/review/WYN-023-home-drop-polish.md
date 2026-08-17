# Product Task — WYN-023

Status: Coding เสร็จแล้ว รอ AI QA & Security (ย้ายเข้า `.wyn/tasks/review/`)
Owner: AI Product Manager → AI Design → AI Coding

Feature: Home/Drop Polish — แก้ 3 Minor finding ที่ค้างจาก QA รอบก่อนหน้า (ไม่เคยถูกหยิบมาทำต่อ)

Goal: ปิด gap เล็กๆ 3 จุดที่ QA เจอและบันทึกไว้ว่า "ไม่ block แต่ควรทำในรอบถัดไป" ตั้งแต่ WYN-005/WYN-007/WYN-015 — ตอนนี้ผ่านมาหลายรอบ feature ใหญ่แล้ว (WYN-017 ถึง WYN-022) แต่ยังไม่มีใครหยิบ 3 จุดนี้กลับมาทำ ทั้งที่เป็นของเล็ก ความเสี่ยงต่ำ ใช้ของที่มีอยู่แล้วในระบบทั้งหมด ไม่ต้องสร้างอะไรใหม่

Target User: ผู้ใช้ WYN Social ทุกคนที่ใช้ Home/Drop tab

Problem:
1. การ์ด Drop ใน Home และ Drop feed (`HomeDropCard`) ไม่แสดงเวลาที่โพสต์เลย (ไม่มีทั้ง relative time และ absolute time) — QA รอบ 3 ของ WYN-005 (2026-08-14) เจอแล้วบันทึกเป็น Minor ไม่ block แต่ยังไม่เคยถูกแก้ ทั้งที่ตอนนี้โปรเจกต์มี `relativeTimeLabel()` ใช้งานจริงอยู่แล้วใน 4 จุด (Notification, Club post, ZOKY order/review) — Drop/Home เป็นจุดเดียวที่ยังขาด
2. แตะไอคอน Comment บนการ์ด Pop ใน Home เปิดหน้าคลิปเดี่ยวก่อนเสมอ แทนที่จะเปิด comment sheet ตรงๆ ทันที — QA รอบ 2 ของ WYN-007 (2026-08-14) เจอแล้วเสนอ fast-follow ด้วย `openCommentsOnStart` flag ไว้ ยังไม่เคยทำ
3. Empty state ของโหมด "จาก Club ของคุณ" ใน Home (เมื่อยังไม่ได้ join Club ไหนเลย) ไม่มีปุ่ม "สำรวจ Club" ตามที่ Design spec เดิมของ WYN-015 ระบุไว้ตรงๆ — QA รอบ 1 ของ WYN-015 (2026-08-14) เจอแล้วไม่ block เพราะปุ่มเดิมของ `ClubSection` เหนือ toggle ยังกดได้อยู่ แต่ก็ยังไม่เคยแก้ให้ตรงตาม spec

Requirements:

R1. เพิ่ม relative timestamp บน `HomeDropCard` (แสดงในทั้ง Home feed และ Drop feed ที่ reuse การ์ดเดียวกันตาม WYN-019) โดยเรียก `relativeTimeLabel()` เดิมจาก `app/lib/core/text_utils.dart` ตรงๆ ไม่เขียนฟังก์ชันใหม่ — ตำแหน่งวางให้ AI Design ตัดสินใจ (ข้าง username เหมือนที่ Notification/Club post ทำอยู่แล้วน่าจะ consistent ที่สุด)
R2. เพิ่ม `openCommentsOnStart` flag (หรือเทียบเท่า) ให้ `PopSingleClipScreen`/`PopClipView` เพื่อให้แตะ Comment บนการ์ด Pop ของ Home เปิด comment sheet ทันทีแทนที่จะรอผู้ใช้เปิดเองหลังจอคลิปโหลด — ตาม fast-follow ที่ WYN-007 QA รอบ 2 เสนอไว้แล้ว
R3. เพิ่มปุ่ม "สำรวจ Club" ใน empty state ของโหมด "จาก Club ของคุณ" (`FromYourClubsFeed`'s empty state) ให้ตรงตาม Design spec เดิมของ WYN-015 — ไม่ต้องสร้าง flow ใหม่ พาไปหน้า `ExploreClubsScreen` ที่มีอยู่แล้ว

Acceptance Criteria:
- [ ] การ์ด Drop ใน Home และ Drop feed ทั้ง 3 tab (For You/Following/Latest) แสดงเวลาที่โพสต์แบบ relative (เช่น "5 นาทีที่แล้ว") ตรงกับ format เดียวกับที่ Notification/Club post ใช้อยู่แล้ว
- [ ] แตะ Comment บนการ์ด Pop ใน Home เปิด comment sheet ทันทีโดยไม่ต้องกดซ้ำหลังคลิปโหลด
- [ ] Empty state ของ "จาก Club ของคุณ" มีปุ่ม "สำรวจ Club" ที่กดแล้วพาไป `ExploreClubsScreen` จริง
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-005/WYN-007/WYN-014/WYN-015/WYN-019

Dependencies: ไม่มี hard dependency ใหม่ — ต่อยอด WYN-005/WYN-007/WYN-012/WYN-014/WYN-015/WYN-019 ที่ผ่าน QA แล้วทั้งหมด (R1 พึ่ง `relativeTimeLabel()` จาก WYN-012, R2 พึ่ง `PopSingleClipScreen` จาก WYN-007, R3 พึ่ง `ExploreClubsScreen` จาก WYN-015)

Priority: กลาง — คุณค่าชัดเจนและความเสี่ยงต่ำมาก (ของเดิมที่มีอยู่แล้วทั้งหมด ไม่มี schema change) แต่ไม่ใช่ blocker ของอะไร เหมาะเป็นงาน "เก็บกวาด" ก่อนเริ่ม feature ใหญ่ชิ้นถัดไป

Risks: แทบไม่มี — เป็นการเรียกใช้ของเดิมที่ผ่าน QA แล้วทั้ง 3 จุด (`relativeTimeLabel`, comment-sheet flag pattern ที่มีอยู่แล้วในโค้ด, `ExploreClubsScreen` ที่มีอยู่แล้ว) ไม่แตะ schema/RLS/ranking logic เลย

Recommendation: ทำได้ทันทีคู่ขนานกับการส่ง WYN-017–022 เข้า QA จริง (ดู DECISIONS.md 2026-08-17 — 6 task ก่อนหน้านี้ยัง "self-verified" เท่านั้น ยังไม่ผ่าน AI QA & Security อิสระจริง) — แนะนำให้ QA อิสระของ WYN-017–022 เป็นลำดับความสำคัญอันดับ 1 ก่อนเริ่ม WYN-023 เพราะเป็นของที่ deploy ค้างอยู่แล้วและมี risk สูงกว่า (แตะ Home feed ranking) — WYN-023 เป็นงานเสริมที่ทำเมื่อไหร่ก็ได้ไม่บล็อกอะไร

Handoff: **AI Design เสร็จแล้ว (2026-08-16)** — Design spec เต็มที่ `.wyn/docs/design/wyn-023-home-drop-polish.md`:
- R1: ตำแหน่ง timestamp บน `HomeDropCard` = บรรทัดที่สองใต้ชื่อผู้เขียนในบล็อก header เดิม (`bodySmall` + `colorScheme.outline`) มิเรอร์โครงสร้าง header ของ `ClubPostCard`/Notification/ZOKY order-review เป๊ะทั้ง 4 จุด — แก้ไฟล์เดียว มีผลอัตโนมัติทั้ง Home feed และ Drop feed 3 tab ตาม WYN-019 ระบุ Non-goal ชัดเจนว่า `HomePopCard` ไม่อยู่ในขอบเขตรอบนี้ (เสนอเป็น fast-follow แยกให้ Product พิจารณา)
- R2: ยืนยันไม่ต้องมี Design เพิ่ม (behavior fix ล้วนๆ) — ส่งตรง AI Coding พร้อม reference พิกัดโค้ดที่เกี่ยวข้องไว้ในเอกสาร
- R3: ปุ่ม "สำรวจ Club" ใน empty state ของ `FromYourClubsFeed` = ใช้ config เดียวกับปุ่มต้นแบบใน `ClubSection` เป๊ะ (`OutlinedButton.icon(icon: Icons.explore_outlined, size: 18, label: 'สำรวจ Club')`) กดแล้วเปิด `ExploreClubsScreen` แล้ว reload feed เมื่อกลับมา มิเรอร์ pattern `ClubSection._openExploreClubs()` ทุกประการ

ส่งต่อ AI Coding (`/code`) เพื่อ implement ทั้ง 3 requirement ตาม Design spec ข้างต้น — ดู Handoff section ในเอกสาร design สำหรับรายละเอียด implementation/regression-test ที่ต้องทำครบ

## Coding Output (2026-08-17)

Implementation:
- **R1**: `HomeDropCard`'s header `Row`'s author-name `Text` เปลี่ยนเป็น `Expanded(Column([ชื่อ, relativeTimeLabel(item.createdAt, now: DateTime.now())]))` มิเรอร์โครงสร้าง header ของ `ClubPostCard` เป๊ะ (`textTheme.bodySmall` + `colorScheme.outline`) เอา `mainAxisSize: MainAxisSize.min` ออกจาก `Row` นั้นตามที่ Design ระบุ (จำเป็นเพื่อให้ `Expanded` มีขอบเขตยืด) — มีผลอัตโนมัติทั้ง Home feed (WYN-007) และ Drop feed ทั้ง 3 tab (WYN-019) เพราะ reuse widget เดียวกัน ไม่แตะ `drop_feed_screen.dart`/`home_feed_screen.dart` เลยตามที่ Design ยืนยันไว้
- **R2**: เพิ่ม `openCommentsOnStart` (`bool`, default `false`) ให้ `PopClipView` — เมื่อ `true` เรียก `_openComments()` ผ่าน `WidgetsBinding.instance.addPostFrameCallback` ใน `initState` (ตามคำเตือนของ Design เรื่อง `showModalBottomSheet` ต้องมี widget tree พร้อมก่อน) ส่งต่อผ่าน `PopSingleClipScreen`'s constructor ใหม่ (default `false` เช่นกัน) — เพิ่ม `onOpenComments` callback แยกจาก `onTap` ให้ `HomePopCard` (ไอคอน Comment เดิมเรียก `onTap` ตรงๆ มาตลอด ตอนนี้แยกเป็น callback ของตัวเอง) `home_feed_screen.dart`'s `_openPop` รับ named param `openCommentsOnStart` (default `false`) — จุดเรียกปกติ (แตะรูป/ชื่อ, TrendingTile) ยังคงส่ง default `false` เหมือนเดิม จุดเดียวที่ส่ง `true` คือ `HomePopCard.onOpenComments`
- **R3**: `FromYourClubsFeed`'s empty state เพิ่มปุ่ม `OutlinedButton.icon(icon: Icons.explore_outlined size 18, label: 'สำรวจ Club')` ต่อท้ายข้อความเดิมด้วย `SizedBox(height: WynSpacing.space3)` (ค่าเดียวกับที่ `_error` state ใช้อยู่แล้วในไฟล์เดียวกัน) เพิ่มเมธอด `_openExploreClubs()` (ชื่อ/logic เดียวกับ `ClubSection._openExploreClubs()`) เปิด `ExploreClubsScreen` แล้วเรียก `_loadInitial()` ทันทีหลังกลับมา — ระหว่างเขียน regression test พบและแก้ **RenderFlex overflow bug ที่ผมสร้างขึ้นเอง**: การห่อ Text+Button ด้วย `Column(mainAxisSize: min)` ตรงๆ ภายใน `Center` ล้นเมื่อพื้นที่แนวตั้งที่มีให้แคบ (เช่นตอน `FromYourClubsFeed` ถูกฝังอยู่ใต้ ClubSection/Trending/toggle ใน Home ที่กินพื้นที่ไปมากแล้ว) แก้โดยห่อด้วย `SingleChildScrollView` แทน (ไม่มีทาง overflow อีก แค่ scroll ได้ถ้าพื้นที่ไม่พอ) เหมือน lesson ที่บันทึกไว้จาก WYN-015's `ViewProfileScreen` overflow bug

Files Changed:
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` (R1)
- `app/lib/features/pop/presentation/widgets/pop_clip_view.dart` (R2)
- `app/lib/features/home/presentation/pop_single_clip_screen.dart` (R2)
- `app/lib/features/home/presentation/widgets/home_pop_card.dart` (R2, เพิ่ม `onOpenComments` callback)
- `app/lib/features/home/presentation/home_feed_screen.dart` (R2, wiring `_openPop`/`HomePopCard`)
- `app/lib/features/home/presentation/widgets/from_your_clubs_feed.dart` (R3)
- `app/test/home_feed_screen_test.dart` (R1 + R2 regression tests, ทั้ง Home feed)
- `app/test/drop_feed_screen_test.dart` (R1 regression test สำหรับ Drop feed — ยืนยันว่า `HomeDropCard` แก้ไฟล์เดียวมีผลทั้งสองที่จริง)
- `app/test/from_your_clubs_feed_test.dart` (ใหม่ — R3 regression tests)

Reason: ปิด 3 Minor QA finding ที่ค้างมาตั้งแต่ WYN-005/WYN-007/WYN-015 ตาม Product/Design spec — reuse pattern เดิมที่ผ่าน QA แล้วทั้งหมด ไม่มี schema change ไม่มี component ใหม่ (นอกจาก instance ปุ่มที่ก็อปปี้ config จากของเดิม)

Tests:
- เขียน red→green จริง 3 จุด (ไม่ใช่แค่ pass ตั้งแต่แรก):
  1. R1: ตอนแรกลืมเอา `mainAxisSize: MainAxisSize.min` ออกจาก header `Row` — ยืนยันว่าจำเป็นจริงตามที่ Design เตือนไว้ (ไม่งั้น `Expanded` error) หลังแก้ตาม spec ทั้งสองไฟล์ (`home_feed_screen_test.dart`, `drop_feed_screen_test.dart`) เขียว
  2. R2: test ใหม่ 2 ตัวใน `home_feed_screen_test.dart` — แยกยืนยันว่าไอคอน Comment เปิด comment sheet ทันที (`find.text('ความคิดเห็น')` เจอ) และแตะการ์ดปกติไม่เปิดอัตโนมัติ (`findsNothing`) — เจอ 2 ปัญหาระหว่างเขียน: (ก) construct `RecordingDropRepository` inline ใน `testWidgets` ทำให้ "Timer is still pending" (anti-pattern เดิมที่เคยบันทึกไว้ใน `.wyn/learning/PATTERNS.md` — แก้โดยย้ายเข้า `setUp()`) (ข) tap บนการ์ดที่อยู่นอก viewport 600px ไม่ hit เพราะการ์ดใหญ่กว่าจอทดสอบ — แก้โดยขยาย `tester.view.physicalSize` แบบเดียวกับ DS-003 test เดิมในไฟล์เดียวกัน
  3. R3: พบ RenderFlex overflow จริงจาก test ที่มีอยู่แล้ว (`shows a join-prompt message on "จาก Club ของคุณ"...` ใน `home_feed_screen_test.dart`) ทันทีหลังเพิ่มปุ่ม — พิสูจน์ overflow จริงก่อนแก้ (`SingleChildScrollView`) แล้วเขียวอีกครั้ง ไม่ใช่แค่สมมติว่าไม่ overflow
- `flutter analyze`: สะอาด (No issues found)
- `flutter test`: **369/369 ผ่านทั้งหมด** (เพิ่มจาก 362 เดิม — 7 test ใหม่: 3 ใน `home_feed_screen_test.dart` (R1 ×1, R2 ×2), 1 ใน `drop_feed_screen_test.dart` (R1), 3 ใน `from_your_clubs_feed_test.dart` ใหม่ทั้งไฟล์ (R3)) ไม่มี regression กับ WYN-005/WYN-007/WYN-012/WYN-014/WYN-015/WYN-019 เลย

Build: ไม่ได้รัน `flutter build` จริง (ต้องมี Supabase project/native platform config จริงตามสถานะเดิมของโปรเจกต์ทั้งหมด — เหมือนทุก task ก่อนหน้าที่ยัง "code-complete รอ deploy")

Known Issues: ไม่มี — Non-goal ของ R1 (`HomePopCard` ยังไม่มี timestamp) เป็นไปตาม Design spec ที่ตั้งใจไว้แล้ว บันทึกเป็น fast-follow ที่แนะนำไว้ ไม่ใช่ bug ของงานนี้

Handoff: ส่งต่อ AI QA & Security (`/qa`) — เอกสาร task นี้ย้ายเข้า `.wyn/tasks/review/` แล้ว รอ QA อิสระตรวจ Requirements/Design Components/Acceptance Criteria ทั้ง 3 หัวข้อ แนะนำให้ QA ทำ red→green proof อิสระเองซ้ำอย่างน้อย 1 จุด (เช่น R2's openCommentsOnStart) ตามธรรมเนียมเดิมของโปรเจกต์ — ไม่ย้ายเข้า `approved/` เอง
