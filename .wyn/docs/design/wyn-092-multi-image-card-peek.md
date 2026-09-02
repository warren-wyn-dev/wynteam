# Design Spec — WYN-092: การ์ดโพสต์หลายรูป (รูปแรกเต็ม รูปที่ 2 โผล่ขอบ)

Owner: AI Design → AI Coding
Ref: `.wyn/tasks/backlog/WYN-092.md`
โค้ดที่ตรวจแล้ว: `app/lib/features/home/presentation/widgets/home_drop_card.dart`, `app/lib/features/drop/presentation/widgets/drop_image_gallery.dart` (multi-image pattern ที่มีอยู่แล้วใน `DropDetailScreen`), `app/lib/features/drop/data/drop.dart` (`Drop.imageCount`/`hasMultipleImages`), `app/lib/features/home/data/home_feed_item.dart` (ยังไม่มี field เทียบเท่า)
Dependency: WYN-091 (restyle การ์ด), WYN-093 (aspect-fit — งานนี้อิง clamp เดียวกัน), WYN-103 (limit 9 รูป — นอกสโคป Phase 2 นี้ ไม่แตะ)

> **Founder แนบภาพอ้างอิงมากับ PDF** (ข้อ 14/28) — **session นี้ไม่มีไฟล์ภาพนั้น** ออกแบบจากคำพูด Founder เท่านั้น: **"รูปแรกเห็นเต็มๆ รูปที่ 2 โผล่นิดเดียว"** — ตัวเลข/สัดส่วนที่ระบุด้านล่างเป็น**จุดเริ่มต้นที่สมเหตุสมผลจาก UX judgment ไม่ใช่ค่าที่วัดจากภาพจริง** ทั้งเอกสารนี้เป็น **draft รอ Founder ยืนยันเทียบกับภาพต้นฉบับ**

---

## ขอบเขต — แยกจาก `DropImageGallery` ที่มีอยู่แล้วโดยเจตนา

`DropDetailScreen` มีระบบดูรูปหลายรูปที่ทำงานสมบูรณ์อยู่แล้ว (`DropImageGallery`, WYN-071): `PageView` เต็มความกว้าง + ตัวเลข "N/M" มุมขวาบน + จุดไข่ปลา (dot indicator) กึ่งกลางล่าง — **งานนี้ไม่แตะ `DropImageGallery`/`DropDetailScreen` เลย** เพราะ (1) เป็น pattern ที่อนุมัติ+ขึ้นโค้ดแล้วจริงสำหรับหน้ารายละเอียด (2) คำพูดของ Founder ("เป็นการ์ด รูปแรกเต็มๆ") ตรงกับบริบท**การ์ดในฟีด**มากกว่าหน้าจอเต็ม — โพสต์เดียวกันจะมีหน้าตาต่างกัน 2 แบบตามบริบท (การ์ดย่อในฟีด vs เปิดเต็มจอดูรายละเอียด) ซึ่งเป็นเรื่องปกติของหลายแพลตฟอร์ม ไม่ใช่ความไม่สอดคล้องที่ต้องแก้

**Data gap ที่ต้องปิดก่อน**: `HomeFeedItem` (ที่ `HomeDropCard` ใช้) **ยังไม่มี field จำนวนรูป** (`Drop` model มี `imageCount`/`hasMultipleImages` อยู่แล้วจาก WYN-071 แต่ `HomeFeedItem`/`home_feed` view ไม่ได้ส่งค่านี้มาด้วย) — ต้องเพิ่ม `imageCount` เข้า `home_feed` view + `HomeFeedItem` ก่อน ถึงจะรู้ว่าการ์ดไหนควรโชว์ peek (ระบุใน Handoff)

---

Screen: `HomeDropCard`'s media area — เฉพาะกรณี `imageCount >= 2` (แทนที่ `AspectRatio(1) + Image.network(item.imageUrl!)` เดี่ยวปัจจุบัน)

Purpose: บอกผู้ใช้ทันทีในฟีดว่าโพสต์นี้มีรูปมากกว่า 1 รูป แบบชวนกดดูต่อ โดยไม่ต้องกดเข้า Detail ก่อน

User Flow: เลื่อนฟีดผ่านโพสต์หลายรูป → เห็นรูปแรกเต็มความกว้างการ์ด + ขอบรูปที่ 2 โผล่มานิดหน่อยทางขวา → ลากนิ้ว (swipe) ไปทางซ้ายบนรูป → รูปเลื่อนเป็นรูปที่ 2 เต็มจอ + รูปที่ 3 โผล่ขอบ (ถ้ามี) → แตะที่ตัวรูป (ไม่ใช่ลาก) → เปิด `DropDetailScreen` ตามปกติ (behavior เดิมของการ์ดไม่เปลี่ยน)

