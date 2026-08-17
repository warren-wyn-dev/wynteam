# Product Task — WYN-024

Status: design เสร็จแล้ว รอ AI Coding
Owner: AI Product Manager → AI Design

Feature: Drop Multi-Image Core (สูงสุด 9 รูป, Horizontal Single-Line Row)

Goal: แก้ gap ที่ใหญ่ที่สุดระหว่าง Drop ปัจจุบันกับ spec "WYN — ULTIMATE CORE 3 PAGES MASTER PROMPT" (2026-08-17) ของ Founder — Drop วันนี้โพสต์ได้แค่ 1 รูปต่อโพสต์ (คอลัมน์ `image_url` เดี่ยวในตาราง `drops`) แต่ spec ต้องการสูงสุด 9 รูปต่อโพสต์ แสดงเป็น Horizontal Single-Line Row เสมอ (ไม่ใช่ Grid/Wrap) — ระบุไว้เองว่าเป็น "Requirement สำคัญที่สุดของระบบรูป"

Target User: ผู้ใช้ WYN ทุกคนที่โพสต์/ดู Drop

Problem: ผู้ใช้อยากแชร์รูปหลายใบในโพสต์เดียว (เช่น อัลบั้มทริป, before/after) แต่ตอนนี้ต้องแยกโพสต์ทีละรูป — ทำให้ Feed รกและ engagement กระจาย

Requirements:

R1. **Schema**: เพิ่มตารางใหม่ `drop_images` (id, drop_id FK→drops, image_url, position int, created_at) แทนที่จะแก้คอลัมน์ `image_url` เดิมของ `drops` ทันที — **ไม่ลบ/ไม่ migrate คอลัมน์เดิมในรอบนี้** (destructive schema change ต้องขออนุมัติ Founder แยกตามกติกา RULES.md) ให้ Drop ใหม่เขียนเข้า `drop_images` เท่านั้น (`drops.image_url` เป็น nullable ต่อจากนี้สำหรับ Drop ใหม่ หรือ backfill แถวเดียวไปตาราง `drop_images` ก็ได้ — ให้ AI Design/Coding ตัดสินใจแนวทาง migration ที่ปลอดภัยที่สุดสำหรับข้อมูลเดิมที่มีอยู่) RLS ของ `drop_images` ต้อง mirror `drops` (select: authenticated ทั้งหมด, insert/delete: เจ้าของ Drop เท่านั้น ผ่านการเช็ค `drops.author_id`)
R2. **Constraint**: 1 Drop ต้องมีอย่างน้อย 1 รูป สูงสุด 9 รูป — บังคับที่ระดับ client (composer ไม่ให้เพิ่มเกิน 9, แสดง "Maximum 9 photos" เมื่อพยายามเพิ่มรูปที่ 10 ไม่ silently ตัดทิ้ง) และพิจารณา DB-level check เพิ่มเติมถ้าทำได้โดยไม่ซับซ้อนเกินไป (เช่น trigger นับแถวก่อน insert)
R3. **Composer (`CreateDropScreen`)**: ปุ่ม "+ Add Photos" เลือกได้หลายรูปพร้อมกัน (multi-select จาก `image_picker`), preview เป็น grid ให้ผู้ใช้จัดการ (ลบรูป, ลากสลับตำแหน่ง/reorder ก่อน publish) — Composer ใช้ Grid ได้ตาม spec ("Composer สามารถใช้ Grid เพื่อจัดการรูป") แต่ **Published Drop ต้องเป็น Horizontal Single-Line Row เสมอ** ไม่ว่า Composer จะแสดงแบบไหน
R4. **Published rendering**: `DropDetailScreen`/`DropGridTile`/`HomeDropCard` ต้องแสดงรูปทั้งหมดของ Drop เป็น **Horizontal Scroll Container เดียว** (ไม่ใช่แต่ละรูปมี scroll ของตัวเอง) เรียงตาม `position`, ทุกรูป `aspect-ratio 1:1` ขนาดเท่ากัน ห้าม Grid/Wrap/ขึ้นบรรทัดใหม่ไม่ว่าจะมี 2-9 รูป — grid tile ของ Drop tab/Search/Profile ที่เป็น thumbnail เดียว (ไม่ใช่ full row) ให้แสดงรูปแรก (position=0) พร้อม indicator เล็กๆ ว่ามีหลายรูป (เช่น ไอคอน stack มุมขวาบน คล้าย pattern ที่ Club post carousel ใช้อยู่แล้วถ้ามี ให้ Design ตรวจสอบ reuse ก่อนสร้างใหม่)
R5. **1 รูปเดิม**: ต้องยังแสดงผลถูกต้องเหมือนเดิมทุกประการ (Horizontal Row ที่มีแค่ 1 รูปหน้าตาเหมือน single image เดิมเป๊ะ ไม่มี regression)

