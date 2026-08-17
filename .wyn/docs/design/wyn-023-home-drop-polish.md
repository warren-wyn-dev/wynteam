# Design Spec — WYN-023: Home/Drop Polish (3 Minor QA Findings)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-023-home-drop-polish.md`
อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md`, `.wyn/docs/design/ds-001-color-system.md` (palette ปัจจุบัน Cyan/Black/White/Gray) — งานนี้ไม่ hardcode สีใหม่จุดใดเลย ใช้แค่ `Theme.of(context)` semantic token (`textTheme.bodySmall`, `colorScheme.outline`) เหมือน 4 จุดเดิมทุกประการ
อ้างอิง Pattern ที่มีอยู่แล้ว (ต้อง reuse ตรงๆ ไม่ประดิษฐ์ใหม่):
- Relative timestamp 4 จุดที่ใช้ `relativeTimeLabel()` อยู่แล้ว: `NotificationListScreen` (`app/lib/features/notification/presentation/notification_list_screen.dart`), `ClubPostCard` (`app/lib/features/club/presentation/widgets/club_post_card.dart`), ZOKY `OrderSummaryCard`, ZOKY `ReviewTile` — ทั้ง 4 จุดใช้โครงสร้างเดียวกันเป๊ะ: ข้อความ/ชื่อหลักบรรทัดบน (`titleSmall`/`bodyMedium`), เวลาบรรทัดล่างทันที (`textTheme.bodySmall?.copyWith(color: colorScheme.outline)`) ไม่มีข้อยกเว้นแม้แต่จุดเดียว
- ปุ่ม "สำรวจ Club" เดิมของ `ClubSection` (`app/lib/features/club/presentation/widgets/club_section.dart`): `OutlinedButton.icon(icon: Icons.explore_outlined, size: 18, label: Text('สำรวจ Club'))` → เปิด `ExploreClubsScreen`
- Design spec เดิมของ WYN-015 (`.wyn/docs/design/wyn-015-club-discovery-integration.md`, Screen 5) ที่ล็อกข้อความ empty state "เข้าร่วม Club เพื่อดูโพสต์ที่นี่" และตั้งใจให้มีปุ่ม "สำรวจ Club" ไปหน้า `ExploreClubsScreen` ไว้อยู่แล้วตั้งแต่ต้น (Coding รอบนั้นแค่ไม่ได้ใส่ปุ่มจริง)

## ทิศทางภาพรวม: งานเก็บกวาด — ไม่มีการตัดสินใจ visual ใหม่แม้แต่จุดเดียว

ทั้ง R1 และ R3 มี pattern ที่ผ่าน QA แล้วในระบบตรงตามที่ต้องการอยู่แล้ว งานของ Design รอบนี้คือ "ชี้ตำแหน่ง/ยืนยันว่า reuse อันไหนตรงที่สุด" ไม่ใช่คิดหน้าตาใหม่ ไม่มี schema change ไม่มี component ใหม่แม้แต่ตัวเดียว — R3 สร้าง widget instance ใหม่ (ปุ่ม) แต่เป็นการก็อปปี้ config จากปุ่มที่มีอยู่แล้วตรงๆ ไม่ใช่ component ใหม่ R2 ไม่ต้องมี Design เลยตามที่ Product Task ระบุไว้ตรงๆ อยู่แล้ว (ส่งตรง AI Coding)

---

## R1: Relative timestamp บน `HomeDropCard`

Screen/Component: `HomeDropCard` (`app/lib/features/home/presentation/widgets/home_drop_card.dart`) — widget เดียวถูก reuse ทั้ง Home feed (WYN-007) และ Drop feed ทั้ง 3 tab For You/Following/Latest (WYN-019) โดยอัตโนมัติ เพราะทั้งสองจุดเรียก `HomeDropCard` ตัวเดียวกันผ่าน `HomeFeedItem`/`HomeFeedItem.fromDrop()` — แก้ไฟล์เดียว มีผลทั้งสองจุดทันที ไม่ต้องแก้ที่ `DropFeedScreen` เลย

Purpose: ปิด gap ที่ QA รอบ 3 ของ WYN-005 (2026-08-14) เจอไว้เป็น Minor — การ์ด Drop ไม่มีทั้ง relative time และ absolute time เลย ผู้ใช้ไม่รู้ว่าโพสต์นี้เก่าแค่ไหน

Decision (ตำแหน่งวาง): เพิ่มเป็น**บรรทัดที่สองใต้ชื่อผู้เขียนในบล็อก header เดิม** (ไม่ใช่ badge มุมขวาบนรูปแบบ duration ของ `HomePopCard`, ไม่ใช่ต่อท้ายชื่อในบรรทัดเดียวกันคั่นด้วย "·", ไม่ใช่ในแถวปฏิสัมพันธ์ Like/Comment/Share/Save ด้านล่างสุด)

เหตุผล:
1. **ตรงกับตำแหน่งของทั้ง 4 จุดที่มีอยู่แล้วในระบบเป๊ะ ไม่มีข้อยกเว้นเลยสักจุด** — Notification, Club post, ZOKY order, ZOKY review ทั้งหมดวางเวลาไว้บรรทัดที่สองใต้ชื่อ/ข้อความหลัก ด้วย `bodySmall` + `colorScheme.outline` แบบเดียวกันหมด นี่คือ convention เดียวที่แอปมีสำหรับ "เวลาประกอบเนื้อหา" — ไม่มีเหตุผลใดที่ `HomeDropCard` ควรต่างออกไป
2. **`ClubPostCard` มีโครงสร้าง header เดียวกับ `HomeDropCard` เป๊ะอยู่แล้ว**: ทั้งคู่เป็น `Row(AvatarCircle 16px + SizedBox(space2) + ชื่อผู้เขียน titleSmall)` — ต่างกันแค่ `ClubPostCard` ห่อชื่อด้วย `Expanded(Column(...))` ที่มีบรรทัดเวลาอยู่ข้างใต้อยู่แล้ว ส่วน `HomeDropCard` ยังเป็น `Text` เดี่ยวๆ การแก้จึงเป็นการ "เติมบรรทัดที่ `ClubPostCard` มีอยู่แล้ว" ล้วนๆ ไม่ใช่ปรับ layout ใหม่
3. **บล็อก header นี้ (avatar+ชื่อ) ห่อด้วย `InkWell(onTap: onOpenProfile)` แยกจาก `InkWell(onTap: onTap)` ของทั้งการ์ด** อยู่แล้ว — เวลาที่เพิ่มเข้าไปในบล็อกเดียวกันจึงเป็นส่วนหนึ่งของ tap target "ไปโปรไฟล์" โดยธรรมชาติ ไม่ใช่ tap target ใหม่ที่ต้องตัดสินใจเพิ่ม
4. ตำแหน่งมุมขวาบนของรูป (แบบ duration badge ของ `HomePopCard`) ถูกปฏิเสธ เพราะ pattern นั้นออกแบบมาเฉพาะสื่อ "ความยาววิดีโอ" ไม่ใช่ "เวลาที่โพสต์" — คนละความหมาย ถ้าเอามาใช้ผิดที่จะกลายเป็น pattern เวลาที่สองคู่ขนานกับ 4 จุดเดิม ขัดกับหลัก consistency ที่งานนี้เน้นย้ำที่สุด

Components (การเปลี่ยนแปลงที่ต้องทำใน `HomeDropCard`):
- Header `Row` เดิม (`AvatarCircle` + `SizedBox(width: WynSpacing.space2)` + `Text(item.authorNameOrUsername, style: titleSmall)`) เปลี่ยนส่วนสุดท้ายจาก `Text` เดี่ยวๆ เป็น:
  ```
  Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.authorNameOrUsername, style: Theme.of(context).textTheme.titleSmall),
        Text(
          relativeTimeLabel(item.createdAt, now: DateTime.now()),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    ),
  )
  ```
  (โครงสร้างนี้ก็อปมาจาก `ClubPostCard`'s header ตรงๆ ทุก property)
- `Row` เดิมมี `mainAxisSize: MainAxisSize.min` — **ต้องเอาออก** (กลับไปใช้ default `MainAxisSize.max`) เพราะตอนนี้มี `Expanded` เป็นลูก ซึ่งต้องพึ่งความกว้างที่เหลือของ `Row` — ถ้ายังเป็น `min` อยู่ `Expanded` จะ error/ไม่ทำงานถูกต้อง (ไม่มีขอบเขตให้ยืด)
- `import '../../../../core/text_utils.dart';` เพิ่มเข้า `home_drop_card.dart` (ยังไม่มี import นี้ในไฟล์ปัจจุบัน)
- ใช้ `relativeTimeLabel()` ตรงๆ ตาม Requirement R1 — ไม่เขียนฟังก์ชันใหม่ ไม่ format เอง `item.createdAt` มีอยู่แล้วเป็น field ของ `HomeFeedItem` (`app/lib/features/home/data/home_feed_item.dart`) ทั้งฝั่ง Home feed และ Drop feed (ผ่าน `HomeFeedItem.fromDrop()`) อยู่แล้ว — **ไม่มี schema/data change ใดๆ ในงานนี้**

Interactions: ไม่เปลี่ยนพฤติกรรมเดิมของการ์ด — เวลาที่เพิ่มเข้ามาไม่ใช่ tap target แยก อยู่ในบล็อก header ที่ไปโปรไฟล์เดิม (`onOpenProfile`) เหมือน avatar/ชื่อ

States: ไม่มี state ใหม่ที่ต้อง track — `relativeTimeLabel()` เป็น pure function คำนวณจาก `item.createdAt` ใหม่ทุกครั้งที่ build เหมือนทั้ง 4 จุดเดิม (ไม่ cache ผลลัพธ์ ไม่มี `Timer` มาคอย refresh label ระหว่างอยู่ในหน้าเดียวกันนานๆ — ตรงกับพฤติกรรมเดิมของทั้ง 4 จุดที่ไม่มีจุดไหนทำ auto-refresh เวลาเช่นกัน ไม่ใช่ gap ใหม่ที่งานนี้สร้างขึ้น)

Accessibility: ไม่ต้องเพิ่ม `Semantics` wrapper แยกให้ `Text` เวลา — ตรงกับทั้ง 4 จุดเดิมที่ไม่มีจุดไหนห่อ `Semantics` เพิ่มให้เวลาเช่นกัน ปล่อยให้ screen reader อ่านต่อจากชื่อไปตามลำดับ widget tree ตามธรรมชาติ (เป็นข้อมูลเสริมของ header เดิม ไม่ใช่ tap target ใหม่ที่ต้องมี label ของตัวเอง) — `Semantics(label: 'รูปของ ${item.authorNameOrUsername}', ...)` ที่ห่อทั้งการ์ดอยู่แล้วไม่ต้องแก้ (ยังคงอธิบาย "การ์ดนี้คือรูป" ถูกต้อง ไม่ใช่หน้าที่ของมันจะบอกเวลาโพสต์)

Responsive Behavior: เวลาไม่มีทางยาวเกิน 1 บรรทัดเพราะ format ของ `relativeTimeLabel()` สั้นเสมอ (ยาวสุดคือ absolute date เช่น "14/8/2026") ชื่อผู้เขียนที่ยาวเกินพื้นที่ยังคง behavior เดิมของ `Text` (ไม่มี overflow handling อยู่ก่อนแล้วในโค้ดปัจจุบัน — นอกขอบเขตของงานนี้ที่จะเพิ่ม ellipsis ให้ชื่อ ถือเป็นสภาพเดิมของโค้ด ไม่ใช่ regression ใหม่จาก R1)

Non-goal ที่ตั้งใจไม่ทำรอบนี้ (บันทึกไว้ให้ชัดเจน ไม่ใช่ oversight): **`HomePopCard` (การ์ด Pop ที่อยู่ในฟีดเดียวกันของ Home) ไม่อยู่ในขอบเขต R1** — Product Task WYN-023 ระบุเจาะจงแค่ `HomeDropCard` เท่านั้น (ตรงกับ QA finding เดิมของ WYN-005 ที่เจอเฉพาะฝั่ง Drop) ผลคือหลัง fix นี้ การ์ด Drop จะมี timestamp แต่การ์ด Pop ที่ scroll สลับกันอยู่ในฟีดเดียวกันจะยังไม่มี เกิดความไม่สอดคล้องกันเองระหว่างการ์ด 2 ประเภทในหน้าเดียว — แนะนำเป็น fast-follow ทำแบบเดียวกันทุกประการกับ `HomePopCard` ในรอบถัดไป (ระบุไว้ใน Handoff ด้านล่างให้ Product พิจารณา ไม่ทำเองในงานนี้เพราะเกินขอบเขตที่ Product กำหนด)

---

## R2: `openCommentsOnStart` — ไม่ต้อง Design

ตามที่ Product Task ระบุไว้ตรงๆ ว่าเป็น behavior fix ล้วนๆ ไม่มี UI ใหม่ (เร่งเปิด comment sheet ที่มีอยู่แล้วให้เร็วขึ้นเท่านั้น ไม่มีหน้าตาใหม่ ไม่มีตำแหน่งใหม่ ไม่มีการตัดสินใจ visual/UX เพิ่มเติม) — AI Design ยืนยันแล้วว่าไม่มีจุดใดต้องตัดสินใจเรื่อง HOW เพิ่ม ส่งตรง AI Coding ตาม Handoff ของ Product Task

Reference สำหรับ AI Coding (ระบุพิกัดโค้ดที่เกี่ยวข้องเพื่อความชัดเจน ไม่ใช่ design decision ใหม่): `PopSingleClipScreen` (`app/lib/features/home/presentation/pop_single_clip_screen.dart`) เป็นตัวห่อบางๆ รอบ `PopClipView` (`app/lib/features/pop/presentation/widgets/pop_clip_view.dart`) ที่มี `_openComments()` อยู่แล้ว (เรียกจาก Comment icon ที่มีอยู่แล้วในแถวปฏิสัมพันธ์)

---

## R3: ปุ่ม "สำรวจ Club" ใน empty state ของ "จาก Club ของคุณ"

Screen/Component: `FromYourClubsFeed` (`app/lib/features/home/presentation/widgets/from_your_clubs_feed.dart`) — empty state ปัจจุบัน (`if (_posts.isEmpty) { return const Center(child: Padding(..., child: Text('เข้าร่วม Club เพื่อดูโพสต์ที่นี่', ...))); }`)

Purpose: ปิด gap ที่ Design spec เดิมของ WYN-015 (`.wyn/docs/design/wyn-015-club-discovery-integration.md`, Screen 5) ตั้งใจไว้ตรงๆ อยู่แล้วแต่ Coding รอบนั้นไม่ได้ใส่ปุ่มจริง — spec เดิมระบุว่า "มีแค่ปุ่ม 'สำรวจ Club' ให้ไปหน้า [ExploreClubsScreen] แทน" QA รอบ 1 ของ WYN-015 เจอเป็น Minor ไม่ block เพราะปุ่มเดิมของ `ClubSection` เหนือ toggle ยังกดได้อยู่เสมอ (ผู้ใช้ไม่ตันจริง) แต่ก็ยังไม่ตรง spec ที่ตั้งใจไว้

Decision (หน้าตา/ปุ่ม): **ใช้ปุ่มเดียวกันเป๊ะกับปุ่ม "สำรวจ Club" ที่มีอยู่แล้วใน `ClubSection`** (`app/lib/features/club/presentation/widgets/club_section.dart`): `OutlinedButton.icon(icon: const Icon(Icons.explore_outlined, size: 18), label: const Text('สำรวจ Club'))`

เหตุผล: เป็นปุ่มที่ไปปลายทางเดียวกัน (`ExploreClubsScreen`) จากหน้าเดียวกัน (Home) ห่างกันแค่ scroll position (เหนือ/ใต้ toggle "สำหรับคุณ"/"จาก Club ของคุณ") — ใช้ icon/label/style ต่างกันสำหรับปลายทางเดียวกันจะทำให้ผู้ใช้เข้าใจผิดว่าเป็นคนละฟีเจอร์ ไม่มีเหตุผลใดที่ควรต่างกัน ยิ่งเหมือนกันเป๊ะยิ่งสื่อสารชัดว่า "นี่คือทางลัดเดียวกัน"

Components:
- Empty state เปลี่ยนจาก `Text` เดี่ยวๆ กลางจอ เป็น:
  ```
  Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('เข้าร่วม Club เพื่อดูโพสต์ที่นี่', textAlign: TextAlign.center),
          const SizedBox(height: WynSpacing.space3),
          OutlinedButton.icon(
            onPressed: _openExploreClubs,
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('สำรวจ Club'),
          ),
        ],
      ),
    ),
  )
  ```
- ข้อความเดิม "เข้าร่วม Club เพื่อดูโพสต์ที่นี่" **ไม่เปลี่ยน** (ล็อกไว้แล้วตาม WYN-015 spec เดิม) เพิ่มแค่ปุ่มต่อท้ายด้วยระยะห่าง `WynSpacing.space3`
- ระยะห่าง `space3` นี้ reuse ค่าที่ไฟล์เดียวกันใช้อยู่แล้วเองใน `_error` state (ข้อความ error → `SizedBox(height: WynSpacing.space3)` → ปุ่ม "ลองใหม่") — ไม่ต้องคิดค่า spacing ใหม่ ใช้ pattern เดียวกับที่มีอยู่แล้วในไฟล์นี้เอง

Interactions:
- เพิ่มเมธอดใหม่ `_openExploreClubs()` ใน `_FromYourClubsFeedState` (ชื่อเดียวกับเมธอดใน `ClubSection` โดยตั้งใจ เพื่อให้ค้นหา/เทียบโค้ดง่าย): `await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExploreClubsScreen(clubRepository: widget.clubRepository, clubPostRepository: widget.clubPostRepository)))` — widget มี `clubRepository`/`clubPostRepository` เป็น field อยู่แล้ว ไม่ต้องส่งของใหม่เข้ามาจาก caller
- หลังกลับจาก `ExploreClubsScreen` เรียก `_loadInitial()` ทันที — มิเรอร์ pattern เดียวกับ `ClubSection._openExploreClubs()` ที่เรียก `_reload()` เสมอหลังกลับมา (เผื่อผู้ใช้ join Club ใหม่ระหว่างอยู่หน้า Explore แล้วกลับมาที่ toggle "จาก Club ของคุณ" ควรเห็นโพสต์ทันทีโดยไม่ต้อง pull-to-refresh เอง)
- ต้อง import `ExploreClubsScreen` เพิ่ม: `import '../../../club/presentation/explore_clubs_screen.dart';`

States: ไม่มี state ใหม่ที่ต้อง track — ปุ่มปรากฏเฉพาะตอนเข้าเงื่อนไข empty state เดิมที่มีอยู่แล้ว (`_posts.isEmpty` หลังโหลดเสร็จไม่มี error) หายไปเองทันทีที่ `_loadInitial()` เจอโพสต์ (กลไก `setState` เดิมของไฟล์นี้ ไม่ต้องเพิ่ม flag ใหม่)

Accessibility: `OutlinedButton.icon` มาตรฐานของ Flutter มี accessible name จาก label text ("สำรวจ Club") ให้อัตโนมัติอยู่แล้ว — เหมือนปุ่มต้นแบบใน `ClubSection` ที่ไม่มี `Semantics` wrapper เพิ่มเช่นกัน ไม่ต้องเพิ่มอะไร

Responsive Behavior: ปุ่มอยู่กึ่งกลางแนวนอน (สืบทอดจาก `Center`/`Column(mainAxisSize: min)`) ความกว้างพอดีกับเนื้อหา ไม่ยืดเต็มจอ — เหมือนปุ่ม "ลองใหม่" ของ `_error` state ในไฟล์เดียวกันทุกประการ

---

## Design Rules (รวมทั้งงาน)

- ห้ามสร้าง pattern ใหม่แม้แต่จุดเดียวในงานนี้ — ทุกจุด reuse widget/style/constant ที่มีอยู่แล้วและผ่าน QA แล้ว 100%
- R1: ตำแหน่งเวลาต้องตรงกับ 4 จุดเดิมเป๊ะ (บรรทัดที่ 2 ใต้ชื่อ/ข้อความหลัก, `textTheme.bodySmall` + `colorScheme.outline`) — ห้ามใช้ตำแหน่ง/สไตล์อื่น
- R3: ปุ่ม "สำรวจ Club" ต้องเหมือนปุ่มต้นแบบใน `ClubSection` เป๊ะ (icon `Icons.explore_outlined` ขนาด 18, label "สำรวจ Club", `OutlinedButton.icon`) เพราะเป็นทางลัดไปปลายทางเดียวกัน
- ไม่มีการเปลี่ยน color token/typography scale/spacing scale ใหม่ใดๆ ในงานนี้ — ใช้ของเดิมทั้งหมด สอดคล้องกับ Priority "กลาง" และ Risk "แทบไม่มี" ที่ Product Task ระบุไว้
- ไม่แตะ `HomePopCard`/`PopClipView`'s ปุ่ม/หน้าตาอื่นใดนอกเหนือจากที่ระบุไว้ใน R1-R3 ข้างต้น

## Handoff: AI Coding

1. **R1**: แก้ `app/lib/features/home/presentation/widgets/home_drop_card.dart` เท่านั้น — header `Row`'s `Text(authorNameOrUsername)` → `Expanded(Column([ชื่อ, relativeTimeLabel(item.createdAt, now: DateTime.now())]))` ตาม Decision/Components ด้านบน, เอา `mainAxisSize: MainAxisSize.min` ออกจาก `Row` นั้น, เพิ่ม import `core/text_utils.dart` — มีผลอัตโนมัติทั้ง Home feed (WYN-007) และ Drop feed ทั้ง 3 tab (WYN-019) เพราะ reuse widget เดียวกัน ไม่ต้องแก้ที่ `drop_feed_screen.dart`/`home_feed_screen.dart` เลย
2. **R2**: เพิ่ม `openCommentsOnStart` (`bool`, default `false`) ให้ constructor ของ `PopClipView` — เมื่อ `true` ให้เรียก `_openComments()` เองหลัง widget พร้อมแสดงผล (ระวัง: ถ้า `_openComments()` พึ่ง `context`/`showModalBottomSheet` ที่ต้องมี widget tree build เสร็จก่อน ให้เรียกผ่าน `WidgetsBinding.instance.addPostFrameCallback` ใน `initState` แทนเรียกตรงๆ ใน `initState`) จากนั้นให้ `PopSingleClipScreen` รับ/ส่งต่อ flag นี้เข้า `PopClipView` — จุดที่ต้องหา: caller ปัจจุบันที่เปิด `PopSingleClipScreen` จากไอคอน Comment ของการ์ด Pop ใน Home (`home_feed_screen.dart`) ต้องแยกให้ `onTap` ปกติ (แตะรูป/ชื่อ) ส่ง `openCommentsOnStart: false` (หรือไม่ระบุ ใช้ default) ต่างจาก `onTap` ของไอคอน Comment โดยเฉพาะที่ต้องส่ง `true`
3. **R3**: แก้ `app/lib/features/home/presentation/widgets/from_your_clubs_feed.dart` เท่านั้น — empty state ตาม Decision/Components ด้านบน, เพิ่มเมธอด `_openExploreClubs()`, เพิ่ม import `ExploreClubsScreen`
4. เขียน regression test ให้ครบตาม Acceptance Criteria ของ Product Task:
   - `HomeDropCard` แสดง `relativeTimeLabel(item.createdAt, now: ...)` ถูกต้อง ทดสอบทั้งจาก `home_feed_screen_test.dart` (Home feed) และจุดที่ทดสอบ Drop tab ของ WYN-019 (`drop_feed_screen_test.dart` หรือเทียบเท่า) — ยืนยันว่าแก้ไฟล์เดียวมีผลทั้งสองที่จริง
   - `openCommentsOnStart: true` เปิด comment sheet ทันทีโดยไม่ต้องแตะซ้ำ, `false`/ไม่ระบุ (default) ไม่เปิดอัตโนมัติ — ป้องกัน regression กับพฤติกรรมเดิมตอนเปิดคลิปจากทางอื่น (เช่นจาก `PopFeedScreen`เดิมที่ไม่ควรมี auto-open)
   - ปุ่ม "สำรวจ Club" ใน `FromYourClubsFeed`'s empty state กดแล้ว navigate ไป `ExploreClubsScreen` จริง และ `_loadInitial()` ถูกเรียกซ้ำหลังกลับมา (mock/spy `ClubRepository`/`ClubPostRepository` ตาม pattern `Recording*Repository` เดิมของโปรเจกต์)
5. `flutter analyze`/`flutter test` ต้องผ่านครบ ไม่มี regression กับ WYN-005/WYN-007/WYN-012/WYN-014/WYN-015/WYN-019 ตาม Acceptance Criteria ของ Product Task
6. **บันทึกไว้ให้ Product พิจารณาเป็น fast-follow** (ไม่ใช่ scope ของ WYN-023): `HomePopCard` ยังไม่มี timestamp หลังงานนี้เสร็จ (ดู Non-goal ใน R1 ด้านบน) — ถ้า Product เห็นด้วย แนะนำทำ task เล็กแยกต่อยอด ใช้ pattern เดียวกันเป๊ะกับ R1 นี้ ความเสี่ยงต่ำเท่ากัน

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement R1/R2/R3 ตาม Design decisions ข้างต้น — ดู Product Task `.wyn/tasks/backlog/WYN-023-home-drop-polish.md` สำหรับ Requirements/Acceptance Criteria/Risks ฉบับเต็ม
