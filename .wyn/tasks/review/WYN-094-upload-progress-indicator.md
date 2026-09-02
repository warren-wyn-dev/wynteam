# Feature Request — WYN-094

Status: coded, awaiting QA (2026-09-02)
Phase: Phase 2 — UI redesign
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 20/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่ม progress indicator ระหว่างกำลังโพสต์ (แสดง % กำลังอัปโหลด)
Goal: ผู้ใช้รู้ว่าระบบกำลังทำงานอยู่ระหว่างโพสต์ ไม่ใช่แอปค้าง
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "อยากให้ตอนกดโพสต์ มีลูกเล่นนิดหน่อย ให้รู้ว่าโพสต์กำลังลง โหลดได้กี่เปอร์เซ็นละ"
Requirements:
- เพิ่ม progress indicator (เช่น progress bar/percentage) ระหว่างอัปโหลดรูป/ข้อความไปเซิร์ฟเวอร์หลังกดปุ่ม "โพสต์"
- จัดการ error state ถ้าโพสต์ไม่สำเร็จระหว่างทาง (แจ้งเตือน + ให้ retry)
Acceptance Criteria:
- [x] กดโพสต์ที่มีรูปแล้วเห็น progress ระหว่างอัปโหลดจริง ไม่ใช่ loading spinner เฉยๆ
- [x] โพสต์เสร็จแล้วปิด progress และกลับไปหน้าฟีดพร้อมโพสต์ใหม่
Dependencies: ไม่มี
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | คำนวณ % จริงยากถ้า backend ไม่ report ความคืบหน้า | ต่ำ-กลาง | **ปิดแล้ว**: ใช้ "จำนวนรูปที่ upload เสร็จ/ทั้งหมด" เป็นความคืบหน้าจริง (ไม่ใช่ค่าเดา) ตามที่ risk mitigation เสนอไว้ |
Recommendation: อนุมัติ
Handoff: AI Coding ทำตรงได้ (Design เบา — แค่ยืนยันสไตล์ progress indicator)

---

## Design Output (2026-09-02)

ยืนยันสไตล์: แถบ `LinearProgressIndicator` บาง (sapphire fill/hairline track) + ข้อความ % ใต้ AppBar ของ `CreateDropScreen` เฉพาะตอนโพสต์มีรูป (โพสต์ข้อความล้วน/Poll ไม่แสดงแถบ เพราะเร็วเกินกว่าจะมีความหมาย) — Supabase storage client ไม่มี byte-level progress callback ให้ใช้จริงตามที่ Risk คาดไว้ จึงคำนวณ % จาก "จำนวนรูปที่ upload เสร็จ/ทั้งหมด" (ความคืบหน้าจริง ไม่ใช่ค่าเดา) สปินเนอร์ในปุ่มเดิมยังคงไว้ ไม่มีปุ่ม retry ใหม่ (ปุ่มเดิมกลับมา enable เองอยู่แล้วหลัง error)

Design doc เต็ม: `.wyn/docs/design/wyn-094-upload-progress-indicator.md`

**ไม่มีอะไรบล็อก — พร้อมขึ้นโค้ดทันที**

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — เพิ่ม progress bar ใหม่ตาม design spec ที่ underlying data (จำนวนรูป upload เสร็จ) มีอยู่แล้วบางส่วนในโค้ด (loop upload รูปทีละใบ) แค่ยังไม่ report ความคืบหน้าออกมาให้ UI เห็น

การเปลี่ยนแปลง:
1. **`DropRepository.createDrop()`** (`app/lib/features/drop/data/drop_repository.dart`) — เพิ่ม parameter ใหม่ `void Function(int uploaded, int total)? onImageUploaded` เรียกหลัง upload แต่ละรูปเสร็จจริงภายใน loop ที่มีอยู่แล้ว (1-based `uploaded`, ไม่ใช่ byte-level แต่เป็นความคืบหน้าจริงระดับ "รูปไหนเสร็จแล้วบ้าง" ตามที่ design doc ตัดสินใจไว้)
2. **`CreateDropScreen`** (`app/lib/features/drop/presentation/create_drop_screen.dart`) — เพิ่ม state `int _uploadedImageCount` รีเซ็ตเป็น 0 ทุกครั้งที่เริ่ม `_share()`, ส่ง `onImageUploaded` callback เข้า `createDrop()` เพื่ออัปเดต state — เพิ่ม widget ใหม่ `_buildUploadProgress()` (แถบ `LinearProgressIndicator` สูง 3px สี sapphire/hairline + ข้อความ "กำลังอัปโหลด N/total รูป... X%") วางทันทีใต้ header/Divider แสดงเฉพาะเมื่อ `_isSharing && _imagesBytes.isNotEmpty` ตรงตามเงื่อนไขที่ design doc ระบุ (โพสต์ไม่มีรูป/Poll ไม่แสดงแถบเลย)
3. Semantics label ครอบแถบทั้งก้อนตามที่ accessibility section ของ design doc กำหนด

