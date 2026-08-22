# Product Task — WYN-027

Status: active (Coding เสร็จ, รอ AI QA & Security)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ — ดู `.wyn/docs/design/wyn-027-block-system.md`) → AI Coding (เสร็จ) → AI QA & Security (ถัดไป)

Feature: Block System

Goal: ให้ผู้ใช้ตัดขาดการมองเห็น/ปฏิสัมพันธ์กับผู้ใช้อื่นที่ไม่ต้องการยุ่งเกี่ยวด้วยได้อย่างสมบูรณ์ทั้งสองทิศทาง เพื่อความปลอดภัยของผู้ใช้ก่อนเปิด WYN Chat (Phase 2)

Target User: ผู้ใช้ทุกคน โดยเฉพาะผู้ที่โดนคุกคาม/สแปม/พฤติกรรมไม่พึงประสงค์จากผู้ใช้อื่น

Problem: WYN ตอนนี้ไม่มีทางตัดขาดจากผู้ใช้อื่นเลย — ต่อให้ Follow กันไม่ได้ ผู้ใช้ที่ไม่พึงประสงค์ก็ยังเห็น/Comment/Mention/Like เนื้อหาได้เสมอ Master Spec ข้อ 23 ระบุผลของ Block ไว้ตายตัว: "ไม่เห็น Content กันตามกฎที่กำหนด, ส่ง DM ไม่ได้, Follow ไม่ได้, Mention ไม่ได้, Interaction ถูกจำกัด" — ต้องทำก่อน WYN Chat (Phase 2) เพราะเปิด DM ให้คนแปลกหน้าคุยกันโดยไม่มี Block เป็นความเสี่ยงสูงเกินยอมรับได้

Requirements:

**การ Block**
- Block ได้จาก Profile ของผู้ใช้อื่น (เมนู More) และจากปุ่ม "Report" flow (ตัวเลือกเสริม "Block ผู้ใช้นี้ด้วย" หลังส่ง Report สำเร็จ — ไม่บังคับ)
- Block เป็น one-directional action แต่ผล **บังคับใช้สองทิศทางเสมอ** (A block B → ทั้ง A เห็น B ไม่ได้ และ B เห็น A ไม่ได้ ไม่ใช่แค่ A ไม่เห็น B)
- Unblock ได้จากหน้า Settings → Safety → Blocked List เท่านั้น (ไม่มีปุ่ม Unblock ด่วนจาก Profile เพื่อกันมือลื่น)

**ผลของการ Block (ตาม Master Spec ข้อ 23 เป๊ะ ๆ)**
- **ไม่เห็น Content กัน**: เนื้อหาของอีกฝ่าย (Drop) หายไปจาก Home Feed/Search/Profile/Trending ของอีกฝ่ายทั้งสองทิศทาง — Comment ของอีกฝ่ายใน Drop คนอื่นก็ถูกซ่อนเช่นกัน (ไม่ใช่แค่ profile-level)
- **ส่ง DM ไม่ได้**: บันทึกไว้เป็น requirement ล่วงหน้าสำหรับ WYN Chat (WYN-031, Phase 2) — schema/logic ต้องรองรับตั้งแต่ตอนนี้ แต่ยัง**ไม่มี UI ให้ทดสอบจริงในรอบนี้**เพราะ Chat ยังไม่มีอยู่
- **Follow ไม่ได้**: ถ้าฝ่ายใดฝ่ายหนึ่งเคย Follow กันอยู่ก่อน Block → **ยกเลิก Follow ทั้งสองทิศทางทันทีที่ Block สำเร็จ** และปุ่ม Follow ถูกปิดใช้งานตราบเท่าที่ยัง Block อยู่ (ทั้งสองทิศทาง)
- **Mention ไม่ได้**: พิมพ์ @username ของฝ่ายที่ถูก/เป็นคนบล็อกใน Caption/Comment → ไม่ resolve เป็น mention ที่กดได้ (แสดงเป็นข้อความธรรมดา ไม่ trigger notification)
- **Interaction ถูกจำกัด**: Like/Comment ระหว่างกันทำไม่ได้ทั้งสองทิศทาง (ปุ่ม Like/ช่อง Comment ปิดใช้งานถ้าเข้าถึงเนื้อหาของอีกฝ่ายได้ทางอ้อม — แม้ปกติจะไม่เห็นเนื้อหากันอยู่แล้วตามข้อด้านบน กรณีนี้เป็น defense-in-depth เผื่อเข้าถึงผ่านลิงก์ตรง)

**Blocked List (ใน Settings → Safety)**
- แสดงรายชื่อผู้ใช้ทั้งหมดที่ตัวเอง Block ไว้ (username, display name, avatar)
- แตะ Unblock รายคน → คืนสถานะปกติทันที (ไม่คืน Follow relationship เดิมให้อัตโนมัติ — ต้อง Follow ใหม่เอง)

