# Design — WYN-024: Bottom Navigation V1.0.0 Restructure

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-024-bottom-nav-v1-restructure.md`, `.wyn/docs/product/wyn-v1.0.0-master-spec.md` (Section 34), `.wyn/company/DECISIONS.md` (2026-08-22)

> ใช้ Design system ที่อนุมัติแล้ว (DS-001–008, Cyan/Orange) ต่อไปจนกว่า DS-009 จะมีคำตอบ — งานนี้ไม่คิดทิศทางสีใหม่ ไม่แตะ token ใดๆ
>
> **Brand copy**: ทุกข้อความ UI ใหม่ที่เขียนในงานนี้ใช้ "WYNOS" ไม่ใช่ "WYN" (เช่น title bar, empty state, onboarding copy ถ้ามีจุดที่พูดชื่อแบรนด์ตรงๆ) ตามที่ Founder ยืนยัน 2026-08-22 — ชื่อ table/class/variable ในโค้ดยังเป็น `wyn`/`Wyn*` เหมือนเดิม ไม่เปลี่ยน

## Founder decision ที่ใช้เป็นฐานของงานนี้ (2026-08-22, ยืนยันผ่าน popup)

**Drop feed (WYN-019–022: For You/Following/Latest ผูก Hashtag/Mention/Reply) ยุบเข้า Home** แทนที่จะเก็บไว้ที่อื่นหรือฝืนคง Drop เป็น tab แยก — เหตุผล: ตรงกับ Master Spec Section 1 ("Home Feed: สองโหมด For You/Following") มากที่สุด และไม่มีการสูญเสีย capability ใดๆ (ทุก query/ranking/hashtag/mention logic ที่ WYN-019–022 สร้างไว้ยังใช้ได้เหมือนเดิม แค่เปลี่ยนที่ mount)

---

## Screen 1 — Bottom Navigation Shell (`RootShell`)

Purpose: โครง navigation หลักของแอป `app/` ให้ตรงกับ Master Spec Section 34

User Flow: ผู้ใช้แตะแท็บใดก็ตามเพื่อสลับหน้าหลัก ยกเว้น "Drop" ที่เป็นปุ่ม action (เปิดหน้าสร้าง Drop แบบ modal/push แล้วปิดกลับมาที่แท็บเดิม ไม่ใช่การสลับหน้า)

```
NavigationBar (5 destinations):
  🏠 Home          -> HomeFeedScreen (index 0, ค่าเริ่มต้น)
  🔍 Search        -> SearchScreen (index 1)
  ＋ Drop          -> action button, push CreateDropScreen แล้ว pop กลับ (ไม่ใช่ index จริง)
  🔔 Notifications -> NotificationListScreen (index 2)
  👤 Profile       -> ViewProfileScreen (index 3)
```

Components:
- **`NavigationBar`** เดิม (Material 3) — คง widget เดิม ลด `destinations` จาก 5 เหลือ 4 index จริง + 1 action
- **Drop action button**: ใช้ตำแหน่งกึ่งกลาง visual เดิม (index 2 เดิม) แต่ **ไม่ผูกกับ `IndexedStack` index** — `onDestinationSelected` แยกเคสนี้ออกมาต่างหาก ไม่เรียก `setState(() => _index = ...)' เหมือน 3 ปุ่มที่เหลือ ให้เรียก `_openCreateDrop()` (push `CreateDropScreen`, ปิดแล้วกลับที่แท็บเดิมที่ user ค้างอยู่ก่อนกด) — mirror ของ `DropFeedScreen._openCreateDrop` เดิมเป๊ะ ย้าย logic มาไว้ที่ `RootShell` แทน
- ไอคอน Drop ใช้ `Icons.add_circle_outline` (unselected) / `Icons.add_circle` (selected-look ตอนกด แต่ไม่ต้องมี selected state ค้างเพราะไม่ใช่ tab จริง — แสดงแค่ ripple ตอนแตะ) — ไม่ใช้ FAB ลอย (นอก `NavigationBar`) เพื่อคง 1 แถบเดียวเรียบง่าย ตรงกับกติกา "ห้ามลอก Layout ของ Instagram/TikTok/Threads โดยตรง" (Instagram ใช้ปุ่มกลางไม่มี background พิเศษอยู่แล้ว จึงไม่ใช่การลอก แค่ทำหน้าที่เดียวกันในเชิง pattern มาตรฐานของ compose action)
- `Semantics(label: 'สร้าง Drop ใหม่', button: true)` ต้องมีบนปุ่มนี้ชัดเจน เพราะ screen reader ต้องไม่พูดว่า "Drop, selected" แบบ tab อื่น (มันไม่ใช่ tab)

