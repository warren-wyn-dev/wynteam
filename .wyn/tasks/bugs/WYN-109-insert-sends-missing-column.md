# Bug Report — WYN-109 (B-109-1)

Status: bugs
Owner: AI Debug Engineer
Severity: **Critical**
พบโดย: AI QA & Security, 2026-09-04 (branch `claude/home-button-ux-ui-design-cbjkzm`, ยังไม่ merge/deploy)

## Bug

`DropRepository._insertDrop` ใส่ key `'image_aspect_ratio'` ลงใน payload ของ `insert()` **เสมอ** แม้ค่าจะเป็น `null`
production ตอนนี้ยังไม่มีคอลัมน์นี้ (Founder ยังไม่ได้รัน `supabase/migrations_wyn109_image_aspect_ratio.sql`)
PostgREST สร้างรายชื่อคอลัมน์ของ `INSERT` จาก key ของ JSON โดยไม่สนว่าค่าเป็น null → คำสั่งจะถูกปฏิเสธด้วย
`PGRST204 Could not find the 'image_aspect_ratio' column of 'drops' in the schema cache`

`_insertDrop` เป็นทางผ่านของ **ทุกเส้นทางการสร้างโพสต์** (`drop_repository.dart` บรรทัด 831 / 859 / 885):
โพสต์รูป · โพสต์ข้อความล้วน · โพลล์ · เผยแพร่ Draft จากรูปที่อัปโหลดไว้แล้ว
ถ้า deploy โค้ดนี้ก่อนรัน SQL → **ผู้ใช้โพสต์อะไรไม่ได้เลยทั้งระบบ**

## Files

- `app/lib/features/drop/data/drop_repository.dart:945`

```dart
.insert({
  …
  'image_aspect_ratio': aspectRatio?.wireValue,   // ใส่ key นี้เสมอ แม้ค่า null
})
```

## Reproduction

1. ยกฐานข้อมูล PostgreSQL 16 แล้วโหลด `git show 0e23d8a:supabase/schema.sql` (สภาพ production ปัจจุบัน)
2. รัน `insert into public.drops (author_id, caption, image_aspect_ratio) values (…, '4:5');`
3. ได้ `ERROR: column "image_aspect_ratio" of relation "drops" does not exist`

ยืนยันแล้วบน PostgreSQL 16.13 จริง (ดู `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa.md` §6.3)

ในแอปจริง: deploy branch นี้โดยยังไม่รัน SQL → เปิดแอป → กด "โพสต์" อะไรก็ได้ → ล้มเหลวทุกครั้ง

## Expected

สร้างโพสต์ได้ตามปกติ ไม่ว่า production จะมีคอลัมน์ใหม่แล้วหรือยัง

## Actual

insert ถูกปฏิเสธทั้งหมด → โพสต์ไม่ได้เลย

## Root Cause (สมมติฐานสำหรับ Debug Engineer)

โค้ดฝั่งอ่านออกแบบให้ทน `null` ไว้อย่างดี (`DropAspectRatio.fromWire(null)` → 4:5) แต่ฝั่งเขียนไม่ได้ทนแบบเดียวกัน
— สมมติว่า migration จะถูก apply ก่อนเสมอ ซึ่งเป็นเงื่อนไขที่ควบคุมไม่ได้จริงในขั้นตอน deploy

## Fix ที่เสนอ (เลือกหรือทำทั้งสอง)

1. **ทำโค้ดให้ทน** (แนะนำ): ใส่ key นี้เฉพาะเมื่อ `aspectRatio != null`
   ทำให้เส้นทางโพสต์ข้อความ/โพลล์/Draft ปลอดภัยทันทีโดยไม่ต้องพึ่ง migration เลย
   (เส้นทางโพสต์รูปยังต้องมีคอลัมน์จริงจึงจะบันทึกค่าได้ ซึ่งถูกต้องตามการออกแบบ)
2. **บังคับลำดับ deploy**: เขียนลง release note และ deploy checklist ให้ชัดว่า
   ต้องรัน SQL + verify ก่อน แล้วจึง deploy แอปเท่านั้น — ห้ามสลับลำดับ

## Regression Risk

ต่ำ — แก้จุดเดียวใน map ที่ประกอบ payload · ไม่แตะ RLS/schema/พฤติกรรมอื่น

## Tests ที่ต้องเพิ่ม

- unit test ยืนยันว่า payload ของ `_insertDrop` **ไม่มี** key `image_aspect_ratio` เมื่อ `aspectRatio == null`
- unit test ยืนยันว่ามี key และค่าถูกต้องเมื่อส่งสัดส่วนมาจริง

## Handoff to QA

หลังแก้ ให้ QA ตรวจซ้ำ: เส้นทางสร้างโพสต์ทั้ง 4 แบบ (รูป / ข้อความ / โพลล์ / Draft) ทั้งกรณีมีคอลัมน์และไม่มีคอลัมน์

---

**ปิดแล้ว 2026-09-04** — แก้ใน commit `ea6f33f` และ QA รอบ 2 ยืนยันแล้วด้วย QA-R2-12/13/14 (อ่าน payload ระดับ HTTP จริง 3 เส้นทาง)
เทสต์ที่แถมมากับการแก้ครั้งแรกตรวจด้วยการอ่านข้อความในซอร์ส ซึ่งจับได้แค่การ revert แบบตรงตัว
รอบ 2 จึงเพิ่มเทสต์ที่วัดสิ่งที่แอปวาด/ส่งออกจริงมาคุมทับอีกชั้น
รายงาน: `.wyn/docs/qa/wyn-106-107-108-109-home-cards-qa-round2.md`
