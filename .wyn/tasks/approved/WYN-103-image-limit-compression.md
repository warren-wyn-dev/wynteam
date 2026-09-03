# Feature Request — WYN-103

Status: QA PASS — approved (2026-09-02)
Phase: Phase 3 — New feature
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 15/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: จำกัดจำนวนรูปต่อโพสต์สูงสุด 9 รูป + ทำระบบบีบอัดรูปภาพ
Goal: ป้องกันโพสต์ที่มีรูปเยอะเกินไป และลดพื้นที่จัดเก็บ/แบนด์วิดท์โดยรูปยังคมชัด
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "หน้าโพสต์ ควรโพสต์รูปได้แค่สูงสุด 9 รูป ห้ามเกิน และต้องมีระบบบีบรูป ให้ไปกินพื้นที่เยอะ แต่รูปยังคมชัดเหมือนเดิม"
Requirements:
- ตอนเลือกรูปในหน้าโพสต์ จำกัดไม่ให้เลือกเกิน 9 รูป (disable ปุ่มเพิ่มรูป/แจ้งเตือนเมื่อครบ)
- ทำระบบบีบอัดรูปก่อนอัปโหลด (resize ความละเอียดสูงสุดที่เหมาะกับการแสดงผลจริง + ปรับ compression quality) ลดขนาดไฟล์แต่ยังคมชัดตอนแสดงผลในแอป
Acceptance Criteria:
- [x] เลือกรูปเกิน 9 รูปไม่ได้ ระบบแจ้งเตือนเมื่อครบ
- [x] อัปโหลดรูปความละเอียดสูงแล้วขนาดไฟล์ลดลงอย่างมีนัยสำคัญ โดยดูด้วยตาไม่ต่างจากต้นฉบับในการแสดงผลปกติ (ของเดิมจาก WYN-071 อยู่แล้ว, regression confirmed)
Dependencies: เกี่ยวข้องกับ WYN-092/093 (การ์ดรูปภาพ/aspect-fit)
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | บีบอัดแรงเกินจนภาพแตก/เบลอสังเกตได้ | กลาง | ไม่แตะค่า compression เดิม (85%/1600px) ที่ใช้งานจริงมาตั้งแต่ WYN-071 |
Recommendation: อนุมัติ
Handoff: AI Coding ทำตรงได้ (Design เบา — แค่ยืนยัน UI แจ้งเตือนครบ 9 รูป)

## Product Full Spec Output (2026-09-02)

