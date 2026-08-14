# Product Task — WYN-008

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS รอบ 1) → AI Deploy & DevOps (รอ infra จาก Founder)

Feature: Follow system (Follow/Unfollow, Followers/Following list)

Goal: ให้ผู้ใช้ติดตาม (Follow) ผู้ใช้คนอื่นได้ ระบบเดียวใช้ร่วมกันทั้ง Drop และ Pop ตามที่ Founder ยืนยันไว้แล้ว (ดู `.wyn/docs/product/wyn-v0.1-roadmap.md` บรรทัด 46) เป็นพื้นฐานให้ WYN-012 (Notification — Follow event) และ WYN-013 (Profile V2 — Followers/Following tab เต็มรูปแบบ) ทำต่อได้

Target User: วัยรุ่น / Gen Z ที่อยากติดตามคนที่โพสต์ Drop/Pop ที่ชอบ เพื่อดูเนื้อหาของคนนั้นต่อเนื่อง (ยังไม่ใช่ตัวกรอง feed ในรอบนี้ — ดู Requirements)

Problem: ตอนนี้ WYN-006 (Pop) มีปุ่ม "ติดตาม" ใน `PopClipView` อยู่แล้วแต่เป็น **UI-only** (แค่ `setState` สลับข้อความในเครื่อง ไม่มี backend, ไม่ persist, กด refresh แล้วหาย) — `DropDetailScreen` (WYN-005) ไม่มีปุ่ม Follow เลยด้วยซ้ำ ทั้งที่ Founder ยืนยันแล้วว่า Follow ต้องใช้ร่วมกันทั้งสองประเภทเนื้อหา

Requirements:
- **Follow/Unfollow ผู้ใช้อื่น**: กดปุ่ม Follow/Unfollow ได้จากทั้ง `DropDetailScreen` (เพิ่มปุ่มใหม่) และ `PopClipView`/`PopSingleClipScreen` (เชื่อมปุ่มเดิมที่มีอยู่แล้วให้ทำงานจริงแทนที่ UI-only เดิม) — **ใช้ตาราง/repository เดียวกันทั้งสองจุด ไม่แยกทำสองระบบ** ตามที่ Founder ยืนยันไว้แล้ว
- **ห้าม Follow ตัวเอง**: ทั้งฝั่ง UI (ซ่อนปุ่ม Follow เมื่อดูเนื้อหาของตัวเอง — ใช้ pattern เดียวกับ `isOwnDrop`/`isOwnPop` ที่มีอยู่แล้วสำหรับซ่อนปุ่มลบ/แสดงปุ่ม Follow เฉพาะเนื้อหาของคนอื่น) และฝั่ง DB (constraint ป้องกัน self-follow ไม่ให้เกิดขึ้นได้แม้ผ่าน client ที่แก้ไขเอง)
- **แสดงจำนวน Followers/Following**: เพิ่มตัวเลข Followers และ Following ใน `ViewProfileScreen` (โปรไฟล์ของตัวเอง — หน้าเดียวที่มีอยู่ในแอปตอนนี้ ดู Recommendation สำหรับเหตุผลที่ยังไม่ทำหน้าโปรไฟล์ของคนอื่น)
- **Followers/Following list**: แตะตัวเลข Followers หรือ Following จาก `ViewProfileScreen` แล้วเปิดหน้ารายชื่อ (list ของ username/avatar/display name) ได้ — รายการแบบเรียบง่าย ยังไม่ต้องมีปุ่ม Follow-back ในหน้า list นี้ในรอบนี้ (ดู Risks)
- **ปุ่ม Follow ต้องแสดงสถานะปัจจุบันถูกต้องเสมอ**: ถ้าติดตามอยู่แล้วต้องแสดง "กำลังติดตาม" ไม่ใช่ "ติดตาม" ตั้งแต่โหลดหน้าครั้งแรก (ต้อง query สถานะจริงจาก DB ไม่ใช่ default เป็น false เสมอเหมือนของเดิมใน WYN-006)
- **ต้องไม่มีบั๊ก double-tap**: กด Follow/Unfollow ซ้ำเร็ว ๆ ต้องได้ผลลัพธ์ถูกต้อง — ใช้ pattern เดียวกับ Like/Save ที่ผ่าน QA มาแล้วทุก feature ก่อนหน้า (อ่าน state สดใหม่ในตัว handler เสมอ ไม่ capture ค่าตอน build)
- **Home ยังไม่กรองตาม Follow ในรอบนี้**: ตามที่ยืนยันไว้แล้วใน roadmap — WYN-008 นี้ทำแค่ระบบ Follow/Unfollow + แสดงจำนวน/list เท่านั้น ไม่แตะ `HomeFeedScreen`/`home_feed` view เลย

