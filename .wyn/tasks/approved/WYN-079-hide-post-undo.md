# Feature Request — WYN-079

Status: approved — QA PASS (2026-09-02)
Phase: Phase 1 — Quick fix
แหล่งที่มา: `Wynos V1.0.0 Beta2.pdf` (Founder แนบมาพร้อมคำสั่ง 2026-09-02, ข้อ 8/28) — ดูรายละเอียดคำถาม/คำตอบเพิ่มเติมใน `.wyn/company/DECISIONS.md` (2026-09-02)

Feature: เพิ่มปุ่ม/ทาง Undo หลังกด "ไม่สนใจโพสต์นี้"
Goal: ป้องกันผู้ใช้กดพลาดแล้วเสียโพสต์ที่อยากดูไปถาวรโดยไม่มีทางย้อนกลับ
Target User: ผู้ใช้ WYN Social ทุกคน
Problem: Founder: "เวลากด ไม่สนใจโพสต์นี้ โพสต์มันหายไปเลย อยากให้มีปุ่มย้อนกลับ"
Requirements:
- หลังกด "ไม่สนใจโพสต์นี้" แสดง snackbar/toast ชั่วคราวพร้อมปุ่ม "เลิกทำ" (Undo)
- ถ้ากด Undo ทันเวลา โพสต์กลับมาแสดงในฟีดตำแหน่งเดิม (หรือใกล้เคียง) เหมือนไม่เคยกด
Acceptance Criteria:
- [ ] กด "ไม่สนใจโพสต์นี้" แล้วเห็นทาง Undo ทันที และกด Undo แล้วโพสต์กลับมาจริง
- [ ] ถ้าไม่กด Undo ภายในเวลาที่กำหนด โพสต์ถูกซ่อนถาวรตามพฤติกรรมเดิม
Dependencies: ไม่มี
Priority: สูง (แก้ UX เสียหายจริง)
Risks:
| # | ความเสี่ยง | ระดับ | การป้องกัน |
|---|---|---|---|
| R1 | เก็บ state "ไม่สนใจ" ผิดจังหวะจน Undo ไม่ sync กับ backend | ต่ำ-กลาง | ทดสอบ race condition กรณีกด Undo ตอนกำลัง sync |
Recommendation: อนุมัติ
Handoff: AI Design (ระยะเวลา snackbar/ข้อความ) → AI Coding

---

## Coding Output (2026-09-02)

Implementation: ตรวจโค้ดเดิมพบว่า "ไม่สนใจโพสต์นี้" มีอยู่แล้ว (`HomeRepository.hideContent` insert แถวลง `feed_signals` ที่ `signal_type='hide'`) แต่ `get_wynos_ranked_feed()` filter ด้วย `not exists` เป็น **hard filter ถาวร** และเดิม doc comment ของ `hideContent` เขียนไว้ตรงๆ ว่า "no unhide this round" — Founder สั่งย้อนมติเดิมนี้ตรงๆ (ข้อ 8/28) เลยต้องเพิ่มความสามารถ unhide จริงทั้ง 3 ชั้น ไม่ใช่แค่ UI:
1. **DB (`supabase/schema.sql`)**: เพิ่ม RLS policy ใหม่ `"Users can delete their own feed signals"` (`for delete ... using (auth.uid() = user_id)`) — เดิมมีแค่ select/insert policy ไม่มี delete เลย
2. **Repository (`HomeRepository`)**: เพิ่ม `unhideContent()` ลบแถว `feed_signals` ที่ตรงกับ user/signal_type='hide'/target_type/target_id ของ contentType/contentId ที่ระบุ (filter shape เดียวกับที่ SQL test ยืนยันไว้)
3. **UI (`HomeFeedScreen._hideItem`)**: หลัง `hideContent` สำเร็จ แสดง `SnackBar` ข้อความ "ไม่สนใจโพสต์นี้แล้ว" พร้อมปุ่ม "เลิกทำ" (SnackBarAction, ใช้ pattern เดียวกับ `report_sheet.dart`/`product_detail_screen.dart` ที่มีอยู่แล้ว) — กด "เลิกทำ" เรียก `_undoHideItem` ใส่การ์ดกลับตำแหน่งเดิมใน `_items` (optimistic) แล้วเรียก `unhideContent` ตาม ถ้า `unhideContent` fail การ์ดก็ยังอยู่ในฟีด (ตามเจตนา Undo) แค่ signal ฝั่ง server อาจไม่ sync จนกว่า fetch ครั้งถัดไป — ไม่ error ให้ผู้ใช้เห็น

