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
- อนุมัติ → **คืนสถานะทันที**: Restrict/Suspend คืนสิทธิ์ก่อนกำหนด, Ban ปลด login ได้ทันที, Remove Content กู้คืนเนื้อหาเดิม (undo soft-delete), Warning ลบ record การเตือนออก (ไม่นับเป็นประวัติ)
- ปฏิเสธ → Action เดิมคงอยู่เหมือนเดิม ผู้ใช้เห็นผลว่าอุทธรณ์ถูกปฏิเสธ พร้อมเหตุผลที่ moderator กรอก (บังคับกรอกเหตุผลตอนปฏิเสธ)

Acceptance Criteria:
- [ ] ผู้ใช้ที่ถูก Warning/Remove Content/Restrict/Suspend/Ban เห็นปุ่ม "อุทธรณ์" จากจุดที่แจ้งผล Action นั้น
- [ ] อุทธรณ์ Ban ได้แม้ login ไม่ได้ (ทดสอบจากหน้าจอ "บัญชีถูกระงับ" ตอนพยายาม login)
- [ ] กรอก Reason (บังคับ) + แนบ Evidence สูงสุด 3 รูป (ไม่บังคับ) → ส่งอุทธรณ์สำเร็จ สถานะ pending
- [ ] อุทธรณ์ action เดิมซ้ำ 2 ครั้ง → ครั้งที่ 2 ทำไม่ได้ (ปุ่มหายไปหลังส่งครั้งแรก)
- [ ] moderator เปิด tab "Appeals" ใน Moderation Queue → เห็น Reason/Evidence/Action เดิมครบ
- [ ] moderator กด "อนุมัติ" บน Appeal ของ Restrict → บัญชีคืนสิทธิ์โพสต์/comment ทันที
- [ ] moderator กด "อนุมัติ" บน Appeal ของ Ban → บัญชี login ได้ทันที
- [ ] moderator กด "อนุมัติ" บน Appeal ของ Remove Content → เนื้อหาเดิมกลับมาแสดงผลปกติ
- [ ] moderator กด "ปฏิเสธ" (ต้องกรอกเหตุผล) → Action เดิมคงอยู่ ผู้ใช้เห็นผลปฏิเสธพร้อมเหตุผล
- [ ] ทุก Appeal บันทึก Reason/Evidence/Status/Reviewer/Decision ครบตาม Master Spec ข้อ 26 ตรวจสอบผ่าน DB ได้
- [ ] Regression: WYN-029 Moderation Queue เดิม (ตรวจ Report/ดำเนินการ Action) ยังทำงานปกติหลังเพิ่ม Appeals tab

Dependencies: WYN-029 (Moderation Queue + Action — ต้องเสร็จก่อน เพราะ Appeal อ้างอิงถึง moderation action ที่มีอยู่แล้วเสมอ)

Priority: P1 — ต่อจาก WYN-029 ทันที เป็น task สุดท้ายของ Phase 1

Risks:
- **Undo ของแต่ละ Action Type ซับซ้อนไม่เท่ากัน**: Warning/Restrict/Suspend/Ban คืนสถานะตรงไปตรงมา (flag/field เดียว) แต่ **Remove Content ต้องเป็น soft-delete ตั้งแต่ WYN-029** (ไม่ hard-delete) ไม่งั้น WYN-030 จะกู้คืนไม่ได้เลย — ต้องย้อนไปยืนยันกับ AI Coding ตอนทำ WYN-029 ว่าใช้ soft-delete จริง (มีอยู่แล้วใน Requirements ของ WYN-029)
- **Evidence เป็นรูปภาพ**: ต้องมี Storage bucket ใหม่หรือ reuse policy คล้าย `drop-images` (private ต่อ appeal, เห็นได้เฉพาะผู้อุทธรณ์เองกับ moderator/admin เท่านั้น ไม่ public เหมือน avatar/drop) — ใกล้เคียง pattern `club-media` (non-public bucket) มากกว่า public bucket เดิม ๆ
- **Self-review**: moderator/admin ต้องอุทธรณ์ Action ของตัวเองไม่ได้ (เช่น moderator คนเดียวกันไปอนุมัติ Appeal ของ Action ที่ตัวเองตัดสินเอง) — รอบนี้มี moderator น้อยคนจึงไม่บังคับ separation แต่ต้อง**ห้ามอย่างน้อยไม่ให้ approve appeal ของ target ที่เป็นตัวเอง**ถ้าเผลอถูก moderate (edge case แต่ป้องกันไว้ตั้งแต่ต้นง่ายกว่าแก้ทีหลัง)
- ยังไม่มี SLA/เวลาตอบกลับ Appeal ที่บังคับในระบบ (นอก scope รอบนี้ เป็นเรื่อง operational ไม่ใช่ product requirement ทางเทคนิค)

Recommendation:
1. เริ่มทันทีหลัง WYN-029 ผ่าน QA — เป็น task สุดท้ายที่ปิด Phase 1 ให้ครบวงจร (Report → Moderation → Appeal) ตาม Master Spec ทั้งหมด
2. ต่อยอด UI เดิมของ Moderation Queue (เพิ่ม tab แทนสร้างหน้าจอใหม่) ลดงาน Design/Coding ซ้ำซ้อน
3. เมื่อ WYN-030 เสร็จ ถือว่า Phase 1 (Safety & Trust Foundation) ครบทั้ง 5 task — แนะนำให้ AI Product Manager ทวนความพร้อมของ Phase 2 (WYN Chat) อีกครั้งก่อนเริ่ม เพราะ Phase 2 มี Dependency ตรงกับ WYN-027/028 (Block/Mute)

Handoff: AI Design — ออกแบบปุ่ม "อุทธรณ์" ในทุกจุดที่แจ้งผล Action, ฟอร์มอุทธรณ์ (Reason + Evidence upload), และ Appeals tab ใน Moderation Queue screen ของ WYN-029
