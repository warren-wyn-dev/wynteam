# Product Task — WYN-022

Status: backlog
Owner: AI Product Manager

Feature: Comment Reply (nested reply แบบชั้นเดียว)

Goal: เพิ่ม "Reply Comment" ตามที่ spec ข้อ 5 ระบุไว้เป็นหนึ่งใน Post Interaction ที่ต้องรองรับ — ปัจจุบันมีแค่ comment แบบ flat (ไม่มี reply)

Target User: ผู้ใช้ WYN Social ที่คุยกันในคอมเมนต์ (reply ตรงถึงคนที่คอมเมนต์ก่อนหน้า)

Problem: ระบบ comment ปัจจุบัน (Drop/Pop/Club post ทั้งหมด) เป็น flat list — มี Like Comment และลบ Comment ของตัวเองอยู่แล้ว (WYN-005/006/014) แต่ไม่มีทาง reply ตรงถึง comment คนอื่น

Requirements:

R1. เพิ่มคอลัมน์ `parent_comment_id` (nullable, self-referencing FK) ให้ `drop_comments`/`pop_comments`/`club_post_comments` ทั้งสามตาราง — จำกัดความลึกแค่ 1 ชั้น (reply-to-top-level-comment เท่านั้น ห้าม reply-to-reply) เพื่อกัน UI ซับซ้อนเกินจำเป็นและ query ง่ายกว่า
R2. UI: ปุ่ม "ตอบกลับ" ใต้แต่ละ comment ระดับบนสุด — reply แสดงเยื้องเข้า (indent) หนึ่งระดับใต้ comment ต้นทาง ไม่ทำ threading ลึกกว่านั้น
R3. Reply นับรวมใน comment count เดิม (ไม่แยก counter) เพื่อไม่กระทบ UI ที่แสดง "จำนวน Comment" อยู่แล้วทุกจุด (Home/Drop/Club card)
R4. Reply ใช้ RLS/Like/Delete pattern เดียวกับ comment เดิมทุกอย่าง (owner ลบของตัวเองได้, like ได้เหมือนกัน) — ไม่สร้าง permission model ใหม่

Acceptance Criteria:
- [ ] กด "ตอบกลับ" ใต้ comment ระดับบนสุด สร้าง reply ที่ผูกกับ comment นั้นถูกต้อง
- [ ] Reply แสดงเยื้องใต้ comment ต้นทาง ไม่ปนกับ comment อื่น
- [ ] ไม่มีทาง reply ต่อ reply (UI ไม่มีปุ่มตอบกลับใต้ reply)
- [ ] จำนวน Comment ที่แสดงบนการ์ด (Home/Drop/Club) นับรวม reply ถูกต้อง
- [ ] Like/ลบ reply ทำงานเหมือน comment ปกติ (reuse permission เดิม)
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับ comment เดิมทั้ง Drop/Pop/Club

Dependencies: ไม่มี — ทำอิสระจากงานอื่นในกลุ่มนี้ได้เลย เพราะแตะเฉพาะ comment schema/UI

Priority: ต่ำ-กลาง (อยู่ใน requirement list ของ spec แต่ไม่ใช่หัวใจของ "Feed & Club Update" เท่า Home/Drop restructure — เหมาะเป็น fast-follow)

Risks: ความเสี่ยงต่ำ — เป็นการเพิ่ม column/UI แบบ additive ไม่กระทบ comment เดิมที่มี `parent_comment_id = null` เสมอ

Recommendation: ทำเป็นลำดับท้ายๆ ของกลุ่มนี้ เพราะเป็น self-contained เล็กสุด ทำเมื่อไหร่ก็ได้ไม่กระทบงานอื่น — เหมาะมอบให้ Coding แทรกระหว่างรอ Design ของงานใหญ่กว่า (WYN-018) ได้

Handoff: AI Design ออกแบบ UI ปุ่มตอบกลับ + indent style สั้นๆ (ไม่ซับซ้อน) ก่อนส่งต่อ AI Coding
