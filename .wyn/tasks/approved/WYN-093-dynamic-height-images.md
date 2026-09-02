# Feature Request — WYN-093

Status: QA PASS — approved (2026-09-02)
Phase: Phase 2 — UI redesign
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 19/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: ปรับการแสดงผลรูปในฟีดให้ยึดสัดส่วนจริงของภาพ (Dynamic Height / Aspect Fit)
Goal: รูปในฟีดแสดงเต็มภาพจริง ไม่ถูกครอบตัดขอบบน-ล่างจากการล็อกความสูงการ์ด
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "ปรับการแสดงผลรูปในฟีดให้อิงตามสัดส่วนจริงของรูปภาพ (Dynamic Height / Aspect Fit) โดยไม่ล็อกความสูงของการ์ด เพื่อไม่ให้รูปถูกครอบตัดขอบบน-ล่าง และแสดงรูปเต็มรูปได้ทันทีในฟีด"
Requirements:
- เปลี่ยนจาก fixed-height image container เป็นคำนวณความสูงการ์ดจาก aspect ratio จริงของรูป (BoxFit.contain หรือคำนวณ ratio เอง ไม่ crop)
- ตรวจ performance การคำนวณ layout แบบ dynamic ในลิสต์ยาว (ListView) ไม่ให้กระตุก
Acceptance Criteria:
- [ ] รูปแนวตั้ง/แนวนอน/สี่เหลี่ยมจัตุรัส แสดงเต็มภาพไม่ถูก crop ขอบบน-ล่างในฟีด
- [ ] scroll ฟีดที่มีรูปหลายสัดส่วนต่อกันไม่กระตุก
Dependencies: เกี่ยวข้องกับ WYN-092 (การ์ดรูปภาพ)
Priority: กลาง
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | ความสูงการ์ดไม่คงที่อาจกระทบ jank ตอน scroll เร็วๆ ถ้าไม่ cache ขนาดภาพไว้ล่วงหน้า | กลาง | cache image dimension ตอนอัปโหลด ไม่ต้องรอโหลดภาพเต็มถึงจะรู้ความสูง |
Recommendation: อนุมัติ
Handoff: AI Design (ยืนยันเกณฑ์ความสูงสูงสุด/ต่ำสุด กันภาพยาวเกินจอ) → AI Coding

---

## Design Output (2026-09-02)

กำหนดเกณฑ์ clamp ตามที่ Product task มอบหมาย: อนุญาต aspect ratio จริง 0.8 (4:5, แนวตั้งสุด) ถึง 1.91 (แนวนอนสุด) โดยไม่ crop, นอกช่วงนี้ crop เข้าขอบ, เพิ่มเพดานเสริม `maxHeight = 0.75 × screen height` กันรูปเดียวครองจอทั้งใบ — ขอบเขตเฉพาะ `HomeDropCard`'s media area เท่านั้น (ไม่แตะ `DropGridTile`/grid โปรไฟล์ที่ตั้งใจให้เป็น 1:1 ตายตัวต่อไป) ต้อง cache ขนาดรูปจริงไว้ตอนอัปโหลด (schema เพิ่ม `image_width`/`image_height`) เพื่อไม่ให้เกิด layout jank ระหว่าง scroll — Drop เก่าที่ไม่มี metadata fallback เป็น 1:1 เดิม ไม่มีภาพอ้างอิงที่ต้องรอ (Product task มอบหมายให้ AI Design ตัดสินใจตัวเลขเอง)

Design doc เต็ม: `.wyn/docs/design/wyn-093-dynamic-height-images.md`

**ไม่มีอะไรบล็อก — พร้อมขึ้นโค้ดทันที**

---

## Coding Output (2026-09-02)

Root cause / สิ่งที่เปลี่ยน: ไม่ใช่บั๊ก — `HomeDropCard`'s media area ล็อก `AspectRatio(aspectRatio: 1)` ตายตัวมาตั้งแต่ต้น ไม่เคยอ่านสัดส่วนจริงของรูป ทำให้รูปแนวตั้ง/แนวนอนถูก `BoxFit.cover` ครอบตัดขอบบน-ล่าง/ซ้าย-ขวาเสมอ Founder ข้อ 19/28 ขอให้ยึดสัดส่วนจริงแทน แก้ตาม AI Design's เกณฑ์ clamp (0.8–1.91 + เพดาน 0.75×screen height) ครบทั้ง 4 ชั้นตามที่ Handoff ระบุ:

1. **Schema (`supabase/schema.sql`)**: เพิ่ม `image_width`/`image_height` (integer, nullable) เข้า `drops` และ `drop_images` (`alter table ... add column if not exists`, idempotentตาม convention เดิมของไฟล์) — อัปเดต `public.home_feed` view **เฉพาะนิยามสุดท้าย/effective ตัวเดียว** (บรรทัด ~10489 เป็นต้นไป จาก 7 นิยามสะสมที่มีอยู่ในไฟล์ — ไม่แตะ 6 นิยามเก่าตามวินัยเดิมที่ WYN-079/083 ใช้) เพิ่มคอลัมน์ `image_width`/`image_height` เป็น **2 คอลัมน์สุดท้ายของทุก branch ใน UNION ALL** (drop/pop/redrop-of-drop) เพราะ `CREATE OR REPLACE VIEW` ของ PostgreSQL ยอมให้ต่อคอลัมน์ใหม่ท้ายสุดเท่านั้น ห้ามแทรกกลาง (ตรงกับ error class ที่ทำให้ schema.sql พังอยู่แล้วตามมติ 2026-09-02 ที่บันทึกไว้ก่อนหน้า — งานนี้ไม่ได้ทำผิดซ้ำ) `get_wynos_ranked_feed()` **ไม่ต้องแก้** เพราะใช้ `to_jsonb(final.*)` ที่ chain มาจาก `select hf.* from home_feed hf` ตลอดสาย คอลัมน์ใหม่ไหลผ่านอัตโนมัติ
2. **`Drop`/`HomeFeedItem` models**: เพิ่ม `imageWidth`/`imageHeight` (nullable int) ทั้งคู่ — `Drop.fromMap` parse จาก `map['image_width']`/`map['image_height']` (ได้มาฟรีเพราะ `_dropSelect` ใช้ `select('*, ...')` จาก `drops` table โดยตรง), `HomeFeedItem.fromMap` parse จาก `home_feed`'s คอลัมน์ใหม่, `HomeFeedItem.fromDrop()`/`.toDrop()` ส่งผ่านค่าทั้งสองทิศทาง (สำคัญเพราะ `HomeDropCard` ถูก reuse ผ่าน `HomeFeedItem.fromDrop(drop)` ใน 3 จุดนอกเหนือจาก Home feed เอง — `profile_drop_grid_tab.dart`/`profile_likes_tab.dart`/`hashtag_feed_screen.dart` ตรวจแล้วด้วย grep — ถ้าไม่เติม field ให้ `Drop` ด้วย 3 จุดนี้จะไม่มีวันได้ dynamic height แม้ Drop จะมี metadata จริงในอนาคต)
3. **`DropRepository`**: เพิ่มไฟล์ใหม่ `image_dimensions.dart` (`decodeImageDimensions()`, ใช้ `dart:ui`'s `instantiateImageCodec` ตัวเดียวกับที่ `square_crop.dart` ใช้อยู่แล้ว ไม่ต้องเพิ่ม dependency) — `createDrop()` decode ขนาดจริงจาก bytes ที่มีอยู่แล้วในหน่วยความจำก่อนอัปโหลด (ไม่มี network round-trip เพิ่ม) ส่งต่อให้ `_insertDrop()` เขียนลง `drops.image_width/height` (รูปแรก/position 0) และ `drop_images.image_width/height` (ทุกรูปตามตำแหน่ง) — `createDropFromExistingImage()` (republish จาก Draft) **ไม่มีขนาดให้ decode** (ไม่มี bytes สดให้วัด) ปล่อยเป็น null ตามที่ design spec ยอมรับไว้แล้วว่าเป็น known gap เดียวกับ Drop เก่า
4. **`HomeDropCard`**: เพิ่มฟังก์ชัน `_feedImageAspectRatio(item)` คำนวณ `(width/height).clamp(0.8, 1.91)` เมื่อมี metadata, fallback เป็น `1` เมื่อไม่มี (Drop เก่า/ไม่มีรูป) — ห่อ `AspectRatio` เดิมด้วย `ConstrainedBox(maxHeight: 0.75 * MediaQuery.of(context).size.height)` เพิ่มเป็นเพดานที่สอง ยังคง `BoxFit.cover`/`Image.network`'s loading/error builder เดิมทุกจุดตาม Design spec ("BoxFit.cover ปลอดภัยกว่า contain เพราะกรอบคำนวณตรงกับรูปจริงแล้ว")

**ขอบเขตที่ไม่แตะ** (ตรงตาม Design spec): `DropGridTile`/`SavedGridTile` (grid โปรไฟล์แบบ 1:1 ตายตัว), `DropDetailScreen` (ไม่ได้อยู่ใน scope ของ Design spec ข้อนี้ — ยังเป็น fixed layout เดิม)

Files Changed:
- `supabase/schema.sql` — เพิ่มคอลัมน์ `image_width`/`image_height` เข้า `drops`/`drop_images`, อัปเดต `home_feed` view definition สุดท้าย (3 branches)
- `app/lib/features/drop/data/drop.dart` — เพิ่ม field/constructor param/copyWith/withEditedCaption/fromMap สำหรับ `imageWidth`/`imageHeight`
- `app/lib/features/home/data/home_feed_item.dart` — เพิ่ม field/constructor/copyWith/toDrop/fromDrop/fromMap สำหรับ `imageWidth`/`imageHeight`
- `app/lib/features/drop/data/image_dimensions.dart` — ไฟล์ใหม่ `decodeImageDimensions()`
- `app/lib/features/drop/data/drop_repository.dart` — `createDrop()` decode ขนาดรูปจริง, `_insertDrop()` เขียนลง `drops`/`drop_images`
- `app/lib/features/home/presentation/widgets/home_drop_card.dart` — เพิ่ม `_feedImageAspectRatio()`, ห่อ media area ด้วย `ConstrainedBox`
- `app/test/image_dimensions_test.dart` — เทสใหม่ 3 เทส (`decodeImageDimensions` ที่ landscape/portrait/square)
- `app/test/home_feed_screen_test.dart` — เพิ่ม `imageWidth`/`imageHeight` เข้า `_dropItem()` fixture helper, เพิ่ม group ใหม่ "WYN-093" 7 เทส (clamp ทั้ง 2 ขอบ, ภายในช่วง 3 กรณี, fallback ไม่มี metadata, เพดาน maxHeight)
- `app/test/drop_test.dart` — เพิ่มเทส `Drop.fromMap` parse `image_width`/`image_height` (มี/ไม่มี)
- `app/test/home_feed_item_test.dart` — เพิ่มเทส `HomeFeedItem.fromMap` parse `image_width`/`image_height` (มี/ไม่มี)
- `app/test/profile_likes_tab_test.dart` — **แก้เทสเดิมที่พัง** (ดู Known Issues ข้อ 1)
- `supabase/tests/wyn_093_home_feed_image_dimensions_test.sh` — เทส SQL ใหม่ (standalone harness ตาม pattern `wyn_079_feed_signals_unhide_test.sh` — ดูเหตุผลใน Tests ด้านล่าง)

Reason: Founder ข้อ 19/28 — "ปรับการแสดงผลรูปในฟีดให้อิงตามสัดส่วนจริงของรูปภาพ (Dynamic Height / Aspect Fit) โดยไม่ล็อกความสูงของการ์ด"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **899/899 ผ่านหมด** (887 เดิมจาก WYN-089 + 3 ใหม่ใน `image_dimensions_test.dart` + 7 ใหม่ใน `home_feed_screen_test.dart`'s WYN-093 group + 2 ใหม่ใน `drop_test.dart`/`home_feed_item_test.dart`)
- Red→green พิสูจน์จริง 2 ชั้น:
  1. **Flutter**: `git stash push` เฉพาะ 3 ไฟล์โค้ด (`home_drop_card.dart`, `home_feed_item.dart`, `drop.dart` — ไม่แตะไฟล์เทส) แล้วรัน `flutter test test/home_feed_screen_test.dart --plain-name "WYN-093"` → **compile error ตรงตามคาด** (`No named parameter with the name 'imageWidth'`) เพราะเทสใหม่เรียก field ที่ยังไม่มี — `git stash pop` คืนโค้ดแล้วรันซ้ำ → ผ่านหมด 7/7
  2. **SQL**: เขียน `wyn_093_home_feed_image_dimensions_test.sh` เป็น structural analog ของ view จริง (ไม่ใช่ full replica — เหตุผลเดียวกับที่ `wyn_079` ทำ: schema.sql เต็มไฟล์โหลดสดไม่ผ่านอยู่ก่อนแล้วจากปัญหาเดิม) รัน 4 CHECK ผ่านหมด ยืนยัน (ก) `alter table add column if not exists` idempotent, (ข) เทคนิค append-only column ทำงานถูกต้องกับ `CREATE OR REPLACE VIEW`, (ค) Drop เก่าไม่มี metadata คืนค่า null ผ่าน view ไม่ error, (ง) branch ที่ไม่เกี่ยวข้อง (pop) type-check ผ่าน UNION ALL ด้วย `null::integer`
- **`bash supabase/tests/wyn_063_unified_home_feed_test.sh`**: ยังรันไม่ผ่านเหมือนเดิม (ปัญหาเดิมก่อนงานนี้ ไม่เกี่ยวกับการแก้ครั้งนี้ — ยืนยันแล้วในมติก่อนหน้า ไม่ได้ลองซ้ำเพราะทราบผลอยู่แล้ว)

Known Issues:
1. **พบและแก้เทสเดิมที่พังจากผลข้างเคียงที่ตั้งใจ**: `profile_likes_tab_test.dart`'s "shows every Drop returned by fetchLikedByAuthor" คาดว่าการ์ดที่ 2 อยู่นอกจอ (ต้อง scroll) ก่อนงานนี้ — แต่ ceiling ใหม่ `maxHeight = 0.75 × screen height` ทำให้การ์ด (แม้ fallback เป็น 1:1 เพราะ fixture ไม่มี metadata) เตี้ยลงกว่าเดิมจนการ์ดทั้ง 2 ใบพอดีกับ viewport เทสเริ่มต้น (800×600) โดยไม่ต้อง scroll เลย — **นี่คือผลลัพธ์ที่ถูกต้องตาม Design spec** (เพดาน 0.75×screen height ตั้งใจให้ใช้แม้กรณี fallback 1:1 ด้วย ไม่ใช่แค่กรณี dynamic ratio เพราะปัญหา "รูปเดียวครองจอเกือบทั้งใบ" เกิดได้ทั้ง 2 กรณี) แก้เทสให้ไม่ assert จำนวนการ์ดก่อน scroll ที่ตายตัว (ลบ `expect(..., findsOneWidget)` ก่อน `scrollUntilVisible`) เหลือแค่ assert ท้ายสุดหลัง scroll (`findsNWidgets(2)`) ซึ่งเป็นพฤติกรรมหลักที่เทสนี้ตั้งใจตรวจจริงๆ
2. **`drop_images.image_width/height` เขียนแล้วแต่ยังไม่มีจุดใดอ่าน**: ตรวจโค้ดแล้วยืนยันว่า multi-image viewer (WYN-092) ยังไม่ implement ใน UI จริง (`grep` หา `drop_images`/multi-image ใน `home_drop_card.dart` ไม่เจอ) — เติมคอลัมน์และเขียนค่าไว้ล่วงหน้าตามที่ Design spec ขอ (Handoff ข้อ 1) เพื่อไม่ต้อง migrate ข้อมูลเก่าซ้ำตอน WYN-092 เริ่มจริง แต่ตอนนี้เป็น dead data ที่ยังไม่มี consumer
3. **`createDropFromExistingImage()` (republish จาก Draft)**: ไม่มี fresh bytes ให้ decode ขนาด จึง `drops.image_width/height` เป็น null เสมอสำหรับ Drop ที่ publish ผ่านทางนี้ — ยอมรับตามที่ design spec ระบุไว้แล้วว่าเป็น known gap เดียวกับ Drop เก่า (fallback 1:1)
4. **Performance ระหว่าง scroll จริง**: ทดสอบแค่ widget test (ไม่มี simulator/emulator ในนี้) — Risk R1 ของ Product spec ("jank ระหว่าง scroll เร็วๆ") แก้เชิงสถาปัตยกรรมแล้ว (metadata รู้ล่วงหน้า ไม่ต้องรอโหลดรูปเพื่อวัดขนาด) แต่ยังไม่เคยยืนยันด้วยการ scroll จริงบนอุปกรณ์
5. ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์เลย (widget test เท่านั้น) — โดยเฉพาะการ crop ที่ขอบ 0.8/1.91 ควรดูภาพจริงเทียบ

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ UI จริงว่ารูปแนวตั้ง/แนวนอน/จัตุรัสแสดงเต็มภาพไม่ crop ในฟีด ตามเกณฑ์ clamp (2) ทดสอบ scroll จริงบนอุปกรณ์ที่มีรูปหลายสัดส่วนต่อกัน ดูว่า jank หรือไม่ (Known Issue ข้อ 4) (3) ทดสอบโพสต์รูปจริงผ่าน `CreateDropScreen` แล้วเช็คใน DB ว่า `drops.image_width/height` ถูกเขียนค่าจริง ไม่ใช่แค่ผ่าน widget test (4) แจ้ง AI Deploy & DevOps เรื่อง schema delta ใหม่ (คอลัมน์ 4 ตัว + view definition ใหม่) ต้อง apply เข้า production แยกจาก deploy โค้ด ตามขั้นตอนปกติ + ต้องเช็ค column/view state จริงบน production ก่อน apply เหมือน WYN-071/072/083 (5) พิจารณา Known Issue ข้อ 1 (เทสที่แก้ไป) ว่า behavior ใหม่ (การ์ดพอดีจอโดยไม่ต้อง scroll ในบางกรณี) ตรงใจ Founder หรือไม่

## QA Report (2026-09-02)

```
Feature: รูปในฟีดยึดสัดส่วนจริง (dynamic-height/aspect-fit) แทน fixed 1:1 crop, พร้อม clamp 0.8–1.91 + เพดาน 0.75×screen height
Environment: อ่านโค้ดจริง (adversarial) + รัน `flutter analyze`/`flutter test` อิสระ + รัน SQL regression script อิสระเองต่อ local PostgreSQL 16 (สร้าง/ทำลายทิ้งหลังทดสอบ) — ไม่มี simulator/emulator
Test Cases:
  1. อ่าน _feedImageAspectRatio()/ConstrainedBox+AspectRatio composition ใน home_drop_card.dart ยืนยัน clamp (0.8, 1.91) และ maxHeight ceiling ตรงตาม design spec, fallback เป็น 1 เมื่อไม่มี metadata/height<=0 (ไม่มีทาง crash จาก division by zero)
  2. ตรวจ home_feed view definition ตัวสุดท้าย (บรรทัด 10508) ยืนยันว่า image_width/image_height ถูกต่อท้ายสุดของทั้ง 3 branch (drop/pop/redrop-of-drop) จริง ไม่ใช่แทรกกลาง — ยืนยันเป็น "create or replace view" ตัวเดียวที่ถูกแก้ (grep ยืนยันอีก 6 นิยามเก่าไม่ถูกแตะ)
  3. รัน `bash supabase/tests/wyn_093_home_feed_image_dimensions_test.sh` อิสระเอง: **4/4 CHECK ผ่านหมด** (real dimensions, old-Drop null fallback, pop branch type-check เป็น null, row count ไม่เปลี่ยน)
  4. ทดสอบ syntactic soundness ของ CHECK constraint และ append-only column ผ่าน ad-hoc PostgreSQL จริง (ไม่ใช่แค่อ่านโค้ด)
  5. ตรวจ drop_repository.dart ยืนยัน decodeImageDimensions() เรียกหลัง uploadBinary() สำเร็จจริงต่อรูป ไม่ใช่ค่าเดา
  6. ตรวจ profile_likes_tab_test.dart's แก้ไข (Known Issue #1) — ยืนยันเป็นการลบ assertion ที่ผูกกับ pixel-height สมมติ ไม่ใช่การลด coverage ของพฤติกรรมจริงที่ทดสอบ (assertion ท้ายสุดหลัง scroll ยังคงอยู่ครบ)
  7. ยืนยัน DropGridTile/DropDetailScreen ไม่ถูกแตะ ตรงตามสโคปที่ประกาศไว้ (grep ไม่พบ _feedImageAspectRatio/imageWidth ใน drop_detail_screen.dart)
  8. รัน `flutter analyze` อิสระ: สะอาด
  9. รัน `flutter test` อิสระเต็ม suite: 917/917 ผ่าน
Passed: ทั้ง 9 ข้อข้างต้น
Failed: ไม่มี
Severity: -
Reproduction Steps: -
Expected: -
Actual: -
Security Findings: ไม่พบ — schema เปลี่ยนแปลงเป็น additive/nullable column เท่านั้น ไม่กระทบ RLS/auth
Recommendation: อนุมัติ — schema delta (คอลัมน์ 4 ตัว + view ใหม่) ยังไม่ apply เข้า production ตามที่ Coding Output ระบุไว้ตรงๆ แล้ว ต้องส่งต่อ AI Deploy & DevOps ตรวจ column/view state จริงก่อน apply เหมือน WYN-071/072/083 — Performance ระหว่าง scroll จริงบนอุปกรณ์ยังไม่ได้ยืนยัน (residual, ไม่ block เพราะ mitigation เชิงสถาปัตยกรรมสมเหตุสมผลแล้ว — metadata รู้ล่วงหน้า ไม่ต้องรอโหลดรูป)
Final Status: PASS
```
