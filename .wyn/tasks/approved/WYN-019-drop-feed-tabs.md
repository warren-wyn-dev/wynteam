# Product Task — WYN-019

Status: QA รอบ 1 (อิสระ) — PASS, 2026-08-17
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (independent — PASS)

## Independent QA — Round 1 (AI QA & Security, 2026-08-17)

**หมายเหตุ**: "PASS" เดิมด้านล่าง (`## Coding + QA Output`) เป็น self-verified โดย session เดียวกับที่เขียนโค้ดเท่านั้น ไม่ใช่ QA อิสระ — รอบนี้คือ QA อิสระรอบแรกที่แท้จริง

```
Feature: Drop Feed Redesign — social feed list + For You/Following/Latest tabs
Environment: Re-synced ไป origin/main tip (commit 8d338cb) ก่อนเริ่ม, Flutter 3.47.0 / Dart 3.13.0, PostgreSQL 16.13 local (harness เดียวกับที่ใช้ตรวจ WYN-021/WYN-022) — ยืนยัน `drops.location` (R6) โหลดสำเร็จผ่าน schema.sql
Test Cases:
1. `flutter analyze` อิสระ — clean
2. `flutter test` อิสระทั้ง suite ที่ HEAD ปัจจุบัน — 362/362 ผ่าน (ครอบคลุม 8 test ของ task นี้ + 2 test เพิ่มจาก follow-up ranking ของ PR #124)
3. Postgres: `\d public.drops` ยืนยันคอลัมน์ `location` (nullable text) มีอยู่จริงตาม R6 — ไม่มี UI อ่าน/เขียนคอลัมน์นี้ (grep `.location` ใน `app/lib/features/drop/` ไม่พบการใช้งานนอก schema)
4. อ่านโค้ด `DropRepository.fetchFollowingFeed` — 2-step fetch (follows → drops filtered by author_id in(...)), short-circuit เป็น `[]` เมื่อไม่ follow ใครเลย (ไม่ส่ง query ด้วย empty inFilter ที่อาจพฤติกรรมไม่แน่นอน) — ยืนยันพึ่ง RLS ของ `drops`/`follows` เดิมล้วนๆ ไม่มี query bypass
5. อ่านโค้ด `DropFeedScreen`'s `_DropTabFeed` — แต่ละ tab มี pagination/scroll/like/save state อิสระผ่าน `AutomaticKeepAliveClientMixin` (ป้องกัน refetch/lose-position เวลาสลับ tab) ยืนยัน R7's grid-not-deleted (`DropGridTile` ยังถูก `ProfileDropGridTab` ใช้อยู่ — grep ยืนยัน)
6. ยืนยัน `HomeDropCard` reuse ตรงๆ (R1) — ไม่มีการสร้างการ์ดใหม่ซ้ำซ้อน, `HomeFeedItem.fromDrop()` factory ใหม่เป็น bridge เดียว
7. ไล่ Acceptance Criteria ทั้ง 6 ข้อเทียบกับ Requirements R1–R7 และ Design doc (`wyn-019-drop-feed-tabs.md`) — ครบทุกข้อ รวม R7's "เก็บ grid ไว้แต่ไม่ใช่ default" decision
8. Regression: ยืนยัน `CreateDropScreen`/`DropDetailScreen`/`ProfileDropGridTab` (WYN-005/013) ไม่ถูกแตะ ตามที่ Coding อ้าง
Passed: 8/8
Failed: 0/8
Severity: N/A
Reproduction Steps: N/A (ไม่พบบั๊ก)
Expected: N/A
Actual: N/A
Security Findings: ไม่มี RLS ใหม่ในงานนี้ (`location` เป็น schema-only column เดิม ไม่มี policy เปลี่ยน) — ไม่พบช่องโหว่
Recommendation: ไม่มีข้อเสนอเพิ่มเติม — follow-up ที่ WYN-018 ระบุไว้ ("For You" ใช้ ranking formula เดียวกับ Home) ถูกทำเสร็จแล้วจริงตามที่ DECISIONS.md (2026-08-17, "Merge PR #124...") บันทึกไว้ — ตรวจสอบโค้ด `DropFeedScreen`'s For You tab เรียก `fetchRankedFeed` แล้วยืนยันตรง
Final Status: PASS
```

---

## Coding + QA Output (เดิม — self-verified เท่านั้น ไม่ใช่ QA อิสระ)

## Coding + QA Output

