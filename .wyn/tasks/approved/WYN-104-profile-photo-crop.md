# Feature Request — WYN-104

Status: design complete, ready for AI Coding (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 18/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่มหน้า Crop รูปโปรไฟล์ (pinch-to-zoom + drag)
Goal: ให้ผู้ใช้ปรับตำแหน่ง/ซูมรูปโปรไฟล์เองก่อนบันทึกจริง แทนที่จะ crop อัตโนมัติแบบเดิม
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "เพิ่มหน้า Crop รูปโปรไฟล์ที่มีวงกลมพรีวิว ให้ผู้ใช้ใช้นิ้วหนีบขยาย/ย่อ (Pinch-to-zoom) และลากขยับรูป (Drag) ให้เข้ามุมที่ต้องการได้เองก่อนกดเซฟ"
Requirements:
- เพิ่มหน้าจอ crop ใหม่ระหว่างเลือกรูปกับบันทึกโปรไฟล์: แสดงวงกลม preview ครอบรูป, รองรับ pinch-to-zoom และ drag ขยับตำแหน่งรูปในกรอบวงกลม
- หลังกด "เซฟ" ค่อย crop รูปจริงตามตำแหน่ง/ซูมที่ผู้ใช้ปรับ แล้วอัปโหลด
Acceptance Criteria:
- [ ] เลือกรูปโปรไฟล์ใหม่แล้วเข้าหน้า crop ทันที ซูม/ลากรูปในวงกลมได้ลื่นไหล
- [ ] กดเซฟแล้วรูปโปรไฟล์ที่บันทึกตรงกับตำแหน่ง/ซูมที่ปรับไว้จริง
Dependencies: ไม่มี
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | Flutter package สำหรับ pinch/drag crop อาจมีข้อจำกัดเรื่อง platform (iOS/Android/Web) | ต่ำ-กลาง | เลือก package ที่ maintain ดีและรองรับทั้ง 3 platform ที่โปรเจกต์นี้ target (`app/web`, android, ios) |
Recommendation: อนุมัติ
Handoff: AI Design (ยืนยัน UI หน้า crop) → AI Coding

## Product Full Spec Output (2026-09-02)

เขียน full spec เสร็จแล้วที่ `.wyn/docs/product/wyn-104-profile-photo-crop.md` — ยืนยันว่าเป็นงานใหม่จริง ไม่มีการ crop จริงในระบบวันนี้เลย (`EditProfileScreen` เก็บรูปดิบตรงๆ วงกลมที่เห็นเป็นแค่ visual clip ของ widget) — เสนอ flow: เลือกรูป → หน้า Crop ใหม่ (pinch-to-zoom+drag ในกรอบวงกลม) → crop จริงก่อนกลับมา preview → อัปโหลดตอนกด "บันทึก" เหมือนเดิม — แนะนำ package `crop_your_image` (pure-Dart) แทน `image_cropper` (native) เพื่อความเข้ากันได้กับ Web ที่โปรเจกต์ target อยู่ด้วย — เพิ่ม edge case สำคัญ: EXIF orientation handling (พบบ่อยกับรูปจากกล้อง iOS) และปุ่ม +/- ซูมสำรองสำหรับ accessibility

ไม่มีจุดที่ต้อง ping Founder เพิ่ม — สโคปตรงตาม backlog เดิมทุกประการ

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-104-profile-photo-crop.md`

Handoff: ส่งต่อ AI Design (`/design`)

## Design Output (2026-09-02)

เขียน design spec เสร็จแล้วที่ `.wyn/docs/design/wyn-104-profile-photo-crop.md` — ยืนยันจาก `app/pubspec.yaml` แล้วว่าไม่มี image-cropping dependency ใดๆ อยู่ในโปรเจกต์วันนี้ (`crop`/`image_cropper`/`crop_your_image` ไม่มีชื่อปรากฏเลย) เป็น dependency ใหม่จริงตามที่ Product spec ระบุ — ออกแบบหน้า Crop เต็มจอใหม่: พื้นหลังเข้ม/ปุ่ม AppBar สีขาว (ข้อยกเว้นสีเดียวของเอกสารนี้ มี precedent อยู่แล้วจาก media viewer เต็มจอของ WYN-071 Screen 4 ไม่ใช่การคิดทิศทางสีใหม่), วงกลม preview กึ่งกลางจอรองรับ pinch-to-zoom+drag, แถบซูมสำรอง +/- บังคับมีสำหรับ accessibility ตาม Product spec Edge Case 5 — คงแนะนำ package `crop_your_image` (pure-Dart) ตาม Product spec แต่ระบุชัดว่า AI Coding ต้องยืนยันซ้ำก่อนติดตั้งจริง

Handoff: ส่งต่อ AI Coding (`/code`)

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — ฟีเจอร์ใหม่ทั้งหมดตรงตามสโคปที่ Design ยืนยันไว้ (ไม่มี crop จริงในระบบมาก่อนเลย ตามที่ Product spec ตรวจยืนยันแล้ว)

การเปลี่ยนแปลง:
1. **`app/lib/features/profile/data/profile_photo_crop.dart`** (ใหม่): pure pan/zoom-to-crop math แยกออกจาก image decode/render โดยเจตนา (`decodeCropImageDimensions`/`baseCropScaleFactor`/`cropDisplaySize`/`centeredCropOffset`/`clampCropOffset`/`computeCropSourceRect`/`cropToCircleSquare`) — ทำให้ตำแหน่ง/ซูมที่ถูกต้อง (Acceptance Criterion 2) พิสูจน์ได้ด้วย plain `test()` ธรรมดา ไม่ต้องพึ่ง widget tree เลย (สำคัญเพราะ sandbox นี้มีข้อจำกัดเรื่อง decode รูปจริงผ่าน widget tree ค้าง ตามที่บันทึกใน DECISIONS.md 2026-09-02) ครอปจริงเป็น dart:ui ล้วน (`ui.instantiateImageCodec` + `Canvas.drawImageRect`) เอาต์พุตเป็น PNG สี่เหลี่ยมจริง ไม่ใช่วงกลมโปร่งใส (ตาม Product spec's "ป้องกันปัญหาพื้นหลังโปร่งใสไม่รองรับทุกที่ที่ใช้รูปนี้" — วงกลมยังเป็นแค่ visual clip เหมือนเดิม)
2. **`app/lib/features/profile/presentation/profile_photo_crop_screen.dart`** (ใหม่): หน้าจอ crop เต็มจอ พื้นดำ วงกลม preview 260×260 กึ่งกลางจอ, `GestureDetector.onScale*` รองรับทั้ง pinch-to-zoom (2 นิ้ว) และ drag (1 นิ้ว) ในตัวเดียวกัน (scale 1.0-3.0, offset clamp ไม่ให้เห็นขอบว่าง), แถบซูมสำรอง +/- และ `Slider` สำหรับ accessibility (Product spec Edge Case 5) — **ตัดสินใจไม่ติดตั้ง `crop_your_image`** ตามที่ Design spec ขอให้ยืนยันซ้ำก่อนติดตั้งจริง: ใช้ `GestureDetector` เปล่า + math จากไฟล์ข้อ 1 แทน เพราะแอปมี pinch-to-zoom precedent ที่ทำงานจริงแล้วอยู่แล้ว (`InteractiveViewer`, WYN-071) ไม่มี dependency ใหม่ที่ต้องแบกรับความเสี่ยง platform-support (Product spec Risk R1) — เป็นการเปลี่ยนแปลงที่เล็กกว่า/ปลอดภัยกว่า EXIF orientation ไม่ต้องเขียนโค้ดแก้เอง เพราะ `dart:ui`'s Skia decoder จัดการอัตโนมัติอยู่แล้ว (ยังไม่ได้ verify บนอุปกรณ์จริงเพราะไม่มี camera/simulator ใน sandbox — flag ให้ QA ตาม Product spec Risk R2)
3. **`app/lib/features/profile/presentation/edit_profile_screen.dart`**: `_pickImage()` เปลี่ยนจาก set `_pickedImageBytes` ตรงๆ เป็น push `ProfilePhotoCropScreen` ก่อนเสมอ (ระหว่างเลือกรูปกับบันทึกโปรไฟล์ ตาม Requirements) — ยกเลิกหน้า crop (pop `null`) ทำให้ avatar เดิมไม่เปลี่ยนแปลงเลย (Product spec Edge Case 1) ผลลัพธ์ที่ crop เสร็จเป็น PNG เสมอ (`_pickedImageExtension = 'png'`)

Files Changed:
- `app/lib/features/profile/data/profile_photo_crop.dart` (ใหม่)
- `app/lib/features/profile/presentation/profile_photo_crop_screen.dart` (ใหม่)
- `app/lib/features/profile/presentation/edit_profile_screen.dart`
- `app/test/profile_photo_crop_test.dart` (ใหม่) — 12 เทส: math ล้วนๆ (scale/offset/clamp) + end-to-end กับ pixel จริงที่ decode แล้ว (quadrant-color PNG พิสูจน์ตำแหน่ง crop ถูกจริง ไม่ใช่แค่ขนาด)
- `app/test/profile_photo_crop_screen_test.dart` (ใหม่) — 6 เทส: AppBar/zoom bar, ยกเลิก pop null, +/- clamp, slider, crop failure error state, load failure error state — ใช้ `@visibleForTesting debugInitialDimensions` seam + invalid bytes + `tester.takeException()` (pattern เดียวกับ WYN-094 ที่บันทึกไว้แล้วใน DECISIONS.md เพราะ decode รูปจริงผ่าน widget tree ค้างใน sandbox นี้)

Reason: Wynos V1.0.0 Beta2.pdf ข้อ 18/28 — Founder: "เพิ่มหน้า Crop รูปโปรไฟล์ที่มีวงกลมพรีวิว ให้ผู้ใช้ใช้นิ้วหนีบขยาย/ย่อ และลากขยับรูปให้เข้ามุมที่ต้องการได้เองก่อนกดเซฟ"

Tests:
- `flutter analyze`: สะอาด (No issues found!)
- `flutter test`: **938/938 ผ่านหมดทั้งโปรเจกต์** (รวม 18 เทสใหม่ของ WYN-104)

Build: ไม่ได้รัน `flutter build` จริง (ไม่มี Android SDK/Xcode ใน session นี้)

Known Issues:
- EXIF orientation (Product spec Edge Case 3) พึ่ง Skia decoder อัตโนมัติ ยังไม่ได้ verify บนอุปกรณ์จริง/รูปจากกล้อง iOS จริง (ไม่มี camera/simulator ใน sandbox)
- Pinch-to-zoom gesture จริงบนอุปกรณ์สัมผัสจริงยังไม่ได้ทดสอบ (widget test ทดสอบได้แค่ผ่าน `_setScale`/slider โดยตรง ไม่ได้ simulate multi-touch gesture จริง)
- ทั้งสอง Acceptance Criteria ผ่านตามที่ตรวจสอบได้ในทางเทคนิค (unit test พิสูจน์ position math ถูกต้องจริงด้วย pixel sampling) แต่ยังไม่ผ่านการทดสอบบนอุปกรณ์จริง

Handoff: ส่งต่อ AI QA & Security — (1) ทดสอบ pinch-to-zoom/drag บนอุปกรณ์สัมผัสจริง (iOS/Android/Web) ลื่นไหลจริงตาม Acceptance Criterion 1 (2) ยืนยันรูปที่ crop จริงตรงกับตำแหน่ง/ซูมที่ปรับ (Acceptance Criterion 2) บนอุปกรณ์จริง ไม่ใช่แค่ unit test (3) ทดสอบ EXIF orientation ด้วยรูปจากกล้อง iOS จริง (Risk R2) (4) ยืนยัน "ยกเลิก" ไม่กระทบ avatar เดิมเลย

## QA Report (2026-09-03)

```
Feature: WYN-104 — Profile Photo Crop screen (pinch-to-zoom + drag, วงกลม preview)
Environment: Static/adversarial code review ของ commit 40cafac บน claude/wynos-beta2-phase2-handoff-w4mi5m (worktree ยืนยันตรง base แล้ว) — อ่าน `profile_photo_crop.dart`/`profile_photo_crop_screen.dart`/`edit_profile_screen.dart` เต็มไฟล์ + รัน `flutter analyze`/`flutter test` อิสระ ไม่มี simulator/emulator/อุปกรณ์สัมผัสจริงใน sandbox นี้เช่นกัน (ตรงตามที่ Coding Output ระบุไว้แล้ว) — ยืนยันว่าใช้ pattern `@visibleForTesting` seam + invalid-bytes + `tester.takeException()` ตามที่ `.wyn/company/DECISIONS.md` (2026-09-02, "พบข้อจำกัดใหม่ของ sandbox") บันทึกไว้ว่าเป็น workaround ที่ถูกต้อง ไม่ใช่ shortcut ที่ต้อง flag
Test Cases:
  1. ยืนยัน `profile_photo_crop.dart` เป็น pure math ล้วน (ไม่มี widget tree/`ui.instantiateImageCodec` ใน hot path ของการคำนวณตำแหน่ง) แยกออกจาก image decode/render ตามที่ตั้งใจ — `baseCropScaleFactor`/`cropDisplaySize`/`centeredCropOffset`/`clampCropOffset`/`computeCropSourceRect` ตรวจ math ด้วยมือ: ถูกต้องตามคณิตศาสตร์ (scale factor จาก shorter side, offset คำนวณจาก (viewportSize - displaySize)/2, clamp ป้องกันเห็นขอบว่างเมื่อ scale >= 1.0 เสมอเพราะ minDx/minDy <= 0 เสมอ)
  2. ยืนยัน `cropToCircleSquare()` มี defensive clamp กัน floating-point rounding ที่ขอบ (`maxLeft`/`maxTop`) ก่อนตัดจริงด้วย `Canvas.drawImageRect` — ป้องกัน crash จาก source rect เกินขอบภาพจริง
  3. ยืนยัน output เป็น PNG สี่เหลี่ยมจัตุรัสจริง (ไม่ใช่วงกลมโปร่งใส) ตรงตาม Product spec's เหตุผลป้องกันปัญหาพื้นหลังโปร่งใส — วงกลมยังเป็นแค่ visual clip เหมือนเดิม ไม่เปลี่ยนพฤติกรรมเดิมของระบบที่ใช้รูปนี้ที่อื่น
  4. รัน `flutter test test/profile_photo_crop_test.dart` อิสระ: **13/13 ผ่าน** รวมเทส end-to-end กับ pixel จริงที่ decode แล้ว (quadrant-color PNG พิสูจน์ตำแหน่ง crop ถูกต้องจริงทั้ง 3 กรณี: centered 1.0x, pan ไปมุมซ้ายบน, pan ไปมุมขวาล่าง) — พิสูจน์ Acceptance Criterion 2 ("รูปที่บันทึกตรงกับตำแหน่ง/ซูมที่ปรับไว้จริง") ด้วยข้อมูลจริงระดับ pixel ไม่ใช่แค่ทฤษฎี
  5. รัน `flutter test test/profile_photo_crop_screen_test.dart` อิสระ: **6/6 ผ่าน** รวม AppBar/zoom bar, ยกเลิก pop null, +/- ปุ่ม clamp, slider, crop failure error state (ไม่ crash), load failure error state (ไม่ crash/ไม่ spinner ค้าง) — ใช้ seam `debugInitialDimensions` + invalid bytes + `tester.takeException()` ตามที่คาดหวังจาก DECISIONS.md จริง
  6. ยืนยัน `edit_profile_screen.dart`'s `_pickImage()`: push `ProfilePhotoCropScreen` ก่อนเสมอหลังเลือกรูป, `if (cropped == null || !mounted) return;` gate การ `setState` ไว้ถูกต้อง — ยกเลิกหน้า crop (pop null) ทำให้ `_pickedImageBytes`/avatar เดิมไม่ถูกแตะเลยจริง (อ่านโค้ดยืนยันตรง ไม่มี side-effect ก่อน guard)
  7. ยืนยัน `_pickedImageExtension = 'png'` ถูกตั้งค่าคู่กับ cropped bytes เสมอ ตรงกับที่ `cropToCircleSquare` เข้ารหัส PNG เสมอ (ไม่มี mismatch ระหว่างนามสกุลไฟล์ที่ประกาศกับ format จริงที่อัปโหลด)
  8. ตรวจ `app/pubspec.yaml`: ยืนยันไม่มี dependency ใหม่ถูกเพิ่ม (ตัดสินใจไม่ติดตั้ง `crop_your_image` ตามที่ Coding Output ระบุ ใช้ `GestureDetector`/`dart:ui` ล้วน) — ลด attack surface/platform-support risk ตรงตาม Risk R1 ของ Product spec ที่กังวลเรื่อง package ข้าม platform
  9. รัน `flutter analyze`: สะอาด, `flutter test` เต็ม suite: 1011/1011 ผ่าน
Passed: ข้อ 1-9
Failed: ไม่มี
Severity: N/A (PASS)
Reproduction Steps: N/A
Expected: N/A
Actual: N/A
Security Findings: ไม่มี (ฟีเจอร์ client-side ล้วน ไม่แตะ schema/RLS/authentication/API key ใดๆ)
Recommendation: อนุมัติเข้า approved — Known Issues ที่ Coding Output เปิดค้างไว้ (pinch-to-zoom gesture จริงบนอุปกรณ์สัมผัส, EXIF orientation จากกล้อง iOS จริง) เป็นข้อจำกัดของ sandbox ที่บันทึกไว้แล้วใน DECISIONS.md ไม่ใช่จุดที่ QA ควร FAIL เพราะ math/position ถูกพิสูจน์ถูกต้องแล้วด้วย pixel sampling จริง — แนะนำให้ Founder/AI Deploy ทดสอบ pinch-to-zoom + รูปจากกล้อง iOS จริงบนอุปกรณ์จริง 1 รอบก่อนประกาศ feature พร้อมใช้งานเต็มรูปแบบ (ไม่ใช่ pre-deploy blocker ระดับ backend เพราะไม่มี schema/migration ในงานนี้เลย)
Final Status: PASS
```
