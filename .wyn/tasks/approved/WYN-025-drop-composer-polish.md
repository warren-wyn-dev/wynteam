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

---

## Status Update (2026-08-17) — Coding เสร็จสมบูรณ์แล้ว รอ QA

Implementation ครบตาม R1/R2/R3 ของ Design spec (ตรวจสอบโค้ดจริงเทียบ spec ทีละจุดแล้ว ตรงทุกประการ): JPEG re-encode (quality 90), `confirmDiscardChanges` dialog + `PopScope` wiring, `FullscreenImageViewer` ใหม่ที่ `core/widgets/`

งานนี้ถูกส่งมาต่อจาก agent ก่อนหน้าที่ implementation เสร็จแล้วแต่ session หมดก่อน commit ได้ — พบและแก้ 2 ปัญหาเพิ่มก่อนส่ง QA:

1. **Production bug จริงที่พบระหว่างแก้ test (ไม่ใช่แค่ test bug)**: `PopScope`'s `canPop` (`!_isSharing && !_hasUnsavedContent`) คำนวณตอน `build()` เท่านั้น — พิมพ์ caption ธรรมดา (ไม่มี `@mention`) ไม่ trigger `setState()` ใดๆ ใน `_CreateDropScreenState` เลย เพราะ `MentionInput`'s `onMentionedUsersChanged` fire เฉพาะตอน mention เปลี่ยน ทำให้ `canPop` ค้างค่าเดิม (true) จากตอนยังไม่พิมพ์อะไร — ผลคือระบบ back ของ OS (system back/gesture) จะ pop หน้าจอออกไปเงียบๆ **โดยไม่เด้ง dialog เลย** ทั้งที่ตั้งใจให้ต้องถามยืนยันก่อน ทำให้ผู้ใช้เสียเนื้อหาที่พิมพ์ไว้แบบไม่รู้ตัว — พิสูจน์ด้วย debug print ยืนยัน `didPop=true` ตอน system back จริง ก่อนแก้ — แก้ด้วยการเพิ่ม `onChanged: (_) => setState(() {})` ให้ `MentionInput` ใน `create_drop_screen.dart` (ทำให้ `canPop` re-derive สดทุกครั้งที่พิมพ์ ตรงตามที่ design spec ตั้งใจไว้แต่แรก "คำนวณสดจาก field ที่มีอยู่แล้ว ไม่ cache" — ที่ขาดไปคือ trigger การ rebuild เท่านั้น)
2. **Test hang จริง (root cause ของ timeout 10 นาทีที่ QA เดิมเจอ)**: `centerCropToSquare()`'s real `dart:ui` Picture-rendering chain ไม่ resolve เมื่อถูกเรียกตรงในโซน fake-async ของ `testWidgets()` — `pumpAndSettle()` เดียวหลัง tap เลือกรูปค้างตลอดไป ไม่มี exception เลย ยืนยันด้วยการ isolate ปัญหาด้วย probe test หลายรอบ — แก้ที่ test เท่านั้น (ไม่แตะ production code เพราะ `square_crop_test.dart`'s plain `test()` ยืนยันแล้วว่า `centerCropToSquare()` เองถูกต้อง) ด้วย bounded `tester.runAsync()`+`pump()` loop แทน `pumpAndSettle()` เดียว — รายละเอียดเต็มบันทึกไว้ที่ `.wyn/learning/PATTERNS.md`

`flutter analyze`: clean. `flutter test`: full suite 396/396 ผ่านหมด (baseline เดิม 369 ก่อน WYN-024/025)

ส่งต่อ AI QA & Security (`/qa`) — ย้ายเข้า `.wyn/tasks/review/` — **QA ควรตรวจ finding #1 ข้างต้นเป็นพิเศษ** เพราะเป็นบั๊กจริงที่กระทบ data-loss risk ของผู้ใช้ตรงๆ (ไม่ใช่แค่ QA finding ที่ Coding พบเองก่อนส่ง แต่ยืนยันด้วย red→green จริง: ลบ `onChanged` ออกแล้ว test "system back...shows the same discard dialog" fail ทันที)

---

## QA Output (2026-08-17) — รอบ 1: PASS

Feature: WYN-025 Drop Composer Polish — R1 (JPEG re-encode), R2 (confirm-discard dialog + `PopScope`), R3 (`FullscreenImageViewer`)

