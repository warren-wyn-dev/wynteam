# Bug Report — WYN-121

Status: **Fixed by AI Debug Engineer (2026-09-06) — รอ push/PR/CI แล้วส่งต่อ Deploy**
Owner: AI Debug Engineer
Reported by: Founder (สด, สกรีนช็อต): กด "ลบ" โพสต์ของ Wynos.online แล้วเจอ SnackBar "ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง"

## Bug

Founder ทดสอบลบโพสต์ตัวเอง (บัญชี Wynos.online) เพื่อยืนยัน WYN-120 แต่กลับเจอ error "ลบโพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง" ทันทีหลังกดยืนยันลบ

## Reproduction / การยืนยัน root cause (ไม่ใช่การเดา)

สร้าง read-only diagnostic GitHub Actions workflow (`wyn120-delete-drop-failure-diagnostic.yml`, มิเรอร์ pattern `chat-*-check.yml` ที่มีอยู่แล้ว) query production ตรงๆ:

1. หา Drop ล่าสุดของบัญชี `wynos_online`
2. พบ Drop id `9ea3fc2c-df24-442f-b6e7-4b870af88e17`: **`deleted_at = 2026-09-06 08:20:59.043376+00`** (UTC) — แปลงเป็นเวลาไทย (+7) = **15:20:59.04** ซึ่งตรงกับเวลาบนสกรีนช็อตของ Founder เป๊ะ (นาฬิกาแสดง **15:21**)
3. ยืนยัน `soft_delete_drop()` definition บน production ตรงกับ `schema.sql` เป๊ะ ไม่มี drift

**สรุปหลักฐาน**: การลบ **สำเร็จจริงที่ฝั่งเซิร์ฟเวอร์** (`deleted_at` ถูกตั้งค่าในวินาทีเดียวกับที่ Founder กด "ลบ") แต่แอปกลับรายงานว่า "ลบไม่สำเร็จ" ให้ผู้ใช้เห็น — เป็น **false-negative** ไม่ใช่การลบล้มเหลวจริง

## Root Cause

`DropDetailScreen._deleteDrop()`:

```dart
try {
  await widget.dropRepository.deleteDrop(_drop.id);
  if (!mounted) return;
  WynFeedback.deleted();
  Navigator.of(context).pop();
} catch (_) {
  // แสดง SnackBar ล้มเหลวเสมอ ไม่ว่า exception จะมาจากอะไร
}
```

`deleteDrop()` เรียก RPC `soft_delete_drop()` ผ่าน Supabase client — ถ้าการเชื่อมต่อขาดหาย **หลังจาก** เซิร์ฟเวอร์ commit การเขียนไปแล้วแต่ **ก่อนที่** response จะกลับมาถึง client (เครือข่ายไม่เสถียร — สกรีนช็อตแสดงสัญญาณ WiFi อ่อน) client-side จะเห็นแค่ exception (timeout/connection error) โดยไม่รู้เลยว่าจริงๆ แล้วคำสั่งสำเร็จไปแล้ว `catch (_)` ที่มีอยู่เดิมจับทุก exception แบบเหมารวมแล้วบอกผู้ใช้ว่า "ลบไม่สำเร็จ" เสมอ โดยไม่เคยตรวจสอบสถานะจริงบนเซิร์ฟเวอร์ก่อน

นี่เป็นปัญหาคลาสสิกของระบบ distributed (การันตี "อย่างน้อยหนึ่งครั้ง" ของการเขียนข้อมูล เทียบกับความแน่นอนของการรับ response) ไม่ใช่บั๊ก logic ที่ผิดพลาดตรงๆ — แต่ client สามารถและควรจะตรวจสอบสถานะจริงก่อนฟันธงว่าล้มเหลว

## Fix

เพิ่ม verification step ใน `catch` block ของ `_deleteDrop()`: เมื่อ `deleteDrop()` throw ให้เรียก `fetchById()` (ที่เพิ่ง filter `deleted_at` ถูกต้องแล้วจาก WYN-120) เพื่อเช็คสถานะจริงของ Drop ก่อนตัดสินใจแสดง error:

