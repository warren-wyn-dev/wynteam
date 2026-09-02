# Product Task — WYN-096

Status: review
Owner: AI Design → AI Coding

Feature: Home Feed — Action Bar (Like/Comment/Repost/View) Left-Alignment Fix

Goal: จับคู่ตำแหน่งแนวนอนของแถวไอคอน หัวใจ/คอมเมนต์/รีโพสต์/ตา ในการ์ด Home feed ให้ตรงกับส่วน
อื่นของการ์ดเดียวกัน (header/ข้อความ/liked-by row) ตามภาพอ้างอิงของ Founder (Beta2 Phase 2 PDF
revision list item 28)

Target User: ผู้ใช้ WYNOS ทุกคนที่เลื่อนดู Home feed

Problem: มี draft ของงานนี้อยู่แล้วจากรอบ AI Design ครั้งก่อน (2026-09-02, เขียนไว้เป็น Part 2
ของ `.wyn/docs/design/wyn-089-096-repost-active-state-action-row.md` ก่อน Founder ส่งภาพ
อ้างอิงจริงมาให้) — ตอนนั้น "Blocked: รอ Founder ยืนยันว่า draft ตรงกับภาพอ้างอิงหรือไม่" และ
draft เดิมเสนอเปลี่ยนทั้งสไตล์การ์ดฟีดให้เหมือน Detail screen's "Focused Action Bar" ทั้งหมด —
ตอนนี้ Founder ส่งภาพจริงมาแล้ว (`a279a127-image.jpg`, PDF item 28, crop ของภาพ item 13 เดิม
มีวงสีแดงล้อมแถวไอคอน) จึงมาปิด block นี้ด้วยการเทียบภาพจริงกับโค้ดโดยตรงแทนการเดา — ผลตรวจ
ใหม่แม่นกว่า draft เดิมมาก: ไอคอน/สี/ขนาด/ระยะห่างภายในแถวถูกต้องครบทุกจุดตาม
`design-reference/SPEC.md` Section 4.9 อยู่แล้ว **ไม่ต้องเปลี่ยนทั้งสไตล์ตามที่ draft เดิมเสนอ**
มี gap จริงแค่จุดเดียว: padding แนวนอนที่ห่อแถวไอคอนทั้งแถว (4px) ไม่ตรงกับ padding ของทุกส่วนอื่น
ในการ์ดเดียวกัน (12px) ทำให้แถวไอคอนเยื้องซ้ายจากเนื้อหาข้างบนเล็กน้อย

Requirements:
- R1. แถวไอคอน action bar (หัวใจ/คอมเมนต์/รีโพสต์/ตา) ต้องอยู่แนวซ้ายเดียวกับ header/ข้อความ
  โพสต์/liked-by row ของการ์ดเดียวกัน (ทั้ง `HomeDropCard` และ `HomePopCard`)
- R2. ไอคอน/สี/ขนาด/ระยะห่างภายในแถว (ระหว่างไอคอนแต่ละอัน, ระหว่างไอคอนกับตัวเลข) **ไม่เปลี่ยน**
  — ตรงกับ SPEC.md 4.9 อยู่แล้วครบทุกจุด

Acceptance Criteria:
- [ ] `HomeDropCard`'s action bar row ใช้ padding แนวนอน 12px (`WynSpacing.space3`) เท่ากับ
  header/ข้อความ/`LikedByRow` ในไฟล์เดียวกัน
- [ ] `HomePopCard` แก้จุดเดียวกันแบบเดียวกันทุกประการ
- [ ] สีหัวใจถูกใจยังคงเป็น `Colors.red` ตาม WYN-076 (Founder-approved override, deployed แล้ว)
  — **ไม่เปลี่ยนกลับเป็น sapphire**
- [ ] ไอคอน/ขนาด/gap ภายในแถวไม่เปลี่ยน
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-023/WYN-034/WYN-076

Dependencies: WYN-076 (liked-heart red override — ต้องคงไว้), WYN-071 (Sapphire re-brand token
ปัจจุบัน)

Priority: ไม่มีคำถามค้าง พร้อมส่งต่อ AI Coding — ความเสี่ยงต่ำมาก

Risks: ต่ำมาก — เปลี่ยนแค่ค่า padding เดียวใน 2 ไฟล์ ไม่มีการเปลี่ยน behavior/schema ใด ๆ

Recommendation: ทำได้ทันที

Handoff: พร้อมส่งต่อ AI Coding

---

## Design Output (AI Design, 2026-09-02)

Design spec เต็ม: `.wyn/docs/design/wyn-096-home-feed-action-bar-alignment.md`

สรุป: ภาพอ้างอิง (`a279a127-image.jpg`, PDF item 28) เป็น crop ของภาพ item 13 เดิม (โพสต์ "ZEN")
มีวงสีแดงล้อมแถวไอคอน action bar ไว้เป็นภาพเป้าหมาย — เทียบกับ `design-reference/SPEC.md`
Section 4.9 ทีละแถว (ไอคอน/ขนาด/สี/gap-5/gap-1.5) พบว่าตรงกันครบทุกจุดอยู่แล้วใน `ActionMetric`/
`HomeDropCard`/`HomePopCard` **ยกเว้น** สีหัวใจถูกใจที่ใช้ `Colors.red` แทน sapphire ตาม
SPEC.md เดิม — ตรวจแล้วยืนยันว่านี่คือการตัดสินใจ Founder-approved จาก WYN-076 (deployed
2026-09-01) **ไม่ใช่ gap ที่ต้องแก้** gap จริงที่พบมีจุดเดียว: padding แนวนอนของแถวไอคอน (4px)
ไม่ตรงกับ padding ของทุกส่วนอื่นในการ์ดเดียวกัน (12px)

Screen: `HomeDropCard`/`HomePopCard` — เฉพาะ `Padding` ที่ห่อแถว `ActionMetric` ทั้งแถว

Handoff ถึง AI Coding (รายละเอียดเต็มดู design doc):
1. `app/lib/features/home/presentation/widgets/home_drop_card.dart` — เปลี่ยน
   `WynSpacing.space1` → `WynSpacing.space3` ใน `Padding` ที่ห่อ `Row` ของ `ActionMetric` ×4
2. `app/lib/features/home/presentation/widgets/home_pop_card.dart` — จุดเดียวกันทุกประการ
3. `ActionMetric` widget เอง ไม่ต้องแก้อะไร (ถูกต้องตาม SPEC.md 4.9 อยู่แล้ว)
4. `flutter analyze` + `flutter test` ต้องผ่านครบ

Design Rules ที่ต้องยึด: ห้ามแก้สีหัวใจถูกใจกลับเป็น sapphire (WYN-076 override), ห้ามแก้ไอคอน/
ขนาด/ระยะห่างภายในของ `ActionMetric`, padding ใหม่ต้องตรงกับ padding แนวนอนของทุกส่วนอื่นใน
การ์ดเดียวกันเสมอ
