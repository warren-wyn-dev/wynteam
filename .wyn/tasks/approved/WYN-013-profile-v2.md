# Product Task — WYN-013

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS รอบ 1) → AI Deploy & DevOps (รอ infra จาก Founder)

Feature: Profile V2 (โปรไฟล์ของคนอื่น + Followers/Following + Drop grid + Pop list + Saved tab)

Goal: ให้ `ViewProfileScreen` ใช้ดูโปรไฟล์ของ**ใครก็ได้**ไม่ใช่แค่ตัวเอง พร้อมแสดงเนื้อหาของเจ้าของโปรไฟล์ (Drop/Pop) และเนื้อหาที่บันทึกไว้ (Saved — เฉพาะเจ้าของโปรไฟล์เห็น) เป็นจุดที่ทำให้ WYN-008 (Follow) และความสามารถ Save (มีอยู่แล้วตั้งแต่ WYN-005/006) มี "ที่ทาง" ใช้งานจริงในแอปเป็นครั้งแรก

Target User: วัยรุ่น / Gen Z ที่อยากดูโปรไฟล์ของคนอื่น (จากการแตะชื่อ/avatar ใน Drop/Pop/Home/Followers list) เพื่อดูผลงานทั้งหมดของเขา หรืออยากย้อนดูสิ่งที่ตัวเองเคยบันทึกไว้

Problem: ตอนนี้ `ViewProfileScreen` เปิดได้แค่โปรไฟล์ตัวเอง (เรียกจาก `RootShell` Profile tab เท่านั้น ไม่มี route อื่นเปิดได้) — ผลคือ (1) `FollowListScreen` (WYN-008) ที่แตะรายชื่อ Followers/Following แล้ว "ยังไปไหนไม่ได้" ตามที่ตั้งใจไว้ชั่วคราว (2) ปุ่ม Save ที่มีอยู่แล้วทุกจุดตั้งแต่ WYN-005 ไม่มีที่ให้ดูผลลัพธ์เลย (3) ไม่มีทางดูว่าใครคนหนึ่งเคยโพสต์ Drop/Pop อะไรไว้บ้างนอกจากเลื่อนหา Home ทีละหน้า

Requirements:
- **`ViewProfileScreen` ต้องแสดงโปรไฟล์ของ user ใดก็ได้**: รับ `userId` เป็นพารามิเตอร์เหมือนเดิม (ไม่เปลี่ยน) แต่ต้องพารามิเตอร์ให้ถูกต้องตามว่าเป็นโปรไฟล์ตัวเองหรือคนอื่น — เป็นตัวเอง: เห็นปุ่ม "แก้ไขโปรไฟล์" + ปุ่ม logout เหมือนเดิม; เป็นคนอื่น: เห็นปุ่ม Follow/Unfollow แทน (reuse component เดียวกับที่มีอยู่แล้วใน `DropDetailScreen`/`PopClipView`) **ไม่เห็น**ปุ่มแก้ไข/logout
- **เปิดโปรไฟล์คนอื่นได้จริงจากทุกจุดที่มีอยู่แล้วในแอป**: แตะชื่อ/avatar ผู้เขียนใน `DropDetailScreen`, `PopClipView`, การ์ด Home (`HomeDropCard`/`HomePopCard`), และแถวใน `FollowListScreen` (WYN-008 — ปัจจุบันแตะแล้วไม่ทำอะไรเลยตามที่ตั้งใจไว้ชั่วคราว ตอนนี้ต้องเปิดโปรไฟล์ได้จริง)
- **Drop grid tab**: แสดง Drop ทั้งหมดของเจ้าของโปรไฟล์ (ไม่ใช่ global feed) เป็น grid เหมือน `DropFeedScreen` เดิม (3 คอลัมน์) — แตะแล้วเปิด `DropDetailScreen` ตามปกติ
- **Pop list tab**: แสดง Pop ทั้งหมดของเจ้าของโปรไฟล์ — **ไม่ใช่** full-screen vertical swipe แบบ Pop Feed เดิม (ไม่เหมาะกับการเป็น tab ย่อยในหน้าอื่น) ให้ Design ตัดสินใจ layout ที่เหมาะสม (เช่น thumbnail grid คล้าย Drop) แตะแล้วเปิดดูคลิปนั้น (reuse `PopSingleClipScreen` ที่มีอยู่แล้วจาก WYN-007 ได้ตรง ๆ)
- **Saved tab**: **เห็นเฉพาะเจ้าของโปรไฟล์เท่านั้น** (ไม่แสดง tab นี้เลยเมื่อดูโปรไฟล์คนอื่น — RLS ของตาราง `saves` เดิมก็จำกัดไว้แบบนี้อยู่แล้วตั้งแต่ WYN-005 คือ private โดยดีไซน์) แสดง Drop และ Pop ที่บันทึกไว้**ปนกันเรียงตามเวลาที่บันทึก** (ไม่ใช่ตามเวลาโพสต์) ใหม่สุดก่อน — ดู Risks สำหรับแนวทางเทคนิคที่แนะนำ (reuse pattern database-side view แบบเดียวกับ `home_feed` ของ WYN-007)
- **แถวใน `FollowListScreen` (WYN-008) กดได้จริงแล้ว**: เพิ่ม tap → เปิดโปรไฟล์ของ user แถวนั้น (แก้จากที่ตั้งใจให้ "ยังไปไหนไม่ได้" ในรอบ WYN-008 เป็น "ไปได้แล้ว" ตอนนี้)
- **จำนวน Followers/Following (WYN-008) ยังทำงานเหมือนเดิมทุกประการ** ไม่ว่าจะดูโปรไฟล์ตัวเองหรือคนอื่น — แตะแล้วเปิด `FollowListScreen` ของ user คนนั้น (ไม่ใช่ของตัวเองเสมอไปเหมือนตอนนี้)

