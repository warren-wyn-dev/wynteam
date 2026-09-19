# Design + Coding Task — WYN-174

Status: approved (Founder ตัดสินใจแล้ว — ส่งต่อ Coding ทันที)
Owner: AI Design → Founder → AI Coding
Screen: หน้า "แก้ไขโปรไฟล์" (`web/components/profile-route.tsx`, component `EditProfile`,
เปิดจากปุ่ม "แก้ไขโปรไฟล์" ในหน้าโปรไฟล์ตัวเอง)

## Bug Context (พบระหว่างคุยกับ Founder, 2026-09-19)

Founder รายงานว่าวงกลม "โน้ตของคุณ" ในหน้าแชทเป็นโลโก้ WYNOS Club สีกรมท่า ไม่ใช่สีขาวอย่างที่ต้องการ —
ตรวจสอบพบว่าไม่ใช่บั๊กโค้ด (fallback avatar ที่ไม่มีรูปจะเป็นวงกลมพื้นขาว/ครีม + ตัวอักษรอยู่แล้ว
ตาม `web/components/phase3-ui.tsx`) แต่เป็นเพราะบัญชี `@wynos_online` **มี `avatar_url` ตั้งไว้จริงในระบบ**
เป็นรูปโลโก้ WYNOS Club (ยืนยันจากสกรีนช็อตหน้า "แก้ไขโปรไฟล์" ที่ Founder ส่งมา เห็นโลโก้เดียวกันเป๊ะ)

ปัญหาจริง: หน้า "แก้ไขโปรไฟล์" (`EditProfile` component) มีแค่ปุ่ม **อัปโหลดรูปใหม่** (ไอคอนกล้อง + คำว่า
"รูปโปรไฟล์") แต่ **ไม่มีปุ่ม "ลบรูปโปรไฟล์"** ให้กลับไปเป็นค่าว่าง (fallback ตัวอักษร) เลย — ผู้ใช้ที่อยากล้าง
รูปโปรไฟล์ทิ้งไม่มีทางทำได้นอกจากอัปโหลดรูปอื่นทับ

## Fix ที่ Founder อนุมัติแล้ว

เพิ่มปุ่ม **"ลบรูปโปรไฟล์"** ในหน้าแก้ไขโปรไฟล์ ข้างๆ ปุ่มอัปโหลดรูปเดิม:

- แสดงเฉพาะตอนที่มีรูปโปรไฟล์อยู่แล้ว (`avatar` ไม่ใช่ null/ว่าง) — ถ้าไม่มีรูปอยู่แล้วไม่ต้องโชว์ปุ่มนี้
- กดแล้วเซ็ต `avatar_url` ในตาราง `profiles` เป็น `null` ทันที (ไม่ต้อง confirm dialog — เป็น action
  เบาๆ ย้อนกลับได้ง่าย อัปโหลดรูปใหม่ได้ตลอด เหมือน pattern การลบโน้ตที่ไม่มี confirm เช่นกัน)
- หลังลบสำเร็จ avatar กลับไปเป็น fallback วงกลมพื้นขาว/ครีม + ตัวอักษรตัวแรกของ username ทันที
  (ใช้ path เดียวกับตอนไม่มี `avatarUrl` อยู่แล้ว ไม่ต้องสร้าง state ใหม่)
- ไม่ลบไฟล์จริงใน storage bucket `avatars` (เก็บไว้เผื่อ rollback/audit — แค่ตัด reference ในตาราง
  `profiles` ออก ความเสี่ยงต่ำ ย้อนกลับได้)

## Files Changed

- `web/lib/phase3-data.ts` — เพิ่มฟังก์ชัน `removeProfileImage(client, userId)` (คู่กับ `uploadProfileImage`
  ที่มีอยู่แล้ว) update `avatar_url: null`
- `web/components/profile-route.tsx` — เพิ่มปุ่ม "ลบรูปโปรไฟล์" ใน `EditProfile`, เรียก
  `removeProfileImage` แล้ว `setAvatar(null)`
- `web/app/profile-golden-final.css` — style ปุ่มใหม่ (ข้อความสีเทา/danger tone เบาๆ ตาม design system
  ที่มีอยู่แล้ว เช่น `.profile-more-sheet > button.danger` ใช้ `var(--wyn-accent)`)

## Regression Risk

ต่ำ — ฟีเจอร์ใหม่ที่แยกจาก flow เดิมชัดเจน ไม่แตะ `uploadProfileImage`/`updateProfileBasics`/
`updateUsername` เลย

## Handoff

พร้อมส่ง AI Coding ทันที → AI QA & Security → Deploy
