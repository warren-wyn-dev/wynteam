# Product Task — WYN-017

Status: QA รอบ 1 (อิสระ) — PASS, 2026-08-17
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (independent — PASS)

## Independent QA — Round 1 (AI QA & Security, 2026-08-17)

**หมายเหตุ**: "PASS" เดิมด้านล่าง (`## Coding + QA Output`) เป็น self-verified โดย session เดียวกับที่เขียนโค้ดเท่านั้น ไม่ใช่ QA อิสระ — รอบนี้คือ QA อิสระรอบแรกที่แท้จริง (ตรวจพร้อมกับ WYN-018 ถึง WYN-022 อีก 5 task ในชุดเดียวกัน)

```
Feature: Home — Trending Content + Recommended/Popular Clubs section
Environment: Re-synced ไป origin/main tip (commit 8d338cb) ก่อนเริ่ม, Flutter 3.47.0 / Dart 3.13.0, ไม่มี schema change ใน task นี้ (R4) จึงไม่ต้อง verify Postgres เพิ่ม
Test Cases:
1. `flutter analyze` อิสระ — clean, ตรงกับที่ Coding รายงาน
2. `flutter test` อิสระทั้ง suite ที่ HEAD ปัจจุบัน — 362/362 ผ่าน (ครอบคลุม 7 test ของ task นี้)
3. อ่านโค้ด `HomeRepository.fetchTrending()` ยืนยัน bounded 48h window + candidate-then-sort-client-side (เหตุผลเดียวกับ `fetchPopularClubs`/PostgREST ไม่ order by computed expression ได้) และยืนยันไม่แก้ `home_feed` view (R4) — grep schema.sql ยืนยันไม่มี `WYN-017` section ใน schema.sql เลย ตรงตามที่อ้าง
4. อ่านโค้ด `ClubSection`'s "Club แนะนำ" threshold (< 3 joined clubs) — reuse `ClubRepository.fetchPopularClubs` ตรงๆ ไม่ query ซ้ำ
5. ไล่ Acceptance Criteria ทั้ง 5 ข้อเทียบกับ Requirements R1–R4 และ Design doc (`wyn-017-home-trending-recommended-clubs.md`) — ครบทุกข้อ
6. Regression: ยืนยัน chronological feed หลัก (WYN-007) และ ClubSection เดิม (Club ของฉัน, WYN-014/015) ไม่ถูกแตะ — Loading/Empty/Error state ของทั้งสอง section ใหม่แยกจาก feed หลัก (fail-safe FutureBuilder pattern เดียวกับ ClubSection เดิม)
Passed: 6/6
Failed: 0/6
Severity: N/A
Reproduction Steps: N/A (ไม่พบบั๊ก)
Expected: N/A
Actual: N/A
Security Findings: ไม่มีตาราง/RLS ใหม่ในงานนี้ (additive query เท่านั้นตาม R4) — ไม่พบช่องโหว่
Recommendation: ไม่มีข้อเสนอเพิ่มเติมนอกจากที่ Coding บันทึกไว้แล้ว (Trending window 48h อาจต้องปรับ threshold ในอนาคตตาม feedback จริง — ไม่ block)
Final Status: PASS
```

---

## Coding + QA Output (เดิม — self-verified เท่านั้น ไม่ใช่ QA อิสระ)

## Coding + QA Output

- `HomeRepository.fetchTrending()`: last-48h `home_feed` rows (bounded candidate fetch, capped at 100), ranked client-side by `like_count + comment_count` (mirrors `ClubRepository.fetchPopularClubs`'s fetch-then-sort precedent — PostgREST can't `order()` by a computed expression). `home_feed` view itself untouched (R4).
- New `TrendingTile` widget (square thumbnail + like-count scrim, handles both Drop/Pop via `HomeFeedItem` since no existing tile is content-type agnostic) — new "กำลังนิยม" row in `HomeFeedScreen` between `ClubSection` and the feed-mode toggle, own Loading/Empty/Error state (fail-safe `FutureBuilder`, same pattern as `ClubSection`'s club row — a failed fetch never blocks the main feed).
- `ClubSection` gained a "Club แนะนำ" row (reuses `ClubRepository.fetchPopularClubs`, `ClubMiniCard` verbatim) shown only when the user has joined fewer than 3 Clubs. Replaced the old `ConstrainedBox(maxHeight: 180)` + `Expanded` layout with fixed-height `SizedBox` rows per Design's reasoning (avoids the same overflow failure mode already hit once in WYN-015's `ViewProfileScreen`) — verified the "Club ของฉัน" row's rendered size is unchanged (108px, same budget the old 180px ceiling implicitly gave it).
- 7 new tests added (`home_feed_screen_test.dart`): Trending row shows header+items, empty state, Drop tap → `DropDetailScreen`, Pop tap → `PopSingleClipScreen`; Recommended Clubs row shows under threshold, hides at/above threshold, tap → `ClubPage`. Hit the session's own documented "never construct a Recording*Repository inline inside `testWidgets`" anti-pattern once while writing these (leaked GoTrue `Timer.periodic`) — fixed by moving all new fakes into `setUpAll`, matching the file's existing pattern.
- `flutter analyze`: clean. `flutter test`: 298/298 (was 291/291 before this task — 7 added, 0 regressed).

