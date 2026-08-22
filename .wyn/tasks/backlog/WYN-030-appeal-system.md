# Product Task — WYN-030

Status: backlog
Owner: AI Product Manager

Feature: Appeal System

Goal: ให้ผู้ใช้ที่ถูก Moderation Action (Warning/Remove Content/Restrict/Suspend/Ban) อุทธรณ์คำตัดสินได้ และให้ moderator/admin ทบทวนคำอุทธรณ์นั้นได้จริงในหน้าจอเดียวกับ WYN-029

Target User: ผู้ใช้ที่โดน Moderation Action และเชื่อว่าคำตัดสินไม่ถูกต้อง/ไม่เป็นธรรม, moderator/admin ที่ต้องทบทวนคำอุทธรณ์

Problem: WYN-029 ทำให้ moderator ดำเนินการกับ Report ได้แล้ว แต่ยังไม่มีทางให้ผู้ใช้ที่ได้รับผลกระทบโต้แย้งได้เลย — Master Spec ข้อ 26 ระบุว่า "ผู้ใช้อุทธรณ์การตัดสินบางประเภทได้ ต้องมี: Reason, Evidence, Status, Reviewer, Decision" และ Workflow ของข้อ 25 จบท้ายด้วย "Appeal" เสมอ — เป็นความเป็นธรรมพื้นฐานที่ระบบลงโทษต้องมี ก่อนเปิด Phase 2 (Chat) ที่อาจมี moderation action เกิดถี่ขึ้น

Requirements:

**สิทธิ์การอุทธรณ์**
- อุทธรณ์ได้เฉพาะ Action ที่มีผลกระทบจริงต่อผู้ใช้: **Warning, Remove Content, Restrict, Suspend, Ban** (ไม่รวม No Action เพราะไม่มีผลกระทบให้อุทธรณ์)
- อุทธรณ์ได้ **1 ครั้งต่อ 1 moderation action** (กันสแปมอุทธรณ์ซ้ำเดิม — ปุ่ม Appeal หายไปหลังส่งแล้วจนกว่าจะมี Decision)
- Ban: อุทธรณ์ได้แม้ Login ไม่ได้ (ต้องมีทางเข้าถึงหน้า Appeal โดยไม่ต้อง login เต็มรูปแบบ — ใช้ช่องทางเดียวกับหน้าจอ "บัญชีถูกระงับ" ที่ขึ้นตอนพยายาม Login ตาม WYN-029)

**ขั้นตอนอุทธรณ์ (ฝั่งผู้ใช้)**
- จากหน้าจอที่แจ้งผล Action (notification ของ Warning, หน้าจอสถานะบัญชีของ Restrict/Suspend/Ban, หรือหน้าจอเนื้อหาที่ถูกลบ) → ปุ่ม "อุทธรณ์"
- กรอก **Reason** (เหตุผลที่คิดว่าคำตัดสินไม่ถูกต้อง, บังคับกรอก) + **Evidence** (แนบรูปภาพประกอบได้สูงสุด 3 รูป, ไม่บังคับ)
- ส่งแล้ว → สถานะ "รอตรวจสอบ" (pending) ผู้ใช้ติดตามสถานะได้จากที่เดิมที่กดอุทธรณ์

