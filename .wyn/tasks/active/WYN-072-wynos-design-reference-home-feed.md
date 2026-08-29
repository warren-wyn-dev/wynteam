# Product Task — WYN-072

Status: coding complete — ส่งต่อ AI QA & Security (implementation เสร็จ, `flutter analyze`/`flutter test`
ยังไม่ได้รันจริงในรอบนี้ — ดูหัวข้อ "Known Issues" ข้อสุดท้าย)
Owner: AI Product Manager → AI Coding → AI QA & Security

Feature: WYNOS Design Reference Rollout — Screen 01: Home Feed

Goal: Founder อัปโหลดชุด design reference ใหม่ทั้งแอป (23 ไฟล์ `.tsx` ที่ root ของ repo, ไม่ใช่ที่
`/design-reference` ตามที่ `README.md` อ้างถึง — อัปโหลดผิดตำแหน่งเล็กน้อยแต่เนื้อหาไม่กระทบ) พร้อม
`SPEC.md` (design tokens + Home Feed component spec แบบละเอียดระดับ pixel) และ `README.md` ที่ระบุ
วิธีทำงานชัดเจน: **ทำทีละหน้าตามลำดับเลข (01 → 22), เทียบให้ตรง 100% กับ reference ก่อนไปหน้าถัดไป,
ห้ามข้าม, โชว์ผลแต่ละหน้าให้ดูก่อน**

Task นี้ครอบคลุมเฉพาะ **หน้า 01 (Home Feed)** เท่านั้น — หน้าอื่นเป็น task แยกที่จะเปิดต่อเนื่องหลังหน้านี้
ผ่านการตรวจแล้ว

Target User: ผู้ใช้ WYNOS ทุกคน (Home คือหน้าแรกที่เห็นหลัง login)

Reference files (อ่านตามลำดับ):
1. `/00-prototype.tsx` — nav map ภาพรวมทั้งแอป (อ่านเพื่อบริบท ไม่ใช่ pixel spec)
2. `/SPEC.md` — **นี่คือไฟล์หลักของ task นี้** (หัวเรื่องเขียนว่า "WYNOS Home Feed" ชัดเจน — Section 1-2
   เป็น design tokens ที่จะใช้ทั้งแอปในอนาคต, Section 3-10 เป็น component spec เฉพาะ Home Feed)
3. `/01-home.tsx` — pixel-level reference implementation (React/JSX ใช้เทียบ, ไม่ใช่โค้ดที่ port ตรงๆ)

**ข้อสังเกตสำคัญ (ตรวจ codebase ก่อนเขียน task นี้ ตาม RULES.md "ตรวจสอบก่อนเสมอ")**:

- **Tech stack ไม่ตรงกัน**: reference เป็น React/TSX (มีการอ้างถึง Tailwind ใน README) แต่แอปจริงใน
  `app/` เป็น **Flutter/Dart** ล้วน — AI Coding ต้อง "แปล" ดีไซน์เป็น Flutter widget เอง ไม่มีโค้ดให้ copy ตรงๆ
- **สีหลักเปลี่ยนทิศทาง**: DS-001 (อนุมัติแล้ว 2026-08-15) กำหนด Cyan `#00C8FF` เป็น primary; reference
  ชุดนี้ใช้ **Sapphire `#1B3A6B`** เป็น "the one accent color" แทนทั้งหมด — ถือเป็นการเปลี่ยนทิศทางแบรนด์ที่
  Founder ตัดสินใจแล้วผ่านการอัปโหลดไฟล์นี้ตรงๆ (สอดคล้องกับการเปลี่ยนชื่อแอปเป็น "Wynos" ที่บันทึกไว้ใน
  CONTEXT.md เมื่อ 2026-08-23) — **ไม่ต้องถาม Founder ซ้ำ**, แต่ implement เป็น token set ใหม่แยกต่างหาก
  (ดู Requirements ข้อ R1) ไม่ overwrite `WynColors`/`WynTheme` เดิมทั้งระบบในรอบนี้ เพราะรอบนี้ทำแค่หน้า
  Home เดียว หน้าอื่นยังต้องใช้ธีมเดิมจนกว่าจะถึงคิว