Acceptance Criteria:
- [ ] Block ผู้ใช้จาก Profile → ปุ่มเปลี่ยนสถานะทันที เนื้อหาของอีกฝ่ายหายจาก Home/Search/Profile ของตัวเองทันที
- [ ] อีกฝ่าย (ผู้ถูก block) เปิดแอป → เนื้อหาของผู้ block ก็หายไปจากมุมมองของตัวเองด้วยเช่นกัน (สองทิศทาง)
- [ ] เคย Follow กันอยู่ก่อน Block → Follow relationship ถูกลบทั้งสองทิศทางทันทีที่ Block
- [ ] พยายาม Follow ผู้ใช้ที่ Block กันอยู่ (ทั้งสองทิศทาง) → ทำไม่ได้ ปุ่มปิดใช้งาน
- [ ] Comment ของฝ่ายที่ถูก Block ในโพสต์คนอื่น (ที่ทั้งคู่มองเห็นร่วมกันได้ เช่นโพสต์ของบุคคลที่สาม) → ถูกซ่อนจากอีกฝ่าย
- [ ] พิมพ์ @username ของฝ่ายที่ Block กันอยู่ → ไม่ resolve เป็น mention ที่กดได้/ไม่ส่ง notification
- [ ] Unblock จาก Settings → Safety → Blocked List → คืนสถานะปกติ เห็นเนื้อหากันได้อีกครั้ง แต่ Follow relationship เดิมไม่กลับมาอัตโนมัติ
- [ ] Block ตัวเองทำไม่ได้ (ปุ่มไม่แสดงบนโปรไฟล์ตัวเอง)
- [ ] Regression: RLS ของ Drop/Club/Follow/Notification เดิมทั้งหมดยังทำงานถูกต้องสำหรับคู่ผู้ใช้ที่ไม่ได้ Block กัน (ต้องแน่ใจว่า filter การ Block ไม่กระทบ query ปกติของคนอื่น)

Dependencies: WYN-002/003 (Auth/Profile — Approved), WYN-008 (Follow — Approved, ต้องแก้ logic ให้เช็ค Block ก่อนอนุญาต Follow), WYN-005/007 (Drop/Home feed — Approved, ต้องเพิ่ม filter Block เข้า query), WYN-026 (Report — แนะนำทำก่อนเพื่อ reuse entry point แต่ไม่ใช่ hard-block ถ้า Founder ต้องการสลับลำดับ)

Priority: P0 — คู่กับ WYN-026 เป็นฐานความปลอดภัยที่สำคัญที่สุดก่อนเปิด Phase 2 (Chat)

Risks:
- **ผลกระทบกว้างที่สุดใน Phase 1**: ต้องแก้ query/RLS ของเกือบทุก feature ที่มีอยู่แล้ว (Home Feed, Search, Drop Detail, Club Post, Comment, Follow, Notification, Mention) ให้ filter ออกทั้งสองทิศทาง — ความเสี่ยงสูงสุดคือ **ตกหล่นจุดใดจุดหนึ่ง** (เช่น ลืม filter ใน Search แต่ทำใน Home) ทำให้ Block "รั่ว" บางส่วน ต้องทำ checklist ทุก entry point ที่ query เนื้อหาข้ามผู้ใช้ให้ครบก่อนส่ง QA
- **Performance**: การ filter "ไม่แสดงเนื้อหาของคนที่ Block กัน" ในทุก feed query จะเพิ่ม join/subquery กับตาราง `blocks` ทุกจุด — แนะนำออกแบบเป็น RLS policy ที่ join ตาราง `blocks` โดยตรงในนโยบาย select ของ `drops`/`club_posts`/`drop_comments` แทนการ filter ฝั่ง Dart (ฝั่ง DB บังคับใช้ได้จริง ป้องกันการเข้าถึงผ่าน API ตรงด้วย)
- **DM block ที่ยังไม่มี UI**: เขียนไว้ล่วงหน้าเป็น requirement แต่ไม่มีทางทดสอบจริงจนกว่าจะถึง WYN-031 — ทำได้แค่ตรวจว่า schema/logic ของ `blocks` table รองรับ (มี dependency ระบุไว้ชัดใน WYN-031 spec ตอนถึง Phase 2)
- **Mutual-block edge case**: A block B แล้ว B block A ด้วย (ซ้อนกัน) — ต้องออกแบบให้ unique constraint/logic ไม่ error และผลลัพธ์ยังคงเหมือน single-direction block (ไม่มีอะไรเปลี่ยนเพิ่มเติม)