**พบปัญหาสำคัญนอกสโคประหว่างพยายามรัน SQL regression test**: `supabase/schema.sql` **โหลดสดเข้า PostgreSQL 16 ว่างเปล่าไม่ผ่าน** (`ERROR: cannot change name of view column "comment_count" to "liked_by"` ที่บรรทัด ~7365) — เป็นปัญหาเดิมที่มีอยู่ก่อนงานนี้ (ยืนยันด้วย `git stash` แล้วรันซ้ำ error เดิมทุกประการ) เกิดจาก `create or replace view public.home_feed` สะสม 7 ครั้งในไฟล์ที่อย่างน้อย 1 คู่เรียงคอลัมน์ใหม่แบบที่ PostgreSQL's `CREATE OR REPLACE VIEW` ไม่ยอม (ต้องใช้ `ALTER VIEW ... RENAME COLUMN` แทน) — ตรงกับ error class เดียวกับ P0 incident ที่เคยเจอใน production ตอน WYN-071/072 (`.wyn/company/DECISIONS.md`) แต่ครั้งนั้นแก้ที่ production ตรงๆ ไม่เคยแก้ที่ไฟล์ `schema.sql` เอง — **ผลคือ `supabase/tests/wyn_063_unified_home_feed_test.sh` (และการรัน schema.sql สดทุกฉบับ) ใช้งานไม่ได้ตอนนี้** ไม่เกี่ยวกับงานนี้เลยแต่บล็อกการทดสอบ SQL ทุกอย่างที่ต้องพึ่ง schema.sql เต็มไฟล์ — **ไม่ได้แก้ในรอบนี้** (out of scope ของ Phase 1 quick fix ไม่อยากแตะ view history ใหญ่ที่ไม่เข้าใจครบทุกจุดโดยไม่ได้รับมอบหมาย) แต่ควรแจ้ง Founder/AI Deploy ให้ทราบและแก้แยกเป็นงานของตัวเอง

เพื่อยืนยัน policy ใหม่โดยไม่ต้องพึ่ง schema.sql เต็มไฟล์ที่พังอยู่ เขียน `supabase/tests/wyn_079_feed_signals_unhide_test.sh` ใหม่ (standalone harness เฉพาะ `profiles`+`feed_signals`+3 policy จริงคัดลอกมาจาก schema.sql เป๊ะ) พิสูจน์ red→green จริง (ปิด policy ชั่วคราวด้วย `using (false)` เห็น CHECK1/CHECK2 fail ตรงตามคาด คืนค่าแล้วผ่านครบ)

Files Changed:
- `supabase/schema.sql` — เพิ่ม DELETE policy บน `feed_signals`
- `app/lib/features/home/data/home_repository.dart` — เพิ่ม `unhideContent()`, อัปเดต doc comment ของ `hideContent()`
- `app/lib/features/home/presentation/home_feed_screen.dart` — `_hideItem` แสดง Snackbar+Undo, เพิ่ม `_undoHideItem`
- `app/test/support/recording_home_repository.dart` — เพิ่ม `unhideContent()` override + `unhideContentArgs` สำหรับเทส
- `app/test/home_feed_screen_test.dart` — เพิ่ม 2 เทสใหม่ (กด Undo แล้วการ์ดกลับมา+เรียก unhideContent ถูกต้อง, ไม่กด Undo แล้ว unhideContent ไม่ถูกเรียก) + fixture ใหม่ `hideDropUndoTimeoutTestHomeRepository` (แยกจาก `hideDropTestHomeRepository` เพราะ fixture ทั้งไฟล์สร้างครั้งเดียวใน `setUpAll` ไม่ได้ reset ต่อเทส ใช้ร่วมกันจะเห็น call-log ของเทสก่อนหน้าเป็น false failure — เจอบั๊กนี้เองระหว่างเขียนเทส แก้แล้ว)
- `supabase/tests/wyn_079_feed_signals_unhide_test.sh` — เทสใหม่ (standalone harness ตามเหตุผลด้านบน)

