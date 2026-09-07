# Product Task — WYN-135

Status: backlog
Owner: AI Product Manager

Feature: Club Channel Chat Actions — Edit Message + Pin Message + Search Message

Goal: เติมความสามารถจัดการข้อความให้ห้องแชทของ Club (WYN-128) ให้ครบเทียบเท่ากับที่วางแผนไว้สำหรับ DM (WYN-132) พร้อมเพิ่ม Search ข้อความ ซึ่งมีคุณค่าสูงกว่าใน Club Chat มาก (ห้องแชทกลุ่มมีข้อความสะสมเยอะกว่าบทสนทนา 2 คนมาก การหาข้อความเก่าจึงจำเป็นกว่า) — ตรงกับสเปกข้อ 4 (Edit Message, Pin/Unpin Message, Search Messages)

Target User: สมาชิกทุกคนของ Club (Edit ข้อความตัวเอง, ค้นหา), Owner/Admin/Moderator (Pin — สิทธิ์ moderation)

Problem: WYN-128 (ยังไม่ deploy จริง ณ ตอนที่เขียน task นี้) มีแค่ ส่งข้อความ/รูป/reply-quote/ลบโดย moderator — ไม่มี Edit, ไม่มี Pin ข้อความสำคัญในห้องแชท (ต่างจาก Pinned **Post** ที่มีอยู่แล้วซึ่งเป็นคนละกลไกกับข้อความในห้องแชท), ไม่มี Search — ห้องแชทที่มีสมาชิกเยอะและคุยกันต่อเนื่องจะมีข้อความสะสมเร็วมาก การหาข้อความเก่าด้วยการ scroll เพียงอย่างเดียวใช้งานไม่ได้จริงในทางปฏิบัติ

Requirements:

**Edit Message** — เหมือน WYN-132 ทุกประการ (แก้ข้อความ text ของตัวเองเท่านั้น, ไม่จำกัดเวลา, ต้องมี "แก้ไขแล้ว" label ถาวร, ไม่รองรับแก้ image)

**Pin Message** — **ต่างจาก DM (WYN-132) ตรงที่สิทธิ์**: จำกัดเฉพาะ **Owner/Admin/Moderator** เท่านั้น (สิทธิ์เดียวกับ Pin Post/Delete Message ที่มีอยู่แล้วใน WYN-127/128 — เป็น moderation authority ไม่ใช่สิทธิ์เท่าเทียมแบบ DM เพราะห้องแชทมีลำดับชั้นของ role อยู่แล้ว) — ปักหมุดผูกกับ **channel** เดียวกับที่ pin นั้นอยู่ (สลับ channel = เห็นชุด pinned message คนละชุด มิเรอร์ pattern ของ Pinned Post ต่อ channel ใน WYN-127)

**Search Message**
- ค้นหาข้อความในห้องแชทของ **channel เดียวที่กำลังเปิดอยู่** เท่านั้นรอบนี้ (ไม่ใช่ unified search ข้าม channel/ข้าม Club — นั่นเป็นสโคปที่ใหญ่กว่า อยู่ใน Phase B ของ roadmap แยกต่างหาก)
- ผลลัพธ์เป็นรายการ snippet เรียงตามเวลา แตะแล้ว jump ไปตำแหน่งข้อความจริงในห้องแชท (เหมือน pattern jump-to-message ของ Pin ใน WYN-132)
- **ข้อกำหนดทางเทคนิคสำหรับ Design/Coding**: ใช้ PostgreSQL full-text search (`to_tsvector`/`tsquery` + GIN index) บน `club_channel_messages.content` ไม่ใช่ `ILIKE '%...%'` ธรรมดา — ห้องแชทที่มีข้อความสะสมหลักหมื่น/แสนแถวในอนาคต ILIKE จะช้าลงเรื่อยๆ เพราะ scan เต็มตาราง

Acceptance Criteria:
- [ ] สมาชิกแก้ไขข้อความ text ของตัวเองได้ในห้องแชท Club
- [ ] Owner/Admin/Moderator ปักหมุดข้อความในห้องแชทได้ สมาชิกทั่วไปทำไม่ได้
- [ ] สลับ channel → เห็นชุดข้อความที่ปักหมุดของ channel นั้นเท่านั้น
- [ ] ค้นหาคำในห้องแชท channel ปัจจุบัน → เจอข้อความที่ตรง แตะแล้ว jump ไปตำแหน่งจริง
- [ ] ค้นหาเร็วแม้ห้องแชทมีข้อความสะสมจำนวนมาก (ใช้ full-text index ไม่ใช่ table scan)

Dependencies: **WYN-128 ต้อง deploy จริงก่อนเสมอ** (task นี้ต่อยอดตาราง `club_channel_messages` ที่ WYN-128 สร้าง — ยังไม่มีอยู่จริงบน production จนกว่า Founder จะสั่ง deploy)

Priority: P2 — blocked จนกว่า WYN-128 จะ deploy จริง (Founder เลือก "รอก่อน" ในการสนทนานี้แล้ว — ดู roadmap doc)

Risks: Search ต้องออกแบบ index ตั้งแต่ Design ไม่ใช่แก้ทีหลังตอนช้า (ระบุไว้ชัดในข้อกำหนดด้านบนแล้ว) — Pin ที่จำกัดสิทธิ์ต่างจาก DM ต้องสื่อสารให้ AI Design/Coding เข้าใจชัดว่าไม่ใช่ bug ที่ inconsistent กับ WYN-132 แต่เป็นการตัดสินใจตั้งใจ (DM = เท่าเทียม, Club = มีลำดับชั้น)

Recommendation: อนุมัติ scope ได้ แต่ **ห้ามส่งต่อ AI Design ก่อน WYN-128 deploy จริง**

Handoff: รอ (1) Founder สั่ง deploy WYN-128 และ (2) ยืนยัน priority ของ Phase A ทั้งชุด ก่อนส่งต่อ AI Design
