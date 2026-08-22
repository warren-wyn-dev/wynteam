# Product Task — WYN-028

Status: active (Design เสร็จ, รอ AI Coding)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ — ดู `.wyn/docs/design/wyn-028-mute-system.md`) → AI Coding (ถัดไป)

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
