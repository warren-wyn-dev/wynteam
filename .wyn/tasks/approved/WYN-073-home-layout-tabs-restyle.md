# Design Task — WYN-073

Status: approved (QA PASS, 2026-09-01) — พร้อม Deploy
Owner: AI QA & Security (approved) → ส่งต่อ AI Deploy & DevOps
Screen: Home
Purpose: 1) จัดลำดับ component ของ Home ใหม่ให้ตรง mockup (Header → Banner → Tabs → New-posts pill → Feed) 2) เอา ClubSection + Trending section ออกจาก Home (ยังเข้าถึงได้ผ่านแท็บค้นหา ไม่เสีย feature) 3) เปลี่ยนสไตล์แท็บ feed-mode จาก SegmentedButton มีกรอบ → text tabs เปล่า + เส้น underline indicator (สี rainbow ตาม DS-009 เดิม ไม่เปลี่ยนเป็น sapphire) — Header (ไอคอนแชท) ไม่เปลี่ยนแปลง
User Flow / Components / Interactions / States: ดูรายละเอียดเต็มใน `.wyn/docs/design/wyn-073-home-layout-tabs-restyle.md`

## Implementation (AI Coding, 2026-09-01)
ดูรายละเอียดที่ commit history — สรุป: ลบ ClubSection/Trending sliver ออกจาก Home, เขียนแท็บใหม่เป็น text+underline (rainbow), แก้บั๊ก height ที่เดาผิด 1px เอง, ลบ test ล้าสมัย 6 ตัว

## QA (2026-09-01) — PASS

ตรวจซ้ำอิสระทั้งหมด ไม่เชื่อตัวเลขที่ Coding รายงานเฉยๆ:
- `flutter analyze`: 0 issues (รันเอง)
- `flutter test` เต็ม suite: **871/871 ผ่านหมด** (รันเอง คนละรอบจาก Coding)
- **ลำดับ component**: ตรวจโค้ด `build()` ตรงจริง — Header → HomeExplainerBanner → pinned(Tabs+NewPostsPill) → Feed, ไม่มี ClubSection/Trending sliver เหลืออยู่
- **แท็บใหม่**: grep ยืนยันไม่มี `SegmentedButton(` instantiation จริงในโค้ด (เหลือแค่ comment ประวัติ), มี `WynColors.rainbowAccent` เป็นสี indicator ตาม DS-009 เดิม
- **Overflow ที่จอแคบ**: test suite มี regression test ชุดเดิมจาก WYN-024 ครอบคลุมอยู่แล้ว (360/375/390/414/430px ทุก label ต้อง legible ไม่ wrap/truncate) — ทั้งหมดผ่านกับโค้ดใหม่จริง ไม่ใช่แค่ trivially pass
- **Club/Trending ยังเข้าถึงได้**: ยืนยันโค้ด `discovery_view.dart`/`search_club_results_tab.dart` (แท็บค้นหา) ยังมี `Top100Screen`/`ClubDiscoveryCard`/`ExploreClubsScreen`/`CreateClubScreen` ครบ ไม่ถูกแตะเลยในรอบนี้ (แยกไฟล์กับที่ Coding แก้)
- **Widget files ไม่ถูกลบ**: `club_section.dart`/`trending_tile.dart` ยังอยู่ในโปรเจกต์ตาม Design Rules

**Final Status: PASS**

Handoff: ส่งต่อ AI Deploy & DevOps (`/deploy`) — deploy ได้เมื่อ Founder พร้อม (ต้องขอยืนยันก่อนเริ่ม deploy จริงตามกติกาการเปลี่ยนแปลงที่กระทบ production) — ไม่มี schema change ในรอบนี้ (ตรวจแล้ว ไม่แตะ `supabase/schema.sql` เลย) จึงไม่มีความเสี่ยง schema-drift แบบ WYN-072
