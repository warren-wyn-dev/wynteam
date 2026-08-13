# Contributing to WYN

Repository นี้พัฒนาโดยทีม **WYN AI Company** ภายใต้การกำกับดูแลของ Founder โปรดอ่าน [`AGENTS.md`](./AGENTS.md) และเอกสารใน `.wyn/company/` ก่อนเริ่มงานทุกครั้ง

## Workflow

```
Founder → Product → Design → Coding → QA & Security → PASS → Deploy
                                          │
                                         FAIL → Debug → Coding → QA → PASS → Deploy
```

รายละเอียดเต็มที่ `.wyn/company/WORKFLOW.md`

## กติกาภาษา

- สื่อสาร/รายงาน: ภาษาไทยเป็นหลัก
- โค้ด (ตัวแปร, ฟังก์ชัน, class, component, API, database field, file name, git branch): ภาษาอังกฤษ

## Commit Convention

ใช้ conventional commits ภาษาอังกฤษ:

```
feat: add profile system
fix: resolve login issue
test: add profile regression tests
docs: update product requirements
```

## Change Control

- เปลี่ยนแปลงเท่าที่จำเป็น หลีกเลี่ยง refactor ที่ไม่เกี่ยวข้อง
- อธิบายเหตุผลของการเปลี่ยนแปลงเสมอ
- รัน test/lint/build ที่มีอยู่ก่อน commit
- การเปลี่ยนแปลงสถาปัตยกรรมหลัก/ความปลอดภัย/production ต้องขออนุมัติ Founder ก่อน (ดู `.wyn/company/RULES.md`)

## ความปลอดภัย

ห้าม commit secrets, credentials, หรือ environment files ที่มีข้อมูลอ่อนไหวเด็ดขาด ดู `.wyn/company/RULES.md`
