# Design Spec — WYN-073: Home Layout Reorder + Tabs Restyle

Owner: AI Design → AI Coding
อ้างอิง: Founder ส่งภาพ `design-reference/01-home.tsx` วงสีแดงชี้ตำแหน่ง "มีโพสต์ใหม่" พร้อม requirement 4 ข้อ, `design-reference/SPEC.md` Section 4.3-4.4, `.wyn/docs/design/ds-009-rainbow-accent.md` (APPROVED, ไม่ถูกแทนที่), `.wyn/docs/design/wyn-014-club-core.md`, `.wyn/docs/design/wyn-017-home-trending-recommended-clubs.md`

## Audit ก่อนออกแบบ — ยืนยันความปลอดภัยของแต่ละจุดที่ Founder ขอ

Founder ถามยืนยันจุด Header (ไอคอนแชท vs search) แล้ว — **ตัดสินใจ: เก็บไอคอนแชทไว้ ไม่เพิ่ม search** (แชทไม่มีทางเข้าอื่นในแอปเลยนอกจากไอคอนนี้จุดเดียว ยืนยันจาก grep `ChatInboxScreen(` ทั้ง codebase) — **Header ไม่มีการเปลี่ยนแปลงในรอบนี้**

ตรวจแล้วว่าการเอา ClubSection + Trending section ออกจาก Home **ปลอดภัย ไม่เสีย feature**: ทั้งสองอย่างเข้าถึงได้จากแท็บ "ค้นหา" อยู่แล้ว (`search_club_results_tab.dart` มี Club discovery + join, `ExploreClubsScreen`/`CreateClubScreen` ต่อจากตรงนั้น, `discovery_view.dart` มี Top100Screen สำหรับ trending) — ไม่ใช่การลบ feature ทิ้ง แค่ลบทางเข้าที่ซ้ำซ้อนออกจาก Home

## การตัดสินใจสี accent ของแท็บ (สำคัญ — ไม่ทำตาม reference เป๊ะทุกจุด)

Reference (`01-home.tsx`) ใช้เส้นใต้สี sapphire ล้วน แต่ DS-009 (Founder-approved 2026-08-22, ยังไม่ถูกยกเลิก) กำหนดไว้ชัดเจนว่า **rainbow accent ใช้กับ "Active feed-mode indicator" ของหน้านี้โดยเฉพาะ** — งานนี้เปลี่ยนแค่ตัวแท็บ (จาก `SegmentedButton` มีกรอบ → text tabs เปล่า) ไม่แตะสีของ indicator ที่อนุมัติไว้แล้ว **เส้น indicator ยังใช้ `WynColors.rainbowAccent` เหมือนเดิม** เปลี่ยนแค่ตำแหน่ง/ความกว้างให้เข้ากับ text tab แบบใหม่ (เต็มความกว้าง label แทนที่จะเป็นแท่งสั้น 24px กลางปุ่ม — อ่านคำว่า "Underline Indicator" ตามที่ Founder ขอ)

## Screen: Home — ลำดับ Component ใหม่

Purpose: จัดลำดับให้ตรงกับ mockup, ตัด section ที่ซ้ำซ้อนกับ "ค้นหา" ออก

User Flow: ไม่เปลี่ยน (เข้าแอป → Home → เลื่อนดู feed) การนำทางไป Club/Trending ย้ายไปเริ่มจากแท็บ "ค้นหา" แทน

Components — ลำดับใหม่จากบนลงล่าง:
1. Header (คงเดิมทุกอย่าง — wordmark กลาง, ปุ่มแชทขวา, ไม่มี hamburger)
2. `HomeExplainerBanner` (คงเดิม)
3. Feed-mode tabs แบบใหม่ (ดูสเปคด้านล่าง) — **ปักหมุด (pinned)** เหมือนเดิม
4. `NewPostsPill` (ถ้ามี) — อยู่ใต้แท็บ ในบล็อก pinned เดียวกัน คงเดิมทุกอย่าง
5. Feed body (`_buildBodySlivers()` / `FromYourClubsFeed`) — คงเดิมทุกอย่าง

**ลบออกทั้งหมด**: `ClubSection` widget และ `_buildTrendingSection()` (การ์ด "กำลังนิยม" + ข้อความ empty state "ยังไม่มี content กำลังนิยม") — ลบทั้ง `SliverToBoxAdapter` 2 อันนี้ออกจาก `CustomScrollView`'s `slivers` list ไม่ต้องเก็บไว้เป็น comment/dead code

Interactions: ไม่เปลี่ยนจากเดิม (การ์ด/ปุ่มใน feed ทำงานเหมือนเดิมทุกจุด)

States: ไม่มี state ใหม่ — การลบ Club/Trending section ไม่กระทบ state ของ feed mode/pagination เดิมเลย

Responsive Behavior: ไม่เปลี่ยน — การลบ 2 section ทำให้เนื้อหา feed จริงขึ้นมาสูงกว่าเดิมบนจอทุกขนาด (ผลดี ไม่ใช่ปัญหา)

Accessibility: ไม่เปลี่ยน — element ที่ลบไม่มี screen-reader path พิเศษที่ต้องย้ายไปไหน (Club/Trending ใน Search ก็มี Semantics ของตัวเองอยู่แล้ว)

