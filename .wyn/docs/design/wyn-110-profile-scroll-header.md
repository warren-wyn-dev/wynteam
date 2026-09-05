# Design Spec — WYN-110: หัวโปรไฟล์ต้องเลื่อนหายไปได้

Owner: AI Design (เสร็จ) → AI Coding
Ref: Founder รายงานบั๊กผ่านคลิปหน้าจอ 2026-09-05 ("เลื่อนดูโพสต์ในโปรไฟล์ แล้วดูได้ครึ่งเดียว
โปรไฟล์ไม่เลื่อนตาม") — อนุมัติ preview แล้ว ("ทำเลย")
Preview ที่อนุมัติ: Artifact "โปรไฟล์เลื่อนไม่ตาม" (สอง phone-frame เลื่อนได้จริง เทียบก่อน/หลัง)

## ปัญหา

`ViewProfileScreen` วางหัวโปรไฟล์ (avatar/ชื่อ/@username/bio/สถิติ/ปุ่ม) และ `TabBar`
(โพสต์/รีโพสต์/ถูกใจ) เป็น `Column` ธรรมดาที่ไม่เลื่อน มีแค่ `Expanded(TabBarView)` ที่เลื่อนได้
(`view_profile_screen.dart:998-1336` ก่อนแก้) ผลคือหัวกินพื้นที่จอค้างไว้ตลอด ไม่ว่าจะเลื่อนโพสต์
ลึกแค่ไหน — ผู้ใช้เห็นเนื้อหาโพสต์ได้แค่ครึ่งจอที่เหลือ

## Screen

`ViewProfileScreen` — ทั้งโปรไฟล์ตัวเอง (`isOwnProfile == true`) และโปรไฟล์คนอื่น

## Purpose

ให้หัวโปรไฟล์เลื่อนหายไปตามปกติเมื่อเลื่อนดูโพสต์ แล้วให้ `TabBar` ค้างติดขอบบนแทน (แทนที่จะกิน
พื้นที่ถาวร) — พฤติกรรมเดียวกับ Instagram/Threads และเหมือนที่ `home_feed_screen.dart` ทำอยู่แล้ว
กับแบนเนอร์อธิบายของ Home (`SliverToBoxAdapter` + `SliverPersistentHeader(pinned: true)`)

## User Flow

ไม่เปลี่ยนจากปัจจุบันเลยสักจุด — เปิดโปรไฟล์ → เลื่อนดูโพสต์ → ปุ่ม Follow/Message/แก้ไขโปรไฟล์
ทำงานเหมือนเดิมทุกประการ กด tab สลับได้เหมือนเดิม infinite-scroll โหลดหน้าถัดไปเหมือนเดิม
เปลี่ยนแค่ "กลไกการเลื่อน" ไม่เปลี่ยน logic ใด ๆ

## Components

1. `NestedScrollView` แทนที่ `Column` เดิมทั้งก้อนใน body ของ `Scaffold`
   - `headerSliverBuilder`: `SliverToBoxAdapter(header)` → (ถ้าไม่ใช่โปรไฟล์ตัวเอง)
     `SliverToBoxAdapter(ProfileRecommendationSection)` → `SliverPersistentHeader(pinned: true,
     delegate: _ProfileTabBarDelegate(TabBar))`
   - `body`: `TabBarView` เดิมทุกประการ (3 children เหมือนเดิม)
2. `_ProfileTabBarDelegate` — คัดลอก pattern จาก `_FeedModeToggleHeaderDelegate` ใน
   `home_feed_screen.dart` แต่ใช้ `tabBar.preferredSize.height` แทนค่าคงที่ที่วัดมือ (TabBar เป็น
   `PreferredSizeWidget` อยู่แล้ว ไม่ต้องเดา/วัดเอง) พื้นหลัง `Material(color: WynColors.paper)`
   กันโพสต์ที่เลื่อนผ่านทะลุขึ้นมาเห็น
3. แต่ละแท็บ (`ProfileDropGridTab`/`ProfileRedropsTab`/`ProfileLikesTab`) เปลี่ยนจาก
   `ListView.separated` เป็น `CustomScrollView` ที่มี `SliverOverlapInjector` เป็น sliver แรกเสมอ
   (คู่กับ `NestedScrollView.sliverOverlapAbsorberHandleFor(context)`) ตามด้วย `SliverList.separated`
   ที่พอร์ต `itemBuilder`/`separatorBuilder`/`itemCount` เดิมมาตรง ๆ ไม่เปลี่ยน widget ภายในเลย
   - เอา `ScrollController` ส่วนตัวของแต่ละแท็บออก (ขัดกับกลไกของ `NestedScrollView` ที่ต้องเป็น
     คนจ่าย controller ให้เอง) เปลี่ยนการตรวจจับ "ใกล้ถึงล่างสุด → โหลดหน้าถัดไป" จาก
     `ScrollController.addListener` เป็น `NotificationListener<ScrollNotification>` ครอบ
     `CustomScrollView` แทน (เกณฑ์ 300px จากล่างสุดเดิมทุกประการ)
   - สถานะ loading เริ่มต้น/error/ว่างเปล่า **ไม่เปลี่ยน** ยังเป็น `Center(...)` ธรรมดานอก
     `CustomScrollView` เหมือนเดิม (มีแค่ตอนมีข้อมูลจริงเท่านั้นที่กลายเป็น sliver)

## Interactions

ไม่เปลี่ยน — Follow/Message/Like/Save/ReDrop/Vote/pull-to-refresh/infinite-scroll ทำงานเหมือนเดิม
ทุกจุด สิ่งเดียวที่ต่างคือหัวโปรไฟล์เลื่อนหายไปได้แล้ว และ `TabBar` ค้างขอบบนแทนที่จะกินพื้นที่ถาวร

## States

- Blocked/Private banner (`_buildBlockedBanner`) — ยังแทนที่ stats+ปุ่มเหมือนเดิม อยู่ใน
  `SliverToBoxAdapter(header)` เดียวกัน ไม่แยก sliver ใหม่
- `PrivacyNoticeBanner` ในแท็บถูกใจ — คงตำแหน่งเดิม (อยู่นอก `CustomScrollView` ของ
  `ProfileLikesTab`, ไม่ได้เลื่อนไปกับโพสต์) ไม่ขยายขอบเขตงานนี้ไปแตะจุดนั้น
- ตำแหน่งเลื่อนของแต่ละแท็บเมื่อสลับไปมา — ยังคงจำได้เหมือนเดิม (`AutomaticKeepAliveClientMixin`
  เดิมไม่ถอด — `NestedScrollView` ผูก controller ให้แต่ละแท็บแยกกันเองโดยอัตโนมัติ)

## Responsive Behavior

ทดสอบที่ 320/360/390/430 — หัวโปรไฟล์เลื่อนหายไปได้ทุกขนาดจอ ไม่ทำให้ `TabBar` ล้นหรือ overflow

## Accessibility

ไม่กระทบ Semantics เดิมทั้งหมด (ปุ่มสถิติ/ปุ่ม Follow/ปุ่ม Message) ยังอยู่ครบตามเดิม

## Design Rules

- ห้ามเปลี่ยนสี/ตำแหน่ง/ทรงของ element ใดในหัวโปรไฟล์หรือการ์ดโพสต์ งานนี้แก้เฉพาะกลไกการเลื่อน
- ห้ามแตะ `ProfileSavedTab`/`ProfilePopGridTab`/`ProfileRepliesTab` (ไม่ได้ใช้งานจริงใน
  `ViewProfileScreen` ปัจจุบัน อยู่นอกขอบเขต)

## Handoff

1. `view_profile_screen.dart` — `Column` → `NestedScrollView`, เพิ่ม `_ProfileTabBarDelegate`
2. `profile_drop_grid_tab.dart` / `profile_redrops_tab.dart` / `profile_likes_tab.dart` —
   `ListView.separated` → `CustomScrollView([SliverOverlapInjector, SliverList.separated])`,
   ถอด `ScrollController` ส่วนตัว เปลี่ยนเป็น `NotificationListener<ScrollNotification>`
3. เทสต์ต้องคุม: header เลื่อนหายไปได้จริง (วัดตำแหน่งก่อน/หลัง drag), `TabBar` ค้างขอบบนหลังเลื่อน
   ผ่านหัว, infinite-scroll ยังโหลดหน้าถัดไปได้, pull-to-refresh ยังทำงาน, สลับแท็บแล้วกลับมา
   ตำแหน่งเลื่อนไม่รีเซ็ต
4. `flutter analyze` + `flutter test` ผ่านครบ
