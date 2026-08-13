# Design Spec — WYN-003: User Profile

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md`
อ้างอิง Product Spec: `.wyn/tasks/backlog/WYN-003-user-profile.md`

---

## Screen 1: View Profile (ตัวเอง)

Purpose: แสดงตัวตนของผู้ใช้ (รูป, ชื่อแสดง, username, bio) และเป็นทางเข้าไปแก้ไข

User Flow: จาก `HomeScreen` กดไอคอนโปรไฟล์ (มุมขวาบนของ AppBar ข้าง ๆ ปุ่ม logout เดิม) → เห็นหน้า View Profile → กด "แก้ไขโปรไฟล์" → ไป Screen 2

Components:
- Avatar วงกลมขนาดใหญ่ (80x80) กึ่งกลางด้านบน — placeholder เป็น initial ตัวอักษรแรกของ username บนพื้นสี primary ถ้ายังไม่มีรูป (ไม่ใช้ broken-image icon)
- ชื่อแสดง (Display Name) — heading ใต้ avatar ถ้ายังไม่ตั้งให้ fallback แสดง `@username` แทน
- `@username` — ตัวเล็กใต้ชื่อแสดง สีรอง (secondary text color) เสมอ
- Bio — ข้อความย่อหน้าใต้ username ถ้ายังไม่มีให้ซ่อนไปเลย (ไม่ใช้ placeholder "ยังไม่มี bio" เพราะดูรกและไม่จำเป็น)
- ปุ่ม Secondary "แก้ไขโปรไฟล์" ใต้ bio

Interactions: กดปุ่ม "แก้ไขโปรไฟล์" ไป Screen 2 (push) เท่านั้น ไม่มี interaction ซับซ้อนอื่นในหน้านี้

States:
- Loading (กำลังโหลดข้อมูลโปรไฟล์จาก Supabase) — แสดง skeleton (วงกลมเทาแทน avatar, แถบเทาแทนข้อความ) ตาม `design-principles.md`
- Loaded — แสดงข้อมูลจริงตามด้านบน
- Error (โหลดไม่สำเร็จ) — ข้อความ error กลางจอ + ปุ่ม "ลองใหม่"

Responsive Behavior: จัดกึ่งกลางแนวตั้ง เนื้อหาไม่เกิน max-width ที่เหมาะสมบนจอแท็บเล็ต/จอกว้าง (เผื่ออนาคต แม้ V0.1 เป็น mobile-only)

Accessibility: Avatar ต้องมี semantics label "รูปโปรไฟล์ของ [ชื่อแสดงหรือ username]" ปุ่มแก้ไขโปรไฟล์มี label ชัดเจนไม่ใช่แค่ icon

Design Rules: ใช้ typography scale และสีตาม `design-principles.md` เป๊ะ ๆ ไม่ประดิษฐ์สี/ฟอนต์ใหม่

Handoff: AI Coding — ดึงข้อมูลจาก `profiles` table ผ่าน `AuthRepository` ที่มีอยู่แล้ว (ขยาย method เพิ่ม ไม่สร้าง repository ใหม่ซ้ำซ้อน)

---

## Screen 2: Edit Profile

Purpose: ให้ผู้ใช้แก้ไขรูปโปรไฟล์ ชื่อแสดง และ bio ของตัวเอง

User Flow: จาก Screen 1 กด "แก้ไขโปรไฟล์" → แก้ไขฟิลด์ที่ต้องการ → กด "บันทึก" → กลับไป Screen 1 พร้อมข้อมูลใหม่ (หรือกด "ยกเลิก"/ปุ่มย้อนกลับเพื่อไม่บันทึก)

Components:
- Avatar เดิม (หรือรูปที่เพิ่งเลือก) พร้อม icon กล้องเล็ก ๆ มุมขวาล่างทับอยู่บน avatar เพื่อสื่อว่ากดเพื่อเปลี่ยนรูปได้ — กดที่ avatar ทั้งก้อนเพื่อเปิด action sheet เลือก "ถ่ายรูปใหม่" / "เลือกจากคลังภาพ"
- Text Input ชื่อแสดง (พร้อม helper "1-50 ตัวอักษร")
- Text Area bio (multi-line, พร้อมตัวนับตัวอักษรมุมขวาล่าง เช่น "42/160")
- ปุ่ม Primary "บันทึก" (bottom-anchored ตาม design principles)
- ปุ่มย้อนกลับ (AppBar back button มาตรฐาน) แทนปุ่ม "ยกเลิก" แยก เพื่อลดความซับซ้อนของหน้าจอ

Interactions:
- กด avatar → เปิด action sheet ระบบ (bottom sheet) ให้เลือก "ถ่ายรูปใหม่" หรือ "เลือกจากคลังภาพ" → หลังเลือก/ถ่ายเสร็จ preview รูปใหม่ทันทีในหน้าจอ (ยังไม่ upload จนกว่าจะกด "บันทึก")
- พิมพ์ bio เกิน 160 ตัวอักษร → พิมพ์ต่อไม่ได้ (input formatter บังคับ) ตัวนับเปลี่ยนสีเป็น warning เมื่อใกล้เต็ม (เช่น เหลือ < 20 ตัวอักษร)
- กด "บันทึก" → upload รูป (ถ้าเปลี่ยน) แล้วอัปเดต `profiles` row → แสดง loading บนปุ่มระหว่างรอ → สำเร็จกลับไป Screen 1

States:
- Default
- Image picking (กำลังรอผลจาก system picker — ไม่ต้องมี custom loading เพราะเป็น native UI)
- Saving (กำลัง upload รูป + อัปเดต database) — ปุ่ม "บันทึก" แสดง spinner, disable input ทั้งหมดระหว่างนี้
- Error (upload ไม่สำเร็จ/เครือข่ายมีปัญหา) — inline error message เหนือปุ่ม "บันทึก" พร้อมให้กดลองใหม่ได้ ไม่เสียข้อมูลที่กรอกไว้

Responsive Behavior: Text Area ขยายความสูงตามเนื้อหา (ไม่ scroll ในกล่องเล็ก ๆ) จนถึง max-height ที่กำหนด จากนั้นค่อย scroll ภายใน

Accessibility: Action sheet เลือกรูปต้องใช้ native accessibility ของระบบ (ไม่ต้องทำเอง) ตัวนับตัวอักษร bio ต้องประกาศให้ screen reader ทราบเมื่อใกล้เต็ม/เต็มแล้ว (live region เหมือน pattern ที่ใช้กับ username ใน WYN-002)

Design Rules: ใช้ Text Input/Text Area component ตาม pattern เดียวกับ `username_setup_screen` ใน WYN-002 เพื่อความสม่ำเสมอ

Handoff: AI Coding — ใช้ image picker package มาตรฐาน (เช่น `image_picker`), compress/resize รูปก่อน upload ตามที่ระบุใน Risks ของ WYN-003, upload ไปยัง Supabase Storage bucket `avatars` ที่ต้องสร้างพร้อม RLS (ผู้ใช้ upload ได้เฉพาะไฟล์ของตัวเอง ตั้งชื่อไฟล์ตาม user id)

---

## สรุป Flow รวม

```
HomeScreen ──(กดไอคอนโปรไฟล์)──> View Profile ──(กด "แก้ไขโปรไฟล์")──> Edit Profile ──(บันทึกสำเร็จ)──> View Profile (ข้อมูลใหม่)
```

## Handoff รวม
ส่งต่อ AI Coding (`/code`) เพื่อ implement 2 screens ข้างต้น — ต้องขยาย `AuthRepository` (หรือแยก `ProfileRepository` ใหม่ถ้าเหมาะสมกว่า เป็นดุลยพินิจของ AI Coding) เพิ่ม Supabase Storage bucket `avatars` พร้อม RLS, และเพิ่มปุ่มไอคอนโปรไฟล์ใน `HomeScreen` เดิม — ต้อง QA & Security ตรวจสอบก่อน deploy เสมอ (ห้ามข้าม QA)
