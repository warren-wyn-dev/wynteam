# Product Task — WYN-026

Status: backlog
Owner: AI Product Manager

Feature: User Safety — Block / Mute / Report (Drop + Profile)

Goal: WYN Vision ระบุชัดว่าเป็น platform สำหรับ Gen Z ที่ "ให้ความสำคัญกับความปลอดภัยและความเป็นส่วนตัวมากกว่าแพลตฟอร์มเดิม" (CONTEXT.md) แต่ตอนนี้ **ไม่มีระบบ Block/Mute/Report ผู้ใช้เลยแม้แต่จุดเดียว** ในทั้งแอป (มีแค่ role-based moderation ภายใน Club เท่านั้น) — เป็นช่องว่าง safety ที่สำคัญที่สุดที่ master prompt ระบุไว้ (More Menu section)

Target User: ผู้ใช้ WYN ทุกคน โดยเฉพาะกลุ่มเป้าหมาย Gen Z ที่อ่อนไหวต่อ harassment/unwanted contact

Problem: ผู้ใช้ที่โดนกวนใจ/สแปมจาก user อื่นไม่มีทางป้องกันตัวเองในแอปได้เลยนอกจากปิดแอป — ไม่มี Block (ซ่อนเนื้อหา/ป้องกันการติดต่อ), ไม่มี Mute (ซ่อนแบบผู้ถูก mute ไม่รู้ตัว), ไม่มี Report (แจ้ง moderator)

Requirements:

R1. **Schema ใหม่**: ตาราง `user_blocks` (blocker_id, blocked_id, created_at, PK คู่) และ `user_mutes` (muter_id, muted_id, created_at, PK คู่) — mirror `follows` table pattern (self-block/self-mute กันสองชั้นแบบเดียวกับ self-follow ใน WYN-008), RLS: เห็น/แก้ได้เฉพาะแถวของตัวเอง (blocker_id/muter_id = auth.uid())
R2. **ตาราง `reports`**: (id, reporter_id, target_type enum('drop','user','comment'), target_id, reason, created_at, status default 'pending') — insert ได้จากผู้ใช้ authenticated ทุกคน (rate-limit เชิง logic ถ้าเป็นไปได้ เช่น 1 report ต่อ target ต่อ user), select/update สงวนไว้สำหรับ future moderator role (ยังไม่ต้องสร้างหน้า moderator ใน task นี้ — เก็บ record ไว้ก่อน)
R3. **Effect ของ Block**: ผู้ใช้ที่ block กัน (ทิศทางใดก็ตาม) ต้อง**มองไม่เห็นเนื้อหาของกันและกัน** — กรองออกจาก Home feed/Drop feed/Search/Trending/Comment/Notification ทุกจุดที่ query เนื้อหา (ต้องตรวจสอบ query point ทุกจุดที่มีอยู่แล้ว ไม่ใช่แค่จุดเดียว — เป็นความเสี่ยง privacy สูงถ้าทำไม่ครบ) และห้าม follow กันได้อีกถ้ายัง block อยู่ (ถ้ามี follow เดิมอยู่ก่อน block ต้อง auto-unfollow ทั้งสองทิศทาง)
R4. **Effect ของ Mute**: ต่างจาก Block ตรงที่ผู้ถูก mute ไม่รู้ตัว และเนื้อหาของผู้ถูก mute แค่ถูกซ่อนจาก Feed ของผู้ mute เท่านั้น (ทิศทางเดียว) — ยังเห็น/ติดต่อกันได้ตามปกติในจุดอื่น (เช่น comment คนอื่นยังเห็น)
R5. **More Menu**: เพิ่มเมนู "..." (more_vert) บนการ์ด Drop และหน้า Profile คนอื่น — ตัวเลือก: Report, Block, Mute (Drop card เพิ่ม Report/Not Interested; Profile คนอื่นเพิ่ม Block/Mute/Report) — **"Not Interested" รอบนี้ทำแค่ signal เก็บลง `reports`-เทียบเคียงหรือตารางแยกเล็กๆ ยังไม่ต้องเชื่อมเข้า ranking algorithm จริง (WYN-018 ranking ยังไม่มี infra สำหรับ per-user negative-signal weighting) — บันทึกเป็น foundation only ตามกติกาห้าม Fake Functionality**
R6. Profile ตัวเอง: ไม่มี More Menu (Block/Mute/Report ตัวเองไม่มีความหมาย)