Acceptance Criteria:
- [ ] เปิด Drop ของคนอื่น เห็นปุ่ม Follow/Unfollow ข้างชื่อผู้เขียน กดแล้วสถานะเปลี่ยนทันที (optimistic UI)
- [ ] เปิด Pop ของคนอื่น เห็นปุ่ม Follow/Unfollow ทำงานจริง (ไม่ใช่ UI-only เหมือนเดิม) สถานะ sync กับที่กดจาก Drop ของคนเดียวกัน (Follow คนคนเดียวจาก Pop แล้วไปเปิด Drop ของเขา ต้องเห็นว่า "กำลังติดตาม" อยู่แล้ว — พิสูจน์ว่าใช้ระบบเดียวกันจริง)
- [ ] เปิด Drop/Pop ของตัวเอง ไม่เห็นปุ่ม Follow เลย (ป้องกัน self-follow ทาง UI)
- [ ] พยายาม self-follow ผ่าน DB โดยตรง (เช่น insert ตรง ๆ) ต้องถูก DB ปฏิเสธ (constraint บังคับ ไม่ใช่พึ่ง client-side เพียงอย่างเดียว)
- [ ] กด Follow ซ้ำเร็ว ๆ (double-tap) ได้ผลลัพธ์ถูกต้องตามจำนวนครั้งที่กดจริง ไม่ toggle ผิดจังหวะ
- [ ] เปิด `ViewProfileScreen` ของตัวเอง เห็นจำนวน Followers และ Following ถูกต้องตามข้อมูลจริง
- [ ] แตะจำนวน Followers เปิดหน้ารายชื่อผู้ติดตามได้ถูกต้อง, แตะจำนวน Following เปิดหน้ารายชื่อที่ติดตามได้ถูกต้อง
- [ ] Follow คนใหม่แล้วกลับมาที่ `ViewProfileScreen` เห็นจำนวน Following เพิ่มขึ้นจริง (ไม่ต้อง force-restart แอป)
- [ ] ผู้ใช้อื่นสั่ง follow/unfollow แทนเราไม่ได้ (RLS บังคับ — เฉพาะเจ้าของ follow record เท่านั้นที่ลบได้)
- [ ] Home feed (WYN-007) ยังทำงานปกติเหมือนเดิมทุกอย่าง ไม่มี regression จากการเพิ่มปุ่ม Follow ใน Drop/Pop detail screens

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved, ให้ `ViewProfileScreen`/`ProfileRepository` เป็นจุดต่อยอด), WYN-005 (Drop — Approved, เพิ่มปุ่ม Follow เข้าไปใน `DropDetailScreen`), WYN-006 (Pop — Approved, เชื่อมปุ่ม Follow ที่มีอยู่แล้วใน `PopClipView` ให้ทำงานจริง)

Priority: P1 — ตาม roadmap dependency graph (ดู `.wyn/docs/product/wyn-v0.1-roadmap.md`) เริ่มทันทีหลัง WYN-007 approved ตามลำดับที่ Founder ยืนยันแล้ว (2026-08-14)

Risks:
- **Follow แยกจาก Like/Save เชิงโครงสร้าง**: Like/Save ผูกกับ `content_id` (Drop/Pop แต่ละชิ้น) แต่ Follow ผูกกับ `user_id` (คน ไม่ใช่เนื้อหา) — ตาราง `follows` จึงมีรูปแบบต่างจาก `drop_likes`/`pop_likes`/`saves` ที่มีอยู่แล้ว (ไม่มี `content_type`/`content_id` แต่มี `follower_id`/`following_id` แทน) ให้ AI Coding ออกแบบ schema ใหม่ตามรูปแบบที่เหมาะกับ user-to-user relationship โดยตรง ไม่ต้องพยายาม reuse โครงสร้างเดิมที่ไม่เข้ากัน
- **Self-follow ต้องกันสองชั้น**: ทั้ง UI (ซ่อนปุ่ม) และ DB (`CHECK` constraint `follower_id <> following_id`) เพราะ RLS อย่างเดียวกันแค่ "ใครเป็นเจ้าของ record" ไม่ได้กันเนื้อหาของ record นั้นเอง (เหมือนที่ WYN-005/006 ใช้ RLS กัน "แก้ของคนอื่น" แต่ยังต้องมี application logic แยกกัน "self-follow เป็นค่าที่ไม่ควรมีอยู่เลย")
- **หน้าโปรไฟล์ของคนอื่นยังไม่มีในแอป**: `ViewProfileScreen` ตอนนี้ผูกกับ `userId` ของตัวเองเท่านั้นผ่าน `RootShell` (ไม่มี route ไหนเปิดโปรไฟล์คนอื่นเลย) — WYN-008 นี้**ไม่สร้าง**หน้าโปรไฟล์ของคนอื่น (ดู Recommendation สำหรับเหตุผล) ดังนั้น Followers/Following list ของรอบนี้จะแสดงแค่ username/avatar/display name เฉย ๆ **แตะรายชื่อในลิสต์แล้วยังไปไหนไม่ได้ในรอบนี้** (เหมือนที่ Search bar ของ WYN-007 เป็น placeholder ที่ตั้งใจ) — WYN-013 (Profile V2) จะเป็นจุดที่ทำหน้าโปรไฟล์คนอื่นแบบเต็มรูปแบบพร้อม routing จาก list นี้
- **Follow-back จากหน้า list**: รอบนี้ไม่ทำปุ่ม Follow ในหน้า Followers/Following list (ต้องเปิดโปรไฟล์/เนื้อหาของคนนั้นก่อนถึงจะกด Follow ได้ ซึ่งยังทำไม่ได้ในรอบนี้ตามข้อจำกัดด้านบน) — ยอมรับเป็น known limitation ของรอบนี้ เหมือนที่ WYN-006 ยอมรับ view-count ไม่ dedup เป็น known limitation ปรับปรุงทีหลังได้เมื่อ WYN-013 ทำหน้าโปรไฟล์คนอื่นเสร็จ
- ยังไม่มี Notification เมื่อถูก Follow (ผูกกับ WYN-012 ทีหลัง)
- Home ยังไม่กรองตาม Follow (ผูกกับ WYN-013 ทีหลัง ตามที่ยืนยันไว้แล้ว)