- ถ้า `fetchById()` คืน `null` (Drop หายไปแล้วจริง = การลบสำเร็จ) → ปฏิบัติเหมือนลบสำเร็จ (haptic + ปิดหน้าจอ) แทนที่จะแสดง error ที่ทำให้เข้าใจผิด
- ถ้า `fetchById()` ยังคืน Drop อยู่ (ยังไม่ถูกลบจริง) → แสดง error ตามเดิม (เป็นความล้มเหลวจริง)
- ถ้า `fetchById()` เองก็ throw (เช่นเน็ตยังไม่กลับมา) → fallback แสดง error ตามพฤติกรรมเดิม (ไม่แย่ไปกว่าเดิม)

เป็น fix ที่พึ่งพา WYN-120 โดยตรง (`fetchById()` ต้อง filter `deleted_at` ให้ถูกต้องก่อน ถึงจะใช้เป็นตัวเช็ค "ยังอยู่จริงไหม" ได้อย่างน่าเชื่อถือ) — ถ้าไม่มี WYN-120 fix มาก่อน fix นี้จะเช็คผิดเพราะ RLS author-exception จะทำให้ `fetchById()` ยังคืนแถวที่ถูกลบแล้วกลับมาอยู่ดี

## Files Changed

- `app/lib/features/drop/presentation/drop_detail_screen.dart` — `_deleteDrop()`: เพิ่ม fetchById() verification ใน catch block
- `app/test/drop_detail_screen_test.dart` — เพิ่ม 2 tests: (1) delete throw แต่ server สำเร็จจริง → ปิดหน้าจอเหมือนสำเร็จ ไม่โชว์ error (2) delete throw และ Drop ยังอยู่จริง (ล้มเหลวจริง) → ยังโชว์ error เหมือนเดิม (regression check — ไม่ใช่ทุก error จะถูกกลืนเป็น "สำเร็จ" ไปหมด)

## Tests

Flutter test ใหม่ 2 เคส (ไม่มี Flutter SDK ใน sandbox นี้ให้รันจริง — ยืนยัน syntax ตรงกับ `RecordingDropRepository`'s API ที่มีอยู่แล้ว `deleteDropError`/`fetchByIdResults`/`fetchByIdCalls` พึ่งพา CI's `flutter test` เหมือนที่ทำมาตลอด session):

1. `'WYN-121: deleteDrop() throwing ... still closes the screen once fetchById confirms the Drop is actually gone'` — จำลอง exact scenario ที่เกิดจริงบน production
2. `'WYN-121 regression: deleteDrop() throwing for a real failure (the Drop is still live) still shows the failure SnackBar'` — ยืนยันว่า fix ไม่ได้ทำให้ error จริงๆ หายไปเงียบๆ

## Regression Risk

**ต่ำ** — เพิ่ม network round-trip เดียว (`fetchById()`) เฉพาะตอนที่ `deleteDrop()` throw เท่านั้น (ไม่กระทบ happy path ที่ไม่มี error เลย) ถ้า `fetchById()` เองก็ throw (เช่นเน็ตหลุดจริงต่อเนื่อง) จะ fallback ไปแสดง error แบบเดิมทุกประการ ไม่มีทางที่ fix นี้จะทำให้การลบที่ล้มเหลวจริงถูกรายงานผิดว่าสำเร็จ (regression test ข้อ 2 ยืนยันแล้ว)

## Related

Pattern เดียวกัน (`catch (_) { แสดง SnackBar ล้มเหลวเสมอ }`) พบซ้ำใน 4 จุดสำหรับ Club posts: `club_post_detail_screen.dart`, `club_posts_tab.dart`, `hashtag_feed_screen.dart`, `from_your_clubs_feed.dart` — Club posts ไม่มี soft-delete (real `DELETE`) จึงน่าจะใช้ fix แบบเดียวกันได้ (เช็คว่า post ยังอยู่จริงไหมก่อนฟันธง error) แต่**ไม่ได้แก้ในรอบนี้** เพราะ Founder รายงานเฉพาะ Drop และยังไม่มีหลักฐานยืนยันว่า Club posts เจอปัญหาเดียวกันจริง — แนะนำให้ AI QA & Security ตรวจสอบเพิ่มเติมเป็น task แยก ถ้าพบรายงานคล้ายกันในอนาคต

## Handoff

ส่งต่อ AI Deploy & DevOps เพื่อ deploy ขึ้น production หลัง CI ผ่านบน PR ใหม่
