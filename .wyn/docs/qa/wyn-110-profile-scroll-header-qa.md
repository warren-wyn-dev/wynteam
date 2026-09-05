# QA Report — WYN-110: หัวโปรไฟล์เลื่อนหายไปได้ (รอบ 1)

Owner: AI QA & Security
วันที่: 2026-09-05
Branch: `claude/home-button-ux-ui-design-cbjkzm`
Commit ที่ตรวจ: `de4b4b0` (parent: `a75c24c`)
Environment: `flutter test` / `flutter analyze` บน Linux, Flutter SDK ที่ `/opt/flutter-sdk/flutter`

## Feature

แก้บั๊ก "เลื่อนดูโพสต์ในโปรไฟล์แล้วเห็นได้แค่ครึ่งจอ" — เปลี่ยนหัวโปรไฟล์ + `TabBar` จาก `Column`
ที่ไม่เลื่อน เป็น `NestedScrollView` (`SliverToBoxAdapter` + `SliverPersistentHeader(pinned: true)`)
พร้อมแปลง 3 แท็บ (`ProfileDropGridTab`/`ProfileRedropsTab`/`ProfileLikesTab`) จาก `ListView.separated`
เป็น `CustomScrollView([SliverList.separated])` ที่ผูกกับ `NestedScrollView` แทน `ScrollController`
ส่วนตัว

## ขอบเขตที่ตรวจสอบ (diff review)

`git diff --name-only a75c24c de4b4b0` มีแค่ไฟล์ที่ระบุไว้จริง 7 ไฟล์ (5 lib + 2 docs/task):

- `app/lib/features/profile/presentation/view_profile_screen.dart`
- `app/lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart`
- `app/lib/features/profile/presentation/widgets/profile_likes_tab.dart`
- `app/lib/features/profile/presentation/widgets/profile_redrops_tab.dart`
- `app/test/view_profile_screen_scroll_test.dart` (ใหม่ จาก coding agent)
- `.wyn/docs/design/wyn-110-profile-scroll-header.md`, `.wyn/tasks/active/WYN-110-profile-scroll-header.md`

ยืนยันแล้วว่า **ไม่มี** การแตะ `ProfileSavedTab`/`ProfilePopGridTab`/`ProfileRepliesTab` (นอกขอบเขต
ตาม design spec) — ตรงตามที่ระบุไว้ ไม่มีอะไรเกินขอบเขต

โค้ด diff ที่อ่านจริงบรรทัดต่อบรรทัด ตรงกับคำอธิบายที่ได้รับมาทุกจุด:
- `_ProfileTabBarDelegate` ใช้ `tabBar.preferredSize.height` เป็น `minExtent`/`maxExtent` จริง
  (ไม่ hardcode) พื้นหลัง `Material(color: WynColors.paper)` ตรงตาม pattern ของ
  `_FeedModeToggleHeaderDelegate` ใน `home_feed_screen.dart`
- 3 แท็บถอด `ScrollController` ส่วนตัวออกจริง เปลี่ยนเป็น `NotificationListener<ScrollNotification>`
  ครอบ `CustomScrollView` เกณฑ์ 300px จากล่างสุดเหมือนเดิม
- `_loadMore()` ถูกเรียกผ่าน `WidgetsBinding.instance.addPostFrameCallback` จริง

### ตรวจสอบการตัดสินใจ "ไม่ใช้ SliverOverlapAbsorber/Injector" — ยืนยันว่าถูกต้อง

อ่าน Flutter framework source (`nested_scroll_view.dart` บรรทัด 85-96) โดยตรง:

> "A pinned SliverAppBar works in a NestedScrollView exactly as it would in another scroll view...
> This works naturally in a NestedScrollView, as the pinned SliverAppBar is not expected to move in
> or out of the visible portion of the viewport."

`SliverOverlapAbsorber`/`Injector` จำเป็นเฉพาะกรณี header เป็น **floating** หรือ **snap** (เพราะ header
แบบนั้นสามารถ "โผล่ทับ" เนื้อหาที่ inner scrollable คิดว่ายังไม่ได้เลื่อน) — `_ProfileTabBarDelegate`
เป็น `pinned: true` เดี่ยว ๆ ไม่มี floating เลย จึงไม่จำเป็นต้องมี absorber/injector จริงตามที่โค้ด
คอมเมนต์ไว้ — **การตัดสินใจนี้ถูกต้อง ไม่ใช่การมองข้าม**

## Test Cases

เขียนเทสต์อิสระของตัวเอง (ไม่พึ่งเทสต์ของ coding agent) ที่
`app/test/qa_wyn110_profile_scroll_header_test.dart` (17 testWidgets ใหม่) ครอบคลุม:

1. Header เลื่อนหายบนโปรไฟล์คนอื่น (`isOwnProfile == false`) รวม `ProfileRecommendationSection`
   ในหัว — วัดตำแหน่งจริงของ `TabBar` หลังเลื่อน (`< 150px` จากขอบบน)