Acceptance Criteria:
- [ ] Block ผู้ใช้ A จากโปรไฟล์ A → เนื้อหาของ A หายจาก Home/Drop feed/Search ของผู้ block ทันที และในทางกลับกัน (A ก็มองไม่เห็นเนื้อหาของผู้ block เช่นกัน)
- [ ] Follow relationship เดิม (ถ้ามี) ถูกยกเลิกอัตโนมัติทั้งสองทิศทางเมื่อ Block
- [ ] Mute ผู้ใช้ B → เนื้อหาของ B หายจาก Feed ของผู้ mute เท่านั้น ผู้ถูก mute ไม่เห็นการเปลี่ยนแปลงใดๆ ในแอปของตัวเอง
- [ ] Report Drop/User → บันทึกลง `reports` สำเร็จ พร้อม feedback ให้ผู้ใช้ว่า "ส่งรายงานแล้ว" (ของจริง ไม่ fake)
- [ ] Unblock/Unmute ทำได้จากรายการที่จัดการได้ (เช่น หน้า Settings หรือ list ผู้ถูก block/mute — ให้ Design ตัดสินใจตำแหน่ง)
- [ ] RLS ของทั้ง 3 ตารางใหม่ผ่าน QA (ทดสอบจริงกับ Postgres ไม่ใช่แค่อ่าน SQL) — โดยเฉพาะยืนยันว่า filter การมองเห็นครบทุก query point ที่มีอยู่จริงในระบบ (Home/Drop/Search/Comment/Notification)
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression

Dependencies: WYN-008 (follow — pattern self-relationship อ้างอิง), WYN-007/009/017/018 (จุดที่ต้อง filter เนื้อหา)

