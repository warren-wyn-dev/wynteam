# Product Task — WYN-028

Status: active (Coding เสร็จ, รอ AI QA & Security)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ — ดู `.wyn/docs/design/wyn-028-mute-system.md`) → AI Coding (เสร็จ) → AI QA & Security (ถัดไป)

Feature: Mute System

Goal: ให้ผู้ใช้ซ่อนเนื้อหาของผู้ใช้อื่นออกจาก Feed ของตัวเองแบบเงียบ ๆ โดยไม่ต้องตัดขาดความสัมพันธ์หรือให้อีกฝ่ายรู้ตัว

Target User: ผู้ใช้ที่ยัง Follow อยู่แต่ไม่อยากเห็นโพสต์บ่อย/ไม่อยากตัดสัมพันธ์ให้อีกฝ่ายรู้ (ต่างจาก Block ที่ต้องการตัดขาดจริงจัง)

Problem: WYN มี Follow แล้วแต่ไม่มีทางเลือกระหว่าง "เห็นทุกโพสต์" กับ "Unfollow/Block ตัดสัมพันธ์" เลย — Master Spec ข้อ 24 ระบุ Mute ไว้ชัดว่าต่างจาก Block ตรงที่ "ไม่อยากเห็นโพสต์ของคนนี้ แต่ไม่อยากให้เขารู้" เป็นฟีเจอร์ที่เบากว่า Block มาก และควรทำคู่กันใน Phase 1 เพราะ user list ใน `User Actions` ของ spec ระบุคู่กันเสมอ (Follow · Unfollow · Mute · Block · Report)

Requirements:

**การ Mute**
- Mute ได้จาก Profile ของผู้ใช้อื่น (เมนู More — ตำแหน่งเดียวกับ Block/Report) — Mute ได้ไม่ว่าจะ Follow กันอยู่หรือไม่ก็ตาม
- Mute เป็น **one-directional เท่านั้น** (A mute B → เฉพาะ A ไม่เห็นโพสต์ B ในฟีดตัวเอง — B ไม่ได้รับผลกระทบใด ๆ ไม่รู้ตัวว่าถูก mute)
- Unmute ได้จาก Settings → Safety → Muted List (เหมือน pattern ของ Blocked List ใน WYN-027)

**ผลของการ Mute (ต่างจาก Block ชัดเจน)**
- โพสต์ (Drop) ของผู้ถูก Mute หายไปจาก **Home Feed ของผู้ Mute เท่านั้น** (ไม่กระทบ Search, ไม่กระทบ Club Post ร่วม, ไม่กระทบ Profile — เข้าไปดู Profile ของผู้ถูก Mute ตรง ๆ ยังเห็นโพสต์ปกติทุกอย่าง เพราะเป็นการเลือกไม่เอาเข้า feed ไม่ใช่การซ่อนเนื้อหาทั้งหมด)
- **Follow relationship ไม่เปลี่ยนแปลง** (ยัง Follow กันอยู่ปกติ, follower/following count ไม่เปลี่ยน)
- **Like/Comment/Mention ยังทำได้ปกติทั้งสองทิศทาง** (mute ไม่จำกัด interaction ใด ๆ ต่างจาก Block)
- **ไม่มี notification ใด ๆ แจ้งว่าถูก mute** และผู้ถูก mute ไม่มีทางรู้เลยว่าตัวเองถูก mute จากช่องทางไหนในแอป

**Muted List (ใน Settings → Safety)**
- แสดงรายชื่อผู้ใช้ทั้งหมดที่ตัวเอง Mute ไว้ (username, display name, avatar)
- แตะ Unmute รายคน → โพสต์กลับมาแสดงใน Home Feed ตามปกติทันที

