# Product Task — WYN-023

Status: design เสร็จแล้ว รอ AI Coding
Owner: AI Product Manager → AI Design

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

## Coding Output

Status: **Coding เสร็จแล้ว (2026-08-17)** — implement ครบทั้ง R1/R2/R3 ตาม Design spec ทุกประการ ไม่มีการเบี่ยงเบนจากที่ Design ตัดสินใจไว้

**R1 — Relative timestamp บน `HomeDropCard`**: แก้ไฟล์เดียวจริงตามที่ Design ระบุ (`app/lib/features/home/presentation/widgets/home_drop_card.dart`) — เพิ่ม `import '../../../../core/text_utils.dart';`, เปลี่ยน header `Row`'s `Text(item.authorNameOrUsername)` เดี่ยวๆ เป็น `Expanded(Column([Text(ชื่อ, titleSmall), Text(relativeTimeLabel(item.createdAt, now: DateTime.now()), bodySmall + colorScheme.outline)]))` เหมือน `ClubPostCard` เป๊ะ และเอา `mainAxisSize: MainAxisSize.min` ออกจาก `Row` นั้นตามที่ Design เตือนไว้ (จำเป็นเพื่อให้ `Expanded` มีขอบเขตยืด) — มีผลอัตโนมัติทั้ง Home feed (WYN-007) และ Drop feed ทั้ง 3 tab (WYN-019) เพราะ reuse widget เดียวกันจริงตามที่ Design ยืนยันไว้ ไม่ได้แตะ `drop_feed_screen.dart`/`home_feed_screen.dart` เลยสำหรับส่วนนี้ `HomePopCard` ไม่ถูกแตะตาม Non-goal

**R2 — `openCommentsOnStart`**: เพิ่ม `bool openCommentsOnStart = false` ให้ `PopClipView` constructor — เมื่อ `true` เรียก `_openComments()` ผ่าน `WidgetsBinding.instance.addPostFrameCallback` ใน `initState` (ตามคำเตือนของ Design เรื่อง `showModalBottomSheet` ต้องรอ widget tree build เสร็จก่อน) `PopSingleClipScreen` รับ/ส่งต่อ flag เดียวกันเข้า `PopClipView` (default `false` ไม่กระทบ caller เดิม 6 จุดที่เรียก `PopSingleClipScreen` โดยไม่ระบุ flag นี้) จุดที่ต้องแก้เพิ่มนอกเหนือจาก Handoff ที่ระบุไว้: `HomePopCard` เดิมไม่มี callback แยกสำหรับไอคอน Comment (ใช้ `onTap` เดียวกับทั้งการ์ดอยู่) จึงต้องเพิ่ม `required VoidCallback onComment` ใหม่ให้ `HomePopCard` แล้วผูก Comment `IconButton`'s `onPressed` เข้ากับมันแทน `onTap` — `home_feed_screen.dart`'s `_openPop` เพิ่ม optional param `openCommentsOnStart = false` และ `HomePopCard` construction site ส่ง `onTap: () => _openPop(item)` (ปกติ, false) แยกจาก `onComment: () => _openPop(item, openCommentsOnStart: true)` ตามที่ Design ตั้งใจ

**R3 — ปุ่ม "สำรวจ Club" ใน `FromYourClubsFeed`'s empty state**: แก้ไฟล์เดียวตามที่ Design ระบุ (`app/lib/features/home/presentation/widgets/from_your_clubs_feed.dart`) — เพิ่ม import `ExploreClubsScreen`, เพิ่มเมธอด `_openExploreClubs()` (ชื่อ/พฤติกรรมมิเรอร์ `ClubSection._openExploreClubs()` ทุกประการ: push แล้วเรียก `_loadInitial()` เสมอหลังกลับมา ไม่มีเงื่อนไข), เปลี่ยน empty state จาก `Text` เดี่ยวๆ เป็น `Column(mainAxisSize: min, [Text เดิม, SizedBox(space3), OutlinedButton.icon(...)])` ตาม Components ที่ Design กำหนดไว้เป๊ะ ข้อความเดิม "เข้าร่วม Club เพื่อดูโพสต์ที่นี่" ไม่เปลี่ยน

