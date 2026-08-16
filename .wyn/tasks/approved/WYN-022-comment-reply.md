# Product Task — WYN-022

Status: QA รอบ 1 (อิสระ) — PASS, 2026-08-17
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security (independent — PASS)

## Independent QA — Round 1 (AI QA & Security, 2026-08-17)

**หมายเหตุ**: "PASS" เดิมด้านล่าง (`## Coding + QA Output`) เป็น self-verified โดย session เดียวกับที่เขียนโค้ดเท่านั้น ไม่ใช่ QA อิสระ — รอบนี้คือ QA อิสระรอบแรกที่แท้จริง

```
Feature: Comment Reply (nested reply แบบชั้นเดียว) — Drop/Pop/Club post ทั้งสาม
Environment: Re-synced ไป origin/main tip (commit 8d338cb) ก่อนเริ่ม, Flutter 3.47.0 / Dart 3.13.0, PostgreSQL 16.13 local (harness เดียวกับที่ใช้ตรวจ WYN-021)
Test Cases:
1. `flutter analyze` อิสระ — clean
2. `flutter test` อิสระทั้ง suite ที่ HEAD ปัจจุบัน — 362/362 ผ่าน (ครอบคลุม 12 test ของ task นี้)
3. **Red→Green regression proof อิสระ กับ Postgres จริง** (คนละวิธีกับ Coding ที่ verify แค่ครั้งเดียวตอนพัฒนา): seed comment ระดับบนสุด → reply เข้า comment นั้น (ควรสำเร็จ) → ยืนยันสำเร็จจริง (2 แถวใน `drop_comments`) → พยายาม reply เข้า reply นั้นอีกที (ควรถูกบล็อก) → ยืนยัน `ERROR: Cannot reply to a reply -- only one level of nesting is allowed` ถูก raise จริงจาก trigger `prevent_nested_drop_comment_reply`
4. **RED proof เพิ่มเติม**: `disable trigger drop_comments_prevent_nested_reply` แล้วลองทำ reply-to-reply เดิมซ้ำ — ยืนยันสำเร็จ (ไม่มี error) เมื่อไม่มี trigger พิสูจน์ว่า trigger (ไม่ใช่ constraint อื่น) คือกลไกที่บล็อกจริง — จากนั้น `enable trigger` กลับคืนและยืนยันบล็อกอีกครั้งได้ปกติ
5. อ่านโค้ด trigger ทั้ง 3 ตัว (`prevent_nested_drop_comment_reply`/`prevent_nested_pop_comment_reply`/`prevent_nested_club_post_comment_reply`) — สมมาตรกันทั้งหมด ตรรกะเดียวกันทุกจุด (subquery เช็ค `parent_comment_id is not null` ของ parent ตัวเอง)
6. อ่านโค้ด `home_feed`/`fetchPosts`'s comment_count subquery — ยืนยัน `count(*)` เดิมนับรวม reply โดยอัตโนมัติ (R3) ไม่ต้องแก้โค้ดจริงตามที่ Coding อ้าง
7. ไล่ Acceptance Criteria ทั้ง 6 ข้อเทียบกับ Requirements R1–R4 และ Design doc (`wyn-022-comment-reply.md`) — ครบทุกข้อ
8. Regression: ยืนยัน RLS insert/select/delete ของ comment เดิมทั้งสามตาราง (Drop/Pop/Club post) ไม่ถูกแก้ (แค่เพิ่มคอลัมน์ + trigger ใหม่แยกต่างหาก ตาม R4) — Like/ลบ reply ใช้ permission เดิมทุกจุด
Passed: 8/8
Failed: 0/8
Severity: N/A
Reproduction Steps: N/A (ไม่พบบั๊ก)
Expected: N/A
Actual: N/A
Security Findings: ไม่พบช่องโหว่ — depth-1 guard บังคับใช้จริงทั้งระดับ UI (ไม่มีปุ่มตอบกลับใต้ reply) และระดับ DB (trigger, พิสูจน์แล้วว่าเป็นกลไกจริงที่บล็อก ไม่ใช่แค่ UI convention ที่ bypass ได้ง่ายๆ ผ่าน raw API)
Recommendation: ไม่มีข้อเสนอเพิ่มเติม
Final Status: PASS
```

---

## Coding + QA Output (เดิม — self-verified เท่านั้น ไม่ใช่ QA อิสระ)

## Coding + QA Output

- `parent_comment_id` (nullable, self-referencing FK) added to `drop_comments`/`pop_comments`/`club_post_comments`, each with its own `before insert` trigger (`prevent_nested_*_reply`) rejecting a reply whose own parent already has a parent -- a CHECK constraint can't run that self-referencing subquery. Verified end-to-end against real local Postgres 16: a reply to a top-level comment succeeds, a reply to a reply is correctly rejected with the trigger's own error message.
- `DropComment`/`PopComment`/`ClubPostComment` gained `parentCommentId`; `DropRepository`/`PopRepository`/`ClubPostRepository.addComment` gained an optional `parentCommentId` param.
- All three comment surfaces (`DropDetailScreen`, `PopCommentSheet`, `ClubPostDetailScreen`) got the same UI treatment: a "ตอบกลับ" button under top-level comments only (not replies, which is what keeps nesting to one level in the UI -- the DB trigger is the real enforcement), replies rendered indented directly under their parent from the same already-fetched flat comment list (no second query), and a "ตอบกลับ [name]" chip with a cancel (X) above the composer while replying.
- Comment count needed no code change -- `comment_count` on `drops`/`pops`/`club_posts` is already a plain `count(*)` over the comments table, so a reply is counted the moment it's inserted (confirmed by reading `home_feed`/`fetchPosts`'s existing count subqueries before concluding this, not assumed).
- 12 new tests: `drop_comment_test.dart`/`pop_comment_test.dart` (+3 each, `parentCommentId` parsing/copyWith), new `club_post_comment_test.dart` (3, this model had no prior test file), `drop_detail_screen_test.dart` (+3: reply button only on top-level comments, reply chip + `addComment` called with the right parent id, cancel clears the chip).
- `flutter analyze`: clean (app-wide). `flutter test`: 348/348 (was 336/336 before this task — 12 new, 0 regressed).

