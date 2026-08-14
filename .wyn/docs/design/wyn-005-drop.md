# Design Spec — WYN-005: Drop (โพสต์รูปภาพ)

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md` (โดยเฉพาะ Color Direction ใหม่: Blue + White + Soft Gray, ห้าม Liquid Glass, ห้ามลอก Layout IG/TikTok)
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-005-drop-post-image.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `AvatarCircle` (WYN-003), image picker action-sheet flow (WYN-003/WYN-004), Post Card interaction pattern (WYN-004 — Like/Comment optimistic update, delete confirm dialog)

## ทิศทางภาพรวม: ทำไม Drop ไม่ใช่ "Feed เดิมที่กรองแค่รูป"

Drop เป็นแท็บแยกใน Bottom Nav ไม่ใช่ Home ที่กรองเอา — ถ้าออกแบบให้เหมือน Feed เดิม (single-column ไล่ตามเวลา) ก็จะรู้สึกซ้ำกับ Home ทันที (Home ก็แสดง Drop อยู่แล้ว) เพื่อให้แต่ละแท็บมีเหตุผลที่ต้องมีอยู่จริง ออกแบบ **Drop tab เป็น grid การ์ดรูปสี่เหลี่ยมจัตุรัส** (การเรียกดูเชิงภาพ/gallery) ต่างจาก Home ที่เป็น chronological feed แบบ single-column — คนละประสบการณ์การเสพคอนเทนต์ ไม่ใช่แค่ view เดียวกันที่กรองซ้ำ (และไม่ใช่ IG Feed tab แบบ single-column, ไม่ใช่ IG Explore tab แบบ algorithm-based เพราะนี่คือคอนเทนต์ตรงจากคนที่ผู้ใช้เห็นใน WYN เอง เรียงตามเวลาในรูปแบบ grid)

---

## Screen 1: Drop Feed (แท็บ Drop ใน Bottom Nav)

Purpose: เรียกดูรูปภาพ (Drop) ของทุกคนแบบ grid เรียงใหม่สุดก่อน

User Flow: แตะแท็บ "Drop" → เห็น grid รูปภาพ 3 คอลัมน์ → แตะรูปใดก็ได้ → ไป Drop Detail (Screen 3) → กด back กลับมา grid เดิม (คงตำแหน่ง scroll ไว้)

Components:
- AppBar: title "Drop" + ปุ่มไอคอน "+" มุมขวาบน (ไปหน้า Create Drop — ใช้ AppBar action แทน FAB ต่างจาก Feed เดิมของ WYN-004 เพื่อไม่ให้ FAB ไปทับ grid ที่ชิดขอบจอ)
- Grid 3 คอลัมน์ ช่องไฟระหว่างรูปบางมาก (1-2px) ให้ภาพต่อกันเป็นผืนเดียว รูปสี่เหลี่ยมจัตุรัสทุกช่อง (`AspectRatio(1)`)
- แต่ละช่อง grid: รูปภาพเต็มช่อง + แถบ scrim โปร่งแสงบางที่มุมล่างซ้าย (ไม่ใช่ Liquid Glass — เป็น gradient ทึบสีเข้มบาง ๆ ไล่จากล่างขึ้นบน) แสดงไอคอนหัวใจเล็ก + จำนวน Like (ตัวเลขเดียว ไม่แสดง Comment count ใน grid เพื่อไม่ให้รก)
- Pull-to-refresh ที่ด้านบนของ grid
- Infinite scroll แบบเดียวกับ Feed เดิมของ WYN-004

Interactions:
- แตะรูปใน grid → เปิด Drop Detail (Screen 3)
- แตะปุ่ม "+" → เปิด Create Drop (Screen 2)
- Pull-to-refresh → โหลด grid ใหม่ทั้งหมด
- เลื่อนถึงล่างสุด → โหลดหน้าถัดไปอัตโนมัติ

States:
- Loading (ครั้งแรก) — grid skeleton (ช่องสีเทาอ่อนตาม soft-gray palette แทนรูปจริง)
- Loaded — grid ปกติ
- Empty (ยังไม่มี Drop เลยในระบบ) — ข้อความเชิญชวน "ยังไม่มีใครแชร์รูปเลย เป็นคนแรกสิ!" พร้อมปุ่มไปสร้าง Drop ใหม่ (จัดกลางจอ แทนที่ grid)
- Error (โหลดไม่สำเร็จ) — ข้อความ error + ปุ่มลองใหม่
- Loading more — แถบ spinner บางท้าย grid

Responsive Behavior: Grid คงที่ 3 คอลัมน์บนมือถือ (ตาม mobile-first) รูปในแต่ละช่องปรับสัดส่วนตามความกว้างจอ คง 1:1 เสมอ

Accessibility: แต่ละช่อง grid มี semantics label รวม ("รูปของ {username}, ถูกใจ {N} ครั้ง") ไม่ใช่แค่ "รูปภาพ" เฉย ๆ ปุ่ม "+" มี tooltip/label "สร้าง Drop ใหม่"

Design Rules: ใช้สี Primary (Blue) เฉพาะจุดเน้น (ปุ่ม "+", loading indicator) ไม่ใช้ทาสีพื้นหลัง grid เป็นสีใด ๆ เพื่อให้รูปภาพเป็นจุดเด่นจริง ๆ (Soft Gray เฉพาะพื้นหลัง AppBar/skeleton)

Handoff: AI Coding — ใช้ `GridView.builder` (`SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3)`) พร้อม pagination pattern เดียวกับ `PostRepository.fetchFeed` ของ WYN-004 (เปลี่ยนชื่อ/ปรับให้เหมาะกับ Drop repository ใหม่)

---

## Screen 2: Create Drop

Purpose: ให้ผู้ใช้เลือก/ถ่ายรูป, crop เป็น 1:1, เขียนแคปชัน (พร้อม hashtag/mention แบบพิมพ์อย่างเดียว), แล้วโพสต์

User Flow: จาก Drop Feed กด "+" → เลือกรูปจากคลังภาพ/ถ่ายใหม่ → **รูปถูก crop กึ่งกลางเป็น 1:1 อัตโนมัติทันที** (ดู Design Rules) → เห็น preview รูปสี่เหลี่ยมจัตุรัส + เขียนแคปชัน → กด "แชร์" → กลับ Drop Feed เห็น Drop ใหม่อยู่บนสุดของ grid

Components:
- AppBar: ปุ่มปิด (กากบาท ซ้าย) + title "Drop ใหม่" + ปุ่ม "แชร์" (primary action, ขวาสุด)
- ขั้นตอนเลือกรูป: action sheet เดียวกับ WYN-003/WYN-004 (ถ่ายรูปใหม่ / เลือกจากคลังภาพ)
- Preview รูปสี่เหลี่ยมจัตุรัส (หลัง crop อัตโนมัติ) เต็มความกว้างจอ ด้านบนของฟอร์ม
- Text field แคปชัน ใต้รูป — placeholder "เขียนแคปชัน... ใส่ #hashtag หรือ @mention ได้" (บอกผู้ใช้ตรง ๆ ว่าใส่ได้ ไม่ต้องเดา)
- ตัวนับตัวอักษร (max 500, pattern เดียวกับ bio counter WYN-003)

Interactions:
- เลือก/ถ่ายรูปแล้ว **crop กึ่งกลางเป็น 1:1 ทันทีแบบอัตโนมัติ ไม่มีขั้นตอนลากปรับตำแหน่งใน V0.1 นี้** (ดู Design Rules ด้านล่างสำหรับเหตุผล scope)
- ปุ่ม "แชร์" **disable จนกว่าจะมีรูปภาพ** (รูปภาพเป็นบังคับสำหรับ Drop ตาม Product spec — ต่างจาก Feed & Post เดิมที่ข้อความอย่างเดียวก็โพสต์ได้)
- พิมพ์ `#คำ` หรือ `@username` ในแคปชัน → ไม่ต้องมี autocomplete/highlight แบบ real-time ใน V0.1 นี้ (แค่บันทึกข้อความดิบ ระบบ parse ตอน submit) — ตรงตามขอบเขตที่ Founder ยืนยันแล้วว่า "พิมพ์ได้ ระบบจำได้" พอ
- กด "แชร์" → upload รูป → สร้าง Drop → loading บนปุ่มระหว่างรอ → สำเร็จปิดหน้าจอกลับ Drop Feed

