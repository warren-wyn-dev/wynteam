# Product Task — WYN-025

Status: backlog
Owner: AI Product Manager

Feature: Drop Composer Polish — Image Compression Fix, Draft Persistence, Fullscreen/Zoom Viewer

Goal: แก้ 3 ช่องว่างที่ Phase 0 Audit (`.wyn/docs/product/wyn-core-3-pages-hardening-audit.md`) พบในระบบโพสต์รูปของ Drop ที่**ไม่ต้องแตะ schema ของ `drops` table เลย** (ต่างจาก Drop multi-image ที่เป็นงานถัดไปซึ่งต้อง migrate schema) — ทำก่อนเพื่อให้ Drop composer แข็งแรงขึ้นก่อนขยายเป็น multi-image

Target User: ผู้ใช้ WYN Social ทุกคนที่โพสต์/ดู Drop

Problem:
1. รูปที่ผู้ใช้เลือกผ่าน `image_picker` (JPEG, quality 85, ลดขนาดแล้ว) ถูก crop เป็น 1:1 แล้ว **re-encode เป็น PNG** ใน `square_crop.dart` — PNG ของภาพถ่ายมักมีขนาดไฟล์ใหญ่กว่า JPEG คุณภาพเทียบเท่ามาก ทำให้ขั้นตอนลดขนาดที่ทำไว้ก่อนหน้าถูกลบล้างบางส่วน อัปโหลดช้ากว่าที่ควรและกิน Storage เกินจำเป็น
2. Drop composer (`create_drop_screen.dart`) เก็บ caption/รูปไว้ใน memory (State) เท่านั้น — ออกจากหน้าจอ (กดปุ่ม back, สลับแอป, โทรศัพท์เข้า) ทำให้สิ่งที่พิมพ์/เลือกไว้หายหมดโดยไม่มีการแจ้งเตือนหรือถามยืนยัน
3. ไม่มีทางดูรูป Drop แบบ fullscreen/ซูมเลย — `drop_detail_screen.dart` แสดงรูปแบบ fixed 1:1 ในหน้า scroll เท่านั้น แตะแล้วไม่มีอะไรเกิดขึ้น ผู้ใช้ดูรายละเอียดเล็กๆ ในรูปไม่ได้

Requirements:

