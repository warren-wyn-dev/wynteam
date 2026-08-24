# Coding Task — WYN-062

Status: approved (Coding + QA เสร็จ, 2026-08-24 — flutter analyze สะอาด, flutter test เต็ม suite 743/743 ผ่าน) — รอ AI Deploy & DevOps เมื่อมี infra จริง
Owner: AI Coding → AI QA & Security

## Implementation

Founder สั่งงานตรงเป็นสเปค "WYNOS V1.0.0 Beta — UX/UI Fix & Feature Update" ครอบคลุม 7 requirement บนโครงสร้างเดิม (ไม่รื้อ Architecture) ตรวจสอบ codebase ที่มีอยู่ก่อนแล้วพบว่าหลายจุดถูกทำไว้ดีอยู่แล้วจากรอบก่อนหน้า (เช่น Home feed continuous scroll + auto-refresh หลังโพสต์สำเร็จ, Profile grid ใช้ CustomScrollView เต็มพื้นที่อยู่แล้ว) จึงแก้เฉพาะส่วนที่ยังขาดจริง:

1. **HOME feed** — ตรวจสอบแล้วว่า `HomeFeedScreen` (ListView.separated ต่อเนื่อง + `RootShell._homeVersion` bump ให้ remount/refetch หลังสร้าง Drop) ทำงานถูกต้องอยู่แล้วตาม Acceptance Criteria ทั้งหมด **ไม่ต้องแก้โค้ด**
2. **DROP — text หรือ image อย่างใดอย่างหนึ่งหรือทั้งคู่** — เดิมบังคับต้องมีรูปเสมอ (`createDrop` require `imageBytes`) ปรับ:
   - `DropRepository`: เพิ่ม `createTextDrop()` (caption-only, image_url null เหมือน Poll), รวม path insert เดิมเป็น `_insertDrop()` ตัวเดียวที่รับ `imageUrl` nullable
   - `CreateDropScreen._canShare`: อนุญาตเมื่อมีรูป **หรือ** caption ไม่ว่าง (เดิมต้องมีรูปเท่านั้น)
   - ทุกจุดที่ render Drop แบบไม่มีรูป (ไม่ใช่ Poll) ต้อง null-safe: เพิ่ม `TextDropPlaceholderTile` (แสดง caption snippet แทน "โพล") ใน `DropGridTile`, `SavedGridTile`, `DraftGridTile`, `recently_deleted_drops_screen`, `quote_redrop_screen`; `HomeDropCard`/`DropDetailScreen` ใช้ `if (imageUrl != null)` แทน force-unwrap
   - `EditDropCaptionScreen` เพิ่ม `hasImage` param — แก้ไข Drop ไม่มีรูปให้เหลือ caption ว่างไม่ได้ (เหมือน Poll question เดิม) ทั้ง client-side และ server-side (`edit_drop()` RPC)
   - เพิ่ม DB constraint `drops_has_content` (`image_url is not null or caption is not null`) เป็น safety net — ไม่กระทบ path เดิมเลย เพราะทุก path ที่มีอยู่ก่อนหน้านี้ (image Drop, Poll Drop) ผ่านเงื่อนไขนี้อยู่แล้ว
3. **PROFILE — ซ่อน Pop** — เอา Pop tab/TabBarView ออกจาก `ViewProfileScreen` เท่านั้น (`ProfilePopGridTab`, `PopRepository`, ตาราง `pops` ไม่แตะ) DefaultTabController length ปรับ 5→4 (ของตัวเอง) / 3→2 (คนอื่น)
4. **LIKE — Double Tap** — สร้าง `DoubleTapLike` widget (reusable, `GestureDetector.onDoubleTap` + heart icon pop-in/fade-out animation ~700ms, guard ไม่ให้ยิง Like ซ้ำถ้า `alreadyLiked` อยู่แล้ว) ครอบพื้นที่รูป/วิดีโอ (และ caption สำหรับ Drop แบบไม่มีรูป) ใน `HomeDropCard`, `HomePopCard`, `DropDetailScreen`
5. **USERNAME แก้ไขได้** — เพิ่ม `ProfileRepository.isUsernameAvailable()`/`updateUsername()` (unique check + race-safe ผ่าน Postgres unique_violation), เพิ่มช่อง `@username` ใน `EditProfileScreen` พร้อม debounce 400ms + สถานะ Available/Unavailable/Invalid เหมือน onboarding's `UsernameSetupScreen` ทุกจุดที่อ่าน username query สดจาก `profiles` อยู่แล้ว ไม่มีการ denormalize เลยไม่ต้อง sync ที่อื่น
6. **PROFILE POST GRID scroll เต็มพื้นที่** — ตรวจสอบแล้วว่า `ProfileDropGridTab` (CustomScrollView ใน Expanded) และ `RootShell` (Scaffold ปกติ + bottomNavigationBar มาตรฐาน ไม่บัง content) ถูกต้องอยู่แล้ว **ไม่พบบั๊ก ไม่ต้องแก้โค้ด**
7. **HASHTAG AUTOCOMPLETE** — สร้าง `HashtagRepository.suggest()` (ILIKE-based เหมือน WYN-020 เดิม ไม่มี `hashtags` table ใหม่ — นับ post count แบบ approximate จาก candidate set ที่ bound ไว้) ต่อยอด `MentionInput` ให้ detect `#token` เหมือน `@token` เดิม แสดง dropdown "#tag — N โพสต์" กดเลือกแล้วแทรกที่ caret ต่อสายเข้า `CreateDropScreen` และ `CreateClubPostScreen` — default constructor lazy (ไม่แตะ `Supabase.instance` จนกว่าผู้ใช้พิมพ์ `#` จริง)

