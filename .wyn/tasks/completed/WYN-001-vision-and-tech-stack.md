# Product Task — WYN-001

Status: completed (Founder อนุมัติแล้วเมื่อ 2026-08-13)
Owner: AI Product Manager

> **หมายเหตุแก้ไขภายหลัง [2026-08-13]**: Frontend framework ด้านล่างถูกแทนที่แล้วจาก React Native เป็น **Flutter (Dart)** ตามคำสั่งตรงของ Founder ดูค่าล่าสุดใน `.wyn/company/CONTEXT.md` และรายละเอียดการเปลี่ยนแปลงใน `.wyn/company/DECISIONS.md`

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
- [x] Founder อนุมัติ Vision/Mission statement (ถ้อยคำ)
- [x] Founder อนุมัติ Platform & Tech Stack ใน `.wyn/company/APPROVALS.md`
- [x] `.wyn/company/CONTEXT.md` อัปเดตเป็นค่าที่ยืนยันแล้ว

Dependencies: ไม่มี (เป็น task แรกของ WYN)

Priority: สูงสุด — เป็น blocker ของทุก feature ถัดไป (ปลดล็อกแล้ว)

Risks:
- ถ้าเลือก stack ผิดทิศทางตั้งแต่ต้น อาจต้อง migrate ภายหลังเมื่อ scale (ยอมรับความเสี่ยงแล้วโดย Founder — ดู `.wyn/company/APPROVALS.md`)

Recommendation: อนุมัติแล้วตามที่เสนอ ไม่มีการแก้ไข

## Vision (อนุมัติแล้ว)
"WYN คือแพลตฟอร์มโซเชียลมีเดียที่ออกแบบมาเพื่อคนรุ่นใหม่ (Gen Z) ให้สามารถเชื่อมต่อ แสดงตัวตน และสร้างชุมชนของตัวเองได้อย่างเป็นธรรมชาติ รวดเร็ว และปลอดภัย"

## Mission (อนุมัติแล้ว)
"สร้างพื้นที่โซเชียลที่เรียบง่าย ตอบสนองไว และให้ความสำคัญกับความปลอดภัยและความเป็นส่วนตัวของผู้ใช้ Gen Z มากกว่าแพลตฟอร์มเดิมในตลาด"

## Platform & Tech Stack (อนุมัติเดิม — ดูหมายเหตุแก้ไขภายหลังด้านบน)
- Platform: Mobile-first — ~~React Native (Expo) + TypeScript~~ → **Flutter (Dart)** (เปลี่ยนเมื่อ 2026-08-13)
- Backend: Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions) — ไม่เปลี่ยนแปลง

Handoff: `.wyn/company/CONTEXT.md` อัปเดตเป็นค่าสุดท้ายแล้ว งานถัดไปคือส่งต่อ AI Design (`/design`) เพื่อเริ่มออกแบบ screen/flow แรกของ V0.1 โดยอ้างอิง Vision/Target User/Tech Stack ข้างต้น
