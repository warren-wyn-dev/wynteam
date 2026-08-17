# Design Spec — WYN-024: Drop Multi-Image Core

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (Color: Cyan primary ตาม `.wyn/docs/design/ds-001-color-system.md`, ห้าม Liquid Glass, ห้ามลอก Layout IG/TikTok)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-024-drop-multi-image-core.md` (R1–R5, AC, Risks)
อ้างอิง Design เดิมที่ต้อง reuse: `.wyn/docs/design/wyn-005-drop.md` (Screen 1–3 ของ Drop เดิม — เอกสารนี้ **แก้ไข/ต่อยอด** ไม่ใช่ทำใหม่), `.wyn/tasks/approved/DS-004-drop-image-first.md` (ยืนยัน image-first ต้องคงไว้)
อ้างอิงโค้ดจริงที่อ่านก่อนตัดสินใจ: `app/lib/features/drop/data/drop.dart`, `drop_repository.dart`, `presentation/create_drop_screen.dart`, `presentation/drop_detail_screen.dart`, `presentation/widgets/drop_grid_tile.dart`, `app/lib/features/home/presentation/widgets/home_drop_card.dart`, `app/lib/features/home/data/home_feed_item.dart`, `app/lib/features/club/presentation/widgets/club_post_card.dart` (`ClubPostImages`), `app/lib/core/design/wyn_colors.dart`/`wyn_spacing.dart`, `supabase/schema.sql` (WYN-005/WYN-007/WYN-013 sections)

---

## ทิศทางภาพรวม

Drop วันนี้เป็น "1 Drop = 1 รูป" ทุกจุด (`drops.image_url text not null`) — งานนี้เปลี่ยนเป็น "1 Drop = 1–9 รูป" โดย **ไม่แก้พฤติกรรมเดิมของ Drop ที่มี 1 รูปแม้แต่พิกเซลเดียว** (R5) และไม่แตะโครงสร้าง `drops` ที่ตารางอื่น (`drop_likes`/`drop_comments`/`drop_mentions`/`saves`) ผูก FK อยู่แล้ว — เพิ่มตารางใหม่แบบ additive ล้วนๆ

ก่อนออกแบบใหม่ ตรวจสอบแล้วว่า **Club post carousel (`ClubPostImages` ใน `club_post_card.dart`) มี pattern หลายรูปอยู่แล้วจริง** — เป็น `PageView.builder` เต็มความกว้าง (1 รูปเต็มจอต่อหน้า) + dot indicator ด้านล่าง สลับหน้าแบบ Instagram carousel — **ตัดสินใจ reuse pattern นี้ตรงๆ ไม่ออกแบบกลไก scroll ใหม่** (เหตุผลเต็มอยู่ในหัวข้อ "ทำไมใช้ PageView ไม่ใช่ filmstrip peek" ด้านล่าง) แต่ **ไม่แก้ไฟล์ Club ในรอบนี้** (Club ผ่าน QA แล้ว ไม่อยู่ในขอบเขต WYN-024 — ดู Design Rules)

---

## 1. Schema: ตาราง `drop_images` ใหม่ + Migration Strategy

### 1.1 ตัดสินใจ Migration: เก็บ `drops.image_url` ไว้เป็น "cover image" ที่ยัง NOT NULL เหมือนเดิม + backfill

Product spec (R1) ให้เลือกได้ระหว่าง (ก) ทำ `drops.image_url` เป็น nullable สำหรับ Drop ใหม่ หรือ (ข) backfill แถวเดียวเข้า `drop_images` — **เลือกทางที่ปลอดภัยกว่าทั้งสองทาง (dual-write + backfill) แทนการเลือกแค่ทางเดียว**:

- **`drops.image_url` ยังคง `not null` เหมือนเดิมทุกประการ ไม่แก้ constraint** — Drop ใหม่ทุกอันเขียน `image_url` เป็น URL ของรูปตำแหน่ง (`position`) 0 เสมอ (รูปแรกที่ผู้ใช้จัดไว้ใน Composer) พร้อมกับ insert แถวเข้า `drop_images` ครบทุกรูป (รวมรูปตำแหน่ง 0 ด้วย) — เป็น "app-level dual write" แบบเดียวกับที่ `createDrop` ทำกับ `drop_mentions` อยู่แล้ว (insert `drops` ก่อน แล้ว insert ตารางลูกทีหลังในทรานแซกชันเดียวกันฝั่ง client) ไม่ใช่สถาปัตยกรรมใหม่
- **One-time backfill migration**: insert `drop_images` position 0 ให้ทุกแถวเดิมของ `drops` จาก `image_url` เดิม (`insert ... select ... on conflict do nothing`, idempotent เหมือน `create table if not exists` ที่เหลือทั้งไฟล์)

**เหตุผลที่เลือกทางนี้แทนการทำ `image_url` เป็น nullable ล้วนๆ:**
1. **Zero SQL change ที่ `home_feed`/`saved_feed` views** — ทั้งสอง view (WYN-007/WYN-013) select `d.image_url` ตรงๆ อยู่แล้ว ถ้าเปลี่ยนเป็น nullable ต้องแก้ view + ทุกจุดที่ยังใช้ `image_url` เป็น fallback วันนี้ (relatively) — คงไว้ NOT NULL ทำให้ view เดิมทำงานถูกต้อง 100% โดยไม่ต้องแตะเลย (ยังใช้เป็น "รูปปก" ได้ต่อ ถ้าจุดไหนยังไม่ทันอัปเดตไปอ่าน `drop_images`)
2. **Drop เก่าก่อน migration ไม่มี edge case ต้อง handle พิเศษ** — เพราะ backfill ทำให้ Drop เก่าทุกอันมี `drop_images` แถวเดียว (position 0) เหมือน Drop ใหม่ที่มีแค่ 1 รูปทุกประการ — ทุก UI ที่จะเปลี่ยนไปอ่านจาก `drop_images` (ดูหัวข้อ 3-4) จึง**อ่าน source เดียวกันทั้งเก่าและใหม่** ไม่ต้องเขียน `if (drop_images ว่าง) fallback ไป image_url` ที่ไหนเลย — ตรงกับ AC "Drop เก่าที่มีแค่ 1 รูป ยังแสดงผลถูกต้อง ไม่พัง" แบบตรงไปตรงมาที่สุด
3. **ความเสี่ยง R1 ในเอกสาร Product ("migration กระทบ Drop เดิมที่ likes/comments/mentions/saves ผูกอยู่")** เป็นศูนย์จริงๆ เพราะ `drops.id`/`drops` แถวเดิมไม่ถูกแตะเลยแม้แต่คอลัมน์เดียว มีแต่ insert แถวใหม่เข้าตารางใหม่

### 1.2 คอลัมน์/FK/Index/Constraint

```sql
create table if not exists public.drop_images (
  id uuid primary key default gen_random_uuid(),
  drop_id uuid not null references public.drops (id) on delete cascade,
  image_url text not null,
  position integer not null,
  created_at timestamptz not null default now(),
  constraint drop_images_position_range check (position >= 0 and position <= 8),
  constraint drop_images_unique_position unique (drop_id, position)
);
```

- `on delete cascade` — ลบ Drop แล้วรูปลูกหายไปด้วยอัตโนมัติ เหมือน `drop_likes`/`drop_comments` ทุกประการ
- `unique (drop_id, position)` — ป้องกันข้อมูลชนตำแหน่งกัน **และทำหน้าที่เป็น index สำหรับ query `where drop_id = ...` ไปในตัว** (ไม่ต้องสร้าง index แยกซ้ำซ้อน — unique constraint ของ Postgres สร้าง index ให้อัตโนมัติอยู่แล้วและ column แรกของ composite index คือ `drop_id` พอดี)
- `check (position between 0 and 8)` — บังคับ "สูงสุด 9 รูป" (0-indexed 0–8) ที่ระดับ column constraint แบบง่ายที่สุด ไม่ต้องพึ่ง trigger สำหรับกฎนี้
- **Trigger เพิ่มเสริม (DB-level "อย่างน้อย ไม่เกิน 9 แถวต่อ drop_id")**: `position` range check กัน insert ตำแหน่ง ≥9 ได้แล้ว แต่ไม่กันกรณี insert ซ้ำที่ position เดิมถ้า client มีบั๊ก (unique constraint กันอยู่แล้วเช่นกัน) — ประเมินแล้ว **ไม่ต้องเพิ่ม trigger นับแถวแยกต่างหาก** เพราะ `position range check` + `unique(drop_id, position)` สองอันนี้ร่วมกันบังคับ "สูงสุด 9 แถวต่อ drop_id" ได้แน่นอนอยู่แล้วทางคณิตศาสตร์ (position ซ้ำไม่ได้ และ position มีแค่ 0–8 ให้เลือก) — ไม่ต้องเขียน trigger ซ้ำซ้อนกับสิ่งที่ constraint 2 ตัวทำได้อยู่แล้ว (ต่างจาก `drop_comments_prevent_nested_reply` ที่ต้องใช้ trigger เพราะ CHECK ธรรมดา query ตารางอื่นไม่ได้)
- **"อย่างน้อย 1 รูป" ไม่บังคับที่ DB** — เหมือนที่ Product spec ยอมรับว่าเป็น client-level constraint (ปุ่ม "แชร์" ยัง disable จนกว่าจะมีรูปเหมือนเดิมทุกประการ) เพราะการบังคับ "Drop ต้องมีอย่างน้อย 1 แถวลูกเสมอ" ที่ DB level ต้องใช้ deferred constraint ข้ามตาราง (ซับซ้อนเกินความจำเป็นเทียบกับ risk จริง — `drops.image_url not null` เดิมก็ยังทำหน้าที่เป็น "หลักฐานว่ามีอย่างน้อย 1 รูป" อยู่ดีในทางปฏิบัติ)

### 1.3 RLS — mirror `drops` เป๊ะ (select all authenticated, insert/delete เฉพาะเจ้าของ Drop)

```sql
alter table public.drop_images enable row level security;