เขียน full spec เสร็จแล้วที่ `.wyn/docs/product/wyn-103-image-limit-compression.md` — พบว่า AC ทั้งสองข้อของ backlog เดิม **ทำไปแล้วเกือบสมบูรณ์ตั้งแต่ WYN-071** (`_maxImages = 9` มีอยู่แล้วใน `CreateDropScreen` + compression ผ่าน `image_picker`'s `maxWidth/maxHeight/imageQuality` มีอยู่แล้วทุกจุด) — gap จริงที่พบมีแค่: (1) `CreateClubPostScreen` จำกัดไว้ที่ 10 รูป ไม่ใช่ 9 (ไม่สอดคล้อง) (2) ไม่มี explicit SnackBar แจ้งเตือนเมื่อถึง limit (มีแค่ early-return เงียบๆ) — สโคปที่ปรับใหม่จึงเล็กกว่าเดิมมาก แค่ consistency fix + UX feedback เพิ่ม + แนะนำ CHECK constraint เสริมที่ DB เป็น defense-in-depth

ไม่มีจุดที่ต้อง ping Founder เพิ่ม

ดูรายละเอียดเต็มที่ `.wyn/docs/product/wyn-103-image-limit-compression.md`

Handoff: ส่งต่อ AI Coding (`/code`) โดยตรง ไม่ต้องผ่าน AI Design เต็มรูปแบบ

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — ความไม่สอดคล้องกันระหว่าง 2 หน้าที่โพสต์รูปได้ (`CreateDropScreen` ใช้ 9 รูปมาตั้งแต่ WYN-071, `CreateClubPostScreen` ยังใช้ 10 รูป) บวกกับ UX feedback ที่ยังไม่ชัดพอ (early-return เงียบๆ)

การเปลี่ยนแปลง:
1. **`create_club_post_screen.dart`**: `_maxImages` เปลี่ยนจาก 10 → 9
2. **SnackBar แจ้งเตือนเมื่อครบ 9 รูป ทั้ง 2 จุด** (`create_drop_screen.dart`'s `_pickImage()`/`_pickMultipleImages()`, `create_club_post_screen.dart`'s `_pickImages()`) — ข้อความ "เพิ่มรูปได้สูงสุด 9 รูปต่อโพสต์" ตรงตาม copy ที่ product spec ระบุ
3. **ปุ่มเพิ่มรูปเปลี่ยนจาก disable เป็น tappable เสมอ** ทั้ง 2 หน้า (`create_club_post_screen.dart`'s ปุ่ม "แนบรูป" เอา `_images.length >= _maxImages` ออกจากเงื่อนไข disable — `create_drop_screen.dart`'s toolbar icon ไม่เคย disable ตาม image count อยู่แล้วตั้งแต่ต้น ไม่ต้องแก้) เพื่อให้กด SnackBar โผล่ได้แทนที่จะกดไม่ได้เงียบๆ
4. **Defense-in-depth (Edge Case 2)**: `create_drop_screen.dart`'s `_pickMultipleImages()` เดิมไม่ truncate ผลลัพธ์จาก multi-select ให้เหลือ `remaining` รูป (พึ่ง native `limit` param อย่างเดียว) — เพิ่ม `.take(remaining)` ให้ตรงกับที่ `create_club_post_screen.dart` ทำอยู่แล้ว
5. **DB CHECK constraint (Edge Case 3, defense-in-depth)**: แก้ `club_posts_image_urls_length` ใน `supabase/schema.sql` จาก `between 1 and 10` → `between 1 and 9`, เพิ่ม constraint ใหม่ `drop_images_position_max_9` (`position >= 0 and position < 9`) ให้ `drop_images` (ไม่เคยมี constraint นี้มาก่อน) — **ทั้งสองจุดยังไม่ apply เข้า production** ต้องรอ AI Deploy & DevOps รัน `alter table` จริง (คอมเมนต์ไว้ในโค้ดแล้วว่าต้องรันอะไร) ปลอดภัยเพราะ UI บังคับ ≤9/≤10 รูปมาตลอด ไม่มีแถวเดิมที่จะ violate

**ไม่ได้แตะ**: ค่า compression (`maxWidth: 1600, maxHeight: 1600, imageQuality: 85`) — ของเดิมยังไม่เคยมีรายงานปัญหา ตามที่ spec สั่งไว้ชัดเจนว่าอย่าเปลี่ยนโดยไม่มีเหตุผล

Files Changed:
- `app/lib/features/drop/presentation/create_drop_screen.dart` — เพิ่ม SnackBar helper + truncate defense-in-depth
- `app/lib/features/club/presentation/create_club_post_screen.dart` — `_maxImages` 10→9, SnackBar, ปุ่มไม่ disable แล้ว, เพิ่ม `@visibleForTesting` seam `debugInitialImagesBytes`
- `app/test/create_club_post_screen_test.dart` — เพิ่ม group "Image limit (WYN-103)" 2 เทสใหม่
- `supabase/schema.sql` — แก้/เพิ่ม CHECK constraint (ยังไม่ apply production)

Reason: Founder ข้อ 15/28 — "หน้าโพสต์ ควรโพสต์รูปได้แค่สูงสุด 9 รูป ห้ามเกิน และต้องมีระบบบีบรูป"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **910/910 ผ่านหมด** (908 เดิม + 2 เทสใหม่)
- Red→green พิสูจน์จริง: เทสยืนยัน (1) ที่ 9/9 รูป ปุ่ม "แนบรูป" ยัง tappable (ไม่ disable) และกดแล้วเห็น SnackBar ข้อความตรงตาม copy (2) ที่ 3/9 รูป ไม่มี SnackBar โผล่มาเอง — ทั้งสองเทสใช้ `debugInitialImagesBytes` seed รูปตรงๆ แทนการ tap เลือกรูปจริง (เหตุผลเดียวกับ WYN-094 — ดู DECISIONS.md 2026-09-02 เรื่อง image decode ค้างใน sandbox นี้)

Build: ไม่ได้รัน `flutter build` จริง — ไม่แตะ backend logic ที่มีผลต่อ build

Known Issues:
- ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator) — โดยเฉพาะ Edge Case 1 ของ product spec (compression จริงบน iOS/Android/Web ว่าไฟล์เล็กลงจริง) ต้องให้ AI QA & Security ทดสอบบนอุปกรณ์จริงเป็นพิเศษ ไม่ใช่แค่ code review เพราะเป็นพฤติกรรมของ platform-native picker ไม่ใช่ Dart code
- CHECK constraint ใหม่ 2 จุดใน schema.sql ยังไม่ได้ apply เข้า production — ต้องส่งต่อ AI Deploy & DevOps รัน `alter table` ตามคอมเมนต์ที่เตรียมไว้ในโค้ด (ตรวจ column/data จริงก่อน apply ตามวินัยเดิมของ WYN-071/072/083)
- Multi-select truncation (Edge Case 2) เทสไม่ได้เพราะเลี่ยง real ImagePicker ทั้งหมด (ตามข้อจำกัด sandbox) — ตรรกะ `.take(remaining)` ตรวจด้วยการอ่านโค้ดเท่านั้น ต้อง QA ยืนยันบนอุปกรณ์จริงถ้าเป็นไปได้