2. ทั้ง 3 แท็บ (ไม่ใช่แค่ Posts) เลื่อน header หายได้เหมือนกันเมื่อสลับไปแท็บนั้นก่อนเลื่อน
3. ตำแหน่งเลื่อนต่อแท็บไม่รีเซ็ตหลังสลับแท็บไปมา (`AutomaticKeepAliveClientMixin` +
   `NestedScrollView` per-tab controller ทำงานถูกต้อง)
4. Infinite-scroll ข้าม page boundary จริงทั้ง 3 แท็บ (เขียน `_PagedDropRepository`/
   `_PagedHomeRepository` ในไฟล์เทสต์เอง เพราะ fake repo เดิมใน `test/support/` รองรับแค่ page 0)
5. Pull-to-refresh ทั้ง `ProfileDropGridTab`/`ProfileRedropsTab` (Likes มีอยู่แล้วใน
   `profile_likes_tab_test.dart` — รันซ้ำผ่าน)
6. ไม่ overflow **ระหว่างลาก** (ไม่ใช่แค่ตอนอยู่นิ่ง) ที่ 320/360/390/430px — ลากทีละ 60px 10 รอบ
   เช็ค exception ทุกรอบ

รวมกับการรันซ้ำเทสต์ regression เดิมที่เกี่ยวข้อง:
- `view_profile_screen_test.dart` (ครบทุกเคส รวม overflow 320x568)
- `view_profile_screen_scroll_test.dart` (เทสต์ของ coding agent เอง)
- `profile_likes_tab_test.dart` (รวม pagination-overlap regression test เดิม)
- `view_profile_private_account_test.dart`, `block_relationship_test.dart` (Blocked/Private banner)

## Passed

- Header เลื่อนหายได้จริงทั้งโปรไฟล์ตัวเองและคนอื่น (รวมกรณีมี `ProfileRecommendationSection`)
  `TabBar` ค้างขอบบนจริง (วัดตำแหน่ง Y แล้ว < 150px)
- ทั้ง 3 แท็บ (Posts/ReDrops/Likes) เลื่อน header หายได้เหมือนกัน ไม่ใช่แค่แท็บแรก
- สลับแท็บหลังเลื่อนผ่านหัวไม่พัง ตำแหน่งเลื่อนต่อแท็บไม่รีเซ็ต
- Pull-to-refresh ทำงานปกติทั้ง 3 แท็บ
- Blocked/Private banner ทุกสถานะยังทำงานถูกต้องในโครงสร้างใหม่
- Responsive 360/360/390/430px ไม่มี overflow แม้ระหว่างลากสด ๆ
- ไม่มี duplicate `ValueKey` / ไม่ throw / ไม่เกิด "Build scheduled during frame" ในทุกกรณีที่ทดสอบ
  (การตัดสินใจใช้ `addPostFrameCallback` แก้ปัญหาเดิมได้จริง)
- การตัดสินใจไม่ใช้ `SliverOverlapAbsorber`/`Injector` ถูกต้องตามเอกสาร Flutter framework จริง
- `flutter analyze`: **0 issues**
- `flutter test`: **1149/1153 ผ่าน** (4 ที่ไม่ผ่านคือเทสต์ QA เขียนขึ้นเองเพื่อพิสูจน์ 2 บั๊กด้านล่าง
  ไม่มี regression อื่นใดในชุดเทสต์เดิม ~1150 เคส)

## Failed / บั๊กที่พบ

### QA-WYN-110-001 (Medium) — infinite-scroll ยิง fetch หน้าถัดไปซ้ำหลายครั้งต่อการเลื่อน 1 ครั้ง

**เกิดจากการเปลี่ยนแปลงของ WYN-110 นี้โดยตรง** พบใน**ทั้ง 3 แท็บ** เพราะโค้ดก็อปแพทเทิร์นเดียวกันมา

- Reproduction: pump `ProfileDropGridTab` ด้วย fake repo ที่หน้า 0 มีครบ `DropRepository.pageSize`
  (21 รายการ) ลาก 1 ครั้ง (`tester.drag`) แล้ว `pump()` 1 ครั้ง → เรียก `fetchByAuthor` **5 ครั้ง**
  แทนที่จะเป็น 2 ครั้ง (page 0 + page 1 อย่างละ 1) ยืนยันซ้ำแบบเดียวกันทั้ง `ProfileRedropsTab`
  (`fetchRedropsByUser`) และ `ProfileLikesTab` (`fetchLikedByAuthor`)
- Root cause: `_onScrollNotification` เช็ค `_isLoadingMore` ตอน notification เข้ามา แต่ตั้งค่าจริง
  ใน `_loadMore()` ที่ถูกเลื่อนไปอีก 1 เฟรมผ่าน `addPostFrameCallback` — ถ้ามีหลาย
  `ScrollNotification` เกิดก่อนเฟรมนั้นจบ (เช่น 1 การลากนิ้วที่แตกเป็นหลาย pointer move ภายใน) ทุก
  notification เห็น guard เป็น `false` เหมือนกันหมด จึงลงทะเบียน callback ซ้อนกันหลายอัน
