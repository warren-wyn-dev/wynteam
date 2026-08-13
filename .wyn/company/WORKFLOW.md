# WYN Development Workflow

## Workflow หลัก

```
Founder
  ↓
Product Manager
  ↓
Design
  ↓
Coding
  ↓
QA & Security
  ↓
PASS → Deploy
  │
  FAIL
  ↓
Debug Engineer
  ↓
Coding
  ↓
QA
  ↓
PASS → Deploy
```

**ห้ามข้าม QA สำหรับงานที่จะขึ้น production เด็ดขาด**

## Task Lifecycle

```
BACKLOG → PRODUCT → DESIGN → CODING → QA → (DEBUG ถ้าจำเป็น) → QA → APPROVED → DEPLOY → COMPLETED
```

Task ทุกตัวมี unique ID รูปแบบ `WYN-001`, `WYN-002`, ... ดู template ที่ `.wyn/tasks/templates/`

โฟลเดอร์ tracking สถานะ task:

- `.wyn/tasks/backlog/`
- `.wyn/tasks/active/`
- `.wyn/tasks/review/`
- `.wyn/tasks/qa/`
- `.wyn/tasks/bugs/`
- `.wyn/tasks/approved/`
- `.wyn/tasks/completed/`

## Regression Test Memory

เมื่อ QA พบและยืนยันบั๊ก:

```
Bug → Debug → Fix → Regression Test → QA → Knowledge Base
```

1. แก้บั๊ก
2. สร้าง regression test เมื่อทำได้ทางเทคนิค
3. บันทึกบทเรียนใน `.wyn/learning/LESSONS_LEARNED.md`
4. ให้แน่ใจว่า QA รอบถัดไปตรวจสอบ failure เดิมด้วย

เป้าหมาย: ลดข้อผิดพลาดซ้ำเดิมลงเรื่อย ๆ

## Rollback Workflow

```
Deploy → Production Verification → Healthy?
  ├── YES → Complete
  └── NO  → Rollback
```

Deploy AI ต้องบันทึกเสมอ: สิ่งที่ deploy, สิ่งที่เปลี่ยน, ผล verification, วิธี rollback

## Continuous Self-Improvement

หลังจบทุก task ทีม AI ต้องทำ retrospective ด้วยคำถาม:

1. อะไรที่ทำได้ดี
2. อะไรที่ผิดพลาด
3. สาเหตุของปัญหาคืออะไร
4. อะไรที่ควรปรับปรุง
5. มีข้อผิดพลาดซ้ำหรือไม่
6. ควรอัปเดตเอกสารหรือไม่
7. ควรสร้าง checklist ใหม่หรือไม่
8. ควรปรับปรุง workflow หรือไม่

แล้วอัปเดต:

- `.wyn/learning/RETROSPECTIVE.md`
- `.wyn/learning/LESSONS_LEARNED.md`
- `.wyn/learning/IMPROVEMENTS.md`
- `.wyn/learning/PATTERNS.md`
- `.wyn/learning/MISTAKES.md`

## Future Orchestration

เป้าหมายในอนาคต:

```
Product → Design → Coding → QA → Debug → QA → Deploy
```

ระบบต้องคงความเป็น Human-controlled, AI-assisted, Auditable, Reversible เสมอ — ห้ามทำ autonomous production deployment โดยไม่มีมนุษย์ตรวจสอบ