Priority: สูง — ตรงกับ WYN Vision (safety สำหรับ Gen Z) โดยตรง แต่ทำหลัง WYN-024/025 เพราะ scope กว้างกว่า (แตะ query point หลายจุด ต้องมั่นใจว่า WYN-024's multi-image query ก็ต้อง filter block ด้วยเหมือนกัน)

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Filter การมองเห็นไม่ครบทุก query point → privacy leak จริง | **สูง** | ทำ checklist ทุกจุดที่ query เนื้อหาข้าม user ก่อนเริ่ม Coding (Home feed view, Drop feed, Search, Trending, Comment list, Notification, Profile), QA ต้องทดสอบทุกจุดแยกกัน ไม่เชื่อแค่จุดเดียว |
| R2 | Mute/Block ปนกันจนทำ effectผิด (เช่น Mute ดันซ่อนแบบ Block) | กลาง | เขียน test แยกชัดเจนระหว่างสอง table/behavior |
| R3 | Report spam (คนเดียว report ซ้ำๆ) | ต่ำ | unique constraint (reporter_id, target_type, target_id) กันซ้ำ ไม่ต้องทำ rate-limit ซับซ้อนเกินจำเป็นรอบแรก |

Recommendation: ทำหลัง WYN-024/025 เพราะ scope กว้างกว่าและต้องแก้ query หลายจุดที่เพิ่งเปลี่ยนจาก WYN-024 (เช่น `drop_images` query ใหม่ก็ต้อง apply block-filter ด้วย) — ทำตอนที่ query point นิ่งแล้วจะเสี่ยงน้อยกว่า

Handoff: ส่งต่อ AI Design เพื่อออกแบบ More Menu UI + ตำแหน่งหน้าจัดการ Block/Mute list แล้วส่งต่อ AI Coding พร้อม checklist query point ที่ต้อง filter ครบทุกจุด

## Design เสร็จแล้ว (AI Design) — ดูฉบับเต็มที่ `.wyn/docs/design/wyn-026-user-safety-block-mute-report.md`

สรุปการตัดสินใจหลัก:

1. **แยกกลไก filter ของ Block กับ Mute เด็ดขาด** (ป้องกัน Risk R2 "Mute/Block ปนกัน" ที่ระดับสถาปัตยกรรม ไม่ใช่แค่ตั้งใจไม่พลาด): Block ใช้ **RLS ของตารางเนื้อหาต้นทางโดยตรง** (`drops`/`pops`/`drop_comments`/`pop_comments`/`notifications`/`profiles`) ผ่านฟังก์ชัน `public.is_blocked(a, b)` (security definer, mirror pattern `club_role()` ของ WYN-014) ส่วน Mute ใช้ **filter เฉพาะระดับ "ฟีด" เท่านั้น** (SQL ใน view `home_feed` + exclude-step ใน 4 method ของ Dart) — ห้ามใช้ RLS ตารางเดียวกับ Block เพราะจะ over-apply ไปโดน Profile grid/Search ซึ่งผิด R4
2. **Checklist ครบ 26 query point ใน 8 ไฟล์** แบ่งเป็น 4 กลุ่ม: (A) 5 ตารางที่แก้ policy ครั้งเดียวแล้ว auto-cover 15 method รวม `home_feed`/`saved_feed` เพราะทั้งสอง view เป็น `security_invoker = true` อยู่แล้ว (ไม่ต้องแตะ Dart เลยสำหรับ Block), (B) `profiles` ต้องใช้ policy แบบไม่สมมาตร (ฝ่าย blocker ยังเห็น profile ฝ่ายที่ถูก block ได้ เพื่อให้หน้าจัดการ Block list ใช้งานได้) พร้อมผลข้างเคียงที่ต้องแก้ตรงๆ ใน `FollowRepository` (กรอง embedded-profile ที่เป็น null ทิ้ง), (C) `club_posts`/`club_post_comments` เป็นส่วนขยายแนะนำแต่ไม่บังคับ (เกิน literal AC), (D) Mute ต้องแก้เฉพาะ `home_feed` view SQL + 4 method ที่เป็นฟีดจริง (`DropRepository.fetchFeed/fetchFollowingFeed/fetchRankedFeed`, `PopRepository.fetchFeed`) และห้ามแตะ `fetchByAuthor`/`searchByCaption`/`fetchById`/`fetchComments` เด็ดขาด
3. **Auto-unfollow เมื่อ Block ใช้ DB trigger** (`user_blocks_auto_unfollow`, AFTER INSERT บน `user_blocks`, ลบ `follows` ทั้งสองทิศ) ไม่ใช่ client เรียกซ้อน — เหตุผลเดียวกับ notification triggers เดิม (การันตีทำงานทุก code path ไม่พึ่งวินัย caller) พร้อมแก้ `follows`' insert policy กัน follow กันใหม่ระหว่าง block
4. **แก้ gap ในสเปกเดิม**: `reports.target_type` เพิ่ม `'pop'` เข้า enum (สเปกเดิมมีแค่ `'drop','user','comment'` ทั้งที่ Pop เป็นเนื้อหาสาธารณะเท่าเทียม Drop) และเพิ่ม More Menu ให้ Pop clip ด้วย (Screen 2 — ส่วนขยายเกิน literal R5 ที่เขียนถึงแค่ "การ์ด Drop" พร้อมเหตุผลชัดเจนและบอกไว้ตรงๆ ว่าตัดออกจาก scope ได้ถ้า Founder ไม่ต้องการ)
5. **"ไม่สนใจ" (Not Interested) ใช้ตารางแยก** `content_not_interested` (ไม่ใช่ overload `reports`) mirror shape ของ `saves` — เพราะ moderation queue กับ personal preference signal คนละโมเดลข้อมูล/RLS กันโดยธรรมชาติ
6. **หน้าจัดการ Block/Mute list** (`SafetyListScreen`, mirror `FollowListScreen` พารามิเตอร์เดียว) เข้าถึงผ่านไอคอนใหม่ใน `ViewProfileScreen` ของตัวเอง (ข้างปุ่ม logout) — **ไม่สร้างหน้า Settings ใหม่** เพราะแอปยังไม่มีโครงสร้าง Settings เลย (เพิ่ม scope เกินจำเป็น) ย้ายเข้า Settings ได้ทีหลังโดยไม่กระทบหน้านี้เอง

ส่งต่อ AI Coding พร้อม checklist เต็มในเอกสาร Design (ส่วนที่ 1.3) เป็นข้อบังคับก่อนส่ง QA
