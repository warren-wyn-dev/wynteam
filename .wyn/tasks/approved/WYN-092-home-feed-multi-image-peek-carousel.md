# Product Task — WYN-092

Status: **PASS — QA อิสระ, 2026-09-03** — ย้ายเข้า `approved/` แล้ว
Owner: AI Design → AI Coding

Feature: Home Feed — Multi-Image Drop "Peek" Carousel

Goal: ให้การ์ด Drop ที่มีมากกว่า 1 รูปใน Home feed แสดงรูปแรกเกือบเต็มการ์ดพร้อมรูปที่สองโผล่
ขอบนิดเดียว (peek) และปาดดูรูปที่เหลือได้ตรงในฟีดเลย ตามภาพอ้างอิงของ Founder (Beta2 Phase 2 PDF
revision list item 14)

Target User: ผู้ใช้ WYNOS ทุกคนที่เลื่อนดู Home feed และผู้โพสต์ Drop หลายรูป (ฟีเจอร์
multi-image เดิมมีอยู่แล้วจาก WYN-071 แต่ยังไม่เคยแสดงในฟีดเลย มีแค่ในหน้า Detail)

Problem: มี draft ของงานนี้อยู่แล้วจากรอบ AI Design ครั้งก่อน (2026-09-02, ก่อน Founder ส่งภาพ
อ้างอิงจริงมาให้) — ตอนนั้น "Blocked: รอ Founder ยืนยัน peek width/สไตล์เทียบกับภาพต้นฉบับ"
เพราะ session นั้นไม่มีไฟล์ภาพ (มีแค่คำพูด Founder: "ส่วนรูป อยากได้แบบในรูปเลย เป็นการ์ด
รูปแรกเห็นเต็มๆ รูปที่ 2 โผล่นิดเดียว") ตอนนี้ Founder ส่งภาพจริงมาแล้ว (`f91d7b63-image.jpg`,
PDF item 14) จึงมาปิด block นี้ด้วยการเทียบภาพจริงกับโค้ดโดยตรง — พบว่า Home feed card
(`HomeDropCard`) ไม่มีการรองรับหลายรูปเลยแม้แต่น้อย (ต่างจาก `DropDetailScreen` ที่มี
`DropImageGallery` จาก WYN-071 แล้ว) — ผู้ใช้ที่เลื่อนฟีดเห็นแค่รูปแรกของ Drop หลายรูป ไม่มี
สัญญาณว่ามีรูปอื่นอีกจนกว่าจะกดเข้า Detail ดีไซน์ peek carousel รอบนี้แม่นกว่า draft เดิมเพราะ
เทียบกับภาพจริงได้ (82%/4:5/มุมโค้ง 16px แทนที่ estimate เดิม ~28px peek strip)

Requirements:
- R1. Drop ที่มี > 1 รูป ต้องแสดง "peek carousel" ในการ์ด Home feed: รูปแรกกว้าง ~82% ของการ์ด,
  aspect-ratio 4:5, มุมโค้ง 16px, รูปถัดไป peek ที่ขอบขวา
- R2. ปาดนิ้วในการ์ดดูรูปที่เหลือได้ตรงในฟีด ไม่ต้องกดเข้า Detail
- R3. Drop รูปเดียว (กรณีส่วนใหญ่ของระบบ) ไม่เปลี่ยนแปลงใด ๆ — ยังคง `AspectRatio(1)` เต็ม
  ความกว้างการ์ดเหมือนเดิม

Acceptance Criteria:
- [ ] `home_feed` SQL view มีคอลัมน์ `image_count` (Drop/redrop branch เท่านั้น)
- [ ] `HomeFeedItem` มี `imageCount`/`hasMultipleImages`
- [ ] `HomeDropCard` แสดง peek carousel เมื่อ `hasMultipleImages == true` เท่านั้น
- [ ] Drop รูปเดียวหน้าตา/พฤติกรรมเหมือนเดิม 100%
- [ ] Double-tap ถูกใจทำงานได้ทุกรูปใน carousel, single-tap เปิด Detail เหมือนเดิม, ไม่มี
  gesture-arena conflict (บั๊กเดียวกับที่ WYN-071 เคยเจอ)
