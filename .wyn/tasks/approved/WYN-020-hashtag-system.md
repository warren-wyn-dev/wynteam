# Product Task — WYN-020

Status: QA รอบ 1 (อิสระ) — PASS, 2026-08-17
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (independent — PASS)

## Independent QA — Round 1 (AI QA & Security, 2026-08-17)

**หมายเหตุ**: "PASS" เดิมด้านล่าง (`## Coding + QA Output`) เป็น self-verified โดย session เดียวกับที่เขียนโค้ดเท่านั้น ไม่ใช่ QA อิสระ — รอบนี้คือ QA อิสระรอบแรกที่แท้จริง

```
Feature: Hashtag System — tappable #hashtag + Hashtag Feed screen (Latest/Trending)
Environment: Re-synced ไป origin/main tip (commit 8d338cb) ก่อนเริ่ม, Flutter 3.47.0 / Dart 3.13.0, ไม่มี schema change ใน task นี้ (ตัดสินใจ ILIKE-based ตาม WYN-009 precedent ไม่สร้างตาราง `hashtags`)
Test Cases:
1. `flutter analyze` อิสระ — clean
2. `flutter test` อิสระทั้ง suite ที่ HEAD ปัจจุบัน — 362/362 ผ่าน (ครอบคลุม 18 test ของ task นี้)
3. อ่านโค้ด `hashtagPattern` (`core/text_utils.dart`) ยืนยัน `\p{M}` (combining mark) รวมอยู่ในแพทเทิร์นจริง — ทดสอบด้วยมือ (`#เที่ยวไทย` มีวรรณยุกต์/สระ Thai ที่เป็น Unicode category Mn) เพื่อยืนยันว่าบั๊กเดิมที่ Coding อ้างว่าเจอและแก้ ("#เที่ยวไทย" → ตัดเหลือ "เท") จะไม่เกิดซ้ำกับแพทเทิร์นปัจจุบัน — สอดคล้องกับที่โค้ดปัจจุบันมี `\p{M}` แล้ว
4. อ่านโค้ด `HashtagFeedScreen._load()` ยืนยัน exact-match re-check ผ่าน `extractHashtags(...).contains(_lowerTag)` หลัง ILIKE candidate fetch — ป้องกัน false-positive ของ `#WYNfamily` เมื่อค้นหา `#WYN` (R4) ตรงตามที่ต้องการ
5. อ่านโค้ด `HashtagFeedScreen._resolveRolesFor()` — ยืนยันพึ่ง `club_posts`'s own RLS (membership-gated select) สำหรับ visibility ของ Club post ที่ปนอยู่ใน Hashtag Feed ไม่ใช่ bypass ใดๆ (เทียบกับ WYN-021's finding ด้านล่าง ยืนยันว่าจุดนี้ไม่มีปัญหาแบบเดียวกัน เพราะ `club_posts` select policy ถูกต้องอยู่แล้ว ไม่ได้พึ่ง `club_post_mentions`)
6. ไล่ Acceptance Criteria ทั้ง 4 ข้อเทียบกับ Requirements R1–R4 และ Design doc (`wyn-020-hashtag-system.md`) — ครบทุกข้อ
7. Regression: `HashtagText` ถูก wire เข้า 6 จุด (HomeDropCard/HomePopCard/DropDetailScreen/PopClipView/ClubPostCard/ClubPostDetailScreen) — ยืนยันไม่มี call site ไหนพัง (อยู่ใน 362/362)
Passed: 7/7
Failed: 0/7
Severity: N/A
Reproduction Steps: N/A (ไม่พบบั๊ก)
Expected: N/A
Actual: N/A
Security Findings: ไม่พบช่องโหว่ — ILIKE substring search พึ่ง RLS เดิมของ `drops`/`club_posts` ทั้งคู่ (ไม่ bypass), known limitation (ILIKE จะช้าลงเมื่อข้อมูลโต) บันทึกไว้แล้วโดย Product เป็นความเสี่ยงที่ยอมรับแล้ว ไม่ใช่ security gap
Recommendation: ไม่มีข้อเสนอเพิ่มเติม
Final Status: PASS
```

---

## Coding + QA Output (เดิม — self-verified เท่านั้น ไม่ใช่ QA อิสระ)

## Coding + QA Output

- `core/text_utils.dart`: `hashtagPattern` + `extractHashtags(text)` -- single shared tokenizer. Caught and fixed a real bug in its own test suite: the first regex draft (`[\p{L}\p{N}_]+`) truncated Thai hashtags at the first combining vowel/tone mark (`#เที่ยวไทย` → `เท`) because marks like ่/ี are Unicode category Mn, not L; fixed by adding `\p{M}`.
- `core/widgets/hashtag_text.dart`: new `HashtagText` widget, drop-in `Text` replacement, renders `#tag` spans as tappable (primary color, semibold) via `TextSpan.recognizer`, disposes recognizers correctly on rebuild/dispose. Builds its own repositories from `Supabase.instance.client` on tap (mirrors `PushNotificationService`'s precedent) so none of its 6 call sites needed a new constructor parameter.
- Wired into all 6 places a caption/content string was previously plain `Text`: `HomeDropCard`, `HomePopCard`, `DropDetailScreen`, `PopClipView` (kept its `maxLines`/`overflow`/white-on-video styling), `ClubPostCard`, `ClubPostDetailScreen`.
- `ClubPostRepository.searchByContent` (new, mirrors `DropRepository.searchByCaption`) -- relies on `club_posts`' own RLS for visibility, same guarantee `fetchFromJoinedClubs` already has.
- New `HashtagFeedScreen` (`features/hashtag/`): Latest/Trending tabs, merges Drop + Club post results. ILIKE candidate fetch narrowed to an **exact** match via `extractHashtags` re-check (fixes the `#WYNfamily` vs `#WYN` false-positive named in the task's own R4) -- caught by a dedicated test before it could ship as a silent bug. Club post role resolution reuses `FromYourClubsFeed`'s (WYN-015) exact per-`clubId` `fetchMyMembership` pattern.
- 18 new tests (`text_utils_test.dart` +7, `hashtag_text_test.dart` +3 via direct `TextSpan.recognizer` invocation, `hashtag_feed_screen_test.dart` +8) covering: tokenizer correctness (including the Thai combining-mark bug once fixed), tap-to-navigate, exact-match filtering, Latest/Trending sort order, mixed Drop+ClubPost rendering, tap-through to `DropDetailScreen`/`ClubPostDetailScreen`. Hit two more instances of the session's known testing gotchas while writing these: forgetting `tester.takeException()` after a pump with a `NetworkImage` 400 (surfaces as an opaque "[E] Test failed" with no visible assertion diff) and the 1:1-image-pushes-content-below-viewport issue from `home_feed_screen_test.dart` -- both fixed using the file's own established patterns.
- `flutter analyze`: clean (app-wide). `flutter test`: 323/323 (was 306/306 before this task).

Acceptance Criteria:
- [x] #hashtag ในแคปชันทุกจุดที่แสดง (Home/Drop feed/Drop detail/Club post) เป็น tappable และแตะแล้วเปิด Hashtag Feed ถูก tag
- [x] Hashtag Feed มี Latest/Trending tab ทำงานถูกต้อง ไม่ค้าง ไม่ crash เมื่อไม่มีผลลัพธ์ (Empty state)
- [x] Hashtag matching มี word-boundary ถูกต้อง (ไม่ปนกับ hashtag ที่มีคำนำหน้าเดียวกัน)
- [x] `flutter test` ผ่านครบ ไม่มี regression กับหน้าที่แสดง caption เดิมทุกจุด

Feature: Hashtag System — tappable #hashtag + Hashtag Feed screen (Latest/Trending)

Goal: ทำให้ #hashtag ใน caption ของ Drop/Club post กดได้จริง เปิดหน้า Hashtag Feed แสดงโพสต์ทั้งหมดที่ใช้ hashtag นั้น พร้อม Latest/Trending tab ตามที่ spec ข้อ 3 ระบุ

Target User: ผู้ใช้ WYN Social ที่อยากค้นหา/ติดตาม content ตาม topic (#WYN #มหาสารคาม ฯลฯ)

Problem: WYN-009 (Search) ตัดสินใจ defer hashtag entity system ไปแล้ว ใช้แค่ caption ILIKE substring search แทน — วิธีนี้หาโพสต์ที่ "มีคำนั้นอยู่ในแคปชัน" ได้ แต่ #hashtag ในแคปชันปัจจุบัน**ไม่ใช่ tappable text เลย** (เป็นแค่ plain string) และไม่มีหน้า Hashtag Feed แยกที่มี Latest/Trending

Requirements:

R1. Render caption เป็น `RichText`/`TextSpan` ที่ parse `#word` เป็น tappable span (สีเน้น, แตะแล้วเปิด Hashtag Feed) — ใช้ regex เดียวกันทุกจุดที่แสดง caption (Home card, Drop card, Drop detail, Club post) ผ่าน shared widget/helper ตัวเดียว ไม่ duplicate regex 4 ที่
R2. หน้า Hashtag Feed ใหม่: query caption ILIKE `%#tag%` ข้าม Drop+Club post (reuse pattern ของ WYN-009's `searchByCaption`) — **ไม่สร้างตาราง `hashtags` แยกรอบนี้** เพื่อไม่ขัดกับการตัดสินใจ defer ของ WYN-009 และหลีกเลี่ยงระบบซ้ำซ้อนตามกติกา RULES.md
R3. Latest tab = chronological, Trending tab = จำนวนโพสต์ที่ใช้ hashtag นี้ในช่วงเวลาสั้น (นิยามเดียวกับ WYN-017's Trending window ถ้าทำแล้ว) — คำนวณแบบ query-time COUNT ไม่ใช่ counter คอลัมน์แยก (เพื่อความง่าย รอบแรก)
R4. เขียนไว้ชัดใน Design spec: การค้นหาแบบ ILIKE ไม่แม่นยำ 100% เมื่อ data โตขึ้น (เช่น `#WYNfamily` จะ match เมื่อค้นหา `#WYN` ด้วย ถ้าไม่ทำ word-boundary ให้ถูก) — ต้องมี regex/query ที่ตรวจ boundary ถูกต้อง ไม่ใช่ substring ธรรมดา

Acceptance Criteria:
- [ ] #hashtag ในแคปชันทุกจุดที่แสดง (Home/Drop feed/Drop detail/Club post) เป็น tappable และแตะแล้วเปิด Hashtag Feed ถูก tag
- [ ] Hashtag Feed มี Latest/Trending tab ทำงานถูกต้อง ไม่ค้าง ไม่ crash เมื่อไม่มีผลลัพธ์ (Empty state)
- [ ] Hashtag matching มี word-boundary ถูกต้อง (ไม่ปนกับ hashtag ที่มีคำนำหน้าเดียวกัน)
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับหน้าที่แสดง caption เดิมทุกจุด

Dependencies: ทำได้อิสระ ไม่ต้องรอ WYN-017/018/019 — แต่ถ้าทำหลัง WYN-017 จะได้ Trending-window query มาต่อยอดได้เลย

Priority: กลาง (spec ข้อ 3 เป็น requirement ชัดเจน แต่ไม่ใช่ blocker ของ Home/Drop restructure หลัก)

Risks: ILIKE-based approach (แทนที่จะมี hashtag entity table) จะช้าลงเมื่อข้อมูลโตมาก — ยอมรับความเสี่ยงนี้รอบแรกตาม precedent ของ WYN-009 แต่ควรบันทึกเป็น known limitation ให้ Founder ทราบชัดเจน เผื่อต้องย้อนกลับมาสร้าง entity table จริงภายหลัง

Recommendation: ทำแบบ ILIKE ต่อจาก WYN-009 เพื่อความสม่ำเสมอและไม่สร้างระบบซ้ำซ้อน ตามกติกา RULES.md ข้อ "ห้ามสร้างระบบซ้ำซ้อน" — เสนอปรับเป็น entity table ในอนาคตถ้า usage จริงเริ่มมีปัญหา performance

Handoff: AI Design ออกแบบ Hashtag Feed screen (reuse tab-bar/card pattern เดิม) + กำหนด regex/tap-target ของ hashtag span ให้ตรงกันทุกจุดที่ใช้ ก่อนส่งต่อ AI Coding
