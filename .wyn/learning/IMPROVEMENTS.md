# Improvements Log

ข้อเสนอปรับปรุงกระบวนการ/เอกสาร/เครื่องมือที่ระบุจาก retrospective

## รูปแบบ

```
### [YYYY-MM-DD] ข้อเสนอ
- ปัญหาที่พบ:
- ข้อเสนอ:
- สถานะ: เสนอ / นำไปใช้แล้ว / ปฏิเสธ
```

## รายการ

### [2026-08-13] ทำให้ `AuthRepository` inject ได้เพื่อเขียน regression test ครอบคลุม navigation/backend behavior
- ปัญหาที่พบ: `AuthGate` สร้าง `AuthRepository(Supabase.instance.client)` เองภายใน constructor ทำให้เขียน widget test ที่ครอบคลุม auth-state-driven navigation (เช่น pop-back หลัง sign-in, หรือ setUsername race condition) ไม่ได้เลยถ้าไม่มี Supabase project จริงเชื่อมต่อ ระหว่างแก้บั๊ก WYN-002 จึงเขียน regression test ได้แค่ 1 ใน 3 ปัญหา (ดู `.wyn/learning/MISTAKES.md`)
- ข้อเสนอ: เพิ่ม constructor parameter ให้ `AuthGate` รับ `AuthRepository` จากภายนอกได้ (dependency injection) และพิจารณาทำ interface/abstract class ให้ `AuthRepository` เพื่อสร้าง fake implementation สำหรับ test ได้โดยไม่ต้องพึ่ง Supabase จริง
- **อัปเดต [2026-08-13] — ยกระดับความสำคัญเป็นสูง**: ช่องว่างนี้ทำให้เกิด regression จริงแล้ว — การแก้บั๊ก Critical รอบ 1 ของ WYN-002 (navigation หลัง sign-in) เอง introduce บั๊ก Critical ใหม่ (logout ไม่ได้สำหรับผู้ใช้ใหม่) ที่ QA รอบ 2 ถึงจะจับได้ ไม่มี automated test ไหนจับได้เลยเพราะช่องว่างนี้เป๊ะ ๆ ควรทำก่อนเริ่ม feature ถัดไปที่แตะ auth flow (เช่น Profile, Feed) ไม่ใช่แค่ "เสนอ" เฉย ๆ
- สถานะ: เสนอ (priority สูง)

### [2026-08-14] เพิ่มขั้นตอน self-checklist บังคับก่อน Coding ส่งงานทุกครั้งที่มีการอ้างอิง Design Component list
- ปัญหาที่พบ: bug class เดียวกัน ("Design/Product spec ระบุ component ไว้ชัดเจน แต่ Coding ข้ามไปเงียบ ๆ โดยไม่บันทึกเหตุผล") เกิดซ้ำแล้ว 3 ครั้งติดต่อกันในโปรเจกต์นี้ — WYN-005 รอบ 1 (Like Comment หาย), WYN-005 รอบ 2 (Delete Comment หาย), WYN-007 รอบ 1 (Share/Comment tap หายจากการ์ด Home) — แม้จะมีบทเรียนบันทึกไว้ใน MISTAKES.md แล้วสองครั้งก่อนหน้า แต่ยังไม่มีขั้นตอนบังคับใน workflow ที่ป้องกันไม่ให้เกิดซ้ำจริง มีแค่การพึ่งพา QA ให้จับได้ทุกครั้ง
- ข้อเสนอ: ก่อน AI Coding ส่งงานให้ QA ทุกครั้งที่ task นั้นอ้างอิง Design Component list ให้บังคับทำ checklist ทีละบรรทัดเทียบ Component list กับโค้ดจริงที่ implement ไว้ (เหมือนที่ QA ทำอยู่แล้ว) แล้วบันทึกผลไว้ใน Coding Output section ของ task file — ถ้าตัดสินใจไม่ทำจุดไหนในรอบนี้ ต้องระบุเป็น known/deferred item พร้อมเหตุผลเสมอ ไม่ปล่อยให้เป็นการมองข้ามเงียบ ๆ อีก
- สถานะ: เสนอ (priority สูง — เกิดซ้ำ 3 ครั้งแล้ว)

### [2026-08-15] เพิ่มขั้นตอนตรวจ "linear executability" ของ `supabase/schema.sql` แยกจากการตรวจ RLS/RPC semantics
- ปัญหาที่พบ: SCHEMA-001 — ตลอดทั้งโปรเจกต์ QA ทุกรอบตรวจ `schema.sql` ด้วยการอ่าน SQL semantics เท่านั้น (RLS policy ถูกต้องไหม, RPC gate ครบไหม) เพราะไม่เคยมี live Supabase project ให้ทดสอบจริงมาก่อน — ไม่มีขั้นตอนไหนเลยที่ตรวจว่าไฟล์ "รันได้จริงแบบ linear จาก DB ว่างเปล่าตั้งแต่บรรทัดแรก" ผลคือ forward-reference bug (`notifications` อ้างอิง `clubs`/`club_posts` ที่ยังไม่ถูกสร้าง) ซ่อนอยู่ในไฟล์มาตั้งแต่ WYN-015 merge โดยไม่มีใครจับได้เลย จนกระทั่ง Founder รันกับ Supabase project จริงเป็นครั้งแรกทั้งโปรเจกต์
- ข้อเสนอ: เพิ่ม `supabase/check_schema_ordering.py` (สร้างไว้แล้วใน PR ของ SCHEMA-001) เป็นขั้นตอนบังคับที่ AI Coding/QA ต้องรันทุกครั้งที่ PR แตะ `supabase/schema.sql` — สคริปต์ไม่ต้องมี live DB, ตรวจแบบ static text ว่าทุก `create table`/`alter table ... references public.X` มี `public.X` ถูกสร้างไปแล้วก่อนบรรทัดนั้นจริงหรือไม่ ควรพิจารณาเพิ่มเป็น pre-merge check อัตโนมัติ (เช่น GitHub Action) เมื่อ AI Deploy & DevOps ตั้ง CI pipeline ในอนาคต แทนที่จะพึ่งพาให้แต่ละ AI role จำไปรันเองทุกครั้ง
- สถานะ: เสนอ (priority สูง — เพิ่งพบว่าเป็นช่องโหว่ที่บล็อก deploy จริงครั้งแรกทั้งโปรเจกต์)
