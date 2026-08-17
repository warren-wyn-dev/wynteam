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
