# Product Task — WYN-017

Status: coded + self-verified (QA — PASS, 2026-08-17)
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (self-verified)

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