create policy "Drop images are viewable by authenticated users"
  on public.drop_images
  for select
  to authenticated
  using (true);

create policy "Drop authors can add images to their own drops"
  on public.drop_images
  for insert
  to authenticated
  with check (
    exists (
      select 1 from public.drops
      where drops.id = drop_id and drops.author_id = auth.uid()
    )
  );

create policy "Drop authors can remove images from their own drops"
  on public.drop_images
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.drops
      where drops.id = drop_id and drops.author_id = auth.uid()
    )
  );
```

**ไม่มี update policy** — ตั้งใจ ไม่ใช่ช่องโหว่ที่ลืมทำ: `drops` เองก็ไม่มี update policy เช่นกัน (ยังไม่มีฟีเจอร์แก้ไข Drop จนกว่าจะถึง WYN-030 "Draft+Edit" ตาม roadmap) รูปใน `drop_images` จึงเป็น insert-then-immutable-until-delete เหมือนกับ `drops` ทั้งแถวทุกประการ ไม่จำเป็นต้องมี policy ที่ไม่มี use case จริงรองรับ (นับเป็น select/insert/delete = 3 policy ที่จำเป็นจริง — พื้นที่ความปลอดภัยจุดที่ 4 คือ **Storage bucket `drop-images` เดิม (WYN-005) reuse ได้ตรงๆ ไม่ต้องแก้** เพราะ policy เดิมอิงแค่ `(storage.foldername(name))[1] = auth.uid()::text` ไม่ผูกกับจำนวนไฟล์ต่อโพสต์อยู่แล้ว — path รูปที่ 2-9 แค่ตั้งชื่อไฟล์ไม่ชนกัน เช่น `{user_id}/{timestamp}-{index}.png`)

### 1.4 Backfill (รันครั้งเดียวต่อ environment เหมือนสไตล์ทั้งไฟล์)

```sql
insert into public.drop_images (drop_id, image_url, position)
select id, image_url, 0
from public.drops
on conflict (drop_id, position) do nothing;
```

---

## 2. Data Shape สำหรับ AI Coding (สรุปสั้น ไม่ลง implementation detail เต็ม — ให้ Coding ตัดสินใจ syntax เอง)

- `Drop` (`drop.dart`): เพิ่ม `List<String> imageUrls` (เรียงตาม `position` แล้ว) คู่กับ `imageUrl` เดิมที่ **คงไว้เป็น cover/back-compat field** (`= imageUrls.first` เสมอ) — จุดที่ยังอ่านแค่ `drop.imageUrl` (เช่น `DropGridTile` ที่แสดง thumbnail เดียว) ไม่ต้องแก้เลย
- `HomeFeedItem` (`home_feed_item.dart`): เพิ่ม `List<String> imageUrls` แบบเดียวกัน (ว่างเปล่าสำหรับ item ประเภท pop) — `HomeFeedItem.fromDrop`/`toDrop` ต้องพา field นี้ไป-กลับด้วย
- **วิธี populate `imageUrls`**: mirror pattern batched-secondary-query ที่ `DropRepository._fetchLikedDropIds`/`_fetchSavedDropIds` ทำอยู่แล้วทุกจุด (`fetchFeed`/`searchByCaption`/`fetchByAuthor`/`fetchFollowingFeed`/`fetchRankedFeed`/`fetchById`) — เพิ่ม `_fetchImagesByDropId({dropIds})` อีกตัว query `drop_images` ด้วย `.inFilter('drop_id', dropIds).order('position')` แล้ว group ฝั่ง client เป็น `Map<String, List<String>>` **ไม่ใช้ embedded PostgREST resource (`drops.select('*, drop_images(...)')`)** เพราะจะชนบั๊กเดิมที่เคยเจอแล้ว (`_dropAuthorSelect`'s comment ด้านบนของไฟล์ — PostgREST งงเมื่อมีหลาย embed ที่ join กลับไป `profiles`/ตารางเดียวกันในคำสั่งเดียว) การใช้ query แยกเหมือนที่ทำกับ liked/saved อยู่แล้วปลอดภัยกว่าและเป็น pattern เดิมของไฟล์นี้ 100%
- `HomeRepository`/`SavedRepository`: ใช้ pattern เดียวกัน — หลัง fetch หน้าเพจของ `home_feed`/`saved_feed` แล้ว กรองเอาเฉพาะ id ที่ `content_type == 'drop'` ไป query `drop_images` แบบ batched อีกครั้งก่อน map เป็น `HomeFeedItem`
- `DropRepository.createDrop`: เปลี่ยนพารามิเตอร์จาก `imageBytes`/`imageExtension` เดี่ยว เป็นลิสต์ที่มีลำดับ (เช่น `List<({Uint8List bytes, String extension})> images` หรือชนิดที่ Coding เห็นว่าอ่านง่ายกว่า) — อัปโหลดทุกไฟล์ก่อน (path `{userId}/{timestamp}-{index}.{ext}`), insert `drops` ด้วย `image_url = urls.first`, แล้ว insert `drop_images` ทุกแถว (`position: index`), แล้ว insert `drop_mentions` เหมือนเดิม — ลำดับ insert เป็น 3 ขั้นแบบเดียวกับที่ไฟล์นี้ทำกับ mentions อยู่แล้ว ไม่ใช่ pattern ใหม่

---

## 3. Screen: Create Drop (Composer) — Multi-select + Reorder

Purpose: เดิม (`.wyn/docs/design/wyn-005-drop.md` Screen 2) ยังใช้ได้ทั้งหมด — เพิ่มความสามารถเลือก/จัดการได้สูงสุด 9 รูปแทนที่จะเลือกได้แค่ 1 รูป

User Flow: จาก Drop Feed กด "+" → พื้นที่รูปว่างเหมือนเดิม ("แตะเพื่อเลือกรูป") → เลือกรูปจากคลังภาพแบบ multi-select (หรือถ่ายรูปใหม่ทีละใบ) → รูปที่เลือกทั้งหมด crop กึ่งกลางเป็น 1:1 อัตโนมัติทีละใบ (logic เดิมจาก `centerCropToSquare` เรียกซ้ำต่อรูป) → เห็น **preview เป็น grid 3 คอลัมน์** เรียงตามลำดับที่เลือก → ลากจัดลำดับใหม่ได้ / แตะ "x" ลบรูปออกได้ / แตะช่องว่างท้าย grid เพื่อเพิ่มรูปต่อ (จนครบ 9) → เขียนแคปชัน → กด "แชร์"

Components:
- **พื้นที่รูปตอนยังไม่มีรูปเลย**: เหมือนเดิมทุกพิกเซล (placeholder สี่เหลี่ยมจัตุรัสเต็มความกว้าง, ไอคอน `add_photo_alternate_outlined`, ข้อความ "แตะเพื่อเลือกรูป") — R5 ต้องไม่มี regression กับ flow เดิมของคนที่เลือกแค่ 1 รูป ต่อให้เป็น flow ใหม่ (multi-select) ก็ตาม
- **Action sheet เลือกรูป**: เดิม 2 ตัวเลือก ("ถ่ายรูปใหม่" / "เลือกจากคลังภาพ") — "ถ่ายรูปใหม่" ยังคงถ่ายได้ทีละใบ (ข้อจำกัดตามธรรมชาติของกล้อง) ส่วน "เลือกจากคลังภาพ" เปลี่ยนจาก `ImagePicker().pickImage()` (เลือกได้ 1 ใบ) เป็น `ImagePicker().pickMultiImage()` (เลือกได้หลายใบพร้อมกัน)
- **Preview grid (แทนที่พื้นที่รูปเดี่ยวเดิมเมื่อมี ≥1 รูป)**: grid 3 คอลัมน์ ช่องไฟ 2px ทุกช่องสี่เหลี่ยมจัตุรัส (`AspectRatio(1)`) — มิเรอร์ภาษาภาพเดียวกับ Drop Feed's browsing grid (WYN-005 Screen 1) ตั้งใจให้ Composer กับ Feed "ดูเป็นตระกูลเดียวกัน" แม้ mode การแสดงผลตอน publish จะต่างกัน (Row vs Grid)
  - **ช่องแรกสุด (position 0) มี badge เล็ก "ปก" มุมซ้ายบน** (สไตล์ pill scrim เดียวกับ badge จำนวนไลค์ใน `DropGridTile`) — สื่อสารชัดเจนว่ารูปนี้จะเป็นรูปที่ใช้แทน Drop นี้ในทุกจุดที่แสดง thumbnail เดียว (Drop tab grid/Search/Profile) ไม่ให้ผู้ใช้งง
  - แต่ละช่องมีปุ่ม "x" มุมขวาบน (วงกลมพื้นดำโปร่งแสง ไอคอนกากบาทขาว, ขนาด touch target ≥44px แม้ตัวไอคอนภาพจะเล็กกว่า) — แตะเพื่อลบรูปนั้นออก ตำแหน่งที่เหลือเลื่อนขึ้นอัตโนมัติ (re-index)
  - ช่องสุดท้าย (ถ้ายังไม่ครบ 9 รูป) เป็น "ช่องเพิ่มรูป" เส้นประ ไอคอน `add_photo_alternate_outlined` ตรงกลาง — แตะเพื่อเปิด action sheet เลือกรูปเพิ่มแบบเดิม
- **ตัวนับ**: "จำนวนรูป X/9" เล็กๆ เหนือ grid (bodySmall, `colorScheme.outline`) — บอกสถานะตลอดเวลาไม่ต้องรอ error ก่อนถึงจะรู้ว่าใกล้เต็ม

Interactions:
- เลือกรูปจากคลังภาพหลายใบพร้อมกัน → **ถ้ารวมกับรูปที่มีอยู่แล้วเกิน 9**: รับเฉพาะรูปแรกๆ เท่าที่ทำให้ครบ 9 พอดี (ไม่ปัดตกทั้งชุดที่เพิ่งเลือก) แล้วแสดงข้อความแจ้งทันที (ดู "ข้อความ Maximum 9 photos" ด้านล่าง) — ไม่ silently ตัดรูปโดยไม่บอกผู้ใช้เลยตาม AC
- แตะ "ช่องเพิ่มรูป" ตอนมี 9 รูปพอดีแล้ว: **ไม่มีช่องนี้ให้แตะอีกต่อไป** (grid เต็ม 9 ช่องพอดี ไม่มีช่องที่ 10 ให้วาด) — เคสที่ยังต้องกันคือถ่ายรูปใหม่ตอนมี 9 รูปแล้ว หรือเลือกจากคลังภาพเพิ่มตอนเต็มแล้ว → กดไม่ได้เพราะไม่มี UI ให้กด แต่ถ้า race เกิดขึ้น (เช่น picker เปิดค้างจากก่อนหน้า) ให้ guard เดียวกับที่ header บอก และแสดงข้อความ "Maximum 9 photos" ทันทีโดยไม่เปิด picker ซ้ำ
- **ลากจัดลำดับใหม่ (Reorder)**: กดค้าง (long-press) ที่รูปใดก็ได้ → รูปยกตัวขึ้นเล็กน้อย (scale ~1.05 + shadow) ให้รู้ว่ากำลังลาก → ลากไปทับช่องอื่น → ปล่อยนิ้ว → รูปทั้งสองสลับตำแหน่งกัน (หรือแทรกที่ตำแหน่งใหม่ ขึ้นกับ index ที่ปล่อย) → ตำแหน่งอื่นๆ re-index ตามลำดับที่แสดงบนจอทันที (optimistic, ไม่ต้อง publish ก่อนถึงจะเห็นผล)
  - **ตัดสินใจ implementation**: ใช้ `LongPressDraggable<int>` + `DragTarget<int>` ต่อช่อง grid (สร้างเอง ไม่เพิ่ม pub package ใหม่) แทนที่จะพึ่ง package `reorderable_grid_view` ภายนอก — เหตุผล: โปรเจกต์นี้เพิ่ม dependency ใหม่น้อยมากและมีเหตุผลกำกับทุกครั้ง (ดู comment ใน `pubspec.yaml`), Flutter ไม่มี reorderable grid ในตัว (`ReorderableListView` เป็นแนวตั้งอย่างเดียว) แต่ `LongPressDraggable`/`DragTarget` เป็น API มาตรฐานของ SDK ที่ทำ 3x3 grid reorder ได้ตรงไปตรงมาโดยไม่ต้องพึ่งอะไรเพิ่ม
- ลบรูป (กด "x"): ลบทันที ไม่มี dialog ยืนยัน (ต่างจากการลบ Drop/Comment ที่ publish ไปแล้ว — นี่เป็นแค่การจัดองค์ประกอบก่อน publish เอง ยกเลิกได้ด้วยการเลือกใหม่ ไม่จำเป็นต้องมี friction)
- ปุ่ม "แชร์": disable จนกว่าจะมี**อย่างน้อย 1 รูป** เหมือนเดิม (เงื่อนไขเปลี่ยนจาก `imageBytes != null` เป็น `images.isNotEmpty`)

States:
- ยังไม่มีรูป — เหมือนเดิมทุกประการ (ดู Components)
- Image picking / cropping ทีละใบ — spinner ทับช่องที่กำลังประมวลผล (ถ้า multi-select คืนมาหลายใบพร้อมกัน ประมวลผล crop ทีละใบต่อเนื่อง แสดง progress รวมสั้นๆ เช่น spinner กลาง grid ชั่วคราวระหว่างรอทั้งชุด ไม่ต้อง progress bar ละเอียดระดับเปอร์เซ็นต์)
- มีรูป 1–9 รูป, กำลังพิมพ์แคปชัน (ปกติ)
- **พยายามเกิน 9**: ข้อความแจ้งปรากฏใต้ตัวนับ/เหนือปุ่มแชร์ชั่วคราว (ใช้กลไก `_errorMessage` เดิมของหน้านี้ซ้ำ ไม่สร้างกลไกใหม่) แล้วหายไปเองเมื่อผู้ใช้ทำ action ถัดไป (เช่นเดียวกับ error อื่นในหน้านี้)
- Sharing (อัปโหลดหลายรูป + สร้าง Drop) — disable ทุก input เหมือนเดิม ปุ่ม "แชร์" แสดง spinner
- Error (แชร์ไม่สำเร็จ) — inline error เหมือนเดิม ไม่เสียรูป/ลำดับ/แคปชันที่จัดไว้

Responsive Behavior: grid คงที่ 3 คอลัมน์ (มือถือ), ทุกช่องคงสัดส่วน 1:1 เสมอไม่ว่าจอกว้างแค่ไหน (เหมือน Drop Feed grid เดิม)

Accessibility: แต่ละช่องมี Semantics label ระบุตำแหน่ง+การกระทำที่ทำได้ (เช่น "รูปที่ 1 จาก 5, รูปปก, กดค้างเพื่อจัดลำดับใหม่, มีปุ่มลบ") ปุ่ม "x" มี label "ลบรูปนี้" แยกจากไอคอน ปุ่ม "แชร์" ที่ disable ประกาศเหตุผลเหมือนเดิม ("ต้องมีรูปภาพอย่างน้อย 1 รูปก่อนถึงจะแชร์ได้")

**ข้อความ "Maximum 9 photos"**: AC ของ Product ใช้คำอังกฤษนี้เป็นตัวอย่าง concept แต่ **ทั้งแอปใช้ภาษาไทยล้วนทุกจุดจริง** (ปุ่ม/ข้อความ error อื่นทั้งหมดในหน้านี้และทั้งระบบเป็นไทย ตาม `AGENTS.md`'s "สื่อสารกับผู้ใช้เป็นภาษาไทย") — **ใช้ข้อความไทยที่สื่อความหมายเดียวกันแทนคำอังกฤษตรงตัว**: `"เพิ่มรูปได้สูงสุด 9 รูป"` — บันทึกไว้ชัดเจนที่นี่เพื่อไม่ให้ QA รอบหน้าตีความว่าไม่ตรง AC (เจตนาของ AC คือ "ต้องมีข้อความแจ้งชัดเจน ไม่ silently ตัด" ไม่ใช่ "ต้องเป็นสตริงอังกฤษตัวนี้เป๊ะ")

Design Rules: Composer ใช้ Grid ได้ตาม R3 ที่ Product อนุญาตไว้ตรงๆ — **ไม่ขัดกับกติกา "ห้ามลอก Layout IG"** เพราะ IG ไม่มี composer แบบ grid-reorder-with-cover-badge นี้ (IG ใช้ filmstrip แนวนอนเรียงตามลำดับที่เลือกในหน้า compose ของมันเอง) — grid ของเราเป็นภาษาภาพเดียวกับ Drop Feed ของ WYN เอง ไม่ใช่การลอกจากที่ไหน

Handoff: AI Coding — `ImagePicker().pickMultiImage()` (มี้อยู่แล้วใน `image_picker: ^1.1.2` ที่ pubspec ปัจจุบัน ไม่ต้อง bump version), เรียก `centerCropToSquare()` เดิมวนซ้ำต่อรูป, ปรับ `_buildImageArea()` ให้ conditionally render placeholder เดี่ยว vs grid ตามจำนวนรูปที่มี, เพิ่ม `LongPressDraggable`/`DragTarget` ต่อช่อง grid สำหรับ reorder

---

## 4. Published Rendering — Horizontal Single-Line Row (Component ใหม่ที่ Reuse ร่วมกัน)

### ทำไมใช้ PageView (แบบ Club) ไม่ใช่ filmstrip-peek

พิจารณา 2 แนวทางสำหรับ "Horizontal Single-Line Row" ตาม R4:

| แนวทาง | คำอธิบาย | ตัดสินใจ |
|---|---|---|
| **A. PageView เต็มความกว้าง (เลือกแนวทางนี้)** | ทุกรูปกว้างเท่า container พอดี (1:1), swipe เปลี่ยนรูปทีละใบเต็มจอ, มี dot indicator บอกตำแหน่ง — เหมือน `ClubPostImages` ที่มีอยู่แล้ว | ✅ ใช้ |
| B. Filmstrip peek (แต่ละช่องกว้างน้อยกว่า container ให้เห็นขอบรูปถัดไปโผล่มา) | ให้ความรู้สึก "มีต่อ" ชัดกว่าตั้งแต่แรกเห็นโดยไม่ต้อง swipe | ❌ ไม่ใช้รอบนี้ |

เหตุผลเลือก A:
1. **ตรงตามตัวอักษรของ R4 ทุกข้อ** — "Horizontal Scroll Container เดียว (ไม่ใช่แต่ละรูปมี scroll ของตัวเอง)" (`PageView` คือ scroll container เดียวจริงๆ), เรียงตาม `position`, ทุกรูป 1:1 ขนาดเท่ากัน, ไม่มี Grid/Wrap ไม่ว่าจะกี่รูป
2. **เป็น pattern ที่ผ่าน QA จริงมาแล้วในโปรเจกต์นี้** (WYN-014/015, Club) และพิสูจน์แล้วว่า **ไม่ชนกับ vertical scroll ของ list หลัก** เมื่อซ้อนอยู่ใน `ListView` แนวตั้ง (Club Posts tab, Home "จากClub ของคุณ") — ตรงกับ Risk R2 ของ Product doc เป๊ะ ("ใช้ pattern scroll ที่ทดสอบแล้วบน mobile จริง") มีประวัติจริงยิ่งกว่าการเริ่มลอง pattern ใหม่
3. **R5 (1 รูปเดิมต้องเหมือนเดิมทุกประการ) ทำได้ตรงไปตรงมาที่สุด**: เมื่อ `imageUrls.length == 1` ให้ render `Image.network` เปล่าๆ ตรงๆ (โค้ด path เดียวกับวันนี้ ไม่ผ่าน `PageView`/dot เลย) — ไม่มี dot ปรากฏเมื่อมีรูปเดียว เป๊ะตามพฤติกรรมเดิม 100%
4. **เรื่อง "ห้ามลอก Layout IG"**: การ swipe-ดูรูปทีละใบเป็น interaction pattern สากล (universal component) ไม่ใช่ "Layout" ระดับโครงหน้าจอที่กติกานี้ตั้งใจห้าม (เหมือนที่หัวใจสีแดง = Like เป็น convention สากลที่ design-principles.md เองก็ยอมรับไว้แล้ว) — Club ใช้ pattern เดียวกันนี้มาก่อนแล้วและผ่าน Founder/QA review เรียบร้อยไม่เคยถูกทักท้วงเรื่องนี้

### Component: `MultiImageRow` (ใหม่, `app/lib/core/widgets/`)

แยกเป็น shared widget ใหม่ (ไม่ใช่ private class ในไฟล์ Drop เดียว) เพราะจุดที่ต้องใช้พฤติกรรมเดียวกันมี 2 จุด (`DropDetailScreen`, `HomeDropCard` — การ์ดหลังใช้ร่วมทั้ง Home feed และ Drop feed 3 tab ตาม WYN-019) — วางไว้ที่ `core/widgets/` (ระดับเดียวกับ `hashtag_text.dart`/`confirm_delete_dialog.dart` ที่ใช้ข้าม feature อยู่แล้ว) ไม่ใช่ใน `features/drop/`

- Input: `List<String> imageUrls` (เรียงตาม position มาแล้วจาก data layer)
- `imageUrls.length == 1` → `AspectRatio(aspectRatio: 1, child: Image.network(imageUrls.single, fit: BoxFit.cover))` ตรงๆ (ไม่มี `PageView`/dot ห่อเลย)
- `imageUrls.length > 1` → `Column` เดียวกับที่ `ClubPostImages` ทำ: `AspectRatio(1, child: PageView.builder(...))` ด้านบน + แถว dot (6x6 circle, `colorScheme.primary` ตอน active / `colorScheme.outlineVariant` ตอนไม่ active, ห่าง 2px) ด้านล่าง
- เพิ่ม `Semantics` ต่อหน้า (`"รูปที่ ${page + 1} จาก ${imageUrls.length}"`) ที่ `ClubPostImages` ปัจจุบันยังไม่มี — เป็นการปรับปรุง accessibility เล็กน้อยไปพร้อมกัน ไม่ต้องรอ task แยก

**ขอบเขตของงานนี้ต่อไฟล์ Club**: **ไม่แก้ `club_post_card.dart` ในรอบนี้** — `ClubPostImages` ยังคงเป็น private widget แยกต่างหากเหมือนเดิม (แม้ logic จะซ้ำกับ `MultiImageRow` เกือบทั้งหมด) เพราะ Club ผ่าน QA และ deploy-ready อยู่แล้ว การแตะไฟล์นั้นเพิ่ม blast radius ที่ไม่จำเป็นสำหรับ scope ของ WYN-024 (แตะเฉพาะ Drop) — **บันทึกเป็น tech debt / optional follow-up**: รอบถัดไปที่มีเหตุผลต้องแตะ Club อยู่แล้ว ค่อยรวม `ClubPostImages` ให้เรียก `MultiImageRow` แทน (ลดโค้ดซ้ำ) ไม่ใช่ requirement ของ WYN-024

### Screen: Drop Detail (แก้ `.wyn/docs/design/wyn-005-drop.md` Screen 3)

ทุกอย่างเหมือนเดิมทั้งหมด **ยกเว้นจุดเดียว**: แทนที่ `AspectRatio(1, child: Image.network(_drop.imageUrl, ...))` ที่หัวข้อ header ด้วย `MultiImageRow(imageUrls: _drop.imageUrls)` — Layout ที่เหลือ (แถวผู้โพสต์, แคปชัน, แถวปฏิสัมพันธ์, comment list, comment input) **ไม่แก้อะไรเลย**

### Screen: Home feed card / Drop feed card (แก้ `HomeDropCard`)

เหมือนกัน — แทนที่ `AspectRatio(1, child: Image.network(item.imageUrl!, ...))` ด้วย `MultiImageRow(imageUrls: item.imageUrls)` จุดเดียว มีผลอัตโนมัติทั้ง Home feed และ Drop feed's 3 tab (For You/Following/Latest ตาม WYN-019 ที่ reuse การ์ดเดียวกัน)

---

## 5. Grid/Thumbnail Views — Indicator รูปเดียวที่แทนหลายรูป (`DropGridTile`)

จุดที่ต้องแก้: `DropGridTile` (ใช้ร่วมกัน 3 จุดจริง — ยืนยันจากโค้ด: `drop_feed_screen.dart`'s Drop tab grid, `search_drop_results_tab.dart`'s Search Drop tab, `profile_drop_grid_tab.dart`'s Profile grid tab — แก้ไฟล์เดียวมีผลครบทั้ง 3 จุดตามที่ AC ต้องการ)

Components:
- ยังคงแสดงแค่รูปเดียว (`drop.imageUrl`, = position 0 เสมอ) เต็มช่อง เหมือนเดิมทุกประการเมื่อ Drop มีรูปเดียว
- **เมื่อ `drop.imageUrls.length > 1`**: เพิ่ม badge เล็กมุม**ขวาบน** (มุมซ้ายล่างมี badge จำนวนไลค์อยู่แล้ว ไม่ชนกัน) — สไตล์ pill เดียวกับ badge duration ของ `PopGridTile` (`WynColors.imageScrim` พื้นหลัง, ขอบมน 3px) ข้างในเป็นไอคอน `Icons.collections` ขนาด 12px สีขาว **ไม่มีตัวเลขกำกับ** (แค่ไอคอนพอ — สื่อความหมาย "มีมากกว่า 1 รูป" ไม่ต้องบอกจำนวนแม่นยำในระดับ thumbnail เล็กขนาดนี้ ตัวเลขจริงเห็นได้ตอนเปิดเข้าไปดู)
- **เมื่อมีรูปเดียว**: ไม่มี badge นี้เลย (ตรงตาม requirement "ต้อง consistent กับ 1 รูปเดิม ไม่มี indicator เมื่อมีแค่ 1 รูป")

Accessibility: Semantics label เดิม `"รูปของ {username}, ถูกใจ {N} ครั้ง"` ต่อท้ายด้วย `", มีรูปทั้งหมด {count} รูป"` เมื่อมีหลายรูป (ไม่พึ่งไอคอน/สีอย่างเดียวสื่อความหมาย ตาม design-principles.md's accessibility rule)

Design Rules: เลือกไอคอน `Icons.collections` (ไม่ใช่ `Icons.photo_library` ที่ใช้ซ้ำอยู่แล้วในบริบท action-sheet "เลือกจากคลังภาพ" ของทั้ง `create_drop_screen.dart`/`edit_profile_screen.dart`) — เพื่อไม่ให้ไอคอนความหมายเดียวกันในเชิงภาพ (คลังรูป) ปรากฏในสองบริบทที่ต่างกัน (action ที่กดได้ vs indicator ที่กดไม่ได้) จนสับสน

---

## 6. สรุป Flow รวม

```
Create Drop: เลือก/ถ่ายรูป (multi-select, สูงสุด 9) ──> preview grid (ลบ/ลากจัดลำดับ) ──(แชร์)──> อัปโหลดทุกรูป + สร้าง drops แถวเดียว + drop_images N แถว ──> กลับ Drop Feed

