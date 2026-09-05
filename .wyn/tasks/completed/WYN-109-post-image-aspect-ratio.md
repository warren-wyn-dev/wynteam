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

---

## สถานะ migration (2026-09-04)

- **ส่วนที่ 1 — คอลัมน์: รันบน production แล้ว** Founder รัน
  `supabase/migrations_wyn109a_column_only.sql` ใน Supabase SQL Editor ผลลัพธ์
  `Success. No rows returned` → `drops.image_aspect_ratio` มีอยู่จริงบน production แล้ว
  ผลที่ตามมาทันที: ฝั่งเขียนใช้ได้ (`_insertDrop` ส่งคอลัมน์นี้เมื่อมีค่า) และทุก query ที่ใช้
  `_dropSelect` (ขึ้นต้นด้วย `*` จากตาราง `drops`) อ่านค่าได้เอง — Drop Detail / Drop grid /
  โปรไฟล์ แสดงสัดส่วนถูกต้องแล้ว
- **ส่วนที่ 2 — view `home_feed`: ยกเลิก ไม่ต้องแก้ view แล้ว** เดิมวางแผนจะ
  `create or replace view home_feed` เพื่อเพิ่มคอลัมน์เข้าไป แต่ทำไม่ได้จริงเพราะนิยาม view
  บน production เพี้ยนจาก `schema.sql` (SCHEMA-004) และ `create or replace view` ต่อท้ายได้อย่างเดียว
  ห้ามสลับ/เปลี่ยนชื่อคอลัมน์ — คือ error `42P16` ที่เจอมาแล้ว

  แทนที่ด้วย **การอ่านแบบ batch จากตาราง `drops` ตรง ๆ**: `HomeRepository._fetchAspectRatios(rows)`
  ยิง `select id, image_aspect_ratio from drops where id in (...)` เฉพาะ drop ที่มีรูปในหน้านั้น
  แล้วเสียบเข้า `Future.wait` ชุดเดิมของ `_fetchViewerState` — **ไม่เพิ่ม round-trip** เพราะวิ่งขนานกับ
  6 query ที่หน้านั้นจ่ายอยู่แล้ว ค่าเดินทางเข้า `HomeFeedItem.fromMap` ทางพารามิเตอร์ `aspectRatio`
  แบบเดียวกับ `imageUrls` ที่ทำมาก่อนหน้า

  ผลลัพธ์: **ไม่ต้องแตะ production view เลยแม้แต่ครั้งเดียว** งาน WYN-109 จบได้โดยไม่ต้องรอ SCHEMA-004
  ถ้า query นี้ล้ม จะ swallow แล้ว fallback 4:5 เหมือนเดิม (pattern เดียวกับ `_fetchImageUrls`)
  และถ้าวันหนึ่ง view มีคอลัมน์นี้ขึ้นมาจริง `fromMap` ยังอ่านจาก row เป็น fallback อยู่ ไม่ต้องแก้อะไร
- **หน้า Saved (`saved_feed` view) ยังวาด 4:5 ทุกรูป** อยู่นอกขอบเขต WYN-109 (ซึ่งระบุหน้า Home)
  และ `SavedRepository` ยังไม่ batch แม้แต่ image URL — ถ้าจะทำต้องเปิดงานใหม่

---

## QA & Security — รอบ 2 (2026-09-04)

**Final Status: PASS** — `flutter analyze` สะอาด · `flutter test` 1253/1253 ผ่าน
รายงานเต็ม: `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa-round2.md`

ย้ายมา `approved/` แล้ว รอ merge + deploy

---

## COMPLETED — 2026-09-05

Deploy ขึ้น production แล้ว (workflow run #63, commit `cb4d02d`) และ **Founder ยืนยันด้วยตาแล้วว่า
ใช้งานได้จริงบน `wynos.online`** ("เช็คแล้ว ใช้ได้")

Deployment log: `.wyn/logs/deployments/2026-09-05-wyn-106-107-108-109-home-cards-deploy.md`