Recommendation:
1. ทำคู่ขนานหรือทันทีหลัง WYN-026 — Block เป็นงานที่กระทบวงกว้างที่สุดใน Phase 1 ควรเผื่อเวลา QA มากที่สุด (แนะนำ regression test แยกทุก feature ที่มี query ข้ามผู้ใช้)
2. Design ตาราง `blocks (blocker_id, blocked_id, created_at)` แบบมี unique constraint คู่ (blocker_id, blocked_id) และเขียน RLS ของตารางอื่นทั้งหมดให้ join ตารางนี้ — reuse pattern นี้ต่อให้ WYN-028 (Mute) ก็ได้เพราะโครงสร้างคล้ายกัน
3. ส่งต่อ AI Design พร้อมกับ/ต่อจาก WYN-026 เพื่อออกแบบ Blocked List screen ใน Settings → Safety

Handoff: AI Design — ออกแบบ Block confirmation dialog, Blocked List screen (Settings → Safety), และสถานะ UI ของปุ่ม Follow/Message/Report เมื่อ Block กันอยู่

---

## Coding Output (2026-08-22)

Implementation: เพิ่ม `blocks` table + RLS + RPC (`block_relationship`/`block_user`/`unblock_user`) ใน schema.sql พร้อม security-definer helper functions 4 ตัว (`drop_author_id`/`pop_author_id`/`drop_comment_author_id`/`pop_comment_author_id`) ที่ต้องใช้แก้บั๊ก RLS self-referential trap ที่เจอระหว่างทดสอบจริงบน Postgres (ดู DECISIONS.md) — SELECT policy ของ drops/drop_comments/pops/pop_comments/club_posts/club_post_comments กรอง block ทั้งสองทิศทางออก, INSERT policy ของ likes/comments/follows/mentions ทุกตัวก็เช็ค block ก่อนอนุญาต ฝั่ง Flutter เพิ่ม feature ใหม่ `block/` (BlockRelationship enum, BlockRepository, block_dialogs, BlockedListScreen), `settings/` (SettingsScreen ใหม่), และแก้ ViewProfileScreen (Blocked persona banner, More menu บล็อก, gear icon), ReportSheet (SnackBarAction "บล็อก" หลังส่ง report), 7 จุดเรียก report เพิ่ม associatedUserId, และ HashtagText เช็ค block ก่อน navigate ไปโปรไฟล์ที่ mention (Screen 9)

Files Changed: `supabase/schema.sql` (WYN-027 section), `app/lib/features/block/**` (ใหม่), `app/lib/features/settings/**` (ใหม่), `app/lib/features/profile/presentation/view_profile_screen.dart`, `app/lib/features/report/presentation/report_sheet.dart`, `app/lib/core/widgets/hashtag_text.dart`, และ 6 call sites ของ `showReportSheet` (drop_detail_screen.dart, club_post_card.dart, club_post_detail_screen.dart, home_drop_card.dart, drop_grid_tile.dart)

Reason: บังคับใช้ Block ทั้งสองทิศทางที่ชั้น RLS ตามดีไซน์ ไม่ใช่ filter ฝั่ง client — ป้องกันการเข้าถึงผ่าน API ตรงด้วย ตามที่ระบุไว้ใน Product spec ("Risks" ข้อ Performance)

Tests: เพิ่ม `test/block_relationship_test.dart`, `test/block_dialogs_test.dart`, `test/blocked_list_screen_test.dart`, `test/support/recording_block_repository.dart` — รวม 13 เทสต์ใหม่ (unit + widget) ครอบ BlockRelationship mapping, confirm/cancel dialog ทั้งสองแบบ, list/empty/error/retry state, และ unblock flow เต็ม `flutter test` ทั้งโปรเจกต์ผ่านครบ 382/382 (baseline 369 + ใหม่ 13, ไม่มี regression) และ SQL ยืนยันด้วยการรัน schema.sql จริงบน local Postgres 16 กับ 11 สถานการณ์ทดสอบ (T1-T11 รวม regression ของ club content)

Build: `flutter analyze` สะอาด ไม่มี issue

Known Issues: (1) Mention ที่ถูก block ยังคงแสดงเป็นสี tappable ตามปกติ (ไม่เปลี่ยนเป็นข้อความธรรมดา) — เช็ค block ที่ tap-time แล้ว silent no-op แทน ตามที่บันทึกไว้ใน Design doc Screen 9 เพราะการเปลี่ยนสีต้องแก้ 6 จุดเรียก HashtagText ทั้งหมด (2) MentionInput autocomplete ยังไม่กรองผู้ใช้ที่ถูก block ออก (Design แนะนำแต่ไม่ hard-required) (3) Denormalized comment count อาจไม่ตรงกับจำนวนแถวที่มองเห็นได้จริงหลังกรอง block (บันทึกไว้ใน Design doc เป็น known limitation)

Handoff: AI QA & Security — ทดสอบ WYN-027 ตาม Acceptance Criteria ทั้งหมด โดยเฉพาะ regression ของ non-blocked pairs และ mutual-block edge case