R1. เปลี่ยนขั้นตอนสุดท้ายของ `square_crop.dart` จาก PNG re-encode เป็น **JPEG** (คุณภาพที่เหมาะสม เช่น 85-90 เพื่อรักษาความคมชัดตามที่ prompt ของ Founder เน้นไว้ "รักษาความคมชัดและรายละเอียด") — ไม่ต้องเพิ่ม dependency ใหม่ ใช้ `dart:ui`/`package:image` (ตรวจสอบว่ามีอยู่แล้วใน pubspec หรือไม่ก่อนเพิ่ม)
R2. เพิ่ม local draft persistence ให้ Drop composer — เมื่อออกจากหน้าจอโดยยังไม่ publish (caption มีข้อความ หรือเลือกรูปแล้ว) ต้องถามยืนยันหรือบันทึก draft ไว้ให้กลับมาทำต่อได้ (Frontend-only ตาม Backend Dependency Rule — ไม่ต้อง sync ข้ามอุปกรณ์รอบนี้ ใช้ local storage บนเครื่องพอ)
R3. เพิ่ม Fullscreen Image Viewer — แตะรูปใน `DropDetailScreen` เปิดมุมมองเต็มจอ รองรับ pinch-to-zoom/double-tap-zoom/ปิด (ยังไม่ต้องรองรับ swipe ซ้าย-ขวาข้ามหลายรูป เพราะ Drop ยังเป็น 1 รูป/โพสต์ในรอบนี้ — เพิ่ม swipe เมื่อ WYN's multi-image feature เสร็จภายหลัง)

Acceptance Criteria:
- [ ] โพสต์ Drop ใหม่ได้ไฟล์ JPEG ไม่ใช่ PNG หลัง crop — เทียบขนาดไฟล์ก่อน/หลัง fix กับภาพตัวอย่างเดียวกันต้องเล็กลงอย่างมีนัยสำคัญ โดยที่คุณภาพภาพยังดูดีเทียบเท่าเดิม
- [ ] ออกจาก Drop composer ที่มีเนื้อหาค้าง (caption หรือรูป) โดยไม่ publish ต้องมีการถามยืนยัน หรือกลับเข้ามาใหม่แล้วเห็น draft เดิม (เลือกแนวทางใดแนวทางหนึ่ง ให้ AI Design ตัดสินใจ)
- [ ] Publish สำเร็จแล้ว draft ที่เก็บไว้ต้องถูกล้างทิ้ง ไม่ค้างให้เห็นซ้ำ
- [ ] แตะรูปใน Drop Detail เปิด Fullscreen Viewer ได้ ซูมเข้า/ออกได้ ปิดกลับมาหน้าเดิมได้ ไม่ crash
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-005/WYN-019

Dependencies: ต่อยอด WYN-005 (Drop)/WYN-019 (Drop Feed Tabs) ที่ผ่าน QA แล้ว — ไม่มี hard dependency กับ WYN-024 (ทำคู่ขนานกันได้ เพราะแตะคนละไฟล์เป็นหลัก)

Priority: สูง — ตามลำดับที่ Founder ยืนยัน ทำก่อน Drop multi-image เพราะเป็นฐานที่ควรแข็งแรงก่อนขยาย scope ของระบบรูปภาพ

Risks: ต่ำ — ไม่มี schema change เลย (`drops.image_url` ยังคง 1 รูปเหมือนเดิม) R1 อาจกระทบขนาดไฟล์ของรูปเก่าที่โพสต์ไปแล้วเป็น PNG ต้องยืนยันว่ารูปเก่ายังเปิดดูได้ปกติ (ไม่ต้อง migrate รูปเก่า แค่โพสต์ใหม่ใช้ JPEG)

Recommendation: ทำพร้อมกับ WYN-024 ได้เลยเพราะแตะคนละไฟล์ ไม่ชนกัน — แนะนำให้ AI Design ตัดสินใจ UX ของ R2 (dialog ยืนยันออก vs. auto-save draft เงียบๆ) ให้สอดคล้องกับ pattern ที่โปรเจกต์นี้เคยใช้ (ถ้ามี) ก่อนส่ง Coding

Handoff: Design เสร็จแล้ว — ดู `.wyn/docs/design/wyn-025-drop-composer-polish.md`

- **R1**: เป็น bug fix ล้วนๆ ไม่ต้องมี Design **ส่งตรง AI Coding ได้เลยตั้งแต่ต้น** (ไม่ต้องรอ R2/R3) — Design เอกสารมีแค่ note ทางเทคนิคว่า `dart:ui` ไม่มี JPEG encoder ในตัว ต้องเพิ่ม package `image` ใหม่ (ตรวจสอบแล้วว่ายังไม่มีใน `pubspec.yaml`)
- **R2**: อ่านโค้ดจริงของ `create_drop_screen.dart` แล้ว (ไม่มี `PopScope`/`WillPopScope`/draft-persistence pattern ใดๆ ในโปรเจกต์มาก่อนเลย — ตรวจด้วย grep ยืนยันแล้ว) ตัดสินใจเลือกแนวทาง **(ก) dialog ยืนยัน "ทิ้งการเปลี่ยนแปลง?"** แทน (ข) auto-save เงียบๆ เพราะ (ข) ต้องเพิ่ม dependency ใหม่ (`path_provider` หรือเทียบเท่า เพื่อเก็บรูปภาพให้รอดข้าม process) และยังต้องตัดสินใจ UX ซ้อนอีกชั้นว่าจะ restore เงียบๆ หรือถามก่อน (วนกลับไปมี dialog อยู่ดี) ส่วน (ก) reuse โครง `AlertDialog` เดียวกับ `confirmDeletePost`/`confirmDeleteDrop` ที่มีอยู่แล้วได้ตรงๆ ไม่ต้องมี dependency ใหม่ — รายละเอียดเต็มดู Design doc หัวข้อ R2
- **R3**: ยืนยันแล้วว่า `pubspec.yaml` ไม่มี `photo_view`/package ซูมรูปใดๆ อยู่ก่อน — ออกแบบ `FullscreenImageViewer` ใหม่ (`app/lib/core/widgets/fullscreen_image_viewer.dart`) ด้วย `InteractiveViewer` ในตัว Flutter ล้วนๆ ตามที่ Product Task กำหนด รองรับ pinch-zoom (1.0x-4.0x)/double-tap-zoom (toggle 1.0x-3.0x)/ปุ่มย้อนกลับมาตรฐาน ไม่รองรับ swipe หลายรูปตามที่ระบุไว้
- **ทั้ง R2/R3 พร้อมส่งต่อ AI Coding (`/code`) แล้ว** ตาม Handoff เต็มใน Design doc — เขียน regression test ครบ ไม่มี regression กับ WYN-005/WYN-019, ดูหัวข้อ "บันทึกไว้ให้ Product พิจารณาเป็น fast-follow" ท้าย Design doc ด้วย (`CreatePopScreen` มีปัญหาเดียวกับ R2 แต่ไม่อยู่ในขอบเขตนี้)
