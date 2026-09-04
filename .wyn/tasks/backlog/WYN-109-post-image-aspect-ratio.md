# Design Task — WYN-109

Status: review (109b–d เขียนเสร็จแล้ว 2026-09-04 · analyze สะอาด · test 1180/1180 · รอ Founder รัน SQL (109a) และ AI QA ตรวจ)
Owner: AI Design → AI Coding
Screen: CreateDropScreen + square_crop.dart (และ post_media.dart ฝั่งฟีด)
Purpose: ให้คนโพสต์เลือกสัดส่วนรูปได้เอง แทนที่จะโดนบังคับครอปจัตุรัสแล้วโดนตัดซ้ำอีกรอบตอนแสดงผล
User Flow: เลือกรูป (≤9) → เลือกสัดส่วนจากแถบชิป (ค่าเริ่มต้น 4:5) → ใช้กับทุกรูปในโพสต์ → แชร์
Components: แถบชิป 4 ตัว (ต้นฉบับ / 1:1 / 4:5 / 16:9) ทรงเดียวกับชิปที่มีอยู่แล้ว ไม่มีสีใหม่
Interactions: แตะชิป → พรีวิวเปลี่ยนทันที, ครอปจริงตอนกดแชร์ (ไม่ครอปซ้อนครอป)
States: ค่าเริ่มต้น 4:5 · ไม่มีรูปไม่แสดงแถบชิป · ใช้ _isCropping เดิมกันกดซ้ำ
Responsive Behavior: แถบชิปเลื่อนแนวนอนได้บนจอแคบ
Accessibility: ชิปมี Semantics(button/selected) ประกาศสถานะด้วยข้อความ ไม่ใช่สีอย่างเดียว
Design Rules: หนึ่งโพสต์ใช้สัดส่วนเดียวทั้งโพสต์ · ห้ามเพิ่มสัดส่วนนอกช่วงที่ฟีดรองรับ (0.8–1.91)
Handoff: ยังไม่ส่ง AI Coding รอ
1. คำตอบ: ลากเลือกจุดครอปเองได้ไหม (AI Design แนะนำให้ได้ — reuse หน้าครอปของรูปโปรไฟล์ WYN-104)
2. อนุมัติเพิ่มคอลัมน์ DB เก็บสัดส่วนระดับโพสต์ (ไม่งั้นฟีดยังวาด 4:5 ตายตัว งานนี้จะไม่มีผลกับคนที่เลือก 16:9)

---

## QA & Security — รอบ 1 (2026-09-04) — ตรวจ 109b/c/d

**Final Status: FAIL**

ผ่าน: flow รูปโปรไฟล์ (WYN-104) ไม่เปลี่ยนแม้แต่จุดเดียว (default 1:1 + circular, กรอบ 260×260,
สูตร scale เดิมตรงกันถึง 1e-12) · ฝั่งอ่าน fallback 4:5 ถูกต้องเมื่อ production ยังไม่มีคอลัมน์ ·
migration ตรวจซ้ำบน PostgreSQL 16.13 จริงแล้ว: additive, idempotent, ไม่แตะข้อมูลเดิม,
ไม่แตะ RLS/policy/grant, `home_feed` ยัง `security_invoker=true`, CHECK ทำงานถูก

**B-109-1 (Critical)** — `_insertDrop` ส่ง key `image_aspect_ratio` เสมอแม้ค่า null →
ถ้า deploy ก่อนรัน SQL การสร้างโพสต์ **ทุกชนิด** จะพัง (`drop_repository.dart:945`)
`.wyn/tasks/bugs/WYN-109-insert-sends-missing-column.md`

**B-109-2 (Major)** — Drop Detail ยังวาด 4:5 ไม่สนสัดส่วนที่เลือก (ฟีด 1.78 vs หน้าโพสต์ 0.8)
`.wyn/tasks/bugs/WYN-109-detail-gallery-ignores-aspect-ratio.md`

**B-109-3 (Major)** — รูปพรีวิวในหน้าสร้างโพสต์ไม่เปลี่ยนสัดส่วนตามชิป (กรอบ 128×160 ตายตัว + BoxFit.cover)
`.wyn/tasks/bugs/WYN-109-compose-preview-fixed-aspect.md`

รายงานเต็ม: `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa.md`
