# Coding Task — WYN-062

Status: review (Coding เสร็จ, 2026-08-24 — flutter analyze สะอาด, flutter test เต็ม suite 740/740 ผ่าน) — รอ AI QA & Security
Owner: AI Coding

## Implementation

Founder สั่งงานตรงเป็นสเปค "WYNOS V1.0.0 Beta — UX/UI Fix & Feature Update" ครอบคลุม 7 requirement บนโครงสร้างเดิม (ไม่รื้อ Architecture) ตรวจสอบ codebase ที่มีอยู่ก่อนแล้วพบว่าหลายจุดถูกทำไว้ดีอยู่แล้วจากรอบก่อนหน้า (เช่น Home feed continuous scroll + auto-refresh หลังโพสต์สำเร็จ, Profile grid ใช้ CustomScrollView เต็มพื้นที่อยู่แล้ว) จึงแก้เฉพาะส่วนที่ยังขาดจริง:

1. **HOME feed** — ตรวจสอบแล้วว่า `HomeFeedScreen` (ListView.separated ต่อเนื่อง + `RootShell._homeVersion` bump ให้ remount/refetch หลังสร้าง Drop) ทำงานถูกต้องอยู่แล้วตาม Acceptance Criteria ทั้งหมด **ไม่ต้องแก้โค้ด**
2. **DROP — text หรือ image อย่างใดอย่างหนึ่งหรือทั้งคู่** — เดิมบังคับต้องมีรูปเสมอ (`createDrop` require `imageBytes`) ปรับ:
   - `DropRepository`: เพิ่ม `createTextDrop()` (caption-only, image_url null เหมือน Poll), รวม path insert เดิมเป็น `_insertDrop()` ตัวเดียวที่รับ `imageUrl` nullable
   - `CreateDropScreen._canShare`: อนุญาตเมื่อมีรูป **หรือ** caption ไม่ว่าง (เดิมต้องมีรูปเท่านั้น)
   - ทุกจุดที่ render Drop แบบไม่มีรูป (ไม่ใช่ Poll) ต้อง null-safe: เพิ่ม `TextDropPlaceholderTile` (แสดง caption snippet แทน "โพล") ใน `DropGridTile`, `SavedGridTile`, `recently_deleted_drops_screen`, `quote_redrop_screen`; `HomeDropCard`/`DropDetailScreen` ใช้ `if (imageUrl != null)` แทน force-unwrap
   - เพิ่ม DB constraint `drops_has_content` (`image_url is not null or caption is not null`) เป็น safety net — ไม่กระทบ path เดิมเลย เพราะทุก path ที่มีอยู่ก่อนหน้านี้ (image Drop, Poll Drop) ผ่านเงื่อนไขนี้อยู่แล้ว
3. **PROFILE — ซ่อน Pop** — เอา Pop tab/TabBarView ออกจาก `ViewProfileScreen` เท่านั้น (`ProfilePopGridTab`, `PopRepository`, ตาราง `pops` ไม่แตะ) DefaultTabController length ปรับ 5→4 (ของตัวเอง) / 3→2 (คนอื่น)
4. **LIKE — Double Tap** — สร้าง `DoubleTapLike` widget (reusable, `GestureDetector.onDoubleTap` + heart icon pop-in/fade-out animation ~700ms, guard ไม่ให้ยิง Like ซ้ำถ้า `alreadyLiked` อยู่แล้ว) ครอบพื้นที่รูป/วิดีโอ (และ caption สำหรับ Drop แบบไม่มีรูป) ใน `HomeDropCard`, `HomePopCard`, `DropDetailScreen`
5. **USERNAME แก้ไขได้** — เพิ่ม `ProfileRepository.isUsernameAvailable()`/`updateUsername()` (unique check + race-safe ผ่าน Postgres unique_violation), เพิ่มช่อง `@username` ใน `EditProfileScreen` พร้อม debounce 400ms + สถานะ Available/Unavailable/Invalid เหมือน onboarding's `UsernameSetupScreen` ทุกจุดที่อ่าน username query สดจาก `profiles` อยู่แล้ว ไม่มีการ denormalize เลยไม่ต้อง sync ที่อื่น
6. **PROFILE POST GRID scroll เต็มพื้นที่** — ตรวจสอบแล้วว่า `ProfileDropGridTab` (CustomScrollView ใน Expanded) และ `RootShell` (Scaffold ปกติ + bottomNavigationBar มาตรฐาน ไม่บัง content) ถูกต้องอยู่แล้ว **ไม่พบบั๊ก ไม่ต้องแก้โค้ด**
7. **HASHTAG AUTOCOMPLETE** — สร้าง `HashtagRepository.suggest()` (ILIKE-based เหมือน WYN-020 เดิม ไม่มี `hashtags` table ใหม่ — นับ post count แบบ approximate จาก candidate set ที่ bound ไว้) ต่อยอด `MentionInput` ให้ detect `#token` เหมือน `@token` เดิม แสดง dropdown "#tag — N โพสต์" กดเลือกแล้วแทรกที่ caret ต่อสายเข้า `CreateDropScreen` และ `CreateClubPostScreen` **สำคัญ**: default constructor lazy (ไม่แตะ `Supabase.instance` จนกว่าผู้ใช้พิมพ์ `#` จริง) — จุดนี้เจอบั๊กจริงระหว่างทดสอบ (ดู Known Issues)