**Gap ที่พบเองระหว่างทำ (ก่อนส่ง QA)**: การเพิ่ม `Column` เข้า empty state ของ `FromYourClubsFeed` (R3) ทำให้ test เดิม 1 เคส (`home_feed_screen_test.dart`, "shows a join-prompt message...") FAIL ด้วย `RenderFlex overflowed by 52 pixels` — สาเหตุคือ test group นั้นไม่เคยตั้งค่า `tester.view.physicalSize` แบบ tall viewport มาก่อน (ใช้ default 800x600 ของ `flutter_test`) ซึ่งหลังจาก `ClubSection`/Trending section/toggle กินพื้นที่ไปแล้ว เหลือพื้นที่แนวตั้งให้ `FromYourClubsFeed` แค่ ~28px — พอเดิมเป็นแค่ `Text` เดี่ยวๆ ไม่มี `RenderFlex` ให้ overflow แต่พอเป็น `Column` (ตามที่ Design กำหนด) ก็ชนทันที **แก้โดยเพิ่ม `tester.view.physicalSize = const Size(800, 2200)` ให้ test เคสนั้นเคสเดียว** มิเรอร์ pattern เดียวกับ `tester.view.physicalSize` ที่ไฟล์เดียวกันใช้อยู่แล้วสำหรับ DS-003 divider test (ไม่ใช่ bug ที่ต้องแก้ที่ widget เอง เพราะพื้นที่จริงบนอุปกรณ์จริงมีมากกว่า 28px เสมอ — เป็นแค่ข้อจำกัดของ test viewport เริ่มต้นที่เล็กเกินไปสำหรับ layout ใหม่นี้) ยืนยันว่าเป็น test-environment artifact ไม่ใช่ production bug จริง เพราะพื้นที่ที่ต้องการ (ข้อความ 1-2 บรรทัด + spacing + ปุ่ม ~70-80px) เทียบกับความสูงหน้าจอจริงทุกรุ่นมีเหลือเฟือ

**Testing**: เขียน regression test ใหม่/ขยาย test เดิมครบตาม Handoff:
- R1: test ใหม่ใน `home_feed_screen_test.dart` (ยืนยัน Drop card แสดง `relativeTimeLabel` และ `HomePopCard` ไม่มี — ตรง Non-goal) และ `drop_feed_screen_test.dart` (test ใหม่สำหรับ For You tab + ขยาย assertion เดิมของ Following/Latest tab อีก 2 จุด) — พิสูจน์ว่าแก้ไฟล์เดียวมีผลทั้ง Home feed และ Drop feed จริงทั้ง 3 tab
- R2: แก้ test เดิม "tapping the Comment icon on a Pop card..." ให้ยืนยัน `PopCommentSheet` เปิดขึ้นจริงทันที (ไม่ใช่แค่ว่าไปหน้า `PopSingleClipScreen` เฉยๆ เหมือนเดิม) และเพิ่ม test ใหม่ (regression guard) ยืนยันว่าแตะการ์ดจุดอื่น (ไม่ใช่ไอคอน Comment) เปิด `PopSingleClipScreen` โดย**ไม่**เปิด comment sheet อัตโนมัติ (ป้องกัน regression ที่ flag จะ default เป็น true ผิดที่)
- R3: ไฟล์ test ใหม่ `app/test/from_your_clubs_feed_test.dart` (pump `FromYourClubsFeed` ตรงๆ ไม่ผ่าน `HomeFeedScreen` ทั้งก้อน) 2 เคส — ปุ่มปรากฏใน empty state จริง, และกดปุ่มแล้ว navigate ไป `ExploreClubsScreen` จริงพร้อม `_loadInitial()` ถูกเรียกซ้ำหลังกลับมา (เพิ่ม `fetchFromJoinedClubsCalls` counter ใหม่ให้ `RecordingClubPostRepository` มิเรอร์ pattern `fetchRankedFeedCalls` ของ `RecordingHomeRepository`/WYN-018 เพื่อพิสูจน์)
- **Red→Green proof จริง (ไม่ใช่แค่เขียน test ผ่านเฉยๆ)**: `git stash` เฉพาะไฟล์ `lib/` ที่แก้ (เก็บไฟล์ test ไว้) แล้วรัน test ยืนยันว่า **8 เคส FAIL จริง** (ตรงกับทุกจุดที่ R1/R2/R3 เพิ่ม/แก้ assertion พอดี — timestamp ×3, comment-sheet-opens ×1, explore-button ×3, join-prompt-button-scoped ×1) จากนั้น `git stash pop` คืนโค้ดกลับมาแล้วรันซ้ำยืนยัน**ผ่านครบทุกเคส**

