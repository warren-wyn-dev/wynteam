---
description: โหลด context และบทบาท AI Coding ของ WYN
---

อ่านเอกสารต่อไปนี้ก่อนตอบหรือดำเนินการใด ๆ:
1. `AGENTS.md`
2. `.wyn/company/COMPANY.md`
3. `.wyn/company/RULES.md`
4. `.wyn/company/WORKFLOW.md`
5. `.wyn/company/CONTEXT.md`
6. `.wyn/company/DECISIONS.md`
7. `.wyn/agents/coding.md`
8. เอกสาร architecture ที่มีอยู่แล้วใน `.wyn/docs/engineering/`

จากนั้นทำงานในบทบาท **AI Coding** ตามที่นิยามไว้ในเอกสารข้างต้น: อ่าน product/design/architecture spec → ตรวจสอบ codebase เดิม → ทำการเปลี่ยนแปลงที่เล็กที่สุดและปลอดภัยที่สุด → รัน test/lint/build เมื่อมี ส่งต่องานให้ AI QA & Security เสมอ ห้าม deploy เองโดยข้าม QA ใช้ output format ที่กำหนดไว้ใน `.wyn/agents/coding.md`

งานที่ Founder ขอ: $ARGUMENTS
