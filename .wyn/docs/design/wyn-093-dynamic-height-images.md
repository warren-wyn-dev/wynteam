# Design Spec — WYN-093: รูปในฟีดยึดสัดส่วนจริง (Dynamic Height / Aspect Fit) + เกณฑ์ Clamp

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-093.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/home/presentation/widgets/home_drop_card.dart` (ปัจจุบัน `AspectRatio(aspectRatio: 1) + Image.network(fit: BoxFit.cover)` ตายตัว), `app/lib/features/drop/presentation/widgets/drop_grid_tile.dart` (grid 3 คอลัมน์โปรไฟล์ — **นอกสโคป**, ดูเหตุผลด้านล่าง)

ไม่มีภาพอ้างอิงที่ขาดสำหรับงานนี้ — Founder ระบุ requirement เป็นข้อความล้วน ("อิงตามสัดส่วนจริงของรูปภาพ ไม่ล็อกความสูงการ์ด") และ**มอบหมายให้ AI Design กำหนดเกณฑ์ min/max โดยตรง** (ตาม Handoff ของ Product task) — **พร้อมขึ้นโค้ดได้ทันที ไม่ต้องรอภาพ**

---

## ขอบเขต — เฉพาะการ์ดฟีด ไม่แตะ Grid โปรไฟล์

`DropGridTile`/`SavedGridTile` (grid 3 คอลัมน์ในโปรไฟล์) **ยังคงเป็น `AspectRatio(1)` ตายตัวเหมือนเดิม ไม่เปลี่ยน** — เหตุผล: WYN-005's Design spec เดิมตั้งใจให้ grid เป็นสี่เหลี่ยมจัตุรัสเท่ากันทุกช่องโดยเจตนา (เพื่อความเป็นระเบียบแบบ gallery) การให้แต่ละช่อง grid สูงไม่เท่ากันตามสัดส่วนภาพจริงจะทำให้ grid เสียระเบียบ 3-คอลัมน์ทันที (ช่องข้างกันสูงไม่เท่ากันจะดูรก) — Founder's requirement พูดถึง "รูปในฟีด" (feed) ตรงๆ ไม่ใช่ grid งานนี้จึงจำกัดเฉพาะ `HomeDropCard`'s media area (Home feed + Drop feed ทุก tab + hashtag feed ที่ reuse widget เดียวกัน) และควรใช้กฎเดียวกันกับ primary image ของ WYN-092 (multi-image card)

---

Screen: `HomeDropCard`'s media area — แทนที่ `AspectRatio(aspectRatio: 1)` ตายตัว

Purpose: ให้รูปแนวตั้ง/แนวนอน/จัตุรัสแสดงเต็มภาพจริงในฟีด ไม่ถูกครอบตัดขอบบน-ล่างจากการล็อก 1:1

## เกณฑ์ Clamp (AI Design กำหนดตามที่ Product task ขอ)

**Aspect ratio ที่ยอมให้แสดงแบบ "เต็มภาพจริง" (ไม่ crop): ระหว่าง 4:5 (0.8, แนวตั้งสุด) ถึง 1.91:1 (แนวนอนสุด)**

เหตุผลของตัวเลข:
- ครอบคลุมสัดส่วนภาพถ่ายทั่วไปเกือบทั้งหมด (ภาพมือถือแนวตั้งมาตรฐาน, ภาพสี่เหลี่ยมจัตุรัส, ภาพแนวนอนมาตรฐานกล้อง/มือถือ) — รูปส่วนใหญ่ที่ผู้ใช้อัปโหลดจะไม่โดน crop เลย ตรงกับเจตนาหลักของ requirement
- นอกช่วงนี้ (เช่น screenshot แชทยาวๆ แนวตั้งมาก, panorama แนวนอนมาก) เป็น edge case ที่ถ้าปล่อยเต็มสัดส่วนจริงจะทำให้การ์ดนั้นสูง/เตี้ยผิดปกติจนรบกวนจังหวะ scroll ของโพสต์อื่นในฟีดเดียวกัน (ตรงกับ Risk ที่ Product task ระบุเองว่า "กันภาพยาวเกินจอ") — จึงยอม crop เฉพาะ 2 ปลายนี้เท่านั้น ไม่ใช่ crop ทุกภาพเหมือนเดิม
- **ไม่ใช่การลอก layout ของแอปคู่แข่งใดๆ** — เป็นเกณฑ์ตัวเลขล้วนๆ (bound คำนวณจากอัตราส่วนภาพถ่ายมาตรฐานทั่วไป) ไม่ใช่การคัดลอกโครงหน้าจอ/ตำแหน่ง element ตามที่ design-principles.md ห้าม

**เพดานสูงสุดเสริม (ผูกกับความสูงจอ)**: ถึงแม้ aspect ratio จะอยู่ในช่วงที่ยอมรับได้ (เช่น 4:5) แต่บนจอที่สูงมาก (เช่น tablet ถือแนวตั้ง) ความสูงจริงอาจยังเยอะเกินไป — เพิ่มเงื่อนไข **`maxHeight = 0.75 × screen height (MediaQuery)`** เป็นเพดานที่สอง (ใครถึงก่อนใช้ค่านั้น) กันไม่ให้รูปเดียวครอบคลุมเกือบทั้งหน้าจอมองเห็นตอน scroll ผ่าน

**ความสูงต่ำสุด**: ไม่ต้องกำหนดขั้นต่ำแยก เพราะ bound แนวนอน (1.91:1) เองก็ทำหน้าที่นี้อยู่แล้ว (ความกว้างการ์ดคงที่ = เต็มจอ, อัตราส่วนแนวนอนสุดที่ 1.91:1 คำนวณความสูงต่ำสุดได้เองจากความกว้างจอ ไม่ต้องมีค่าคงที่แยก)

## Components

- คำนวณ `displayAspectRatio = clamp(trueAspectRatio, 0.8, 1.91)` จาก **ขนาดรูปจริงที่รู้ล่วงหน้า** (ดู "การจัดการ performance" ด้านล่าง — ห้ามรอโหลดรูปเต็มถึงจะรู้ความสูง)
- ห่อด้วย `ConstrainedBox(maxHeight: 0.75 * MediaQuery.of(context).size.height)` เพิ่มจาก `AspectRatio` เดิม
- เมื่อ `trueAspectRatio` อยู่นอกช่วง clamp: ใช้ `BoxFit.cover` ครอบตัดเฉพาะส่วนเกิน (เหมือนพฤติกรรมเดิม) — เมื่ออยู่ในช่วง: ใช้ `BoxFit.cover` เช่นกันแต่ภายใน box ที่คำนวณสัดส่วนตรงกับรูปจริงแล้ว (จึงไม่มีการ crop จริง เพราะกรอบเท่ากับรูปพอดี — `BoxFit.cover` ปลอดภัยกว่า `contain` เพราะไม่มีแถบพื้นหลังว่างสองข้าง)

## การจัดการ Performance (ปิด Risk R1 ของ Product task)

**ต้อง cache ขนาดรูปไว้ตอนอัปโหลด ไม่ใช่คำนวณจากไฟล์รูปที่โหลดมาระหว่าง scroll** — เหตุผล: ถ้าไม่รู้ aspect ratio ล่วงหน้า การ์ดจะต้องรอโหลดรูปเสร็จก่อนถึงจะรู้ความสูงตัวเอง ทำให้ layout กระโดด (jank) ระหว่าง scroll เร็วๆ ตรงกับที่ Risk ของ Product task เตือนไว้ตรงๆ

- Data layer เพิ่ม `image_width`/`image_height` (integer, nullable) เข้า `drop_images`/`drops` table — เขียนค่าตอน `CreateDropScreen` อัปโหลดรูป (มีขนาดอยู่แล้วในหน่วยความจำตอน compress/resize ก่อน upload อยู่แล้ว ไม่ต้องคำนวณเพิ่ม)
- `HomeFeedItem`/`Drop` เพิ่ม field `imageWidth`/`imageHeight` (nullable) — ใช้คำนวณ `trueAspectRatio = imageWidth / imageHeight` ได้ทันทีตอน build widget โดยไม่ต้องรอ `Image.network` โหลด
- **Drop เก่าที่ไม่มี metadata นี้ (อัปโหลดก่อนงานนี้ deploy)**: `imageWidth`/`imageHeight` เป็น `null` → fallback เป็น `AspectRatio(1)` ตายตัวแบบเดิมทุกประการ (ไม่ crash ไม่พยายามเดา ไม่รอโหลดรูปเพื่อวัดขนาดในเดี่ยว-เดี่ยว) — Drop เก่าจะไม่ได้ dynamic-height จนกว่าจะมีการรัน backfill แยก (นอกสโคปงานนี้ ถือเป็น known gap ที่ยอมรับได้เพราะโพสต์เก่าอยู่แล้วในฟีดเป็นสัดส่วนน้อยลงเรื่อยๆ เทียบกับโพสต์ใหม่)

## States

- มี `imageWidth`/`imageHeight` ครบ → dynamic height ตาม clamp ข้างบน
- ไม่มี (Drop เก่า/ค่า null) → `AspectRatio(1)` เดิม
- โหลดรูปจริงไม่สำเร็จ (network error) → พฤติกรรม error/placeholder เดิมของ `Image.network`'s `errorBuilder` ไม่เปลี่ยน (ยังอยู่ในกรอบขนาดที่คำนวณไว้แล้วจาก metadata)

## Responsive Behavior

ทดสอบ 3 กรณีตาม Acceptance Criteria: รูปแนวตั้ง (เช่น 4:5, 3:4), แนวนอน (เช่น 16:9, 1.91:1), จัตุรัส (1:1) — ต้องแสดงเต็มภาพไม่ crop ทั้ง 3 กรณี (อยู่ในช่วง clamp พอดี) — ทดสอบ scroll เร็วในฟีดที่มีรูปหลายสัดส่วนต่อกัน (ListView/CustomScrollView) ต้องไม่มี layout jank เพราะ metadata รู้ล่วงหน้าแล้วตามที่ระบุข้างบน

## Accessibility

ไม่มีการเปลี่ยนแปลง Semantics — ข้อมูลสัดส่วนภาพเป็นเรื่อง visual layout ล้วน ไม่กระทบ screen reader label ที่มีอยู่แล้ว ("รูปของ {username}")

## Design Rules

- Clamp bound (0.8 – 1.91) เป็นค่าเดียวที่ใช้ทั่วทั้งแอปสำหรับ context นี้ — ห้ามมีค่าต่างกันระหว่าง Home feed / Drop feed tab / hashtag feed (ทั้งหมด reuse `HomeDropCard` ตัวเดียวอยู่แล้ว จึงเป็นค่าเดียวโดยอัตโนมัติ)
- ใช้ตรงกับ primary image ของ WYN-092's multi-image peek card ด้วย (ไม่มีเกณฑ์แยก)
- ห้ามเปลี่ยน `DropGridTile`/`SavedGridTile`/grid โปรไฟล์ (ยังเป็น 1:1 ตายตัวตามเหตุผลข้างบน)

## Handoff

AI Coding —
1. Schema: เพิ่ม `image_width`/`image_height` เข้า `drop_images` (และ `drops` สำหรับ backward-compat กับ Drop รูปเดียวเก่าที่ยังอ้างจาก `drops.image_url` ตรงๆ) — เขียนค่าตอน `CreateDropScreen`/`DropRepository.createDrop()` อัปโหลด
2. `HomeFeedItem`/`Drop` เพิ่ม `imageWidth`/`imageHeight` (nullable int) — ส่งผ่าน `home_feed` view
3. แก้ `HomeDropCard`'s media area: คำนวณ `displayAspectRatio` ตามสูตร clamp ข้างบน, ห่อด้วย `ConstrainedBox(maxHeight: ...)` เพิ่ม
4. Regression: Drop เก่า (ไม่มี metadata) ต้อง render เหมือนเดิมทุกประการ (1:1) — เขียน widget test ยืนยันทั้ง 2 กรณี (มี metadata / ไม่มี) และยืนยัน clamp ทำงานถูกต้องที่ขอบทั้งสองด้าน (ทดสอบด้วยค่า aspect ratio สุดขั้ว เช่น 0.3 และ 4.0 ต้องถูกบีบเข้า 0.8/1.91)

**สถานะ: พร้อมขึ้นโค้ดทันที** — ไม่มีภาพอ้างอิงที่ขาด ทุกตัวเลขเป็นการตัดสินใจของ AI Design ตามที่ Product task มอบหมายไว้ตรงๆ
