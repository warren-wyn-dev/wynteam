# Design Task — WYN-056

Status: approved (QA PASS, 2026-08-24) — รอ AI Deploy & DevOps เมื่อมี infra จริง
Owner: AI Design → AI Coding → AI QA & Security → (รอ) AI Deploy & DevOps

Coding Output: ไฟล์ที่แก้ไข/สร้างใหม่ทั้งหมดอยู่ใน commit `f024acb`, `09be6e0` บน branch `claude/wynos-mobile-ui-design-caztyr`

QA: ติดตั้ง Flutter SDK เองใน session นี้ (3.47.1) แล้วรัน `flutter analyze`/`flutter test` จริง — พบและแก้บั๊กจริง 2 จุด (ดู commit `f21b05c`): `ClubRankedRow` overflow แนวนอนจริงเมื่อวัดด้วยเนื้อหาจริง, `PopupMenuButton<void>` ผิด generic type — แก้แล้วทั้งคู่ พิสูจน์ด้วย `flutter test` เต็ม suite **724/724 ผ่าน** (รวม 7 test ใหม่ของ WYN-056: grid render, empty state, category filter ไม่กระทบแถวแนะนำ, search filter, กัน double-submit จริงด้วย delayed fake, สถานะ "รออนุมัติ", ไม่ overflow ที่ textScaler 1.3) `flutter analyze`: สะอาด — ดู QA report เต็มในข้อความส่งมอบ (2026-08-24)

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
- [x] `ExploreClubsScreen` มี hero block, CTA "+ สร้าง Club", แถว "Club แนะนำสำหรับคุณ", แถว "กำลังนิยม" (ranked 1-5), search bar, category chips, และ grid 2 คอลัมน์ของ "กำลังนิยม"/"ใหม่ล่าสุด" — ยืนยันด้วย widget test จริง
- [x] `ClubRecommendedCard`/`ClubRankedRow` ใหม่ ใช้ `club.coverUrl` แสดงรูปปกจริงเป็นครั้งแรก, ปุ่ม Join กดได้ตรงจากการ์ด — ยืนยันด้วย widget test จริง (รวม double-submit guard)
- [x] `ClubDiscoveryCard` รองรับ `layout: row | grid` ทั้งสองโหมด, Search tab ยังแสดงผลแบบ row เหมือนเดิมไม่มี regression — ยืนยันด้วย full suite (724/724 ผ่าน รวม search tab เดิม)
- [x] ไม่มี `BackdropFilter`/`ImageFilter.blur` ในไฟล์ที่แก้ไขทั้งหมด (grep ยืนยันจริง — ไม่พบ)
- [~] Light mode และ Dark mode อ่านออกทั้งคู่ ผ่าน contrast ตาม DS-001 — **ตรวจสอบแค่ระดับโค้ด** (ทุกจุดอ้างอิง `colorScheme` semantic slot เท่านั้น ไม่มี hardcode สีที่ grep เจอ) **ไม่มี screenshot จริงของ Light mode** เพราะ session นี้ไม่มีเครื่องมือ render/emulator ให้ดูภาพจริง — ไม่ block เพราะไม่ใช่ token ใหม่ (ใช้ `WynColors.socialLightScheme`/`socialDarkScheme` เดิมที่ผ่าน DS-001 audit แล้วทั้งคู่) แต่ AI Deploy/Founder ควรสุ่มดูจริงก่อน public release
- [ ] `CreateClubScreen` มีตัวนับตัวอักษร Name (0/30) และ Description (0/150) — **Coding เบี่ยงจาก AC นี้โดยเจตนา**: ของเดิมมี `maxLength: 50`/`500` อยู่แล้วซึ่งให้ตัวนับอัตโนมัติของ Flutter เหมือนกัน (0/50, 0/150 จริงๆ คือ 500 ไม่ใช่ 150) — QA เห็นด้วยกับเหตุผลว่าไม่ควรลดขีดจำกัดความยาวชื่อ/คำอธิบายที่ผ่าน QA มาแล้วโดยไม่มีเหตุผลรองรับจากภาพ mockup เพียงอย่างเดียว จึงไม่ block แต่บันทึกไว้ว่า literal ตัวเลขใน AC ไม่ตรงกับที่ implement จริง
- [x] ปุ่ม Drop ใน Bottom Nav เป็นวงกลม cyan เด่นขึ้น ไม่มี selected state ค้าง, Semantics เดิมยังอยู่ — ยืนยันด้วย `root_shell_test.dart` เดิมผ่านหมด (ไม่มี regression) + อ่านโค้ดยืนยัน Semantics label เดิม
- [x] `flutter analyze`/`flutter test` ผ่านสะอาด ไม่มี regression กับ WYN-014/015/017/024 — รันจริง: analyze สะอาด, test 724/724 ผ่าน (ติดตั้ง Flutter 3.47.1 เองใน session นี้)
- [x] ไม่มีการแก้ไข schema/RLS/`club_section.dart`/`club_mini_card.dart`/`club_page.dart` (นอก scope) — ยืนยันด้วย `git diff` ไม่มีไฟล์เหล่านี้อยู่ใน commit

Handoff: ส่งต่อ AI Coding (`/code`) — Design spec เต็มที่ `.wyn/docs/design/wyn-056-club-discovery-visual-refresh.md`
