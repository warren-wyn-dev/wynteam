# WYN Context / Knowledge Base

> เอกสารนี้คือ source of truth เกี่ยวกับ WYN โปรดอัปเดตทุกครั้งที่มีข้อมูลใหม่ที่ยืนยันแล้วจาก Founder หรือจาก repository ห้ามเดาหรือสมมติข้อมูลที่ไม่ทราบแน่ชัด — ให้ระบุ `UNKNOWN`

- **WYN Vision**: WYN คือแพลตฟอร์มโซเชียลมีเดียที่ออกแบบมาเพื่อคนรุ่นใหม่ (Gen Z) ให้สามารถเชื่อมต่อ แสดงตัวตน และสร้างชุมชนของตัวเองได้อย่างเป็นธรรมชาติ รวดเร็ว และปลอดภัย (ยืนยันโดย Founder เมื่อ 2026-08-13)
- **WYN Mission**: สร้างพื้นที่โซเชียลที่เรียบง่าย ตอบสนองไว และให้ความสำคัญกับความปลอดภัยและความเป็นส่วนตัวของผู้ใช้ Gen Z มากกว่าแพลตฟอร์มเดิมในตลาด (ยืนยันโดย Founder เมื่อ 2026-08-13)
- **Target Users**: วัยรุ่น / Gen Z (ยืนยันโดย Founder เมื่อ 2026-08-13 ผ่าน `/product`)
- **Core Product**: โซเชียลมีเดียทั่วไป (general social media platform) สำหรับกลุ่ม Gen Z (ยืนยันโดย Founder เมื่อ 2026-08-13)
- **Current Version**: UNKNOWN (repository มีเพียงเอกสาร WYN AI Company และ product foundation ยังไม่มี source code หรือ version marker)
- **Current Features**: UNKNOWN (ยังไม่มี source code ใน repository)
- **Future Features**: UNKNOWN — รอ backlog ถัดไปจาก AI Product Manager
- **Design Principles**: UNKNOWN (ยังไม่มี design system ใน repository — เป็นงานถัดไปของ AI Design)
- **Technology Stack**: Mobile-first — **Flutter (Dart)** สำหรับ frontend (แทนที่ React Native เดิม); Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions) สำหรับ backend ใช้ผ่าน `supabase_flutter` package (ระบุโดย Founder ตรงเมื่อ 2026-08-13 ดู `.wyn/company/DECISIONS.md`)
- **Architecture**: Mobile app (Flutter, ภาษา Dart) เรียกใช้ Supabase โดยตรงสำหรับ Auth/Database/Storage/Realtime ผ่าน `supabase_flutter` และใช้ Supabase Edge Functions สำหรับ backend logic ที่ต้องการความปลอดภัยเพิ่มเติม เว็บแอปเป็นเฟสถัดไป (ยังไม่กำหนดรายละเอียด)
- **Business Rules**: UNKNOWN

## หมายเหตุ

ฟิลด์ที่ยังเป็น `UNKNOWN` จะถูกอัปเดตเป็นค่าจริงเมื่อ Founder ให้ข้อมูลหรืออนุมัติ ห้ามเดาหรือสมมติข้อมูลที่ยังไม่ได้รับการยืนยัน — ให้คงสถานะ `UNKNOWN` ไว้จนกว่าจะมีการยืนยันจริง

เมื่อ Founder ให้ข้อมูลเกี่ยวกับหัวข้อใดด้านบน ให้ AI Product Manager เป็นผู้ปรับปรุงไฟล์นี้ และบันทึกการตัดสินใจถาวรที่เกี่ยวข้องไว้ที่ `.wyn/company/DECISIONS.md` ด้วย
