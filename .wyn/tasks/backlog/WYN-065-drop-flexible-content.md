# Product Task — WYN-065

Status: backlog
Owner: AI Product Manager

Feature: Drop — รองรับ Text-only, Image-only, หรือ Image+Caption

Goal: ทำให้ Drop ยืดหยุ่นเหมือน Social Post ทั่วไป ไม่บังคับต้องมีรูปเสมอไป

Target User: ผู้ใช้ WYNOS ที่อยากโพสต์ข้อความล้วน (ความคิด/อัปเดตสั้นๆ) โดยไม่มีรูป

Problem: ตรวจโค้ดปัจจุบัน (`create_drop_screen.dart`, `_canShare` getter) ยืนยันว่า Drop มี 2 โหมดอยู่แล้วคือ `_ComposeMode.image` (บังคับต้องมีรูป, caption optional) และ `_ComposeMode.poll` (WYN-035, บังคับต้องมี caption เป็นคำถามโพล) — **ไม่มีโหมด "ข้อความล้วน" (text-only post ทั่วไป) เลย** ผู้ใช้ที่อยากโพสต์แค่ข้อความธรรมดาไม่มีทางทำได้ในปัจจุบัน ต้องเลือกรูปเสมอ

Requirements:
- R1. เพิ่มความสามารถโพสต์ได้ 3 แบบ: (1) รูปอย่างเดียว (2) Caption/Text อย่างเดียว (3) รูป+Caption — ไม่บังคับว่าต้องมีทั้งคู่
- R2. Validation: อนุญาตโพสต์เมื่อมีรูปอย่างเดียว หรือ caption อย่างเดียว หรือทั้งคู่ — ไม่อนุญาตเฉพาะกรณีไม่มีทั้งคู่ (ต้องมี DB-level CHECK constraint ป้องกันด้วย ไม่ใช่แค่ client-side validation เพราะ RPC เรียกตรงได้)
- R3. Composer แสดง preview ตาม content: ไม่มีรูป → Text Post ที่ออกแบบสวยงาม (ไม่ใช่กรอบว่างที่ดูเหมือนพัง), มีรูป → Image Post, มีทั้งคู่ → Image + Caption (พฤติกรรมเดิม)
- R4. เมนู "Poll" (WYN-035) ที่มีอยู่แล้วยังคงแยกเป็นโหมดของตัวเอง ไม่ปนกับโหมด text-only ใหม่นี้ — เพิ่มเป็นโหมดที่ 3 ของ mode selector เดิม ไม่รื้อ 2 โหมดเดิม

Acceptance Criteria:
- [ ] โพสต์รูปอย่างเดียวได้ (พฤติกรรมเดิม ต้องไม่มี regression)
- [ ] โพสต์ caption อย่างเดียวได้ (ไม่ต้องเลือกรูป)
- [ ] โพสต์รูป+caption ได้ (พฤติกรรมเดิม)
- [ ] โพสต์แบบไม่มีทั้งรูปและ caption ไม่ได้ — ปุ่มแชร์ disabled และ DB มี CHECK constraint กันซ้ำ
- [ ] Regression: Poll mode (WYN-035), Edit Drop (WYN-037), Draft (WYN-036) ยังทำงานถูกต้องทุกจุด

Dependencies: แก้ที่ `create_drop_screen.dart` (`_ComposeMode`, `_canShare`) และตาราง `drops` ใน `supabase/schema.sql` (เพิ่ม CHECK constraint แบบ additive-only ไม่กระทบข้อมูลเดิม) — ต้องขอ approve จาก Founder ก่อน apply เข้า production ตามกติกาที่ใช้อยู่ (schema change ต้องทดสอบ local ก่อนเสมอ)

Priority: สูง — เป็น requirement ข้อ 2 ที่ Founder ระบุชัดเจน และเป็น pattern พื้นฐานของ social platform ทั่วไปที่ WYNOS ยังขาด

Risks: DB CHECK constraint ใหม่ (`image_url is not null or caption is not null`) ต้อง verify ก่อนว่าไม่มีแถวเดิมใน production ที่จะ fail constraint นี้ (ไม่ควรมี เพราะ mode เดิมบังคับมีรูปอยู่แล้ว แต่ต้อง verify จริงก่อน apply)

Recommendation: เพิ่ม `_ComposeMode.text` ใหม่ต่อจาก `.image`/`.poll` เดิม แทนที่จะรื้อ `.image` mode ให้ caption อย่างเดียวผ่านได้ — รักษาความชัดเจนของแต่ละโหมดตาม engineering rule "ห้ามรื้อระบบเดิมโดยไม่จำเป็น"

Handoff: AI Design ออกแบบ mode selector ใหม่ (3 ปุ่ม) + หน้าตา Text Post card ใน Feed ให้ตรงกับ Design Language เดิม (Dark/Cyan #00C8FF) ก่อนส่ง AI Coding