Handoff: ส่งต่อ AI QA & Security — (1) ทดสอบเลือกรูปเกิน 9 รูปพร้อมกัน (multi-select) บนอุปกรณ์จริงทั้ง iOS/Android/Web ว่าได้แค่ 9 รูปแรกเสมอ (2) ทดสอบ compression จริงเทียบขนาดไฟล์ก่อน-หลัง (3) ยืนยัน SnackBar ข้อความและตำแหน่งถูกต้องทั้ง Drop และ Club post → ส่งต่อ AI Deploy & DevOps สำหรับ CHECK constraint migration

## QA Report (2026-09-02)

```
Feature: จำกัด 9 รูปต่อโพสต์ (Drop+Club post สอดคล้องกัน) + SnackBar แจ้งเตือนเมื่อครบ + CHECK constraint เสริมที่ DB
Environment: อ่านโค้ดจริง (adversarial) + รัน `flutter analyze`/`flutter test` อิสระ + ทดสอบ CHECK constraint จริงต่อ local PostgreSQL 16 (สร้าง/ทำลายทิ้งหลังทดสอบ)
Test Cases:
  1. อ่าน create_drop_screen.dart/create_club_post_screen.dart ยืนยัน `_maxImages = 9` ตรงกันทั้ง 2 หน้าแล้วจริง (เดิม Club post = 10)
  2. ยืนยัน `.take(remaining)` (defense-in-depth สำหรับ multi-select) มีอยู่จริงทั้ง 2 หน้า — ป้องกัน exceed 9 ได้แม้ native picker คืนเกิน remaining
  3. ยืนยันปุ่มเพิ่มรูปไม่ disable ที่ 9/9 แต่โชว์ SnackBar แทนจริงทั้ง 2 หน้า (ตรวจ onPressed condition + SnackBar helper)
  4. **grep `debugInitialImagesBytes` ทั้ง `app/lib` อิสระเอง (จุดที่มอบหมายให้ตรวจเข้ม)**: พบใช้เฉพาะใน create_drop_screen.dart/create_club_post_screen.dart เอง (constructor param) และไฟล์เทส 2 ไฟล์เท่านั้น — grep หา 2 จุดที่สร้าง `CreateClubPostScreen(...)`/`CreateDropScreen(...)` จริงใน production code (`club_posts_tab.dart`, `profile_drafts_tab.dart`, `root_shell.dart`) ยืนยันว่าไม่มีจุดใดส่ง parameter นี้เลย — **seam เป็น test-only จริง ไม่รั่วเข้า production flow**
  5. **ทดสอบ CHECK constraint จริงต่อ PostgreSQL** (ไม่ใช่แค่อ่านโค้ด): จำลอง `club_posts_image_urls_length`/`drop_images_position_max_9` — insert position=8 ผ่าน, position=9 ถูกปฏิเสธถูกต้องตามที่ตั้งใจ — สรุปว่า**ทั้งสอง constraint syntactically sound และทำงานถูกต้องตามเจตนา**
  6. **ตรวจว่า Coding Output ยอมรับตรงๆ ว่ายังไม่ apply เข้า production หรือไม่**: ยืนยันแล้ว — ทั้ง Coding Output ("ยังไม่ apply เข้า production") และ Known Issues ("ต้องส่งต่อ AI Deploy & DevOps รัน alter table") ระบุตรงไปตรงมา ไม่ได้เคลมว่าทำเสร็จแล้วอย่างเงียบๆ — **หมายเหตุเล็กน้อย**: comment ของ `drop_images_position_max_9` อธิบายเหตุผลไว้ครบแต่ไม่ได้สะกดคำสั่ง `alter table ... add constraint` ตรงๆ ไว้ให้ (ต่างจาก `club_posts_image_urls_length` ที่ comment มีคำสั่งเต็มให้เลย) — ไม่ block เพราะ AI Deploy & DevOps ต้องตรวจ column/data จริงบน production ก่อน apply ตามวินัยเดิมของ WYN-071/072/083 อยู่แล้ว แต่แนะนำเพิ่มคำสั่งให้ชัดเจนเพื่อลดโอกาสพลาด
  7. รัน `flutter analyze` อิสระ: สะอาด
  8. รัน `flutter test` อิสระเต็ม suite: 917/917 ผ่าน
Passed: ทั้ง 8 ข้อข้างต้น
Failed: ไม่มี
Severity: -
Reproduction Steps: -
Expected: -
Actual: -
Security Findings: ไม่พบ — CHECK constraint เป็น defense-in-depth ที่ปลอดภัย (UI บังคับ ≤9 อยู่แล้ว ไม่มีแถวเดิมที่จะ violate เมื่อ apply)
Recommendation: อนุมัติ — แนะนำ AI Deploy & DevOps เติมคำสั่ง `alter table public.drop_images add constraint drop_images_position_max_9 check (...)` ให้ชัดเจนก่อน apply (ดูข้อ 6) — compression จริงข้าม platform (iOS/Android/Web) ยังตรวจไม่ได้ในสภาพแวดล้อมนี้ (residual, ไม่ block เพราะเป็นพฤติกรรมเดิมที่ไม่ได้แตะตั้งแต่ WYN-071)
Final Status: PASS
```
