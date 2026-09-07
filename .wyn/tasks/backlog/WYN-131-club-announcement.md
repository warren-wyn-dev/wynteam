# Product Task — WYN-131

Status: backlog
Owner: AI Product Manager

Feature: Club Announcement (ประเภทโพสต์แยกจาก Pinned Post ทั่วไป)

Goal: ให้ Owner/Admin/Moderator สร้าง "ประกาศ" ของ Club เป็นประเภทเนื้อหาที่แยกออกจากโพสต์ทั่วไปอย่างชัดเจน มีรายการประวัติประกาศของตัวเอง แทนที่การใช้ Pinned Post (โพสต์ธรรมดา + ปักหมุด) แทนกันอยู่ตอนนี้ — ตรงกับสเปกข้อ 6 ที่ Founder ระบุ

Target User: Owner/Admin/Moderator ของ Club (สร้าง/แก้ไข/ลบประกาศ), สมาชิกทุกคน (รับประกาศ)

Problem: **ต้องพูดตรงๆ ก่อน**: ของเดิมที่มีอยู่แล้ว (Pinned Post ตาม WYN-014 + Club Re-engagement Notification ตาม WYN-116 ที่แจ้งเตือนสมาชิกเมื่อมี pin ใหม่) **ครอบคลุม 80% ของสิ่งที่สเปกข้อ 6 ต้องการอยู่แล้ว** — "โพสต์ธรรมดา + ปักหมุด + แจ้งเตือนสมาชิก" ก็คือ workflow ประกาศอยู่ในตัว มูลค่าเพิ่มที่แท้จริงของ task นี้แคบกว่าที่สเปกฟังดู มีแค่ 2 อย่าง: (1) แท็บ/รายการ "ประกาศ" แยกจาก feed โพสต์ทั่วไป ให้สมาชิกไล่ดูย้อนหลังได้ง่ายโดยไม่ต้องหาโพสต์ที่ปักหมุดปนกับโพสต์อื่น (2) แยกสิทธิ์ให้ชัดว่า "นี่คือประกาศทางการของ Club" ไม่ใช่แค่โพสต์ของสมาชิกที่บังเอิญถูกปักหมุด (ความน่าเชื่อถือ/สัญญาณภาพ)

Requirements:
- ประเภทเนื้อหาใหม่ "Announcement" แยกจาก `club_posts` ปกติ (หรือ extend `club_posts` ด้วย `type = 'announcement'` — ให้ AI Design ตัดสินใจแนวทาง schema ที่กระทบของเดิมน้อยที่สุด)
- สร้างได้เฉพาะ Owner/Admin/Moderator (สิทธิ์เดียวกับ Pin Post เดิม ไม่ต้องออกแบบ permission ใหม่)
- Edit/Delete ประกาศของตัวเอง — Owner/Admin ลบประกาศของ Moderator คนอื่นได้ (สิทธิ์เดียวกับ Delete Post เดิม)
- Announcement แสดงในแท็บ/ส่วนแยกต่างหากบน Club Page (ไม่ปนกับ feed โพสต์ปกติของแต่ละ channel) — ไม่ผูกกับ channel ใด channel หนึ่ง (เป็นระดับ Club ทั้งก้อน ต่างจาก Pinned Post ที่ผูกกับ channel ตาม WYN-127)
- แจ้งเตือนสมาชิกทุกคนทันทีที่มีประกาศใหม่ (reuse notification mechanism เดียวกับ WYN-116 — ไม่สร้างระบบแจ้งเตือนใหม่)

Acceptance Criteria:
- [ ] Owner/Admin/Moderator สร้างประกาศได้ ปรากฏในแท็บ "ประกาศ" แยกจาก feed โพสต์ปกติ
- [ ] สมาชิกทั่วไปสร้างประกาศไม่ได้ (เห็นอย่างเดียว)
- [ ] สมาชิกได้รับแจ้งเตือนเมื่อมีประกาศใหม่
- [ ] Edit/Delete ประกาศทำงานตามสิทธิ์เดียวกับ Post ปกติ

Dependencies: WYN-014 (Club Core), WYN-116 (notification mechanism), WYN-127 (Club Channels — ต้องออกแบบไม่ให้ Announcement ผูก channel ขัดกับโครงสร้างที่ WYN-127 วางไว้)

Priority: **P3 — ต่ำที่สุดในกลุ่ม Phase A** เพราะ Pinned Post + WYN-116 ครอบคลุม use case หลักไปมากแล้ว คุณค่าเพิ่มเติมคือ UX/การจัดหมวดเท่านั้น ไม่ใช่ความสามารถใหม่จริงๆ — แนะนำพิจารณาว่า "จำเป็นต้องทำแยกจริงไหม" ก่อนเข้า Design

Risks: เสี่ยง over-engineering ถ้าทำเป็นระบบใหม่เต็มรูปแบบทั้งที่ของเดิมแก้ปัญหาได้เกือบหมดแล้ว — ควรพิจารณาทางเลือกที่เบากว่า (เช่น แค่เพิ่ม UI filter "แสดงเฉพาะโพสต์ที่ปักหมุด" บน Pinned Post เดิม แทนสร้าง content type ใหม่) เป็นทางเลือกให้ Founder เทียบก่อนตัดสินใจ

Recommendation: **แนะนำให้ Founder พิจารณาทางเลือกที่เบากว่า (filter บน Pinned Post เดิม) ก่อน** แทนที่จะสร้าง content type ใหม่ทันที — ถ้า Founder ยืนยันว่าต้องการแยกจริงตามสเปก จึงค่อยเข้า Design เต็มรูปแบบ

Handoff: รอ Founder ยืนยัน priority + ทางเลือก scope (แยกเต็มรูปแบบ vs filter บนของเดิม) ก่อนส่งต่อ AI Design
