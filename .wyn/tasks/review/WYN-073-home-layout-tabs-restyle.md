# Design Task — WYN-073

Status: review
Owner: AI Coding (implemented) → ส่งต่อ AI QA & Security
Screen: Home
Purpose: 1) จัดลำดับ component ของ Home ใหม่ให้ตรง mockup (Header → Banner → Tabs → New-posts pill → Feed) 2) เอา ClubSection + Trending section ออกจาก Home (ยังเข้าถึงได้ผ่านแท็บค้นหา ไม่เสีย feature) 3) เปลี่ยนสไตล์แท็บ feed-mode จาก SegmentedButton มีกรอบ → text tabs เปล่า + เส้น underline indicator (สี rainbow ตาม DS-009 เดิม ไม่เปลี่ยนเป็น sapphire) — Header (ไอคอนแชท) ไม่เปลี่ยนแปลง ยืนยันกับ Founder แล้วว่าเก็บไว้ตามเดิม
User Flow / Components / Interactions / States: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-073-home-layout-tabs-restyle.md`
Responsive Behavior: ต้องกัน overflow ที่ 360px width เหมือนเกณฑ์เดิมของ WYN-024
Accessibility: touch target แท็บ ≥44x44, Semantics label เดิมคงไว้
Design Rules: ไม่แตะสี/token อื่นนอกจากที่ระบุ, ห้ามลบไฟล์ widget ที่ยังมี declare อยู่ (ClubSection/TrendingTile) แค่เลิก reference จาก Home

## Implementation (AI Coding, 2026-09-01)

แก้ `home_feed_screen.dart`:
- ลบ `ClubSection`/`_buildTrendingSection()` sliver ออกจาก `build()`, ลบ `_trendingFuture` field + `initState` assignment, ลบ `_buildTrendingSection()` method ทั้งหมด, ลบ import `club_section.dart`/`trending_tile.dart` ที่ไม่ใช้แล้ว (ไม่ได้ลบไฟล์ widget เอง ยังอยู่ครบตาม Design Rules)
- เขียน `_buildFeedModeToggle()`/`_buildFeedModeTab()` ใหม่ทั้งหมด: จาก `SegmentedButton` → `Row` ของ `Semantics`+`InkWell`+`Text` เปล่า พร้อมเส้น underline (`WynColors.rainbowAccent` เดิมตาม DS-009) ใต้ label โดยตรง (ไม่ใช่แท่งสั้นกลางปุ่มแบบเดิม) ยังคง `SingleChildScrollView` แนวนอนกัน overflow เหมือนเดิม (ไม่ต้องใช้ `IntrinsicWidth` ระดับแถวอีกต่อไปเพราะไม่มี equal-width constraint ของ SegmentedButton ให้ workaround)

**บั๊กที่เจอระหว่างทำและแก้แล้ว**: ค่า `_feedModeToggleHeight` เดาไว้ 51 ตอนแรก ทำให้ `flutter test` ทั้งไฟล์ timeout/exception spam มหาศาล (SliverGeometry ไม่ valid: layoutExtent 51 > paintExtent 50) — วัดจริงผ่าน test แล้วแก้เป็น 50

**ลบ test ที่ล้าสมัย**: `home_feed_screen_test.dart`'s "Trending row (WYN-017)" และ "Recommended Clubs row (WYN-017)" groups (6 tests) ลบทิ้งเพราะ feature ที่ทดสอบไม่มีอยู่ใน Home แล้วตามที่ตั้งใจ (TrendingTile/ClubSection ยังมี test ของตัวเองแยกต่างหาก) พร้อมลบ unused imports/fixtures/helper ที่ค้างจากการลบนี้

Tests: `flutter analyze` 0 issues, `flutter test` เต็ม suite **871/871 ผ่านหมด** ไม่มี regression

Handoff: ส่งต่อ AI QA & Security (`/qa`) — เน้นตรวจ: (1) ลำดับ component ใหม่ตรงตาม mockup จริง (2) แท็บใหม่ไม่มีกรอบ มีเส้นใต้สี rainbow ใต้ label ที่ active (3) ทดสอบ overflow ที่จอแคบ 360px ซ้ำ (เกณฑ์เดียวกับ WYN-024 เดิม) (4) Club/Trending section หายจาก Home จริง แต่ยังกดเข้าถึงได้ผ่านแท็บค้นหา