Acceptance Criteria:
- [ ] สร้าง Drop ด้วย 1, 2, 5, 9 รูป — publish สำเร็จ แสดงผลถูกต้องทุกกรณี
- [ ] พยายามเพิ่มรูปที่ 10 ใน Composer → ระบบบล็อกพร้อมข้อความ "Maximum 9 photos" ชัดเจน ไม่ silently ตัดรูป
- [ ] Reorder รูปใน Composer ก่อน publish แล้วลำดับที่ publish จริงตรงกับที่จัดใหม่
- [ ] Published Drop (ทุกจำนวนรูป 2-9) แสดงเป็น Horizontal Single-Line Row เสมอ ไม่มี Grid/Wrap ปรากฏในทุกจุดที่การ์ด Drop แสดง (Home, Drop feed, Profile, Search, Detail)
- [ ] Horizontal Row swipe ซ้าย/ขวาได้ลื่น ไม่ชนกับ vertical scroll ของหน้าหลัก
- [ ] Drop เก่าที่มีแค่ 1 รูป (ข้อมูลก่อน migration) ยังแสดงผลถูกต้อง ไม่พัง
- [ ] RLS ของ `drop_images` ผ่าน QA (insert/delete จำกัดเจ้าของ Drop เท่านั้น อ่านได้ทุกคน authenticated เหมือน `drops`)
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-005/007/009/013/018/019/020/021/022

Dependencies: WYN-005 (Drop core), WYN-019 (Drop feed tabs — reuse การ์ดเดียวกัน)

Priority: **สูงสุด** ในกลุ่ม Gap ใหม่ — Founder ระบุเองว่าเป็น requirement สำคัญที่สุดของระบบรูปทั้งหมด

Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Schema migration กระทบ Drop เดิมที่มีข้อมูลจริงอยู่แล้ว (likes/comments/mentions/saves ผูกกับ `drop_id` เดิม) | กลาง | เพิ่มตารางใหม่แบบ additive เท่านั้น ไม่แตะ/ลบคอลัมน์เดิมของ `drops` ในรอบนี้ ทดสอบกับข้อมูลเก่าจริงก่อน QA ผ่าน |
| R2 | Horizontal Row ชนกับ vertical scroll ของ Feed (gesture conflict) | กลาง | ใช้ pattern scroll ที่ทดสอบแล้วบน mobile จริง (`SingleChildScrollView(scrollDirection: Axis.horizontal)` ซ้อนใน `ListView` แนวตั้ง เป็น pattern มาตรฐานของ Flutter ไม่ใช่เรื่องใหม่) |
| R3 | Storage cost เพิ่มขึ้น 9 เท่าต่อโพสต์ | ต่ำ | ยังไม่ทำ responsive image derivative pipeline รอบนี้ (นอกขอบเขต ตามที่ roadmap ระบุ) — เก็บเป็นข้อสังเกตให้ Founder รับทราบ ไม่ block |

Recommendation: เริ่มทำทันทีหลัง WYN-023 (งานเก็บกวาดเล็กที่เสี่ยงต่ำกว่า) — เป็น foundation ที่งานถัดไป (WYN-025 Image Viewer) ต้องพึ่งพา

