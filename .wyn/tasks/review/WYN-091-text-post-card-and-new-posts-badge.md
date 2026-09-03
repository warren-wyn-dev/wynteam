# Product Task — WYN-091

Status: review
Owner: AI Design → AI Coding

Feature: Home Feed — Text-Only Post Card Confirmation + "มีโพสต์ใหม่" Pill Text Simplification

Goal: จับคู่หน้าตาการ์ดโพสต์ข้อความล้วนและข้อความ pill "มีโพสต์ใหม่" ให้ตรงกับภาพอ้างอิงที่
Founder ระบุไว้ใน Beta2 Phase 2 PDF revision list (item 13)

Target User: ผู้ใช้ WYNOS ทุกคนที่เลื่อนดู Home feed

Problem: มี draft ของงานนี้อยู่แล้วจากรอบ AI Design ครั้งก่อน (2026-09-02, ก่อน Founder ส่งภาพ
อ้างอิงจริงมาให้) — ตอนนั้น Part 1 (badge) พร้อมขึ้นโค้ดแล้ว แต่ Part 2 (การ์ดข้อความล้วน) ยัง
"Blocked: รอ Founder ยืนยันภาพอ้างอิง" เพราะ session นั้นไม่มีไฟล์ภาพ ตอนนี้ Founder ส่งภาพจริงมา
แล้ว (`c2a85036-image.jpg`, PDF item 13) จึงมาปิด block นี้ด้วยการเทียบภาพจริงกับโค้ดโดยตรง —
Founder เดิม: "หน้า Home feed อยากให้เรียงโพสต์ที่เป็นข้อความแบบนี้ เรียบๆหรู เหมือนในรูป" +
"ปล. วงน้ำเงินที่เขียนว่า 'มีโพสต์ใหม่ 3 โพสต์' เปลี่ยนเป็น 'มีโพสต์ใหม่' จะขึ้นมาเฉพาะ มีโพสต์ใหม่ๆ"

Requirements:
- R1. การ์ดโพสต์ข้อความล้วน (ไม่มีรูป) ใน Home feed ต้อง "เรียบๆหรู" ตามคำกำกับของ Founder —
  ไม่มีกรอบ/พื้นหลัง/เงาแยกจากพื้นเพจ
- R2. Pill "มีโพสต์ใหม่" ต้องแสดงข้อความคงที่ "มีโพสต์ใหม่" โดยไม่มีตัวเลขจำนวนต่อท้ายอีกต่อไป
  (เดิมแสดง "มีโพสต์ใหม่ {N} โพสต์")

Acceptance Criteria:
- [ ] การ์ดข้อความล้วนของ `HomeDropCard` ไม่มี border/shadow/background ห่อรอบ (ยืนยันแล้วว่า
  ตรงอยู่แล้ว — ดู Design Output)
- [ ] `NewPostsPill` แสดงข้อความ "มีโพสต์ใหม่" โดยไม่มีจำนวนกำกับ ไม่ว่าจะมีโพสต์ใหม่กี่โพสต์ก็ตาม
- [ ] Accessibility label ยังคงมีจำนวนกำกับเหมือนเดิม (ไม่ลดข้อมูลสำหรับ screen reader)
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-007/WYN-023

Dependencies: WYN-023 (Home Drop Polish, header 2 บรรทัด — คงไว้ ไม่แก้), WYN-071 (Sapphire
re-brand, สี/spacing token ปัจจุบัน)

Priority: ไม่มีคำถามค้าง — ได้ภาพอ้างอิงและคำกำกับชัดเจนจาก Founder แล้ว พร้อมส่งต่อ AI Coding

Risks: ต่ำ — เปลี่ยนแค่ 1 บรรทัดข้อความใน `NewPostsPill`, ไม่มีการเปลี่ยนโครงสร้าง/schema/
behavior ใด ๆ

Recommendation: ทำได้ทันที ความเสี่ยงต่ำมาก