Acceptance Criteria:
- [x] Home มีแถว Trending แสดง Drop/Pop ที่ engagement สูงในช่วง 48 ชม.ล่าสุด ไม่ว่างเปล่าเมื่อมี content
- [x] ClubSection มีแถว Club แนะนำ ใช้ query เดียวกับ "กำลังนิยม" ของ ExploreClubsScreen
- [x] แถวใหม่ทั้งสองมี Loading/Empty/Error state ครบ ไม่ crash เมื่อไม่มีข้อมูล
- [x] Feed หลัก (chronological) และ ClubSection เดิม (Club ของฉัน) ทำงานเหมือนเดิมทุกจุด ไม่มี regression (`flutter test` ผ่านครบ)
- [x] ไม่มีตาราง/schema ใหม่ (ใช้ query เพิ่มจาก `drops`/`pops`/`clubs` เดิม)


Feature: Home — Trending Content + Recommended/Popular Clubs section

Goal: เติมเต็มช่องว่าง 2 จุดที่ Founder ระบุไว้ใน "WYN — Feed & Club Update" brief (2026-08-16) ที่ Home ยังไม่มี: (1) ไม่มี Trending Content โผล่ใน Home เลย (2) ClubSection ใน Home โชว์แค่ "Club ของฉัน" ไม่มี Recommended/Popular Clubs ให้ค้นพบ community ใหม่ — ทั้งสองจุดนี้ทำแบบ additive ล้วนๆ (เพิ่ม section ใหม่) ไม่แตะ feed หลักหรือ ranking logic เดิม จึงเสี่ยงน้อยและให้คุณค่าเร็ว

Target User: ผู้ใช้ WYN Social ทุกคน โดยเฉพาะผู้ใช้ใหม่ที่ยังไม่ได้ follow/join อะไรเลย (Trending/Popular คือทางค้นพบ content หลักของกลุ่มนี้)

Problem: Home ปัจจุบัน (WYN-007) เป็น chronological feed ของ Drop+Pop ล้วนๆ ไม่มีสัญญาณอะไรช่วยผู้ใช้ค้นพบ content ที่กำลังนิยม และ ClubSection (WYN-014) โชว์แค่ Club ที่ join แล้ว — ผู้ใช้ใหม่ที่ยังไม่ join Club ไหนเลยจะไม่เห็น Club อะไรใน Home เลย ทั้งที่ ExploreClubsScreen (WYN-015) มี query "กำลังนิยม"/"ใหม่ล่าสุด" อยู่แล้วแค่ไม่ได้ surface เข้า Home

Requirements:

R1. เพิ่มส่วน "Trending" ใน Home feed — นิยาม Trending = engagement (like+comment) สูงในช่วงเวลาสั้น (เสนอ 48 ชม.) ไม่ใช่ยอดสะสมตลอดกาล เพื่อไม่ให้ post เก่าครองอันดับถาวร แสดงเป็น horizontal card row แทรกเหนือ feed หลัก (ไม่ผสมเข้า chronological list เดิม — กัน regression กับ WYN-007's ordering ที่ QA ผ่านแล้ว)
R2. ขยาย `ClubSection` (WYN-014) ให้มีแถว "Club แนะนำ" ต่อจากแถว Club ของฉัน เมื่อ Club ของฉันมีน้อย (หรือว่าง) — reuse query เดียวกับ ExploreClubsScreen's "กำลังนิยม" (`ClubRepository`) และ reuse `ClubMiniCard` เดิมตรงๆ ไม่สร้าง widget ใหม่
R3. ทั้งสอง section ต้องมี Loading/Empty/Error state ของตัวเอง แยกจาก feed หลัก — ถ้า Trending/Recommended โหลดพลาด ต้องไม่บล็อก feed หลักที่โหลดสำเร็จ (fail-safe เหมือนที่ ClubSection ทำอยู่แล้ว)
R4. ไม่แก้ `home_feed` view เดิม ไม่แก้ ranking/ordering ของ feed หลัก (นั่นคือ WYN-018) — งานนี้เป็นแค่ additive section

Acceptance Criteria:
- [ ] Home มีแถว Trending แสดง Drop/Pop ที่ engagement สูงในช่วง 48 ชม.ล่าสุด ไม่ว่างเปล่าเมื่อมี content
- [ ] ClubSection มีแถว Club แนะนำ ใช้ query เดียวกับ "กำลังนิยม" ของ ExploreClubsScreen
- [ ] แถวใหม่ทั้งสองมี Loading/Empty/Error state ครบ ไม่ crash เมื่อไม่มีข้อมูล
- [ ] Feed หลัก (chronological) และ ClubSection เดิม (Club ของฉัน) ทำงานเหมือนเดิมทุกจุด ไม่มี regression (`flutter test` ผ่านครบ)
- [ ] ไม่มีตาราง/schema ใหม่ (ใช้ query เพิ่มจาก `drops`/`pops`/`clubs` เดิม)

Dependencies: ไม่มี — ต่อยอด WYN-007 (Home)/WYN-014 (Club Core)/WYN-015 (Club Discovery) ที่ผ่าน QA แล้วทั้งหมด

Priority: สูง (คุณค่าชัดเจน ความเสี่ยงต่ำ เพราะเป็น additive section ล้วนๆ ไม่แตะ feed logic เดิม)

Risks: ถ้า definition ของ "Trending" (48 ชม. window) ผิดจากที่ Founder คาดหวัง อาจต้องปรับ threshold ทีหลัง — ไม่ใช่ breaking change เพราะเป็นแค่ query parameter

Recommendation: เริ่มก่อนงานอื่นทั้งหมดในกลุ่มนี้ เพราะเป็น quick win ที่ตรงกับ "Recommended Clubs / Popular Clubs" และ "Trending Content" ใน spec ข้อ 1 โดยตรง ใช้ component/query ที่มีอยู่แล้วเกือบทั้งหมด

Handoff: AI Design ออกแบบ 2 section ใหม่นี้ (ตำแหน่งวางใน Home, card layout ของ Trending row) ก่อนส่งต่อ AI Coding