Reason: Founder ข้อ 8/28 — "เวลากด ไม่สนใจโพสต์นี้ โพสต์มันหายไปเลย อยากให้มีปุ่มย้อนกลับ"

Tests:
- `flutter analyze`: สะอาด
- `flutter test`: **873/873 ผ่านหมด** (871 เดิม + 2 ใหม่)
- `bash supabase/tests/wyn_079_feed_signals_unhide_test.sh`: **3/3 CHECK ผ่าน** พิสูจน์ red→green จริงด้วยตัวเอง (ปิด policy ชั่วคราวเห็น fail ตรงตามคาด)
- `bash supabase/tests/wyn_063_unified_home_feed_test.sh`: **รันไม่ผ่าน — แต่เป็นปัญหาเดิมก่อนงานนี้** (ดูรายละเอียดด้านบน ยืนยันด้วย `git stash`)

Build: ไม่ได้รัน `flutter build`/`supabase db push` จริง — DELETE policy ใหม่ยังไม่ได้ apply เข้า production (ต้องรอ AI Deploy & DevOps ตามขั้นตอนปกติของโปรเจกต์นี้ + คำเตือนจาก P0 incident เดิมว่า schema delta ต้อง apply แยกจาก deploy โค้ดเสมอ)

Known Issues:
- **`schema.sql` โหลดสดไม่ผ่าน (pre-existing, นอกสโคป)** — ดูรายละเอียดเต็มด้านบน ต้องมีคนแก้ history ของ `home_feed` view แยกเป็นงานของตัวเอง ไม่งั้น SQL regression suite ทั้งหมดที่พึ่ง schema.sql เต็มไฟล์ (ไม่ใช่แค่ wyn_063) จะรันไม่ได้เรื่อยๆ
- DELETE policy ใหม่ยังไม่ live ใน production จนกว่า Deploy จะ apply — ถ้า QA ทดสอบกับ production DB จริงตอนนี้ กด "เลิกทำ" จะ fail เงียบๆ (การ์ดยังกลับมาที่ UI แต่ signal ฝั่ง server ไม่ถูกลบจริง จนกว่า migration จะ apply)

Handoff: ส่งต่อ AI QA & Security — (1) ตรวจ SQL policy ตาม `wyn_079_feed_signals_unhide_test.sh` (2) ตรวจ UI flow กด "ไม่สนใจโพสต์นี้" → เห็น Snackbar → กด "เลิกทำ" → การ์ดกลับมา (3) **แจ้ง Founder/AI Deploy เรื่อง schema.sql โหลดสดไม่ผ่าน** เป็นปัญหาที่ควรแก้แยกต่างหากโดยเร็ว เพราะบล็อก SQL regression testing ทั้งระบบ ไม่ใช่แค่งานนี้

---

## QA Report (2026-09-02)

Feature: Undo หลังกด "ไม่สนใจโพสต์นี้" (Snackbar + เลิกทำ) พร้อม DELETE policy ใหม่บน `feed_signals` (Wynos V1.0.0 Beta2, ข้อ 8/28)

Environment: อ่านโค้ดจริง + รัน `flutter analyze`/`flutter test` จริง + รัน `bash supabase/tests/wyn_079_feed_signals_unhide_test.sh` จริงกับ PostgreSQL 16 ที่ตั้งค่าขึ้นเองในเครื่อง sandbox นี้ (`service postgresql start`)

