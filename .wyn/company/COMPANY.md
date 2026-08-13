# WYN AI Company

ภาพรวมองค์กร AI ที่สร้างขึ้นเพื่อช่วย Founder พัฒนา WYN จาก V0.1 ไปสู่ production

## วิสัยทัศน์ขององค์กร AI นี้

สร้างทีมพัฒนาซอฟต์แวร์ AI ภายใน repository ที่ปลอดภัย ตรวจสอบได้ (auditable) ย้อนกลับได้ (reversible) และควบคุมโดยมนุษย์ (human-controlled) เพื่อช่วย Founder สร้างผลิตภัณฑ์ WYN

## โครงสร้างทีม (6 บทบาท)

1. **AI Product Manager** — นิยาม "ควรสร้างอะไร" (WHAT)
2. **AI Design** — นิยาม "หน้าตาและพฤติกรรมควรเป็นอย่างไร" (HOW)
3. **AI Coding** — implement ตาม spec
4. **AI QA & Security** — ทดสอบและพยายาม break งานที่ implement
5. **AI Debug Engineer** — reproduce/หา root cause/fix bug ที่ QA พบ
6. **AI Deploy & DevOps** — build/deploy/verify/rollback

รายละเอียดบทบาทแต่ละตัวอยู่ที่ `.wyn/agents/*.md`

## เอกสารหลักที่ทุกบทบาทต้องอ่านก่อนเริ่มงาน

- `AGENTS.md` (root)
- `.wyn/company/COMPANY.md` (ไฟล์นี้)
- `.wyn/company/RULES.md`
- `.wyn/company/WORKFLOW.md`
- `.wyn/company/CONTEXT.md`
- `.wyn/company/DECISIONS.md`

## Founder

Founder คือ CEO, Product Owner และผู้ตัดสินใจสุดท้าย (final decision maker) ของทุกการเปลี่ยนแปลงสำคัญ ดูรายละเอียดสิทธิ์ใน `.wyn/company/RULES.md`

## สถานะปัจจุบัน

ดู `.wyn/company/PROJECT_STATUS.md` สำหรับผลตรวจสอบ repository ล่าสุด และ `.wyn/company/SETUP_COMPLETE.md` สำหรับสรุปการติดตั้งระบบนี้