**ขั้นตอนทบทวน (ฝั่ง moderator/admin — ต่อยอด Moderation Queue ของ WYN-029)**
- เพิ่ม tab/filter "Appeals" ในหน้าจอ Moderation Queue เดิม (ไม่สร้างหน้าจอแยกใหม่ทั้งหมด) แสดง Appeal ที่ status = pending
- แต่ละ Appeal แสดง: Reason, Evidence (รูปที่แนบ), Action เดิมที่ถูกอุทธรณ์ (พร้อมเหตุผลเดิมของ moderator ตอนตัดสิน), เวลาที่อุทธรณ์
- **Reviewer ของ Appeal ต้องเป็นคนละคนกับ Reviewer ของ Action เดิมถ้าเป็นไปได้** (ถ้ามี moderator มากกว่า 1 คน) — รอบนี้ (มี moderator น้อยคน) ไม่บังคับ แต่ระบบต้องบันทึก reviewer ของ Action เดิมกับ Appeal แยกกันเพื่อให้ตรวจสอบย้อนหลังได้ว่าใครทำอะไร
- ปุ่ม Decision 2 แบบ: **อนุมัติ (Uphold ผู้ใช้ / ยกเลิก Action เดิม)** หรือ **ปฏิเสธ (คง Action เดิมไว้)**
- อนุมัติ → **คืนสถานะทันที**: Restrict/Suspend คืนสิทธิ์ก่อนกำหนด, Ban ปลด login ได้ทันที, Warning ลบ record การเตือนออก (ไม่นับเป็นประวัติ)
- อนุมัติ Appeal ของ **Remove Content** → **ล้างผลทางวินัยเท่านั้น ไม่คืนเนื้อหาเดิม**: action นั้นไม่นับเป็น strike/ประวัติการละเมิดของผู้ใช้อีกต่อไป และผู้ใช้ได้รับแจ้ง (notification) ว่าอุทธรณ์สำเร็จ — แต่ Drop/Comment/Club Post ที่ถูกลบไปแล้ว**ไม่กลับมาแสดงผล** เพราะ WYN-029's Remove Content เป็นการลบถาวรจริง (hard delete) ตามการออกแบบที่ตั้งใจไว้ตั้งแต่ต้น ไม่ใช่ soft-delete ที่กู้คืนได้ (ยืนยันกับโค้ดจริงที่ merge เข้า `main` แล้ว — ดู Risks) เนื้อหาถูกลบไปตั้งแต่จังหวะที่ moderator กด Remove Content ครั้งแรก ไม่ใช่ตอนอุทธรณ์ถูกปฏิเสธ ดังนั้นไม่มีจังหวะใดที่ "กู้คืน" เป็นไปได้ทางเทคนิคเลยแม้แต่ตอน approve appeal
- ปฏิเสธ → Action เดิมคงอยู่เหมือนเดิม ผู้ใช้เห็นผลว่าอุทธรณ์ถูกปฏิเสธ พร้อมเหตุผลที่ moderator กรอก (บังคับกรอกเหตุผลตอนปฏิเสธ)