Design Rules: ห้ามลบไฟล์ `club_section.dart`/`trending_tile.dart`/`ClubSection`/`TrendingTile` widget class ทิ้ง (ยังใช้ที่อื่น หรือเผื่ออนาคต) — แค่เลิก reference จาก `home_feed_screen.dart` เท่านั้น เหมือน pattern ที่ WYN-024 ทำกับ `zoky_home_screen.dart` ("ห้ามลบไฟล์ที่ import อยู่จริง แค่เลิก reference")

---

## Component: Feed-mode Tabs (restyle)

Purpose: แทนที่ `SegmentedButton` (ดูเป็นกรอบ/ปุ่มเต็ม) ด้วย text tabs แบบเรียบ

Components:
- แถวแท็บ: `Row` ของ 4 `InkWell`/`GestureDetector` แต่ละอันมี `Text` label เปล่า ไม่มีพื้นหลัง/กรอบ/มุมโค้งใดๆ ห่อด้วย `SingleChildScrollView(scrollDirection: horizontal)` เหมือนเดิม (กัน overflow บนจอแคบตอน "จาก Club ของคุณ" active) — ไม่ต้องใช้ `IntrinsicWidth` อีกต่อไปเพราะไม่มี equal-width constraint ของ `SegmentedButton` ให้ต้อง workaround แล้ว (`Row` ปกติจัดความกว้างตาม content เอง)
- ระยะห่างระหว่างแท็บ: `WynSpacing.space6` (24px, ตรงกับ SPEC.md 4.3 `mr-6`)
- Padding แนวตั้งของแต่ละแท็บ: `WynSpacing.space3` (12px บน-ล่าง, ตรงกับ `py-3`)
- Active tab: `Theme.of(context).textTheme` weight 600 (เทียบเท่า `titleSmall`/`bodyMedium` ที่มี fontWeight 600 อยู่แล้วในธีม), สี `colorScheme.onSurface` (ink)
- Inactive tab: weight ปกติ (400), สี `colorScheme.onSurfaceVariant` (graphite — เข้ากับ theme, ต่างจาก reference ที่ hardcode `faint` เพราะแอปนี้ใช้ semantic token ตาม dark-mode convention เดิมเสมอ)
- Indicator เส้นใต้: `Container` สูง 2px, `WynColors.rainbowAccent` gradient (ของเดิมจาก DS-009), **ความกว้างเท่ากับความกว้างจริงของ label นั้น** (ไม่ใช่ 24px คงที่แบบเดิม) วางชิดใต้ label พอดี (แทนที่จะเป็นแท่งลอยกลางปุ่มแบบเดิม) — ทำได้โดยห่อแต่ละแท็บ (label+indicator) เป็น `Column` เดียวกัน แทนที่จะแยก Row ของ indicator ออกมาต่างหากเหมือนโค้ดเดิม
- Bottom border ของทั้งแถว: `1px solid colorScheme.outlineVariant` (hairline) ตรงกับ SPEC.md 4.3

Interactions: แตะแท็บใดก็ตาม → `setState(_feedMode = ...)` เหมือนเดิมทุกประการ (logic ไม่เปลี่ยน เปลี่ยนแค่ widget tree ของตัว UI)

States: active/inactive ตามเดิม ไม่มี state ใหม่

Responsive Behavior: `SingleChildScrollView` แนวนอนกัน overflow เหมือนโค้ดเดิม — เกณฑ์เดียวกับที่ WYN-024 QA round 2-4 เคยแก้ (ไม่ยุบ 1 บรรทัดเป็นหลายบรรทัด, ไม่ truncate label) ต้องทดสอบซ้ำที่ 360px width เหมือนที่ QA รอบก่อนเคยทำ

Accessibility: touch target แต่ละแท็บต้องยังคงอย่างน้อย 44x44 (padding แนวตั้ง 12px + text height เพียงพออยู่แล้วจากการวัดของเดิม แต่ AI Coding ต้องยืนยันด้วย widget test เหมือนที่ QA เคยเจอปัญหานี้มาก่อน) — Semantics label เดิม (ชื่อโหมด + สถานะ selected) ต้องคงไว้

Design Rules: ห้ามใช้ `SegmentedButton` อีกต่อไปสำหรับ component นี้ — เปลี่ยนเป็น custom Row+InkWell ตามสเปคข้างบน ห้ามเปลี่ยนสี indicator จาก rainbow เป็น sapphire (DS-009 ยังมีผลอยู่ ไม่ใช่ direction ใหม่ที่ AI Design เลือกเอง)

Handoff: AI Coding — แก้ไฟล์เดียว `home_feed_screen.dart`: (1) ลบ `ClubSection`/`_buildTrendingSection()` ออกจาก `slivers` list, ลบ import 2 ตัวที่ไม่ใช้แล้ว (2) เขียน `_buildFeedModeToggle()` ใหม่ตามสเปคแท็บข้างบน แทนที่ implementation เดิมทั้งหมด (3) อัปเดต `_feedModeToggleHeight` const ให้ตรงกับความสูงจริงของ layout ใหม่ (วัดจริงผ่าน widget test เหมือนที่ comment เดิมอธิบายไว้ ห้ามเดา) — ต้องรัน `flutter test` เต็ม suite รวม `root_shell_test.dart`/`home_feed_screen_test.dart` ที่จะได้รับผลกระทบโดยตรงจากการเปลี่ยนนี้ QA ต้องตรวจเรื่อง overflow ที่ 360px ซ้ำ (เกณฑ์เดียวกับ WYN-024)
