# Product Task — WYN-092

Status: review
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