- R7 resolved: Drop tab's default view is now the feed (TabBar: For You/Following/Latest, default For You); the 3-column grid is not deleted — `DropGridTile` keeps rendering `ProfileDropGridTab` (WYN-013) unchanged, only stopped being this tab's own layout. See the Design doc's reasoning.
- `HomeFeedItem.fromDrop(Drop)` new factory (mirrors the existing reverse `toDrop()`) bridges `Drop` into `HomeDropCard` (WYN-007) so the feed card is reused verbatim — no new card widget.
- `DropRepository.fetchFollowingFeed(page)`: two-step fetch (followed-user-ids from `follows`, then `drops` filtered by `inFilter('author_id', ...)`), short-circuits to `[]` when the user follows nobody rather than sending a query with an empty `inFilter`.
- `drops.location` (nullable text, schema-only) added and verified against real local Postgres 16 end-to-end (`schema.sql` loads clean with `ON_ERROR_STOP=1`, column confirmed via `\d public.drops`) — no UI reads/writes it yet, per R6.
- Each tab (`_DropTabFeed`) owns independent pagination/scroll/like/save state with `AutomaticKeepAliveClientMixin` so switching tabs doesn't refetch or lose position — same reasoning `SearchScreen`'s independent per-tab pagination already established. Creating a new Drop bumps a `_feedVersion` key that remounts all 3 tabs (mirrors `RootShell`'s existing "bump a key to force reload" pattern for its Profile tab) so a fresh post shows up immediately.
- New `test/drop_feed_screen_test.dart` (8 tests) — this screen had **zero** prior test coverage (confirmed via search before starting; `RootShell`, which wires it up, also has none), so this closes a pre-existing gap, not just covers the new work: default tab, tab switching + per-tab data isolation, Following's distinct empty-state message vs. the generic one, tap → `DropDetailScreen`, double-tap Like safety, keep-alive across tab switches. Hit the session's own "never construct a Recording*Repository inline inside `testWidgets`" anti-pattern twice while writing these (Timer leak) — fixed by moving both into `setUp()`.
- `flutter analyze`: clean (app-wide). `flutter test`: 306/306 (was 298/298 before this task — 8 added, 0 regressed).

Acceptance Criteria:
- [x] Drop tab default เปิดที่ For You, แสดง feed แบบ scroll การ์ดเดียวต่อโพสต์ (ไม่ใช่ grid)
- [x] สลับ Following/Latest tab ได้ ข้อมูลถูกต้องตาม tab (Following = เฉพาะคนที่ follow, Latest = ทุกคนเรียงเวลา)
- [x] การ์ดใน Drop feed มี Like/Comment/Share/Save/แตะ profile ครบเหมือนใน Home (reuses `HomeDropCard` verbatim, so identical by construction)
- [x] แตะการ์ดเปิด `DropDetailScreen` เดิม (ไม่เปลี่ยนพฤติกรรมนี้)
- [x] `drops` table มีคอลัมน์ location (nullable) แต่ไม่มี UI ให้กรอก/แสดงรอบนี้
- [x] `flutter test` ผ่านครบ ไม่มี regression กับ WYN-005/WYN-007/WYN-013

Feature: Drop Feed Redesign — social feed list (ไม่ใช่ grid) + For You/Following/Latest tabs

Goal: ทำให้ Drop tab เป็น "Social Photo Feed" ตัวจริงตามที่ Founder ระบุใน spec ข้อ 2 และ 6 — หน้า scroll แบบ social media (รูป+Caption+Username+เวลา+Like/Comment/Share ครบในการ์ดเดียว) พร้อม 3 tabs (For You/Following/Latest, default For You) แทนที่ 3-column grid ปัจจุบัน

Target User: ผู้ใช้ WYN Social ที่อยากดูโพสต์ของคนอื่นแบบ browse ต่อเนื่อง (scroll feed) ไม่ใช่แค่ดู thumbnail grid

Problem: Drop tab ปัจจุบัน (WYN-005) เป็น **3-column grid** ของทุก Drop ทั้งระบบเรียงตามเวลา — ต้องแตะเข้า detail ทีละอันถึงจะเห็น caption/like/comment ครบ ไม่ใช่ scroll feed ที่เห็นทุกอย่างพร้อมกันแบบที่ Home's `HomeDropCard` แสดงอยู่แล้ว และไม่มี tab แยก For You/Following/Latest เลย — Founder ระบุชัดว่า "ห้ามนำ Drop Feed ไปแทน Home" ดังนั้นทั้งสองหน้าต้องคง distinct purpose ไว้ (Home = ทุกอย่างของ WYN ผสมกัน, Drop = เฉพาะรูป+Caption+Social)

Requirements:

R1. เปลี่ยน Drop tab จาก grid เป็น scrollable single-column list โดย **reuse `HomeDropCard` (WYN-007) ตรงๆ** ไม่สร้างการ์ดใหม่ซ้ำซ้อน (มีทุก element ที่ spec ต้องการอยู่แล้ว: รูป/caption/username/avatar/เวลา/like/comment/share/save/จำนวน)
R2. เพิ่ม TabBar 3 tab เหนือ feed: For You (default) / Following / Latest — reuse tab-bar pattern ที่มีอยู่แล้วใน `ViewProfileScreen` (WYN-013, Drop grid/Pop list/Saved tabs) และ `SearchScreen` (WYN-009, User/Drop/Pop/Club tabs)
R3. "Following" tab ต้องการ query ใหม่ใน `DropRepository` (fetch เฉพาะ Drop จากคนที่ follow อยู่ — reuse `follows` table ของ WYN-008 join เข้า `drops`) — Drop repository ยังไม่มี method นี้
R4. "For You" tab รอบแรกใช้ chronological เหมือนเดิมไปก่อน (ไม่ผูกกับ WYN-018's ranking algorithm ที่ยังไม่เริ่ม) — ปรับมาใช้ ranking formula เดียวกันภายหลังเมื่อ WYN-018 เสร็จ เพื่อความสม่ำเสมอของคำว่า "For You" ทั้งแอป
R5. "Latest" tab = chronological ล้วนๆ (เหมือน grid เดิมทุกวันนี้ แค่เปลี่ยน layout)
R6. เตรียมโครงสร้าง Location field ใน `drops` table (nullable, ไม่บังคับกรอก, ไม่แสดงผล UI รอบนี้) ตามที่ spec ข้อ 2 ระบุ "เตรียมโครงสร้างไว้สำหรับอนาคต" — schema-only, ความเสี่ยงต่ำ
R7. **คง 3-column grid เดิมไว้หรือไม่**: เสนอถามให้ Founder ตัดสินใจ — เก็บ grid ไว้เป็น sub-view (เช่นใน Profile ตัวเองอยู่แล้วผ่าน `ProfileDropGridTab`) แต่ไม่ใช่ default view ของ Drop tab อีกต่อไป หรือจะตัด grid view ออกจาก Drop tab ไปเลย (Profile ยังมี grid อยู่ดี ไม่หายไปจากระบบ)

Acceptance Criteria:
- [ ] Drop tab default เปิดที่ For You, แสดง feed แบบ scroll การ์ดเดียวต่อโพสต์ (ไม่ใช่ grid)
- [ ] สลับ Following/Latest tab ได้ ข้อมูลถูกต้องตาม tab (Following = เฉพาะคนที่ follow, Latest = ทุกคนเรียงเวลา)
- [ ] การ์ดใน Drop feed มี Like/Comment/Share/Save/แตะ profile ครบเหมือนใน Home
- [ ] แตะการ์ดเปิด `DropDetailScreen` เดิม (ไม่เปลี่ยนพฤติกรรมนี้)
- [ ] `drops` table มีคอลัมน์ location (nullable) แต่ไม่มี UI ให้กรอก/แสดงรอบนี้
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับ WYN-005/WYN-007/WYN-013

Dependencies: ไม่มี hard dependency — ทำคู่ขนานกับ WYN-017/WYN-018 ได้ (แตะคนละไฟล์เป็นหลัก ยกเว้น `HomeDropCard` ที่ทั้งสองงานจะ reuse ร่วมกัน แนะนำไม่แก้ signature ของ widget นี้พร้อมกันสองงาน)

Priority: สูง (ตรงกับ spec ข้อ 2 และ 6 โดยตรง เป็นหัวใจของคำร้องขอครั้งนี้ — Founder เน้นย้ำว่า "Drop ไม่ใช่แค่หน้าสำหรับสร้างโพสต์")

Risks: การเปลี่ยน default view ของ Drop tab จาก grid เป็น feed เป็น UX change ที่ผู้ใช้เดิม (ถ้ามี) จะสังเกตเห็นทันที — ควรยืนยันกับ Founder ว่าต้องการแทนที่ grid หรือเสริมเป็นอีก view (ดู R7)

Recommendation: เริ่มพร้อมกับ WYN-017 ได้เลย (ความเสี่ยงต่ำ-กลาง คุณค่าสูง ไม่ต้องรอ WYN-018) — ส่วน R7 (จะเก็บ grid ไว้ไหม) ควรถาม Founder ก่อนเริ่ม Design

Handoff: AI Design ตัดสินใจ R7 (เก็บ/ตัด grid) ร่วมกับ Founder ก่อน แล้วออกแบบ TabBar + reuse `HomeDropCard` ให้ชัดเจน ก่อนส่งต่อ AI Coding