States:
- ยังไม่ได้เลือกรูป — แสดงพื้นที่ placeholder สี่เหลี่ยมจัตุรัสสี Soft Gray พร้อมไอคอน + ข้อความ "แตะเพื่อเลือกรูป" (แทนที่จะเปิด action sheet ทันทีตอนเข้าหน้านี้ ให้ผู้ใช้เห็นหน้าจอก่อนแล้วค่อยเลือกเอง ป้องกัน action sheet เด้งทันทีแบบไม่ทันตั้งตัว)
- Image picking (native picker กำลังเปิด)
- มีรูปแล้ว, กำลังพิมพ์แคปชัน (ปกติ)
- Sharing (กำลัง upload + สร้าง Drop) — disable ทุก input, ปุ่ม "แชร์" แสดง spinner
- Error (แชร์ไม่สำเร็จ) — inline error เหนือปุ่ม ไม่เสียรูป/แคปชันที่เลือกไว้

Responsive Behavior: Preview รูปคงสัดส่วน 1:1 เสมอไม่ว่าจอกว้างแค่ไหน ส่วนแคปชัน scroll ได้อิสระถ้าเนื้อหายาว

Accessibility: พื้นที่ placeholder เลือกรูปมี label "แตะเพื่อเลือกหรือถ่ายรูป" ปุ่ม "แชร์" ที่ disable ต้องประกาศเหตุผล (เช่น ผ่าน semantics hint "ต้องมีรูปภาพก่อนถึงจะแชร์ได้")