Components:
- **Primary image**: กว้างเต็มการ์ด (เหมือนปัจจุบัน) สูงตาม aspect-ratio จริงของรูปแรก คำนวณตามกฎ clamp เดียวกับ WYN-093 (ดู `.wyn/docs/design/wyn-093-dynamic-height-images.md`) — งานนี้ไม่กำหนด aspect ratio ของตัวเองซ้ำ อ้างอิง spec นั้นตรงๆ
- **Peek strip**: แถบขอบรูปถัดไป โผล่จากขอบขวาของการ์ด กว้างประมาณ `WynSpacing.space6` (24px) ถึง `WynSpacing.space8` (32px) — **ค่าตั้งต้น draft: 28px** (ค่ากึ่งกลางระหว่าง 2 token ที่มีอยู่แล้ว ไม่ใช่ token ใหม่ — ปรับเป็น 24 หรือ 32 ตรงๆ ได้ถ้า Founder เทียบกับภาพแล้วเห็นว่าเหมาะกว่า) สูงเท่ากับ primary image (ใช้ `Stack` วาง `Positioned(right: 0)` ครอบด้วย `ClipRect` ตัดความกว้าง)
- **ตัวคั่นระหว่างรูปแรกกับ peek**: เส้นแนวตั้งบาง 1-2px สี `WynColors.paper` (หรือ scrim จางๆ) ให้รู้สึกว่าเป็นรูปคนละใบ ไม่ใช่รูปเดียวถูกตัดขอบ — ไม่ใช่เงา/gradient ฟุ้ง (ตาม "ห้าม Liquid Glass")
- **ตัวนับ "N/M"**: มุมขวาบนของ primary image เมื่อ `imageCount >= 2` — reuse component เดิมเป๊ะจาก `DropImageGallery` (`WynColors.imageScrim` พื้นหลัง, `radius 12`, ตัวหนังสือขาว 12px) เพื่อความสม่ำเสมอทางภาพระหว่างฟีดกับ Detail แม้ layout ต่างกัน
- **Multi-image indicator ไอคอนเล็ก** (`Icons.filter_none`, ที่ `DropGridTile` ใช้อยู่แล้วจาก WYN-071): **ไม่ต้องใช้ในการ์ดฟีดแบบใหม่นี้** เพราะ peek strip เองทำหน้าที่สื่อสาร "มีรูปเพิ่ม" อยู่แล้วโดยไม่ต้องมีไอคอนซ้ำ (icon นี้ยังคงใช้ต่อไปเฉพาะใน `DropGridTile`/grid โปรไฟล์ ที่ไม่มีพื้นที่พอสำหรับ peek strip)

Interactions:
- **Swipe/drag แนวนอนบนพื้นที่รูป** → เปลี่ยนรูปปัจจุบัน (เหมือน `PageView` แต่อยู่ในสถานะพัก [rest state] ก็ยังเห็นรูปถัดไปโผล่ขอบอยู่เสมอ ไม่ใช่ซ่อนสนิทแบบ `PageView` เริ่มต้น — implementation แนะนำ: `PageView.builder` ปกติ ครอบด้วย padding ขวา `-peekWidth` เพื่อดึงรูปถัดไปให้โผล่เข้ามาในกรอบมองเห็น หรือใช้ `Stack` วาดรูปถัดไปไว้ข้างหลังแล้วสลับด้วย `AnimatedPositioned` เมื่อลาก — **รายละเอียด implementation ปล่อยให้ AI Coding เลือกวิธีที่ smooth ที่สุด ไม่ล็อกวิธีทำ แค่ล็อก "หน้าตาตอนพัก" ตามที่ระบุข้างบน**)
- **แตะที่รูป (ไม่ลาก)** → เปิด `DropDetailScreen` เหมือนเดิมทุกประการ — behavior เดิมของทั้งการ์ด (`onTap`) ต้องยังทำงาน ไม่ถูกแทนที่ด้วย gesture ใหม่ (มิเรอร์ pattern ที่ `DropImageGallery` พิสูจน์แล้วว่า tap กับ horizontal-drag แยกกันได้โดยไม่ชนกัน — ดู doc comment ของไฟล์นั้น)
- **Double-tap** → ไลค์ (เหมือนเดิม, `DoubleTapLike` ยังห่อพื้นที่รูปอยู่)
- **แตะที่ peek strip โดยเฉพาะ** → ทางเลือกเสริม: เลื่อนไปรูปถัดไปทันที (ไม่บังคับ ถ้า implement ยากให้ปล่อยเป็นแค่ "ลากเพื่อดู" อย่างเดียวก็ได้ — ไม่ block)