**ไม่ได้แตะ**: logic การ share อื่นๆ, ปุ่ม retry (reuse ปุ่ม "โพสต์" เดิมที่กลับมา enable เองหลัง error ตามที่ design doc ตัดสินใจไม่ต้องมีปุ่มใหม่)

Files Changed:
- `app/lib/features/drop/data/drop_repository.dart` — เพิ่ม `onImageUploaded` callback param ให้ `createDrop()`
- `app/lib/features/drop/presentation/create_drop_screen.dart` — เพิ่ม `_uploadedImageCount` state, widget แถบ progress ใหม่, เพิ่ม `@visibleForTesting` seam `debugInitialImagesBytes` (ดู Known Issues)
- `app/test/support/recording_drop_repository.dart` — เพิ่ม `imageUploadGate` (optional, สำหรับเทสคุม timing ของแต่ละรูปทีละใบ) และรองรับ `onImageUploaded` callback ใน fake
- `app/test/create_drop_screen_test.dart` — เพิ่ม group "Upload progress (WYN-094)" 3 เทสใหม่ + ย้าย repo ที่ใช้เข้า `setUpAll` (ดู Known Issues เรื่อง timer-leak pattern)

Reason: Founder ข้อ 20/28 — "อยากให้ตอนกดโพสต์ มีลูกเล่นนิดหน่อย ให้รู้ว่าโพสต์กำลังลง โหลดได้กี่เปอร์เซ็นละ"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **908/908 ผ่านหมด** (905 เดิม + 3 เทสใหม่)
- Red→green พิสูจน์จริง: เขียนเทสก่อน implementation จริง (TDD) — 3 เทสยืนยัน (1) แถบ progress โผล่พร้อม % ที่ขยับตามจำนวนรูปที่ mock ให้ resolve ทีละใบ (ผ่าน `Completer` gate ใน `RecordingDropRepository`) แล้วหายไปหลังสำเร็จ (2) โพสต์ไม่มีรูป → ไม่มีแถบเลยตลอด flow (3) error → แถบหายไป ปุ่ม "โพสต์" กลับมา enable

Known Issues:
- **ไม่สามารถเทสผ่าน flow การเลือกรูปจริงได้ (`image_picker`)**: พบว่า `image_picker`'s default `MethodChannelImagePicker` instance ค้าง (hang) เมื่อถูกเรียกใน widget test ภายใต้ `AutomatedTestWidgetsFlutterBinding` ของ sandbox นี้ — พิสูจน์แล้วด้วยการแยกทดสอบอย่างละเอียด (isolate ปัญหาจนเหลือแค่ "ตั้งค่า `ImagePickerPlatform` fake + pump widget เปล่าๆ" ก็ค้างแล้ว ทั้งที่ลำดับคำสั่งเดียวกันเป๊ะรันผ่าน plain `test()` ได้ทันที) และแยกอีกชั้นพบว่าจริงๆ แล้วเป็นปัญหาที่กว้างกว่านั้น: **การ decode รูปจริงที่ถูกต้องผ่าน widget tree (`Image.memory`) เองก็ค้างเหมือนกัน ไม่ใช่แค่ `image_picker`** (bytes ปลอมที่ decode ไม่ผ่านกลับ fail เร็วแทน) — สรุปว่าเป็นข้อจำกัดของ sandbox environment นี้เอง (software rendering) ไม่ใช่บั๊กของโค้ดที่เขียน จึงเพิ่ม `@visibleForTesting` seam `debugInitialImagesBytes` ใน `CreateDropScreen` (ไม่ถูกใช้จาก production code เลย) เพื่อ seed `_imagesBytes` ตรงๆ แทนการ tap ปุ่มเลือกรูปจริง — เทสจึงพิสูจน์ครบทุกอย่างของ WYN-094 เอง (progress bar/percentage/visibility) แต่**ไม่ครอบคลุม flow "เลือกรูปจริงแล้วเห็น progress"** อันนี้ต้องให้ AI QA & Security ทดสอบบนอุปกรณ์จริงแทน
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator ในสภาพแวดล้อมนี้ — ตาม pattern เดิมของทุกงานก่อนหน้า)
- % ที่แสดงคำนวณจาก "จำนวนรูปเสร็จ/ทั้งหมด" ไม่ใช่ byte-level จริง — โพสต์รูปเดียวจะกระโดดจาก 0%→100% ทันที (ตามที่ design doc ยอมรับไว้แล้วว่าเป็น trade-off ที่ยอมรับได้)

Handoff: ส่งต่อ AI QA & Security — (1) ทดสอบ flow จริงบนอุปกรณ์: เลือกรูป 1 และหลายรูปแล้วกดโพสต์ ดูว่าแถบ progress ขึ้นจริงและขยับตามจำนวนรูป (2) ทดสอบโพสต์ข้อความล้วน/Poll → ต้องไม่มีแถบเลย (3) ทดสอบ error (เช่น ปิด network กลางทาง) → แถบหายไป ปุ่มกลับมากดซ้ำได้ (4) สังเกตว่า % ไม่ได้ smooth แบบ byte-level เป็นพฤติกรรมที่ตั้งใจ ไม่ใช่บั๊ก