Design Rules: **Crop อัตโนมัติแบบไม่มี interactive drag ใน V0.1** เป็นการตัดสินใจลดขอบเขตโดยเจตนา (เหมือนที่ WYN-004 ยอมรับ offset pagination เป็น known limitation) — interactive crop (ลาก/ซูมปรับตำแหน่งก่อน crop) เป็น nice-to-have ที่เสนอให้ทำในรอบถัดไปถ้า Founder ต้องการ ไม่ block WYN-005 รอบแรก

Handoff: AI Coding — ใช้ `image_picker` (มีอยู่แล้ว) resize/compress เหมือน WYN-003/004 แล้ว crop กึ่งกลางเป็น 1:1 ด้วย logic ฝั่ง client (เช่น `ClipRect`/manual bounding-box crop จาก byte data ก่อน upload — ไม่ต้องพึ่ง package เพิ่มถ้าทำ center-crop แบบง่ายได้) เขียน parser หา `#hashtag`/`@mention` จาก caption string (regex พื้นฐานพอ ไม่ต้อง validate ว่า username มีจริงในรอบนี้)

---

## Screen 3: Drop Detail

Purpose: แสดง Drop เต็มจอ พร้อมคอมเมนต์ทั้งหมด, Like/Comment/Share/Save, และให้คอมเมนต์ใหม่ได้

User Flow: จาก Drop Feed แตะรูปใดก็ได้ → เห็นรูปเต็ม + แคปชัน + ปุ่ม Like/Comment/Share/Save ด้านบน + รายการคอมเมนต์ด้านล่าง → พิมพ์คอมเมนต์ที่ช่อง input ด้านล่างสุด → กดส่ง → คอมเมนต์ใหม่ปรากฏทันที

Components:
- AppBar: ปุ่มย้อนกลับมาตรฐาน + title "Drop"
- รูปภาพเต็มความกว้างจอ สัดส่วน 1:1 คงที่ (ไม่ครอปซ้ำ ใช้รูปเดียวกับที่ผู้ใช้ crop ไว้ตอนสร้าง)
- แถวผู้โพสต์: `AvatarCircle` + ชื่อแสดง/@username + เวลาที่โพสต์ (relative time) + ปุ่มลบ (ถังขยะ, เฉพาะ Drop ของตัวเอง)
- แคปชัน (ถ้ามี) ใต้รูป
- แถวปฏิสัมพันธ์: ปุ่ม Like (หัวใจ + จำนวน) / ปุ่ม Comment (บับเบิล + จำนวน, เลื่อนโฟกัสไปช่อง comment input) / ปุ่ม Share (ไอคอนแชร์ — เปิด share sheet ของระบบ + ตัวเลือก "คัดลอกลิงก์") / ปุ่ม Save (ไอคอน bookmark, toggle filled/outline)
- รายการ Comment (avatar เล็ก + ชื่อ + ข้อความ + เวลา + ปุ่ม Like เล็ก ๆ ข้างคอมเมนต์)
- ช่อง input คอมเมนต์ bottom-anchored พร้อมปุ่มส่ง

