# Design + Coding Task — WYN-174

Status: deployed to production (PR #555, merge commit 5b3f8fff) — รอ Founder ยืนยัน production จริงบน
device ก่อนปิดงาน
Owner: AI Design → Founder → AI Coding → AI QA & Security
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

## QA Verification (AI QA & Security, 2026-09-19)

**Logic**:
- ปุ่ม "ลบรูปโปรไฟล์" render เฉพาะเมื่อ `{avatar ? ... : null}` — ตรวจ diff ยืนยันตรงตาม spec ✅
- กด → `removeProfileImage(client, userId)` → `setAvatar(null)` → ปุ่มหายไปทันที (avatar falsy) →
  `<Avatar src={null} .../>` fallback กลับเป็นตัวอักษรตาม username เหมือนที่ออกแบบไว้ ✅

**Security/RLS**: ตรวจ `supabase/schema.sql` บรรทัด 29-33 — policy `"Users can update their own profile"`
บังคับ `using (auth.uid() = id)` ที่ระดับ Postgres RLS ครอบคลุม `removeProfileImage` เหมือนกับ
`uploadProfileImage`/`updateProfileBasics` เดิมทุกประการ — ต่อให้ `userId` param ถูกแก้ไขฝั่ง client ก็ยัง
ถูก RLS บล็อกไม่ให้แก้ไขแถวคนอื่นได้ ไม่มีช่องโหว่ ✅

**Regression**: จุดเรียกใช้ `<EditProfile>` มีจุดเดียว (`profile-route.tsx:247`) ไม่มี prop เปลี่ยน —
flow อัปโหลดรูปใหม่/บันทึกชื่อ/username/bio ไม่ถูกแตะเลย (diff จำกัดอยู่แค่ฟังก์ชันใหม่ + ปุ่มใหม่) ✅

**Error handling**: `try/catch/finally` เหมือน pattern `image()` เดิมทุกประการ — error แสดงผ่าน
`route-error`, `saving` reset เป็น `false` ใน `finally` เสมอ ปุ่มไม่ค้าง disabled ✅

**Build**: `npm run check` (lint + typecheck + build) อิสระ: 0 error, 3 warning เดิมที่ไม่เกี่ยวข้อง ✅

**พบ 2 จุด LOW severity (ไม่ block release)**:
1. `var(--wyn-accent)` (#e0203d) ที่ใช้เป็นสีปุ่ม เมื่อคำนวณ WCAG contrast บนพื้นหลังโหมดมืด (`--wyn-bg:
   #000000`) ได้ **4.44:1** — ต่ำกว่าเกณฑ์ AA (4.5:1) เล็กน้อย (โหมดสว่างผ่านที่ 4.73:1) — แต่เป็นสีที่
   comment ใน `design-system.css:42` ระบุชัดว่า "stays fixed across themes" โดยตั้งใจ และใช้ร่วมกับปุ่ม
   danger อื่นที่มีอยู่แล้วในโปรดักชัน (เช่น `.profile-more-sheet > button.danger`) — ไม่ใช่บั๊กที่ WYN-174
   สร้างขึ้นใหม่ เป็นลักษณะของ token เดิมที่ใช้ทั่วระบบ แนะนำให้ Design ทบทวน token นี้แยกเป็นงานของตัวเอง
   ในอนาคต ไม่ใช่ scope ของ WYN-174
2. ปุ่มใหม่ไม่มี `min-height` กำหนดชัดเจน (touch target อาจเล็กกว่าเกณฑ์ DS-008 44px) — แต่ตรงตาม pattern
   เดียวกับ label "รูปโปรไฟล์" ข้างๆ ที่ไม่มี min-height เช่นกัน (ตามที่ spec สั่งให้ style คู่กัน) ไม่ใช่
   regression ใหม่

**Final Status: PASS**
