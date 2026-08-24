# Coding Task — WYN-063

Status: approved (Coding + QA เสร็จ, 2026-08-24 — flutter analyze สะอาด, flutter test เต็ม suite 759/759 ผ่าน, SQL ranking function ยืนยันจริงบน local Postgres 16) — รอ AI Deploy & DevOps เมื่อมี infra จริง
Owner: AI Coding → AI QA & Security

## Implementation

Founder สั่งงานตรงเป็นสเปค "WYNOS — Unified Home Feed Algorithm V1.0" ให้รวม Home feed (Following / Trending / Recommended / Discovery) เป็น feed เดียวจัดอันดับด้วย "Wynos Score" (6 องค์ประกอบถ่วงน้ำหนัก) แทนการเรียงตามเวลาอย่างเดียว โดยห้ามฮาร์ดโค้ดน้ำหนักถาวรและห้ามคำนวณหนักฝั่ง client

สำรวจโค้ดเดิมก่อนแก้ (ตามที่สเปคบังคับ) พบว่า WYN-018 เคยเจอข้อจำกัดเดียวกัน (PostgREST `.order()` ด้วย expression ที่คำนวณไม่ได้) แล้วแก้ด้วยการดึง candidate window มา sort ฝั่ง client — รอบนี้แก้ปัญหาเดิมให้ถูกจุดกว่าด้วยการย้าย ranking ไปเป็น SQL function จริงฝั่ง backend (`language sql` ธรรมดา ไม่ใช่ PostgREST query builder) ตรงตาม requirement "Backend ต้องคำนวณ ranking score":

1. **Wynos Score (Backend)** — สร้างตาราง `feed_ranking_config` (key/weight, seed ค่าเริ่มต้นตามสเปค: personalized_interest 0.35, following 0.25, engagement 0.15, trending 0.10, recency 0.10, discovery 0.05) เพื่อให้ปรับน้ำหนักจากข้อมูลจริงได้ในอนาคตโดยไม่ต้องแก้โค้ด — ไม่มี UPDATE policy ให้ client แก้เอง (ต้องผ่าน DB migration/admin เท่านั้นใน V1.0)
2. **`get_wynos_ranked_feed()` RPC ใหม่** — SQL function หลายชั้น CTE คำนวณ:
   - **Personalized Interest**: สะสมจาก Like/Comment/Save/View/Profile Visit ต่อ author ใน 30 วันล่าสุด (ถ่วงน้ำหนักต่าง action ต่างกัน) แล้ว normalize ด้วย `percent_rank()` (ทนต่อ outlier/โพสต์ไวรัลกว่า min-max)
   - **Following/Relationship**: เช็ค `follows` ตรง ๆ
   - **Engagement**: Like/Comment/Save/View รวม แล้ว `percent_rank()`
   - **Trending**: ใช้ **velocity** (engagement ÷ อายุโพสต์เป็นชั่วโมง) ไม่ใช่ raw count ตามสเปค (โพสต์ 500 like ใน 30 นาที ต้องชนะ 2000 like ใน 3 วัน) แล้ว `percent_rank()`
   - **Recency**: time-decay เชิงเส้นใน 7 วัน (168 ชม.)
   - **Discovery**: ผู้เขียนที่ยังไม่เคย follow และไม่เคยมี interaction เลย
   - รวมคะแนนด้วยน้ำหนักจาก `feed_ranking_config` (มี `coalesce(...,default)` fallback ต่อ key กันกรณี config ว่าง/ถูกลบ)
   - กรอง Hide/block ออกตั้งแต่ CTE แรก (`feed_signals` + `authors_posting_blocked()` เดิมจาก WYN-041)
   - คืนค่าด้วย `to_jsonb(row.*)` ทั้งแถว — ทำให้ `HomeFeedItem.fromMap` ฝั่ง client **ไม่ต้องแก้เลย** (จุดตัดสินใจสำคัญ: ลดความเสี่ยงกระทบ 25+ call site เดิม)
3. **User Signal ใหม่** — ตาราง `feed_signals` (signal_type: profile_visit / hide / not_interested) RLS ธรรมดา (insert เฉพาะแถวตัวเอง — ไม่มีความเสี่ยง gaming แบบ `drop_views` เดิมที่ต้องบังคับผ่าน RPC เท่านั้น) ผูกกับ:
   - `HomeRepository.hideContent()` — เรียกตอนกด "ไม่สนใจโพสต์นี้" ใน more-menu ของ `HomeDropCard`/`HomePopCard` แล้ว optimistic-remove ออกจาก feed ทันที (revert ถ้า RPC fail)
   - `ViewProfileScreen._recordProfileVisit()` — บันทึกตอนเปิดโปรไฟล์คนอื่น (ไม่บันทึกโปรไฟล์ตัวเอง)
   - View Duration / Skip-Scroll-Past / Share velocity: **ไม่ implement ในรอบนี้** (ตัดสินใจแล้วว่าเป็นการลดความซับซ้อนที่เหมาะกับ V1.0 Beta ตามสเปคที่บอกห้าม over-engineer — ใช้ View แบบ binary จาก `drop_views` เดิมแทน ดูรายละเอียดใน Known Issues)