Handoff: **AI Design เสร็จแล้ว (2026-08-17)** — Design spec เต็มที่ `.wyn/docs/design/wyn-024-drop-multi-image-core.md`:
- **Schema/Migration**: เพิ่มตาราง `drop_images` (id, drop_id FK cascade, image_url, position int 0-8, created_at) + `unique(drop_id, position)` + `check(position between 0 and 8)` (สองอันนี้ร่วมกันบังคับ "สูงสุด 9 รูป" ที่ DB level อยู่แล้วโดยไม่ต้องเขียน trigger เพิ่ม) + RLS 3 policy มิเรอร์ `drops` เป๊ะ (select all authenticated, insert/delete เฉพาะเจ้าของผ่านเช็ค `drops.author_id`, ไม่มี update policy เพราะ Drop ยังแก้ไม่ได้จนกว่าจะถึง WYN-030) — **ตัดสินใจ migration**: คง `drops.image_url` เป็น `not null` เหมือนเดิมทุกประการ (ไม่ทำ nullable) เขียนเป็น "cover image" (=รูป position 0) เสมอ ควบคู่กับ dual-write เข้า `drop_images` ทุกรูป + backfill 1 ครั้งให้ Drop เก่าทุกอันมีแถว `drop_images` position 0 จาก `image_url` เดิม — เลือกทางนี้เพราะทำให้ `home_feed`/`saved_feed` view (WYN-007/013) ไม่ต้องแก้ SQL เลย และ Drop เก่า/ใหม่อ่านจาก source เดียวกัน (`drop_images`) โดยไม่ต้อง fallback-check ที่ไหนเลย
- **Composer**: preview เป็น grid 3 คอลัมน์ (มิเรอร์ภาษาภาพของ Drop Feed grid), ช่องแรกมี badge "ปก", ลบรูปด้วยปุ่ม "x" ต่อช่อง, reorder ด้วย `LongPressDraggable`/`DragTarget` เขียนเอง (ตัดสินใจไม่เพิ่ม pub package ใหม่ ตาม pattern เดิมของโปรเจกต์ที่เพิ่ม dependency น้อยและมีเหตุผลกำกับเสมอ), ข้อความเมื่อเกิน 9 รูปเป็นภาษาไทย "เพิ่มรูปได้สูงสุด 9 รูป" (ไม่ใช่ literal string อังกฤษ "Maximum 9 photos" ของ AC ตรงๆ — ทั้งแอปเป็นภาษาไทยทุกจุดตาม `AGENTS.md`, บันทึกไว้ชัดเจนกัน QA ตีความผิด)
- **Published rendering**: ตรวจ Club's `ClubPostImages` (PageView + dot indicator) แล้ว **ตัดสินใจ reuse pattern เดียวกันตรงๆ** (ไม่ใช่ filmstrip-peek แบบใหม่) เพราะตรงตามตัวอักษรของ R4 ทุกข้อและมีประวัติผ่าน QA จริงมาแล้วว่าไม่ชน vertical scroll — สร้าง widget ใหม่ `MultiImageRow` ที่ `core/widgets/` (ใช้ร่วมกับทั้ง `DropDetailScreen` และ `HomeDropCard`) แทนที่จะแก้ Club (Club ไม่อยู่ในขอบเขต ผ่าน QA แล้ว ไม่แตะในรอบนี้ — บันทึกเป็น optional tech-debt follow-up ให้รวมโค้ดทีหลัง) — รูปเดียวยัง render เป็น `Image.network` ตรงๆ ไม่ผ่าน PageView เลย รับประกัน R5 (ไม่มี regression)
- **Grid/thumbnail indicator**: `DropGridTile` (ใช้ร่วม 3 จุด: Drop tab/Search/Profile grid) เพิ่ม badge ไอคอน `Icons.collections` มุมขวาบนเมื่อมี >1 รูปเท่านั้น (เลือกไอคอนนี้แทน `Icons.photo_library` เพื่อไม่ให้ชนความหมายกับไอคอนเดิมในบริบท action-sheet เลือกรูป)

ส่งต่อ AI Coding (`/code`) เพื่อ implement ตาม Design spec ข้างต้น — ดู Handoff section เต็มในเอกสาร design สำหรับรายละเอียด implementation/regression-test ที่ต้องทำครบ (ห้ามข้าม QA ตาม WORKFLOW.md)
