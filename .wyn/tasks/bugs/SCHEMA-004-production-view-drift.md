# Bug — SCHEMA-004: public.home_feed บน production ไม่ตรงกับ schema.sql

Status: open — **ไม่ block งานไหนอยู่แล้ว** (WYN-109 เลิกพึ่ง view ไปแล้ว ดูท้ายไฟล์)
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


## อัปเดต 2026-09-04 — เลิกเป็นตัว block

WYN-109 ถูกออกแบบใหม่ให้ **ไม่แตะ view เลย**: `HomeRepository._fetchAspectRatios()` อ่าน
`image_aspect_ratio` จากตาราง `drops` ตรง ๆ แบบ batch เสียบใน `Future.wait` ที่หน้าฟีดจ่ายอยู่แล้ว
(ไม่เพิ่ม round-trip) แล้วส่งเข้า `HomeFeedItem.fromMap` ทางพารามิเตอร์ — วิธีเดียวกับที่ `imageUrls`
ใช้มาก่อนแล้ว จึงไม่ต้องรอ SCHEMA-004 อีกต่อไป

บั๊กนี้ยัง **open** อยู่ เพราะ drift ยังมีจริงและจะทำให้ migration ตัวไหนก็ตามที่ redefine `home_feed`
ในอนาคตล้มแบบเดิม แต่ตอนนี้ไม่มีงานค้างรอมันแล้ว จึงลดความเร่งด่วนลง

คำสั่งอ่านอย่างเดียวในข้อ 1 ยังใช้ได้ ถ้า Founder ส่งผลมาเมื่อไหร่ก็สืบต่อได้ทันที
(เพิ่มเติม: `select pg_get_viewdef('public.home_feed'::regclass, true);` ให้นิยามเต็มของ view
ในเซลล์เดียว ซึ่งเป็นสิ่งที่ต้องใช้จริงถ้าจะ sync repo ↔ production)

**บทเรียนที่ควรถือเป็นกติกา**: ถ้าเลี่ยงการแก้ view ได้ ให้เลี่ยง — การอ่านเพิ่มหนึ่ง query แบบ batch
ที่ขนานกับของเดิมนั้นถูกกว่าและปลอดภัยกว่าการ redefine view บน production มาก

## อัปเดต 2026-09-05 — checklist ป้องกันซ้ำ + สถานะสุดท้าย

เพิ่ม `.wyn/docs/engineering/checklist-db-migration-touching-a-view.md` — ขั้นตอนบังคับ 5 ข้อ
ก่อนเขียน migration ที่แตะ view ใด ๆ ในอนาคต (เลี่ยงได้ไหม → ดึงนิยามจริงจาก `pg_get_viewdef` →
เขียนแบบ append-only → ซ้อมบนนิยามจริง → sync `schema.sql` กลับหลัง Founder รันจริง)
และเพิ่มขั้น "Production Verification" ใน `.wyn/company/WORKFLOW.md` แยกชัดว่า AI ยืนยันอะไรได้เอง
กับอะไรต้องรอ Founder — ทั้งสองมาจากบทเรียนของบั๊กนี้โดยตรง

**สถานะสุดท้าย: open แต่ไม่เร่งด่วน (deprioritized)** ตัวบั๊กจริง (view บน production มีคอลัมน์
ไม่ตรงกับ `schema.sql`) **ยังไม่ถูกแก้** เพราะการแก้จริงต้องมี 2 อย่างที่ AI ทำเองไม่ได้:

1. นิยามจริงของ view จาก `pg_get_viewdef` (คำสั่งอ่านอย่างเดียวในข้อ 1 ของไฟล์นี้ — Founder ยังไม่ได้
   ส่งผลมา และตอนนี้ไม่มีงานไหนรอผลนี้อยู่แล้ว)
2. การตัดสินใจว่าจะ sync production ให้ตรง repo (drop+recreate view) หรือแก้ repo ให้ตรง production
   — เป็นการเปลี่ยนโครงสร้างที่ต้องขออนุมัติ Founder ตาม `.wyn/company/RULES.md` เสมอ

AI จะไม่เดา/สร้างนิยาม view เองโดยเด็ดขาด (คือสาเหตุของบั๊กนี้ตั้งแต่แรก) ถ้า Founder อยากปิดบั๊กนี้
ให้เบ็ดเสร็จ ขั้นตอนคือส่งผลคำสั่งอ่านในข้อ 1 มา — ไม่เช่นนั้นปล่อยเป็น known issue ที่มี checklist
คุมไว้แล้วก็ปลอดภัยพอสำหรับตอนนี้