4. **Feed Diversity (`feed_diversity.dart` ใหม่)** — pure function ฝั่ง client รับ candidate ที่จัดอันดับมาจาก backend แล้วจัดเรียงใหม่แบบ diversity-aware (ไม่แก้คะแนน แค่สลับตำแหน่ง): ห้าม author เดียวกันติดกันเกิน 2 โพสต์รวด, แทรก Discovery content อย่างน้อยทุก 5 slot ถ้ามีให้แทรก — ออกแบบตามแพทเทิร์นเดียวกับ `home_ranking.dart` เดิม (pure, unit-testable, ไม่พึ่ง DB call)
5. **Post-Create Refresh / Pagination / Duplicate Prevention** — ตรวจสอบแล้วว่า `HomeFeedScreen`/`RootShell` เดิม (cursor-based page fetch, `_homeVersion` bump remount, id-based dedup) ทำงานถูกต้องตาม requirement อยู่แล้วจาก WYN-018/WYN-062 **ไม่ต้องแก้โค้ดเพิ่ม** — แค่เปลี่ยน data source ที่ `fetchRankedFeed()` เรียกจาก candidate-window-then-client-sort (เดิม) เป็นเรียก RPC ใหม่แล้วรัน diversity pass เพิ่มก่อน map เป็น `HomeFeedItem`

## Files Changed

**App (lib)**: `features/home/data/home_repository.dart` (`fetchRankedFeed()` เปลี่ยนไปเรียก `get_wynos_ranked_feed()` RPC + รัน `applyFeedDiversity()`, เพิ่ม `hideContent()`/`recordProfileVisit()`, ลบ `_fetchFollowedAuthorIds` ที่กลายเป็น dead code), `features/home/data/feed_diversity.dart` (ใหม่), `features/home/presentation/home_feed_screen.dart` (`_hideItem()` + optimistic remove/revert), `features/home/presentation/widgets/{home_drop_card,home_pop_card}.dart` (`onHide` param + "ไม่สนใจโพสต์นี้" ใน more-menu), `features/profile/presentation/view_profile_screen.dart` (`_recordProfileVisit()`)

**Supabase**: `schema.sql` (เพิ่ม section "WYNOS Unified Home Feed Algorithm V1.0": `feed_ranking_config`, `feed_signals`, `content_save_count()`, `get_wynos_ranked_feed()`), `tests/wyn_063_unified_home_feed_test.sh` (ใหม่ — regression script ถาวร มิเรอร์ `wyn_041_trending_engine_test.sh`)

**Tests**: `test/feed_diversity_test.dart` (ใหม่ — 11 test), `test/home_feed_screen_test.dart` (เพิ่ม group Hide — 3 test), `test/view_profile_screen_test.dart` (เพิ่ม group Profile Visit signal — 2 test), `test/support/recording_home_repository.dart` (เพิ่ม override `hideContent`/`recordProfileVisit`)

## Reason

ตาม Founder spec ตรง ๆ — สถาปัตยกรรมยึดหลัก "backend ทำ ranking หนัก, client ทำแค่ diversity pass เบา ๆ" ตามที่สเปคระบุ diagram ชัดเจน (Client→Request / Backend→Candidates→Score→Diversity→Return / Client→Render) น้ำหนักคะแนนเก็บใน DB table แทนฮาร์ดโค้ดในโค้ด Dart หรือ SQL literal เพื่อให้ปรับได้จากข้อมูลจริงในอนาคตตามที่สเปคบังคับห้ามฮาร์ดโค้ดถาวร ใช้ `percent_rank()` แทน min-max normalization เพราะทนทานต่อโพสต์ไวรัล (ค่า outlier ไม่ทำให้ทุกคะแนนอื่นบีบตัวลงเป็นศูนย์เหมือน min-max) โครงสร้าง SQL function เป็น `language sql` ธรรมดา (ไม่ใช่ black-box ML) — future AI Recommendation เพิ่มได้ในภายหลังโดยเพิ่ม CTE ใหม่หรือ column คะแนนใหม่ใน `feed_ranking_config` โดยไม่ต้องรื้อ query เดิม ตรงตาม "ไม่ต้อง rewrite ทั้งระบบ" ที่สเปคระบุ

