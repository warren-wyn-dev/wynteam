# Design Spec — WYN-004: Feed & Post

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md`
อ้างอิง Product Spec: `.wyn/tasks/active/WYN-004-feed-and-post.md`
อ้างอิง Pattern ที่มีอยู่แล้ว: `AvatarCircle` (WYN-003), image picker flow (WYN-003 Edit Profile)

---

## Screen 1: Feed (แทนที่ placeholder ของ `HomeScreen`)

Purpose: หน้าหลักของแอป แสดงโพสต์ของทุกคนแบบ Global Feed เรียงใหม่สุดก่อน

User Flow: เปิดแอป (หลัง login) → เห็น Feed ทันที → เลื่อนดูโพสต์ → กด Like/กดเข้าไปคอมเมนต์/กด avatar หรือ FAB เพื่อสร้างโพสต์ใหม่

Components:
- AppBar: title "WYN" + ปุ่มไอคอนโปรไฟล์ (ของเดิมจาก WYN-002/003) — ปุ่ม logout ย้ายไปอยู่ในหน้าโปรไฟล์แทน (ดูหมายเหตุ Design Rules)
- รายการ **Post Card** ต่อกันเป็น list, แต่ละใบมี:
  - แถวบน: `AvatarCircle` เล็ก (radius 20) + ชื่อแสดง/@username + เวลาที่โพสต์ (relative time เช่น "5 นาทีที่แล้ว")
  - ข้อความโพสต์ (ถ้ามี)
  - รูปภาพโพสต์ (ถ้ามี) — เต็มความกว้างการ์ด, aspect ratio คงที่ (เช่น 4:3) พร้อม loading skeleton ระหว่างโหลด
  - แถวล่าง: ปุ่ม Like (ไอคอนหัวใจ + จำนวน, toggle filled/outline ตามสถานะ) + ปุ่ม Comment (ไอคอนบับเบิล + จำนวน, กดแล้วไป Screen 3) + ปุ่มลบ (ไอคอนถังขยะ, **แสดงเฉพาะโพสต์ของตัวเอง**)
- FAB (Floating Action Button) มุมขวาล่าง ไอคอน "+" กดไปหน้า Create Post (Screen 2)
- Pull-to-refresh ที่ด้านบนของ list
- Infinite scroll: โหลดโพสต์เพิ่มอัตโนมัติเมื่อเลื่อนใกล้ล่างสุด (แบ่งหน้า ไม่โหลดทั้งหมดทีเดียว ตามที่ระบุใน Risks ของ Product spec)

Interactions:
- กด Like → toggle ทันที (optimistic UI: อัปเดตจำนวน/สีก่อน แล้วค่อยยืนยันกับ server เบื้องหลัง)
- กดปุ่มลบ → dialog ยืนยัน "ลบโพสต์นี้?" ก่อนลบจริงเสมอ (ป้องกันกดพลาด)
- Pull-to-refresh → โหลดโพสต์ล่าสุดใหม่ทั้งหมด
- เลื่อนถึงล่างสุด → โหลดหน้าถัดไปอัตโนมัติ พร้อม loading indicator เล็ก ๆ ท้าย list

States:
- Loading (ครั้งแรก) — skeleton card 3-4 ใบ
- Loaded — รายการโพสต์ปกติ
- Empty (ยังไม่มีโพสต์เลยในระบบ) — ข้อความเชิญชวน "ยังไม่มีใครโพสต์เลย เป็นคนแรกสิ!" พร้อมปุ่มไปสร้างโพสต์
- Error (โหลดไม่สำเร็จ) — ข้อความ error + ปุ่มลองใหม่
- Loading more (กำลังโหลดหน้าถัดไป) — spinner เล็กท้าย list

Responsive Behavior: List แบบ single column เต็มความกว้างจอ รูปภาพปรับตามความกว้างจอโดยรักษา aspect ratio

Accessibility: แต่ละ Post Card ต้องมี semantics ที่อ่านลำดับได้เป็นธรรมชาติ (ชื่อผู้โพสต์ → เวลา → เนื้อหา → จำนวน like/comment) ปุ่ม Like ต้องประกาศสถานะปัจจุบัน (เช่น "ถูกใจแล้ว, กดเพื่อเลิกถูกใจ" / "กดเพื่อถูกใจ") ไม่ใช่แค่ไอคอนเฉย ๆ

Design Rules: ใช้สี/spacing ตาม `design-principles.md` ปุ่ม Like ที่ถูกกดใช้สี error/red ตาม convention ทั่วไปของปุ่มหัวใจ (ข้อยกเว้นเดียวที่ไม่ใช้สี primary เพราะเป็น universal convention ที่ผู้ใช้คุ้นเคยอยู่แล้ว) — **ย้ายปุ่ม logout จาก `HomeScreen` (AppBar) ไปไว้ในหน้า View Profile แทน** เพราะตอนนี้ AppBar ของ Feed มีแค่ปุ่มโปรไฟล์ปุ่มเดียวพอ ลด clutter

Handoff: AI Coding — ต้อง refactor `HomeScreen` เดิมทั้งหมด (ปัจจุบันเป็น placeholder + ปุ่ม logout) ให้กลายเป็น Feed จริง และย้ายปุ่ม logout ไปที่ `ViewProfileScreen` แทน (เพิ่ม action ใหม่ในหน้านั้น)

---

## Screen 2: Create Post

Purpose: ให้ผู้ใช้พิมพ์ข้อความและ/หรือแนบรูปเพื่อโพสต์ใหม่

User Flow: จาก Feed กด FAB → พิมพ์ข้อความ/แนบรูป → กด "โพสต์" → กลับไป Feed พร้อมเห็นโพสต์ใหม่อยู่บนสุดทันที

Components:
- AppBar: ปุ่มปิด (กากบาท ไม่ใช่ back arrow เพราะเป็น modal-style flow) + ปุ่ม "โพสต์" (primary action, ขวาสุดของ AppBar)
- Text Area สำหรับพิมพ์ข้อความ (ไม่มีจำกัดความยาวเข้มงวดเหมือน bio แต่ควรมี soft limit เพื่อกัน abuse เช่น 500 ตัวอักษร พร้อมตัวนับเมื่อใกล้เต็ม — ใช้ pattern เดียวกับ bio counter ใน WYN-003)
- ปุ่ม "แนบรูปภาพ" (ไอคอนรูปภาพ) ใต้ text area — กดแล้วเปิด action sheet เลือกกล้อง/คลังภาพ (ใช้ pattern เดียวกับ WYN-003 Edit Profile เป๊ะ ๆ)
- Preview รูปที่เลือก (ถ้ามี) พร้อมปุ่ม "x" มุมขวาบนของรูปเพื่อเอารูปออก

Interactions:
- ปุ่ม "โพสต์" **disable จนกว่าจะมีข้อความหรือรูปอย่างน้อย 1 อย่าง** (ตาม Acceptance Criteria)
- กด "โพสต์" → upload รูป (ถ้ามี) แล้วสร้างโพสต์ → แสดง loading บนปุ่มระหว่างรอ → สำเร็จปิดหน้าจอกลับ Feed
- กดปุ่มปิด (กากบาท) ระหว่างมีข้อความ/รูปค้างอยู่ → ไม่ต้องมี confirm dialog พิเศษ (เก็บให้ minimal ตาม MVP นี้ — ต่างจาก consideration อื่นที่อาจมีในอนาคต)

States:
- Default
- Image picking (native picker กำลังเปิด)
- Posting (กำลัง upload + สร้างโพสต์) — disable ทุก input, ปุ่ม "โพสต์" แสดง spinner
- Error (โพสต์ไม่สำเร็จ) — inline error เหนือปุ่ม พร้อมให้ลองใหม่ ไม่เสียข้อความ/รูปที่เลือกไว้

Responsive Behavior: Text area ขยายตามเนื้อหาจนถึงพื้นที่ที่เหลือของจอ จากนั้น scroll ภายใน

Accessibility: ปุ่ม "แนบรูปภาพ" มี label เต็ม ไม่ใช่แค่ไอคอน ตัวนับตัวอักษรใช้ pattern เดียวกับ WYN-003

Design Rules: ใช้ Text Area/ปุ่มแนบรูปตาม pattern เดียวกับ Edit Profile ใน WYN-003 เพื่อความสม่ำเสมอ

Handoff: AI Coding — ใช้ `image_picker` (มีอยู่แล้วจาก WYN-003) resize/compress รูปก่อน upload เหมือน avatar

---

## Screen 3: Post Detail (Comments)

Purpose: แสดงโพสต์เต็ม ๆ พร้อมคอมเมนต์ทั้งหมด และให้คอมเมนต์ใหม่ได้

User Flow: จาก Feed กดปุ่ม Comment บนโพสต์ใด ๆ → เห็นโพสต์เต็มด้านบน + รายการคอมเมนต์ด้านล่าง → พิมพ์คอมเมนต์ใหม่ที่ช่อง input ด้านล่างสุด → กดส่ง → คอมเมนต์ใหม่ปรากฏทันทีในรายการ

Components:
- AppBar: ปุ่มย้อนกลับมาตรฐาน + title "โพสต์"
- ด้านบน: Post Card เดียวกับใน Feed (reuse widget เดียวกัน ไม่สร้างซ้ำ) — รวมปุ่ม Like ด้วย (กดไลก์จากหน้านี้ได้เหมือนกัน)
- รายการ Comment: แต่ละคอมเมนต์มี avatar เล็ก + ชื่อแสดง/@username + ข้อความ + เวลา
- ช่อง input คอมเมนต์ bottom-anchored พร้อมปุ่มส่ง (ไอคอนลูกศร) ข้าง ๆ

Interactions:
- พิมพ์คอมเมนต์แล้วกดปุ่มส่ง (หรือกด enter/return) → ส่งคอมเมนต์ → เคลียร์ช่อง input → คอมเมนต์ใหม่ต่อท้ายรายการทันที (optimistic UI)
- ปุ่มส่งคอมเมนต์ disable ถ้าช่อง input ว่างเปล่า

States:
- Loading คอมเมนต์ครั้งแรก — skeleton
- Loaded — รายการคอมเมนต์ปกติ (เรียงเก่าไปใหม่ อ่านง่ายเหมือนบทสนทนา)
- Empty (ยังไม่มีคอมเมนต์) — ข้อความ "ยังไม่มีคอมเมนต์ เป็นคนแรกสิ!"
- Sending (กำลังส่งคอมเมนต์) — ปุ่มส่ง disable ชั่วคราว
- Error (ส่งคอมเมนต์ไม่สำเร็จ) — inline error ใกล้ช่อง input

Responsive Behavior: รายการคอมเมนต์ scroll ได้อิสระจากช่อง input ที่ fix อยู่ด้านล่างเสมอ (คล้าย chat interface ทั่วไป)

Accessibility: ช่อง input คอมเมนต์มี label ชัดเจน ("เขียนคอมเมนต์") ปุ่มส่งมี label ไม่ใช่แค่ไอคอนลูกศร

Design Rules: reuse Post Card widget จาก Screen 1 ตรง ๆ ไม่ประดิษฐ์ใหม่

Handoff: AI Coding — โครงสร้าง comment list แบบ chronological (เก่า→ใหม่) ต่างจาก Feed ที่เป็น (ใหม่→เก่า) ต้องระวังตอน query อย่าสลับกัน

---

## สรุป Flow รวม

```
Feed ──(กด FAB)──> Create Post ──(โพสต์สำเร็จ)──> กลับ Feed (เห็นโพสต์ใหม่บนสุด)
Feed ──(กดปุ่ม Comment บนโพสต์)──> Post Detail (Comments) ──(กด back)──> กลับ Feed
```

## Handoff รวม
ส่งต่อ AI Coding (`/code`) เพื่อ implement 3 screens ข้างต้น — ต้องสร้างตาราง `posts`/`likes`/`comments` ใน Supabase พร้อม RLS, Storage bucket ใหม่สำหรับรูปโพสต์, refactor `HomeScreen` เดิมให้เป็น Feed จริง (ย้ายปุ่ม logout ไปหน้าโปรไฟล์) — ต้อง QA & Security ตรวจสอบก่อน deploy เสมอ (ห้ามข้าม QA) โดยเฉพาะ RLS ของ like/comment/post delete ที่ต้องเช็คให้ครบว่าคนอื่นแก้/ลบของเราไม่ได้
