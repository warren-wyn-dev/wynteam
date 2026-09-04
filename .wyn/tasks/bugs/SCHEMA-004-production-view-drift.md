# Bug — SCHEMA-004: public.home_feed บน production ไม่ตรงกับ schema.sql

Status: open (รอข้อมูลจาก production)
Severity: Major — ไม่กระทบผู้ใช้ตอนนี้ แต่ทำให้ migration ที่แตะ view ทุกตัวในอนาคตล้ม
พบเมื่อ: 2026-09-04 ตอน Founder รัน `supabase/migrations_wyn109_image_aspect_ratio.sql`

## อาการ

```
ERROR:  42P16: cannot change name of view column "created_at" to "author_is_verified"
HINT:   Use ALTER VIEW ... RENAME COLUMN ... to change name of view column instead.
```

`create or replace view` ของ PostgreSQL ยอมให้**เพิ่มคอลัมน์ต่อท้ายเท่านั้น** ห้ามแทรก/สลับกลางลิสต์
error บอกว่าตำแหน่งที่ production มี `created_at` นิยามใน repo มี `author_is_verified` แปลว่า
**view บน production มีคอลัมน์ไม่ตรงกับ `supabase/schema.sql`**

## ผลกระทบ

- migration WYN-109 ล้มทั้งไฟล์ (rollback หมด ไม่มีอะไรถูกเปลี่ยน — ยืนยันโดยทำซ้ำบน scratch DB แล้ว)
- **migration ใดก็ตามที่ redefine `home_feed` จากข้อความใน repo จะล้มแบบเดียวกัน** จนกว่าจะแก้เรื่องนี้
- ไม่กระทบผู้ใช้: production ทำงานปกติด้วย view ที่มันมีอยู่

## สาเหตุที่รอดมาถึง production

การซ้อม migration ก่อนหน้าโหลด `schema.sql` จาก repo แล้วทดสอบ — คือทดสอบกับ*สิ่งที่เราเขียนเอง*
ไม่ใช่กับสิ่งที่ production เป็นจริง การซ้อมแบบนั้นพิสูจน์ได้แค่ว่าไฟล์ไม่ขัดกับตัวเอง

## ต้องทำอะไรต่อ

1. **ขอข้อมูลจาก production** (อ่านอย่างเดียว):
   ```sql
   select ordinal_position, column_name, data_type
   from information_schema.columns
   where table_schema = 'public' and table_name = 'home_feed'
   order by ordinal_position;

   select pg_get_viewdef('public.home_feed'::regclass, true);
   ```
2. เทียบกับ `schema.sql` หาว่าต่างกันตรงไหนและเพราะอะไร (มีการเปลี่ยน view ที่ไม่เคย apply ขึ้น
   production หรือ apply ขึ้น production โดยไม่เข้า repo)
3. ตัดสินใจว่าจะ **sync production ให้ตรง repo** (ต้อง drop+recreate view — ต้องประเมิน dependency
   และขออนุมัติ Founder เพราะเป็นการเปลี่ยนโครงสร้าง) หรือ **แก้ repo ให้ตรง production**
4. กติกาใหม่ที่ควรมี: **ก่อนรัน migration ที่แตะ view ต้องดึงนิยามจริงจาก production มาเทียบก่อนเสมอ**
   ไม่ซ้อมกับ `schema.sql` อย่างเดียว

## ทางออกเฉพาะหน้า (ทำแล้ว)

แยก WYN-109 ออกเป็น 2 ส่วน — `migrations_wyn109a_column_only.sql` เพิ่มคอลัมน์อย่างเดียว
ไม่แตะ view เลย จึงไม่ขึ้นกับ drift นี้ ทดสอบแล้วบน DB ที่จำลอง drift: ผ่าน รันซ้ำได้ ข้อมูลเดิมไม่ถูกแตะ
