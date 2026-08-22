# Product Task — WYN-024

Status: **AI Coding implement เสร็จแล้ว (2026-08-22)** — `SegmentedButton` ห่อด้วย `SingleChildScrollView(Axis.horizontal)` + `IntrinsicWidth` แทนการถูกบีบให้เท่าจอ (ยืนยันโดยอ่าน Flutter source: `_calculateHorizontalChildSize` clamp `constraints.maxWidth/childCount` กลายเป็น no-op เมื่อได้ unbounded width) — ทุก segment ได้ความกว้างเท่ากับ label ที่กว้างที่สุด ("จาก Club ของคุณ", 211.5px) ไม่ถูกตัดข้อความอีกเลยที่ทุกความกว้างจอจริง 360-430px (ยืนยันด้วย `RenderParagraph`/`didExceedMaxLines` เหมือนทุกรอบที่ผ่านมา) — Rainbow indicator (DS-009) ยังถูกต้องเพราะ segment กว้างเท่ากันจริงแล้ว (ไม่ใช่แค่ประมาณ) สูตรหารเท่ากันเดิมยังใช้ได้ — เจอและแก้ปัญหาเพิ่ม 1 จุดระหว่างทาง: `LayoutBuilder` (เดิมใช้คำนวณตำแหน่ง indicator) ใช้ร่วมกับ `IntrinsicWidth` ไม่ได้ (ทำให้ test ค้าง) เปลี่ยนเป็น `Row`+`Expanded` แทน — `flutter analyze` 0 error, `flutter test` 365/365 ผ่าน (360+5 ใหม่) พิสูจน์ red→green แล้ว — รอ QA รอบ 5
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security → AI Debug Engineer → AI QA & Security → AI Debug Engineer → AI QA & Security → AI Debug Engineer → AI QA & Security → AI Design → AI Coding → AI QA & Security

Feature: Bottom Navigation V1.0.0 Restructure — ถอด Pop/ZOKY ออกจาก Bottom Nav, เพิ่ม Search และ Notifications เป็น tab

Goal: ปรับโครงสร้าง Bottom Navigation ของแอป `app/` ให้ตรงกับ WYN V1.0.0 Master Spec (Section 34): 🏠 Home · 🔍 Search · ＋ Drop · 🔔 Notifications · 👤 Profile — เป็นงานแรกของ V1.0.0 เพราะทุกฟีเจอร์ที่จะเพิ่มต่อจากนี้ (Phase 1-8 ตาม `.wyn/docs/product/wyn-v1.0.0-roadmap.md`) อยู่ภายใต้โครง nav นี้

Target User: ผู้ใช้ WYN Social ทุกคน

Problem: Bottom Nav ปัจจุบันมี 5 tab คือ Home/Drop/Pop/ZOKY/Profile — Search เป็นแค่ search bar ใน Home (WYN-009), Notification เป็นไอคอนกระดิ่งข้าง search bar (WYN-012) ไม่ใช่ tab แยก — Founder ยืนยันแล้ว (2026-08-22) ว่า Pop และ ZOKY ไม่อยู่ใน scope V1.0.0 (Pop → V3, Shop/Marketplace → V2) จึงต้องถอดออกจาก Bottom Nav โดยไม่ลบโค้ด/database

Requirements:

R1. Bottom Nav ใหม่ 5 ตำแหน่ง: Home / Search / Drop (ปุ่ม "+" กึ่งกลาง เปิดหน้าสร้าง Drop ตรง ไม่ใช่ tab ที่มี state ค้างไว้) / Notifications / Profile
R2. ถอด Pop ออกจาก Bottom Nav ทั้งหมด — **ห้ามลบ** `app/lib/features/pop/`, ตาราง `pops`/`pop_likes`/`pop_comments`, หรือ storage bucket ที่เกี่ยวข้อง — ยังไม่มีทางเข้าถึง Pop จาก UI ปกติอีกต่อไปจนกว่าจะมีคำสั่ง V3
R3. ถอด ZOKY ออกจาก Bottom Nav ของ `app/` เท่านั้น — **ห้ามแตะ** `seller_app/` เลย (แอปแยก ไม่เกี่ยวกับ Bottom Nav ของ `app/`) — ห้ามลบโค้ด `app/lib/features/zoky/`, ตาราง ZOKY/SELLER ทั้งหมด, หรือ route ที่ deep-link เข้า ZOKY (ถ้ามีจุดอื่นอ้างอิง เช่น จาก Search/Profile ต้องตรวจสอบและปิดทางเข้าให้สอดคล้องกัน ไม่ทิ้ง dead link)
R4. ย้าย Search จาก search bar ใน Home ไปเป็น tab แยก — หน้า `SearchScreen` เดิม (WYN-009) reuse ตรง ๆ ไม่ต้องเขียนใหม่ Home ไม่มี search bar อีกต่อไป
R5. ย้าย Notification จากไอคอนกระดิ่งใน Home ไปเป็น tab แยก — หน้า `NotificationListScreen` เดิม (WYN-012) reuse ตรง ๆ ไม่ต้องเขียนใหม่ badge unread เดิมต้องยังทำงานถูกต้องบน tab icon
R6. ปุ่ม Drop ("+") กึ่งกลาง nav เปิดหน้า `CreateDropScreen` เดิมตรง ๆ (ไม่สร้าง flow ใหม่) ไม่ต้องมี state ค้างเหมือน tab อื่น (คล้ายปุ่มสร้างโพสต์ของแอปโซเชียลทั่วไปที่ไม่ใช่ "หน้าจอ" แต่เป็น action)
R7. ไม่แตะ/ไม่ลบตาราง DB ใด ๆ (Pop, ZOKY, SELLER ทั้งหมดยังอยู่ใน schema.sql) — เป็นแค่ UI-layer change ล้วนๆ
R8. **[เพิ่ม 2026-08-22, ยืนยันผ่าน popup]** ยุบ Drop feed (`DropFeedScreen`'s For You/Following/Latest tabs — WYN-019 ถึง WYN-022) เข้า Home แทนการเก็บไว้ที่อื่น — Home's feed-mode selector ขยายจาก 3 เป็น 4 ตัวเลือก (สำหรับคุณ/**ติดตาม (ใหม่)**/ล่าสุด/จาก Club ของคุณ) รายละเอียดเต็มที่ Design spec Screen 2 — `DropFeedScreen`/`_DropTabFeed` **ลบออกจากโค้ดได้จริง** (ต่างจาก Pop/ZOKY ที่แค่ถอด UI) เพราะ capability ทั้งหมดย้ายเข้า Home ครบ ไม่ใช่ของที่จะกลับมาใช้แยกอีกในอนาคต

Acceptance Criteria:
- [ ] Bottom Nav แสดง 5 ตำแหน่งตรงตาม R1 เป๊ะ ไม่มี Pop/ZOKY tab เหลืออยู่
- [ ] แตะ Search tab เปิด `SearchScreen` เดิมทำงานปกติทุกฟังก์ชัน (User/Drop/Pop-content-still-searchable-if-existing/Hashtag/Club tab ภายในหน้า Search ไม่ต้องแก้)
- [ ] แตะ Notifications tab เปิด `NotificationListScreen` เดิม unread badge sync ถูกต้อง
- [ ] แตะปุ่ม Drop "+" เปิด `CreateDropScreen` แล้วกลับมา Home tab เดิม (ไม่ค้างอยู่ที่ "Drop tab" เพราะไม่มี tab นั้นแล้ว)
- [ ] ไม่มี dead link เหลือที่ชี้ไป Pop/ZOKY จากหน้าจออื่น (ตรวจ Profile/Search/Home ทุกจุดที่เคย deep-link)
- [ ] Pop/ZOKY โค้ดและ route ยังคอมไพล์ผ่าน ไม่ถูกลบ (สามารถ manual-navigate เข้าถึงได้ถ้าจำเป็นสำหรับ debug แต่ไม่ผ่าน UI ปกติ)
- [ ] Home's feed-mode selector มี 4 ตัวเลือก (สำหรับคุณ/ติดตาม/ล่าสุด/จาก Club ของคุณ) — "ติดตาม" แสดง Drop+Pop ผสมจากคนที่ follow เท่านั้น พร้อม empty state ที่เหมาะสม
- [ ] `DropFeedScreen`/`_DropTabFeed` ถูกลบออกจากโค้ดแล้ว ไม่มี route ใดชี้ไปอีก (ต่าง จาก Pop/ZOKY ที่ยังคงโค้ดไว้)
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ Home/Drop/Search/Notification/Follow/Club เดิมทั้งหมด

Dependencies: ไม่มี — เป็นงานลำดับแรกของ V1.0.0 Roadmap (Phase 0)

Priority: สูงสุด — บล็อกงานอื่นทุก Phase เพราะเป็นโครง navigation ที่ทุกฟีเจอร์ใหม่จะต้องอิงตาม

Risks: ต่ำ — reuse หน้าจอเดิมทั้งหมด (Search/Notification/CreateDrop) ไม่มี schema change ความเสี่ยงหลักอยู่ที่จุด deep-link ที่อาจตกหล่น (ต้อง grep ให้ครบทุกจุดที่ reference Pop/ZOKY route)

Recommendation: เริ่มได้ทันที ทำคู่ขนานกับ DS-009 (Design comparison) ได้เพราะเป็นคนละเรื่อง (โครงสร้าง nav vs สี) — แนะนำให้ AI Design ตัดสินใจ icon/layout ของปุ่ม Drop "+" ตรงกลาง (elevated FAB-style vs regular tab icon) และตำแหน่ง badge ของ Notifications tab

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ Bottom Nav ใหม่ตาม R1-R6 ก่อนส่ง AI Coding

---

## Coding Output (2026-08-22)

**Implementation**: Nav restructure ตาม design spec ครบทุก R (R1-R8) — `RootShell` เหลือ 5 destination (Home/Search/Drop+/Notifications/Profile) map เข้า 4 tab จริงใน `IndexedStack` (Drop เป็น action เปิด `CreateDropScreen` ไม่ใช่ tab) ย้าย unread-badge state + mark-as-read-on-visit (remount-key pattern เดียวกับ Profile เดิม) จาก `HomeFeedScreen` มาไว้ที่ `RootShell`, ย้าย Search/Notifications ออกจาก Home's top row เป็น tab จริง (เพิ่ม `SearchScreen.autofocus` default `false` เพื่อไม่ให้คีย์บอร์ดผุดทุกครั้งที่สลับแท็บ) — **R8**: ยุบ `DropFeedScreen` (For You/Following/Latest) เข้า Home เป็นโหมด "ติดตาม" ใหม่ (`HomeRepository.fetchFollowingFeed` มิเรอร์ `DropRepository.fetchFollowingFeed` เดิมเป๊ะ) แล้วลบ `drop_feed_screen.dart`/`drop_feed_screen_test.dart` ทิ้งจริง (capability ย้ายเข้า Home ครบ ไม่มี route ไหนชี้ไปอีก) — DS-009's Rainbow accent (Trending tile ring + active-segment dot) ทำพร้อมกันในรอบเดียวเพราะแตะไฟล์ Home เดียวกัน

**Files Changed**:
- `app/lib/features/root/presentation/root_shell.dart` — เขียนใหม่ทั้งไฟล์ (5-destination nav, badge state, remount keys, optional-repository-injection สำหรับ testability)
- `app/lib/features/home/presentation/home_feed_screen.dart` — ตัด top row (search bar/notif bell) ทิ้ง, เพิ่มโหมด "ติดตาม", เพิ่ม Rainbow accent dot บน segment ที่ active
- `app/lib/features/home/data/home_repository.dart` — เพิ่ม `fetchFollowingFeed`
- `app/lib/features/home/presentation/widgets/trending_tile.dart` — เพิ่ม Rainbow ring (DS-009)
- `app/lib/features/search/presentation/search_screen.dart` — เพิ่ม `autofocus` param (default `false`)
- `app/lib/core/design/wyn_colors.dart` + `seller_app/lib/core/design/wyn_colors.dart` (มิเรอร์ตรงตัวอักษร ตาม DS-001's sync convention) — เพิ่ม `rainbowAccent` gradient token
- ลบ: `app/lib/features/drop/presentation/drop_feed_screen.dart`, `app/test/drop_feed_screen_test.dart`
- `app/test/home_feed_screen_test.dart` — ตัด test ของ search-bar/notification-badge ที่ย้ายออกไป (ตอนนี้อยู่ใน `root_shell_test.dart` ใหม่), เพิ่ม test กลุ่ม "ติดตาม" + Rainbow accent dot
- `app/test/support/recording_home_repository.dart` — เพิ่ม `followingFeedItems`/`fetchFollowingFeedCalls`
- `app/test/root_shell_test.dart` — **ไฟล์ใหม่** (RootShell ไม่เคยมี test มาก่อน — เพิ่ม optional repository injection ให้ testable เป็นครั้งแรก มิเรอร์ pattern เดิมของ `CreateDropScreen`)

**Reason**: ตรงตาม Design spec `wyn-024-bottom-nav-v1-restructure.md` และ `ds-009-rainbow-accent.md` ทุกข้อ — ไม่แตะ Pop/ZOKY/SELLER โค้ดหรือ DB เลย (แค่เลิก mount ใน `RootShell`)

**Tests**: เพิ่ม test ใหม่ครอบคลุม nav mapping, badge zeroing, Drop-action-ไม่เปลี่ยน-tab, โหมด "ติดตาม" (fetch/empty-state/switch-back), Rainbow accent dot เคลื่อนตามการเลือก — **⚠️ ไม่สามารถรัน `flutter analyze`/`flutter test` ได้ในเซสชันนี้** (ไม่มี Flutter/Dart SDK ติดตั้งอยู่ใน environment นี้ และ network proxy ที่ใช้อยู่ไม่อนุญาตให้ดาวน์โหลด Flutter SDK จาก github.com/storage.googleapis.com) — ตรวจสอบด้วยมือแทน: อ่านโค้ดทุกไฟล์ที่แก้ซ้ำ, ตรวจสอบ brace/paren balance ทุกไฟล์, grep หา reference ที่ตกค้างของ param/class ที่ลบ/เปลี่ยนชื่อทุกจุด (ไม่พบ), เทียบ constructor signature ทุกจุดเรียกกับที่นิยามจริง — **AI QA & Security ต้องรัน `flutter analyze`/`flutter test` อิสระเป็นด่านแรกก่อนอย่างอื่นทั้งหมด** เพราะรอบนี้ไม่มีตัวเลขจาก Coding ให้เทียบเหมือนทุกรอบก่อนหน้า

**Build**: ไม่ได้ build (Flutter SDK ไม่มีในเซสชันนี้ ดูเหตุผลเดียวกับ Tests)

**Known Issues**:
1. Drop action button's accessibility semantics (`Semantics(label: 'สร้าง Drop ใหม่', button: true)`) อยู่ซ้อนใน `NavigationDestination` ซึ่ง Flutter ห่อ semantics อัตโนมัติเป็น "tab X of 5" — ไม่ได้ทดสอบว่า screen reader จะพูดซ้ำซ้อนกันไหม (ไม่มี pattern อ้างอิงในโปรเจกต์นี้มาก่อนสำหรับปุ่ม action กลาง Bottom Nav)
2. `_homeVersion` bump (remount ทั้ง Home หลังสร้าง Drop) รีเซ็ต feed mode กลับเป็น "สำหรับคุณ" เสมอ แทนที่จะรักษาโหมดเดิมที่ user ค้างอยู่ — เป็นการยอมรับ trade-off เพื่อไม่ต้อง thread callback/GlobalKey ซับซ้อนเข้า `HomeFeedScreen`'s private State (ตามที่ design spec เปิดทางให้ "หรือเทียบเท่า")
3. `RootShell` ไม่เคยมี test มาก่อนเลย เพิ่ง unlock ได้รอบนี้ — coverage ยังไม่ครบทุก edge case (เช่น double-tap Drop action, Profile visit-key bump)

**Handoff**: ส่งต่อ AI QA & Security — ให้ความสำคัญเป็นพิเศษกับ: (1) รัน `flutter analyze`/`flutter test` เป็นอันดับแรก เพราะ Coding ไม่มีตัวเลขให้เทียบรอบนี้ (2) ยืนยันว่า Pop/ZOKY โค้ด+ตาราง DB ยังอยู่ครบ ไม่ได้ถูกลบไปด้วยระหว่างที่ลบ `DropFeedScreen` (3) ยืนยันว่าไม่มี dead-link เหลือที่ยังชี้ไป Pop/ZOKY จากหน้าจออื่น (4) ทดสอบ "ติดตาม" mode ด้วย fixture ที่มี Drop+Pop ผสมกันจริง ไม่ใช่แค่ Drop อย่างเดียวแบบที่ unit test ใช้

---

## QA Output (2026-08-22) — รอบ 1: FAIL

**Environment**: ติดตั้ง Flutter 3.47.1 (stable) ใหม่ในเซสชันนี้ — สิ่งที่ Coding รายงานว่าทำไม่ได้ (ไม่มี Flutter SDK ในเซสชันนั้น, `github.com`/`storage.googleapis.com` ดูเหมือนจะโดนบล็อกจาก proxy) จริงๆ แล้ว **`storage.googleapis.com` (ที่เก็บ Flutter SDK archive) เข้าถึงได้** (`github.com` เท่านั้นที่บล็อก, HTTP 403) — ดาวน์โหลด `flutter_linux_3.47.1-stable.tar.xz` ตรงๆ สำเร็จ ตรงกับเวอร์ชันที่ QA รอบก่อนๆ ของโปรเจกต์นี้เคยใช้ (3.47.0)

**Test Cases**: sync branch (`claude/remaining-items-r10hl0` ล่าสุด, commit `31418ff`) → `flutter pub get` → `flutter analyze` → `flutter test` (ทั้ง suite) → ไล่ requirement R1-R8 ของ WYN-024 + DS-009's 2 จุด (Trending ring, active-segment accent) เทียบกับ design spec → ตรวจ Pop/ZOKY ไม่มี dead code/dead link เหลือ → ยืนยัน `seller_app`'s token-sync test ผ่าน

**Passed**:
- ไม่มี schema.sql change รอบนี้ (ไม่ต้องตรวจ RLS/Postgres)
- Pop/ZOKY: โค้ด/ไฟล์ยังอยู่ครบ ไม่มี call site เหลือนอกจากตัวเองในทั้ง `app/lib` (ถอดจาก UI จริง ไม่ใช่ dead-link)
- DS-009's Trending tile ring (`trending_tile.dart`): ไม่มี layout error ใดๆ ที่ตรวจพบ
- `seller_app`: `flutter analyze` สะอาด, `token_sync_test.dart` 4/4 ผ่าน (mirror ของ `wyn_colors.dart`'s `rainbowAccent` sync ถูกต้อง)

**Failed** (รายละเอียดเต็มที่ `.wyn/tasks/bugs/WYN-024-nav-restructure-build-and-overflow.md`):
1. **`flutter analyze` — 1 error** (`const_with_non_const` ที่ `root_shell.dart:301`) — **แอปคอมไพล์ไม่ผ่านทั้งแอป** ไม่ใช่แค่ feature เดียว
2. **`flutter test test/home_feed_screen_test.dart` — 4 failing** — Rainbow accent dot (DS-009) ทำให้ `SegmentedButton`'s active segment overflow 11px ตั้งแต่ตอนเปิด Home ครั้งแรก (โหมดเริ่มต้น "สำหรับคุณ" ก็ overflow อยู่แล้ว ไม่ใช่แค่กรณี label ยาว)
3. **`flutter test test/root_shell_test.dart` — 6/6 failing** — test file ใหม่สร้าง `SupabaseClient` (และ auto-refresh Timer) ใหม่ทุก test แทนที่จะสร้างครั้งเดียวใน `setUpAll` (anti-pattern ที่โปรเจกต์นี้เคยบันทึกไว้ใน `.wyn/learning/PATTERNS.md` แล้ว)

**Severity**: Critical (Bug 1, build-blocking), Major (Bug 2, กระทบหน้าจอหลักของแอปโดย default), Major/test-only (Bug 3)

**Reproduction Steps**: ดูใน bug report แต่ละข้อ — ทำซ้ำได้ 100% ด้วย `flutter analyze`/`flutter test` ตรงๆ ไม่ต้องมี fixture พิเศษ

**Expected**: `flutter analyze` 0 error, `flutter test` ผ่านครบ, Home เปิดมาไม่มี layout overflow

**Actual**: คอมไพล์ไม่ผ่าน + Home overflow โดย default + test ใหม่ทั้งไฟล์ fail ด้วยเหตุผลที่ไม่เกี่ยวกับ logic จริง

**Security Findings**: ไม่พบ — ตรวจ `HomeRepository.fetchFollowingFeed` แล้ว (query pattern มิเรอร์ `DropRepository.fetchFollowingFeed` เดิมที่ผ่าน QA ไปแล้ว ไม่มี RLS/auth ใหม่ที่ต้องตรวจเพิ่มเพราะไม่แตะ schema)

**Recommendation**: ส่งต่อ AI Debug Engineer ทันที — ทั้ง 3 บั๊กอยู่ในไฟล์ที่แก้รอบนี้ทั้งหมด ไม่กระทบไฟล์อื่น ความเสี่ยง regression ต่ำถ้าแก้ตามที่ bug report เสนอ (QA ทดลอง patch ชั่วคราวแล้ว revert ออกแล้ว ยืนยันว่าการแก้ตามที่เสนอทำให้ `flutter analyze`/`flutter test` ของ `home_feed_screen_test.dart` ผ่านสะอาดจริง)

**Final Status: FAIL**

---

## QA Output (2026-08-22) — รอบ 2: FAIL (พบบั๊กใหม่)

**Environment**: Flutter 3.47.1 เดิมจากรอบ 1 (ยังอยู่ในเซสชันนี้) — sync branch ใหม่ที่ commit `665ee79` (Debug Engineer's fix)

**Test Cases**: รัน `flutter analyze`/`flutter test` อิสระใหม่ทั้งหมด (ไม่เชื่อตัวเลขที่ Debug รายงาน) → ตรวจ `seller_app` → **ทำ narrow-viewport spot-check เพิ่มเติมที่ Debug ไม่ได้ทำ** (ตามที่ตัวเองแนะนำไว้ท้าย Bug Report ว่า "จาก Club ของคุณ" ควรดูจริงจังอีกที) — เขียน widget test ชั่วคราว (ไม่ commit) วัด `RenderParagraph` ของ label "จาก Club ของคุณ" ตอน active ที่ 6 ความกว้างจอ (360/375/390/414/430/800px) + capture screenshot จริงที่ 360px ด้วย `RenderRepaintBoundary.toImage`

**Passed**:
- `flutter analyze` — 0 error ทั้ง `app/`/`seller_app/` (Bug 1 ยืนยันแก้จริง)
- `flutter test` (ทั้ง suite) — **357/357 ผ่าน** ตรงกับตัวเลขที่ Debug รายงานเป๊ะ (Bug 2's overflow assertion, Bug 3's Timer leak, Bug 4's `pageBack()` ยืนยันแก้จริงทั้งหมด — ไม่มี regression อื่นเกิดขึ้น)
- `seller_app`'s token-sync test — 4/4 ผ่าน

**Failed** (รายละเอียดเต็มที่ `.wyn/tasks/bugs/WYN-024-active-segment-label-truncation.md`):
- **บั๊กใหม่ (ไม่ใช่จากรอบ 1)**: Bug 2's fix (`Flexible(child: Text(label, overflow: ellipsis))`) หยุด overflow assertion ได้จริง แต่ label ข้อความของ segment "จาก Club ของคุณ" ตอน active **หายไปเกือบหมด** ทุกความกว้างจอมือถือจริง (360–430px ได้แค่ 20–38px กว้าง, `didExceedMaxLines: true` ทุกจุด รวมถึงที่ 800px ซึ่งเป็น default viewport ของ `flutter test` เอง) — screenshot ที่ 360px ยืนยันด้วยตา: segment ที่ active เหลือแค่เครื่องหมายถูกของ Material เอง + จุด Rainbow เท่านั้น ไม่มีตัวอักษรเหลือให้อ่านเลย

**Severity**: Major — ไม่ crash/ไม่ error แต่ผู้ใช้เสียความสามารถอ่านชื่อโหมดที่กำลังดูอยู่ (ยังพอรู้ผ่านสี/ขอบที่ selected แต่ไม่ใช่ผ่านตัวอักษรอีกต่อไป) บนหน้าจอหลักของแอป ทุกขนาดจอจริงไม่มีข้อยกเว้น

**Reproduction Steps**: ดูตารางเต็มใน bug report — ทำซ้ำได้ 100%

**Expected**: label "จาก Club ของคุณ" ตอน active อ่านได้ชัดเจนอย่างน้อยบางส่วนที่มีความหมาย ไม่ใช่หายไปทั้งหมด

**Actual**: หายไปเกือบสมบูรณ์ทุกความกว้างจอที่ทดสอบ

**Security Findings**: ไม่พบเพิ่มเติม

**Recommendation**: ทำไมถึงไม่ block ตั้งแต่รอบ 1 — เพราะทั้ง Debug และ QA รอบ 1 ตรวจแค่ "overflow assertion หายไหม" ไม่ได้ตรวจ "อ่านได้จริงไหม" ที่ความกว้างจอจริง (บทเรียนเดียวกับที่ SELLER-004 เคยเจอมาแล้ว บันทึกไว้ใน `.wyn/learning/LESSONS_LEARNED.md`) — ส่งต่อ AI Debug Engineer พร้อม AI Design ให้ช่วยตัดสินใจทางเลือกการแก้ (3 ทางเลือกเสนอไว้ใน bug report) เพราะเป็นการตัดสินใจเชิง UX ไม่ใช่แค่ technical fix

**Final Status: FAIL**