Test Cases:
1. `flutter analyze` สะอาดจริง
2. `flutter test` เต็ม suite ผ่านจริง (917/917)
3. รัน `bash supabase/tests/wyn_079_feed_signals_unhide_test.sh` เอง — **3/3 CHECK ผ่านจริง** (CHECK1 เจ้าของ signal ลบ signal ตัวเองได้, CHECK2 ยืนยันแถวหายไปจริงในมุมมอง superuser (ไม่ใช่แค่ถูกซ่อนจาก SELECT), CHECK3 ผู้ใช้อื่นลบ signal ของคนอื่นไม่ได้ — 0 แถวถูกลบ)
4. เทียบ SQL ใน `supabase/schema.sql`'s `feed_signals` section (บรรทัด ~10011-10061) กับที่ harness ใช้ — **ตรงกันคำต่อคำ (verbatim)** จริงตามที่ Coding Output อ้าง ไม่ใช่แค่ paraphrase
5. อ่านโค้ด `HomeRepository.unhideContent()` — filter shape (`user_id`/`signal_type='hide'`/`target_type`/`target_id`) ตรงกับที่ policy ทดสอบไว้เป๊ะ
6. อ่านโค้ด `HomeFeedScreen._hideItem`/`_undoHideItem` — Snackbar+ปุ่ม "เลิกทำ" แสดงถูกต้องหลัง hide สำเร็จ, undo แทรกการ์ดกลับตำแหน่งเดิม (optimistic) แล้วเรียก `unhideContent` ตาม, ถ้า `unhideContent` fail การ์ดยังอยู่ในฟีด (ไม่ error ผู้ใช้เห็น) — ตรงตามเจตนา
7. **Edge case ที่ลองพยายาม break**: ถ้าผู้ใช้กด "ไม่สนใจ" หลายโพสต์ติดกันเร็วๆ ก่อนกด Undo ของโพสต์แรก — ตรวจโค้ดแล้ว index ที่ capture ไว้ตอน hide อาจ stale ถ้ามีการ hide โพสต์ที่อยู่ index ต่ำกว่าคั่นกลางก่อน undo จะทำงาน (การ์อาจ insert กลับผิดตำแหน่งเล็กน้อย) — ตรวจสอบแล้วไม่ crash (clamp ด้วย `index <= _items.length ? index : _items.length`) เป็นแค่ cosmetic edge case ไม่ใช่ functional bug ที่ทำให้ acceptance criteria ล้มเหลว ("โพสต์กลับมาแสดงในฟีดตำแหน่งเดิม **หรือใกล้เคียง**" — สเปกเองยอมรับ "ใกล้เคียง" ได้)
8. `wyn_063_unified_home_feed_test.sh` รันไม่ผ่านจริง — ยืนยันแล้วว่าเป็นปัญหาเดิม (pre-existing, นอกสโคป WYN-079) จาก `schema.sql`'s `home_feed` view migration history ไม่ใช่ regression จากงานนี้

Passed: 1, 2, 3, 4, 5, 6, 7, 8

Failed: ไม่มี

Severity: N/A (PASS)

Reproduction Steps: N/A

Expected: N/A

Actual: N/A

Security Findings: DELETE policy ใหม่ (`"Users can delete their own feed signals"`) จำกัดด้วย `using (auth.uid() = user_id)` เหมือน select/insert policy เดิม — ไม่มี privilege escalation, ผู้ใช้ลบ signal ของคนอื่นไม่ได้จริง (ยืนยันด้วย CHECK3) ไม่มี secret/ข้อมูลส่วนตัวหลุด

Recommendation: อนุมัติ PASS — **ยืนยันซ้ำเรื่อง `schema.sql` โหลดสดไม่ผ่าน (pre-existing bug, นอกสโคป)**: ควรแจ้ง Founder/AI Deploy & DevOps ให้ตั้งเป็นงานแก้แยกต่างหากโดยเร็ว เพราะบล็อก SQL regression testing เต็มรูปแบบทั้งระบบ (ไม่ใช่แค่ WYN-063) ไม่เกี่ยวกับ WYN-079 นี้โดยตรงแต่ยืนยันแล้วว่ายังคงอยู่จริง — **เตือน AI Deploy & DevOps**: DELETE policy ใหม่ยังไม่ apply เข้า production ต้อง migrate แยกก่อนใช้งานจริง (ไม่งั้นกด "เลิกทำ" จะดูเหมือนได้ผลใน UI แต่ signal ฝั่ง server ไม่ถูกลบจริง ตามที่ Coding Output เตือนไว้แล้ว)

Final Status: PASS