## Tests

`flutter test` เต็ม suite: **759/759 ผ่าน** (baseline ก่อนแก้ 743/743 จาก WYN-062 — เพิ่ม 16 test case ใหม่: 11 feed_diversity + 3 home_feed hide + 2 profile visit)

SQL ranking function ยืนยันจริงด้วย local PostgreSQL 16 (ไม่ใช่แค่โค้ดที่ "น่าจะถูก" — รันจริงกับฐานข้อมูลจริง): `supabase/tests/wyn_063_unified_home_feed_test.sh` — **10/10 checks ผ่าน** ครอบคลุม hide exclusion, following flag, discovery flag, personalized-interest ทำให้ followed-author ชนะ stranger, score ไม่ null/ไม่ติดลบเสมอ, `content_save_count()` คืนยอดรวมจริงข้าม RLS, `feed_signals` RLS แยกข้อมูลผู้ใช้ถูกต้อง, candidate set ว่าง (ผู้ใช้ใหม่ไม่มี Drop เลย) ไม่ error, `feed_ranking_config` ถูกลบทั้งหมดยัง fallback ได้ไม่ null

## Build

`flutter analyze`: **No issues found**

---

## QA & Security Review

Feature: WYNOS Unified Home Feed Algorithm V1.0 (Wynos Score ranking, User Signal, Feed Diversity, Post-Create Refresh, Pagination, Performance architecture)
Environment: Flutter 3.47.1 + local PostgreSQL 16 (ติดตั้ง/ใช้จริงในเซสชันนี้เพื่อรัน SQL ranking function กับฐานข้อมูลจริง ไม่ใช่แค่ตรวจ syntax) — ไม่มี emulator/device จริงสำหรับ manual UI testing

Test Cases:
- โหลด `schema.sql` เต็มไฟล์กับ Postgres 16 จริง ยืนยันไม่มี syntax error / dependency order ผิด
- สร้าง regression script ถาวร (`wyn_063_unified_home_feed_test.sh`) จำลอง 3 ผู้ใช้ (me/followed/stranger) + hide signal + like + save ยืนยัน ranking, RLS, discovery/following flag ถูกต้องจริงภายใต้ role `authenticated` (ไม่ใช่ superuser ที่ bypass RLS)
- ทดสอบ edge case แยก: candidate set ว่าง (ผู้ใช้ใหม่ไม่มี Drop เลย ระบบทั้งหมด), `feed_ranking_config` ถูกลบทั้งตาราง, `drops_has_content`/`edit_drop()` guard เดิมจาก WYN-062 ยังทำงานถูกต้องหลังแก้ schema เพิ่ม (ไม่มี regression)
- รัน `flutter analyze` + `flutter test` เต็ม suite ซ้ำหลังแก้ไขทุกจุด
- ไล่ตรวจ diff แบบ adversarial หาทางทำให้ diversity algorithm ปล่อย author เดิมติดกันเกิน 2 หรือทำโพสต์หาย/ซ้ำ

Passed:
- `get_wynos_ranked_feed()` กรอง Hide ถูกต้อง, ให้คะแนน Personalized+Following สูงกว่าจริงสำหรับ author ที่ follow+like เทียบกับ stranger, discovery flag ถูกต้องเฉพาะ author ที่ไม่เคย interact เลย, score ไม่มีทาง null/ติดลบ
- `content_save_count()` คืนยอดรวมจริงข้ามทุกผู้ใช้ (bypass RLS ของ `saves` ตามที่ตั้งใจ เพราะเป็นแค่ตัวนับสาธารณะ ไม่ใช่ query ข้อมูลส่วนตัว)
- `feed_signals` RLS แยกข้อมูลผู้ใช้แต่ละคนถูกต้อง (เห็นเฉพาะแถวตัวเอง)
- `applyFeedDiversity()`: ไม่ทำโพสต์หายหรือซ้ำในทุก edge case (รวมกรณี author เดียวครองเกือบทั้ง candidate set — ไม่มี alternate เพียงพอ), บังคับ author ติดกันไม่เกิน 2 ได้จริงเมื่อมี alternate เพียงพอ, แทรก Discovery ตามช่วงที่กำหนดเมื่อมีให้แทรก
- Hide flow: กด "ไม่สนใจโพสต์นี้" ลบออกจาก feed ทันที (optimistic), ถ้า RPC fail คืนกลับที่เดิมพร้อม error แจ้งผู้ใช้ — ทดสอบทั้ง Drop และ Pop card
- Profile Visit signal: บันทึกเฉพาะตอนดูโปรไฟล์คนอื่น ไม่บันทึกโปรไฟล์ตัวเอง, ไม่ crash แม้ไม่ได้ inject `homeRepository` ใน test (สืบเนื่องจาก try/catch ครอบการเข้าถึง Supabase lazy fallback ตามแพทเทิร์นที่ปลอดภัยที่ยืนยันแล้ว ต่างจากบั๊กเดิมใน WYN-062 ที่เข้าถึงแบบ bare ใน `build()`)
- Edge cases: candidate set ว่างไม่ error, `feed_ranking_config` ว่างทั้งตารางยัง fallback ได้ค่า default ไม่ null, WYN-062's `drops_has_content`/`edit_drop()` guard ยังทำงานถูกต้อง (ไม่มี regression)