- **ClubSection + Trending Section ไม่มีใน reference เลย**: reference (`01-home.tsx`) มีแค่ Header →
  Explainer banner → Sticky tabs+pill → Post list เท่านั้น ไม่มีส่วน Club/Trending ที่แอปจริงมีอยู่ในหน้า
  Home ปัจจุบัน (`ClubSection`, `_buildTrendingSection` ใน `home_feed_screen.dart`) — SPEC.md section 6
  ("Explicitly out of scope") ไม่ได้พูดถึงสองส่วนนี้เลย ตีความว่า **เป็นส่วนที่ spec นี้ไม่ครอบคลุม ไม่ใช่สั่งให้
  ลบ** — **การตัดสินใจ**: คงโครงสร้าง/ตำแหน่งเดิมของ ClubSection และ Trending ไว้เหมือนเดิมทั้งหมด (เหนือ
  แถบ tab, ก่อนฟีด) ไม่แตะทั้ง styling และ logic ของสองส่วนนี้ในรอบนี้ — เป็น "ส่วนที่ยังไม่ถึงคิว" ไม่ใช่
  "ส่วนที่ต้องลบทิ้ง"
- **4 filter tabs ตรงกับของเดิมอยู่แล้ว**: "สำหรับคุณ"/"ติดตาม"/"ล่าสุด"/"จาก Club" ตรงกับ `_HomeFeedMode`
  enum ที่มีอยู่แล้วเป๊ะ (forYou/following/latest/fromYourClubs) — เปลี่ยนแค่ visual (underline indicator
  สีเดียวแทน rainbow gradient เดิมจาก DS-009, ไม่ใช้ `SegmentedButton` แบบเดิม) ต้อง**คง scroll-safety
  fix ของ WYN-024 ไว้** (segment label ต้องไม่ถูกตัดที่จอแคบ 320px) แม้จะเปลี่ยนวิธี render

Requirements:
- R1. สร้าง token file ใหม่ (เช่น `app/lib/core/design/wynos_home_tokens.dart`) จาก SPEC.md Section 1-2
  เป๊ะ: สี ink/paper/canvas/graphite/faint/hairline/sapphire (+ sapphire 20% alpha สำหรับ avatar ring),
  ฟอนต์ Fraunces (wordmark เท่านั้น)/Inter (ทุกที่) — ห้าม hardcode hex กระจายในไฟล์อื่น ให้ทุก widget ที่
  แก้ในรอบนี้ reference จาก token file นี้ (ตรวจสอบว่า Fraunces/Inter มีอยู่ใน `pubspec.yaml`/assets
  หรือยัง ถ้าไม่มีต้องเพิ่ม — ห้ามใช้ font อื่นแทนเงียบๆ)
- R2. Header: hamburger (☰) — "WYNOS" wordmark (Fraunces 500 19px letter-spacing 0.06em) — search icon
  — ตาม SPEC 4.1 (คง onTap เดิมของ ☰/search ไว้ แค่เปลี่ยน styling)
- R3. First-time explainer banner (SPEC 4.2) — ใหม่ทั้งหมด ไม่เคยมีในแอป — ต้อง persist การ dismiss แบบ
  ถาวรต่อ account จริง (ไม่ใช่ per-session) — เก็บ preference นี้ที่ไหน (local prefs vs. backend column)
  ให้ AI Coding เลือก pattern เดียวกับ preference อื่นที่มีอยู่แล้วในระบบ (เช่น notification settings)
- R4. Sticky filter tabs (SPEC 4.3): แทนที่ `SegmentedButton` เดิมด้วย underline-tab style ตาม spec เป๊ะ
  (active: weight 600 ink + sapphire underline 2px; inactive: weight 400 faint) — **ต้องยังคง responsive
  fix ของ WYN-024** (ห้าม regress กลับไปเป็นปัญหา label ถูกตัดที่จอแคบ)
- R5. New-posts indicator pill (SPEC 4.4) — ใหม่ทั้งหมด ไม่เคยมีในแอป — ต้องต่อกับ real-time infra ที่มี
  อยู่แล้ว (ถ้ายังไม่มี realtime signal สำหรับ "มีโพสต์ใหม่" ให้ AI Coding รายงานเป็น Known Issue ไม่ใช่
  ปลอมด้วย mock/hardcoded — ตาม SPEC "Do not silently prepend new posts on refresh")
