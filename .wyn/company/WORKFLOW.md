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

### Production Verification คือใครยืนยัน ยืนยันอะไร (เพิ่ม 2026-09-05)

บทเรียนจากเหตุการณ์ Vercel 2026-09-02 (`.wyn/learning/LESSONS_LEARNED.md`): **CI เขียว + deploy
workflow รายงาน success ไม่เท่ากับ production ใช้งานได้จริง** ต้องแยกสองอย่างนี้ออกจากกันเสมอ
ในบันทึก deploy log:

1. **สิ่งที่ AI ยืนยันได้เอง** — ผล CI, ผล workflow run แต่ละ step, `flutter analyze`/`flutter test`
   ผลลัพธ์อัตโนมัติอื่น ๆ ที่มีเครื่องมือให้ AI ตรวจสอบได้จริง
2. **สิ่งที่ต้องรอ Founder ยืนยัน** — เว็บ/แอปจริงเปิดใช้งานได้ไหม ฟีเจอร์ที่แก้ทำงานถูกไหมเมื่อลองใช้จริง
   โดยเฉพาะเมื่อ environment ของ AI ไม่มีทางออกเน็ตไปยัง production (เช่น egress ถูกบล็อก) —
   AI ต้องระบุไว้ชัดเจนในบันทึกว่า "ยืนยันเองไม่ได้" แทนที่จะสรุปว่า "เสร็จแล้ว" จากผล workflow อย่างเดียว

Task จะย้ายจาก `approved/` → `completed/` ได้ก็ต่อเมื่อ **Founder ยืนยันข้อ 2 แล้วเท่านั้น**
(ไม่ใช่แค่ deploy workflow สำเร็จ) — บันทึกคำยืนยันของ Founder ไว้ใน deployment log ด้วยว่า
ยืนยันเมื่อไหร่ ยืนยันว่าอะไร

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
