# Design Spec — WYN-049 (WYN Admin Foundation)

Status: active
Owner: AI Design
อ้างอิง Product spec: `.wyn/tasks/backlog/WYN-049-admin-foundation.md`
อ้างอิง stack ที่อนุมัติแล้ว: `.wyn/company/DECISIONS.md` (2026-08-24) — Next.js 14+ App Router/TypeScript/Tailwind/shadcn/ui บน Vercel

## หมายเหตุเรื่อง Design System (สำคัญ — อ่านก่อน)

WYN Design System เดิมทั้งหมด (`DS-001` ถึง `DS-009`: WYN Cyan primary, Rainbow accent ring, ZOKY Orange, spacing scale ฯลฯ) ถูกออกแบบไว้สำหรับ **Consumer App บน Flutter** โดยเฉพาะ (Gen Z, ผู้ใช้ทั่วไป, มือถือ) — Master Spec section 36 เองระบุตรงๆ ว่า "WYN App ≠ WYN Admin — Admin ต้องเป็นระบบแยกโดยสิ้นเชิง" ทั้ง target user (staff ภายใน ไม่ใช่ผู้ใช้ทั่วไป), platform (web/desktop-first ไม่ใช่มือถือ), และเป้าหมาย UX (ความหนาแน่นของข้อมูล/ความเร็วในการทำงาน ไม่ใช่ความสนุก/อารมณ์แบบ social app) ต่างกันโดยพื้นฐาน — การยกทั้งระบบ (Rainbow ring/DS-009's 2-point rule ฯลฯ) มาใช้ตรงๆ จะผิดบริบทตั้งแต่ต้น

**สิ่งที่ borrow มาจริง (ไม่ใช่คิดใหม่ทั้งหมด)**: ใช้สี **WYN Cyan** (`#00C8FF`, `app/lib/core/design/wyn_colors.dart`'s `cyan500`) เป็น accent/primary สำหรับ active state เท่านั้น เพื่อรักษาความต่อเนื่องของแบรนด์ขั้นต่ำระหว่าง Consumer app กับ Admin (ผู้ใช้ที่เห็นทั้งคู่ควรรู้สึกว่าเป็นผลิตภัณฑ์เดียวกัน) — นอกนั้นใช้ **shadcn/ui's default neutral theme** (Slate/Zinc grayscale) เป็นฐาน เพราะเป็นค่าเริ่มต้นมาตรฐานที่ผ่านการทดสอบ accessibility/contrast มาแล้วของ ecosystem นี้ ไม่ต้องออกแบบ color scale ใหม่ทั้งชุดสำหรับเครื่องมือภายใน

## Screen 1 — Sign-in

Purpose: จุดเข้าเดียวของ WYN Admin — ยืนยันตัวตนด้วยบัญชีจริง (ไม่ใช่ Anonymous) แล้วเช็คสิทธิ์ก่อนปล่อยเข้า

User Flow:
1. เปิด root URL (`/`) โดยไม่มี session → redirect ไป `/login` เสมอ
2. กรอก email + password → เรียก Supabase Auth `signInWithPassword`
3. **สำเร็จ**: เช็ค `profiles.platform_role` ของ user ที่ login (query ฝั่ง server ผ่าน Server Component/Route Handler ไม่ใช่ client-side fetch)
   - `admin`/`moderator` → redirect เข้า `/` (Dashboard placeholder)
   - `user` (หรือ role อื่นที่ไม่ใช่ 2 ค่านี้) → **sign-out ทันที** (เรียก `supabase.auth.signOut()`) แล้วแสดงข้อความ "บัญชีนี้ไม่มีสิทธิ์เข้าใช้งาน WYN Admin" บนหน้า login เดิม (ไม่ redirect ไปหน้าอื่น ป้องกันไม่ให้ user เข้าใจผิดว่ามีการยืนยันตัวตนบางส่วนสำเร็จแล้ว)
4. **ไม่สำเร็จ** (email/password ผิด): แสดงข้อความ error ทั่วไป "อีเมลหรือรหัสผ่านไม่ถูกต้อง" — **ไม่ระบุว่าฝั่งไหนผิด** (ป้องกัน account enumeration — เป็นหลักการเดียวกับ security best practice ทั่วไป ไม่ใช่ requirement ใหม่จาก Master Spec แต่เป็น minimum security bar ที่ AI Design ควรใส่เองโดยไม่ต้องรอ Product ระบุ)

Components:
- Card กึ่งกลางจอ (max-width ~400px) บนพื้นหลัง neutral เรียบ — ไม่มี background image/illustration (ต่างจาก Consumer app's onboarding ที่เน้นภาพ เพราะ target user คนละกลุ่ม)
- Logo/wordmark "WYN Admin" ข้อความล้วน (ไม่มีโลโก้กราฟิกใหม่ในรอบนี้ — รอ Founder ยืนยัน asset จริงถ้าต้องการภายหลัง)
- `Input` (email, type="email", required), `Input` (password, type="password", required) — shadcn/ui `Input` ตรงๆ
- `Button` submit เต็มความกว้าง Card, สี WYN Cyan (`bg-[#00C8FF]` หรือกำหนดเป็น Tailwind CSS variable `--primary` ใน theme config ให้ shadcn component ทุกตัวอ้างอิงจุดเดียว ไม่ hardcode hex กระจายทั่วโค้ด)
- Error message area ใต้ฟอร์ม (แสดงเมื่อ login ผิดหรือ role ไม่ผ่าน)

Interactions:
- Submit ระหว่างรอ response: ปุ่มแสดง loading spinner + disabled (ป้องกัน double-submit)
- Enter key ในช่อง password submit ฟอร์มได้ (มาตรฐาน HTML form)

States:
- Idle (ฟอร์มว่าง)
- Submitting (ปุ่ม disabled + spinner)
- Error — wrong credentials (ข้อความทั่วไป)
- Error — role rejected (ข้อความเฉพาะ "ไม่มีสิทธิ์เข้าใช้งาน")

Responsive Behavior: Desktop/tablet-first (ตรงข้ามกับ Consumer app ที่ Mobile-first) — Card กึ่งกลางจอทำงานได้ทุกขนาดจอโดยธรรมชาติ (responsive ผ่าน Tailwind `max-w-*`/`mx-auto` มาตรฐาน ไม่ต้องออกแบบ breakpoint พิเศษเพิ่มในรอบนี้ เพราะมีแค่ 1 component)

Accessibility: `<label>` ผูกกับทุก `<input>` ด้วย `htmlFor`, ปุ่ม submit มี `aria-busy` ระหว่าง submitting, error message ใช้ `role="alert"` ให้ screen reader ประกาศทันทีที่ปรากฏ

Design Rules:
- ห้ามใส่ทางเลือก "Sign in with Google/social"/"Anonymous" ใดๆ — Admin ต้องเป็นบัญชีจริงที่ระบุตัวตนได้เท่านั้น ตาม Product spec ล็อกไว้
- ห้ามแสดง "สมัครสมาชิก" — ไม่มี self-service signup สำหรับ Admin เด็ดขาด (บัญชี Admin/Moderator ถูกสร้าง/กำหนด role ผ่าน Supabase โดย Founder/Admin เท่านั้น ไม่มี UI สมัครเองในระบบนี้)

Handoff: AI Coding — sign-in flow ต้อง verify role ฝั่ง server เท่านั้น (Route Handler หรือ Server Action) ห้ามเช็ค `platform_role` แล้วตัดสินใจ redirect ฝั่ง client-side JavaScript ล้วนๆ (bypass ได้ง่ายผ่าน devtools) — client แค่รับผลลัพธ์สุดท้ายจาก server

---

## Screen 2 — Layout Shell (Dashboard placeholder + 5 หน้า placeholder อื่น)

Purpose: โครงหลักของ WYN Admin หลัง sign-in สำเร็จ — sidebar navigation ที่มีช่องให้ WYN-050 ถึง WYN-055 เติมเนื้อหาจริงทีละหน้า

User Flow:
1. Sign-in สำเร็จ → เข้าหน้า `/` (Dashboard) พร้อม Layout shell ที่มีอยู่ทุกหน้า
2. คลิกเมนูใน sidebar → เปลี่ยนหน้าใน content area (Dashboard/User Management/Content Moderation/Report Center/Audit Log/Announcements) — ทุกหน้ายกเว้น Dashboard เป็น placeholder ในรอบนี้
3. คลิกปุ่ม sign-out ที่ header → เรียก `signOut()` → redirect กลับ `/login`

Components:
- **Sidebar** (ซ้าย, fixed width ~240px, ไม่ collapse ในรอบนี้ — ตัดสินใจลดสโคป เพราะยังไม่มีเนื้อหาให้ collapse จริงจนกว่า WYN-050+ จะเติม): 6 รายการเมนู (ไอคอน + label) ตรงกับ roadmap Phase 7 เป๊ะ — Dashboard (WYN-050) / User Management (WYN-051) / Content Moderation (WYN-052) / Report Center (WYN-053) / Audit Log (WYN-054) / Announcements (WYN-055) — เมนูที่ active ใช้พื้นหลัง WYN Cyan อ่อน (`cyan-50` เทียบเท่า) + ตัวหนังสือสี `cyan-700` (มิเรอร์คู่สี light/dark ของ `WynColors.cyan50`/`cyan700` แนวคิดเดียวกัน แปลงเป็น Tailwind scale)
- **Header** (บน, เต็มความกว้างของ content area): ชื่อหน้าปัจจุบัน (ซ้าย) + ชื่อผู้ใช้ปัจจุบัน/`platform_role` badge (`Admin`/`Moderator`) + ปุ่ม sign-out (ขวา)
- **Content area**: Dashboard แสดงข้อความ "WYN Admin Dashboard พร้อมใช้งาน — เมตริกจริงจะเพิ่มใน WYN-050" (placeholder ที่สื่อสารชัดว่าไม่ใช่ error/ยังสร้างไม่เสร็จ) — อีก 5 หน้าใช้ placeholder รูปแบบเดียวกัน เปลี่ยนแค่ชื่อ feature + เลข task ("จะเพิ่มใน WYN-0XX")

Interactions:
- Sidebar เป็น client-side navigation (Next.js `<Link>`) — ไม่ full page reload ระหว่างเปลี่ยนหน้า
- Header's role badge ไม่ clickable (แสดงข้อมูลอย่างเดียว)

States:
- Loading (ระหว่างรอ session/role check ตอนโหลดหน้าแรกหลัง sign-in — สั้นมาก แต่ต้องมี skeleton/spinner ไม่ใช่จอว่างกระพริบ)
- Loaded — แสดง layout ปกติ
- Session expired ระหว่างใช้งาน (เช่น token หมดอายุ) → redirect กลับ `/login` อัตโนมัติ ไม่ค้างแสดงหน้าที่ query ข้อมูลไม่ได้

Responsive Behavior: Desktop-first ตามที่ระบุใน Product spec ("ADMIN — แยก Application" ของ Master Spec ไม่ได้ระบุ mobile requirement ใดๆ สำหรับ Admin) — ไม่ออกแบบ mobile-collapse sidebar ในรอบนี้ (ต่างจาก Consumer app ที่ mobile-first เป็นข้อบังคับ) เสนอเป็น follow-up ถ้า Admin ต้องใช้งานจากมือถือจริงในอนาคต

Accessibility: Sidebar nav ใช้ `<nav>` + `aria-current="page"` บนเมนูที่ active, sign-out button มี accessible label ชัดเจน ("ออกจากระบบ" ไม่ใช่แค่ไอคอน)

Design Rules:
- **ไม่มี Rainbow ring/2-point accent rule ใดๆ ในหน้านี้เลย** (DS-009 ใช้กับ Trending content บน Consumer app เท่านั้น ไม่เกี่ยวกับ Admin)
- Placeholder ทั้ง 5 หน้าต้องใช้ copy เดียวกันทุกจุด (แค่เปลี่ยนชื่อ feature/เลข task) — ไม่ต้องออกแบบ empty-state graphic ใหม่ต่อหน้า (ประหยัดเวลา เพราะเนื้อหาจริงจะมาแทนที่ทั้งหมดใน task ถัดไปอยู่แล้ว)

Handoff: AI Coding — Layout shell เป็น Next.js layout component (`app/(admin)/layout.tsx` หรือเทียบเท่าตาม App Router convention) ที่ wrap ทุกหน้าหลัง auth — role check ต้องเกิดที่ layout level (server-side) ไม่ใช่ทำซ้ำในทุกหน้าลูก
