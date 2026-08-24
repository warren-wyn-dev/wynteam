# Design Spec — WYN-052 (WYN Admin Content Moderation)

Status: active
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/backlog/WYN-052-admin-content-moderation.md`
อ้างอิง Design system: `.wyn/docs/design/wyn-049-admin-foundation.md` (shadcn neutral + WYN Cyan) — reuse component ที่มีอยู่แล้วทั้งหมดจาก WYN-051 (`Badge`/`Dialog`/`Textarea`) ไม่มี component ใหม่ในรอบนี้

## Screen 1 — Content Moderation (`app/(admin)/moderation/page.tsx`, แทนที่ placeholder เดิม)

Purpose: ค้นหา Drop เพื่อตรวจสอบ/ดำเนินการ

User Flow: เหมือน WYN-051's Screen 1 เป๊ะ (พิมพ์คำค้น → Enter/กดค้นหา → ผลลัพธ์) — ต่างกันที่ **ผลลัพธ์เป็น grid ของรูปภาพ ไม่ใช่ตาราง** เพราะ Admin ต้องเห็นเนื้อหาจริงก่อนตัดสินใจ (Product's Handoff ระบุไว้ตรงๆ) มิเรอร์ `DropGridTile` ที่ Consumer app ใช้ในหน้า Profile grid อยู่แล้ว (แนวคิดเดียวกัน: thumbnail สี่เหลี่ยม, ไม่ต้องคิด layout ใหม่)

Components:
- `Input`+`Button` ค้นหาเดิมจาก WYN-051 (label เปลี่ยนเป็น "ค้นหาด้วย caption หรือ username ผู้เขียน")
- ผลลัพธ์: `grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-3` การ์ดสี่เหลี่ยมจัตุรัส แต่ละใบ = รูปภาพ Drop (`object-cover`) + overlay มุมล่าง: username ผู้เขียน (ตัวเล็ก, พื้นหลังโปร่งแสงดำ อ่านง่ายบนรูปทุกสี) — **ถ้า Drop ถูกลบไปแล้ว (moderation หรือ self) ให้แสดง `Badge variant="destructive"` มุมบนขวาการ์ด "ลบแล้ว"** ให้ Admin กรองสายตาได้ทันทีว่าอันไหน active/removed อยู่แล้วโดยไม่ต้องคลิกเข้าไปทีละใบ
- คลิกการ์ด → ไปหน้า `app/(admin)/moderation/[id]/page.tsx`

States: เหมือน WYN-051's Screen 1 (Idle/Searching/ว่างเปล่า/มีผลลัพธ์) — ผลว่างเปล่า: "ไม่พบ Drop ที่ตรงกับคำค้น"

Design Rules: ไม่มี pagination รอบนี้ (limit ~30 เหมือน WYN-051) — ไม่ใช้ Rainbow ring/accent ใดๆ ของ Consumer app's DS-009 (หน้านี้เป็นเครื่องมือตรวจสอบ ไม่ใช่ social feed)

---

## Screen 2 — Drop Detail (`app/(admin)/moderation/[id]/page.tsx`, หน้าใหม่)

Purpose: ดูเนื้อหาเต็ม + Reports + ประวัติ + สั่ง Remove/Restore

User Flow:
1. เข้าจาก Screen 1 → เห็นรูปเต็ม + caption + ผู้เขียน + สถานะปัจจุบัน
2. **ถ้า Drop ยัง active**: ปุ่ม "Remove" เท่านั้น (ไม่มี Restore ให้กด เพราะไม่มีอะไรให้กู้คืน)
3. **ถ้า Drop ถูกลบไปแล้ว (ไม่ว่า self-delete หรือ moderation-remove)**: ปุ่ม "Restore" เท่านั้น — **แต่ต้องสื่อสารชัดเจนว่า self-deleted Drop ไม่ใช่หน้าที่ของ Admin ที่จะไปยุ่ง** (ตาม Product's Requirement 2 เจตนาคือแก้เฉพาะเคส moderation-removed) — แสดงข้อความกำกับใต้ปุ่ม Restore บอกที่มาของการลบ ("ลบโดยผู้ดูแลระบบ" / "ลบโดยเจ้าของเอง") ให้ Admin ตัดสินใจเองว่าควรกด Restore ไหม ไม่ disable ปุ่มสำหรับกรณี self-delete (Admin อาจมีเหตุผลทำแทนผู้ใช้ที่ติดต่อมาขอความช่วยเหลือได้เหมือนกัน ไม่ใช่ข้อจำกัดทางเทคนิคที่ต้องบล็อก)

Components:
- ภาพ Drop เต็มขนาด (`max-w-md`, `object-contain`, พื้นหลังเทาอ่อนถ้าไม่เต็มกรอบ) + caption ใต้ภาพ
- Header: username ผู้เขียน + `Badge` สถานะ (`variant="destructive"` "ลบแล้ว" ถ้า `deleted_at is not null`, ไม่แสดง badge ถ้า active — มิเรอร์หลักการ "ไม่ใช้สีแดงตายตัว" เดียวกับ WYN-050/051)
- ปุ่ม action เดียว (Remove **หรือ** Restore ไม่ใช่ทั้งคู่พร้อมกัน — ต่างจาก WYN-051 ที่มีหลายปุ่มพร้อมกันเพราะ user มีหลาย action ระดับต่างกัน แต่ Drop มีแค่ 2 สถานะ ("อยู่"/"ลบแล้ว") ไม่ต้องมีทางเลือกหลายระดับความรุนแรงแบบ Warn/Restrict/Suspend/Ban)
  - Remove: `ActionDialog` (reuse component เดิมจาก WYN-051 ตรงๆ) — reason required, ไม่ต้องมี duration (permanent จนกว่าจะ restore) — `variant="destructive"`
  - Restore: `ActionDialog` เดิมเช่นกัน — reason required (สำหรับ audit trail "ทำไมถึง restore") — `variant="default"`
- Section "รายงานที่มีต่อ Drop นี้": ตารางเดียวกับ WYN-051's Reports table เป๊ะ (reuse `moderation_queue` filter `target_type='drop'`)
- Section "ประวัติการดำเนินการ": ตารางเดียวกับ WYN-051's History table เป๊ะ (คอลัมน์เดียวกันทั้งหมด กรองด้วย `target_content_id` แทน `target_user_id`)

States: Loading/Loaded/Error เหมือน WYN-050/051 ทุกประการ (reuse `app/(admin)/error.tsx` เดิม)

Responsive Behavior: Desktop-first ตาม WYN-049 — grid ผลการค้นหาปรับ 2→4→6 คอลัมน์ตาม breakpoint มาตรฐาน

Accessibility: การ์ดผลการค้นหาแต่ละใบมี `alt` text ของรูป = "Drop โดย {username}" (ไม่ใช่ alt ว่างเปล่า เพราะเนื้อหาภาพมีความหมายสำคัญต่อการตัดสินใจของ Admin ไม่ใช่แค่ decoration)

Design Rules:
- **ไม่มีปุ่ม Remove และ Restore พร้อมกันในหน้าเดียว** (สถานะใดสถานะหนึ่งเท่านั้น ตามที่ระบุใน User Flow)
- สีแดง (`destructive`) ใช้กับปุ่ม Remove และ badge "ลบแล้ว" เท่านั้น — ปุ่ม Restore ใช้สีปกติ (`default`, ไม่ใช่สีเตือน เพราะเป็นการคืนสภาพ ไม่ใช่การกระทำที่มีความเสี่ยง)

Handoff: AI Coding (เมื่อ Founder อนุมัติแนวทางแก้ `restore_drop()` ตาม Product spec's Recommendation แล้ว) — Screen 1/2 ทั้งคู่ reuse `ActionDialog`/`Badge`/table layout จาก WYN-051 ได้เกือบทั้งหมด ส่วนที่ต้องเขียนใหม่จริงๆ มีแค่: grid การ์ดรูปภาพ (Screen 1), รูปเต็ม+ปุ่มเดี่ยว (Screen 2 header) — SQL ต้องทำ `restore_drop()`'s เงื่อนไขใหม่ตาม Product's Requirement 2 **ก่อน** เปิดใช้ `admin_remove_drop()` จริง ไม่ใช่ทำคู่ขนานแล้วค่อยแก้ทีหลัง (ป้องกันหน้าต่างเวลาที่ช่องโหว่เปิดอยู่จริงแม้แค่ชั่วคราว)