Acceptance Criteria:
- [ ] Mute ผู้ใช้จาก Profile → โพสต์ของผู้นั้นหายจาก Home Feed ของตัวเองทันที
- [ ] เข้า Profile ของผู้ถูก Mute โดยตรง → ยังเห็นโพสต์ปกติครบทุกอัน (mute ไม่กระทบ Profile view)
- [ ] Search เจอโพสต์ของผู้ถูก Mute ได้ปกติ (mute ไม่กระทบ Search)
- [ ] Follow/Follower count ของทั้งสองฝ่ายไม่เปลี่ยนแปลงหลัง Mute
- [ ] Like/Comment ระหว่างผู้ Mute กับผู้ถูก Mute ยังทำได้ปกติทั้งสองทิศทาง
- [ ] ไม่มี notification/สัญญาณใด ๆ ให้ผู้ถูก Mute รู้ว่าตัวเองถูก mute
- [ ] Unmute จาก Muted List → โพสต์กลับมาใน Home Feed ทันที
- [ ] Mute ตัวเองทำไม่ได้ (ปุ่มไม่แสดงบนโปรไฟล์ตัวเอง)
- [ ] Regression: Home Feed/Trending/Club Feed ของผู้ใช้อื่นที่ไม่เกี่ยวข้องกับความสัมพันธ์ Mute นี้ยังทำงานปกติ ไม่มีการกรองผิดคน

Dependencies: WYN-002/003 (Auth/Profile — Approved), WYN-007 (Home Feed — Approved, ต้องเพิ่ม filter Mute เข้า query), WYN-008 (Follow — Approved, ไม่ต้องแก้ logic เพราะ Mute ไม่กระทบ Follow) — ไม่ต้องพึ่ง WYN-026/027 โดยตรง แต่แนะนำ reuse entry point เดียวกับ Block/Report ใน Profile More menu

Priority: P1 — รองจาก WYN-026/WYN-027 เพราะผลกระทบต่อ safety จริงจังน้อยกว่า (เป็นเรื่อง UX/ความสบายใจ ไม่ใช่การป้องกันอันตราย) แต่ยังอยู่ใน Phase 1 ตามที่ roadmap กำหนด ทำได้ขนานกับ WYN-027 เพราะ scope แคบกว่ามากและไม่ชนกัน (Mute กระทบแค่ Home Feed query จุดเดียว)

Risks:
- **ต้องแยก scope ให้ชัดจาก Block ที่สุด**: ความเสี่ยงหลักคือ implement ผิดแล้ว mute กลายเป็น "block เบา ๆ" ที่กระทบ Search/Profile/Interaction ไปด้วย ต้องเทส cross-check กับ WYN-027 ให้แน่ใจว่าเห็นความต่างจริงในทุกจุดที่ระบุใน Acceptance Criteria
- **Home Feed query ต้องรวม filter ทั้ง Block และ Mute พร้อมกัน** (ถ้า WYN-027 ทำก่อนแล้ว) — ต้องออกแบบให้ไม่ชนกันและอ่านง่าย (แนะนำ view หรือ RPC เดียวที่ join ทั้ง `blocks` และ `mutes` แทนการซ้อน filter หลายชั้นในโค้ด Dart)
- Mute ไม่กระทบ Trending Score/View count ของ WYN-018 — ผู้ถูก mute ยังนับ engagement ปกติจากคนอื่นทั่วไป (มีแค่คนที่ mute เท่านั้นที่ไม่เห็น ไม่ใช่การลงโทษเนื้อหา)

Recommendation:
1. ทำขนานกับ WYN-027 ได้ (คนละ Dev cycle ก็ได้เพราะ scope ไม่ชนกัน) แต่แนะนำให้ AI Design ออกแบบ entry point ในหน้าเดียวกับ Block/Report (เมนู More ของ Profile) เพื่อความสม่ำเสมอของ UX
2. Design ตาราง `mutes (muter_id, muted_id, created_at)` โครงสร้างเดียวกับ `blocks` ของ WYN-027 (unique constraint คู่) — ต่างกันแค่ semantic ของ effect
3. Settings → Safety รวม Blocked List + Muted List ไว้หน้าเดียวกัน (2 section) แทนแยก 2 หน้า ลดจำนวนหน้าจอใหม่