Published Drop (ทุกจำนวนรูป 1-9):
  - Drop Detail / Home card / Drop feed card  → MultiImageRow (Horizontal Row เต็มความกว้าง, รูปเดียวไม่มี dot, หลายรูปมี dot)
  - Drop tab grid / Search / Profile grid     → DropGridTile (รูปแรกเสมอ + badge "collections" มุมขวาบนถ้ามีหลายรูป)
```

---

## Handoff

ส่งต่อ AI Coding (`/code`) เพื่อ implement:

1. **Schema** (`supabase/schema.sql`): เพิ่ม `drop_images` table + 3 RLS policy + backfill statement ตามหัวข้อ 1 ทุกตัวอักษร — verify กับ Postgres local จริงก่อนส่ง QA (ตาม pattern ที่ session ก่อนหน้าทำมาตลอด) โดยเฉพาะ backfill ต้อง idempotent จริง (รันซ้ำได้ไม่ error/ไม่สร้างข้อมูลซ้ำ)
2. **Data layer**: `Drop`/`HomeFeedItem` เพิ่ม `imageUrls`, `DropRepository`/`HomeRepository`/`SavedRepository` เพิ่ม batched secondary-query ของ `drop_images` มิเรอร์ pattern `_fetchLikedDropIds`/`_fetchSavedDropIds` ที่มีอยู่แล้ว, `createDrop` เปลี่ยนเป็นรับหลายรูป + insert แบบ dual-write ตามหัวข้อ 1.1/2
3. **Composer** (`create_drop_screen.dart`): multi-select, preview grid, reorder (`LongPressDraggable`/`DragTarget`, ไม่เพิ่ม package ใหม่), ลบรูป, "เพิ่มรูปได้สูงสุด 9 รูป" (ข้อความไทย ไม่ใช่ literal string อังกฤษของ AC) ตามหัวข้อ 3
4. **`MultiImageRow`** widget ใหม่ที่ `app/lib/core/widgets/` ตามหัวข้อ 4 — ใช้แทนที่ `Image.network` เดี่ยวใน `DropDetailScreen` และ `HomeDropCard` **2 จุดเท่านั้น** — **ห้ามแก้ `club_post_card.dart` ในรอบนี้**
5. **`DropGridTile`**: badge `Icons.collections` มุมขวาบนเมื่อมีหลายรูป ตามหัวข้อ 5 — มีผลอัตโนมัติทั้ง Drop tab/Search/Profile grid เพราะ widget เดียวกัน
6. เขียน regression test ครอบคลุม AC ทั้งหมดของ backlog doc (1/2/5/9 รูป publish สำเร็จ, บล็อกรูปที่ 10 พร้อมข้อความ, reorder ก่อน publish ตรงกับลำดับจริง, ทุกจุดแสดง Horizontal Row ไม่มี Grid/Wrap, Drop เก่า 1 รูปไม่พัง, RLS insert/delete จำกัดเจ้าของ) — โดยเฉพาะ **RLS ของ `drop_images` ต้อง verify กับ Postgres จริงเหมือนที่ WYN-021 เคยพลาดมาก่อน** (อย่าเชื่อแค่ policy syntax ถูกต้องบนกระดาษ ต้อง reproduce จริงว่า insert/delete ของคนอื่นถูกบล็อกจริง)
7. `flutter analyze`/`flutter test` ต้องผ่านครบ ไม่มี regression กับ WYN-005/007/009/013/018/019/020/021/022 ตามที่ AC ระบุ

ส่งต่อ AI QA & Security อิสระเมื่อ Coding เสร็จ (ห้ามข้าม QA ตาม WORKFLOW.md)
