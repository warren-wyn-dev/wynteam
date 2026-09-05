# Checklist — migration ที่แตะ view

มาจากบทเรียน WYN-109 / SCHEMA-004 (2026-09-04): migration ที่ `create or replace view` ล้มบน
production ด้วย `ERROR 42P16` เพราะซ้อมกับ `schema.sql` ในโค้ดแทนที่จะเป็นนิยามจริงบน production
รายละเอียดเต็ม: `.wyn/tasks/bugs/SCHEMA-004-production-view-drift.md`,
`.wyn/learning/LESSONS_LEARNED.md` (รายการ 2026-09-04)

ก่อนเขียน migration ใดก็ตามที่จะ `create or replace view` (หรือ `drop view` / `alter view`) ให้ไล่ตามลำดับนี้เสมอ:

## 1. เลี่ยงได้ไหม — ถามก่อนเป็นข้อแรก

ข้อมูลที่ต้องการต้องมาจาก view จริงหรือไม่ ถ้าโค้ดฝั่ง client มีจุดที่ยิง query แบบ `Future.wait`
ขนานกันอยู่แล้ว (batched lookup pattern — ดู `HomeRepository._fetchViewerState` เป็นตัวอย่าง)
การเสียบ query ที่อ่านจากตารางต้นทางตรง ๆ เข้าไปในชุดนั้นมักถูกกว่าและปลอดภัยกว่าการแก้ view เสมอ
เพราะ:
- ไม่มีความเสี่ยงเรื่อง `create or replace view` เป็น append-only เลย
- ไม่ต้องรู้นิยามที่แน่นอนของ view บน production ก่อน
- ปกติไม่เพิ่ม round-trip (วิ่งขนานกับของเดิม)

ถ้าเลี่ยงได้ ให้เลี่ยง จบที่ข้อนี้ ไม่ต้องอ่านข้อถัดไป

## 2. ถ้าเลี่ยงไม่ได้ — ดึงนิยามจริงจาก production ก่อนเขียนโค้ดสักบรรทัด

ขอ Founder รันคำสั่งอ่านอย่างเดียวนี้ใน Supabase SQL Editor แล้วส่งผลกลับมา (ปลอดภัย 100% ไม่แก้อะไร):

```sql
select ordinal_position, column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = '<ชื่อ view>'
order by ordinal_position;

select pg_get_viewdef('public.<ชื่อ view>'::regclass, true);
```

**ห้ามเขียนนิยาม view จากความจำหรือจาก `schema.sql` ในโค้ดเด็ดขาด** แม้จะดูมั่นใจแค่ไหนก็ตาม —
`schema.sql` อาจไม่ตรงกับ production (ดู SCHEMA-004) และ `pg_get_viewdef` เท่านั้นที่บอกความจริง

## 3. เขียน migration ให้เป็น append-only เท่านั้น

`create or replace view` ของ PostgreSQL ยอมให้ต่อท้ายคอลัมน์ได้อย่างเดียว — ห้ามแทรกกลาง
ห้ามสลับลำดับ ห้ามเปลี่ยนชื่อคอลัมน์เดิม (แม้แค่ตัวเดียว) ถ้าจำเป็นต้องเปลี่ยนชื่อ/ลำดับจริง ๆ
ต้อง `drop view` แล้ว `create view` ใหม่ ซึ่งเป็นการเปลี่ยนโครงสร้างที่ต้องขออนุมัติ Founder ก่อนเสมอ
(`.wyn/company/RULES.md`) และต้องตรวจสอบ dependency ของ view นั้นก่อน (RLS policy, function อื่นที่
query ผ่าน view นี้, grants)

## 4. ซ้อมบนนิยามจริง ไม่ใช่บน `schema.sql`

สร้าง view บน scratch database (`/usr/lib/postgresql/16/bin`, data dir `/tmp/pgd`) ด้วยข้อความจาก
`pg_get_viewdef` ที่ได้จากข้อ 2 (ไม่ใช่จาก `schema.sql`) แล้วรัน migration ทับ ถ้าผ่านตรงนี้ถึงจะ
มั่นใจได้ว่าจะไม่ล้มบน production ด้วยเหตุผลเดียวกับที่ WYN-109 เจอ

## 5. หลัง Founder รัน migration จริงแล้ว

อัปเดต `schema.sql` ให้ตรงกับสิ่งที่รันจริง (ไม่ใช่สิ่งที่ตั้งใจจะรัน) แล้ว diff กับนิยามที่ได้จาก
ข้อ 2 อีกครั้งเพื่อยืนยันว่าตรงกันเป๊ะ — ปิดวงจร ไม่ปล่อยให้ repo หลุดจาก production อีกครั้ง