- R6. Empty state (SPEC 4.5) — เชื่อมกับเงื่อนไขจริง (follow count = 0) ไม่ใช่ mock toggle แบบใน reference
- R7. Post card เขียนใหม่ทั้ง `HomeDropCard`/`HomePopCard` ให้ตรง SPEC 4.6-4.10:
  - ย้าย Share/Bookmark ออกจาก action bar เดิม ไปอยู่ใน `⋯` dropdown menu ใหม่ (SPEC 4.6)
  - Action bar เหลือ 4 อย่างเท่านั้นตามลำดับ: Heart/Comment/Repost/Eye(view, ไม่ tap ได้) (SPEC 4.9)
  - Image carousel แบบ peek-card + double-tap-to-like + heart-burst animation (SPEC 4.7) — ผูกกับ
    `_toggleLike` ที่มีอยู่แล้วจริง ไม่ใช่ mock
  - Liked-by row แบบ avatar ซ้อนกัน (SPEC 4.8) — ต้องมีข้อมูล "ใครกดไลค์บ้าง" จริงจาก backend; ถ้า
    repository ปัจจุบันไม่ return รายชื่อผู้ไลค์ (มีแค่ count) ให้ AI Coding ตรวจสอบและรายงานเป็น
    Requirement เพิ่มเติม/gap แทนการ mock ชื่อ
  - Top reply preview (SPEC 4.10) — ต้องดึง reply/comment ที่มี engagement สูงสุดจริงจาก backend; ถ้า
    ยังไม่มี query แบบนี้ ให้รายงานเป็น gap เช่นกัน
- R8. Regression: ฟีเจอร์เดิมทั้งหมดของ Home ต้องทำงานถูกต้องเหมือนเดิม — infinite scroll, pull-to-
  refresh, poll voting, redrop/quote-redrop, hide, chat icon badge, ClubSection, Trending — ไม่มีอะไรพัง

Acceptance Criteria:
- [x] Token file ใหม่ตรง SPEC.md Section 1-2 ทุกค่า (สี, font, type scale) ไม่มี hardcode hex กระจาย —
      `app/lib/core/design/wynos_home_tokens.dart` (สร้างโดยรอบนี้, แล้ว merge เข้ากับเวอร์ชันที่ WYN-073
      สร้างขึ้นพร้อมกันบน branch เดียวกัน — ดู "Known Issues" หัวข้อ concurrent-session conflict)
- [x] Header/Explainer banner/Sticky tabs+pill/Post card ตรง SPEC.md Section 4 ทุกจุดที่ implement ได้จริง
      (จุดที่ backend ยังไม่รองรับ — liked-by names, top reply — บันทึกเป็น Known Issue พร้อมข้อเสนอแล้ว
      ไม่ได้ mock ข้อมูลปลอม)
- [x] ClubSection/Trending ยังอยู่ตำแหน่งเดิม ทำงานเหมือนเดิม ไม่ถูกแตะ
- [ ] `flutter analyze` สะอาด, `flutter test` เต็ม suite ผ่านทั้งหมด (รวม test เดิมของ Home ที่มีอยู่) —
      **ยังไม่ได้รันจริง** ไม่มี Flutter SDK ใน sandbox ของ session นี้ (ดู Known Issues) — โค้ดตรวจสอบด้วย
      มือ (imports, constructor signatures, brace balance) แต่ต้องรัน `flutter pub get && flutter analyze
      && flutter test` จริงก่อนอนุมัติ
- [x] Regression ของ R8 ผ่านหมด (เพิ่ม/ปรับ widget test ตามจุดที่โครงสร้าง widget เปลี่ยน) — แก้ test เดิม
      ที่อ้างอิง action-bar Share icon/`Icons.more_vert`/rainbow accent key แล้ว, เพิ่ม test ใหม่สำหรับ
      header/banner/empty-state/more-menu
- [x] ไม่แตะไฟล์ของหน้าจออื่นที่ไม่เกี่ยวกับ Home (นอกเหนือจาก token file ที่ share ได้ และ
      `root_shell.dart` ซึ่งต้อง wire repository ใหม่ 3 ตัวเข้า `HomeFeedScreen`)

Dependencies: ไม่ทับ `WynColors`/`WynTheme` เดิม (หน้าอื่นยังใช้ต่อจนกว่าจะถึงคิว), ต่อยอด
`HomeFeedItem`/`HomeRepository`/`DropRepository`/`PopRepository` เดิมทั้งหมด (ห้ามเปลี่ยน data model)

