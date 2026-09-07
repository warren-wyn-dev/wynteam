# Bug Report — WYN-120

Status: **Deploy ขึ้น production แล้ว (deploy-web.yml run #90, 2026-09-06 08:17 UTC) — รอ Founder ยืนยันว่าลบโพสต์จริงแล้วหายจากโปรไฟล์ทันที ก่อนย้ายไป completed/** ดู `.wyn/logs/deployments/2026-09-06-wyn-120-delete-drop-profile-fix-deploy.md`

**อัปเดต 2026-09-07**: Founder ทดสอบซ้ำแล้วอาการเดิมยังอยู่ — แต่ยืนยันแล้วว่า **ไม่ใช่บั๊กเดิมกลับมา** fix ของ WYN-120 (`fetchById()`) ยังทำงานถูกต้องและ deploy จริง (ตรวจ code + production header ซ้ำแล้ว) เป็นบั๊กคนละตัวที่มีอาการเหมือนกัน: `ProfileDropGridTab._loadInitial()` ใช้ `DropRepository.fetchByAuthor()` (คนละ method กับ `fetchById()`) ซึ่งไม่เคยมี `deleted_at` filter มาก่อนเลย — root cause/fix/test เต็มอยู่ที่ `.wyn/tasks/bugs/WYN-132-profile-grid-fetch-by-author-missing-deleted-at-filter.md` งานนี้ (WYN-120) ยังคงสถานะเดิมไว้ (fix ของตัวเองถูกต้องแล้ว ไม่ต้องแก้เพิ่ม) — ให้ Founder ยืนยันทั้งสอง fix (WYN-120 + WYN-132) พร้อมกันในรอบทดสอบถัดไป
Owner: AI Debug Engineer → AI Deploy & DevOps → รอ Founder ยืนยัน
Reported by: Founder (สด, ไม่ผ่าน QA ก่อน): "ตอนลบโพสต์ หน้าโปรไฟล์ โพสต์ไม่หายเลย"

## Bug

ลบโพสต์ของตัวเอง (จาก Drop Detail → เมนู ⋯ → ลบ) แล้วกลับมาหน้าโปรไฟล์ของตัวเอง — โพสต์ที่เพิ่งลบยังค้างอยู่ในกริดเหมือนเดิม ไม่หายไปจนกว่าจะรีเฟรชทั้งหน้าใหม่ (pull-to-refresh หรือออกแล้วกลับเข้าโปรไฟล์ใหม่)

## Reproduction

1. Login เป็น user A, เปิด Drop ของ user A เอง 1 โพสต์ จาก Profile grid
2. กดเมนู ⋯ (มุมขวาบน, เมนูนี้แสดงเฉพาะเจ้าของโพสต์) → "ลบ"
3. แอปเรียก `soft_delete_drop()` RPC สำเร็จ แล้ว `Navigator.pop()` กลับไปหน้า Profile grid โดยไม่ reload ทั้งหน้า
4. **คาดหวัง**: โพสต์นั้นหายไปจากกริดทันที
5. **จริง**: โพสต์ยังอยู่ในกริดเหมือนไม่มีอะไรเกิดขึ้น (แต่ถ้ากดเปิดโพสต์นั้นซ้ำจะเจอ error/ว่างเปล่า เพราะจริงๆ มันถูกลบไปแล้วในฐานข้อมูล)

Path เดียวกันนี้ยังกระทบ `profile_likes_tab.dart` (แท็บถูกใจ) และ `hashtag_feed_screen.dart` (ฟีดแฮชแท็ก) เพราะทั้งสามหน้าใช้ pattern `_refreshRow()` เดียวกันหลังกลับจาก Detail — ยืนยันด้วยการอ่านโค้ดทั้งสามไฟล์ ไม่ใช่การเดา

## Root Cause

**ยืนยันจากการอ่าน `supabase/schema.sql` โดยตรง ไม่ใช่การเดา.** RLS SELECT policy บนตาราง `public.drops`:

```sql
create policy "Drops are viewable by authenticated users, excluding blocked authors and deleted"
  on public.drops
  for select
  to authenticated
  using (
    not internal.is_blocked_either_way(auth.uid(), author_id)
    and (deleted_at is null or auth.uid() = author_id)
  );
```

`(deleted_at is null or auth.uid() = author_id)` เป็นการออกแบบที่ **ตั้งใจ** — เพื่อให้เจ้าของโพสต์ยังมองเห็นโพสต์ที่ตัวเองลบไปแล้วได้ ซึ่งเป็นสิ่งจำเป็นสำหรับฟีเจอร์ "รายการที่ลบ" (Recently Deleted, WYN-037) ที่ให้กู้คืนโพสต์ภายใน 30 วัน

ปัญหาคือ `DropRepository.fetchById(dropId)` — method กลางที่ใช้เป็น "เช็คว่าโพสต์นี้ยังอยู่จริงไหม" ใน ~10 จุดทั่วแอป (รวมถึง `ProfileDropGridTab._refreshRow()`) — **ไม่เคย filter `deleted_at` เองเลย**:

```dart
// ก่อนแก้:
final row = await _client
    .from('drops')
    .select(_dropSelect)
    .eq('id', dropId)
    .maybeSingle();
```

เมื่อผู้เรียกคือ**เจ้าของโพสต์เอง** (เคสตรงตัวของบั๊กนี้: "คุณเพิ่งลบโพสต์ของคุณเอง แล้วกลับมาหน้าโปรไฟล์ของคุณเอง") RLS's author-exception ทำให้ query นี้ยังคืนแถวนั้นกลับมาอยู่ดี (ไม่ใช่ `null`) ทั้งที่โพสต์ถูกลบไปแล้ว ผลคือ `_refreshRow()` ที่มี logic "ถ้า `fetchById` คืน `null` ให้ลบแถวออกจากกริด, ถ้าไม่ใช่ `null` ให้อัปเดตแถวแทน" — ไม่เคยเจอ `null` เลย เลยไม่ลบโพสต์ออกจากกริด

`fetchDeletedDrops()` (สำหรับหน้า "รายการที่ลบ" เอง) filter ตรงกันข้ามอย่างชัดเจนอยู่แล้ว (`.not('deleted_at', 'is', null)`) — เป็นหลักฐานว่าทีมเดิมรู้จัก RLS exception นี้ดี แต่ไม่ได้ตามไปแก้ `fetchById()` ให้ครบ

**ยืนยันขอบเขต**: `club_posts` และ `pops` ไม่มีคอลัมน์ `deleted_at`/soft-delete เลย (grep schema.sql ยืนยันแล้ว) — บั๊กนี้จำกัดเฉพาะ Drops เท่านั้น

## Fix

เพิ่ม `.isFilter('deleted_at', null)` เข้าไปใน query chain ของ `DropRepository.fetchById()` — ตรงตาม syntax ที่ใช้อยู่แล้วในโปรเจกต์ (`home_repository.dart:141`, `:908`):

```dart
final row = await _client
    .from('drops')
    .select(_dropSelect)
    .eq('id', dropId)
    .isFilter('deleted_at', null)
    .maybeSingle();
```

เป็น fix ที่เล็กที่สุดเท่าที่เป็นไปได้ — บรรทัดเดียว ไม่แตะ schema/RLS/migration ใดๆ เลย เพราะพฤติกรรม RLS ปัจจุบันถูกต้องแล้วตามที่ออกแบบไว้ (WYN-037) ปัญหาอยู่ที่ client query ฝั่ง Dart ไม่ครบเท่านั้น เนื่องจาก `fetchById()` ถูกใช้ร่วมกันในหลายจุด การแก้ที่จุดเดียวนี้แก้ผลกระทบใน `ProfileDropGridTab`/`profile_likes_tab`/`hashtag_feed_screen`/`profile_replies_tab`/`moderation_report_detail_screen`/`notification_list_screen`/`conversation_screen`/`push_notification_service` (เฉพาะ path ที่เกี่ยวกับ Drops) พร้อมกันทั้งหมด

## Files Changed

- `app/lib/features/drop/data/drop_repository.dart` — `fetchById()`: เพิ่ม `.isFilter('deleted_at', null)` + doc comment อธิบาย root cause

## Tests

**Regression test ใหม่**: `supabase/tests/wyn_120_delete_drop_not_disappearing_from_profile_test.sh` — รันจริงกับ PostgreSQL 16 local (`schema.sql` ตัวจริง, RLS จริง, role-switching จริงแบบเดียวกับ `wyn_037_edit_delete_drop_test.sh`) — 6 checks, **ALL CHECKS PASSED**:

1. `CHECK1` — จำลอง query แบบก่อนแก้ (id-only, ไม่ filter `deleted_at`) รันในฐานะเจ้าของโพสต์ที่เพิ่งลบไป → **ยังคืนแถวกลับมา (reproduce บั๊กได้จริงที่ระดับ RLS)**
2. `CHECK2` — คนแปลกหน้า (ไม่ใช่เจ้าของ) ไม่เคยเห็นโพสต์ที่ถูกลบเลยทั้งก่อนและหลังแก้ (ยืนยันว่าบั๊กนี้กระทบเฉพาะเจ้าของโพสต์ ไม่ใช่การรั่วไหลข้อมูลให้คนอื่น)
3. `CHECK3` — จำลอง query แบบหลังแก้ (id + `deleted_at is null`) รันในฐานะเจ้าของโพสต์ → **คืนค่าว่างถูกต้อง (fix ใช้ได้จริง)**
4. `CHECK4` — regression: query ของ `fetchDeletedDrops()` (filter ตรงข้าม `deleted_at is not null`) สำหรับหน้า "รายการที่ลบ" ยังทำงานถูกต้องเหมือนเดิม ไม่ถูกกระทบจาก fix นี้
5. `CHECK5`/`CHECK6` — regression: โพสต์ที่ยังไม่ถูกลบ (live) ยังคืนค่าถูกต้องทั้งสำหรับเจ้าของและคนแปลกหน้า

Flutter/Dart-side: ไม่มี Flutter SDK ในห้อง sandbox นี้ (ยืนยันด้วย `which flutter` ไม่พบ) — พึ่งพา CI's `flutter analyze`/`flutter test` step บน PR ตามที่ทำมาตลอดทั้ง session นี้ syntax `.isFilter('deleted_at', null)` ตรงกับที่ใช้อยู่แล้วในไฟล์เดียวกันของโปรเจกต์ (`home_repository.dart`) ยืนยันว่าถูกต้องตาม Supabase Dart client API

## Regression Risk

**ต่ำมาก** — เพิ่ม filter เข้าไปในทิศทางที่ "เข้มงวดขึ้น" เท่านั้น (จากคืนแถวที่อาจถูกลบไปแล้ว เป็นไม่คืนแถวที่ถูกลบ) ไม่มีทางที่ query จะเริ่มคืนแถวที่ก่อนหน้านี้ไม่เคยคืนมาก่อน จึงไม่มีทางเปิดโพสต์ live ให้หายไปโดยไม่ตั้งใจ ไม่มี migration ไม่มีการแก้ RLS/schema ใดๆ เลย เป็น client-side query change ล้วนๆ เหมือนกับ WYN-114

## Related, NOT fixed in this pass (ติดตามแยก)

พบระหว่างสืบสวน: `HomeRepository.fetchItemById()` (ใช้โดย `profile_redrops_tab.dart` แท็บ "รีดรอป") query ตรงกับ view `home_feed` (ไม่ใช่ตาราง `drops` โดยตรง) ซึ่ง**ไม่ expose คอลัมน์ `deleted_at`ในผลลัพธ์** (ตรวจสอบจาก definition ล่าสุดของ view ที่ `schema.sql` บรรทัด ~10902) — จึงแก้แบบเดียวกับ `fetchById()` (เติม filter ฝั่ง client) ไม่ได้ตรงๆ ต้องแก้ที่ตัว view เอง (เพิ่ม `deleted_at` เข้า SELECT list หรือเพิ่ม WHERE filter ในนิยาม view) ซึ่งเป็นการแก้ production view ที่มีความเสี่ยงสูงกว่ามาก (ดูประวัติ WYN-109/SCHEMA-004 เรื่อง view drift)

นอกจากนี้ `HomeRepository.fetchFeed()` (Home feed หลัก) ก็ query view เดียวกันนี้โดยไม่มี explicit `deleted_at` filter เช่นกัน — **ยังไม่ได้ทดสอบยืนยันจริงว่ากระทบ Home feed หรือไม่** เป็นเพียงข้อสังเกตจากการอ่าน view definition เท่านั้น

**ไม่รวมอยู่ใน fix รอบนี้โดยเจตนา** เพราะ (1) ขอบเขตกว้างกว่าและเสี่ยงกว่ามาก ต้องแก้ที่ production view (2) บั๊กที่ Founder รายงานคือหน้าโปรไฟล์ ซึ่งแก้ครบแล้วในรอบนี้ (3) ควรแยกเป็น task ใหม่ให้ AI Product Manager/AI Coding วางแผนแก้ view อย่างรอบคอบแยกต่างหาก ไม่ปนกับ hotfix ด่วนนี้

แนะนำให้เปิด task ใหม่ (WYN-121 หรือเลขถัดไปที่ยังไม่ถูกใช้ ณ ตอนเปิดจริง — ตรวจ collision ก่อนเสมอ) สำหรับเรื่องนี้แยกต่างหาก

## Handoff to QA

ส่งต่อ AI QA & Security เพื่อ:
1. ทวนโค้ด fix (`app/lib/features/drop/data/drop_repository.dart`) และ regression test (`supabase/tests/wyn_120_delete_drop_not_disappearing_from_profile_test.sh`)
2. รอ CI (`flutter analyze` + `flutter test`) ผ่านบน PR
3. ตรวจว่า fix ครอบคลุมทุกจุดที่ใช้ `fetchById()` จริงตามที่ระบุไว้ข้างต้น (ไม่ต้องแก้เพิ่ม แค่ตรวจว่า caller ทุกจุดพึ่งพา method เดียวกันจริง)
4. ตัดสินใจว่าจะสร้าง task ใหม่สำหรับปัญหา `HomeRepository`/`home_feed` view ที่พบระหว่างทางหรือไม่ (แนะนำให้สร้าง แต่เป็น QA/Product ตัดสินใจ priority)
