# Design Task — WYN-056

Status: review (Coding เสร็จแล้ว รอ AI QA & Security)
Owner: AI Design → AI Coding → AI QA & Security

Coding Output: ดูสรุปเต็มในข้อความส่งมอบของ AI Coding (2026-08-24) — ไฟล์ที่แก้ไข/สร้างใหม่ทั้งหมดอยู่ใน commit `f024acb` บน branch `claude/wynos-mobile-ui-design-caztyr` — **flutter analyze/flutter test ยังไม่ได้รันจริง เพราะ session นี้ไม่มี Flutter SDK ติดตั้งอยู่** (ตรวจสอบด้วยการนับ parens/braces balance ในทุกไฟล์ที่แก้ไข/สร้างใหม่แทน) — AI QA & Security ต้องรัน `flutter analyze`/`flutter test` จริงเป็นด่านแรกก่อนตรวจข้ออื่น

Screen: `ExploreClubsScreen` redesign + widget ใหม่ (`ClubRecommendedCard`, `ClubRankedRow`) + ปรับ `ClubDiscoveryCard`/`CreateClubScreen`/ปุ่ม Drop ของ Bottom Nav

Purpose: Founder ส่งภาพ mockup "WYNOS" high-fidelity Club UI concept เต็มรูปแบบ (2026-08-24) ขอยกระดับความสวยงาม/ความหนาแน่นของภาพในหน้า Discovery ของ Club ให้ตรงกับ WYNOS identity มากขึ้น — เป็นงาน visual-refresh บน Club system ที่มีอยู่แล้ว (WYN-014/015/017 ผ่าน QA แล้ว) ไม่ใช่ฟีเจอร์ใหม่ ไม่แตะ schema/permission/RLS

User Flow: ดูรายละเอียดเต็มที่ Design spec

Components: ดู `.wyn/docs/design/wyn-056-club-discovery-visual-refresh.md` (Screen 1-6 ครบ: Explore redesign, ClubRecommendedCard, ClubRankedRow, Discovery grid tile, Create Club ผิว, Drop button ผิว)

Interactions: เหมือนเดิมทุกจุดจาก WYN-014/015 (Join/Leave/tap-to-ClubPage/filter category) — จุดใหม่เดียวคือกด Join ได้ตรงจากการ์ดในหน้า Explore โดยไม่ต้องเปิด ClubPage ก่อน (reuse `ClubRepository` method เดิม ไม่มี logic ใหม่)

States: Loading/Empty/Error mirror pattern เดิมของ WYN-015/017 ทุกจุด (ดู Design spec)

Responsive Behavior: Grid 2 คอลัมน์ต้องไม่ overflow ที่ textScale 130% ตาม DS-008

Accessibility: Semantics label รูปแบบเดิม ("ชื่อ Club, หมวดหมู่, จำนวนสมาชิก คน") ทุกการ์ด/แถวใหม่

Design Rules:
- ห้าม Liquid Glass (ห้าม `BackdropFilter`/blur/translucent surface ใดๆ) — glow ทำด้วย `BoxShadow` สีเรืองแสงทึบเท่านั้น
- ห้ามเพิ่ม Rainbow accent จุดที่ 3 (DS-009 จำกัดไว้แค่ 2 จุด) — ใช้ไอคอน `trending_up` สี cyan แทนสำหรับ Club ranked row
- สีทุกจุดอ้างอิง `colorScheme` เท่านั้น ห้าม hardcode (ให้ Light mode ถูกต้องอัตโนมัติ, DS-001 ยืนยัน Light/Dark ต้อง first-class เท่ากัน)
- ไม่แตะ Home's `ClubSection`/`ClubMiniCard` (ผ่าน QA แล้วใน WYN-017) — เนื้อหา hero/แนะนำ/กำลังนิยมทั้งหมดของภาพ Founder ย้ายไปอยู่ที่ `ExploreClubsScreen` แทน
- Search tab ของ WYN-015 (Club tab ใน `SearchScreen`) ยังใช้ `ClubDiscoveryCard` layout แถวเดิม ไม่เปลี่ยนเป็น grid

Acceptance Criteria:
- [ ] `ExploreClubsScreen` มี hero block, CTA "+ สร้าง Club", แถว "Club แนะนำสำหรับคุณ", แถว "กำลังนิยม" (ranked 1-5), search bar, category chips, และ grid 2 คอลัมน์ของ "กำลังนิยม"/"ใหม่ล่าสุด"
- [ ] `ClubRecommendedCard`/`ClubRankedRow` ใหม่ ใช้ `club.coverUrl` แสดงรูปปกจริงเป็นครั้งแรก, ปุ่ม Join กดได้ตรงจากการ์ด
- [ ] `ClubDiscoveryCard` รองรับ `layout: row | grid` ทั้งสองโหมด, Search tab ยังแสดงผลแบบ row เหมือนเดิมไม่มี regression
- [ ] ไม่มี `BackdropFilter`/`ImageFilter.blur` ในไฟล์ที่แก้ไขทั้งหมด (grep ยืนยัน)
- [ ] Light mode และ Dark mode อ่านออกทั้งคู่ ผ่าน contrast ตาม DS-001 (ไม่มีสี hardcode ผิดฝั่ง)
- [ ] `CreateClubScreen` มีตัวนับตัวอักษร Name (0/30) และ Description (0/150) โดยไม่เปลี่ยน validation เดิม
- [ ] ปุ่ม Drop ใน Bottom Nav เป็นวงกลม cyan เด่นขึ้น ไม่มี selected state ค้าง, Semantics เดิมยังอยู่
- [ ] `flutter analyze`/`flutter test` ผ่านสะอาด ไม่มี regression กับ WYN-014/015/017/024
- [ ] ไม่มีการแก้ไข schema/RLS/`club_section.dart`/`club_mini_card.dart`/`club_page.dart` (นอก scope)

Handoff: ส่งต่อ AI Coding (`/code`) — Design spec เต็มที่ `.wyn/docs/design/wyn-056-club-discovery-visual-refresh.md`
