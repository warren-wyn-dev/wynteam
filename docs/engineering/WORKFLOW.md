# WYN Engineering Workflow

## Standard Flow

`Founder → Product Manager → CTO → Software Architect → UI/UX + Database → Full-Stack Engineer → QA & Security → CTO Final Review → Staging → Founder Approval → Production`

ขั้นตอน UI/UX และ Database ทำงานคู่ขนานได้เมื่อ boundaries ชัดเจน แต่ต้อง reconcile contracts ก่อน implementation

## Stage-by-Stage

1. **Founder Intent** — Founder ระบุ goal, constraints และ final decisions; ยังไม่ถือว่าอนุมัติ production
2. **Product Definition** — PM สร้าง requirements, P0/P1/P2 priority, acceptance criteria, edge cases และ out-of-scope list แล้วขอ clarification แทนการ invent scope
3. **CTO Triage** — CTO ระบุ technical owners, review feasibility/risks และตรวจว่ามี approval gate หรือไม่
4. **Technical Design** — Architect เสนอ simplest viable design, boundaries, security/data flow และ decision records; major architecture/auth changes ต้องรอ Founder approval
5. **Experience and Data Design** — UI/UX ระบุ flows/states/accessibility; Database ระบุ integrity/migration/ownership concerns โดยไม่เริ่ม destructive operation
6. **Implementation** — Full-Stack Engineer ทำ smallest approved change, tests และ self-review พร้อม traceability ถึง acceptance criteria
7. **QA & Security** — ทดสอบตาม risk; finding ต้องมี severity, evidence และ reproduction steps งาน FAIL ส่งกลับ implementation/architecture/product owner ที่ถูกต้อง
8. **CTO Final Review** — ตรวจ scope, technical quality, security findings, debt, operational readiness และ approval records
9. **Staging** — DevOps/SRE deploy immutable reviewed artifact, รัน smoke/regression/security verification และพิสูจน์ monitoring/rollback readiness
10. **Founder Approval** — แสดง scope, evidence, risks, staging result และ rollback plan; ต้องได้รับ explicit production approval
11. **Production** — controlled deployment, smoke checks, monitoring/cost review และ deployment record; incident/rollback เป็นไปตาม Founder authority และ runbook

## Handoff Contract

ทุก handoff ต้องมี:

- work item/owner และ approved scope
- inputs, changed artifacts และ decision links
- acceptance criteria กับ evidence ปัจจุบัน
- test/security status และ unresolved risks
- required approvals และสถานะของแต่ละ approval
- exact next action, rollback/recovery concern เมื่อเกี่ยวข้อง

ผู้รับต้อง reject handoff ที่ขาด critical evidence แทนการเติม assumption เอง

## Rework and Escalation

- Requirement ambiguity → PM → Founder เมื่อกระทบ scope/direction
- Architecture/security decision → Architect/QA → CTO → Founder หากอยู่ใน change control
- Implementation defect → Full-Stack → QA retest
- Data concern → Database Engineer; destructive production action → Founder approval
- Release/operations concern → DevOps/SRE → CTO; production decision → Founder
- CRITICAL finding หยุด release ทันที; HIGH หยุด releaseจนกว่าจะแก้หรือ Founder accepts risk อย่างชัดเจน

## Emergency Principle

Incident ไม่ยกเลิก approval, audit หรือ data-safety rules ให้ contain, preserve evidence, report impact, เสนอ safe options และรอ Founder decision สำหรับ destructive action, production rollback หรือ policy exception

## Prohibited Shortcuts

ห้าม implement ก่อน scope พร้อม, bypass server-side authorization, self-approve controlled change, skip QA/CTO review, deploy local/unreviewed artifact, equate staging success with production approval หรือ deploy/rollback production อัตโนมัติ