Acceptance Criteria:
- [ ] แตะชื่อ/avatar ผู้เขียน Drop ของคนอื่นใน `DropDetailScreen` → เปิดโปรไฟล์ของเขาได้ถูกต้อง
- [ ] แตะชื่อ/avatar ผู้เขียน Pop ของคนอื่นใน `PopClipView`/`PopSingleClipScreen` → เปิดโปรไฟล์ของเขาได้ถูกต้อง
- [ ] แตะการ์ด Home (Drop/Pop) ของคนอื่นที่ส่วนชื่อ/avatar → เปิดโปรไฟล์ของเขาได้ถูกต้อง (ไม่ใช่เปิด Drop/Pop Detail เหมือนแตะส่วนอื่นของการ์ด)
- [ ] แตะรายชื่อใน `FollowListScreen` → เปิดโปรไฟล์ของคนนั้นได้ถูกต้อง
- [ ] เปิดโปรไฟล์ตัวเอง เห็นปุ่มแก้ไขโปรไฟล์ + logout เหมือนเดิม ไม่เห็นปุ่ม Follow (follow ตัวเองไม่ได้)
- [ ] เปิดโปรไฟล์คนอื่น เห็นปุ่ม Follow/Unfollow ทำงานถูกต้อง ไม่เห็นปุ่มแก้ไขโปรไฟล์/logout
- [ ] เปิดโปรไฟล์คนอื่น เห็น Drop grid/Pop list ของเขา ไม่เห็น Saved tab เลย
- [ ] เปิดโปรไฟล์ตัวเอง เห็นทั้ง 3 tab (Drop/Pop/Saved) ครบ
- [ ] แตะ Drop ใน grid → เปิด `DropDetailScreen` ถูกต้อง, แตะ Pop ใน list → เปิดดูคลิปนั้นถูกต้อง
- [ ] บันทึก Drop/Pop ใหม่จากที่ไหนก็ได้ในแอปแล้วเปิด Saved tab ของตัวเอง → เห็นรายการนั้นจริง เรียงจากบันทึกล่าสุดก่อน
- [ ] เอา Drop/Pop ออกจาก Saved (unsave) แล้วกลับมาที่ Saved tab → หายไปจริง
- [ ] จำนวน Followers/Following ที่เห็นตอนดูโปรไฟล์คนอื่นถูกต้องตามข้อมูลจริงของเขา (ไม่ใช่ของเราเอง)
- [ ] Drop/Pop/Home/Follow เดิมทั้งหมดยังทำงานปกติ ไม่มี regression

Dependencies: WYN-005 (Drop — Approved), WYN-006 (Pop — Approved), WYN-007 (Home — Approved, การ์ดต้องเพิ่ม tap-to-profile), WYN-008 (Follow — Approved, ปุ่ม Follow/`FollowListScreen` reuse ตรง ๆ)

Priority: P1 — ตาม roadmap dependency graph เดิม แต่ Founder ยืนยันให้ทำต่อจาก WYN-008 ทันที (ข้าม WYN-009/010 ที่เป็น P2) เพราะเป็นจุดที่ทำให้ Follow/Save มี "ที่ทางใช้งานจริง" (2026-08-14)

Risks:
- **Saved tab ต้องการ pagination ที่ถูกต้องข้าม 2 ตาราง เหมือนปัญหาที่ WYN-007 เจอตอนรวม `home_feed`**: `saves` เก็บแค่ `content_type`/`content_id` ไม่มี FK ตรงไปตาราง `drops`/`pops` (เพราะ 1 คอลัมน์ใช้ชี้ 2 ตารางที่เป็นไปได้) การ fetch แบบ "ดึง saves ของ user แล้ว query drops/pops แยกด้วย id" ธรรมดาจะพอสำหรับ 1 หน้า แต่ paginate ข้ามหลายหน้าจะมีปัญหาเดียวกับที่ WYN-007 เจอ — **แนะนำสร้าง SQL view `saved_feed`** (มิเรอร์แนวทางของ `home_feed`) join `saves` กับ `drops`/`pops` แยกฝั่งด้วย `UNION ALL` กรอง `content_type` ให้ตรง เรียงตาม `saves.created_at` (เวลาบันทึก ไม่ใช่เวลาโพสต์) แล้ว paginate บน view เดียวนั้นตรง ๆ — ต้องมี `security_invoker = true` เพื่อให้ RLS ของ `saves` (private ต่อ user) ยังบังคับใช้ผ่าน view
- **`ViewProfileScreen` ต้องรองรับ 2 persona (เจ้าของ vs คนอื่น) ในโค้ดเดียวกัน**: ความเสี่ยงคือถ้าไม่ระวัง ปุ่มแก้ไข/logout/Follow อาจแสดงผิดเงื่อนไข (เช่น เห็นปุ่ม Follow ตัวเอง) — ต้องเทียบ `userId` พารามิเตอร์กับ `Supabase.instance.client.auth.currentUser!.id` ให้ถูกต้องแบบเดียวกับที่ `isOwnDrop`/`isOwnPop` ทำอยู่แล้ว ไม่ใช่ logic ใหม่ที่ยังไม่เคยพิสูจน์
- **ต้องเพิ่ม repository method ใหม่**: `DropRepository`/`PopRepository` ยังไม่มี "fetch by author" (มีแต่ `fetchFeed` แบบ global) — ต้องเพิ่ม method ใหม่ (เช่น `fetchByAuthor({authorId, page})`) ไม่ใช่ hack `fetchFeed` เดิม เพื่อไม่ให้กระทบ Drop/Pop Feed ที่ผ่าน QA มาแล้ว
- **Pop list tab layout**: Pop Feed เดิม (WYN-006) ออกแบบมาเป็น full-screen vertical swipe โดยเฉพาะ ไม่เหมาะเป็น tab ย่อย — ต้องมี layout ใหม่ (แนะนำ thumbnail grid เหมือน Drop เพื่อความสม่ำเสมอทางสายตา ตาม pattern ที่ WYN-007 วางไว้แล้วสำหรับการ์ด Pop ใน Home ที่ crop เป็น 1:1 + play icon) ให้ Design ตัดสินใจรายละเอียดสุดท้าย
- ยังไม่มี Content Moderation (นอก scope เหมือนทุก feature ก่อนหน้า)