Handoff: พร้อมส่งต่อ AI Coding

---

## Design Output (AI Design, 2026-09-02)

Design spec เต็ม: `.wyn/docs/design/wyn-091-text-post-card-and-new-posts-badge.md`

สรุป: ตรวจสอบภาพอ้างอิงของ Founder (`c2a85036-image.jpg`, PDF item 13) เทียบกับโค้ดจริงแล้วพบว่า
`HomeDropCard`'s caption-only path ตรงกับภาพอยู่แล้วครบทุกจุด (ไม่มี diff ที่ต้องแก้) — gap เดียว
ที่พบจริงคือ `NewPostsPill` ยังแสดงตัวเลขจำนวนต่อท้ายข้อความ ("มีโพสต์ใหม่ 3 โพสต์") ซึ่ง Founder
เขียนกำกับชัดว่าต้องการเอาออก (เหลือแค่ "มีโพสต์ใหม่")

Screen: `HomeDropCard` (caption-only path, ยืนยันไม่ต้องแก้) และ `NewPostsPill` (แก้ 1 บรรทัด)

Handoff ถึง AI Coding (รายละเอียดเต็มดู design doc):
1. `app/lib/features/home/presentation/widgets/new_posts_pill.dart` — เปลี่ยนข้อความที่แสดงผล
   จาก `'มีโพสต์ใหม่ $count โพสต์'` → `'มีโพสต์ใหม่'` เท่านั้น (คง `Semantics.label` แบบมีจำนวนไว้)
2. อัปเดตเทสที่ assert ข้อความเดิม: `app/test/new_posts_pill_test.dart`,
   `app/test/home_feed_screen_test.dart`
3. `HomeDropCard` ไม่ต้องแก้โค้ดใด ๆ
4. `flutter analyze` + `flutter test` ต้องผ่านครบ

Design Rules ที่ต้องยึด: ห้ามเพิ่ม border/shadow ให้การ์ดข้อความล้วน, ห้ามเปลี่ยนโครงสร้าง header
2 บรรทัดของ `HomeDropCard` (WYN-023 convention), สีทุกจุดต้องมาจาก `WynColors` เท่านั้น
(ตรวจแล้วถูกต้อง), ข้อความ pill เป็น literal คงที่เท่านั้น ห้ามใส่ placeholder ตัวเลขกลับมา

---

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — ตรงตามสโคปที่ Design ยืนยันแล้วว่า `HomeDropCard` ไม่ต้องแก้ เหลือแค่
`NewPostsPill`

การเปลี่ยนแปลง:
1. **`app/lib/features/home/presentation/widgets/new_posts_pill.dart`**: ข้อความที่แสดงผลจาก
   `'มีโพสต์ใหม่ $count โพสต์'` → literal คงที่ `'มีโพสต์ใหม่'` — `Semantics.label` ยังคงมี
   `$count` เหมือนเดิมสำหรับ screen reader, พารามิเตอร์ `count`/`onTap` ไม่ถูกลบออกจาก
   constructor (ยังใช้ควบคุมว่า pill แสดงหรือไม่)
2. `HomeDropCard` ไม่ถูกแตะเลยตามที่ Design ยืนยัน

Files Changed:
- `app/lib/features/home/presentation/widgets/new_posts_pill.dart`
- `app/test/new_posts_pill_test.dart` — อัปเดตเทสที่ assert ข้อความเดิม
- `app/test/home_feed_screen_test.dart` — อัปเดตจุดที่อ้างอิงข้อความ pill เดิม

Tests: `flutter analyze` สะอาด, `flutter test` ผ่านครบ (ยกเว้น WYN-081's regression test ที่ยัง
red อยู่ในสาขานี้ ณ ตอนโค้ด — เป็นเรื่องคนละงาน กำลังถูกแก้แยกโดย AI Debug Engineer อยู่แล้ว)

Handoff: ส่งต่อ AI QA & Security