Failed: ไม่มีรายการ FAIL ค้างอยู่ (บั๊กที่พบระหว่างพัฒนา เช่น diversity algorithm ตัวแรกบล็อก author ที่ไม่ติดกันจริงผิดพลาด, `SET LOCAL` ใช้นอก transaction ทำให้ `auth.uid()` เป็น NULL ระหว่างทดสอบ SQL, harness stub ขาด grant บน schema `auth` ให้ role `authenticated` — ถูกแก้ก่อนเขียนเป็น regression script ถาวร ไม่ใช่บั๊กที่หลงเหลือในโค้ดที่ commit)

Severity: N/A (ไม่มีรายการ FAIL ค้างอยู่)

Security Findings:
- ไม่พบ secret/credential หลุดใน diff นี้
- `feed_signals` INSERT policy บังคับ `auth.uid() = user_id` — ผู้ใช้ยิง signal แทนคนอื่นไม่ได้
- `get_wynos_ranked_feed()`/`content_save_count()` เป็น invoker-rights (`language sql` ธรรมดา ไม่ใช่ `SECURITY DEFINER`) — ยืนยันแล้วว่า role `authenticated` ต้องมี grant บน `auth.uid()`/`auth.role()`/`auth.users` โดยตรงจึงจะเรียกได้ (ต่างจาก `authors_posting_blocked()` เดิมที่เป็น `SECURITY DEFINER`) — grant เหล่านี้เป็นของแพลตฟอร์ม Supabase อยู่แล้วในทุก production instance ไม่ต้องเพิ่มอะไรตอน deploy จริง (ที่ต้องเพิ่มเองคือใน harness ทดสอบเท่านั้น)
- `feed_ranking_config` ไม่มี INSERT/UPDATE/DELETE policy ให้ client เลย (เจตนา — ป้องกันผู้ใช้ปรับน้ำหนัก ranking เอง) การปรับน้ำหนักในอนาคตต้องผ่าน migration/admin tool เท่านั้น
- `get_wynos_ranked_feed()` ยังไม่ได้ validate กับข้อมูลจริงระดับ production scale (ทดสอบด้วย candidate window จำกัด 200 แถวล่าสุดเท่านั้น) — ต้องให้ AI Deploy & DevOps ตรวจ query plan/performance กับ data volume จริงก่อน deploy

Recommendation:
- ก่อน deploy จริง ให้ AI Deploy & DevOps รัน `EXPLAIN ANALYZE` กับ `get_wynos_ranked_feed()` บน staging ที่มีข้อมูลใกล้เคียง production เพื่อยืนยัน `percent_rank()` window function ไม่ช้าเกินไปเมื่อ candidate window โต (ปัจจุบัน hardcode 200 แถวล่าสุดใน `recent` CTE เป็นการจำกัดขอบเขตคำนวณตามที่สเปคเตือนเรื่อง performance)
- View Duration, Skip/Scroll-Past, Share velocity เป็น signal ที่สเปคระบุแต่ตัดสินใจไม่ implement ในรอบนี้ (V1.0 Beta ตามที่สเปคขอไม่ให้ over-engineer) — เป็นงานแยกในอนาคตที่ต้องมี Product กำหนด schema/threshold ก่อน (เช่น "ดูนานแค่ไหนถึงนับเป็น engaged")
- แนะนำให้ Founder ทดสอบ diversity/ranking จริงบนมือถือด้วยข้อมูลผู้ใช้จริงเพื่อ tune น้ำหนักใน `feed_ranking_config` ตามพฤติกรรมจริง (ตามที่สเปคออกแบบไว้ให้ปรับได้)

Final Status: **PASS**

## Handoff

ส่งต่อ AI Deploy & DevOps (`/deploy`) — เมื่อมี production infra จริง ให้ตรวจ query performance ของ `get_wynos_ranked_feed()` กับข้อมูลจริงก่อนตาม Recommendation ด้านบน แล้วจึง deploy
