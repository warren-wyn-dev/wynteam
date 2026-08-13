# Product Task — WYN-001

Status: active (รอ Founder อนุมัติ Platform & Tech Stack)
Owner: AI Product Manager

Feature: กำหนด WYN Vision, Mission และ Tech Stack Foundation สำหรับ V0.1

Goal: ให้ WYN AI Company มีฐานข้อมูล product ที่ชัดเจนพอจะเริ่ม Design และ Coding ได้จริง

Target User: วัยรุ่น / Gen Z (ยืนยันโดย Founder)

Problem: `.wyn/company/CONTEXT.md` ยังเป็น UNKNOWN ทั้งหมด ทำให้ AI Design และ AI Coding ยังเริ่มงานจริงไม่ได้

Requirements:
- นิยาม Vision/Mission statement ที่สะท้อน Core Product (โซเชียลมีเดียทั่วไปสำหรับ Gen Z)
- เลือก Platform เป้าหมายสำหรับ V0.1
- เลือก Tech Stack เบื้องต้น (frontend, backend, database)
- บันทึกทุกอย่างใน `.wyn/company/CONTEXT.md` เมื่อ Founder อนุมัติแล้ว

Acceptance Criteria:
- Founder อนุมัติ Vision/Mission statement (ถ้อยคำ)
- Founder อนุมัติ Platform & Tech Stack ใน `.wyn/company/APPROVALS.md`
- `.wyn/company/CONTEXT.md` อัปเดตจาก PROPOSED เป็นค่าที่ยืนยันแล้ว

Dependencies: ไม่มี (เป็น task แรกของ WYN)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป

Risks:
- ถ้าเลือก stack ผิดทิศทางตั้งแต่ต้น อาจต้อง migrate ภายหลังเมื่อ scale (ดูรายละเอียดใน `.wyn/company/APPROVALS.md`)
- Vision ที่ยังไม่ชัดอาจทำให้ feature ที่ตามมาไม่ consistent กัน

Recommendation:

## ร่าง Vision (รอ Founder ยืนยันถ้อยคำ)
"WYN คือแพลตฟอร์มโซเชียลมีเดียที่ออกแบบมาเพื่อคนรุ่นใหม่ (Gen Z) ให้สามารถเชื่อมต่อ แสดงตัวตน และสร้างชุมชนของตัวเองได้อย่างเป็นธรรมชาติ รวดเร็ว และปลอดภัย"

## ร่าง Mission (รอ Founder ยืนยันถ้อยคำ)
"สร้างพื้นที่โซเชียลที่เรียบง่าย ตอบสนองไว และให้ความสำคัญกับความปลอดภัยและความเป็นส่วนตัวของผู้ใช้ Gen Z มากกว่าแพลตฟอร์มเดิมในตลาด"

## คำแนะนำ Platform & Tech Stack (รอ Founder อนุมัติ — ดู APPROVAL_REQUIRED เต็มใน `.wyn/company/APPROVALS.md`)
- Platform: Mobile-first — React Native (Expo) + TypeScript, เว็บเป็นเฟสถัดไป
- Backend: Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions)
- เหตุผลสรุป: Gen Z ใช้งานผ่านมือถือเป็นหลัก และ Supabase ช่วยลดเวลา build MVP ได้มาก

Handoff:
- รอ Founder ตอบกลับ 2 เรื่อง: (1) อนุมัติ/แก้ไขถ้อยคำ Vision & Mission (2) อนุมัติ/ปฏิเสธ Platform & Tech Stack ใน `.wyn/company/APPROVALS.md`
- เมื่ออนุมัติแล้ว AI Product Manager จะอัปเดต `.wyn/company/CONTEXT.md` ให้เป็นค่าสุดท้าย แล้วส่งต่อ AI Design เพื่อเริ่มออกแบบ V0.1
