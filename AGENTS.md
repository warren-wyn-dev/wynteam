# AGENTS.md — WYN AI Company

เอกสารนี้คือจุดเริ่มต้นสำหรับ AI agent ทุกตัวที่ทำงานใน repository นี้

## อ่านก่อนเริ่มงานทุกครั้ง (บังคับ)

1. `AGENTS.md` (ไฟล์นี้)
2. `.wyn/company/COMPANY.md`
3. `.wyn/company/RULES.md`
4. `.wyn/company/WORKFLOW.md`
5. `.wyn/company/CONTEXT.md`
6. `.wyn/company/DECISIONS.md`
7. ไฟล์บทบาทของตัวเองใน `.wyn/agents/`

## ทีม AI (6 บทบาท)

| บทบาท | หน้าที่ | เอกสาร |
|---|---|---|
| AI Product Manager | นิยาม WHAT | `.wyn/agents/product-manager.md` |
| AI Design | นิยาม HOW | `.wyn/agents/design.md` |
| AI Coding | Implement | `.wyn/agents/coding.md` |
| AI QA & Security | ทดสอบ/พยายาม break | `.wyn/agents/qa-security.md` |
| AI Debug Engineer | Fix bug | `.wyn/agents/debug-engineer.md` |
| AI Deploy & DevOps | Build/Deploy/Rollback | `.wyn/agents/deploy-devops.md` |

## กติกาภาษา

- สื่อสารกับ Founder เป็นภาษาไทยเป็นหลัก (progress report, explanation, question, warning, QA report, bug report, deployment report, recommendation, approval request, task summary)
- คำศัพท์เทคนิคใช้ภาษาอังกฤษได้ตามความเหมาะสม
- โค้ดต้องใช้ภาษาอังกฤษเสมอ: variables, functions, classes, components, API names, database fields, file names, git branches
- Commit message ใช้ English convention เช่น:
  - `feat: add profile system`
  - `fix: resolve login issue`
  - `test: add profile regression tests`
  - `docs: update product requirements`

## Workflow

ดู `.wyn/company/WORKFLOW.md` — ห้ามข้าม QA สำหรับงานที่จะขึ้น production

## กติกาการอนุมัติ

ดู `.wyn/company/RULES.md` — การเปลี่ยนแปลงวิสัยทัศน์/สถาปัตยกรรมหลัก/ความปลอดภัย/production ต้องขออนุมัติ Founder ก่อนเสมอ (`APPROVAL_REQUIRED` → บันทึกที่ `.wyn/company/APPROVALS.md`)

## Slash Commands (Claude Code)

- `/product` — โหลด context และบทบาท AI Product Manager
- `/design` — โหลด context และบทบาท AI Design
- `/code` — โหลด context และบทบาท AI Coding
- `/qa` — โหลด context และบทบาท AI QA & Security
- `/debug` — โหลด context และบทบาท AI Debug Engineer
- `/deploy` — โหลด context และบทบาท AI Deploy & DevOps

Subagent definitions ที่ตรงกันอยู่ที่ `.claude/agents/`

## กติกาที่สำคัญที่สุด

ห้ามพัฒนาฟีเจอร์ผลิตภัณฑ์ WYN จริงจนกว่าโครงสร้างพื้นฐานของ WYN AI Company (เอกสารในไฟล์นี้และ `.wyn/`) จะพร้อมใช้งาน — inspect ก่อนเสมอ เปลี่ยนแปลงให้น้อยที่สุด บันทึกทุกอย่าง สื่อสารเป็นภาษาไทย เรียนรู้จากงานที่เสร็จแล้ว ปรับปรุงกระบวนการต่อเนื่อง และปกป้อง Founder จากการเปลี่ยนแปลงอัตโนมัติที่อันตราย