Interactions:
- แตะ Home/Search/Notifications/Profile → สลับ `IndexedStack` index ปกติ (คง pattern `_profileVisitKey` bump เดิมของ Profile ไว้ทุกประการ — WYN-008's fix)
- แตะ Drop → push `CreateDropScreen`; สำเร็จ (`created == true`) → home ไม่ต้อง auto-refresh ทันที (จะ refresh เองตอน user pull-to-refresh หรือกลับมาที่ Home ใหม่) — **ต่างจาก DropFeedScreen เดิมที่ bump `_feedVersion` ทันทีเพราะตัวเองเป็นเจ้าของ feed** ตอนนี้ Home เป็นเจ้าของ feed แทน ให้ `RootShell` โยนสัญญาณ "created" ไปให้ `HomeFeedScreen` ผ่าน callback/`GlobalKey` เพื่อ prepend Drop ใหม่เข้า feed ทันที (ประสบการณ์เดิมที่ user คาดหวังหลังโพสต์ ต้องไม่หายไป)

States: ไม่มี state พิเศษเพิ่มจากเดิม (ปุ่ม Drop ไม่มี "selected" state ค้าง)

Responsive Behavior: เหมือนเดิมทุกประการ (`NavigationBar` responsive อยู่แล้ว)

Accessibility: Semantics label ของปุ่ม Drop ต้องระบุว่าเป็น action ไม่ใช่ tab (ดูข้างบน) — 4 tab ที่เหลือคง Semantics เดิม

Design Rules: ใช้ Design system เดิม (DS-001–008) ทั้งหมด ไม่มีการเปลี่ยนสี/ธีม — ถอด `Icons.storefront`/ZOKY-orange selected-icon ออกจากไฟล์นี้ทั้งหมด (WynColors.orange500 reference ใน `root_shell.dart` ต้องหายไป เพราะ ZOKY tab ไม่อยู่แล้ว) — ถอด `Icons.play_circle` (Pop) ออกเช่นกัน

Handoff: ส่ง AI Coding — ไฟล์หลักที่แก้: `app/lib/features/root/presentation/root_shell.dart` (ตัด tabs array เหลือ 4 จริง + Drop action, ตัด import `zoky_home_screen.dart`/`pop_feed_screen.dart` ที่ไม่ได้ใช้ในนี้อีก — **ห้ามลบไฟล์ที่ import อยู่จริง เช่น `pop_feed_screen.dart`/`zoky_home_screen.dart` เอง** แค่เลิก reference จาก `RootShell`)

---

## Screen 2 — Home Feed (ขยายรับ Drop feed เดิมเข้ามา)

Purpose: Home เป็นจุดเดียวที่ browse content ทั้งหมด (Drop+Pop+Club+Trending) ตาม Master Spec Section 1 — ดูดซับ capability ของ Drop tab เดิม (WYN-019–022) เข้ามาโดยไม่สูญเสียอะไร

User Flow: เหมือนเดิมทุกประการ + มีโหมด feed เพิ่มขึ้น 1 โหมด ("Following")

Components — โครงสร้าง Home คงเดิมทั้งหมด (`_buildTopRow` → `ClubSection` → Trending row → feed-mode selector → feed body) เปลี่ยนแค่ **feed-mode selector**:

```
เดิม (SegmentedButton 3 ตัวเลือก): สำหรับคุณ | ล่าสุด | จาก Club ของคุณ
ใหม่ (SegmentedButton 4 ตัวเลือก): สำหรับคุณ | ติดตาม | ล่าสุด | จาก Club ของคุณ
                                              ^^^^^^ NEW — ดูดซับ DropFeedScreen's "Following" tab
```

- **"ติดตาม" (Following) โหมดใหม่**: มิกซ์ Drop+Pop จากคนที่ follow เท่านั้น (**ต่างจาก Drop tab เดิมที่ Following มีแค่ Drop** — ตอนนี้ผสาน Pop เข้าด้วยเพราะ Home คือ "ศูนย์รวม Content ทุกระบบ" ตาม Master Spec ไม่ใช่ Drop-only อีกต่อไป) ต้องการ method ใหม่ใน `HomeRepository` (เทียบเคียง `fetchRankedFeed`/`fetchFeed` เดิม) เช่น `fetchFollowingFeed(page)` — reuse `home_feed` view (WYN-007) เดิมเพิ่ม filter `WHERE author_id IN (SELECT following_id FROM follows WHERE follower_id = auth.uid())` (มิเรอร์ pattern ของ `DropRepository.fetchFollowingFeed` เดิมที่กำลังจะถูกดูดซับ ไม่ต้องคิดใหม่)
- Empty state ของ "ติดตาม" reuse ข้อความเดิมจาก Drop tab: "ยังไม่ได้ follow ใครเลย ลองดู สำหรับคุณ เพื่อค้นหาคนน่าสนใจ" (ปรับคำจาก "For You" เป็น "สำหรับคุณ" ให้ตรงชื่อโหมดภาษาไทยที่ใช้จริงใน UI)
- ลำดับตัวเลือกใน `SegmentedButton`: สำหรับคุณ (ค่าเริ่มต้น, ไม่เปลี่ยน) → **ติดตาม (ใหม่ วางถัดจาก "สำหรับคุณ" ตรงตาม Master Spec ที่เขียนคู่กันว่า "For You / Following")** → ล่าสุด → จาก Club ของคุณ (2 ตัวหลังคงตำแหน่งเดิม)
- "Latest" (ล่าสุด) ของ Home เดิมเป็น chronological ของ Drop+Pop ผสมอยู่แล้ว **ไม่ต้องเปลี่ยนอะไร** — เป็นตัวที่ดูดซับ DropFeedScreen's "Latest" tab ไปในตัวอยู่แล้วโดยธรรมชาติ (แค่ Drop-only → Drop+Pop ซึ่งกว้างกว่าเดิม ไม่ใช่แคบลง)
- ปุ่ม "+" (สร้าง Drop จาก `RootShell`, ดู Screen 1) ต้อง prepend Drop ที่สร้างใหม่เข้า `_items` ของ Home ทันทีถ้า mode ปัจจุบันเป็น "สำหรับคุณ"/"ติดตาม"/"ล่าสุด" (ไม่ใช่ "จาก Club ของคุณ" ซึ่งเป็น mode ที่ไม่เกี่ยวกับ Drop ส่วนตัว) — ให้ `HomeFeedScreen` เปิด public method (ผ่าน `GlobalKey<_HomeFeedScreenState>` หรือเทียบเท่า) ที่ `RootShell` เรียกได้หลัง `CreateDropScreen` ปิดสำเร็จ

Interactions: เหมือนเดิมทุกจุด (`_toggleLike`/`_toggleSave`/`_openDrop`/`_openPop`/`_openProfile` คงเดิม) + `_fetchPage` เพิ่มเงื่อนไข mode ใหม่ 1 กรณี

States: Empty/Error/Loading ของโหมด "ติดตาม" mirror pattern เดิมของ "สำหรับคุณ"/"ล่าสุด" ทุกประการ (ใช้ `_items`/`_page`/`_isLoadingInitial` ชุดเดียวกัน ไม่แยก state)

Responsive Behavior: `SegmentedButton` 4 ตัวเลือกบนจอแคบ (< 360px) ต้องตรวจ overflow — ถ้าคับให้ยุบ label เหลือไอคอน+tooltip แทนข้อความเต็ม (Coding ตัดสินใจ threshold จริงตอน implement ทดสอบกับจอเล็กสุดที่ต้อง support)

Accessibility: Semantics label ของแต่ละ segment คงข้อความเต็มเสมอแม้ label ที่แสดงจะย่อ (`Semantics(label: 'ติดตาม')` ไม่ใช่แค่ไอคอน)

Design Rules: ไม่มีสี/token ใหม่ ใช้ `SegmentedButton` เดิมของ Material 3 ตาม DS-001

Handoff: ส่ง AI Coding — ไฟล์หลักที่แก้: `app/lib/features/home/presentation/home_feed_screen.dart` (เพิ่ม `_HomeFeedMode.following`), `app/lib/features/home/data/home_repository.dart` (เพิ่ม `fetchFollowingFeed`) — **ลบ** `app/lib/features/drop/presentation/drop_feed_screen.dart` และ `_DropTabFeed` ในไฟล์เดียวกันได้ทันทีหลังยืนยันว่า capability ทั้งหมดย้ายเข้า Home ครบแล้ว (ไม่มี route ใดชี้ไปอีกหลัง WYN-024 เสร็จ — ต่างจาก Pop/ZOKY ที่ยังไม่ลบเพราะจะกลับมาใช้ในอนาคต Drop tab **จะไม่กลับมาเป็น tab แยกอีก** ตาม decision นี้ จึงลบได้จริง ไม่ใช่แค่ถอดจาก UI) `DropGridTile`/`ProfileDropGridTab` (WYN-013, ใช้ใน Profile's "Drops" tab) **ไม่เกี่ยวข้อง ไม่ถูกแตะ**

---

## Screen 3 — Search (ย้ายเข้า Bottom Nav)

Purpose: `SearchScreen` เดิม (WYN-009/WYN-015) กลายเป็น tab root แทนที่จะเป็นหน้าที่ถูก push จาก Home's search bar

Components: **reuse `SearchScreen` เดิม 100% ไม่แก้ UI ภายใน** — จุดเดียวที่ต้องแก้คือ `autofocus` ของช่องค้นหาด้านบน (ปัจจุบัน `autofocus: true` เพราะโหมดเดิมคือ "ผู้ใช้ตั้งใจกดค้นหา ต้องได้คีย์บอร์ดทันที") — เมื่อเป็น tab root **ต้องปิด autofocus เป็นค่าเริ่มต้น** (`autofocus: false`) เพราะ user อาจแค่แตะแท็บผ่านๆ ไม่ได้ตั้งใจพิมพ์ทันที คีย์บอร์ดผุดขึ้นเองทุกครั้งที่สลับแท็บจะน่ารำคาญ — เพิ่ม constructor parameter `autofocus` (default `false`) ให้ `SearchScreen` เรียกได้ทั้งสองแบบ

Handoff: ส่ง AI Coding — แก้ `app/lib/features/search/presentation/search_screen.dart` เพิ่ม parameter, แก้ `root_shell.dart` mount เป็น tab index 1

---

## Screen 4 — Notifications (ย้ายเข้า Bottom Nav)

Purpose: `NotificationListScreen` เดิม (WYN-012) กลายเป็น tab root แทนไอคอนกระดิ่งใน Home

Components: reuse เดิม 100% — **unread badge** ที่เคยอยู่ข้างไอคอนกระดิ่งใน Home's top row ย้ายไปแสดงบน `NavigationDestination` ของ Notifications tab แทน (Material 3's `Badge` widget ห่อ icon ได้ตรงๆ ไม่ต้องประดิษฐ์ใหม่ — ใช้ค่า `_unreadNotificationCount` เดิมที่ `HomeFeedScreen` เคย fetch คง logic การ mark-as-read-on-open เดิมทั้งหมด) — **ย้าย state การนับ unread ขึ้นไปที่ `RootShell`** แทนที่จะอยู่ใน `HomeFeedScreen` เพราะ badge ตอนนี้อยู่ที่ระดับ Bottom Nav ไม่ใช่ระดับ Home อีกต่อไป

Handoff: ส่ง AI Coding — ย้าย `_loadUnreadNotificationCount`/`_unreadNotificationCount` จาก `home_feed_screen.dart` ไป `root_shell.dart`, ลบ `_buildTopRow`/`_buildSearchBar`/`_buildNotificationButton` ออกจาก `HomeFeedScreen` ทั้งหมด (Home ไม่มี top row นี้อีกแล้ว เริ่มด้วย `ClubSection` เลย)

---

## Non-goals รอบนี้

- ไม่แตะ Pop/ZOKY โค้ด/schema เลย (แค่เลิก mount ใน `RootShell` ตาม WYN-024's R2/R3)
- ไม่ทำ Chat entry icon (ยังไม่มี Chat feature จนกว่าจะถึง Phase 2 — Master Spec เองก็บอกว่า Chat "เข้าผ่านไอคอนแยก" ซึ่งหมายถึงตอนที่ Chat มีอยู่จริง ไม่ใช่ตอนนี้)
- ไม่แตะสี/DS token ใดๆ (รอ DS-009)
- ไม่ทำ WYNOS rename ของ asset/splash screen/app display name (เป็นงาน Coding แยกเมื่อแตะ native config — ไม่บังคับอยู่ใน scope ของ nav restructure นี้)