## Files Changed

**App (lib)**: `core/widgets/mention_input.dart`, `core/widgets/double_tap_like.dart` (ใหม่), `features/hashtag/data/hashtag_repository.dart` (ใหม่), `features/drop/data/drop_repository.dart`, `features/drop/presentation/{create_drop_screen,drop_detail_screen,quote_redrop_screen,recently_deleted_drops_screen}.dart`, `features/drop/presentation/widgets/{drop_grid_tile,text_drop_placeholder_tile(ใหม่)}.dart`, `features/club/data/club_post_repository.dart`, `features/club/presentation/create_club_post_screen.dart`, `features/home/presentation/widgets/{home_drop_card,home_pop_card}.dart`, `features/profile/data/profile_repository.dart`, `features/profile/presentation/{edit_profile_screen,view_profile_screen}.dart`, `features/saved/presentation/widgets/saved_grid_tile.dart`

**Supabase**: `schema.sql` (เพิ่ม `drops_has_content` CHECK constraint ท้ายไฟล์)

**Tests**: `test/{create_drop_screen_test,edit_profile_screen_test,mention_input_test,view_profile_screen_test}.dart` (แก้ของเดิม), `test/double_tap_like_test.dart` (ใหม่), `test/support/{recording_drop_repository,recording_club_post_repository,recording_profile_repository}.dart` (เพิ่ม override สำหรับ method ใหม่)

## Reason

ตาม Founder spec ตรง ๆ — ดูรายละเอียดเหตุผลแต่ละข้อใน Implementation ด้านบน หลักการที่ยึดตลอดทั้งงาน: แก้เฉพาะจุดที่จำเป็นจริง (สำรวจโค้ดเดิมก่อนทุกจุด พบว่า requirement 1 กับ 6 ทำไว้ถูกต้องแล้วจากรอบก่อน ไม่แตะ), ไม่ลบ Pop ออกจาก codebase (ซ่อนจาก UI เท่านั้น), ไม่สร้าง `hashtags` table ใหม่ (สอดคล้อง WYN-020 เดิม)

## Tests

`flutter test` เต็ม suite: **740/740 ผ่าน** (baseline ก่อนแก้ 725/725 — เพิ่ม 15 test case ใหม่: 4 ใน `double_tap_like_test.dart`, 4 ใน `mention_input_test.dart` (hashtag), 7 ใน `edit_profile_screen_test.dart` (username), 1 ใน `create_drop_screen_test.dart` (text-only Drop) และแก้ 2 test เดิมใน `create_drop_screen_test.dart`/`view_profile_screen_test.dart` ให้ตรงพฤติกรรมใหม่)

## Build

`flutter analyze`: **No issues found**

## Known Issues

- ระหว่าง implement เจอบั๊กจริง 2 รอบที่ตัวเองสร้างขึ้นแล้วแก้เอง: (1) `HashtagRepository` แบบ eager default (`late final ... = HashtagRepository(Supabase.instance.client)`) ทำให้ widget test ทุกตัวที่เปิด `CreateDropScreen`/`CreateClubPostScreen` โดยไม่ initialize Supabase จริงพังหมด — แก้เป็น lazy construction ใน `MentionInput` เอง (สร้างเฉพาะตอนพิมพ์ `#` จริง) (2) test ใหม่สร้าง `RecordingDropRepository()` inline ในตัว test แทนที่จะ constructed ใน `setUpAll` ทำให้ GoTrue timer leak — ย้ายมาไว้ใน `setUpAll` ตาม pattern เดิมของไฟล์
- Hashtag suggestion post count เป็นค่าประมาณจาก candidate set ที่ bound (limit 60 รายการล่าสุดต่อ query) ไม่ใช่ count จริงทั้งระบบ — สอดคล้องกับ design ของ WYN-020 เดิมที่ไม่มี `hashtags` table ถ้าต้องการ count แม่นยำ ต้องเป็นงานแยกที่มีการอนุมัติ schema change เพิ่ม
- ไม่ได้รัน `supabase/tests/*.sh` (ต้องมี Supabase instance จริง ไม่มีในสภาพแวดล้อมนี้) — DB constraint ใหม่เป็น additive-only (แค่ปฏิเสธ row ที่เป็นไปไม่ได้อยู่แล้วในทุก path เดิม) ความเสี่ยงต่ำ แต่ QA ควรยืนยันกับ Supabase project จริงก่อน deploy
- Double Tap Like: ยังไม่ได้ต่อเข้า `PopSingleClipScreen` (full-screen Pop video player) เพราะ Pop ถูก deprioritize ใน V1.0.0 Beta อยู่แล้ว (ซ่อนจาก Profile, unmounted จาก Bottom Nav) — ถ้า Founder ต้องการให้ Pop เต็มจอก็มี Double Tap Like ด้วย แจ้งมาเพิ่มได้

## Handoff

ส่งต่อ AI QA & Security (`/qa`) — ตรวจ 7 requirement ตาม Acceptance Criteria ที่ Founder ระบุไว้ในสเปคเดิม โดยเฉพาะ manual/UI verification ที่ automated test ยังไม่ครอบคลุม (เช่น mobile layout จริง, animation feel, ต้องรอ Founder ยืนยัน UX ด้วยตาจริงเพราะ environment นี้รัน Flutter widget test ได้แต่ไม่มี emulator/device สำหรับ screenshot จริง)
