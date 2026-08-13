# Approval Requests Log

เอกสารนี้บันทึกคำขออนุมัติ (`APPROVAL_REQUIRED`) ทุกครั้งที่ AI Team เสนอการเปลี่ยนแปลงในหมวดที่ต้องได้รับอนุมัติจาก Founder ก่อน (ดูรายการในหัวข้อ "อำนาจของ Founder" ที่ `.wyn/company/RULES.md`)

## รูปแบบคำขออนุมัติ

```
### APPROVAL_REQUIRED — [YYYY-MM-DD] หัวข้อ
- Proposed change:
- Reason:
- Benefits:
- Risks:
- Files affected:
- Recommendation:
- สถานะ: รออนุมัติ / อนุมัติแล้ว / ปฏิเสธ
- วันที่ตัดสินใจ:
```

## รายการคำขอ

### APPROVAL_REQUIRED — [2026-08-13] Platform & Tech Stack สำหรับ WYN V0.1
- Proposed change: กำหนด Platform เป็น **Mobile-first** (React Native + Expo, TypeScript) และ Backend เป็น **Supabase** (PostgreSQL + Auth + Storage + Realtime + Edge Functions) สำหรับ WYN V0.1 MVP
- Reason: Target Users คือ Gen Z ซึ่งใช้งานโซเชียลผ่านมือถือเป็นหลัก และ Founder ต้องการให้ AI แนะนำ stack ที่เหมาะสมกับการพัฒนา MVP ให้เร็วที่สุด
- Benefits: ลดเวลาพัฒนา backend infrastructure (auth/realtime/storage พร้อมใช้ทันที), ทีมเล็กดูแลง่าย, ใช้ TypeScript ร่วมกันได้ทั้ง frontend และ backend logic (Edge Functions), เหมาะกับการ validate product เร็ว
- Risks: Vendor lock-in กับ Supabase (มี migration path ผ่าน PostgreSQL มาตรฐานหากต้องย้ายภายหลัง), React Native อาจมีข้อจำกัดด้าน native performance สำหรับบาง feature ขั้นสูงในอนาคต (เช่น video processing หนัก ๆ)
- Files affected: `.wyn/company/CONTEXT.md` (Technology Stack, Architecture) และจะเป็นฐานอ้างอิงให้ AI Coding เมื่อเริ่ม implement จริง — ยังไม่มีการแก้ไข source code ใด ๆ ในขั้นตอนนี้
- Recommendation: อนุมัติแนวทางนี้สำหรับ V0.1 เพื่อ validate product ให้เร็วที่สุด แล้วประเมินใหม่เมื่อ WYN scale ขึ้น
- สถานะ: อนุมัติแล้ว
- วันที่ตัดสินใจ: 2026-08-13
- **หมายเหตุอัปเดต [2026-08-13]**: ส่วน Frontend Framework (React Native) ถูกแทนที่แล้วตามคำสั่งตรงของ Founder — เปลี่ยนเป็น **Flutter (Dart)** ส่วน Backend (Supabase) ยังคงเดิม ดูรายละเอียดที่ `.wyn/company/DECISIONS.md`
