# Design Spec — WYN-092: Home Feed Card — Multi-Image "Peek" Carousel

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/active/WYN-092-home-feed-multi-image-peek-carousel.md`
อ้างอิงภาพต้นฉบับจาก Founder (Beta2 Phase 2 PDF revision list, item 14 — ที่ตั้ง
`/root/.claude/uploads/874e2b82-2d79-56e1-bb55-bece689d658d/f91d7b63-image.jpg`)
อ้างอิง Design System ปัจจุบัน (Sapphire era): `app/lib/core/design/wyn_colors.dart`,
`app/lib/core/design/wyn_spacing.dart`, `design-reference/SPEC.md` Section 4.7 ("Image
carousel (peek-card style)"), `design-reference/01-home.tsx` (`ImageCarousel` component) —
**ไม่ใช้** `.wyn/docs/design/ds-001-color-system.md` (Cyan เดิม, ถูกแทนที่แล้วตาม
`.wyn/company/DECISIONS.md` "เปลี่ยน Color Direction ของ WYN: Cyan → Sapphire", 2026-08-29)

## ภาพอ้างอิงคือ screenshot ของ `design-reference/01-home.tsx` เอง (post id 3, "WYNOS")

โพสต์ "WYNOS" ในภาพ ("บรรยากาศตลาดนัดงานฝีมือสุดสัปดาห์นี้ 🌿") ตรงกับ `posts[2]` ใน
`design-reference/01-home.tsx` เป๊ะ (มี `images: ["#B98F6B", "#2B2A26", "#7C8B6E"]` — 3 รูป) —
ภาพอ้างอิงนี้คือ screenshot ของ prototype ที่ Founder อนุมัติไว้แล้วในโค้ด (สี beige/ดำ ที่เห็น
ในภาพคือ placeholder background สีจากโค้ด mock ไม่ใช่รูปจริง) เช่นเดียวกับ WYN-091 จึงยึด
`design-reference/SPEC.md` Section 4.7 เป็นสเปกอ้างอิงหลัก ไม่ใช่แค่ตีความจากภาพ

## สิ่งที่เห็นจริงในภาพอ้างอิง (item 14)

การ์ดรูปที่ Founder ต้องการ: **รูปแรกเห็นเต็มความกว้างการ์ดเกือบทั้งหมด มีมุมโค้งชัดเจน (rounded
card) และรูปที่สองโผล่มานิดเดียวที่ขอบขวา** (ไม่ใช่ full-bleed เต็มจอ ไม่ใช่ swipe แบบเห็นทีละรูป
เต็มจอ) — มีไอคอน scan/expand เล็ก ๆ มุมล่างขวาของรูปแรก Founder เขียนกำกับชัดว่า "รูปแรกเห็น
เต็มๆ รูปที่ 2 โผล่นิดเดียว" ตรงกับคำอธิบาย SPEC.md 4.7 ทุกตัวอักษร: การ์ดกว้าง 82% ของพื้นที่,
`aspect-ratio 4:5`, bo มุมโค้ง 16px (`rounded-2xl`), เว้นช่องระหว่างการ์ด 8px, container เลื่อน
แนวนอนมี negative right-margin เท่ากับ padding ขอบหน้าเพจ ทำให้การ์ดใบสุดท้ายที่มองเห็นสามารถ
"peek" เลยขอบเนื้อหาปกติออกไปได้พอดี — นี่คือที่มาของเอฟเฟกต์ "โผล่นิดเดียว" ในภาพ

## เทียบกับโค้ดปัจจุบันจริง — พบ gap จริง 3 ชั้น (data → model → widget)

ตรวจสอบทั้ง stack แล้วพบว่า **Home feed การ์ด (`HomeDropCard`) ไม่มีการรองรับหลายรูปเลยแม้แต่
น้อย** ต่างจาก Detail screen ที่ทำไปแล้วใน WYN-071:

1. **SQL (`supabase/schema.sql`, view `public.home_feed`)**: ทุก branch ของ view (`drop`,
   `pop`, redrop) ไม่มีคอลัมน์ที่บอกว่า Drop นั้นมีกี่รูปเลย — มีแค่ `image_url` เดียว (รูปแรก
   เท่านั้น) แม้ตาราง `drop_images` (สร้างใน WYN-071, เก็บรูปทุกรูปแบบมีลำดับ `position`) จะมี
   ข้อมูลรูปที่ 2-9 อยู่แล้วในฐานข้อมูลจริงก็ตาม — `home_feed` ไม่เคย join/subquery เข้าไปหา
   `drop_images` เลยแม้แต่ครั้งเดียว
2. **Model (`HomeFeedItem`, `app/lib/features/home/data/home_feed_item.dart`)**: มีแค่ field
   `imageUrl` เดี่ยว ไม่มี `imageCount`/`hasMultipleImages` แบบที่ `Drop`
   (`app/lib/features/drop/data/drop.dart` บรรทัด 51/98) มีอยู่แล้วสำหรับหน้า Detail
3. **Widget (`HomeDropCard`)**: เส้นทางมีรูป (บรรทัด 325-353 ของ
   `home_drop_card.dart`) render แค่ `Image.network(item.imageUrl!)` เดี่ยว ๆ ใน
   `AspectRatio(aspectRatio: 1)` เต็มความกว้างการ์ด ไม่มีการเช็คว่ามีรูปมากกว่า 1 รูปเลย — ถ้า
   Drop มี 3 รูป ผู้ใช้ที่เลื่อนดู Home feed จะเห็นแค่รูปแรกเท่านั้น ไม่มีสัญญาณใด ๆ ว่ามีรูปอื่น
   อีก ต้องกดเข้า Detail (`DropDetailScreen` → `DropImageGallery`) ถึงจะเห็นรูปที่เหลือ

**นี่คือ gap ของจริงที่ WYN-092 ต้องปิด** — ไม่ใช่แค่เรื่อง visual polish อย่างเดียวแบบ WYN-091

## แยกให้ชัด: นี่คนละจุดกับ `DropImageGallery`/`DropImageViewer` (WYN-071) — ไม่แตะของเดิม

`DropImageGallery` (`app/lib/features/drop/presentation/widgets/drop_image_gallery.dart`,
สร้างใน WYN-071) เป็น image area ของ **`DropDetailScreen` เท่านั้น** (ดู doc comment ของไฟล์
เอง บรรทัด 9) ใช้ pattern คนละแบบโดยเจตนา: `PageView` แบบ full-bleed เห็นทีละรูปเต็มการ์ด
(`AspectRatio(aspectRatio: 1)`) + badge นับรูป "1/3" มุมขวาบน + dot indicator ล่าง — เหมาะกับ
บริบท "เปิดดูโพสต์นี้อย่างเดียวเต็ม ๆ" ของหน้า Detail จริง ๆ ไม่ใช่บริบท "เลื่อนผ่านฟีดเร็ว ๆ"
ของ Home feed **ทั้งสอง pattern ถูกต้องในบริบทของตัวเอง ไม่ใช่ inconsistency ที่ต้องแก้ให้เหมือน
กัน** — SPEC.md เองก็แยกไว้คนละที่ (4.7 คือ Home feed carousel, ส่วน Detail screen ไม่ได้อยู่ใน
ขอบเขตของ SPEC.md ฉบับนี้เลยเพราะมันเป็น mockup ของหน้า Home feed เท่านั้น) — **WYN-092 นี้แก้
เฉพาะ `HomeDropCard` เท่านั้น ห้ามแตะ `DropImageGallery`/`DropImageViewer`/`DropDetailScreen`
ทั้งหมด** (ผ่าน QA แล้วใน WYN-071, ไม่มีเหตุผลให้เปลี่ยน)

## ขอบเขต: เฉพาะกรณีมีมากกว่า 1 รูปเท่านั้น

Drop รูปเดียว (กรณีส่วนใหญ่ในระบบปัจจุบันเกือบทั้งหมด) **ไม่เปลี่ยนอะไรเลย** — ยังคงเป็น
`AspectRatio(1)` เต็มความกว้างการ์ดเหมือนเดิมทุกประการ ไม่มีภาพอ้างอิงหรือคำกำกับใด ๆ จาก
Founder ที่ขอให้เปลี่ยน treatment ของรูปเดียว การเปลี่ยนไปด้วยจะเป็นการคิดทิศทางใหม่ที่ไม่มีใคร
ขอ และเสี่ยง regression กับหน้าตาการ์ดรูปเดียวที่ใช้งานจริงอยู่แล้วเป็นส่วนใหญ่ของ feed

---

Screen: `HomeDropCard` — เฉพาะเส้นทางที่ `item.imageUrl != null && imageCount > 1` (Home feed,
`HomeFeedScreen`) — ไม่กระทบ `HomePopCard` (Pop ไม่มีแนวคิดหลายรูป), ไม่กระทบ `DropDetailScreen`

Purpose: ให้ผู้ใช้เห็นตั้งแต่ในฟีดว่าโพสต์นี้มีมากกว่า 1 รูป (ผ่านการ "โผล่นิดเดียว" ของรูปที่ 2
ตามภาพอ้างอิง) และเลื่อนดูรูปที่เหลือได้ทันทีโดยไม่ต้องกดเข้า Detail — ตรงกับ SPEC.md 4.7

User Flow: ผู้ใช้เลื่อนดู Home feed ตามปกติ → เจอ Drop ที่มีหลายรูป เห็นรูปแรกเกือบเต็มการ์ด
พร้อมรูปที่สองโผล่ขอบขวานิดเดียว → ปาดนิ้วซ้าย (horizontal scroll) เพื่อดูรูปถัดไปได้โดยตรงใน
ฟีด (ไม่ต้องออกจากฟีด) → แตะรูปใดรูปหนึ่งเพื่อเปิด Detail แบบเดิม (พฤติกรรม `onTap` เดิมของทั้ง
การ์ดไม่เปลี่ยน) → double-tap รูปเพื่อกดถูกใจได้เหมือนเดิมทุกจุดของ carousel

Components:
- **SQL — `public.home_feed` view** (`supabase/schema.sql`): เพิ่มคอลัมน์ `image_count` ให้ทั้ง
  2 branch ที่เป็น Drop (`drop` ธรรมดา และ redrop) ด้วย scalar subquery รูปแบบเดียวกับ
  `like_count`/`comment_count`/`redrop_count` ที่มีอยู่แล้วในไฟล์เดียวกัน:
  `(select count(*) from public.drop_images where drop_id = d.id) as image_count` — branch
  `pop` ใส่ `null::bigint as image_count` (Pop ไม่มีรูปหลายรูป) — **ห้ามดึงรายชื่อ URL รูปเต็ม
  เข้ามาใน view นี้** (ต่างจาก `liked_by`/`top_reply` ที่ jsonb_agg มาเลย) เพราะ Home feed
  paginate การ์ดจำนวนมากต่อหน้าจอ การฝัง URL รายการเต็มทุกแถวจะทำให้ payload หนักโดยไม่จำเป็น —
  ขอแค่ "จำนวน" พอสำหรับตัดสินใจว่าจะ fetch รูปที่เหลือ (lazy) หรือไม่ ดูข้อถัดไป
- **Model — `HomeFeedItem`**: เพิ่ม field `int? imageCount` (nullable เพราะ Pop ไม่มีค่านี้,
  รูปแบบเดียวกับ `viewCount`) อ่านจาก `map['image_count']` ใน `fromMap`, ส่งผ่านใน `copyWith`/
  `toDrop()` (map เข้า `Drop.imageCount` ได้ตรง ๆ เพราะ field ชื่อ/ความหมายเดียวกันแล้ว) เพิ่ม
  getter `bool get hasMultipleImages => (imageCount ?? 1) > 1` (mirror `Drop.hasMultipleImages`
  บรรทัด 98 ของ `drop.dart` ตรง ๆ เพื่อความสม่ำเสมอของชื่อ/ความหมายในระบบ)
- **Widget ใหม่ — `HomeFeedImagePeekCarousel`** (ไฟล์ใหม่ เสนอที่
  `app/lib/features/home/presentation/widgets/home_feed_image_peek_carousel.dart`): ใช้เฉพาะ
  เมื่อ `item.hasMultipleImages` เท่านั้น — โครงสร้างข้อมูลเหมือน `DropImageGallery` เป๊ะ (reuse
  pattern เดิม ไม่ใช่คิดใหม่): แสดงรูปแรก (`item.imageUrl`) ทันทีจาก field ที่มีอยู่แล้วในฟีด
  โดยไม่ต้อง fetch เพิ่ม แล้วเรียก `DropRepository.fetchDropImages(item.id)` (method เดิมจาก
  WYN-071, `app/lib/features/drop/data/drop_repository.dart` บรรทัด 729) แบบ async ใน
  `initState` เพื่อดึงรายการรูปที่เหลือมาแสดงต่อ — ถ้า fetch fail ให้ fallback เหลือแค่รูปแรก
  เฉย ๆ (เหมือน `_DropImageGalleryState._load()` ทำอยู่แล้วบรรทัด 50-59 ของไฟล์นั้น) —
  **ต่างจาก `DropImageGallery` ตรงที่ container/scroll behavior**: ใช้ `ListView.builder`
  แนวนอน (ไม่ใช่ `PageView`) ความกว้างการ์ดละ `82%` ของความกว้างการ์ดทั้งหมด, `aspect-ratio
  4:5` (ผ่าน `AspectRatio(aspectRatio: 4/5)` ต่อรูป ไม่ใช่ 1:1 เหมือนรูปเดี่ยว), มุมโค้ง 16px
  (`WynSpacing.radiusLg`), gap ระหว่างการ์ด 8px (`WynSpacing.space2`), scroll snap ผ่าน
  `PageStorageKey`+`ScrollPhysics` หรือ `ListWheelScrollView` แล้วแต่ AI Coding เลือก
  implementation ที่ smooth ที่สุดบน Flutter — **ข้อกำหนดที่ต้องตรงคือผลลัพธ์ทางสายตา (82%
  กว้าง, การ์ดถัดไป peek ออกทางขวา, snap ไม่ใช่เลื่อนลอย ๆ)** ไม่ใช่ implementation ภายใน
  - Container เลื่อนต้องมี right padding/margin ติดลบเทียบเท่า padding ขอบการ์ดปกติ (ตาม SPEC
    4.7's "negative right margin equal to page's own right padding") เพื่อให้การ์ดใบสุดท้าย
    ที่มองเห็น peek ทะลุขอบปกติออกไปได้ ตรงกับภาพอ้างอิง
  - รูปเดี่ยว (ไม่ใช่ multi-image) **ไม่ผ่าน widget ใหม่นี้เลย** — `HomeDropCard` ยังคงเรียก
    `Image.network` เดี่ยว ๆ ใน `AspectRatio(1)` เหมือนเดิมทุกบรรทัด (ดู "ขอบเขต" ด้านบน)
- **Badge/indicator**: มุมล่างขวาของการ์ดแรก (ไม่ใช่ทุกการ์ด) แสดง icon เล็ก ๆ บอกว่ามีหลายรูป
  ให้ปาดดู — reuse ไอคอน scan/expand ที่เห็นในภาพอ้างอิงได้ (Material `Icons.photo_library`
  หรือใกล้เคียง, ขนาด ~16-18px, สีขาวบนพื้น `WynColors.imageScrim` เหมือน badge อื่นที่มีอยู่
  แล้วในระบบ เช่น duration badge ของ `HomePopCard` บรรทัด 197-214 — reuse สไตล์ badge เดิม ไม่
  คิดสีใหม่) — ไม่บังคับต้องมีเลขจำนวนรูปตรงนี้ (ต่างจาก `DropImageGallery`'s "1/3" badge ซึ่ง
  เป็นของ Detail screen คนละบริบท) เพราะภาพอ้างอิงเองก็ไม่มีตัวเลขกำกับ มีแค่ไอคอนเดียว

Interactions:
- ปาดนิ้ว (horizontal drag) บน carousel = เลื่อนดูรูปถัดไป/ก่อนหน้า ภายในการ์ดเดิม ไม่นำทางออก
  จากฟีด
- แตะที่รูปใดก็ได้ในการ์ด (single tap, ไม่ใช่ double-tap) = เปิด `DropDetailScreen` เหมือนเดิม
  ทุกจุด (พฤติกรรม `onTap` ของ `HomeDropCard` ทั้งใบไม่เปลี่ยน — carousel ไม่ intercept tap ไป
  จาก parent `InkWell` เดิม)
- Double-tap บนรูปใดก็ได้ = กดถูกใจ (`onToggleLike`) เหมือน `DoubleTapLike` เดิมที่ใช้กับรูป
  เดี่ยวอยู่แล้ว — ครอบทั้ง carousel ด้วย `DoubleTapLike` เดียว (ไม่ใช่แยกทีละรูป) ตาม pattern
  เดิมของ `DropImageGallery` (บรรทัด 98-106 ของไฟล์นั้น อธิบายเหตุผลไว้แล้วว่าทำไมต้องเป็น
  `GestureDetector` เดียวกัน ไม่แยก 2 ตัวซ้อนกัน — **ต้องระวังบั๊กเดียวกับที่ WYN-071 เคยเจอและ
  แก้แล้ว** (gesture arena ชนกันถ้าแยก `onTap` เป็นอีก `GestureDetector`)
- Scroll position ของ carousel **ไม่ต้อง persist ข้าม rebuild ของฟีด** (เช่นตอน pull-to-
  refresh) — กลับไปเริ่มที่รูปแรกใหม่ทุกครั้งที่การ์ดถูก rebuild เป็นพฤติกรรมที่ยอมรับได้และ
  ตรงกับพฤติกรรมทั่วไปของ feed ที่ virtualize การ์ดอยู่แล้ว

States:
- `_imageUrls == null` (ยัง fetch ไม่เสร็จ): แสดงแค่รูปแรก (`item.imageUrl`) เหมือน single-
  image เดิมไปก่อน ไม่มี loading spinner ทับ (เหมือน `DropImageGallery` ทำอยู่แล้ว — "show what
  we already have while more loads")
- `_imageUrls` fetch สำเร็จและมี > 1 รูป: แสดง carousel เต็มรูปแบบ
- `_imageUrls` fetch fail: fallback เหลือรูปแรกอย่างเดียว เงียบ ๆ ไม่มี error UI (ไม่บล็อกการดู
  โพสต์)
- `imageCount == 1` หรือ `null`: ไม่แสดง carousel เลย ใช้เส้นทางรูปเดี่ยวเดิม 100%

Responsive Behavior: ความกว้าง 82% คำนวณจากความกว้างการ์ดจริง (`MediaQuery`/`LayoutBuilder`
ของ parent) ไม่ hardcode พิกเซล เพื่อให้ทำงานถูกต้องทั้งจอมือถือแคบ/กว้าง และ Flutter Web

Accessibility: แต่ละรูปใน carousel ต้องมี `Semantics.label` บอกลำดับ (เช่น "รูปที่ 1 จาก 3 ของ
${item.authorNameOrUsername}") เหมือนที่ `DropImageGallery` ทำไว้แล้วสำหรับ dot indicator
(บรรทัด 140-142 ของไฟล์นั้น) — reuse ข้อความรูปแบบเดียวกัน

Design Rules:
- ห้ามใช้ `PageView`/full-bleed 1:1 แบบ `DropImageGallery` กับ Home feed card — ต้องเป็น peek-
  card 82%/4:5/gap 8px/มุมโค้ง 16px ตาม SPEC.md 4.7 เท่านั้น สองบริบทนี้ตั้งใจให้ต่างกัน
- ห้ามแก้ `DropImageGallery`/`DropImageViewer`/`DropDetailScreen`/`CreateDropScreen` ใด ๆ ในงาน
  นี้ — ขอบเขตอยู่ที่ `HomeDropCard`/`HomeFeedItem`/`home_feed` view เท่านั้น
- ห้ามเปลี่ยน treatment ของ Drop รูปเดียว (`AspectRatio(1)` เดิม) — ตาม "ขอบเขต" ด้านบน
- สีทุกจุด (badge, scrim) ต้องมาจาก `WynColors` เท่านั้น ห้าม hardcode `Color(0x...)` ใหม่ที่
  ไม่ได้อยู่ใน `wyn_colors.dart` อยู่แล้ว
- ต้อง reuse `DropRepository.fetchDropImages()` เดิม ห้ามสร้าง endpoint/query ใหม่ซ้ำซ้อน
- SQL: ต้องเพิ่มแค่ `image_count` (นับจำนวน) ห้าม embed URL รายการรูปเต็มเข้า `home_feed` view
  ตามเหตุผล payload ด้านบน

Handoff: ส่งต่อ AI Coding —
1. SQL migration ใหม่: `create or replace view public.home_feed` ฉบับเต็ม (ตาม convention เดิม
   ของไฟล์นี้ที่ "append a fresh full redefinition" ทุกครั้งที่แก้ view) เพิ่ม `image_count`
   ให้ branch `drop`/redrop, `null::bigint` ให้ branch `pop`
2. `app/lib/features/home/data/home_feed_item.dart`: เพิ่ม `imageCount`/`hasMultipleImages`
   ตามที่ระบุใน Components ด้านบน, อัปเดต `fromMap`/`copyWith`/`toDrop()`/`fromDrop()` ให้ผ่าน
   ค่านี้ครบทุก path (`fromDrop()` อ่านจาก `Drop.imageCount` ที่มีอยู่แล้ว)
3. Widget ใหม่ `HomeFeedImagePeekCarousel` ตาม Components ด้านบน — เพิ่มใน `HomeDropCard`
   บรรทัด 325-353 (แทนที่ `Image.network` เดี่ยว ๆ ด้วย conditional: `hasMultipleImages`
   → carousel ใหม่, ไม่งั้น → โค้ดเดิมทุกบรรทัด)
4. Regression ที่ต้องเช็คเป็นพิเศษ: Drop รูปเดียว (กรณีส่วนใหญ่ของระบบ) ต้องหน้าตา/พฤติกรรม
   เหมือนเดิม 100% ไม่มีอะไรเปลี่ยน, gesture arena ของ double-tap/single-tap ต้องไม่ชนกันแบบที่
   WYN-071 เคยเจอบั๊กมาแล้ว (ดู Interactions ด้านบน), `home_feed` view เดิมที่ 3 branch ต้อง
   ยังคืนค่าที่ถูกต้องหลังแก้ (SQL regression test ใหม่แนะนำชื่อ
   `wyn_092_home_feed_image_count_test.sh` มิเรอร์ style ของ `wyn_071_multi_image_drop_test.sh`)
5. `flutter analyze` + `flutter test` ต้องผ่านครบ ไม่มี regression กับ WYN-007/WYN-018/WYN-063
   (ranking algorithm ที่อ่าน `home_feed` เหมือนกัน — ตรวจว่า `image_count` ใหม่ไม่กระทบ query
   plan/performance ของ feed pagination)
