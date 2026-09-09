# WYN Definition of Done

คำว่า “Done” ใช้ได้เมื่อ checklist ที่ applicable ด้านล่างครบและมี evidence จริง “Code complete”, “QA passed”, “staged” และ “released” เป็นสถานะแยกกัน

## Scope and Product

- [ ] Founder intent ถูกแปลงเป็น requirements โดยไม่ invent major feature
- [ ] priority P0/P1/P2, acceptance criteria, edge cases และ out-of-scope ชัดเจน
- [ ] scope change ได้รับ approval และบันทึกเมื่อ required
- [ ] ทุก acceptance criterion trace ไปยัง implementation/test evidence ได้

## Design and Architecture

- [ ] approved UI/UX และ technical design พร้อมก่อน implementation เมื่อ applicable
- [ ] solution เป็น simplest approach ที่ตอบ requirement และรักษา module boundaries
- [ ] mobile/responsive, accessibility และ loading/empty/error/recovery states ถูกกำหนด
- [ ] data ownership, integrity, migration, performance และ backup impacts ถูก review
- [ ] major architecture/auth/framework/security decisions มี Founder approval และ decision record

## Implementation Quality

- [ ] implementation ตรง approved scope/design/architecture และ preserve working behavior
- [ ] server-side validation/authorization ครบ; ไม่มี client-only security control
- [ ] error handling ปลอดภัยและ observable; ไม่มี secret/PII leakage
- [ ] reuse existing components/patterns และไม่มี unnecessary dependency/refactor
- [ ] author self-review diff และ relevant documentation/ADR/runbook อัปเดต

## Verification

- [ ] formatter/lint/type checks/build ที่ applicable ผ่าน
- [ ] unit/integration/E2E/regression tests ตาม risk ผ่าน และมีผลลัพธ์บันทึก
- [ ] happy paths, error/edge cases และ cross-user/direct-API abuse cases ถูกทดสอบ
- [ ] accessibility, mobile/responsive และ performance ถูกตรวจตาม impact
- [ ] bug fixes มี regression coverage เมื่อทำได้
- [ ] QA & Security ให้ผลชัดเจน; ไม่มี CRITICAL และ HIGH ถูกแก้หรือ Founder accepts risk อย่างชัดเจน

## Release Readiness

- [ ] CTO final review ผ่านและ unresolved debt/risk มี owner
- [ ] staging ใช้ reviewed artifact และ verification ผ่าน
- [ ] migration/backup/restore/rollback plan ถูกทดสอบตามความเสี่ยง
- [ ] monitoring, logging, alerts, health และ cost checks พร้อม
- [ ] Founder ให้ explicit production approval
- [ ] production deployment/smoke checks/monitoring record ครบเมื่อ release อยู่ใน scope

## Evidence and Handoff

- [ ] work item ระบุ changed files, decisions, approvals, test commands/results และ known limitations
- [ ] handoff ระบุ owner, current state, next action และ unresolved risks
- [ ] git diff ไม่มี secret, local artifact หรือ unrelated change
- [ ] branch/commit/PR/merge ปฏิบัติตาม `GIT_WORKFLOW.md`

## Release Gates Summary

| Gate | Required evidence | Blocking condition |
|---|---|---|
| Scope | Requirements, priority, acceptance criteria | Ambiguous/invented scope |
| Technical | Reviews, designs, required approvals | Unapproved controlled decision |
| Implementation | Reviewed diff, tests, docs | Broken checks or missing critical control |
| QA & Security | Test report and security findings | Any CRITICAL; unresolved/unaccepted HIGH |
| Staging | Deploy verification, monitoring, rollback evidence | Staging failure or no recovery readiness |
| Founder | Explicit production authorization | No explicit approval |
| Production | Controlled deploy and verification record | Failed health/smoke checks; unsafe operation |

ห้าม mark Done ด้วยการ waive checklist แบบเงียบ ๆ รายการที่ไม่ applicable ต้องระบุเหตุผล และ exception ที่กระทบ controlled area ต้องได้รับ Founder approval