## Files Changed

**App (lib)**: `core/widgets/mention_input.dart`, `core/widgets/double_tap_like.dart` (ใหม่), `features/hashtag/data/hashtag_repository.dart` (ใหม่), `features/drop/data/drop_repository.dart`, `features/drop/presentation/{create_drop_screen,drop_detail_screen,quote_redrop_screen,recently_deleted_drops_screen,edit_drop_caption_screen}.dart`, `features/drop/presentation/widgets/{drop_grid_tile,draft_grid_tile,text_drop_placeholder_tile(ใหม่)}.dart`, `features/club/data/club_post_repository.dart`, `features/club/presentation/create_club_post_screen.dart`, `features/home/presentation/widgets/{home_drop_card,home_pop_card}.dart`, `features/profile/data/profile_repository.dart`, `features/profile/presentation/{edit_profile_screen,view_profile_screen}.dart`, `features/saved/presentation/widgets/saved_grid_tile.dart`

**Supabase**: `schema.sql` (เพิ่ม `drops_has_content` CHECK constraint + guard ใน `edit_drop()` RPC ท้ายไฟล์)

**Tests**: `test/{create_drop_screen_test,edit_profile_screen_test,mention_input_test,view_profile_screen_test,edit_drop_caption_screen_test}.dart` (แก้ของเดิม), `test/double_tap_like_test.dart` (ใหม่), `test/support/{recording_drop_repository,recording_club_post_repository,recording_profile_repository}.dart` (เพิ่ม override สำหรับ method ใหม่)

## Reason

ตาม Founder spec ตรง ๆ — ดูรายละเอียดเหตุผลแต่ละข้อใน Implementation ด้านบน หลักการที่ยึดตลอดทั้งงาน: แก้เฉพาะจุดที่จำเป็นจริง (สำรวจโค้ดเดิมก่อนทุกจุด พบว่า requirement 1 กับ 6 ทำไว้ถูกต้องแล้วจากรอบก่อน ไม่แตะ), ไม่ลบ Pop ออกจาก codebase (ซ่อนจาก UI เท่านั้น), ไม่สร้าง `hashtags` table ใหม่ (สอดคล้อง WYN-020 เดิม)

## Tests

`flutter test` เต็ม suite: **743/743 ผ่าน** (baseline ก่อนแก้ 725/725 — เพิ่ม 18 test case ใหม่ตลอดทั้ง Coding+QA รอบนี้)

## Build

`flutter analyze`: **No issues found**

---

## QA & Security Review

Feature: WYNOS V1.0.0 Beta UX/UI Fix & Feature Update (7 requirement ด้านบน)
Environment: Flutter 3.47.1 (ติดตั้งใหม่ในเซสชันนี้เพื่อรัน `flutter analyze`/`flutter test` จริง) — ไม่มี emulator/device จริงสำหรับ manual UI testing

Test Cases: อ่าน diff ทั้งหมดซ้ำแบบ adversarial (พยายามหาทางทำให้ Drop ไม่มีรูป/ไม่มี caption หลุดเข้าระบบได้), รัน `flutter analyze` + `flutter test` เต็ม suite, ไล่ตรวจทุกจุดที่เคย `Drop.imageUrl!` (force-unwrap) ทั้ง repo ว่า null-safe ครบหลัง Drop เป็น optional-image ได้แล้ว, ตรวจ RLS policy ของ `profiles`/`drops` ว่ารองรับ method ใหม่จริง (ไม่ใช่แค่ client-side logic ที่ดูเหมือนถูก)

Passed:
- Drop image-only / caption-only / ทั้งคู่ โพสต์ได้ทั้ง 3 แบบ, ปุ่ม "แชร์" ปิดเมื่อไม่มีทั้งคู่ — ยืนยันด้วย test จริง
- ทุก grid tile / card / detail screen ที่เคยสมมติว่า Drop มีรูปเสมอ (`DropGridTile`, `SavedGridTile`, `DraftGridTile`, `HomeDropCard`, `DropDetailScreen`, `quote_redrop_screen`, `recently_deleted_drops_screen`) null-safe ครบ ไม่มีจุดไหน crash เมื่อเจอ Drop ไม่มีรูป
- Pop tab หายจาก Profile ทั้ง 2 persona (ของตัวเอง/คนอื่น), ระบบ Pop เดิมไม่ถูกแตะ
- Double Tap Like: ยิง Like ครั้งเดียวไม่ซ้ำแม้ double-tap ซ้ำบนโพสต์ที่ Like อยู่แล้ว, heart animation แสดงแล้วหายไปจริง (ไม่ค้างในทรีแบบมองไม่เห็น — แก้บั๊กจุดนี้ระหว่าง QA ดู Security Findings)
- Username: เช็คซ้ำ real-time ถูกต้อง (รวมกรณี "พิมพ์กลับเป็นชื่อเดิมของตัวเอง" ต้องไม่ขึ้น "ถูกใช้แล้ว"), บันทึกเฉพาะตอนเปลี่ยนจริง, RLS อนุญาต update แถวตัวเองแล้วยืนยันแล้ว
- Hashtag: dropdown ขึ้นถูกต้องตาม prefix, เรียงตาม count, กดเลือกแทรกที่ caret ถูกต้อง, mention/hashtag ไม่ชนกัน

