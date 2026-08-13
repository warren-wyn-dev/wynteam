# Founder Decisions Log

เอกสารนี้บันทึกการตัดสินใจถาวรของ Founder เมื่อ Founder ให้ feedback ในลักษณะ เช่น "จำไว้", "ต่อไปให้ทำแบบนี้", "ไม่เอาแบบนี้", "เปลี่ยนวิธีทำ", "อยากให้ WYN เป็นแบบนี้" ทีม AI ต้องบันทึกไว้ที่นี่ทันทีและห้าม override โดยไม่แจ้ง Founder

## รูปแบบการบันทึก

```
### [YYYY-MM-DD] หัวข้อการตัดสินใจ
- บริบท:
- คำตัดสินใจของ Founder:
- ผลกระทบ:
- อ้างอิง (task/PR ถ้ามี):
```

## รายการการตัดสินใจ

### [2026-08-13] WYN Core Product & Target Users
- บริบท: Founder ตอบคำถามเริ่มต้นผ่านคำสั่ง `/product` เพื่อเริ่มกำหนด WYN Vision และ Tech Stack
- คำตัดสินใจของ Founder:
  - Core Product: โซเชียลมีเดียทั่วไป (general social media platform)
  - Target Users: วัยรุ่น / Gen Z
  - Platform และ Tech Stack: มอบหมายให้ AI Product Manager เสนอคำแนะนำ แล้วรอ Founder อนุมัติ
- ผลกระทบ: ใช้เป็นฐานในการร่าง Vision/Mission และคำแนะนำ Platform/Tech Stack ใน WYN-001 อัปเดตใน `.wyn/company/CONTEXT.md`
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/active/WYN-001-vision-and-tech-stack.md`

### [2026-08-13] WYN Vision/Mission และ Platform/Tech Stack — อนุมัติแล้ว
- บริบท: Founder ตอบ "ยืนยัน" ต่อร่าง Vision/Mission และคำแนะนำ Platform/Tech Stack ที่ AI Product Manager เสนอใน WYN-001
- คำตัดสินใจของ Founder:
  - อนุมัติถ้อยคำ Vision และ Mission ตามร่างทั้งหมด (ไม่มีแก้ไข)
  - อนุมัติ Platform: Mobile-first — React Native (Expo) + TypeScript
  - อนุมัติ Backend: Supabase (PostgreSQL + Auth + Storage + Realtime + Edge Functions)
- ผลกระทบ: `.wyn/company/CONTEXT.md` อัปเดตเป็นค่าสุดท้ายแล้ว WYN-001 เสร็จสมบูรณ์ AI Design และ AI Coding ใช้ข้อมูลนี้เป็นฐานอ้างอิงได้ทันที การเปลี่ยน Platform/Tech Stack ในอนาคตต้องขออนุมัติใหม่ (Major Architecture)
- อ้างอิง (task/PR ถ้ามี): `.wyn/tasks/completed/WYN-001-vision-and-tech-stack.md`