- ผลกระทบจริง: **ไม่มี duplicate row บนจอ** (มี `_seenKeys` กันไว้แล้ว) ไม่ throw — แต่ยิง Supabase
  query ซ้ำโดยไม่จำเป็นทุกครั้งที่ผู้ใช้เลื่อนผ่านจุด near-bottom กระทบต้นทุน/ความเสี่ยง rate-limit
  จริงเมื่อขึ้น production
- Bug report เต็ม: `.wyn/tasks/bugs/WYN-110-redundant-load-more-fetches.md`
- เทสต์ที่ยืนยัน: `app/test/qa_wyn110_profile_scroll_header_test.dart` กลุ่ม "4." (3 testWidgets)

### QA-WYN-110-002 (Low, พบระหว่างตรวจแต่ไม่ใช่บั๊กของ WYN-110) — `HomeDropCard` ล้น 3px ที่ 320px

- `git diff a75c24c de4b4b0 -- .../home_drop_card.dart` **ไม่มีการเปลี่ยนแปลงเลย** — ไฟล์นี้ไม่ได้
  ถูกแตะในงานนี้ ยืนยันแล้วด้วย widget test แยก (ไม่พึ่งพา scroll/NestedScrollView เลย) ว่า
  `HomeDropCard` เดี่ยว ๆ ที่ 320px กว้าง ล้น action row (หัวใจ/คอมเมนต์/รีโพสต์/ยอดวิว) 3px แม้ยอด
  like/comment เป็น 0 — เกิดขึ้นทั้งใน Home feed และ 3 แท็บโปรไฟล์เท่า ๆ กัน (เพราะใช้ widget
  เดียวกัน) ไม่เกี่ยวกับกลไกเลื่อนที่ WYN-110 แก้เลย
- 360/390/430px ผ่านสะอาด ไม่มี overflow เลย — ยืนยันว่าเป็นปัญหาเฉพาะ 320px ของการ์ดเอง
- ไม่ควรบล็อกการอนุมัติ WYN-110 (design spec ของ WYN-110 เองก็ห้ามแตะการ์ดโพสต์) แต่ต้องบันทึกไว้
  ไม่ให้หลุดหาย แนะนำเปิด task แยก
- Bug report เต็ม: `.wyn/tasks/bugs/WYN-110-homedropcard-320px-action-row-overflow.md`

## Security Findings

- ไม่พบ secret/API key/credential หลุดในไฟล์ที่แก้ทั้ง 5 ไฟล์ lib
- ไม่มีการเปลี่ยนแปลง authentication/authorization logic ในงานนี้ (เปลี่ยนเฉพาะกลไกการเลื่อน)
- ไม่มี user data ใหม่ถูก log หรือแสดงผลผิดที่

## Recommendation

1. ส่งบั๊ก **QA-WYN-110-001** ให้ AI Debug Engineer แก้ก่อนอนุมัติขึ้น production (เป็นผลจากการ
   เปลี่ยนแปลงของ WYN-110 นี้โดยตรง กระทบทั้ง 3 แท็บ)
2. บั๊ก **QA-WYN-110-002** ให้ Founder/PM ตัดสินใจว่าจะเปิด task แยกตอนไหน — ไม่ต้องรอให้ WYN-110
   เสร็จก่อน เพราะไม่เกี่ยวข้องกัน
3. หลัง Debug Engineer แก้ QA-WYN-110-001 แล้ว ให้ QA รอบ 2 ตรวจซ้ำเฉพาะจุด: (ก) จำนวนครั้งที่ fetch
   หน้าถัดไปต้องเท่ากับ 1 ต่อการข้าม threshold, (ข) ไม่มี regression ใหม่ที่ CircularProgressIndicator
   ท้าย list, (ค) รัน `flutter test` เต็มชุดอีกครั้ง

## Final Status: **FAIL**

เหตุผล: พบบั๊กจริงที่เกิดจากการเปลี่ยนแปลงของ WYN-110 นี้โดยตรง (QA-WYN-110-001) — แม้จะไม่ crash และ
ไม่ทำให้ผู้ใช้เห็น UI ผิดปกติ (เพราะมี dedup กันไว้) แต่เป็นการเบี่ยงเบนจากพฤติกรรมที่ตั้งใจไว้จริง
("โหลดหน้าถัดไป 1 ครั้งต่อการเลื่อนใกล้ถึงล่างสุด 1 ครั้ง") และกระทบทั้ง 3 แท็บอย่างเป็นระบบ ตามกติกา
"ห้ามอนุมัติงานที่ยังไม่ได้ทดสอบจริงเด็ดขาด" จึงส่งต่อ AI Debug Engineer พร้อม bug report ทั้ง 2 ฉบับ
ก่อน ส่วน UX หลัก (หัวโปรไฟล์เลื่อนหายได้ ตามที่ Founder ร้องขอ) ทำงานถูกต้องสมบูรณ์แล้วในทุกกรณีที่
ทดสอบ — ไม่ต้องแก้ใหม่ทั้งหมด เหลือแค่แก้จุด guard เดียวใน 3 ไฟล์
