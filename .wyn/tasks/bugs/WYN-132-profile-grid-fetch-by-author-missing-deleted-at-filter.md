# Bug Report — WYN-132

Status: **แก้แล้ว รอ CI + Founder ยืนยันบน production ก่อนย้ายไป completed/**
Owner: AI Debug Engineer → รอส่งต่อ AI QA & Security → รอ Founder ยืนยัน
Reported by: Founder (สด, ไม่ผ่าน QA ก่อน): "ทำไมกดลบโพสต์แล้ว โพสต์ที่อยู่หน้าโปรไฟล์ไม่หาย" — **อาการเดียวกันเป๊ะกับ WYN-120 ซึ่ง deploy fix ไปแล้ว** (2026-09-06 08:17 UTC)

## Bug

ลบโพสต์ของตัวเอง (จาก Drop Detail → เมนู ⋯ → ลบ) แล้วกลับมาหน้าโปรไฟล์ของตัวเอง (แท็บ Drops/กริดโพสต์หลัก) — โพสต์ที่เพิ่งลบยังค้างอยู่ในกริด **แม้ปิดแท็บ/รีเฟรชหน้าใหม่ทั้งหมดแล้วก็ยังไม่หาย** (ต่างจาก WYN-120 ที่หายไปได้ถ้ารีเฟรชทั้งหน้า — นี่คือสัญญาณสำคัญที่แยกบั๊กสองตัวนี้ออกจากกัน)

## Reproduction

1. Login เป็น user A, เปิดโปรไฟล์ตัวเอง → แท็บ Drops (กริดโพสต์หลัก) → เปิดโพสต์ 1 อัน
2. กดเมนู ⋯ → "ลบ" → ยืนยัน → `soft_delete_drop()` RPC สำเร็จ → กลับมาหน้าโปรไฟล์
3. ปิดแท็บเบราว์เซอร์ทั้งหมด เปิดใหม่ แล้วเข้าโปรไฟล์อีกครั้ง (ตัดความเป็นไปได้เรื่อง client cache/stale in-memory state ออกทั้งหมด)
4. **คาดหวัง**: โพสต์ที่ลบไปแล้วไม่ปรากฏในกริด
5. **จริง**: โพสต์ยังอยู่ในกริดเหมือนไม่มีอะไรเกิดขึ้น

**การถามยืนยันก่อนสรุป root cause** (ตามกติกา "ห้ามเดา root cause"): ถาม Founder 3 คำถามผ่าน popup ก่อนอ่านโค้ด —
1. แท็บไหน → **แท็บ Drops (กริดโพสต์หลัก)**
2. แพลตฟอร์มไหน → **เว็บ (wynos.online ผ่านเบราว์เซอร์)**
3. รีเฟรชแบบไหน → **"ยังค้างอยู่เหมือนเดิม แม้รีเฟรชหน้าใหม่ทั้งหมด"** ← คำตอบนี้ตัดทฤษฎี "client cache/stale tab เก่าจาก WYN-120 ยังไม่ deploy ถึงเบราว์เซอร์ผู้ใช้" ทิ้งได้ทันที เพราะ full page reload สร้าง widget ทั้งหมดใหม่จาก initState()

ยืนยันเพิ่มเติมว่า WYN-120's fix deploy จริงและถูกต้อง: อ่านโค้ดปัจจุบันของ `DropRepository.fetchById()` มี `.isFilter('deleted_at', null)` อยู่แล้ว (บรรทัด ~501), `ProfileDropGridTab._refreshRow()`/`_openDropDetail()` เรียก logic ถูกต้องครบ, deployment log (`.wyn/logs/deployments/2026-09-06-wyn-120-delete-drop-profile-fix-deploy.md`) ยืนยัน commit `8e42ae9` ขึ้น production จริงผ่าน curl (bundle มี `deleted_at` string literal, `Last-Modified` ตรงเวลา deploy) — **ไม่ใช่บั๊กเดิมกลับมา ไม่ใช่ deploy ไม่ถึง เป็นบั๊กคนละตัวที่มีอาการเหมือนกัน**

## Root Cause

**ยืนยันจากการอ่าน `app/lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart` และ `app/lib/features/drop/data/drop_repository.dart` โดยตรง ไม่ใช่การเดา.**

`ProfileDropGridTab._loadInitial()` (เรียกจาก `initState()` — วิ่งทุกครั้งที่หน้าโปรไฟล์ถูก mount ใหม่ ไม่ว่าจะจาก full page reload หรือเปิดโปรไฟล์ครั้งแรก) และ `_loadMore()`/pull-to-refresh ทั้งหมดเรียก `DropRepository.fetchByAuthor()` — **คนละ method กับ `fetchById()` ที่ WYN-120 แก้ไปแล้ว**:

```dart
// ก่อนแก้:
final rows = await _client
    .from('drops')
    .select(_dropSelect)
    .eq('author_id', authorId)
    .order('created_at', ascending: false)
    .range(from, to);
```

`fetchByAuthor()` ไม่เคย filter `deleted_at` เลยตั้งแต่แรก — WYN-120 ไม่เคยแตะ method นี้ (ขอบเขตของ WYN-120 ระบุชัดว่าแก้เฉพาะ `fetchById()` เท่านั้น) เมื่อผู้เรียกคือเจ้าของโปรไฟล์เอง (เคสตรงตัว: "ดูโปรไฟล์ตัวเอง") RLS policy เดียวกับที่ WYN-120 อธิบายไว้ (`deleted_at is null or auth.uid() = author_id`) ทำให้ query นี้ยังคืนโพสต์ที่ลบไปแล้วกลับมาทุกครั้งที่โหลดกริด ไม่ว่าจะเป็น initial load, pull-to-refresh, หรือ pagination — **นี่คือสาเหตุที่แม้ full page reload ก็ยังไม่หาย** เพราะ full reload สร้าง `ProfileDropGridTab` ใหม่ทั้งหมด ซึ่งวิ่งผ่าน `fetchByAuthor()` โดยตรง ไม่เคยผ่าน `fetchById()`/`_refreshRow()` เลย

**ยืนยันขอบเขต**: grep `.from('drops')` ทั้งไฟล์ `drop_repository.dart` พบ query อื่นอีก 4 จุดที่มีช่องโหว่ลักษณะเดียวกัน (ไม่ได้แก้ในรอบนี้ — ดูหัวข้อ "Related, NOT fixed" ด้านล่าง) แต่ไม่มีจุดไหนตรงกับ reproduction ของบั๊กนี้โดยตรงนอกจาก `fetchByAuthor()`

## Fix

เพิ่ม `.isFilter('deleted_at', null)` เข้าไปใน query chain ของ `DropRepository.fetchByAuthor()` — syntax เดียวกับที่ WYN-120 ใช้กับ `fetchById()`:

```dart
final rows = await _client
    .from('drops')
    .select(_dropSelect)
    .eq('author_id', authorId)
    .isFilter('deleted_at', null)
    .order('created_at', ascending: false)
    .range(from, to);
```

เป็น fix ที่เล็กที่สุดเท่าที่เป็นไปได้ — บรรทัดเดียว ไม่แตะ schema/RLS/migration ใดๆ เลย เหตุผลเดียวกับ WYN-120 ทุกประการ: พฤติกรรม RLS ถูกต้องแล้วตามที่ออกแบบไว้ (WYN-037), ปัญหาอยู่ที่ client query ฝั่ง Dart ไม่ครบ

## Files Changed

- `app/lib/features/drop/data/drop_repository.dart` — `fetchByAuthor()`: เพิ่ม `.isFilter('deleted_at', null)` + doc comment อธิบาย root cause และอ้างอิง WYN-120/WYN-132
- `supabase/tests/wyn_132_profile_grid_deleted_drop_survives_reload_test.sh` (ใหม่) — regression test

## Tests

**Regression test ใหม่**: `supabase/tests/wyn_132_profile_grid_deleted_drop_survives_reload_test.sh` — รันจริงกับ PostgreSQL 16 local (`schema.sql` ตัวจริง, RLS จริง, role-switching จริงแบบเดียวกับ `wyn_120_*_test.sh`) — 8 checks, **ALL CHECKS PASSED**:

1. `CHECK1`/`CHECK2` — จำลอง query แบบก่อนแก้ (`author_id` match เท่านั้น ไม่ filter `deleted_at`) รันในฐานะเจ้าของโปรไฟล์ที่เพิ่งลบโพสต์ D1 ไป → **ยังคืน D1 กลับมาเป็นส่วนหนึ่งของกริด (reproduce บั๊กได้จริงที่ระดับ RLS)**
2. `CHECK3` — คนแปลกหน้าที่มาดูโปรไฟล์ของ alice ไม่เคยเห็น D1 เลยทั้งก่อนและหลังแก้ (ยืนยันว่าบั๊กนี้กระทบเฉพาะเจ้าของโปรไฟล์ตัวเอง ไม่ใช่การรั่วไหลข้อมูลให้คนอื่น)
3. `CHECK4`/`CHECK5` — จำลอง query แบบหลังแก้ (`author_id` + `deleted_at is null`) รันในฐานะเจ้าของโปรไฟล์ → **คืนเฉพาะโพสต์ที่ยังไม่ถูกลบ (D2) ถูกต้อง (fix ใช้ได้จริง)**
4. `CHECK6` — regression: `fetchDeletedDrops()`'s ตรงกันข้าม (`deleted_at is not null`) สำหรับหน้า "รายการที่ลบ" ยังทำงานถูกต้องเหมือนเดิม
5. `CHECK7`/`CHECK8` — regression: โพสต์ที่ยังไม่ถูกลบ (D2) ยังคืนค่าถูกต้องทั้งสำหรับเจ้าของและคนแปลกหน้า

**เทสต์ที่รันซ้ำเพื่อยืนยันไม่มี cross-task regression**: `wyn_120_delete_drop_not_disappearing_from_profile_test.sh` (6/6 PASS) และ `wyn_037_edit_delete_drop_test.sh` (23/23 PASS) — ทั้งสองไม่ได้รับผลกระทบเพราะ fix นี้เป็น Dart client-side query change ล้วนๆ ไม่แตะ schema.sql/RLS เลย

Flutter/Dart-side: ไม่มี Flutter SDK ในห้อง sandbox นี้ (เหมือน WYN-120) — `fetchByAuthor()` ถูก mock ทับด้วย `RecordingDropRepository` ใน Dart test ทุกจุดที่อ้างถึง (`app/test/support/recording_drop_repository.dart`, `view_profile_screen_test.dart`, `qa_wyn110_profile_scroll_header_test.dart`) จึงไม่มีความเสี่ยงที่การเปลี่ยน query chain ภายในจะกระทบ widget/unit test ที่มีอยู่ — พึ่งพา CI's `flutter analyze`/`flutter test` บน PR เพื่อยืนยัน syntax เหมือนที่ทำมาตลอด

## Regression Risk

**ต่ำมาก** — เหตุผลเดียวกับ WYN-120 ทุกประการ: เพิ่ม filter ในทิศทาง "เข้มงวดขึ้น" เท่านั้น ไม่มีทางคืนแถวที่ก่อนหน้านี้ไม่เคยคืนมาก่อน ไม่มี migration ไม่มีการแก้ RLS/schema ใดๆ เลย

## Related, NOT fixed in this pass (ติดตามแยก)

grep `.from('drops')` ทั้งไฟล์ `drop_repository.dart` พบ query อื่นอีก 4 เมธอดที่ไม่มี `deleted_at` filter เช่นกัน แต่ **ไม่ตรงกับ reproduction ของบั๊กนี้โดยตรง** (ผู้เรียกมักไม่ใช่เจ้าของโพสต์เอง ทำให้ RLS's author-exception ไม่ค่อยมีผลในทางปฏิบัติ ยกเว้นกรณีขอบ เช่น ค้นหา caption ของโพสต์ตัวเองที่ลบไปแล้ว) — ไม่รวมอยู่ใน fix รอบนี้โดยเจตนาเพื่อจำกัด blast radius ให้เท่ากับที่ Founder รายงานจริงเท่านั้น:

1. `fetchFeed()` (บรรทัด ~117) — global feed ที่ไม่ scope ตาม author
2. `searchByCaption()` (บรรทัด ~150) — ค้นหาโพสต์จาก caption
3. `fetchLikedByAuthor()` (บรรทัด ~255, ใช้ `inFilter('id', orderedIds)` ที่บรรทัด ~270) — น่าจะกระทบ `profile_likes_tab.dart` ในลักษณะเดียวกับบั๊กนี้ทุกประการถ้าผู้ใช้กดถูกใจโพสต์ของตัวเองไว้ก่อนแล้วค่อยลบมัน (ยังไม่ยืนยัน reproduce จริง)
4. `fetchFollowingFeed()` (บรรทัด ~353)
5. `fetchRankedFeed()` (บรรทัด ~405)

นอกจากนี้ `HomeRepository.fetchItemById()`/`fetchFeed()` (query `home_feed` view, ใช้โดย `profile_redrops_tab.dart`) ยังมีช่องโหว่แบบเดียวกันตามที่ WYN-120 บันทึกไว้แล้วในหัวข้อ "Related, NOT fixed" ของตัวเอง — ยังไม่ถูกแก้เช่นกัน (การแก้ต้องแตะ production view ซึ่งเสี่ยงกว่ามาก ดู SCHEMA-004)

**แนะนำ**: เปิด task ใหม่ให้ AI Product Manager/AI Coding ไล่ตรวจทั้ง 5 จุดข้างต้น + `fetchLikedByAuthor()` โดยเฉพาะ (มีโอกาส reproduce ได้จริงสูงสุดในกลุ่มนี้) อย่างเป็นระบบ แทนที่จะรอ Founder รายงานทีละจุดแบบที่เกิดกับ WYN-120→WYN-132 นี้

## Handoff to QA

ส่งต่อ AI QA & Security เพื่อ:
1. ทวนโค้ด fix (`app/lib/features/drop/data/drop_repository.dart`) และ regression test (`supabase/tests/wyn_132_profile_grid_deleted_drop_survives_reload_test.sh`)
2. รอ CI (`flutter analyze` + `flutter test`) ผ่านบน PR
3. ทดสอบ manual บน production หลัง deploy: ลบโพสต์ตัวเอง → ปิดแท็บ/รีเฟรชทั้งหน้าใหม่ → เข้าโปรไฟล์อีกครั้ง → ต้องไม่เห็นโพสต์นั้นแล้ว (ครอบคลุม case ที่ WYN-120's fix เดิมไม่ครอบคลุม)
4. ตัดสินใจว่าจะเปิด task ใหม่สำหรับ 5 จุดใน "Related, NOT fixed" หรือไม่ (แนะนำให้เปิด โดยเฉพาะ `fetchLikedByAuthor()`)