- [ ] `DropImageGallery`/`DropImageViewer`/`DropDetailScreen` ไม่ถูกแตะเลย
- [ ] `flutter analyze`/`flutter test` ผ่านครบ ไม่มี regression กับ WYN-007/WYN-018/WYN-063/WYN-071

Dependencies: WYN-071 (`drop_images` table, `DropRepository.fetchDropImages()`,
`Drop.imageCount`/`hasMultipleImages` — reuse ทั้งหมด), WYN-063 (ranking algorithm ที่อ่าน
`home_feed` เดียวกัน — ต้องไม่กระทบ query plan)

Priority: ไม่มีคำถามค้าง — ได้ภาพอ้างอิงและคำกำกับชัดเจนจาก Founder แล้ว พร้อมส่งต่อ AI Coding
(ขนาดงานใหญ่กว่า WYN-091/WYN-096 เพราะกระทบ SQL view + model + widget ใหม่)

Risks: กลาง — แก้ SQL view ที่ระบบอื่นพึ่งพาอยู่ (ranking algorithm, feed pagination) ต้องตรวจ
regression รอบ 3 branch ของ `home_feed` ให้ครบ, gesture-arena เดิมที่ WYN-071 เคยเจอบั๊กต้อง
ระวังซ้ำ

Recommendation: ทำตาม design spec โดยตรง — reuse pattern เดิมจาก `DropImageGallery`/
`fetchDropImages()` ให้มากที่สุด อย่าสร้าง fetch mechanism ใหม่ซ้ำซ้อน

Handoff: พร้อมส่งต่อ AI Coding

---

## Design Output (AI Design, 2026-09-02)

Design spec เต็ม: `.wyn/docs/design/wyn-092-home-feed-multi-image-peek-carousel.md`

สรุป: ภาพอ้างอิง (`f91d7b63-image.jpg`, PDF item 14) คือ screenshot ของ
`design-reference/01-home.tsx` post id 3 ("WYNOS") ตรงกับ `design-reference/SPEC.md` Section 4.7
("Image carousel, peek-card style") เป๊ะ — ตรวจ stack ทั้ง 3 ชั้นแล้วพบว่า Home feed card ไม่มี
multi-image awareness เลย (SQL view ไม่มี image count, model ไม่มี field, widget แสดงแค่รูปแรก)
ต่างจาก Detail screen ที่ทำไปแล้วครบใน WYN-071 — งานนี้คือการเติมส่วนที่เหลือ (Home feed
preview) เท่านั้น ไม่แตะของเดิมที่ทำงานถูกต้องอยู่แล้ว

Screen: `HomeDropCard` เฉพาะเมื่อ `imageCount > 1` — ไม่กระทบ `HomePopCard`/`DropDetailScreen`

Handoff ถึง AI Coding (รายละเอียดเต็มดู design doc):
1. SQL: `create or replace view public.home_feed` เพิ่ม `image_count` scalar subquery (drop/
   redrop branch), `null::bigint` สำหรับ pop branch — ห้าม embed URL รายการเต็ม