Acceptance Criteria:
- [x] กด "ตอบกลับ" ใต้ comment ระดับบนสุด สร้าง reply ที่ผูกกับ comment นั้นถูกต้อง
- [x] Reply แสดงเยื้องใต้ comment ต้นทาง ไม่ปนกับ comment อื่น
- [x] ไม่มีทาง reply ต่อ reply (UI ไม่มีปุ่มตอบกลับใต้ reply, และ DB trigger บล็อกจริงถ้าพยายามข้ามหน้า UI)
- [x] จำนวน Comment ที่แสดงบนการ์ด (Home/Drop/Club) นับรวม reply ถูกต้อง (ไม่ต้องแก้โค้ด -- count(*) เดิมนับรวมอยู่แล้ว)
- [x] Like/ลบ reply ทำงานเหมือน comment ปกติ (reuse permission เดิม -- ใช้ widget row เดียวกันทุกจุด)
- [x] `flutter test` ผ่านครบ ไม่มี regression กับ comment เดิมทั้ง Drop/Pop/Club

Feature: Comment Reply (nested reply แบบชั้นเดียว)

Goal: เพิ่ม "Reply Comment" ตามที่ spec ข้อ 5 ระบุไว้เป็นหนึ่งใน Post Interaction ที่ต้องรองรับ — ปัจจุบันมีแค่ comment แบบ flat (ไม่มี reply)

Target User: ผู้ใช้ WYN Social ที่คุยกันในคอมเมนต์ (reply ตรงถึงคนที่คอมเมนต์ก่อนหน้า)

Problem: ระบบ comment ปัจจุบัน (Drop/Pop/Club post ทั้งหมด) เป็น flat list — มี Like Comment และลบ Comment ของตัวเองอยู่แล้ว (WYN-005/006/014) แต่ไม่มีทาง reply ตรงถึง comment คนอื่น

Requirements:

R1. เพิ่มคอลัมน์ `parent_comment_id` (nullable, self-referencing FK) ให้ `drop_comments`/`pop_comments`/`club_post_comments` ทั้งสามตาราง — จำกัดความลึกแค่ 1 ชั้น (reply-to-top-level-comment เท่านั้น ห้าม reply-to-reply) เพื่อกัน UI ซับซ้อนเกินจำเป็นและ query ง่ายกว่า
R2. UI: ปุ่ม "ตอบกลับ" ใต้แต่ละ comment ระดับบนสุด — reply แสดงเยื้องเข้า (indent) หนึ่งระดับใต้ comment ต้นทาง ไม่ทำ threading ลึกกว่านั้น
R3. Reply นับรวมใน comment count เดิม (ไม่แยก counter) เพื่อไม่กระทบ UI ที่แสดง "จำนวน Comment" อยู่แล้วทุกจุด (Home/Drop/Club card)
R4. Reply ใช้ RLS/Like/Delete pattern เดียวกับ comment เดิมทุกอย่าง (owner ลบของตัวเองได้, like ได้เหมือนกัน) — ไม่สร้าง permission model ใหม่

Acceptance Criteria:
- [ ] กด "ตอบกลับ" ใต้ comment ระดับบนสุด สร้าง reply ที่ผูกกับ comment นั้นถูกต้อง
- [ ] Reply แสดงเยื้องใต้ comment ต้นทาง ไม่ปนกับ comment อื่น
- [ ] ไม่มีทาง reply ต่อ reply (UI ไม่มีปุ่มตอบกลับใต้ reply)
- [ ] จำนวน Comment ที่แสดงบนการ์ด (Home/Drop/Club) นับรวม reply ถูกต้อง
- [ ] Like/ลบ reply ทำงานเหมือน comment ปกติ (reuse permission เดิม)
- [ ] `flutter test` ผ่านครบ ไม่มี regression กับ comment เดิมทั้ง Drop/Pop/Club

Dependencies: ไม่มี — ทำอิสระจากงานอื่นในกลุ่มนี้ได้เลย เพราะแตะเฉพาะ comment schema/UI

Priority: ต่ำ-กลาง (อยู่ใน requirement list ของ spec แต่ไม่ใช่หัวใจของ "Feed & Club Update" เท่า Home/Drop restructure — เหมาะเป็น fast-follow)

Risks: ความเสี่ยงต่ำ — เป็นการเพิ่ม column/UI แบบ additive ไม่กระทบ comment เดิมที่มี `parent_comment_id = null` เสมอ

Recommendation: ทำเป็นลำดับท้ายๆ ของกลุ่มนี้ เพราะเป็น self-contained เล็กสุด ทำเมื่อไหร่ก็ได้ไม่กระทบงานอื่น — เหมาะมอบให้ Coding แทรกระหว่างรอ Design ของงานใหญ่กว่า (WYN-018) ได้

Handoff: AI Design ออกแบบ UI ปุ่มตอบกลับ + indent style สั้นๆ (ไม่ซับซ้อน) ก่อนส่งต่อ AI Coding