Recommendation:
1. เริ่ม WYN-013 ทันทีตามที่ Founder ยืนยันแล้ว ข้าม WYN-009 (Search)/WYN-010 (Share — ทำไปแล้วบางส่วนตั้งแต่ WYN-005/006/007)/WYN-011 (Save — ทำไปแล้วบางส่วนเช่นกัน) ไปก่อน
2. **รวม scope ที่เหลือของ WYN-011 (Saved tab) เข้ามาใน WYN-013 นี้เลย ไม่แยกทำ WYN-011 เป็น task ต่างหากก่อน** — เหตุผล: (ก) ปุ่ม Save toggle เองทำงานสมบูรณ์แล้วตั้งแต่ WYN-005/006/007 สิ่งที่ขาดมีแค่ "หน้าจอแสดงผล" ซึ่งตรงกับ Saved tab ของ WYN-013 พอดี แยกทำสองรอบจะต้องเขียน query เดียวกัน (join saves กับ drops/pops) ซ้ำสองที (ข) สอดคล้องกับ precedent ที่ WYN-008 เคยรวม scope ของตัวเองให้ครบ (Followers/Following list) แทนที่จะรอ WYN-013 เหมือนกัน — ครั้งนี้เป็นทิศทางตรงกันข้ามที่สมเหตุสมผลเท่ากัน เพราะเนื้อหาที่ต้องดึงมันคาบเกี่ยวกันจริง
3. **Saved tab แสดง Drop+Pop ปนกันเรียงตามเวลาบันทึก** (ไม่แยก 2 tab ย่อย) — เหตุผล: ผู้ใช้บันทึกเพราะ "ชอบเนื้อหานี้" ไม่ได้สนใจว่าเป็นรูปหรือวิดีโอตอนกลับมาดูซ้ำ การแยก sub-tab เพิ่มความซับซ้อนโดยไม่มีประโยชน์ชัดเจน สอดคล้องกับที่ Home (WYN-007) เลือกรวม Drop+Pop เป็น feed เดียวด้วยเหตุผลเดียวกัน

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) `ViewProfileScreen` สองโหมด (เจ้าของ/คนอื่น) ในหน้าเดียวกัน (2) TabBar/สลับ 3 tab (Drop grid/Pop list/Saved) ที่ไม่ลอก Instagram/TikTok โดยตรง (3) layout ของ Pop list tab (4) จุด tap-to-profile ใหม่ทั้งหมด (Drop Detail/Pop Clip/Home card/FollowListScreen) — ต้องตัดสินใจ UX ที่ชัดเจนว่าแตะตรงไหนของแต่ละหน้าจอถึงจะเปิดโปรไฟล์ ไม่ปนกับ tap ที่มีอยู่แล้ว (เช่น แตะการ์ด Home ทั้งการ์ดเปิด Detail อยู่แล้ว ต้องมีจุดแยกสำหรับเปิดโปรไฟล์)

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-013-profile-v2.md` — 6 หัวข้อ: (1) header สองบุคลิกในไฟล์เดียว (2) TabBar 2-3 tab แบบ conditional length ไม่ใช่ disabled tab (3) Drop grid reuse `DropGridTile` ตรง ๆ (4) Pop list เป็น grid 3 คอลัมน์เหมือนกัน ไม่ใช่ full-screen swipe (5) Saved tab grid ผสม Drop+Pop (6) จุด tap-to-profile ใหม่ 4 จุด ขอบเขตเฉพาะ avatar+ชื่อ ไม่ชนกับ tap เดิม

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- Database: เพิ่ม view `saved_feed` ใน `supabase/schema.sql` มิเรอร์ `home_feed` (WYN-007) — `UNION ALL` ระหว่าง `saves` join `drops`/`pops` แยกฝั่งตาม `content_type`, เรียงตาม `saves.created_at` (เวลาบันทึก ไม่ใช่เวลาโพสต์ — คอลัมน์ `saved_at` แยกจาก `created_at` ของเนื้อหาเอง), join `profiles` เข้ามาด้วยตั้งแต่ร่างแรก (ไม่พลาดแบบที่ WYN-007 เคยพลาด), `security_invoker = true` ให้ RLS ของ `saves` (private ต่อ user) ยังบังคับใช้จริงผ่าน view
- `DropRepository.fetchByAuthor`/`PopRepository.fetchByAuthor` (ใหม่): mirror `fetchFeed` แต่ filter ด้วย `author_id` ไม่แก้ `fetchFeed` เดิม
- `lib/features/saved/data/saved_repository.dart` (ใหม่): `SavedRepository.fetchFeed({page})` query view `saved_feed` — **ไม่มี parameter `userId`** เพราะ RLS ของ `saves` จำกัดเฉพาะข้อมูลของผู้เรียกเองอยู่แล้ว ไม่มีแนวคิด "ดู Saved ของคนอื่น" ในระบบเลย ไม่ใช่แค่ UI ซ่อนไว้ reuse `HomeFeedItem` (WYN-007) ตรง ๆ แทนที่จะสร้าง model ใหม่ซ้ำซ้อน (`savedByMe` ถูก set เป็น `true` เสมอเพราะทุกแถวเป็นสิ่งที่ user คนนี้บันทึกไว้โดยนิยาม)
- `lib/features/pop/presentation/widgets/pop_grid_tile.dart`, `lib/features/saved/presentation/widgets/saved_grid_tile.dart` (ใหม่ทั้งคู่): มิเรอร์ `DropGridTile` (WYN-005) — media area 1:1 เท่านั้น ไม่มี caption/แถวปฏิสัมพันธ์ `PopGridTile` ใช้ thumbnail+play icon+duration badge จาก `HomePopCard` (WYN-007), `SavedGridTile` เลือก media ตาม `item.contentType` (Drop→รูปตรง ๆ, Pop→thumbnail+play icon+badge เหมือนกัน)
- `lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart`, `profile_pop_grid_tab.dart`, `profile_saved_tab.dart` (ใหม่ทั้งสาม): แต่ละอันเป็น infinite-scroll grid 3 คอลัมน์ pattern เดียวกับ `DropFeedScreen` (WYN-005) ทุกประการ ต่างแค่แหล่งข้อมูล (`fetchByAuthor`/`SavedRepository.fetchFeed`) ใช้ `AutomaticKeepAliveClientMixin` เพื่อไม่ให้ tab ที่เคยโหลดแล้ว reload ใหม่ทุกครั้งที่สลับกลับมา
- `view_profile_screen.dart`: เพิ่ม `_isOwnProfile` getter (เทียบ `widget.userId` กับ `Supabase.instance.client.auth.currentUser!.id` แบบเดียวกับ `isOwnDrop`/`isOwnPop`), เพิ่มปุ่ม Follow (mirror จาก `DropDetailScreen` ทุกประการ รวม nullable `_isFollowing` pattern) แทนที่ปุ่มแก้ไข/logout เมื่อไม่ใช่โปรไฟล์ตัวเอง, ครอบด้วย `DefaultTabController(length: isOwnProfile ? 3 : 2)` — Saved tab หายไปแบบ conditional list ไม่ใช่ disabled tab, `TabBar` ใช้ icon+label ทุก tab (`Icons.grid_view_outlined`/`Icons.play_circle_outline`/`Icons.bookmark_border`) ไม่ใช่ icon-only แบบ Instagram, `_toggleFollow()` เรียก `_reload()` หลัง toggle สำเร็จเพื่อให้จำนวน Followers ของโปรไฟล์นั้นอัปเดตทันที (เพิ่มเองนอกเหนือจาก spec — ไม่งั้นจำนวนจะค้างจนกว่าจะออกแล้วกลับเข้ามาใหม่)
- เพิ่มจุด tap-to-profile ใน `drop_detail_screen.dart`/`pop_clip_view.dart` (ห่อเฉพาะ `AvatarCircle`+ชื่อด้วย `InkWell` แยกจากปุ่ม Follow/ลบข้าง ๆ ไม่ให้ gesture ชนกัน) และ `home_drop_card.dart`/`home_pop_card.dart` (`InkWell` ใหม่ครอบเฉพาะแถว avatar+ชื่อ ซ้อนอยู่ใน `InkWell` เดิมของทั้งการ์ด — Flutter's gesture arena ให้ widget ที่ specific กว่าชนะ จึงไม่ชนกัน) — ทุกจุด push `ViewProfileScreen(userId: <ผู้เขียน>)` เดิม ไม่สร้างหน้าจอใหม่
- `follow_list_screen.dart` (WYN-008): เปลี่ยนแถวจากไม่มี tap affordance (ตั้งใจไว้ตอน WYN-008 เพราะยังไม่มีปลายทาง) เป็น `InkWell` เปิด `ViewProfileScreen` ของ user แถวนั้นจริง ปรับ Semantics label เป็น `button: true` พร้อมบอกว่า "กดเพื่อดูโปรไฟล์"
- `root_shell.dart`: สร้าง `ProfileRepository`/`SavedRepository` เป็น shared local var (เดิม `ProfileRepository` สร้าง inline ในจุดเดียว ยกออกมาเป็นตัวแปรร่วมเหมือน `dropRepository`/`popRepository`/`followRepository`) ส่งต่อให้ทุกแท็บที่ต้องใช้ — ทุก entry point (`HomeFeedScreen`, `DropFeedScreen`, `PopFeedScreen`, `ViewProfileScreen`) ตอนนี้รับ `profileRepository`/`savedRepository`/(`dropRepository`ในกรณีของ Pop) เพิ่มเพื่อส่งต่อให้จุด tap-to-profile ภายในทำงานได้

Files Changed:
- `supabase/schema.sql` (เพิ่ม view `saved_feed`)
- ใหม่: `app/lib/features/saved/data/saved_repository.dart`, `app/lib/features/pop/presentation/widgets/pop_grid_tile.dart`, `app/lib/features/saved/presentation/widgets/saved_grid_tile.dart`, `app/lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart`, `profile_pop_grid_tab.dart`, `profile_saved_tab.dart`
- แก้: `app/lib/features/drop/data/drop_repository.dart` (`fetchByAuthor`), `app/lib/features/pop/data/pop_repository.dart` (`fetchByAuthor`), `app/lib/features/profile/presentation/view_profile_screen.dart` (rewrite ใหญ่), `app/lib/features/drop/presentation/drop_detail_screen.dart`, `app/lib/features/drop/presentation/drop_feed_screen.dart`, `app/lib/features/pop/presentation/widgets/pop_clip_view.dart`, `app/lib/features/pop/presentation/pop_feed_screen.dart`, `app/lib/features/home/presentation/home_feed_screen.dart`, `app/lib/features/home/presentation/pop_single_clip_screen.dart`, `app/lib/features/home/presentation/widgets/home_drop_card.dart`, `home_pop_card.dart`, `app/lib/features/follow/presentation/follow_list_screen.dart`, `app/lib/features/root/presentation/root_shell.dart` (ทุกไฟล์อัปเดต constructor parameter ให้ส่ง repository ใหม่ที่จำเป็น)
- test ใหม่: `app/test/support/recording_saved_repository.dart`, `app/test/support/recording_profile_repository.dart` (มีอยู่แล้วจาก WYN-008)
- test แก้: `app/test/drop_comment_delete_test.dart`, `drop_comment_like_test.dart`, `drop_detail_screen_test.dart` (เพิ่มเทสต์ tap-to-profile ใหม่), `follow_list_screen_test.dart` (เปลี่ยนเทสต์ "ไม่มี ripple" เป็น "แตะแล้วเปิดโปรไฟล์"), `home_feed_screen_test.dart`, `pop_feed_screen_test.dart` (เพิ่มเทสต์ tap-to-profile), `view_profile_screen_test.dart` (ขยายใหญ่ — persona/tab-count/tab-content), `support/recording_drop_repository.dart`/`recording_pop_repository.dart` (เพิ่ม override `fetchByAuthor`)

Reason: implement ตาม Product spec + Design spec ของ WYN-013 ครบตามขอบเขต — `ViewProfileScreen` ใช้ดูโปรไฟล์ใครก็ได้จริง, Follow/Save มี "ที่ทาง" ใช้งานจริงเป็นครั้งแรก, `FollowListScreen` (WYN-008) ที่ตั้งใจทำแถวกดไม่ได้ไว้ก่อนตอนนี้กดได้จริงแล้ว, Saved tab paginate ถูกต้องข้าม Drop/Pop ด้วย database-side view แบบเดียวกับ `home_feed`

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 102/102 ผ่านทั้งหมด (เพิ่มจาก 95 — 7 เทสต์ใหม่: tap-to-profile ใน `DropDetailScreen`/`PopClipView`/`FollowListScreen`, persona-based header (edit/logout vs Follow), tab count 2 vs 3 ตาม persona, เนื้อหาจริงของแต่ละ tab (Drop/Pop/Saved))
- **พบและแก้ gap เอง 3 จุดก่อนส่ง QA**:
  1. `RootShell`'s `IndexedStack` — ไม่มีปัญหาใหม่จาก WYN-013 เอง (fix ของ WYN-008 ยังใช้ได้) แต่ตรวจซ้ำแล้วว่ายังทำงานถูกต้องหลังเพิ่ม repo ใหม่
  2. Widget test ที่ pump `DropDetailScreen` สองครั้งในบล็อกเดียวกันไม่รีเซ็ต State (testing gotcha เดียวกับที่เจอใน WYN-008 — คราวนี้เจอระหว่างเขียนเทสต์ persona ของ `ViewProfileScreen` ก็เจอเหมือนกัน แก้ด้วยการแยก `RecordingProfileRepository`/`RecordingFollowRepository` คนละชุดต่อ persona ตั้งแต่แรกแทนที่จะ pump ซ้ำ)
  3. `find.bySemanticsLabel()` ใช้ไม่ได้ในเทสต์ที่ไม่ได้เปิด semantics tree ไว้ (`tester.ensureSemantics()`) — ทั้งที่ widget มี `Semantics` label ถูกต้องจริงในโค้ด production (ตรวจสอบด้วย `debugDumpApp()`) เป็นแค่ข้อจำกัดของวิธี assert ในเทสต์ ไม่ใช่บั๊ก แก้ด้วยการ assert บน widget type (`find.byType(SavedGridTile)`) แทน — บันทึกเป็น pattern ใหม่ใน `.wyn/learning/PATTERNS.md`
- **ทำ red→green จริงด้วยตัวเอง**: revert `_isOwnProfile` ให้คืนค่า `true` เสมอชั่วคราว (จำลอง persona-guard bug) รัน `flutter test test/view_profile_screen_test.dart --plain-name "someone else"` → **FAIL จริง** (เจอปุ่มแก้ไขโปรไฟล์ทั้งที่ควรเห็น Follow) restore แล้วรัน `flutter test`/`flutter analyze` ซ้ำ → สะอาด 102/102 อีกครั้ง

Known Issues:
- Followers/Following list (WYN-008) ตอนนี้แตะแล้วเปิดโปรไฟล์ได้จริงตามที่ WYN-013 นี้แก้ไว้แล้ว — ไม่มี known issue ค้างจาก WYN-008 อีกต่อไปในจุดนี้
- ยังไม่มี Notification เมื่อถูก Follow (รอ WYN-012)
- Home ยังไม่กรองตาม Follow (รอ WYN-013 — **หมายเหตุ**: ข้อนี้เป็นเรื่องคนละประเด็นกับ Profile V2 ที่ทำอยู่นี้ Home filtering ยังไม่อยู่ใน scope ของ task นี้ อาจต้องพิจารณาเป็น task แยกในอนาคตถ้า Founder ต้องการ)
- ยังไม่ทดสอบกับ Supabase project จริง (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า) — โดยเฉพาะ view `saved_feed` และ `fetchByAuthor` ที่ query ด้วย `.eq('author_id', ...)` บน `drops`/`pops` ยังไม่เคยรันจริงกับ Postgres จริงเลย (ควรมี index บน `author_id` ถ้ายังไม่มี เพื่อ performance เมื่อข้อมูลโตขึ้น — บันทึกเป็นข้อเสนอปรับปรุง)

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ WYN-013 ก่อนอนุมัติ — เน้นตรวจ: (ก) persona สองแบบไม่ชนกัน โดยเฉพาะ self-follow guard ยังทำงานถูกต้องเมื่อเข้าถึงผ่านเส้นทางใหม่ทั้งหมด (ข) tap-to-profile ไม่ชนกับ tap เดิมของการ์ด Home/Drop Detail/Pop Clip (ค) Saved tab เห็นเฉพาะเจ้าของจริงทั้ง UI และ RLS (ง) regression กับ Drop/Pop/Home/Follow เดิมทั้งหมด (จ) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัด

---

## QA & Security Report — รอบ 1 (AI QA & Security)

```
Feature: WYN-013 Profile V2 (โปรไฟล์คนอื่น + Follow button reuse + Drop/Pop/Saved tabs + tap-to-profile ทั่วแอป)
Environment: flutter analyze + flutter test (static/widget-test level เท่านั้น — ยังไม่มี Supabase project จริง เหมือนทุก feature ก่อนหน้า)
```

**หมายเหตุก่อนเริ่ม**: ไม่เชื่อ Coding Output ว่าทำครบ/ตัวเลข 102/102 เฉย ๆ — sync branch จาก `origin/main` ใหม่ (พบว่า branch ค้าง commit เก่าก่อน merge PR #50 อีกครั้ง) แล้วรัน `flutter analyze`/`flutter test` อิสระด้วยตัวเองใน environment นี้ ก่อนอ่านโค้ดเทียบ spec ทีละบรรทัด

### ไล่ Requirements ทีละบรรทัด (Product spec)
- [x] `ViewProfileScreen` รับ `userId` เหมือนเดิม แสดงปุ่มถูกต้องตาม persona — อ่านโค้ดจริง `_isOwnProfile` เทียบ `widget.userId == Supabase.instance.client.auth.currentUser!.id` แบบเดียวกับ `isOwnDrop`/`isOwnPop` ตรงตามที่ Risks กำหนดไว้ ไม่ใช่ logic ใหม่ที่ไม่เคยพิสูจน์
- [x] เปิดโปรไฟล์คนอื่นได้จากทุกจุด (DropDetailScreen, PopClipView, HomeDropCard/HomePopCard, FollowListScreen) — อ่านโค้ดจริงทั้ง 4+1 จุด ทุกจุด push `ViewProfileScreen(userId: ...)` ตัวเดียวกัน ไม่มีหน้าจอใหม่แยก
- [x] Drop grid tab — `ProfileDropGridTab` reuse `DropGridTile`/grid layout เดียวกับ `DropFeedScreen` จริง ต่างแค่ query (`fetchByAuthor` แทน `fetchFeed`) empty state 2 แบบตาม persona ตรงตาม spec
- [x] Pop list tab — ตีความ "list" ถูกต้องตามที่ Design ตัดสินใจ (grid 3 คอลัมน์ ไม่ใช่ 1 คอลัมน์แนวตั้ง) `PopGridTile` ใช้ media area เดียวกับ `HomePopCard` (thumbnail+play icon+duration badge) ตัดส่วน header/interaction ออกจริง
- [x] Saved tab — เฉพาะเจ้าของเห็น (ซ่อนจริงเมื่อ `!isOwnProfile` — ดูหัวข้อ Security ด้านล่างสำหรับการยืนยันระดับ RLS), Drop+Pop ปนกันเรียงตาม `saved_at` (เวลาบันทึก) ไม่ใช่ `created_at` (เวลาโพสต์) — ยืนยันจาก `saved_repository.dart` line 28: `.order('saved_at', ascending: false)` ตรงกับคอลัมน์ `s.created_at as saved_at` ใน view
- [x] แถวใน `FollowListScreen` กดได้จริงแล้ว — ทั้งแถวห่อด้วย `InkWell` เปิด `ViewProfileScreen(userId: profile.id)` จริง ไม่ใช่ ripple ค้างที่กดไม่ได้จริง
- [x] จำนวน Followers/Following ทำงานเหมือนเดิมทั้งสอง persona แตะแล้วเปิด `FollowListScreen` ของ `widget.userId` (ไม่ใช่ของตัวเองเสมอไป) — อ่านโค้ด `_openFollowList` ยืนยันใช้ `widget.userId` ไม่ใช่ current user id ตายตัว

### ไล่ Design Components ทีละบรรทัด (Screen 1-6)
- [x] Screen 1 — AppBar action (logout เฉพาะ own), ปุ่มใต้ bio (Edit vs Follow mirror `DropDetailScreen` สไตล์เดียวกัน สี Primary Blue), Semantics label Follow ตรงรูปแบบเดียวกับทุกจุดอื่น ("กำลังติดตาม กดเพื่อเลิกติดตาม"/"กดเพื่อติดตาม")
- [x] Screen 2 — `DefaultTabController(length: isOwnProfile ? 3 : 2)` ซ่อน tab Saved แบบ conditional list จริง (ไม่ใช่ disabled tab ค้าง) ทุก tab มี icon+label ไม่ใช่ icon-only ตรงตาม Design Rule
- [x] Screen 3 — reuse `DropGridTile` ตรงตัว 3 คอลัมน์ `SliverGridDelegateWithFixedCrossAxisCount`
- [x] Screen 4 — grid 3 คอลัมน์ (ไม่ใช่ list 1 คอลัมน์) tile ใช้โครงสร้าง `HomePopCard`'s media area จริง เปิด `PopSingleClipScreen` เมื่อแตะ
- [x] Screen 5 — grid 3 คอลัมน์เดียวกัน `SavedGridTile` เลือก media ตาม `contentType` จริง (Drop: รูปตรง ๆ, Pop: thumbnail+play+badge) empty state ข้อความตรงตาม spec เป๊ะ
- [x] Screen 6 — ทุกจุด "เฉพาะ avatar+ชื่อ" เป็น `InkWell`/`Flexible(InkWell(...))` แยกจากปุ่ม Follow/ลบข้าง ๆ ไม่ mark สี/underline แบบลิงก์ ตรงตาม Design Rule; `FollowListScreen` เปลี่ยนเป็นทั้งแถวตามที่ Screen 6 ระบุไว้เฉพาะจุดนี้ (ต่างจาก 4 จุดอื่นที่เฉพาะ avatar+ชื่อ)

### ไล่ Acceptance Criteria ทีละข้อ (แยกจาก Requirements/Design ข้างต้น ตามบทเรียนจาก WYN-005)
1. [x] แตะชื่อ/avatar ผู้เขียน Drop คนอื่นใน `DropDetailScreen` → เปิดโปรไฟล์ถูกต้อง — มี regression test จริง (`drop_detail_screen_test.dart`) ยืนยันด้วย `find.byType(ViewProfileScreen)` และยืนยันไม่ trigger toggleFollow (`toggleFollowCalls == 0`)
2. [x] แตะชื่อ/avatar ผู้เขียน Pop คนอื่นใน `PopClipView`/`PopSingleClipScreen` → เปิดโปรไฟล์ถูกต้อง — มี regression test จริง (`pop_feed_screen_test.dart`)
3. [x] แตะการ์ด Home ที่ส่วนชื่อ/avatar → เปิดโปรไฟล์ (ไม่ใช่ Detail) — **อ่านโค้ดแล้วไม่พบ regression test ถาวรสำหรับจุดนี้ใน `home_feed_screen_test.dart`** (มีแค่ `sharedProfileRepository`/`sharedSavedRepository` เพิ่มเข้ามาเฉย ๆ ไม่มี test เปิดโปรไฟล์จาก Home card) — เขียน widget test ชั่วคราวขึ้นมาเองเพื่อพิสูจน์ functional correctness จริง (แตะ `@namfah` บน `HomeDropCard` → `ViewProfileScreen` เปิดจริง, `DropDetailScreen` ไม่เปิด) **ผ่านจริง** ลบไฟล์ทดสอบชั่วคราวทิ้งหลังยืนยันแล้ว — ดู Minor finding ด้านล่าง
4. [x] แตะรายชื่อใน `FollowListScreen` → เปิดโปรไฟล์ถูกต้อง — มี regression test จริง
5. [x] โปรไฟล์ตัวเอง → Edit+logout, ไม่มี Follow — มี regression test จริง
6. [x] โปรไฟล์คนอื่น → Follow ทำงานถูกต้อง, ไม่มี Edit/logout — มี regression test จริง + ทำ red→green ยืนยันเอง (ดูด้านล่าง)
7. [x] โปรไฟล์คนอื่น → เห็น Drop grid/Pop list, ไม่เห็น Saved tab — มี regression test จริง (`find.text('บันทึก'), findsNothing`, `find.byType(Tab), findsNWidgets(2)`)
8. [x] โปรไฟล์ตัวเอง → 3 tab ครบ — มี regression test จริง
9. [x] แตะ Drop ใน grid → `DropDetailScreen`, แตะ Pop → เปิดคลิปนั้น — มี regression test จริง (content tests ของ `ProfileDropGridTab`/`ProfilePopGridTab` ผ่าน `ViewProfileScreen`)
10. [x] Saved tab แสดงรายการที่บันทึกจริง เรียงบันทึกล่าสุดก่อน — โครงสร้าง query/view ถูกต้อง (`saved_at desc`) ยืนยันด้วย code read + test เนื้อหา Saved tab ผ่าน — **หมายเหตุ**: เหมือนทุก feature ก่อนหน้า ยังไม่มี live Supabase project ให้ทดสอบ end-to-end จริง (save แล้วเห็นจริง) เป็น known limitation เดิมของทั้งโปรเจกต์ ไม่ใช่ gap ใหม่ของ WYN-013
11. [x] Unsave แล้วหายจาก Saved tab — `ProfileSavedTab._openItem` เรียก `_loadInitial()` (reload) หลังกลับจาก Detail/Clip screen เสมอ ตรงตาม pattern เดียวกับ `DropFeedScreen`/Home ที่ผ่าน QA มาแล้ว — ยัง untested แบบ live เหมือนข้อ 10
12. [x] จำนวน Followers/Following ของคนอื่นถูกต้องตามข้อมูลจริงของเขา ไม่ใช่ของเรา — โค้ด `_load()` ใช้ `widget.userId` (ไม่ใช่ current user id) ล้วน ๆ ทั้ง `fetchProfile`/`countFollowers`/`countFollowing` เส้นทางเดียวกับที่ test "own profile" (12/5) พิสูจน์กลไกแล้วว่าแสดงผลถูกต้องจากค่าที่ repository ส่งมา — ไม่มี test แยกยืนยันตัวเลข 3/8 ของ "other profile" โดยเฉพาะ แต่กลไกเดียวกันเป๊ะ ไม่มี branch แยกตาม persona สำหรับตัวเลขนี้เลย ความเสี่ยงต่ำมาก
13. [x] Drop/Pop/Home/Follow เดิมทั้งหมดยังทำงานปกติ ไม่มี regression — `flutter test` เต็ม 102/102 ผ่าน (รันเองอิสระ ไม่เชื่อตัวเลขจาก Coding Output) ครอบคลุม double-tap safety, Share/Comment tap, Follow self-guard เดิมทั้งหมด

### Red→Green Regression Proof (ทำเองอิสระ ไม่เชื่อรายงานจาก Coding Output)
Reproduction Steps:
1. แก้ `_isOwnProfile` ใน `view_profile_screen.dart` ให้ `return true;` เสมอ (จำลอง persona-guard bug ที่จะทำให้เห็นปุ่มแก้ไข+Saved tab ส่วนตัวของเราเองทั้งที่กำลังดูโปรไฟล์คนอื่น)
2. รัน `flutter test test/view_profile_screen_test.dart --plain-name "someone else"`
Expected: FAIL (ต้องเจอปุ่ม Follow ไม่ใช่ปุ่มแก้ไขโปรไฟล์)
Actual: **FAIL จริง** — `Expected: exactly one matching candidate / Actual: []` สำหรับปุ่ม Follow, และเจอปุ่ม "แก้ไขโปรไฟล์" ที่ไม่ควรเจอ ยืนยันว่า test นี้จับบั๊กจริงได้ ไม่ใช่ test ที่ผ่านโดยบังเอิญ
3. Restore โค้ดเดิม รัน `flutter analyze` + `flutter test` เต็มอีกครั้ง → สะอาด 102/102 ทั้งคู่กลับมาเหมือนเดิม

### Security Findings
- **`saved_feed` view**: อ่าน `supabase/schema.sql` จริง ยืนยัน `security_invoker = true` ถูกตั้งจริง (บรรทัด 651) และ `saves` RLS select policy จำกัด `auth.uid() = user_id` (บรรทัด 340-344) เท่านั้น — เพราะ `drops`/`pops`/`profiles` ทั้งสามตารางที่ join เข้ามาใน view เป็น select-all-authenticated (`using (true)`) อยู่แล้ว ตัวที่ทำให้ view นี้ private จริง ๆ คือ RLS ของ `saves` เพียงอย่างเดียว ซึ่งยังบังคับใช้ผ่าน view เพราะ `security_invoker = true` — ยืนยันว่าไม่มีทาง bypass
- **`SavedRepository` ไม่มีช่องให้ inject `userId` คนอื่นได้เลย** — `fetchFeed({required int page})` ไม่มี parameter `userId` ตรวจสอบโค้ดจริงแล้วว่าไม่มีทาง query แทนคนอื่นได้แม้แต่ทาง client-side (สอดคล้องกับที่ Coding Output อ้างไว้)
- **Self-follow guard**: ตรวจ DB constraint `follows_no_self_follow check (follower_id <> following_id)` (WYN-008, ไม่เปลี่ยนใน WYN-013) ยังอยู่ครบ + UI guard `_isOwnProfile`/`isOwnDrop`/`isOwnPop` คำนวณจาก `widget.userId`/`_drop.authorId`/`_pop.authorId` เทียบ current user เสมอ ไม่ว่าจะเข้าถึงผ่านเส้นทางเดิมหรือเส้นทางใหม่ 4+1 จุดที่ WYN-013 เพิ่ม เพราะเป็น getter ตัวเดียวไม่มี branch แยกตาม entry point
- ไม่พบ secret exposure ใหม่ใน diff (ไม่มี API key/credential ใน code changes)

### Regression กับ Drop/Pop/Home/Follow เดิม
`flutter test` เต็ม 102/102 ผ่าน ครอบคลุม double-tap safety (Like ทั้ง Drop/Pop/Home), Share/Comment tap บนการ์ด Home (WYN-007 regression), self-follow guard เดิม, Comment Like/Delete (WYN-005), Pop view-count/mute (WYN-006) — ไม่มี regression จากการเพิ่ม parameter ใหม่ (`profileRepository`/`popRepository`/`dropRepository`/`savedRepository`) ในหลายจุด

Passed: 102/102 (`flutter test`, รันเองอิสระ 2 ครั้ง — ครั้งแรกยืนยันตัวเลขจาก Coding Output, ครั้งที่สองหลัง red→green proof เพื่อยืนยัน restore ถูกต้อง)
Failed: 0
Severity: Minor เดียว (ไม่ block)

Reproduction Steps (Minor): อ่าน `app/test/home_feed_screen_test.dart` ทั้งไฟล์ ไม่พบ test ใด ๆ ที่แตะ avatar/ชื่อบน `HomeDropCard`/`HomePopCard` แล้วยืนยันเปิด `ViewProfileScreen`
Expected: มี regression test ถาวรคุ้มครองจุดนี้ เหมือนที่มีให้ `DropDetailScreen`/`PopClipView`/`FollowListScreen` แล้ว โดยเฉพาะเพราะ Design spec เองก็ระบุว่า Home card เป็นจุดเสี่ยงชนกันมากที่สุด (การ์ดมีทั้ง full-card tap เดิม + ปุ่มย่อยหลายปุ่ม)
Actual: ฟีเจอร์ทำงานถูกต้องจริง (พิสูจน์ด้วย widget test ชั่วคราวที่เขียนขึ้นเองแล้วลบทิ้ง — แตะ `@namfah` บน `HomeDropCard` เปิด `ViewProfileScreen` จริง ไม่เปิด `DropDetailScreen`) แต่ไม่มี test ถาวรป้องกัน regression ในอนาคตถ้ามีใครแก้ `home_drop_card.dart`/`home_pop_card.dart`/`home_feed_screen.dart` ทีหลัง
Recommendation: เพิ่ม regression test สำหรับจุดนี้ใน `home_feed_screen_test.dart` เป็น fast-follow (ไม่ block การอนุมัติรอบนี้เพราะฟีเจอร์ทำงานถูกต้องจริงตามที่พิสูจน์แล้ว และ Acceptance Criteria ข้อ 3 ผ่านจริงในทางปฏิบัติ — เข้าเกณฑ์เดียวกับ Minor ของ WYN-005 รอบ 3/WYN-006/WYN-007 รอบ 2 ที่ไม่กระทบ Acceptance Criteria ที่ทดสอบแล้วว่าผ่านจริง)

Final Status: PASS
```

Handoff: อนุมัติ WYN-013 — ย้ายเข้า `.wyn/tasks/approved/` และส่งต่อ AI Deploy & DevOps (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า)