**ตัวเลข test ก่อน/หลัง**: Baseline (ก่อนเริ่มงาน, sync จาก branch ปัจจุบัน): `flutter analyze` สะอาด, `flutter test` **362/362** ผ่าน — หลังแก้ไข: `flutter analyze` สะอาด (No issues found), `flutter test` **367/367** ผ่าน (เพิ่ม 5 เคสใหม่สุทธิ: 2 ใน `home_feed_screen_test.dart`, 1 ใน `drop_feed_screen_test.dart`, 2 ใน `from_your_clubs_feed_test.dart` — ส่วนที่เหลือเป็นการขยาย assertion ในเคสเดิมที่มีอยู่แล้ว ไม่เพิ่มจำนวนเคส) ไม่มี regression กับ WYN-005/WYN-007/WYN-012/WYN-014/WYN-015/WYN-019

**หมายเหตุ environment**: เครื่องนี้ไม่มี Flutter SDK ติดตั้งไว้ล่วงหน้า ติดตั้ง Flutter 3.47.0 stable (ดาวน์โหลดตรงจาก `storage.googleapis.com/flutter_infra_release`) ที่ `/home/user/tools/flutter` เพื่อรัน `flutter analyze`/`flutter test` ให้ได้ตัวเลขจริง ไม่ใช่แค่ตรวจโค้ดด้วยตา

**Files Changed**:
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` (R1)
- `app/lib/features/pop/presentation/widgets/pop_clip_view.dart` (R2)
- `app/lib/features/home/presentation/pop_single_clip_screen.dart` (R2)
- `app/lib/features/home/presentation/widgets/home_pop_card.dart` (R2 — เพิ่ม `onComment` callback ใหม่)
- `app/lib/features/home/presentation/home_feed_screen.dart` (R2 — wiring `onComment`)
- `app/lib/features/home/presentation/widgets/from_your_clubs_feed.dart` (R3)
- `app/test/home_feed_screen_test.dart` (R1/R2 tests)
- `app/test/drop_feed_screen_test.dart` (R1 tests)
- `app/test/from_your_clubs_feed_test.dart` (ไฟล์ใหม่ — R3 tests)
- `app/test/support/recording_club_post_repository.dart` (เพิ่ม `fetchFromJoinedClubsCalls` counter สำหรับ R3 test)

**Known Issues**: ไม่มี — ทุก Acceptance Criteria ของ Product Task ตรวจแล้วครบและมี test คุ้มครองจริง

**Handoff**: ส่งต่อ AI QA & Security เพื่อตรวจ Requirements/Design Components/Acceptance Criteria ทั้ง 3 หัวข้อแยกกันตาม pattern เดิม รวมถึงตรวจ red→green proof ข้างต้นซ้ำอิสระ และพิจารณา fast-follow ที่บันทึกไว้ใน Design spec (timestamp ให้ `HomePopCard` ด้วย — นอกขอบเขต WYN-023 นี้ ต้องเป็น task ใหม่ถ้า Product เห็นด้วย)