States:
- `imageCount == 1` หรือไม่มีรูป → media area เหมือนปัจจุบันทุกประการ (ไม่มี peek, ไม่มีตัวนับ) — **ไม่กระทบโพสต์รูปเดียว/ไม่มีรูปเลย**
- `imageCount >= 2` แต่ยังโหลด URL รูปที่เหลือไม่เสร็จ (ต้อง fetch แยกเหมือน `DropImageGallery._load()`) → แสดงรูปแรก (`item.imageUrl`) เต็มความกว้างไปก่อน **ไม่มี peek** จนกว่าจะโหลดรายชื่อรูปครบ (มิเรอร์ `DropImageGallery`'s fallback behavior เป๊ะ — "แสดงสิ่งที่มีอยู่แล้วระหว่างโหลดเพิ่ม" ไม่ใช่โชว์ spinner ทับรูป)
- โหลดรายชื่อรูปล้มเหลว → fallback เหมือนกรณี `imageCount == 1` (แสดงรูปแรกอย่างเดียว ไม่ error ทั้งการ์ด)

Responsive Behavior: peek width (28px draft) เป็นค่าคงที่ไม่ผูกกับความกว้างจอ — บนจอแคบมาก (320-360px) ต้องยืนยันว่า primary image ยังกว้างพอสมควร (การ์ดกว้างลบ 28px ยังเหลือ >90% ของความกว้างจอ ไม่ใช่ปัญหาจริง)

Accessibility: `Semantics(label: 'รูปที่ ${current+1} จาก $imageCount, ปัดเพื่อดูรูปถัดไป')` ครอบพื้นที่รูป (มิเรอร์ `DropImageGallery`'s semantics เดิม) — ตัวนับ "N/M" ใช้ `ExcludeSemantics` (เหมือนต้นแบบ เพราะ semantics label หลักบอกข้อมูลเดียวกันแล้ว ไม่ต้องอ่านซ้ำ)

Design Rules:
- ห้ามใช้สีใหม่ — เส้นคั่น/scrim ใช้ `WynColors.paper`/`imageScrim` ที่มีอยู่แล้ว
- Peek width เป็น**ค่าประมาณเริ่มต้น** ไม่ใช่ pixel-perfect ตามภาพจริง (ไม่มีภาพให้เทียบ) — AI Coding ทำตามนี้ไปก่อนได้ แต่ AI QA & Security ต้องขอ Founder เทียบภาพจริงหลัง merge ก่อนถือว่าปิดงาน
- ต้อง apply กฎ clamp ความสูงเดียวกับ WYN-093 กับ primary image เสมอ ไม่มีข้อยกเว้น

Handoff: **อย่าเพิ่งขึ้นโค้ดจนกว่า Founder ยืนยัน peek width/สไตล์เทียบกับภาพต้นฉบับ** (ถามผ่าน popup พร้อมตัวเลขที่เสนอ: "ใช้ 24px / 28px / 32px" หรือ "ขอดูภาพอ้างอิงอีกครั้ง") เมื่อยืนยันแล้วส่ง AI Coding:
1. Data layer: เพิ่ม `image_count`/`imageCount` เข้า `home_feed` view + `HomeFeedItem` (มิเรอร์ `Drop.imageCount` ที่มีอยู่แล้ว, ใช้ `drop_images(count)` เดียวกับที่ `DropRepository` เลือก column ชุดนี้อยู่แล้ว)
2. Widget ใหม่ `HomeDropCardImageStack` (หรือชื่อเทียบเท่า) แยกออกจาก media-area logic เดิมของ `HomeDropCard` — เรียก `DropRepository.fetchDropImages()` เดิมซ้ำได้ (method นี้มีอยู่แล้ว ไม่ต้องสร้างใหม่)
3. Performance (Risk R1 ของ Product task): lazy-load เฉพาะรูปที่ index ปัจจุบัน + รูปถัดไป (สำหรับ peek) ไม่โหลดรูปทั้งหมดของโพสต์พร้อมกันตอน build การ์ด
4. Regression: ต้องไม่กระทบ `DropDetailScreen`/`DropImageGallery`/`DropGridTile` เลย (คนละ widget กันเจตนา)

## สรุปสถานะ

**Draft — รอ Founder ยืนยันภาพอ้างอิง (โดยเฉพาะ peek width) ก่อนส่ง AI Coding**