2. `HomeFeedItem`: เพิ่ม `imageCount`/`hasMultipleImages` (mirror `Drop`'s field เดิม), ผ่านค่า
   ครบทุก path (`fromMap`/`copyWith`/`toDrop`/`fromDrop`)
3. Widget ใหม่ `HomeFeedImagePeekCarousel` (ไฟล์ใหม่ที่เสนอ:
   `app/lib/features/home/presentation/widgets/home_feed_image_peek_carousel.dart`) — reuse
   `DropRepository.fetchDropImages()` เดิม, แสดงรูปแรกทันทีจาก `item.imageUrl` ระหว่างรอ fetch,
   fallback เหลือรูปแรกถ้า fetch fail — container 82% width/4:5 aspect/มุมโค้ง 16px/gap 8px/
   negative right margin ให้ peek ทะลุขอบได้ตาม SPEC.md 4.7
4. Regression พิเศษ: Drop รูปเดียวต้องไม่เปลี่ยนเลย, gesture arena (double-tap ถูกใจ vs
   single-tap เปิด Detail) ต้องไม่ชนกัน — reuse `DoubleTapLike` เดียวครอบทั้ง carousel ตาม
   pattern ของ `DropImageGallery`
5. `DropImageGallery`/`DropImageViewer`/`DropDetailScreen`/`CreateDropScreen` ห้ามแตะเลย

Design Rules ที่ต้องยึด: ห้ามใช้ pattern `PageView`/full-bleed 1:1 แบบ `DropImageGallery` กับ
Home feed (ต้องเป็น peek-card 82%/4:5 เท่านั้น), ห้ามเปลี่ยน treatment รูปเดี่ยว, สีทุกจุดมาจาก
`WynColors` เท่านั้น, ต้อง reuse `fetchDropImages()` เดิม ห้ามสร้าง query ใหม่ซ้ำ

---

## Coding Output (2026-09-02)

Root cause: ไม่ใช่บั๊ก — งานใหม่ตามสโคป Design (SQL view + model field + widget ใหม่)

การเปลี่ยนแปลง:
1. **`supabase/schema.sql`**: `create or replace view public.home_feed` ฉบับใหม่ (append เต็ม
   ตาม convention เดิมของไฟล์นี้ — ไม่แก้ของเก่า) เพิ่ม `image_count` เป็นคอลัมน์สุดท้ายของทุก
   branch — drop branch: `(select count(*) from public.drop_images where drop_id = d.id)`,
   pop branch: `null::bigint` (พิมพ์ตรงกับ bigint ของ count(*))
2. **`app/lib/features/home/data/home_feed_item.dart`**: เพิ่ม `imageCount`/`hasMultipleImages`
   (getter จาก `imageCount > 1`) ผ่านครบทุก path (`fromMap`/`copyWith`)
3. **`app/lib/features/home/presentation/widgets/home_feed_image_peek_carousel.dart`** (ไฟล์
   ใหม่): `HomeFeedImagePeekCarousel` — reuse `DropRepository.fetchDropImages()` เดิม, แสดง
   `item.imageUrl` ทันทีระหว่างรอ fetch/ถ้า fetch fail (fallback เหมือน single-image เดิม),
   container 82% width/4:5 aspect/มุมโค้ง 16px (`WynSpacing.radiusLg`)/gap 8px
   (`WynSpacing.space2`) ใน `ListView.builder` แนวนอน, ครอบด้วย `DoubleTapLike` เดียวทั้ง
   carousel (ไม่มี `onTap` ของตัวเอง — อาศัย `HomeDropCard`'s outer `InkWell` เดิมเปิด Detail
   เหมือน single-image case), badge ไอคอนรูปภาพเล็กที่มุมขวาล่างของรูปแรกเท่านั้น (ไม่มีตัวเลข
   นับ ตามภาพอ้างอิง ต่างจาก `DropImageGallery`'s "1/3" badge โดยเจตนา)
4. **`app/lib/features/home/presentation/widgets/home_drop_card.dart`**: เพิ่ม required
   `dropRepository` param, เพิ่ม branch `else if (item.imageUrl != null && item.hasMultipleImages)`
   เรียก `HomeFeedImagePeekCarousel` ก่อน single-image branch เดิม (ซึ่งไม่ถูกแตะเลย)
5. Caller ทั้งหมดของ `HomeDropCard` (constructor เปลี่ยนเป็น required param ใหม่) อัปเดตให้ส่ง
   `dropRepository` เข้าไป: `hashtag_feed_screen.dart`, `home_feed_screen.dart`,
   `profile_drop_grid_tab.dart`, `profile_likes_tab.dart`, `profile_redrops_tab.dart`
6. `DropImageGallery`/`DropImageViewer`/`DropDetailScreen`/`CreateDropScreen` ไม่ถูกแตะเลยตามที่
   Design กำหนด

Files Changed:
- `supabase/schema.sql`
- `app/lib/features/home/data/home_feed_item.dart`
- `app/lib/features/home/presentation/widgets/home_feed_image_peek_carousel.dart` (ใหม่)
- `app/lib/features/home/presentation/widgets/home_drop_card.dart`
- `app/lib/features/hashtag/presentation/hashtag_feed_screen.dart`,
  `app/lib/features/home/presentation/home_feed_screen.dart`,
  `app/lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart`,
  `app/lib/features/profile/presentation/widgets/profile_likes_tab.dart`,
  `app/lib/features/profile/presentation/widgets/profile_redrops_tab.dart`
- `app/test/home_feed_screen_test.dart` — เทสใหม่ครอบคลุม peek carousel (multi-image แสดง
  carousel, single-image ไม่เปลี่ยน, double-tap ถูกใจทำงานในทุกรูป)
- `supabase/tests/wyn_092_home_feed_image_count_test.sh` (ใหม่) — standalone SQL regression
  (ไม่โหลด schema.sql เต็มไฟล์ ตามข้อจำกัดที่บันทึกไว้ใน DECISIONS.md)

Tests: `flutter analyze` สะอาด (No issues found!), `flutter test` เต็ม suite ผ่าน 944/945
(ตัวที่ fail คือ WYN-081's regression test ที่ยัง red ในสาขานี้ ณ ตอนโค้ด — คนละงาน กำลังถูกแก้
แยกโดย AI Debug Engineer อยู่แล้ว ไม่เกี่ยวกับ WYN-092)

Build: ไม่ได้รัน migration จริงกับ production DB (ไม่มีสิทธิ์ใน session นี้) — `schema.sql`
เพิ่มเฉพาะ view definition ใหม่ ไม่มี `alter table`/breaking change ใดๆ

Known Issues: ยังไม่ได้ทดสอบภาพจริงบนอุปกรณ์ (ไม่มี simulator/emulator) — โดยเฉพาะ swipe
gesture ในแนวนอนของ carousel ไม่ชนกับ vertical scroll ของ feed เอง (ClampingScrollPhysics
ควรป้องกันได้ตามทฤษฎี แต่ยังไม่ยืนยันบนอุปกรณ์จริง)

Handoff: ส่งต่อ AI QA & Security — (1) ยืนยัน migration `image_count` ปลอดภัยกับ query plan เดิม
ของ `home_feed` (ranking algorithm ที่พึ่งพา view เดียวกัน) (2) ยืนยัน gesture จริงบนอุปกรณ์/
เบราว์เซอร์ (3) รัน `supabase/tests/wyn_092_home_feed_image_count_test.sh`

---

## QA Report (AI QA & Security, 2026-09-03)

Feature: Home Feed — Multi-Image Drop "Peek" Carousel (Wynos V1.0.0 Beta2 Phase 2, item 14) — งานใหญ่ที่สุดในรอบ QA นี้ กระทบ SQL view + model + widget ใหม่ + merge-reconciliation กับ WYN-097/098/099

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` (Flutter 3.47.2, Dart 3.13.2, `app/`) + ทดสอบ SQL อิสระด้วย PostgreSQL 16 จริง (local cluster, `/var/run/postgresql`) — worktree ยืนยันแล้วว่าอยู่บน `claude/wynos-beta2-phase2-handoff-w4mi5m` @ `40cafac`

Test Cases:
1. **ยืนยัน merge-reconciliation ของ `public.home_feed` view ไม่เชื่อ comment เฉยๆ**: หา `create or replace view public.home_feed` ทุกจุดในไฟล์ (10 จุด, บรรทัด 456 ถึง 11821) ยืนยันว่านิยามที่บรรทัด 11821 (มี "Merge-reconciliation note" กำกับ) เป็นจุด**สุดท้ายจริง** ในไฟล์ (คือนิยามที่ PostgreSQL จะใช้จริงเมื่อโหลด schema.sql ทั้งไฟล์แบบลำดับ) — เทียบ diff บรรทัดต่อบรรทัดกับนิยามก่อนหน้าทันที (บรรทัด 11572, ของ WYN-098) พบว่าเหมือนกันทุกตัวอักษร **ยกเว้น** `image_count` ที่ถูกเพิ่มเป็นคอลัมน์สุดท้ายของทั้ง 3 branch (drop/pop/redrop) เท่านั้น — ยืนยัน column order/type ตรงกันครบ 34 คอลัมน์ทั้ง 3 branch (นับมือ), `audience`/`location` (จาก WYN-097/098) และ `image_count` (จาก WYN-092) **อยู่ครบทั้งคู่ไม่มีฝ่ายไหนถูกกลืนหาย**
2. **ทดสอบ SQL จริงกับ PostgreSQL 16 ที่รันในเครื่อง sandbox นี้ (ไม่ใช่แค่อ่านอย่างเดียว)**: เปิด local Postgres cluster (`pg_ctlcluster 16 main start`), สร้างตารางขั้นต่ำ (profiles/drops/pops/redrops/drop_images/drop_polls/ฯลฯ พร้อม stub `auth.uid()`/`drop_view_count()`) แล้ว **extract โค้ด SQL ของนิยาม view ตัวจริงจาก schema.sql บรรทัด 11821-12053 แบบ byte-for-byte** มารันตรงๆ (ไม่ใช่ structural analog) — `CREATE VIEW` สำเร็จ ไม่มี syntax/type error ใดๆ แล้ว insert ข้อมูลทดสอบจริง (Drop 3 รูป, Drop 1 รูป, Drop ไม่มีรูป, Pop, Redrop ของ Drop 3 รูป) แล้ว query — ผลลัพธ์ถูกต้องครบ: `image_count` = 3/1/0/NULL(pop)/3(redrop) ตามลำดับ, `audience`/`location` ผ่านมาถูกต้องพร้อมกัน (เช่น Drop 3 รูปมี `location='Bangkok'`, `audience='everyone'` และ `image_count=3` ในแถวเดียวกันถูกต้อง) — พิสูจน์ว่า reconciliation ถูกต้องจริงในทางปฏิบัติ ไม่ใช่แค่ในทางทฤษฎี
3. รัน `bash supabase/tests/wyn_092_home_feed_image_count_test.sh` ตามที่ task ขอ — **ALL CHECKS PASSED** ทั้ง 5 check (multi-image=3, single-image=1, text-only=0, pop branch type-checks เป็น NULL, redrop นับรูปของ Drop ต้นฉบับถูกต้อง)
4. อ่านโค้ด `HomeFeedItem` (`home_feed_item.dart`) — ยืนยัน `imageCount`/`hasMultipleImages` ผ่านครบทุก path: `fromMap` (อ่าน `map['image_count']`), `copyWith`, `toDrop()`, `fromDrop()` — ไม่มีจุดไหนตกหล่น
5. อ่านโค้ด `HomeDropCard` — ยืนยัน branch ใหม่ `else if (item.imageUrl != null && item.hasMultipleImages)` แทรกอยู่**ก่อน** branch เดิมของ single-image (ซึ่งไม่ถูกแก้แม้แต่บรรทัดเดียว) — โครงสร้าง `else if` รับประกันว่า Drop รูปเดียว/ไม่มีรูปไม่มีทางเข้า branch ใหม่ได้เลย
6. รัน `flutter test test/home_feed_screen_test.dart` เฉพาะกลุ่ม "WYN-092: multi-image peek carousel" — ยืนยันครบทุกเคส: (a) single-image ไม่ build carousel เลย ยังเห็น `Image` เดียวเหมือนเดิม (b) multi-image build carousel จริง แสดงรูปแรกทันทีก่อน fetch เสร็จ (c) หลัง fetch เสร็จแสดงครบทุกรูปที่ 82% width/4:5 aspect ratio ถูกต้อง (ยืนยันด้วยการวัดขนาดจริงจาก `tester.getSize`) (d) fetch fail แล้ว fallback เหลือรูปแรกแบบ silent ไม่มี error UI (e) double-tap ที่ตำแหน่งกึ่งกลาง carousel เรียก `onToggleLike` แค่ 1 ครั้ง (f) single-tap (ไม่ตามด้วย tap ที่ 2) เปิด Detail ผ่าน `HomeDropCard`'s outer `InkWell` เหมือน single-image case ทุกประการ — ครบทุกเคสตาม Acceptance Criteria
7. อ่านโค้ด `DoubleTapLike`/`HomeFeedImagePeekCarousel` — ยืนยัน gesture-arena ปลอดภัยเชิงสถาปัตยกรรม: `GestureDetector` ตัวเดียว (double-tap+tap) ห่อ**ทั้ง** carousel (ไม่ใช่ต่อรูป) ส่วน horizontal drag เป็น `ListView`'s Scrollable ที่ซ้อนอยู่ข้างใน — Flutter's gesture arena แยก drag (touch-slop exceeded) ออกจาก tap ให้เองโดยธรรมชาติ ไม่ชนกัน ตรงกับที่ WYN-071 เคยแก้บั๊กคลาสเดียวกันมาก่อนแล้วสำหรับ Detail screen — เนื่องจากเป็น `GestureDetector` เดียวครอบทั้งแถว การดับเบิลแทปที่ตำแหน่งรูปใดก็ตาม (ไม่ใช่แค่รูปแรก) ต้องเรียก `onLike` เหมือนกันหมดตามสถาปัตยกรรมนี้ ไม่ใช่แค่ที่ตำแหน่งที่เทสทดสอบ
8. อ่านโค้ด callers ทั้ง 6 ไฟล์ของ `HomeDropCard` (constructor เปลี่ยนเป็น required param `dropRepository`) — ยืนยันส่ง `dropRepository: widget.dropRepository` ครบทุกจุด (ยืนยันซ้ำด้วย `flutter analyze` สะอาด — ถ้าตกหล่นจุดไหนจะ compile error ทันที)
9. ยืนยัน `HomePopCard`/`ActionMetric`/`DropImageGallery`/`DropImageViewer`/`DropDetailScreen`/`CreateDropScreen` ไม่ถูกแตะเลยจากงานนี้ (ตรวจ `git show 71ec4d6 --stat` — `home_pop_card.dart` มีแค่ diff ของ WYN-096 คนละงาน)
10. ยืนยัน query จาก `home_repository.dart` ใช้ `.from('home_feed').select(...)` ผ่าน Supabase/PostgREST ซึ่ง map คอลัมน์ด้วยชื่อ ไม่ใช่ตำแหน่ง — เพิ่มคอลัมน์ท้ายตารางจึงไม่กระทบ ranking algorithm (WYN-063/WYN-018) เดิมที่อ่าน column อื่นด้วยชื่ออยู่แล้ว
11. รัน `flutter analyze` เต็ม `app/` — "No issues found!"
12. รัน `flutter test` เต็ม suite — **1011/1011 ผ่านหมด** ไม่มี regression กับ WYN-007/WYN-018/WYN-063/WYN-071

Passed: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 (ทั้งหมด)

Failed: ไม่มี

Severity: N/A

Reproduction Steps: เปิด Home feed ที่มี Drop โพสต์แบบหลายรูป → เห็นรูปแรกกว้าง ~82% การ์ด, รูปที่ 2 โผล่ขอบขวา → ปาดดูรูปถัดไปได้ในฟีดโดยตรง → ดับเบิลแทปที่รูปใดก็ได้ถูกใจได้ → แทปครั้งเดียวเปิด Detail

Expected: ตรงตาม R1/R2/R3 และ Acceptance Criteria ทุกข้อ, Drop รูปเดียวไม่เปลี่ยนแปลงเลย

Actual: ตรงตาม Expected ทุกจุด — ยืนยันทั้งด้วยการอ่านโค้ด, รัน SQL จริง, และรัน widget test จริง

Security Findings: ตรวจ SQL view ใหม่แล้วไม่พบการรั่วไหลข้อมูล — `image_count` เป็นแค่ scalar count ไม่ embed URL รายการเต็ม (ตามที่ Design ระบุห้ามไว้), view ยังคง `security_invoker = true` และ `where not exists (select 1 from mutes ...)` เหมือนเดิมทุกจุด (mute filtering ไม่ถูกรบกวน), ไม่มีการเปลี่ยนแปลง RLS policy ใดๆ ในงานนี้

Recommendation: อนุมัติ ย้ายเข้า `.wyn/tasks/approved/` — หมายเหตุ Known Issue ที่ task เองระบุไว้แล้ว (ยังไม่ยืนยัน gesture จริงบนอุปกรณ์/เบราว์เซอร์จริง เนื่องจากไม่มี simulator/emulator ในสภาพแวดล้อมนี้) ยังคงเป็น residual risk ต่ำที่ควรให้คนทดสอบยืนยันอีกชั้นก่อน mass rollout แต่ไม่ใช่ blocker สำหรับ PASS รอบนี้ เพราะการวิเคราะห์ gesture-arena เชิงสถาปัตยกรรม + เทสอัตโนมัติที่มีอยู่ยืนยันแล้วว่าไม่มี conflict ในทางทฤษฎี

Final Status: PASS