Handoff: AI Design — ออกแบบ Mute entry point ใน Profile More menu (ร่วมกับ Block/Report) และ Muted List section ใน Settings → Safety

---

## Design Output (2026-08-22)

ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-028-mute-system.md` สรุปสั้น:

- **Entry point**: toggle "ปิดเสียง"/"เปิดเสียง" ใน `ViewProfileScreen`'s More menu ระหว่าง "รายงาน" กับ "บล็อก" — ไม่มี confirm dialog (ต่างจาก Block ตรงๆ เพราะ reversible/เงียบ/ไม่กระทบใคร) ใช้ pattern optimistic toggle เดียวกับ `_toggleFollow` ไม่แสดงเลยเมื่อมี block relationship อยู่แล้ว (ซ้ำซ้อนกับ Block ที่แรงกว่า)
- **Data layer เบากว่า Block มาก**: ไม่ต้องมี RPC เลย (ต่างจาก `block_user()`/`unblock_user()`) เพราะ Mute ไม่มี side-effect ที่ต้องอะตอมมิก — ตาราง `mutes` ใช้ direct insert/delete ผ่าน RLS ธรรมดาเหมือน `follows`
- **Filter จุดเดียวที่ `home_feed` VIEW** (ไม่ใช่ RLS ของ `drops`/`pops` เอง แบบที่ Block ทำ) เพราะต้อง "ไม่กระทบ Search/Club Post/Profile" ตรงตัวอักษร — ผลพลอยได้ที่ประกาศไว้ตรงๆ: Trending row ก็ถูกกรองด้วยเพราะ query view เดียวกัน (ตีความจาก AC ที่เขียน "Home Feed/Trending" คู่กัน)
- **ยืนยันแล้วว่าไม่ชนกับบั๊ก RLS self-referential trap ของ WYN-027**: อธิบายเหตุผลละเอียดใน Screen 2 ของ design doc ว่าทำไม inline subquery ปลอดภัยในกรณีนี้ ไม่ต้องมี helper function
- **Muted List ต่างจาก Blocked List ตรงที่แถว tap-to-profile ได้ปกติ** (Mute ไม่จำกัดการเข้าถึงโปรไฟล์เลย ไม่มีเหตุผลต้องกันเหมือน Block) — อยู่ใน `SettingsScreen` เดิมเป็น section "ความปลอดภัย" เดียวกัน แถวที่ 2 ต่อจาก Blocked List ไม่ใช่หน้าใหม่
- Follow/Like/Comment/Mention/Notification: **ไม่มี UI เปลี่ยนแปลงใดๆ เลย** — บันทึกไว้ชัดเจนกันเข้าใจผิดว่าต้องทำเหมือน Block

Handoff: AI Coding — เริ่มจาก data layer (`mutes` table + `home_feed` view filter) ตามลำดับใน design doc's Handoff section

---

## Coding Output (2026-08-22)

Implementation: เพิ่มตาราง `mutes` (unique key คู่ `muter_id`/`muted_id`, self-mute กันด้วย check constraint) พร้อม RLS ธรรมดา 3 policy (SELECT/INSERT/DELETE ผูกกับ `auth.uid() = muter_id` ทั้งหมด) — **ไม่มี RPC เลยตามที่ Design ระบุ** เพราะไม่มี side-effect ต้องอะตอมมิก แก้ `home_feed` view เพิ่มเงื่อนไข `not exists (select 1 from mutes where muter_id = auth.uid() and muted_id = <author_id>)` ในทั้งสองครึ่งของ UNION ALL (Drop และ Pop) เป็นจุดเดียวที่บังคับใช้ mute จริง ฝั่ง Flutter เพิ่มฟีเจอร์ใหม่ `app/lib/features/mute/` (`MuteRepository`, `MutedListScreen`) แก้ `ViewProfileScreen` เพิ่ม toggle "ปิดเสียง"/"เปิดเสียง" ใน More menu ระหว่าง "รายงาน"/"บล็อก" (ไม่มี confirm dialog ตาม Design) แก้ `SettingsScreen` เพิ่มแถวที่ 2 "บัญชีที่ปิดเสียง" ใน section "ความปลอดภัย" เดิม

Files Changed: `supabase/schema.sql` (WYN-028 section — `mutes` table + RLS + `home_feed` view redefinition), `app/lib/features/mute/**` (ใหม่), `app/lib/features/profile/presentation/view_profile_screen.dart`, `app/lib/features/settings/presentation/settings_screen.dart`

Reason: บังคับใช้ Mute เฉพาะที่ `home_feed` view (ไม่ใช่ RLS ของ `drops`/`pops` แบบ Block) เพื่อไม่ให้กระทบ Search/Club Post/Profile ตามที่ Design กำหนดไว้ชัดเจน — ผลพลอยได้ที่ตั้งใจ: แถว Trending ก็ถูกกรองด้วยเพราะ query view เดียวกัน

Known Issues fixed proactively: WYN-027 QA รอบ 1 พบว่า `ViewProfileScreen`'s `_reportRepository`/`_blockRepository` hardcode `Supabase.instance.client` ตรงๆ ทำให้ More menu/Blocked persona ไม่มี automated test ถาวรได้เลย (เสนอเป็น fast-follow) — แก้จุดนี้พร้อมกันตอนเพิ่ม `_muteRepository` ตัวที่สาม โดยเปลี่ยนทั้ง 3 ตัวเป็น optional constructor param (`reportRepository`/`blockRepository`/`muteRepository`) ที่ default ไปสร้างจาก `Supabase.instance.client` เองถ้าไม่ส่งมา (pattern เดียวกับ `clubRepository`/`clubPostRepository` ที่มีอยู่แล้ว) — ทำให้เขียน `view_profile_mute_test.dart` ทดสอบ More menu integration ได้จริงเป็นครั้งแรก (ก่อนหน้านี้ทำไม่ได้เลยเพราะ network call จริงล้มเหลวเงียบๆ ในสภาพแวดล้อม test)

Tests: เพิ่ม `test/muted_list_screen_test.dart` (5 เคส), `test/view_profile_mute_test.dart` (5 เคส — รวมถึงเคสที่ยืนยันว่า More menu แสดง "ปิดเสียง"/"เปิดเสียง" ถูกต้องตามสถานะ, ไม่แสดงเลยเมื่อมี block relationship, และ error revert ทำงานถูกต้อง), `test/settings_screen_test.dart` (3 เคส), `test/support/recording_mute_repository.dart` — รวม 13 เทสต์ใหม่ `flutter test` ทั้งโปรเจกต์ผ่านครบ 395/395 (baseline 382 + ใหม่ 13, ไม่มี regression) `flutter analyze`: สะอาด ไม่มี issue — SQL ยืนยันด้วยการรัน schema.sql จริงบน local Postgres 16 กับ 12 สถานการณ์ทดสอบ (T0-T12 รวม one-directional/regression/privacy/self-mute/spoofing/unmute) พร้อมเช็คเพิ่มเติมว่า Block+Mute พร้อมกันบนคู่เดียวกัน Block ยังคง dominant (เนื้อหาหายทุกที่ ไม่ใช่แค่ Home Feed)

Build: `flutter analyze` สะอาด ไม่มี issue

Known Issues: ไม่มี known issue ใหม่จากรอบนี้ (scope ตรงตาม Design doc ทุกข้อ ไม่มี trade-off ที่ต้องเปิดเผยเพิ่มเติมแบบ WYN-027's mention-color gap)

Handoff: AI QA & Security — ทดสอบ WYN-028 ตาม Acceptance Criteria ทั้งหมด โดยเฉพาะ regression กับ WYN-027 (คู่ที่ทั้ง Mute และ Block กันพร้อมกัน) และย้ำ AC ที่ตรงข้ามกับ WYN-027 (Follow/Like/Comment/Mention ต้อง**ไม่ถูก**บล็อกระหว่างคู่ที่ Mute กันอยู่)
