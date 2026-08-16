# Product Task — WYN-019

Status: backlog
Owner: AI Product Manager

Feature: Drop Feed Redesign — social feed list (ไม่ใช่ grid) + For You/Following/Latest tabs

Goal: ทำให้ Drop tab เป็น "Social Photo Feed" ตัวจริงตามที่ Founder ระบุใน spec ข้อ 2 และ 6 — หน้า scroll แบบ social media (รูป+Caption+Username+เวลา+Like/Comment/Share ครบในการ์ดเดียว) พร้อม 3 tabs (For You/Following/Latest, default For You) แทนที่ 3-column grid ปัจจุบัน

Target User: ผู้ใช้ WYN Social ที่อยากดูโพสต์ของคนอื่นแบบ browse ต่อเนื่อง (scroll feed) ไม่ใช่แค่ดู thumbnail grid

Problem: Drop tab ปัจจุบัน (WYN-005) เป็น **3-column grid** ของทุก Drop ทั้งระบบเรียงตามเวลา — ต้องแตะเข้า detail ทีละอันถึงจะเห็น caption/like/comment ครบ ไม่ใช่ scroll feed ที่เห็นทุกอย่างพร้อมกันแบบที่ Home's `HomeDropCard` แสดงอยู่แล้ว และไม่มี tab แยก For You/Following/Latest เลย — Founder ระบุชัดว่า "ห้ามนำ Drop Feed ไปแทน Home" ดังนั้นทั้งสองหน้าต้องคง distinct purpose ไว้ (Home = ทุกอย่างของ WYN ผสมกัน, Drop = เฉพาะรูป+Caption+Social)

Requirements:

R1. เปลี่ยน Drop tab จาก grid เป็น scrollable single-column list โดย **reuse `HomeDropCard` (WYN-007) ตรงๆ** ไม่สร้างการ์ดใหม่ซ้ำซ้อน (มีทุก element ที่ spec ต้องการอยู่แล้ว: รูป/caption/username/avatar/เวลา/like/comment/share/save/จำนวน)
R2. เพิ่ม TabBar 3 tab เหนือ feed: For You (default) / Following / Latest — reuse tab-bar pattern ที่มีอยู่แล้วใน `ViewProfileScreen` (WYN-013, Drop grid/Pop list/Saved tabs) และ `SearchScreen` (WYN-009, User/Drop/Pop/Club tabs)
R3. "Following" tab ต้องการ query ใหม่ใน `DropRepository` (fetch เฉพาะ Drop จากคนที่ follow อยู่ — reuse `follows` table ของ WYN-008 join เข้า `drops`) — Drop repository ยังไม่มี method นี้
R4. "For You" tab รอบแรกใช้ chronological เหมือนเดิมไปก่อน (ไม่ผูกกับ WYN-018's ranking algorithm ที่ยังไม่เริ่ม) — ปรับมาใช้ ranking formula เดียวกันภายหลังเมื่อ WYN-018 เสร็จ เพื่อความสม่ำเสมอของคำว่า "For You" ทั้งแอป
R5. "Latest" tab = chronological ล้วนๆ (เหมือน grid เดิมทุกวันนี้ แค่เปลี่ยน layout)
R6. เตรียมโครงสร้าง Location field ใน `drops` table (nullable, ไม่บังคับกรอก, ไม่แสดงผล UI รอบนี้) ตามที่ spec ข้อ 2 ระบุ "เตรียมโครงสร้างไว้สำหรับอนาคต" — schema-only, ความเสี่ยงต่ำ
R7. **คง 3-column grid เดิมไว้หรือไม่**: เสนอถามให้ Founder ตัดสินใจ — เก็บ grid ไว้เป็น sub-view (เช่นใน Profile ตัวเองอยู่แล้วผ่าน `ProfileDropGridTab`) แต่ไม่ใช่ default view ของ Drop tab อีกต่อไป หรือจะตัด grid view ออกจาก Drop tab ไปเลย (Profile ยังมี grid อยู่ดี ไม่หายไปจากระบบ)

Acceptance Criteria:
- [ ] Drop tab default เปิดที่ For You, แสดง feed แบบ scroll การ์ดเดียวต่อโพสต์ (ไม่ใช่ grid)
- [ ] สลับ Following/Latest tab ได้ ข้อมูลถูกต้องตาม tab (Following = เฉพาะคนที่ follow, Latest = ทุกคนเรียงเวลา)
- [ ] การ์ดใน Drop feed มี Like/Comment/Share/Save/แตะ profile ครบเหมือนใน Home
- [ ] แตะการ์ดเปิด `DropDetailScreen` เดิม (ไม่เปลี่ยนพฤติกรรมนี้)
- [ ] `drops` table มีคอลัมน์ location (nullable) แต่ไม่มี UI ให้กรอก/แสดงรอบนี้
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับ WYN-005/WYN-007/WYN-013

Dependencies: ไม่มี hard dependency — ทำคู่ขนานกับ WYN-017/WYN-018 ได้ (แตะคนละไฟล์เป็นหลัก ยกเว้น `HomeDropCard` ที่ทั้งสองงานจะ reuse ร่วมกัน แนะนำไม่แก้ signature ของ widget นี้พร้อมกันสองงาน)

Priority: สูง (ตรงกับ spec ข้อ 2 และ 6 โดยตรง เป็นหัวใจของคำร้องขอครั้งนี้ — Founder เน้นย้ำว่า "Drop ไม่ใช่แค่หน้าสำหรับสร้างโพสต์")

Risks: การเปลี่ยน default view ของ Drop tab จาก grid เป็น feed เป็น UX change ที่ผู้ใช้เดิม (ถ้ามี) จะสังเกตเห็นทันที — ควรยืนยันกับ Founder ว่าต้องการแทนที่ grid หรือเสริมเป็นอีก view (ดู R7)

Recommendation: เริ่มพร้อมกับ WYN-017 ได้เลย (ความเสี่ยงต่ำ-กลาง คุณค่าสูง ไม่ต้องรอ WYN-018) — ส่วน R7 (จะเก็บ grid ไว้ไหม) ควรถาม Founder ก่อนเริ่ม Design

Handoff: AI Design ตัดสินใจ R7 (เก็บ/ตัด grid) ร่วมกับ Founder ก่อน แล้วออกแบบ TabBar + reuse `HomeDropCard` ให้ชัดเจน ก่อนส่งต่อ AI Coding
