# Product Task — WYN-030

Status: backlog
Owner: AI Product Manager

Feature: Drop Draft + Edit Caption

Goal: ปิด 2 gap ที่ master prompt ระบุ — (1) ออกจาก Composer กลางคันแล้วข้อมูลหายหมด ไม่มี draft (2) Drop แก้ไม่ได้เลยหลัง publish ต้องลบแล้วโพสต์ใหม่เท่านั้น

Target User: ผู้ใช้ WYN ที่กำลังสร้าง Drop (โดยเฉพาะหลาย Requirements: รูป — WYN-024 — ที่ใช้เวลาจัดรูปนานขึ้น ยิ่งเสี่ยงเสียงานถ้าโดนแทรก/ออกจากหน้าโดยไม่ตั้งใจ) และผู้ใช้ที่พิมพ์แคปชันผิดหลังโพสต์ไปแล้ว

Problem: ปัจจุบันปิด/ออกจาก `CreateDropScreen` กลางคัน (เช่น โดนแอปอื่นแทรก, กด back พลาด) ข้อมูลทั้งหมด (รูปที่เลือก+แคปชัน) หายทันทีไม่มีทางกู้คืน และพิมพ์แคปชันผิดหลังโพสต์ต้องลบทั้งโพสต์ (เสีย Like/Comment ที่มีอยู่แล้ว) แทนที่จะแก้แค่ข้อความ

Requirements:

R1. **Draft — local only**: บันทึกสถานะ Composer (caption, รายการรูปที่เลือก+ลำดับ, hashtag/mention ที่ parse ไว้) ลง local storage ของอุปกรณ์ (ไม่ใช่ backend — เป็น draft ส่วนตัวไม่ต้อง sync ข้ามเครื่อง) ทุกครั้งที่ผู้ใช้ออกจาก Composer โดยยังไม่ publish — เปิด Composer ใหม่แล้วเสนอกู้คืน draft ที่ค้างอยู่ (ถ้ามี) — **ถ้ารูปที่เลือกไว้ persist ไม่ได้จริง (ข้อจำกัดของ image_picker ที่มักให้ path ชั่วคราวที่หายไปเมื่อปิดแอป) ต้องแจ้งผู้ใช้ชัดเจนว่ากู้คืนได้แค่ caption ไม่ใช่รูป — ห้ามอ้างว่ากู้คืนได้ครบถ้าทำไม่ได้จริงตามกติกาห้าม Fake Functionality**
R2. **Edit caption**: เพิ่มปุ่ม "แก้ไข" ใน More Menu ของ Drop (สำหรับเจ้าของเท่านั้น) → แก้แคปชันได้ (re-parse hashtag/mention ใหม่ตามแคปชันที่แก้) — **รอบนี้ยังไม่รองรับแก้ไข/เพิ่ม/ลบรูปหลัง publish** (ซับซ้อนกว่ามาก ต้องจัดการ `drop_images` ที่มีอยู่แล้ว+ RLS + reorder — เกินขอบเขต task นี้ เก็บเป็น fast-follow ถ้า Founder ต้องการ) Requirements ของ `drops` table เพิ่ม `updated_at` column และ RLS update policy จำกัดเจ้าของเท่านั้น
R3. แสดง indicator ว่าโพสต์นี้ถูกแก้ไขแล้ว (เช่น "แก้ไขแล้ว" ข้าง timestamp) เพื่อความโปร่งใส ไม่หลอกผู้ดูว่าเป็นแคปชันดั้งเดิม

Acceptance Criteria:
- [ ] เริ่มพิมพ์แคปชัน+เลือกรูปใน Composer แล้วออกกลางคัน → เปิด Composer ใหม่ → เสนอกู้คืนแคปชันที่พิมพ์ค้างไว้ได้ถูกต้อง
- [ ] ถ้ารูปกู้คืนไม่ได้จริง (ข้อจำกัดทางเทคนิค) → ระบบแจ้งชัดเจนว่ากู้คืนได้แค่ข้อความ ไม่อ้างว่าได้ครบ
- [ ] Publish Drop สำเร็จ → draft ที่ค้างไว้ถูกล้างทิ้ง (ไม่ค้างเสนอกู้คืนซ้ำ)
- [ ] เจ้าของ Drop แก้แคปชันจาก More Menu → บันทึกสำเร็จ, แสดง "แก้ไขแล้ว" ให้ผู้ดูเห็น, hashtag/mention ใหม่ทำงานถูกต้องตามแคปชันที่แก้
- [ ] ผู้ใช้อื่น (ไม่ใช่เจ้าของ) ไม่เห็นตัวเลือก "แก้ไข" เลย, พยายามแก้ผ่าน request ตรงๆ → RLS บล็อก
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression

Dependencies: WYN-024 (Draft ต้องรองรับ multi-image state), WYN-026 (More Menu ที่ Edit จะอยู่ — ถ้ายังไม่เสร็จ ทำปุ่ม Edit แยกไปก่อนได้เหมือน WYN-029)

Priority: ต่ำ-กลาง — เป็นงาน polish ไม่ block อะไร ทำหลัง gap ใหญ่กว่า (WYN-024/025/026) เสร็จก่อน

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Draft รูปกู้คืนไม่ได้จริงตามข้อจำกัดของ image_picker | กลาง | แจ้งผู้ใช้ตรงไปตรงมาตาม R1 ไม่พยายามฝืนทำ fake persistence |
| R2 | Edit caption กระทบ hashtag/mention ที่ trigger notification ไปแล้วก่อนแก้ | ต่ำ | Re-parse ใหม่ทุกครั้งที่ save ไม่ต้อง retroactively แก้ notification เก่าที่ส่งไปแล้ว |

Recommendation: ทำเป็นลำดับท้ายๆ ของแผนนี้ ความเสี่ยงต่ำ คุณค่าชัดเจนแต่ไม่เร่งด่วน

Handoff: ส่งต่อ AI Design เพื่อออกแบบ draft-recovery UX (เสนอกู้คืนแบบไหน) + Edit UI แล้วส่งต่อ AI Coding