Failed (พบระหว่าง QA แล้วแก้ไขก่อนอนุมัติ — ไม่มีรายการ FAIL ค้างอยู่):
1. **`EditDropCaptionScreen` ปล่อยให้แก้ Drop ไม่มีรูปเหลือ caption ว่างได้** — เดิม `_canSave` เช็คเฉพาะกรณี `isPollQuestion` เท่านั้นว่าห้ามว่าง แต่ Drop แบบไม่มีรูป (feature ใหม่ในรอบนี้) ไม่มีการเช็คนี้เลย ผู้ใช้แก้แคปชันเหลือว่างได้แล้วเจอ error ทั่วไปจาก DB constraint (`drops_has_content`) ซึ่ง error message ไม่บอกสาเหตุจริง → **แก้แล้ว**: เพิ่ม `hasImage` param ปิดปุ่ม "บันทึก" เมื่อ caption ว่างและไม่มีรูป (ทั้ง client-side และเพิ่ม guard ใน `edit_drop()` RPC เป็น defense-in-depth) มี test คุมไว้ 3 เคสใหม่
2. **Heart animation ค้างอยู่ในทรีแบบมองไม่เห็นหลัง fade เสร็จ** — `DoubleTapLike` เช็ค `_controller.isDismissed` เพื่อซ่อน heart แต่ animation แบบ `forward()` จบที่สถานะ `completed` ไม่ใช่ `dismissed` เลยไม่เคยถูกลบออกจากทรีจริง (มองไม่เห็นเพราะ opacity 0 แต่ widget ยังอยู่) → **แก้แล้ว**: เช็คทั้ง `isDismissed || isCompleted`

Severity: ทั้ง 2 ข้อเป็น Medium (ข้อ 1 กระทบ data integrity ระดับ UX ที่แย่ ไม่ใช่ security hole จริง เพราะ DB constraint กันไว้อยู่แล้วไม่ให้ข้อมูลเสียหาย; ข้อ 2 เป็น cosmetic/perf เล็กน้อย ไม่กระทบผู้ใช้จริงเพราะ opacity 0 มองไม่เห็นอยู่แล้ว)

Security Findings:
- ไม่พบ secret/credential หลุดใน diff นี้
- `isUsernameAvailable`/`updateUsername` ตรวจแล้วว่าอาศัย RLS policy เดิม (`auth.uid() = id` สำหรับ UPDATE) ไม่ได้เปิดช่องให้แก้ profile คนอื่น
- `HashtagRepository.suggest()` ใช้ ILIKE ผ่าน Supabase client (parameterized ผ่าน PostgREST query builder) ไม่มี raw SQL string concatenation ที่เสี่ยง injection
- DB constraint ใหม่ (`drops_has_content`) เป็น additive-only ไม่มีความเสี่ยงทำลายข้อมูลเดิม แต่ **ยังไม่ได้ validate กับข้อมูลจริงใน production** (ไม่มี Supabase instance จริงในสภาพแวดล้อมนี้) — ต้องให้ AI Deploy & DevOps รัน migration แบบ dry-run/ตรวจสอบก่อน apply จริงเสมอ เพราะ `ALTER TABLE ADD CONSTRAINT CHECK` จะ validate ทุกแถวที่มีอยู่ทันทีและ fail ทั้ง migration ถ้ามีแถวเก่าที่ผิดเงื่อนไข (ไม่ควรมี แต่ต้องยืนยันจริงก่อน deploy)

Recommendation:
- ก่อน deploy จริง ให้ AI Deploy & DevOps รัน schema migration กับ staging/read-replica ก่อนเพื่อยืนยันว่า `drops_has_content` constraint ไม่ fail กับข้อมูลจริง
- แนะนำให้ Founder ทดสอบ UX จริงบนมือถือ (animation feel ของ Double Tap Like, mobile layout) เพราะสภาพแวดล้อมนี้รันได้แค่ widget test ไม่มี emulator
- Hashtag count เป็นค่าประมาณ ถ้าต้องการ exact count ในอนาคตต้องเป็นงานแยกที่มี Product/Design approve schema change เพิ่ม (`hashtags` table)

Final Status: **PASS**

## Handoff

ส่งต่อ AI Deploy & DevOps (`/deploy`) — เมื่อมี production infra จริง ให้ตรวจ schema migration กับข้อมูลจริงก่อนตาม Recommendation ด้านบน แล้วจึง deploy