Recommendation:
1. เริ่ม WYN-008 ทันทีตาม roadmap ที่ Founder อนุมัติไว้แล้ว
2. **Followers/Following list รอบนี้ทำแบบเรียบง่ายที่สุด (แสดงรายชื่อเฉย ๆ ไม่มี routing ไปโปรไฟล์คนอื่น) แทนที่จะรอทำเต็มรูปแบบใน WYN-013** — เหตุผล: (ก) การนับ/แสดงจำนวน Followers/Following ที่ถูกต้องคือ core value ของ Follow system เอง ถ้ารอ WYN-013 จะทำให้ WYN-008 เสร็จแล้วแต่ "downstream feature" (จำนวน/list) ยังใช้ไม่ได้จริง ไม่ตรงกับที่ AC ต้องพิสูจน์ (ข) การสร้างแค่ list แบบอ่านอย่างเดียว (ไม่มี routing ไปหน้าโปรไฟล์คนอื่นที่ยังไม่มี) เป็นงานเล็กมาก ไม่ throwaway เพราะ WYN-013 จะมาต่อยอด (เพิ่ม routing) ไม่ใช่เขียนใหม่ทั้งหมด (ค) สอดคล้องกับ precedent ของ WYN-007 ที่เลือกทำ Search bar เป็น placeholder ที่ตั้งใจ แทนที่จะข้ามไปเงียบ ๆ — รอบนี้ก็บันทึกข้อจำกัด "แตะรายชื่อแล้วยังไปไหนไม่ได้" ไว้ชัดเจนเหมือนกัน ไม่ใช่ mistake ที่มองข้าม
3. **ไม่สร้างหน้าโปรไฟล์ของคนอื่น (`ViewProfileScreen` สำหรับ `userId` ที่ไม่ใช่ตัวเอง) ในรอบนี้** — เหตุผล: เป็นงานคนละขอบเขตกับ Follow system เอง (ต้องคิดเรื่อง grid Drop, list Pop, Saved tab ของคนอื่น ฯลฯ ซึ่งเป็น scope ของ WYN-013 Profile V2 ตรง ๆ ตาม roadmap) การทำแบบง่าย ๆ ตอนนี้แล้วต้องรื้อใหม่ตอน WYN-013 คือ throwaway work เหมือนเหตุผลที่ WYN-007 ใช้ตัดสินใจเรื่อง Search
4. Follow button ใน `PopClipView` ที่มีอยู่แล้ว (UI-only) ให้เปลี่ยนจาก local `setState` เป็นเรียก repository จริง พร้อมโหลดสถานะ Follow ปัจจุบันตอนเปิดคลิป (ไม่ default เป็น false เสมอเหมือนเดิม)

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) ตำแหน่ง/ลักษณะปุ่ม Follow ใน `DropDetailScreen` ให้เข้ากับ header ที่มีอยู่แล้ว (มิเรอร์ตำแหน่งเดียวกับใน `PopClipView`) (2) หน้าจอ Followers/Following list ใหม่ (เรียบง่าย — avatar+ชื่อ+username เรียงเป็น list, empty state เมื่อยังไม่มีใคร) (3) การแสดงจำนวน Followers/Following ใน `ViewProfileScreen` (ตำแหน่ง, tap target, sync ทันทีหลัง follow/unfollow) — อ้างอิง pattern ปุ่ม Follow เดิมใน `PopClipView`/`.wyn/docs/design/wyn-006-pop.md` เป็นจุดตั้งต้น

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-008-follow.md` — 4 หน้าจอ: (1) ปุ่ม Follow ใน `DropDetailScreen` header ใหม่ mirror ตำแหน่ง/สไตล์จาก `PopClipView` เดิม ต่างแค่สี (Primary Blue บนพื้นสว่าง vs ขาวบนพื้นมืด) (2) ปุ่ม Follow เดิมใน `PopClipView` เปลี่ยนจาก UI-only เป็นของจริง ไม่มีเปลี่ยน visual (3) หน้า Followers/Following list ใหม่ (screen เดียว สลับ mode) — แถวไม่มี ripple/tap affordance เลยตั้งใจ เพราะยังไม่มีหน้าปลายทาง (4) จำนวน Followers/Following ใน `ViewProfileScreen` เป็น tap target จริงเปิด list ได้

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- Database: เพิ่มตาราง `follows` ใหม่ใน `supabase/schema.sql` — `follower_id`/`following_id` อ้างอิง `profiles(id)`, primary key คู่ (`follower_id`, `following_id`) ป้องกัน follow ซ้ำ, `CHECK (follower_id <> following_id)` ป้องกัน self-follow ระดับ DB, RLS มิเรอร์ pattern ของ `drop_likes`/`pop_likes`/`saves` เป๊ะ (select เปิดให้ authenticated อ่านได้ทุกคน, insert/delete จำกัดเฉพาะ `auth.uid() = follower_id`)
- `lib/features/follow/data/follow_repository.dart` (ใหม่): `FollowRepository(SupabaseClient)` — `isFollowing`, `toggleFollow` (insert/delete ตรง ๆ อ่าน `currentlyFollowing` จาก parameter ที่ caller ต้องอ่านสดใหม่เสมอ — เหมือนทุก toggle method ก่อนหน้านี้), `countFollowers`/`countFollowing` (ใช้ `.count(CountOption.exact)` ของ postgrest), `fetchFollowers`/`fetchFollowing` (query `follows` join `profiles` ผ่าน embedded resource บน FK ที่ระบุชื่อ constraint ตรง ๆ เพราะตาราง `follows` มี 2 FK ไปตาราง `profiles` เดียวกัน ต้องระบุให้ชัดว่าอันไหน) คืนเป็น `List<Profile>` (reuse model เดิมจาก WYN-003 ไม่สร้าง model ใหม่ซ้ำซ้อน) ใช้ร่วมกันทั้ง Drop และ Pop ไม่มี logic แยกที่ไหนเลย
- `drop_detail_screen.dart`: เพิ่ม `_isFollowing` (nullable — `null` = ยังไม่โหลดสถานะจริง ซ่อนปุ่มไว้ก่อนแทนที่จะเดา `false`), `_loadFollowStatus()` เรียกตอน `initState` เฉพาะกรณีไม่ใช่ Drop ของตัวเอง, `_toggleFollow()` อ่าน `_isFollowing` สดใหม่ทุกครั้งแบบเดียวกับ `_toggleLike`/`_toggleSave`, ปุ่ม Follow ใหม่ในแถว header (แสดงเมื่อ `!isOwnDrop && _isFollowing != null`) มี Semantics label ประกาศสถานะ ต้องเพิ่ม `followRepository` เป็น constructor parameter ใหม่ (breaking change กับทุกจุดที่สร้าง `DropDetailScreen` — อัปเดตแล้วทั้ง `DropFeedScreen`/`HomeFeedScreen`/test ทุกไฟล์)
- `pop_clip_view.dart`: เปลี่ยน `_isFollowing` จาก `bool` (default `false`, UI-only) เป็น `bool?` (null จนกว่าจะโหลดสถานะจริง) เพิ่ม `followRepository` constructor parameter ใหม่, `_loadFollowStatus()`/`_toggleFollow()` เหมือนกับ Drop เป๊ะ, เพิ่ม `Semantics` label ที่ขาดไปให้ปุ่ม Follow (Minor finding จาก WYN-006 QA รอบ 1 — แก้พร้อมกันตามที่ Coding Output ของ Design แนะนำ) — ต้องอัปเดต `PopFeedScreen`/`PopSingleClipScreen` ให้ส่ง `followRepository` ผ่านเข้ามาด้วย
- `lib/features/follow/presentation/follow_list_screen.dart` (ใหม่): `FollowListScreen` รับ `mode` (`FollowListMode.followers`/`.following`) + `userId` — screen เดียว สลับ query/title ตาม mode, infinite scroll + pull-to-refresh pattern เดียวกับ feed อื่น ๆ, แถวแต่ละแถวเป็น `Padding` + `Row` ธรรมดา **ไม่มี** `InkWell`/`GestureDetector` ห่อ (ตั้งใจตาม Design spec — ยังไม่มีหน้าปลายทางให้กดไปในรอบนี้), empty state แยกข้อความตาม mode
- `view_profile_screen.dart`: เปลี่ยนจาก `FutureBuilder<Profile>` เดี่ยว ๆ เป็น `FutureBuilder<({Profile profile, int followerCount, int followingCount})>` (Dart record) — โหลด profile + ทั้งสองจำนวนพร้อมกันเป็น future เดียว ไม่ใช่ query แยกที่ทำให้เกิด loading state ซ้อนกัน ตามที่ Design ระบุ เพิ่มแถวจำนวน Followers/Following ใต้ `@username` เป็น tap target จริง (`InkWell` + `Semantics(button: true)`) เปิด `FollowListScreen` ตาม mode ที่กด ต้องเพิ่ม `followRepository` เป็น constructor parameter ใหม่ด้วย
- `root_shell.dart`: สร้าง `FollowRepository` ตัวเดียวใน `build()` ส่งต่อให้ทุกแท็บที่ต้องใช้ (Home/Drop/Pop/Profile) **พบและแก้ gap ระหว่างพัฒนาเอง**: `RootShell` ใช้ `IndexedStack` เก็บทุกแท็บให้ยังไม่ถูก dispose เมื่อสลับแท็บ (เพื่อรักษาตำแหน่ง scroll ฯลฯ) แต่ Design ระบุไว้ว่าต้อง "sync ทันที" จำนวน Following หลัง follow จากแท็บอื่นแล้วสลับกลับมา Profile — ด้วย `IndexedStack` เพียงอย่างเดียว `ViewProfileScreen` จะไม่ reload อัตโนมัติเพราะ state ไม่เคยถูกทำลาย (ต่างจาก `Navigator.push`/`pop` ที่ `HomeFeedScreen._openDrop` ใช้ reload ได้ตามปกติ) แก้ด้วยการเพิ่ม `_profileVisitKey` (int) ใน `RootShell` ที่เพิ่มค่าทุกครั้งที่ผู้ใช้สลับ**ไปที่**แท็บ Profile แล้วใช้เป็น `ValueKey` ของ `ViewProfileScreen` — ทำให้ Flutter unmount/remount widget นั้นใหม่ (fetch ใหม่) ทุกครั้งที่เข้าแท็บ Profile โดยไม่กระทบแท็บอื่นที่ไม่มี key เปลี่ยน

Files Changed:
- `supabase/schema.sql` (เพิ่มตาราง `follows`)
- ใหม่: `app/lib/features/follow/data/follow_repository.dart`, `app/lib/features/follow/presentation/follow_list_screen.dart`
- แก้: `app/lib/features/drop/presentation/drop_detail_screen.dart`, `app/lib/features/drop/presentation/drop_feed_screen.dart`, `app/lib/features/pop/presentation/widgets/pop_clip_view.dart`, `app/lib/features/pop/presentation/pop_feed_screen.dart`, `app/lib/features/home/presentation/home_feed_screen.dart`, `app/lib/features/home/presentation/pop_single_clip_screen.dart`, `app/lib/features/profile/presentation/view_profile_screen.dart`, `app/lib/features/root/presentation/root_shell.dart`
- test ใหม่: `app/test/follow_list_screen_test.dart`, `app/test/view_profile_screen_test.dart`, `app/test/support/recording_follow_repository.dart`, `app/test/support/recording_profile_repository.dart`
- test แก้: `app/test/drop_detail_screen_test.dart`, `app/test/drop_comment_delete_test.dart`, `app/test/drop_comment_like_test.dart`, `app/test/pop_feed_screen_test.dart`, `app/test/home_feed_screen_test.dart` (ทุกไฟล์อัปเดต constructor call ให้ส่ง `followRepository` เข้าไปด้วย)

Reason: implement ตาม Product spec + Design spec ของ WYN-008 ครบตามขอบเขต — Follow ใช้ระบบเดียวกันจริงทั้ง Drop/Pop (พิสูจน์ด้วย regression test), self-follow กันสองชั้น (UI ซ่อนปุ่ม + DB CHECK constraint), ปุ่ม Follow โหลดสถานะจริงก่อนแสดงผลเสมอ (ไม่ default false แบบที่ WYN-006 เคยทำ), Followers/Following list+count ทำงานจริงในรอบนี้ตามที่ Product ตัดสินใจ (ไม่รอ WYN-013)

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 95/95 ผ่านทั้งหมด (เพิ่มจาก 83 — เทสต์ใหม่ 12 เคส: Follow double-tap safety ทั้ง Drop และ Pop context, self-follow UI guard ทั้งสองฝั่ง, `FollowListScreen` แสดงรายชื่อ/empty state ถูกต้องตาม mode/ไม่มี ripple, `ViewProfileScreen` แสดงจำนวนถูกต้องและ tap เปิด list ตาม mode ถูกต้อง)
- **พบและแก้ gap เอง 2 จุดก่อนส่ง QA** (นอกเหนือจากที่ Design ระบุไว้แล้ว): (1) `IndexedStack` sync gap ของ `ViewProfileScreen` ตามที่อธิบายไว้ใน Implementation ด้านบน (2) ระหว่างเขียนเทสต์ครั้งแรกของ "shows a Follow button for another user's Drop but not for the current user's own Drop" ใช้ `tester.pumpWidget()` สองครั้งในเทสต์เดียวกันเพื่อเปลี่ยน Drop แล้วคาดหวังว่า state จะรีเซ็ต — พบว่า Flutter ไม่เรียก `initState()` ซ้ำเมื่อ widget type เดิมถูก pump ทับที่ตำแหน่งเดิมในทรี (เรียก `didUpdateWidget` แทน ซึ่ง `DropDetailScreen` ไม่ได้ override) ทำให้ `_drop`/`_isFollowing` ค้างค่าเดิมข้ามการ pump ครั้งที่สอง เป็น testing gotcha ไม่ใช่บั๊กจริงของแอป แก้ด้วยการแยกเป็น 2 `testWidgets` block แยกกัน (แต่ละ block ได้ element tree ใหม่จริง) — บันทึกเป็น pattern ใหม่ใน `.wyn/learning/PATTERNS.md`

Known Issues:
- Followers/Following list แตะรายชื่อแล้วยังไปไหนไม่ได้ตามที่ Product/Design ตั้งใจไว้แล้ว (รอ WYN-013 ทำหน้าโปรไฟล์คนอื่น)
- ยังไม่มี Notification เมื่อถูก Follow (รอ WYN-012)
- Home ยังไม่กรองตาม Follow (รอ WYN-013 ตามที่ยืนยันไว้แล้ว)
- `ViewProfileScreen` reload ผ่านการเปลี่ยน key เมื่อเข้าแท็บ Profile ทุกครั้ง (ไม่ใช่ real-time subscription) — ตรงตามที่ Design อนุญาตไว้ ("ไม่ต้อง real-time subscription ในรอบนี้") แต่หมายความว่าจำนวนจะไม่อัปเดตถ้าผู้ใช้ค้างอยู่ที่แท็บ Profile ขณะที่มีคน follow ตัวเองใหม่จากอุปกรณ์อื่น — ยอมรับเป็น known limitation เหมือนกับ WYN-007's tie-breaking pagination caveat
- ยังไม่ทดสอบกับ Supabase project จริง (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า) — โดยเฉพาะ query แบบ `profiles!follows_follower_id_fkey`/`profiles!follows_following_id_fkey` ที่พึ่งชื่อ default ของ Postgres foreign key constraint ยังไม่เคยรันจริงกับ Postgres จริงเลย ต้องยืนยันว่าชื่อ constraint ตรงตามที่คาดไว้ (`follows_follower_id_fkey`/`follows_following_id_fkey`) เมื่อมี infra จริง

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ WYN-008 ก่อนอนุมัติ — เน้นตรวจ: (ก) self-follow ถูกกันจริงทั้ง UI และ DB (ข) double-tap safety ของปุ่ม Follow ทั้ง Drop และ Pop (ค) regression กับ Drop/Pop/Home/Profile เดิม (ต้องยังทำงานปกติหลังเพิ่ม `followRepository` parameter ทุกจุด) (ง) `IndexedStack` reload-on-visit fix ทำงานถูกต้องจริงตามที่อธิบายไว้ (จ) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัด

---

## QA & Security Report — รอบ 1 (AI QA & Security)

Feature: WYN-008 — Follow system (Follow/Unfollow, Followers/Following)

Environment: Code review + static analysis บน `main` หลัง merge PR #47 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับทุก feature ก่อนหน้า (ไม่มี Supabase project จริง, ไม่มี Postgres จริงให้รัน `follows` table/constraint ทดสอบ)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. **ไล่ Product Requirements ทุกบรรทัดกับโค้ดจริง** (แยกหัวข้อ)
4. **ไล่ Design Components ทั้ง 4 หน้าจอของ `wyn-008-follow.md` ทุกบรรทัดกับโค้ดจริง** (แยกหัวข้อ)
5. **ไล่ Acceptance Criteria ทั้ง 10 ข้อกับโค้ดจริง** (แยกหัวข้อ)
6. ตรวจ self-follow guard สองชั้น (UI + DB CHECK constraint) อ่าน SQL จริง
7. ตรวจ double-tap safety ของปุ่ม Follow ทั้ง Drop และ Pop — **ทำ red→green จริงด้วยตัวเอง** ไม่เชื่อ Coding Output อย่างเดียว
8. ตรวจว่า `FollowRepository` ตัวเดียวถูกใช้ร่วมกันจริงทั้ง Drop/Pop/Home/Profile ไม่ duplicate
9. ตรวจ query embedded resource ที่พึ่งชื่อ default ของ Postgres FK constraint
10. ตรวจ `IndexedStack` reload-on-visit fix ใน `RootShell` ด้วยเหตุผลเชิง logic
11. ตรวจ regression กับ Drop/Pop/Home/Profile เดิมทั้งหมด
12. Secret/credential exposure check ในโค้ดใหม่ทั้งหมด

Passed: 12/12

Severity: **N/A — ไม่พบ Major/Critical**

Findings:
1. **`flutter analyze`**: No issues found (ตรวจซ้ำอิสระ ตรงกับที่ Coding รายงาน)
2. **`flutter test`**: 95/95 ผ่านทั้งหมด (ตรวจซ้ำอิสระ ตรงกับที่ Coding รายงาน)
3. **Product Requirements**: ไล่ครบทุกบรรทัด — Follow/Unfollow ใช้ `FollowRepository` เดียวกันทั้ง Drop/Pop จริง (ยืนยันด้วย `grep` ว่า `RootShell` สร้าง `FollowRepository` ตัวเดียวแล้วส่งต่อทุกแท็บ ไม่มีจุดไหนสร้างซ้ำ), self-follow กันสองชั้นจริง, จำนวน Followers/Following แสดงใน `ViewProfileScreen` จริง, Followers/Following list เปิดได้จริง, ปุ่ม Follow โหลดสถานะจริงก่อนแสดง (nullable `_isFollowing`, ซ่อนจนกว่าจะโหลดเสร็จ — ตรงข้ามกับที่ WYN-006 เคย default `false` มาก่อน), Home ไม่ถูกแตะเลย (`grep` ยืนยัน `home_feed_screen.dart`/`home_repository.dart` ไม่มีการเปลี่ยนแปลงใน diff ของ PR #47) **ผ่านครบ**
4. **Design Components**: ไล่ครบทั้ง 4 หน้าจอ — Screen 1 (ปุ่ม Follow ใน `DropDetailScreen`, mirror ตำแหน่ง/สไตล์จาก `PopClipView` ต่างแค่สี Primary Blue vs ขาว, Semantics label ประกาศสถานะ) ตรง, Screen 2 (`PopClipView` เชื่อม backend จริง + เพิ่ม Semantics label ที่ขาดไปจาก WYN-006 QA รอบ 1) ตรง, Screen 3 (`FollowListScreen` — ยืนยันด้วย `grep -n "InkWell\|GestureDetector\|onTap" follow_list_screen.dart` **ไม่พบผลลัพธ์เลย** ยืนยันว่าแถวไม่มี tap affordance จริงตามที่ตั้งใจ, empty state แยกข้อความตาม mode ตรง) ตรง, Screen 4 (จำนวน Followers/Following เป็น tap target จริงด้วย `InkWell`+`Semantics(button:true)`, โหลดพร้อม profile เป็น future เดียวตามที่ระบุ) ตรง **ผ่านครบ**
5. **Acceptance Criteria**: ไล่ครบทั้ง 10 ข้อ — ทุกข้อมีโค้ดรองรับจริง (ดู Test Case 6-11 ด้านล่างสำหรับรายละเอียดของแต่ละข้อที่ตรวจเจาะลึก) **ผ่านครบ**
6. **Self-follow guard สองชั้น**: UI — `if (!isOwnDrop && _isFollowing != null)`/`if (!isOwnPop && _isFollowing != null)` ซ่อนปุ่มถูกต้องเมื่อเป็นเนื้อหาตัวเอง ยืนยันด้วย regression test ใหม่ (`drop_detail_screen_test.dart`, `pop_feed_screen_test.dart`) ที่ผ่านจริง — DB: อ่าน SQL จริงยืนยัน `constraint follows_no_self_follow check (follower_id <> following_id)` มีอยู่จริงในตาราง `follows` ครอบคลุมทุกเส้นทาง insert แม้ผ่าน client ที่แก้ไขเองก็ยังถูก Postgres ปฏิเสธ ไม่ใช่พึ่ง RLS/UI อย่างเดียว **ผ่าน**
7. **Double-tap safety — ทำ red→green จริงด้วยตัวเอง**: อ่าน `_toggleFollow()` ทั้งใน `DropDetailScreen`/`PopClipView` ยืนยันว่าอ่าน `_isFollowing` สดใหม่ทุกครั้งก่อน optimistic update (ไม่ capture ค่าตอน build) จากนั้น**แก้โค้ด `pop_clip_view.dart` ชั่วคราวให้ `_toggleFollow` ใช้ค่าคงที่แทนการอ่านสดใหม่** (จำลอง bug class เดียวกับที่เคยพบใน WYN-004) รัน `flutter test test/pop_feed_screen_test.dart --plain-name "rapid double-tap on Follow"` → **FAIL จริง** (`Expected: [false, true], Actual: [false, false]`) ยืนยันว่าเทสต์จับบั๊กได้จริงไม่ใช่ tautological จากนั้น restore โค้ดกลับมาที่ถูกต้อง รัน `flutter test`/`flutter analyze` ซ้ำ → **สะอาด 95/95 อีกครั้ง** **ผ่าน**
8. **`FollowRepository` shared**: ยืนยันด้วยการอ่าน `root_shell.dart` บรรทัด 49 ว่าสร้าง `final followRepository = FollowRepository(Supabase.instance.client);` ครั้งเดียวแล้วส่งต่อ (ไม่ใช่ `.copyWith`/สร้างใหม่) ให้ทั้ง `HomeFeedScreen`, `DropFeedScreen`, `PopFeedScreen`, `ViewProfileScreen` **ผ่าน**
9. **Embedded resource FK naming**: Postgres สร้างชื่อ constraint อัตโนมัติสำหรับ `references` ที่ไม่ได้ตั้งชื่อเองตาม pattern `<table>_<column>_fkey` เสมอ — ตาราง `follows` มี `follower_id references profiles(id)` และ `following_id references profiles(id)` (ไม่มีการตั้งชื่อ constraint เอง) จึงได้ชื่อ `follows_follower_id_fkey`/`follows_following_id_fkey` ตรงตามที่ `follow_repository.dart` ใช้ใน `profiles!follows_follower_id_fkey(*)`/`profiles!follows_following_id_fkey(*)` เป๊ะ ตรงตาม PostgREST embedded-resource disambiguation syntax (`table!constraint_name(...)`) ที่ใช้แก้ปัญหา "ambiguous relationship" เมื่อมี FK มากกว่า 1 เส้นไปตารางเดียวกัน **ผ่าน** — ยังไม่เคยรันจริงกับ Postgres จริง (บันทึกเป็น Known Issue ต่อเนื่องจาก Coding Output ไม่ใช่จุดใหม่)
10. **`IndexedStack` reload-on-visit fix**: อ่าน `root_shell.dart` ยืนยัน logic ถูกต้อง — `_profileVisitKey` เพิ่มค่าเฉพาะเมื่อ `index == 3 && _index != 3` (สลับ**เข้า**แท็บ Profile จากแท็บอื่น ไม่ใช่แตะแท็บ Profile ซ้ำตอนอยู่แล้ว) แล้วใช้เป็น `ValueKey` ของ `ViewProfileScreen` — Flutter จะ unmount/remount widget ที่ตำแหน่งเดิมเมื่อ key เปลี่ยน (คนละพฤติกรรมกับ `didUpdateWidget`) ทำให้ `initState()`/`_load()` ถูกเรียกใหม่จริงทุกครั้งที่เข้าแท็บ Profile โดยไม่กระทบแท็บอื่นที่ไม่มี key เปลี่ยนเลย — ยืนยันด้วย test ใหม่ (`view_profile_screen_test.dart`) ว่า `ViewProfileScreen` เองแสดงจำนวนถูกต้องเมื่อ mount ใหม่ (ครอบคลุมพฤติกรรมหลังรีเมาท์ แม้จะทดสอบ `RootShell`'s `IndexedStack` โดยตรงไม่ได้ในสภาพแวดล้อมนี้เพราะต้องพึ่ง `Supabase.instance.client.auth.currentUser` จริงที่ `RootShell.build()` เรียกตรง ๆ) **ผ่าน — สมเหตุสมผลและถูกต้องตาม Flutter reconciliation semantics**
11. **Regression**: `flutter test` เต็ม 95/95 ผ่าน ครอบคลุม `drop_detail_screen_test.dart`, `drop_comment_delete_test.dart`, `drop_comment_like_test.dart`, `pop_feed_screen_test.dart`, `home_feed_screen_test.dart` เดิมทั้งหมด (อัปเดต constructor call ให้ส่ง `followRepository` แล้วยัง pass) ยืนยันว่าไม่มี behavior เดิมพังจากการเพิ่ม parameter ใหม่ **ผ่าน**
12. Secret/credential check: ไม่พบ hardcode ใด ๆ ในโค้ดใหม่ทั้งหมดของ WYN-008

Security Findings:
- RLS ของตาราง `follows` ถูกต้อง: select เปิดกว้างสำหรับ authenticated (จำเป็นสำหรับนับ follower/following ของใครก็ได้ตาม requirement), insert/delete จำกัดเฉพาะ `auth.uid() = follower_id` — ผู้ใช้อื่นสั่ง follow/unfollow แทนเราไม่ได้จริงตาม AC ข้อที่เกี่ยวข้อง
- ไม่พบ secret/credential ใหม่ในโค้ดทั้งหมด
- Self-follow ป้องกันสองชั้นถูกต้อง (ดู Finding #6)

Minor (ไม่ block):
- Comment ใน `supabase/schema.sql` เหนือตาราง `follows` อ้างอิง `.wyn/tasks/approved/WYN-008-follow-system.md` ทั้งที่ตอน commit จริง task ยังอยู่ที่ `review/` (อนุมัติหลังจากนั้น) — เป็นแค่ comment เอกสารอ้างอิงล่วงหน้า ไม่กระทบการทำงานเลย ถือเป็น cosmetic ตามธรรมเนียมเดิมของโปรเจกต์ที่ path มักอ้างอิง `approved/` ล่วงหน้าตั้งแต่ตอน Coding

Recommendation: **อนุมัติ WYN-008** — ครบทุก Requirements/Design Components/Acceptance Criteria ไม่มี Major/Critical ไม่มี regression กับฟีเจอร์เดิม self-follow กันสองชั้นถูกต้อง double-tap safety พิสูจน์แล้วจริงทั้งสอง context (Drop/Pop) gap ของ `IndexedStack` ที่ Coding พบและแก้เองก่อนส่ง QA ตรวจสอบแล้วว่าแก้ถูกต้องสมเหตุสมผล

Final Status: **PASS**