Acceptance Criteria:
- [ ] ผู้ใช้ที่ถูก Warning/Remove Content/Restrict/Suspend/Ban เห็นปุ่ม "อุทธรณ์" จากจุดที่แจ้งผล Action นั้น
- [ ] อุทธรณ์ Ban ได้แม้ login ไม่ได้ (ทดสอบจากหน้าจอ "บัญชีถูกระงับ" ตอนพยายาม login)
- [ ] กรอก Reason (บังคับ) + แนบ Evidence สูงสุด 3 รูป (ไม่บังคับ) → ส่งอุทธรณ์สำเร็จ สถานะ pending
- [ ] อุทธรณ์ action เดิมซ้ำ 2 ครั้ง → ครั้งที่ 2 ทำไม่ได้ (ปุ่มหายไปหลังส่งครั้งแรก)
- [ ] moderator เปิด tab "Appeals" ใน Moderation Queue → เห็น Reason/Evidence/Action เดิมครบ
- [ ] moderator กด "อนุมัติ" บน Appeal ของ Restrict → บัญชีคืนสิทธิ์โพสต์/comment ทันที
- [ ] moderator กด "อนุมัติ" บน Appeal ของ Ban → บัญชี login ได้ทันที
- [ ] moderator กด "อนุมัติ" บน Appeal ของ Remove Content → action นั้นไม่นับเป็น strike/ประวัติการละเมิดของผู้ใช้อีกต่อไป และผู้ใช้ได้รับแจ้งว่าอุทธรณ์สำเร็จ **แต่เนื้อหาที่ถูกลบไม่กลับมาแสดงผล** (WYN-029's Remove Content เป็น hard delete ถาวร กู้คืนไม่ได้ — ผลลัพธ์นี้เป็นความตั้งใจตาม scope ที่ปรับแล้ว ไม่ใช่บั๊ก)
- [ ] moderator กด "ปฏิเสธ" (ต้องกรอกเหตุผล) → Action เดิมคงอยู่ ผู้ใช้เห็นผลปฏิเสธพร้อมเหตุผล
- [ ] ทุก Appeal บันทึก Reason/Evidence/Status/Reviewer/Decision ครบตาม Master Spec ข้อ 26 ตรวจสอบผ่าน DB ได้
- [ ] Regression: WYN-029 Moderation Queue เดิม (ตรวจ Report/ดำเนินการ Action) ยังทำงานปกติหลังเพิ่ม Appeals tab

Dependencies: WYN-029 (Moderation Queue + Action — ต้องเสร็จก่อน เพราะ Appeal อ้างอิงถึง moderation action ที่มีอยู่แล้วเสมอ)

Priority: P1 — ต่อจาก WYN-029 ทันที เป็น task สุดท้ายของ Phase 1

Risks:
- **[RESOLVED 2026-08-22 — AI Product Manager] Undo ของแต่ละ Action Type ซับซ้อนไม่เท่ากัน**: Warning/Restrict/Suspend/Ban คืนสถานะตรงไปตรงมา (flag/field เดียวใน `moderation_actions`/`profiles`) แต่ Remove Content เกี่ยวข้องกับข้อมูลเนื้อหาจริงที่ถูกลบไป — ความเสี่ยงเดิมที่บันทึกไว้ตอนร่าง spec รอบแรกคือ "ถ้า WYN-029 ทำ Remove Content แบบ hard-delete แทนที่จะเป็น soft-delete WYN-030 จะกู้คืนไม่ได้เลย" และระบุให้ย้อนไปยืนยันกับ AI Coding ตอน WYN-029 เสร็จ — **ยืนยันแล้วกับโค้ดจริงที่ merge เข้า `main`**: `supabase/schema.sql`'s `apply_moderation_action()` ใช้ `delete from public.drops/drop_comments/club_posts/club_post_comments where id = ...` เป็น **hard DELETE จริง ไม่มี soft-delete flag ใดๆ กู้คืนไม่ได้ทางเทคนิค** นี่เป็นการตัดสินใจเชิง scope ที่ AI Design ตั้งใจทำตอนออกแบบ WYN-029 (ดู `.wyn/docs/design/wyn-029-moderation-queue.md`'s "ตัดสินใจเชิง scope ที่สำคัญ 3 ข้อ" ข้อ 1 — เลือก reuse กลไก hard-delete เดิมที่ทุกฟีเจอร์ "ลบเนื้อหาของตัวเอง" ใช้อยู่แล้ว แทนการเพิ่ม `is_deleted` flag + SELECT-filter policy ใหม่ในทุก grid/list ที่มีอยู่ เพื่อไม่ over-invest ตาม Product's Recommendation เดิม) ซึ่งบันทึกไว้เองแล้วว่า "เป็นการตีความ HOW ภายใน WHAT ที่อนุมัติแล้ว" แต่ไม่เคยถูกนำมาขอยืนยันจาก Founder อย่างเป็นทางการใน DECISIONS.md ตามที่เขียนไว้ — WYN-029 ผ่าน QA อิสระ 2 รอบและ merge เข้า `main` เรียบร้อยแล้ว จึง **ไม่ reopen โค้ดที่ shipped แล้ว** เพื่อแก้ปัญหานี้ แต่ปรับ scope ของ WYN-030 แทน: successful appeal ของ Remove Content ล้างผลทางวินัย (strike/ประวัติ) และแจ้งผู้ใช้ แต่ไม่คืนเนื้อหาเดิม — ดู Requirements/Acceptance Criteria ด้านบนที่ปรับตามนี้แล้ว บันทึกเป็น product decision ที่ `.wyn/company/DECISIONS.md` (2026-08-22)
- **ผู้ใช้อาจรู้สึกว่า "ชนะอุทธรณ์แต่ไม่ได้อะไรคืน" สำหรับ Remove Content**: ต่างจาก 4 action type อื่นที่ approve แล้วเห็นผลจับต้องได้ทันที (login ได้/โพสต์ได้อีกครั้ง) — Design ต้องสื่อสารผลลัพธ์ของการ approve ให้ตรงไปตรงมาว่า "การละเมิดถูกล้างออกจากประวัติบัญชีแล้ว" ไม่ใช้ถ้อยคำที่สื่อว่าเนื้อหาจะกลับมา (ดู Handoff)
- **Evidence เป็นรูปภาพ**: ต้องมี Storage bucket ใหม่หรือ reuse policy คล้าย `drop-images` (private ต่อ appeal, เห็นได้เฉพาะผู้อุทธรณ์เองกับ moderator/admin เท่านั้น ไม่ public เหมือน avatar/drop) — ใกล้เคียง pattern `club-media` (non-public bucket) มากกว่า public bucket เดิม ๆ
- **Self-review**: moderator/admin ต้องอุทธรณ์ Action ของตัวเองไม่ได้ (เช่น moderator คนเดียวกันไปอนุมัติ Appeal ของ Action ที่ตัวเองตัดสินเอง) — รอบนี้มี moderator น้อยคนจึงไม่บังคับ separation แต่ต้อง**ห้ามอย่างน้อยไม่ให้ approve appeal ของ target ที่เป็นตัวเอง**ถ้าเผลอถูก moderate (edge case แต่ป้องกันไว้ตั้งแต่ต้นง่ายกว่าแก้ทีหลัง)
- ยังไม่มี SLA/เวลาตอบกลับ Appeal ที่บังคับในระบบ (นอก scope รอบนี้ เป็นเรื่อง operational ไม่ใช่ product requirement ทางเทคนิค)

Recommendation:
1. เริ่มทันทีหลัง WYN-029 ผ่าน QA — เป็น task สุดท้ายที่ปิด Phase 1 ให้ครบวงจร (Report → Moderation → Appeal) ตาม Master Spec ทั้งหมด
2. ต่อยอด UI เดิมของ Moderation Queue (เพิ่ม tab แทนสร้างหน้าจอใหม่) ลดงาน Design/Coding ซ้ำซ้อน
3. เมื่อ WYN-030 เสร็จ ถือว่า Phase 1 (Safety & Trust Foundation) ครบทั้ง 5 task — แนะนำให้ AI Product Manager ทวนความพร้อมของ Phase 2 (WYN Chat) อีกครั้งก่อนเริ่ม เพราะ Phase 2 มี Dependency ตรงกับ WYN-027/028 (Block/Mute)
4. **ข้อเสนอสำหรับอนาคต (นอกขอบเขต WYN-030 นี้)**: เมื่อ WYN Admin (Phase 7) เริ่มพัฒนาจริง แนะนำให้พิจารณา task ปรับปรุง WYN-029 ให้ Remove Content เป็น soft-delete จริง (เช่น `is_removed` flag + SELECT-filter แทน hard DELETE) เพื่อให้ appeal ในอนาคตคืนเนื้อหาเดิมได้จริง — ตอนนั้นมี WYN Admin เป็นเครื่องมือกลางที่ต้องแตะ grid/list หลายจุดอยู่แล้ว ต้นทุนของการเพิ่ม filter จะต่ำกว่าตอนนี้มาก ไม่ใช่เรื่องเร่งด่วนของ Phase 1 — **ไม่ scope เข้า WYN-030 นี้**

Handoff: AI Design — ออกแบบปุ่ม "อุทธรณ์" ในทุกจุดที่แจ้งผล Action, ฟอร์มอุทธรณ์ (Reason + Evidence upload), และ Appeals tab ใน Moderation Queue screen ของ WYN-029 — **สำหรับผลลัพธ์ของการ approve Appeal ของ Remove Content โดยเฉพาะ**: ข้อความแจ้งผล (notification/หน้าจอสถานะ) ต้องสื่อสารตรงไปตรงมาว่า "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว การละเมิดนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว" หรือทำนองเดียวกัน **ห้ามใช้ถ้อยคำที่สื่อว่าเนื้อหาจะกลับมาแสดงผล** (เช่น "โพสต์ของคุณถูกกู้คืนแล้ว") เพราะไม่เป็นความจริง — เนื้อหาเดิม (รูป/ข้อความเต็ม) ถูกลบถาวรไปแล้วตั้งแต่ตอน moderator ดำเนินการครั้งแรก ไม่มีทางกู้คืนได้จริงในระบบปัจจุบัน (ดู Risks) พิจารณาได้ว่าจะโชว์แคปชัน/ข้อความเดิมที่ผู้ใช้กรอกตอนยื่นอุทธรณ์ (Reason ของ Appeal เอง ซึ่งเก็บอยู่แล้วตาม Requirements) ประกอบหน้าจอผลลัพธ์เพื่อให้บริบทครบถ้วนได้ แต่ **ห้ามเพิ่มกลไกใหม่ใดๆ ที่ต้อง snapshot/สำเนาเนื้อหาเดิม (แคปชันจริงของ Drop/Comment/Club Post ที่ถูกลบ) ไว้ตอนลบ** เพราะนั่นจะเท่ากับสร้าง undo-infrastructure แบบใหม่ซ้อนเข้าไปในโค้ด WYN-029 ที่ merge แล้ว ซึ่งอยู่นอกขอบเขตของ WYN-030 (ดู Recommendation ข้อ 4 สำหรับแนวทางระยะยาว)

---

## Design Output (2026-08-22)

ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-030-appeal-system.md` สรุปสั้น:

- **แนวทาง**: ต่อยอด `ModerationQueueScreen` เดิม (เพิ่ม tab "อุทธรณ์" ข้างๆ tab "รายงาน" ที่มีอยู่แล้ว, ไม่สร้างหน้าจอแยกใหม่ทั้งหมด) + ฟอร์มอุทธรณ์เดียว (`AppealFormScreen`) ใช้ร่วมกันทั้ง 5 action type + reuse pattern ที่มีอยู่แล้วเกือบทั้งหมด (`ReportSheet`/`ModerationActionSheet`'s bottom-sheet shape, `CreateClubPostScreen`'s multi-image picker สำหรับ Evidence สูงสุด 3 รูป, `club-media`'s private-bucket + signed-URL pattern สำหรับ `appeal-evidence` bucket ใหม่)
- **กลไกเดียวสำหรับ "ล้างผลทางวินัย" ทั้ง 5 action type**: เพิ่ม `moderation_actions.overturned_at` — approve appeal set ค่านี้ แล้วให้ `is_posting_blocked()`/`get_my_moderation_status()`'s existence-check ของ restrict/suspend/ban เพิ่มเงื่อนไข `and overturned_at is null` (ไม่แตะ `expires_at` เลย) — Warning/Remove Content ใช้ column เดียวกันเป็นสัญลักษณ์ "ไม่นับประวัติ" แม้ยังไม่มีฟีเจอร์นับ strike จริงตอนนี้
- **3 จุดเข้าอุทธรณ์**: (1) `RestrictionBanner` เพิ่มปุ่ม/สถานะแบบ optional param (backward-compatible) (2) `AccountRestrictedScreen` เพิ่มปุ่มจริงแทนบรรทัด "อุทธรณ์ยังไม่เปิดใช้งาน" เดิมของ Ban — **ต้องเลื่อนจังหวะ `signOut()` ของ `AuthGate` ออกไปจนกว่าผู้ใช้จะออกจากหน้านี้** เพื่อให้ session ยัง valid พอเรียก `submit_appeal()` ได้แม้ Ban/Suspend (นี่คือจุดตัดสินใจที่สำคัญที่สุดของงานนี้ — อธิบายความเสี่ยง/เหตุผลละเอียดที่ Screen 3 ของ design doc) (3) `MyModerationActionScreen` ใหม่ — ปลายทางเดียวของ notification 4 ประเภท (`moderation_warning`/`moderation_content_removed`/`appeal_approved`/`appeal_rejected`) แทนที่จะแยกหน้า
- **ฝั่ง moderator**: `AppealDetailScreen`+`AppealDecisionSheet` ใหม่ (reuse โครง `ModerationReportDetailScreen`/`ModerationActionSheet` เป๊ะ) — Appeal row ใน Queue reuse `ModerationRepository.fetchTargetSummary()` เดิมตรงๆ ผ่าน `moderation_actions.report_id` ไม่ duplicate ข้อมูล target ใหม่
- **Self-review guard**: ตัดสินใจบล็อก **ทั้ง Approve และ Reject** (เกินกว่าขั้นต่ำที่ Requirement เขียนไว้) ที่ **ทั้ง UI (ซ่อนปุ่ม) และ DB (`decide_appeal()` raise exception)** พร้อมกัน — DB-level คือ boundary จริงตามบทเรียนที่โปรเจกต์นี้เจอซ้ำมาแล้ว 2 ครั้ง (WYN-027/WYN-029)
- **Actor-identity protection ครั้งที่ 3**: `appeal_approved`/`appeal_rejected` notification ต้องมี `actor_id = null` เสมอตั้งแต่ insert แรก (ไม่ต้องแก้ทีหลังแบบ WYN-029) — reviewer ตัวจริงบันทึกเฉพาะที่ `appeals.reviewer_id` ที่ ordinary user ไม่มีสิทธิ์ SELECT เห็นเลย
- **Remove Content ถ้อยคำ**: "อุทธรณ์ของคุณได้รับการอนุมัติแล้ว การละเมิดนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว" ตรงตาม Handoff เป๊ะ ไม่มีคำใดสื่อว่าเนื้อหากลับมา ไม่มีกลไก snapshot เนื้อหาเดิมใดๆ เพิ่มเข้ามา
- **3 จุดแนะนำให้ Coding ยืนยันสั้นๆ กับ Founder ก่อนเริ่ม** (ไม่ใช่ Founder-authority ตาม RULES.md — ไม่แตะวิสัยทัศน์/สถาปัตยกรรมหลัก/ความปลอดภัย/การยืนยันตัวตน/โครงสร้าง DB แบบทำลายล้างเลย): การเลื่อนจังหวะ `signOut()`, self-review บล็อกทั้ง 2 ปุ่ม, การโชว์ "ผู้ตัดสินใจเดิม" ให้ moderator ที่พิจารณาอุทธรณ์เห็น

Handoff: AI Coding — เริ่มจาก data layer ตามลำดับใน design doc's Handoff section: (1) `moderation_actions.overturned_at` + แก้ existence-check เดิม, (2) `notifications` เพิ่ม 2 คอลัมน์ (`moderation_action_id`/`moderation_action_type`) + แก้ 2 insert site เดิมของ `apply_moderation_action()`, (3) `appeals` table + RLS, (4) `appeal-evidence` storage bucket + 2 policy, (5) `submit_appeal()` RPC, (6) `decide_appeal()` RPC (self-review guard + `actor_id = null` เสมอ), (7) `get_my_moderation_status()` ขยาย 6 คอลัมน์ใหม่, (8) `get_my_moderation_action()` RPC ใหม่, (9) `NotificationType`/`WynNotification`/`NotificationListScreen` ขยาย 2 type ใหม่ — แล้วค่อยเข้า UI (10) `AppealFormScreen` → 3 entry point → `ModerationQueueScreen` tab ใหม่ → `AppealDetailScreen`/`AppealDecisionSheet`/`EvidenceImageViewer`
