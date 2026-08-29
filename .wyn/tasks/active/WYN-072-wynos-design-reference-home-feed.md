# Product Task — WYN-072

Status: active — ส่งต่อ AI Coding (เริ่มเฉพาะหน้า 01-home ตามลำดับที่ README ของ reference กำหนด)
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
- [ ] Token file ใหม่ตรง SPEC.md Section 1-2 ทุกค่า (สี, font, type scale) ไม่มี hardcode hex กระจาย
- [ ] Header/Explainer banner/Sticky tabs+pill/Post card ตรง SPEC.md Section 4 ทุกจุดที่ implement ได้จริง
      (จุดที่ backend ยังไม่รองรับ — liked-by names, top reply — ให้บันทึกเป็น Known Issue พร้อมข้อเสนอ
      ไม่ใช่ mock ข้อมูลปลอม)
- [ ] ClubSection/Trending ยังอยู่ตำแหน่งเดิม ทำงานเหมือนเดิม ไม่ถูกแตะ
- [ ] `flutter analyze` สะอาด, `flutter test` เต็ม suite ผ่านทั้งหมด (รวม test เดิมของ Home ที่มีอยู่)
- [ ] Regression ของ R8 ผ่านหมด (เพิ่ม/ปรับ widget test ตามจุดที่โครงสร้าง widget เปลี่ยน)
- [ ] ไม่แตะไฟล์ของหน้าจออื่นที่ไม่เกี่ยวกับ Home (นอกเหนือจาก token file ที่ share ได้)

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

Handoff: ส่งต่อ AI Coding ทันที — เสร็จแล้วให้กลับมาโชว์ผลก่อนเปิด task หน้าถัดไป (02-notifications)
ตามกติกาที่ README ของ reference กำหนดไว้ชัดเจนว่าห้ามทำรวดเดียวหลายหน้า