Priority: สูง — Founder ขอให้เริ่มทันที (สั่งผ่าน session นี้ 2026-08-29)

Risks:
- Backend gap สำหรับ "liked-by names" และ "top reply" อาจทำให้ implement ได้ไม่ครบ 100% ตาม spec ใน
  รอบเดียว — ถ้าเจอ ให้ AI Coding ทำเท่าที่ backend รองรับจริงก่อน แล้วบันทึก gap ไว้ชัดเจน ห้าม mock
  ข้อมูลที่ดูเหมือนจริงแต่ไม่ใช่
- การเปลี่ยน widget structure ของ post card (ย้าย Share/Bookmark ออกจาก action bar) กระทบทุกจุดที่มี
  test อ้างอิง action bar เดิม — ต้องตามแก้ test ให้ครบ ไม่ปล่อยให้แดง

Recommendation: เริ่มจาก R1 (tokens) ก่อนเสมอ ตามลำดับที่ README ของ reference กำหนด แล้วค่อยไล่ R2-R7
ทีละจุดตามลำดับใน SPEC.md Section 4 (4.1 → 4.10) ห้ามข้าม

## Known Issues (บันทึกโดย AI Coding, 2026-08-29)

1. **Liked-by row (SPEC 4.8) — ไม่ได้ implement**: `HomeFeedItem`/`home_feed` view คืนแค่ `likeCount`
   (ตัวเลขรวม) ไม่มี list รายชื่อผู้กดไลค์เลยในทุก query ของ Home feed — ไม่มี backend รองรับให้ implement
   จริงได้ในรอบนี้ ไม่ได้ mock ชื่อปลอมใดๆ ข้อเสนอ: เพิ่ม join `drop_likes`/`pop_likes` คืนโปรไฟล์ผู้ไลค์ 3
   คนแรก + total count ผ่าน view หรือ RPC ใหม่
2. **Top reply preview (SPEC 4.10) — ไม่ได้ implement**: ไม่มี repository/RPC ใดคืน "reply ที่ engagement
   สูงสุด" ของโพสต์ได้เลย — `commentCount` คือ field เดียวที่เกี่ยวกับ comment ที่ `HomeFeedItem` มี ข้อเสนอ:
   เพิ่ม column แบบ embed ใน `home_feed` view คำนวณจาก comment like-count สูงสุด หรือ RPC แยก
3. **New-posts pill trigger (SPEC 4.4) — UI/interaction ครบ แต่ trigger ไม่เคยเป็น true**: ปุ่ม/สไตล์/
   tap-to-scroll-to-top-and-refresh ทำงานจริงครบ (`_buildNewPostsPill`/`_onTapNewPostsPill` ใน
   `home_feed_screen.dart`) แต่ `_showNewPostsPill` ไม่มี code path ไหนตั้งเป็น `true` เลย เพราะไม่มี
   realtime/poll infra ที่บอกได้ว่า "มีโพสต์ใหม่ที่ควรอยู่บนสุดของ feed mode ปัจจุบัน" จริงๆ (โดยเฉพาะ
   "สำหรับคุณ" ที่ ranking มาจาก RPC ไม่ใช่ created_at ธรรมดา) — ไม่ได้ hardcode เป็น `true` ตามที่ spec
   ห้ามไว้ชัดเจน ข้อเสนอ: ต่อ Supabase Realtime บน `home_feed`/`drops`/`pops` insert events หรือ poll
   นับจำนวนโพสต์ใหม่กว่ารายการบนสุดปัจจุบันเป็นระยะ
4. **Header hamburger (SPEC 4.1) — ไม่มี Side Menu screen จริงให้เปิด**: reference มี Side Menu
   (`10-side-menu.tsx`, มี "โปรไฟล์"/"Club ของฉัน"/"บันทึกไว้") แต่แอปจริงไม่มี Drawer/Side Menu widget
   เลย ณ ตอนนี้ — สร้างเป็น task แยก (หน้า 10) ไม่ใช่ scope ของ Home Feed รอบนี้ ปุ่ม ☰ จึงแสดง
   SnackBar "เมนูนี้จะพร้อมใช้งานเร็ว ๆ นี้" (ตามรูปแบบเดียวกับที่ reference เองใช้กับ "Club ของฉัน" ใน
   `00-prototype.tsx`) แทนที่จะเงียบไม่ตอบสนอง — ไอคอน search ทำงานจริง (push `SearchScreen`)