Environment: sync `HEAD` (`f43f06c`, ครอบคลุม `e252ea4`/`e2b2626`/`f43f06c`) — เหมือน WYN-023 ที่ผ่านมา repository directory มี agent อื่นกำลังทำงาน WYN-024 คู่ขนานจริง (พบ staged rename + unstaged edit ของ `WYN-024-profile-identity-fields.md` ระหว่าง session นี้) — ป้องกันด้วยการสร้าง `git worktree` แยกจาก commit `f43f06c` (detached HEAD) ตั้งแต่ต้นก่อนรัน `flutter pub get`/`analyze`/`test`/red-green proof ทั้งหมด ไม่แตะ working directory หลักเลยตลอด session (ยกเว้นตอนท้ายที่ move task file + อัปเดตเอกสาร) ลบ worktree ทิ้งหลังตรวจเสร็จ ยืนยัน `git status` สะอาดทั้งสองฝั่งก่อน/หลัง

Test Cases:
1. `flutter analyze` อิสระ (worktree แยก) — clean, ไม่มี issue ตรงกับที่ Coding รายงาน
2. `flutter test` อิสระเต็มชุด (worktree แยก, รันซ้ำ 2 ครั้งคนละช่วงเวลาของ session) — **396/396 ผ่านทั้งสองครั้ง** ตรงกับตัวเลขที่ Coding รายงาน
3. **R1 — อ่านโค้ดจริง** (`square_crop.dart`): ยืนยัน `centerCropToSquare()` decode เป็น raw RGBA แล้ว re-encode ด้วย `package:image`'s `img.encodeJpg(quality: 90)` จริง (ไม่ใช่ PNG อีกต่อไป), `create_drop_screen.dart`'s `_imageExtension` เปลี่ยนจาก hardcode `'png'` เป็น `'jpg'` ทั้ง initial value และหลัง crop เสร็จ — ตรงตาม Design spec/Handoff ทุกจุด
4. **R1 — independent size/quality proof** (เขียน test ชั่วคราวเองแยกจาก `square_crop_test.dart` ที่ Coding ส่งมา ไม่ใช้ของ Coding เลย ใช้ gradient+noise "photo-like" sample คนละแบบ): เปรียบเทียบ JPEG output ของ `centerCropToSquare()` กับ PNG baseline ของภาพต้นทางเดียวกัน — **ขนาดไฟล์เล็กลง 51.6%** (302,426 → 146,419 bytes) และ**คุณภาพยังดี** (mean per-channel abs error เพียง 2.56/255 หลัง decode กลับมาเทียบกับต้นฉบับ) ตรงตาม AC1 "เล็กลงอย่างมีนัยสำคัญ...คุณภาพยังดูดีเทียบเท่าเดิม"
5. **R1 — รูปเก่า PNG ยังเปิดได้** independent test ยืนยันว่า `ui.instantiateImageCodec` sniff format จาก content bytes ไม่ใช่จาก extension ของ URL — รูป Drop เก่าที่อัปโหลดเป็น PNG ก่อน fix นี้ยังเปิดดูได้ปกติทั้งใน feed และ `FullscreenImageViewer` ใหม่ ไม่ต้อง migrate ตาม Risk ที่ Product Task ระบุไว้
6. **R2 — อ่านโค้ดจริง** (`create_drop_screen.dart`, `confirm_discard_dialog.dart`): ยืนยัน `_hasUnsavedContent` getter, `PopScope(canPop: !_isSharing && !_hasUnsavedContent, onPopInvokedWithResult: ...)`, `_requestExit()` ใช้ร่วมกันทั้งปุ่ม X และ system back, AppBar's close button disable ระหว่าง `_isSharing`, `_share()`'s success path เรียก `pop(true)` ตรงๆไม่ผ่าน guard — ตรงตาม Design Components/Interactions ทุกข้อ
7. **R2 — Red→Green regression proof อิสระของบั๊ก PopScope/caption-only-change (จุดที่สำคัญที่สุดของรอบนี้)**: revert fix ชั่วคราวในไฟล์จริงของ worktree (เอา `onChanged: (_) => setState(() {})` ออกจาก `MentionInput` ใน `create_drop_screen.dart`) แล้วรันเทส `create_drop_screen_test.dart --plain-name "system back (PopScope) with unsaved content shows the same discard dialog as the close button"` (เทสที่ใช้ `enterText` พิมพ์ caption ธรรมดา ไม่มี `@mention` เลย ตรงกับที่ Coding รายงาน) — **RED จริง**: `Expected: exactly one matching candidate / Actual: Found 0 widgets with text "ทิ้งการเปลี่ยนแปลง?"` (dialog ไม่ขึ้นเลย ยืนยัน system back หลุดออกไปเงียบๆ ตรงกับ finding ของ Coding เป๊ะ) — restore ไฟล์กลับ (diff กับต้นฉบับเป็น 0 บรรทัด ยืนยัน revert สะอาด) รันซ้ำ — **GREEN**: ผ่าน — สรุปว่าบั๊กเป็นบั๊กจริงและ fix แก้ได้จริง ไม่ใช่แค่รายงานที่ยังไม่ได้ยืนยัน
8. **R2 — edge case: มีแค่รูป ไม่มี caption**: เขียน test อิสระเอง (เลือกรูปอย่างเดียว ไม่พิมพ์อะไรเลย แล้วกด system back ผ่าน `navigatorKey`) — dialog ขึ้นจริง (รูปอย่างเดียวก็นับเป็น unsaved content ตาม `_hasUnsavedContent`'s OR logic), กด "ยกเลิก" กลับมาหน้าเดิมรูปยังอยู่, กด "ทิ้ง" ออกจริง — ผ่านทั้งหมด
9. **R2 — edge case: มีทั้ง caption และรูป**: ครอบคลุมโดยอ่านโค้ด (`_hasUnsavedContent` เป็น OR ธรรมดา ทดสอบแยกทั้งสอง operand ด้านบนแล้วเพียงพอที่จะยืนยัน logic รวม) และ test ที่ Coding ส่งมา (publish success ใช้ทั้ง caption+รูปพร้อมกัน ผ่าน)
10. **R2 — edge case: ระหว่าง publish (`_isSharing`)**: ยืนยันด้วยเทสของ Coding ("while sharing, the close button is disabled and system back is blocked silently instead of showing the dialog") + อ่านโค้ดตรง — บล็อกเงียบๆ จริง ไม่มี dialog ซ้อน ปุ่ม X disable
11. **R2 — edge case: publish สำเร็จแล้ว dialog ต้องไม่ขึ้นอีก**: ยืนยันด้วยเทสของ Coding ("a successful publish closes the composer without hitting the discard dialog") — ผ่าน; ยืนยันเพิ่มด้วยการอ่าน design decision ว่าไม่มีการเก็บ draft ลงดิสก์เลยตั้งแต่ต้น (สถาปัตยกรรมเลือกไม่ persist) จึง AC "publish แล้ว draft ถูกล้างทิ้ง" เป็นจริงโดยธรรมชาติ ไม่ใช่ gap
12. **R2 — edge case เพิ่มเติมที่ทดสอบเอง: double system-back อย่างรวดเร็วขณะมีเนื้อหาค้าง**: เขียน test อิสระยิง `maybePop()` สองครั้งติดกันโดยไม่รอ frame ระหว่างกลาง — dialog ขึ้นแค่ใบเดียว ไม่ stack ซ้อนกัน (ไม่พบบั๊ก double-dialog)
13. **R3 — อ่านโค้ดจริง** (`fullscreen_image_viewer.dart`, `drop_detail_screen.dart`): ยืนยัน `InteractiveViewer(minScale: 1.0, maxScale: 4.0)`, double-tap zoom toggle 1.0x↔3.0x centered ที่จุดแตะด้วย `Matrix4` คำนวณถูกต้อง, animate ด้วย `AnimationController` 200ms, `Scaffold(backgroundColor: Colors.black)` ไม่มี `AppBar`, ปุ่มย้อนกลับ `IconButton(Icons.arrow_back)` ลอยใน `SafeArea` พร้อม scrim วงกลมโปร่งแสง (ไม่ใช่ Liquid Glass), `DropDetailScreen` ห่อเฉพาะ `Image.network` ด้วย `GestureDetector`+`Semantics(label: 'ดูรูปเต็มจอ')` (ไม่ใช่ทั้ง header block), เปิดด้วย `MaterialPageRoute(fullscreenDialog: true, ...)` — ตรงตาม Design Components ทุกข้อ
14. **R3 — integration gap ที่พบเอง**: เทสที่ Coding ส่งมา (`fullscreen_image_viewer_test.dart`) ทดสอบ `FullscreenImageViewer` แบบ isolated เท่านั้น (push ผ่านปุ่ม "open" ปลอม) — **ไม่มีเทสถาวรที่แตะเส้นทางจริงจาก `DropDetailScreen`'s `_openFullscreenViewer()`/`GestureDetector` จริง** ทั้งที่ Design Handoff ระบุไว้ตรงๆ ว่าต้องมี ("แตะรูปเปิด FullscreenImageViewer จริง (ยืนยัน route ใหม่ปรากฏ)") — เขียน widget test ชั่วคราวเองยืนยัน**การทำงานจริงถูกต้อง 100%**: แตะ `Semantics(label: 'ดูรูปเต็มจอ')` ใน `DropDetailScreen` เปิด `FullscreenImageViewer` จริงพร้อม `imageUrl` ตรงกับ `Drop.imageUrl`, ปุ่มย้อนกลับปิดกลับมา `DropDetailScreen` เดิม ไม่ crash — ฟังก์ชันทำงานถูกต้อง เป็นแค่ **gap ของ test coverage ถาวร ไม่ใช่ bug ของ functionality** (ดู Recommendation)
15. **R3 — memory leak / dispose() check**: อ่านโค้ด `dispose()` ยืนยัน `_animationController.dispose()` + `_transformationController.dispose()` ครบทั้งคู่ — เขียน test อิสระเพิ่มเติม: pop หน้าจอออกขณะ double-tap-zoom animation (200ms) ยังไม่จบ (pop กลางคันที่ ~20ms) แล้ว pump ต่อเกินระยะเวลา animation เดิม — ไม่มี exception ใดๆ (`tester.takeException()` เป็น `null`) ไม่มี "used after being disposed"/"setState() called after dispose()" — ยืนยันไม่มี memory leak จริง
16. ไล่ Acceptance Criteria ทั้ง 5 ข้อแยกกันครบ: (1) JPEG ไม่ใช่ PNG หลัง crop เล็กลงมีนัยสำคัญคุณภาพยังดี — ผ่าน (ข้อ 3-5), (2) ออกจาก composer ที่มีเนื้อหาค้างต้องถามยืนยัน — ผ่าน (ข้อ 6-10, 12), (3) publish สำเร็จ draft ถูกล้างทิ้งไม่ค้าง — ผ่านโดยธรรมชาติของสถาปัตยกรรม (ข้อ 11), (4) แตะรูปเปิด Fullscreen Viewer ซูมได้ปิดกลับมาได้ไม่ crash — ผ่าน (ข้อ 13-15), (5) `flutter analyze`/`flutter test` ผ่านครบไม่มี regression กับ WYN-005/WYN-019 — ผ่าน (ข้อ 1-2, ไม่มี regression ใน 396 เทสทั้งหมดซึ่งรวม WYN-005/WYN-019's เทสเดิมด้วย)

Passed: 16/16
Failed: 0

Severity: -

Reproduction Steps (ของ regression proof หลักที่ทำเอง — ข้อ 7): (1) revert `onChanged: (_) => setState(() {})` ออกจาก `MentionInput` ใน `create_drop_screen.dart` (2) เปิด `CreateDropScreen`, พิมพ์ caption ธรรมดาไม่มี `@mention` (3) เรียก system back ผ่าน `navigatorKey.currentState!.maybePop()` (จำลอง Android hardware back/iOS swipe-back)

Expected: dialog "ทิ้งการเปลี่ยนแปลง?" ต้องปรากฏก่อนออกจากหน้าจอเสมอเมื่อมีเนื้อหาค้าง

Actual (ก่อนแก้/บั๊กเดิม): หน้าจอปิดตรงๆ โดยไม่มี dialog เลย (`find.text('ทิ้งการเปลี่ยนแปลง?')` = 0 widgets) — ยืนยันแล้วว่า fix (`onChanged: (_) => setState(() {})`) แก้ปัญหานี้ได้จริง ไม่ใช่แค่ Coding รายงานเฉยๆ

Security Findings: ไม่มีจุดที่แตะ auth/authorization/API/secret ใหม่ — R1 เป็น client-side image encoding ล้วนๆ ไม่มี backend change, R2 ไม่มี local/remote persistence ใดๆ (ตัดสินใจไม่ทำ draft persistence ตั้งแต่ design), R3 เป็น view-only widget ไม่มี state ที่ต้อง secure ตรวจโค้ดที่เปลี่ยนแปลงทั้งหมดแล้วไม่มี secret หลุด

Recommendation:
- **ไม่ block, แนะนำเป็น fast-follow**: เพิ่มเทสถาวรใน `drop_detail_screen_test.dart` ที่แตะเส้นทางจริงจาก `_openFullscreenViewer()` (ไม่ใช่แค่ทดสอบ `FullscreenImageViewer` แบบ isolated ใน `fullscreen_image_viewer_test.dart`) ตามที่ Design Handoff ระบุไว้ตรงๆ — QA ยืนยันแล้วว่าฟังก์ชันทำงานถูกต้อง 100% ด้วย widget test ชั่วคราวที่เขียนเองแล้วลบทิ้ง (ดู ข้อ 14) จึงไม่ใช่ bug ของ WYN-025 แต่เป็น test-coverage gap ที่ควรปิดในรอบถัดไป เหมือน pattern ที่เคยเจอใน WYN-013 (tap-to-profile) และ WYN-012 (badge-refresh)
- เห็นด้วยกับ Non-goal ของ Design ที่ยังไม่ทำ `CreatePopScreen`'s exit guard (บันทึกไว้แล้วเป็น fast-follow แยกในเอกสาร)
- ยืนยันซ้ำเรื่อง process: repository directory ถูกใช้งานพร้อมกันโดย agent อื่น (WYN-024) ระหว่าง session นี้จริง — ป้องกันสำเร็จด้วย `git worktree` ตาม pattern ที่บันทึกไว้จาก WYN-023's QA round แล้ว ไม่มีปัญหาเกิดขึ้นจริงรอบนี้

Final Status: PASS