Interactions:
- กด Like/Save → toggle ทันที (optimistic UI, pattern เดียวกับ WYN-004 **ที่แก้บั๊ก double-tap แล้ว** — อ่าน state สดใหม่ทุกครั้งที่ handler ถูกเรียก ไม่ capture ค่าตอน build ดู `.wyn/learning/PATTERNS.md`)
- กด Share → เปิด native share sheet (รูป + ลิงก์) พร้อมตัวเลือกคัดลอกลิงก์แยก (toast "คัดลอกลิงก์แล้ว" เมื่อกด)
- กด Comment → เลื่อนจอ/โฟกัสไปที่ช่อง input คอมเมนต์ด้านล่าง (ไม่ต้องเปิดหน้าใหม่ ต่างจาก WYN-004 ที่ Comment แยกเป็นปุ่มไปหน้าอื่น — ที่นี่ทุกอย่างอยู่หน้าเดียวกันเพราะ Drop Detail คือหน้ารวมอยู่แล้ว)
- พิมพ์คอมเมนต์แล้วกดส่ง → เคลียร์ช่อง input → คอมเมนต์ใหม่ต่อท้ายรายการทันที (optimistic UI)
- กดปุ่มลบ Drop → dialog ยืนยัน "ลบ Drop นี้?" ก่อนลบจริงเสมอ (pattern เดียวกับ WYN-004)

States:
- Loading คอมเมนต์ครั้งแรก — skeleton
- Loaded — ปกติ
- Empty comment — "ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!"
- Sending comment — ปุ่มส่ง disable ชั่วคราว
- Error (โหลด/ส่งคอมเมนต์ไม่สำเร็จ) — inline error ตามจุดที่เกี่ยวข้อง

Responsive Behavior: รูปภาพ+แคปชัน+ปุ่มปฏิสัมพันธ์+รายการคอมเมนต์ต้อง scroll รวมเป็น list เดียวกัน (ไม่แยก scroll สองส่วน) — ใช้ pattern เดียวกับที่ WYN-004 แก้บั๊ก layout overflow บน viewport กว้าง/เตี้ยไปแล้ว (ดู `.wyn/tasks/approved/WYN-004-feed-and-post.md` หัวข้อ Coding Output) ช่อง input คอมเมนต์เท่านั้นที่ fix อยู่ด้านล่างเสมอ

Accessibility: ปุ่ม Like/Save ประกาศสถานะปัจจุบันเสมอ (เช่น "บันทึกแล้ว กดเพื่อเอาออกจาก Saved" / "กดเพื่อบันทึก") ปุ่ม Share มี label ชัดเจนแยกจากไอคอน

Design Rules: **ต้องรวม Drop header + comment list เป็น scrollable เดียวกันตั้งแต่แรก** อย่าแยกเป็นสองส่วนเหมือนที่ WYN-004 เคยพลาดตอน implement รอบแรก (ต้องแก้ทีหลัง) — งานนี้เรียนรู้ไว้แล้วให้ทำถูกตั้งแต่ต้น

Handoff: AI Coding — reuse pattern การจัดการ optimistic like/comment จาก `PostRepository`/`FeedScreen`/`PostDetailScreen` ของ WYN-004 (คัดลอกโครงสร้างที่ถูกต้องแล้ว ไม่ใช่ของเดิมก่อนแก้บั๊ก) เพิ่มตาราง `saves` ใหม่ใน schema (RLS insert/delete เฉพาะของตัวเอง, select ตามที่จำเป็นสำหรับ Profile → Saved ใน WYN-013)

---

## สรุป Flow รวม

```
Drop Feed (grid) ──(กด "+")──> Create Drop ──(แชร์สำเร็จ)──> กลับ Drop Feed (เห็น Drop ใหม่บนสุดของ grid)
Drop Feed (grid) ──(แตะรูป)──> Drop Detail ──(กด back)──> กลับ Drop Feed (คง scroll position)
```

## Handoff รวม

ส่งต่อ AI Coding (`/code`) เพื่อ implement 3 screens ข้างต้น — ต้องสร้างตาราง `drops`/`drop_likes`/`drop_comments`/`saves` ใน Supabase พร้อม RLS (pattern เดียวกับ `posts`/`likes`/`comments` ของ WYN-004 ทุกประการ), Storage bucket ใหม่สำหรับรูป Drop, อัปเดต Bottom Navigation ให้มี 4 แท็บ (Home/Drop/Pop/Profile — Home และ Pop ยังไม่ implement ในรอบนี้ ใส่เป็น placeholder ไปก่อนได้ถ้าจำเป็นต้องมี route ครบ) ต้อง QA & Security ตรวจสอบก่อน deploy เสมอ (ห้ามข้าม QA) — เน้นตรวจ double-tap guard ของ Like/Save ตั้งแต่รอบแรก (อย่าให้บั๊กเดิมของ WYN-004 เกิดซ้ำ)