5. **Verified badge — ไม่มี field รองรับ**: ทั้ง `Profile` และ `HomeFeedItem` ไม่มี field ระบุบัญชี
   verified เลย (ยืนยันด้วยการ grep ทั้ง codebase) จึงไม่ render badge นี้ที่ไหนเลยในรอบนี้ ไม่ใช่ bug
   แค่ไม่มีข้อมูลจริงให้แสดง
6. **Image carousel (SPEC 4.7) — โครง peek-card ถูกต้อง แต่มีแค่ 1 รูปจริง**: `HomeFeedItem.imageUrl`
   เป็นรูปเดียว (cover image) เท่านั้น ทั้งที่ WYN-071 มี `drop_images` เก็บรูปเต็ม (1-9 รูป) อยู่แล้ว และมี
   `DropRepository.fetchDropImages()` ให้ดึงได้จริง — แต่การ wire ทุก card ใน feed แบบ paginated ให้ query
   เพิ่มต่อโพสต์ (N+1) เป็นการตัดสินใจ scope ที่ใหญ่กว่ารอบนี้ (ความเสี่ยง performance) จึงยังไม่ทำ โครง
   carousel (peek-card 82% width, aspect 4:5, scroll-snap, double-tap-like ผ่าน `DoubleTapLike` เดิม)
   รองรับหลายรูปอยู่แล้วถ้ามีข้อมูลจริงในอนาคต
7. **`flutter analyze`/`flutter test` ยังไม่ได้รันจริง**: sandbox ของ session นี้ไม่มี Flutter SDK ติดตั้ง
   (`flutter`/`dart` ไม่พบใน PATH, ไม่มี SDK ที่ไหนในเครื่องเลย) — ตรวจโค้ดด้วยมือทั้งหมด (imports,
   constructor signatures ตรงกัน, brace/paren balance, การเรียกใช้ API ของ `google_fonts`) แต่ **ไม่ใช่
   สิ่งทดแทนการรัน compiler/test runner จริง** — AI QA & Security (หรือ session ถัดไปที่มี Flutter SDK)
   ต้องรัน `flutter pub get && flutter analyze && flutter test` ก่อนอนุมัติงานนี้เด็ดขาด (มีหลักฐานทางอ้อม
   ว่า dependency `google_fonts: ^6.2.1` ที่เพิ่มใน `pubspec.yaml` resolve ได้จริง — `pubspec.lock` ถูก
   อัปเดตโดย session ของ WYN-073 ที่รันบน branch เดียวกันและมี Flutter SDK จริง เห็น `google_fonts` เวอร์ชัน
   6.3.3 ถูก lock ไว้แล้ว)
8. **Concurrent-session file conflict**: WYN-073 (Screen 05, Profile) รันพร้อมกันบน branch เดียวกัน
   (`claude/remaining-work-x27ngr`) และสร้างไฟล์ `app/lib/core/design/wynos_home_tokens.dart` ชื่อเดียวกัน
   กับที่ task นี้สร้างพร้อมกัน — เกิด race condition เขียนทับกันบน disk ระหว่างทำงาน แก้ด้วยการ merge เป็น
   ไฟล์เดียว (superset ของทั้งสองเวอร์ชัน, ยืนยันแล้วว่า WYN-073's `wynos_post_row.dart`/
   `wynos_profile_post_list.dart` compile ได้กับเวอร์ชัน merge นี้) — Founder/orchestrator ควรพิจารณาว่า
   การรัน 2 AI Coding session พร้อมกันบน branch เดียวกันโดยไม่มี lock/coordination เป็นความเสี่ยงที่ควร
   ปรับ process ในอนาคต (เช่น แยก branch ต่อ task แล้ว merge, หรือ sequential เท่านั้น)

Handoff: ส่งต่อ AI QA & Security — โค้ดครบตาม R1-R8 (ยกเว้น gap ที่บันทึกไว้ข้างบน) แต่ **ต้องรัน
`flutter analyze`/`flutter test` ก่อน** เพราะ session นี้ไม่มี Flutter SDK ให้รันเอง เสร็จ QA แล้วค่อยกลับมา
โชว์ผลก่อนเปิด task หน้าถัดไป (02-notifications) ตามกติกาที่ README ของ reference กำหนดไว้ชัดเจนว่าห้ามทำ
รวดเดียวหลายหน้า
