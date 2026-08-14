# Product Task — WYN-006

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS รอบ 1) → AI Deploy & DevOps (รอ infra จาก Founder)

Feature: Pop (คลิปสั้นแนวตั้ง)

Goal: ให้ผู้ใช้โพสต์คลิปวิดีโอสั้นแนวตั้งพร้อมแคปชันได้ เป็นเนื้อหาหลักประเภทที่สองของ WYN V0.1 ("WYN V0.1 — CORE APP FEATURE PROMPT" ดู `.wyn/company/DECISIONS.md` 2026-08-14) คู่กับ Drop (WYN-005 — Approved แล้ว)

Target User: วัยรุ่น / Gen Z ที่ต้องการดูและสร้างคลิปวิดีโอสั้นแนวตั้ง มีปฏิสัมพันธ์กับคลิปของคนอื่น

Problem: ตอนนี้ WYN มีแค่ Drop (โพสต์รูปภาพ) เป็นเนื้อหาหลัก ยังไม่มีรูปแบบวิดีโอสั้นเลย ทั้งที่ spec ใหม่กำหนดให้ Pop เป็นหนึ่งใน 4 แท็บหลักของ Bottom Nav — Home (WYN-007) ต้องรอทั้ง Drop และ Pop มีเนื้อหาก่อนถึงจะรวม feed ได้จริง

Requirements:
- **สร้าง Pop**: กดปุ่ม "+ Create Pop" แล้ว:
  - เลือกวิดีโอจากอุปกรณ์ หรือถ่ายวิดีโอใหม่ (ความยาวจำกัด — ดู Risks สำหรับข้อเสนอ limit)
  - เขียน Caption
  - เพิ่ม Hashtag ในแคปชัน (พิมพ์ `#คำ` ระบบรู้จำ — ยังไม่ต้องทำหน้ารวมผลลัพธ์ hashtag ในรอบนี้ ผูกกับ WYN-009 เหมือน WYN-005)
  - Mention ผู้ใช้ในแคปชัน (พิมพ์ `@username` ระบบรู้จำ — ยังไม่ต้องส่ง Notification ในรอบนี้ ผูกกับ WYN-012 เหมือน WYN-005)
  - กด Post
- **วิดีโอ**: อัตราส่วนแนวตั้ง (9:16) เป็นหลักตาม spec — วิดีโอที่ไม่ใช่ 9:16 อยู่แล้วให้ constrain/crop ให้แสดงผลเป็น 9:16 สม่ำเสมอ
- **Vertical swipe feed**: เลื่อนขึ้น/ลงเพื่อไปคลิปถัดไป/ก่อนหน้า ทีละคลิปเต็มจอ (คลิปเดียวเต็มจอเสมอ ไม่ใช่ list/grid) — **ห้ามลอก Layout ของ TikTok โดยตรง** ตามกติกาที่ Founder กำหนดไว้ตายตัว (ดู `.wyn/docs/design/design-principles.md`) ให้ AI Design ตีความสิ่งนี้เป็นโจทย์การออกแบบที่ต้องแก้ ไม่ใช่แค่ก็อปปี้แล้วเปลี่ยนสี
- **แสดงผลคลิปแต่ละอัน**: Profile picture, Username, Caption, ปุ่ม Like/Comment/Share/Save, จำนวน Like, จำนวน Comment, **จำนวน View**
- **Like**: กด Like/Unlike ได้ เห็นจำนวนอัปเดตทันที (ต้องไม่มีบั๊ก double-tap แบบที่เจอใน WYN-004 — pattern ที่ถูกต้องมีอยู่แล้วใน `DropDetailScreen._toggleLike` ให้อ้างอิงตรง ๆ ได้เลยครั้งนี้ ต่างจาก WYN-005 ที่ยังไม่มี pattern ให้อ้างอิงตอนเริ่ม)
- **Comment**: เพิ่ม Comment ได้, **ลบ Comment ของตัวเองได้**, **Like Comment ได้** — ทั้ง 3 ความสามารถต้องมีตั้งแต่รอบแรก (ดู Risks ด้านล่าง: นี่คือจุดที่ WYN-005 พลาดไป 2 รอบติดกันเพราะไม่มี pattern จาก WYN-004 ให้อ้างอิง — รอบนี้ **มี** pattern ที่ถูกต้องแล้วจาก WYN-005 หลัง Debug รอบ 2 ให้ AI Coding อ้างอิงได้ตรง ๆ ไม่มีข้อแก้ตัวให้พลาดซ้ำ)
- **Views**: นับจำนวนครั้งที่คลิปถูกเปิดดู (นับแบบง่ายที่สุดในรอบนี้ — เปิดดูครั้งเดียวนับ 1 ไม่ต้อง dedup ต่อ user/session ในรอบแรก เก็บรายละเอียด dedup ไว้ปรับปรุงทีหลังถ้า Founder ต้องการ)
- **Follow**: กด Follow/Unfollow เจ้าของคลิปได้จากหน้า Pop — ใช้ระบบ Follow เดียวกับที่จะสร้างใน WYN-008 (ยืนยันแล้วว่า Follow ใช้ร่วมกันทั้ง Drop และ Pop ไม่แยกทำสองระบบ) **WYN-006 นี้จะยังไม่สร้างระบบ Follow เอง** เพราะ WYN-008 ยังไม่เริ่ม — ใส่ปุ่ม UI ไว้ก่อนได้แต่ยังไม่ผูก backend จริงจนกว่า WYN-008 จะเสร็จ (ดู Dependencies)
- **Save**: บันทึกคลิปไว้ดูทีหลังได้ — ใช้ตาราง `saves` เดียวกับ WYN-005 (`content_type`/`content_id` ออกแบบรองรับ Pop ไว้แล้วตั้งแต่ต้น ไม่ต้อง migrate schema ใหม่ — เปลี่ยนแค่ `content_type = 'pop'`)
- **Share**: Share Content ออกไปนอกแอป + Copy Link (pattern เดียวกับ WYN-005 — share sheet ของระบบปฏิบัติการ + generate ลิงก์ไปหน้า Pop นั้น ยังใช้ placeholder domain จนกว่า Founder จะยืนยัน domain จริง)
- ผู้ใช้ลบ Pop ของตัวเองได้

Acceptance Criteria:
- [ ] กดปุ่ม "+ Create Pop" เลือกวิดีโอจากอุปกรณ์หรือถ่ายใหม่ พิมพ์ caption (มี/ไม่มี hashtag/mention ก็โพสต์ได้) กด Post แล้วเห็น Pop ใหม่ปรากฏในฟีด
- [ ] Pop ที่ไม่มีวิดีโอ โพสต์ไม่ได้ (วิดีโอเป็น**บังคับ**สำหรับ Pop เหมือนที่รูปภาพเป็นบังคับสำหรับ Drop)
- [ ] วิดีโอแสดงเป็นแนวตั้ง (9:16) สม่ำเสมอทุกคลิป ไม่ว่าไฟล์ต้นฉบับจะเป็นสัดส่วนใด
- [ ] เลื่อนขึ้น/ลง (swipe) เพื่อไปคลิปถัดไป/ก่อนหน้าได้ ทีละคลิปเต็มจอ วิดีโอเล่นอัตโนมัติเมื่อคลิปนั้นอยู่ในจอ หยุดเมื่อเลื่อนออกจากจอ
- [ ] กดไลก์คลิปแล้วเห็นจำนวนไลก์เพิ่มทันที กดซ้ำเพื่อเลิกไลก์ได้ (ต้องไม่มีบั๊ก double-tap)
- [ ] คอมเมนต์ได้ ลบคอมเมนต์ของตัวเองได้ กด Like คอมเมนต์ได้ (**ครบทั้ง 3 อย่างตั้งแต่รอบแรก**)
- [ ] จำนวน View เพิ่มขึ้นเมื่อคลิปถูกเปิดดู
- [ ] กด Share เปิด share sheet ของระบบ หรือ copy ลิงก์ไปยัง clipboard ได้
- [ ] กด Save แล้วบันทึกไว้ได้ (ที่เก็บจริงไปแสดงใน Profile รอ WYN-013 เหมือน Drop)
- [ ] ผู้ใช้เห็นปุ่มลบเฉพาะ Pop ของตัวเองเท่านั้น
- [ ] ผู้ใช้อื่นแก้ไข/ลบ Pop ของเราไม่ได้ (RLS บังคับ)
- [ ] ผู้ใช้อื่นลบไลก์/คอมเมนต์/save ของเราแทนเราไม่ได้ (RLS บังคับ)
- [ ] ผู้ใช้อื่นแก้ไข/ลบคอมเมนต์ของเราแทนเราไม่ได้ (RLS บังคับ)

Dependencies: WYN-002 (Auth — Approved), WYN-003 (Profile — Approved), WYN-005 (Drop — Approved, ใช้เป็นจุดอ้างอิง pattern โดยตรงสำหรับ Like/Comment/Save/Share/schema RLS)

Priority: P0 — เท่ากับ WYN-005 ตาม roadmap dependency graph (ดู `.wyn/docs/product/wyn-v0.1-roadmap.md`) แต่เริ่มหลัง WYN-005 ตามลำดับที่ Founder ยืนยันแล้ว

Risks:
- **Video handling เป็นความเสี่ยงใหม่ที่โปรเจกต์นี้ยังไม่เคยทำมาก่อนเลย** (WYN-002/003/004/005 มีแค่รูปภาพ) — ขนาดไฟล์วิดีโอใหญ่กว่ารูปมาก, ต้องมี compression/encoding ก่อน upload ไม่งั้น Storage และ bandwidth จะโดนกระทบหนัก, ต้องคุยเรื่อง thumbnail (frame แรกหรือ frame ที่กำหนด) สำหรับใช้เป็น placeholder ระหว่างโหลด
- **ความยาวคลิปสูงสุด**: spec ต้นฉบับไม่ได้ระบุตัวเลขชัดเจน เสนอ 60 วินาทีเป็นค่าเริ่มต้น (มาตรฐานทั่วไปของ short-form video, ปรับได้ทีหลังถ้า Founder ต้องการอย่างอื่น) — ให้ AI Design/Coding ล็อกที่ 60 วินาทีไปก่อนในรอบนี้ และ reject วิดีโอที่ยาวเกินตอนเลือกไฟล์ พร้อม error message ชัดเจน
- **Autoplay + เสียง**: TikTok/Reels convention คือ autoplay พร้อมเสียง (ไม่ mute default) — แต่ autoplay-with-sound มีข้อพิจารณาเรื่อง UX/battery/data usage ที่ควรให้ AI Design ตัดสินใจอย่างมีเหตุผล ไม่ใช่แค่ copy convention มาเฉย ๆ (ต้องสอดคล้องกับกติกา "ห้ามลอก Layout ของ TikTok โดยตรง" ด้วย — เป็นได้ทั้งเรื่อง layout และ behavior)
- **View count dedup**: รอบแรกนับแบบง่าย (เปิดดู = +1 ไม่ dedup) อาจทำให้ตัวเลขสูงเกินจริงถ้าผู้ใช้เลื่อนกลับไปกลับมาซ้ำ ๆ — ยอมรับเป็น known limitation ของรอบนี้ (เหมือนที่ WYN-005 ยอมรับ auto-crop แบบไม่มี interactive drag เป็น known limitation) ปรับปรุงทีหลังได้ถ้า Founder ต้องการความแม่นยำมากกว่านี้
- **Storage bucket ใหม่สำหรับวิดีโอ**: ต้องแยกจาก `drop-images` (คนละ bucket, คนละ RLS policy รูปแบบเดียวกัน) เพราะเป็นคนละ content type และขนาดไฟล์ต่างกันมาก
- ยังไม่มี Content Moderation (นอก scope เหมือน WYN-004/WYN-005)
- Follow button ใน UI จะยังไม่ทำงานจริงจนกว่า WYN-008 จะเสร็จ — ต้องตัดสินใจว่าจะซ่อนปุ่มไปก่อนหรือใส่ไว้แบบ disabled ให้ AI Design เสนอทางเลือก

Founder ยืนยันแล้ว (สืบเนื่องจากการตัดสินใจของ WYN-005 ที่ครอบคลุมทั้ง Drop และ Pop ดู `.wyn/company/DECISIONS.md` 2026-08-14):
- Hashtag/Mention รอบนี้ทำแค่ "พิมพ์ในแคปชันได้ ระบบจำ/บันทึกได้" — แตะแล้วไปหน้าค้นหา/โปรไฟล์ผูกกับ WYN-009 ทีหลัง (เหมือน WYN-005)
- Follow (WYN-008 เมื่อถึงคิว) จะใช้ได้กับ Pop ด้วย ไม่ใช่แค่ Drop — ระบบเดียวใช้ร่วมกันทั้งแอป
- Home Feed (WYN-007) จะเป็น Global ก่อน ไม่กรองตาม Follow

Recommendation: ดำเนินการต่อจาก WYN-005 ทันทีตาม roadmap ที่ Founder อนุมัติไว้แล้ว (P0, ลำดับที่ 2 ต่อจาก Drop) — เน้นย้ำให้ AI Design/Coding ไล่ checklist "Comment: เพิ่ม/ลบ/Like" ให้ครบทั้ง 3 อย่างตั้งแต่ต้น โดยอ้างอิงโค้ดของ WYN-005 หลัง Debug รอบ 2 ตรง ๆ (`DropRepository`/`DropDetailScreen` ปัจจุบันมี pattern ที่ถูกต้องครบแล้วทั้ง Like Comment และ Delete Comment) เพื่อไม่ให้เกิดการ "มองข้ามเพราะไม่มี pattern อ้างอิง" ซ้ำเป็นครั้งที่ 3

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบหน้าจอ Pop Feed (vertical swipe), Create Pop, และองค์ประกอบ Comment/Like/Share/Save ที่ใช้ร่วมกับ Pop Detail (ถ้าออกแบบเป็นหน้าแยก) หรือ overlay บนตัว feed เอง (ถ้าออกแบบแบบ TikTok-inspired-but-not-copied) — ให้ AI Design ตัดสินใจและอธิบายเหตุผลว่าทำไมไม่ใช่การลอก Layout ของ TikTok โดยตรง เหมือนที่ WYN-005 อธิบายเหตุผลของ grid-vs-feed ไว้ใน `.wyn/docs/design/wyn-005-drop.md`

---

## Coding Output (AI Coding)

Implementation:
- Database: เพิ่ม section WYN-006 ใน `supabase/schema.sql` — ตาราง `pops` (video_url NOT NULL, thumbnail_url optional, duration_seconds กับ CHECK 1-60, view_count bigint default 0), `pop_likes`, `pop_comments`, `pop_comment_likes` (pattern เดียวกับ `drops`/`drop_likes`/`drop_comments`/`drop_comment_likes` ของ WYN-005 ทุกประการ **รวม Like Comment และ Delete Comment ตั้งแต่ตาราง schema แรก** ตามที่ Design/Product ย้ำไว้ไม่ให้พลาดซ้ำเป็นรอบที่ 3) เพิ่ม `increment_pop_view_count(pop_id)` เป็น `security definer` function สำหรับนับ view (กัน client set view_count เองตรง ๆ) ขยาย `saves.content_type` CHECK ให้รองรับ `'pop'` เพิ่มจาก `'drop'` เดิม (ไม่ต้อง migrate ตารางใหม่ตามที่ WYN-005 ออกแบบไว้) เพิ่ม storage bucket `pop-videos` (เก็บทั้งวิดีโอและ thumbnail ภายใต้ path เดียวกัน ไม่แยก bucket)
- `lib/features/pop/data/`: `pop.dart`, `pop_comment.dart` (mirror `drop.dart`/`drop_comment.dart` ของ WYN-005 field-for-field รวม `withRemovedComment()`/`toggledLike()` ที่ WYN-005 ต้องแก้ทีหลัง ใส่มาตั้งแต่ต้นรอบนี้ เพิ่ม `withExtraView()` ใหม่เฉพาะของ Pop), `pop_repository.dart` (fetchFeed page size 10 แบบ single-column ไม่ใช่ grid, createPop อัปโหลดวิดีโอ+thumbnail แยกกันได้ (thumbnail เป็น optional), deleteComment/toggleCommentLike ใส่มาตั้งแต่แรก, `recordView` เรียกผ่าน RPC ไม่ใช่ direct update)
- `lib/features/pop/presentation/`: `pop_feed_screen.dart` (`PageView.builder` แนวตั้ง, แต่ละคลิปเป็น `_PopClipView` ที่ init/dispose `VideoPlayerController` ตาม active state, overlay UI แบบ scrim ทึบไม่ใช่ Liquid Glass, แถวปฏิสัมพันธ์แนวนอนด้านล่างแทนแถบตั้งขวาแบบ TikTok, mute toggle จำค่าผ่าน `SharedPreferences`, ปุ่ม Follow local-only พร้อม comment ชี้ไป WYN-008), `create_pop_screen.dart` (เลือก/ถ่ายวิดีโอ → ตรวจความยาวผ่าน `VideoPlayerController.initialize()` reject ถ้าเกิน 60 วิ → preview เล่น/หยุดได้ → แคปชัน → แชร์ generate thumbnail ผ่าน `video_thumbnail` แบบ best-effort ไม่ block ถ้า fail), `widgets/pop_comment_sheet.dart` (modal bottom sheet reuse pattern comment list+Like+Delete ของ `DropDetailScreen` เป๊ะ แทนที่จะเป็นหน้าแยกเหมือน Drop เพราะ Pop ไม่ออกจาก vertical feed), `widgets/confirm_delete_pop_dialog.dart` (wrap `confirmDeletePost` เดิม เหมือน Drop)
- `lib/features/root/presentation/root_shell.dart`: แท็บ Pop ชี้ไป `PopFeedScreen` จริงแทน placeholder "เร็ว ๆ นี้"
- `pubspec.yaml`: เพิ่ม `video_player`, `video_thumbnail` ย้าย `shared_preferences` จาก dev_dependencies ไป dependencies จริง (ใช้ใน production code แล้ว ไม่ใช่แค่ test) เพิ่ม `video_player_platform_interface` เป็น dev_dependency สำหรับ fake platform ที่ใช้ทดสอบ

Files Changed:
- `supabase/schema.sql` (เพิ่ม section WYN-006, ขยาย `saves` CHECK)
- `app/lib/features/pop/` (ใหม่ทั้งหมด — data/ 3 ไฟล์, presentation/ 2 screens + 2 widgets)
- `app/lib/features/root/presentation/root_shell.dart` (ชี้แท็บ Pop ไปหน้าจอจริง)
- `app/pubspec.yaml` (เพิ่ม dependencies)
- `app/test/pop_test.dart`, `pop_comment_test.dart`, `create_pop_screen_test.dart`, `pop_feed_screen_test.dart`, `pop_comment_sheet_test.dart`, `support/recording_pop_repository.dart`, `support/fake_video_player_platform.dart` (ใหม่ทั้งหมด)

Reason: implement ตาม Product spec + Design Spec ของ WYN-006 (`.wyn/docs/design/wyn-006-pop.md`) ครบตามขอบเขต reuse pattern ของ WYN-005 ตรง ๆ ตามที่ Design ย้ำไว้ โดยเฉพาะ Comment (เพิ่ม/ลบ/Like ครบทั้ง 3 ตั้งแต่ต้น — ไม่พลาดซ้ำเป็นรอบที่ 3)

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 95/95 ผ่านทั้งหมด (รวม test ใหม่ 29 เคสของ WYN-006)
- **ป้องกันบั๊ก double-tap เชิงรุกแล้วพบว่าพลาดจริงระหว่างเขียน**: ฉบับร่างแรกของ `_PopClipView._toggleLike` อ่าน `widget.pop` (ค่าที่ถูก capture ไว้ตอน build จาก parent) แทนที่จะอ่าน state ของตัวเองสด ๆ — เขียน regression test (`pop_feed_screen_test.dart`) แล้วพบว่า FAIL จริงตั้งแต่รอบแรกที่เขียน (ไม่ใช่แค่ทฤษฎี) ก่อนแก้เป็นให้ widget เก็บ `_pop` เป็น local mutable state ของตัวเอง (mirror `DropDetailScreen._drop` ของ WYN-005) แล้ว pass — พิสูจน์ทั้ง red และ green จริงเช่นเดียวกับทุกรอบก่อนหน้า
- **สร้าง test double ใหม่สำหรับ `video_player`**: `test/support/fake_video_player_platform.dart` implement `VideoPlayerPlatform` แบบง่าย (emit `VideoEvent.initialized` ทันที) ให้ `VideoPlayerController.initialize()` สำเร็จแบบ deterministic ในสภาพแวดล้อมทดสอบที่ไม่มี platform channel จริง (ปกติจะ throw `MissingPluginException`) — ทำให้ทดสอบ view recording และ mute/volume propagation ได้จริง ไม่ใช่แค่ code review เฉย ๆ เหมือนที่ยอมรับไว้สำหรับ `Image.network` ใน Drop เพราะ Pop มี behavior (view count, mute) ที่ผูกกับความสำเร็จของการเล่นวิดีโอโดยตรง
- Comment (เพิ่ม/ลบ/Like) ทดสอบครบทั้ง 3 ความสามารถตั้งแต่รอบแรกใน `pop_comment_sheet_test.dart` (ownership-based visibility, double-tap safety ของ Like, ลบแล้วหายจาก list + แจ้ง count เปลี่ยนถูกต้อง)

Build: ยังไม่ได้ build จริง (`flutter build apk/ios`) — sandbox นี้ไม่มี Android SDK/Xcode ให้ verify ได้ เหมือนทุก feature ก่อนหน้า

Known Issues:
- ไม่มี interactive video trim/crop ในรอบนี้ — จำกัดความยาว 60 วินาทีแบบ reject-only ตามที่ Design ยอมรับเป็น known limitation ของรอบแรก (เหมือน auto-crop ของ Drop)
- View count ไม่ dedup ต่อ user/session — เปิดดูซ้ำนับซ้ำได้ ตามที่ Product ยอมรับไว้เป็น known limitation ของรอบแรก
- Share/Copy Link ใช้ placeholder domain (`wyn.app`) เหมือน Drop — ต้องทบทวนก่อน Deploy จริงเมื่อ Founder ยืนยัน domain
- Hashtag/Mention ยังเป็นแค่ข้อความดิบใน caption ไม่มี parsing/แตะได้ (ตามขอบเขตเดียวกับ WYN-005 — ผูกกับ WYN-009 ทีหลัง)
- ปุ่ม Follow เป็น UI-only ไม่ผูก backend จริง (ตามที่ Design ระบุไว้ตรง ๆ — รอ WYN-008)
- ยังไม่ทดสอบกับ Supabase project จริง หรือ platform channel จริงของ `video_player`/`video_thumbnail` (รอ infra จาก Founder และ Android SDK/Xcode)

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ WYN-006 ก่อนอนุมัติ deploy — เน้นตรวจ: (ก) Comment ครบทั้ง 3 ความสามารถจริง ไม่ใช่แค่ 1-2 อย่างเหมือนที่ WYN-005 พลาดสองรอบ (ข) RLS ของตารางใหม่ทั้งหมดถูกต้องตาม pattern WYN-005 (ค) video controller lifecycle (dispose เมื่อเลื่อนออกจอจริง ไม่ leak) (ง) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัดตั้งแต่รอบแรก (บทเรียนจาก WYN-005 QA รอบ 2-3)

---

## QA & Security Report — รอบ 1 (AI QA & Security)

Feature: WYN-006 — Pop (คลิปสั้นแนวตั้ง)

Environment: Code review + static analysis บน `main` หลัง merge PR #37 (Flutter SDK 3.47.0 stable) — เงื่อนไขเดียวกับทุก feature ก่อนหน้า (ไม่มี Supabase project จริง, ไม่มี Android SDK/Xcode, ไม่มี platform channel จริงของ `video_player`/`video_thumbnail`)

Test Cases:
1. `flutter analyze` ซ้ำอย่างอิสระ
2. `flutter test` ซ้ำอย่างอิสระ
3. **ไล่ Product Requirements ทุกบรรทัดกับโค้ดจริง** (แยกหัวข้อ ไม่รวมกับ Design/AC — บทเรียนจาก WYN-005)
4. **ไล่ Design Components ของทั้ง 2 หน้าจอ + ทิศทางภาพรวมทุกบรรทัดกับโค้ดจริง** (แยกหัวข้อ)
5. **ไล่ Acceptance Criteria ทุกข้อกับโค้ดจริง** (แยกหัวข้อ) — โดยเฉพาะ Comment 3 ความสามารถ
6. ตรวจ RLS ของ `pops`/`pop_likes`/`pop_comments`/`pop_comment_likes` เทียบกับ pattern ของ WYN-005 ทุกตาราง
7. ตรวจ security ของ `increment_pop_view_count` RPC (ป้องกัน client set view_count เองได้หรือไม่)
8. ตรวจ video controller lifecycle: dispose เมื่อ inactive จริงหรือไม่ (โค้ดจริง ไม่ใช่แค่อ่าน comment)
9. ตรวจ double-tap safety ของ Like/Save/Comment Like ด้วยการย้อน fix กลับไปเป็นบั๊กชั่วคราวเอง (ไม่เชื่อแค่ Coding Output ว่าทดสอบแล้ว) ยืนยัน red→green ด้วยตัวเอง
10. ตรวจว่าปุ่ม Follow เป็น UI-only จริง ไม่มี call ไป backend
11. ตรวจ regression กับ WYN-005 จากการขยาย `saves.content_type` CHECK
12. Secret/credential exposure check ในโค้ดใหม่ทั้งหมด

Passed: 12/12 (ไม่มีข้อ FAIL) — พบ 2 ข้อสังเกตระดับ **Minor** ที่ไม่ block การอนุมัติ (ดูด้านล่าง)

Failed: 0/12

Severity: **Minor**

### รายละเอียดการตรวจแต่ละข้อ

**#3 Product Requirements** — ครบทุกบรรทัด: สร้าง Pop (เลือก/ถ่ายวิดีโอ+caption+hashtag/mention พิมพ์อย่างเดียว+Post), วิดีโอ 9:16 (`AspectRatio(9/16)` ใน Create + `BoxFit.cover` เต็มจอใน Feed), vertical swipe feed ทีละคลิป, แสดงผล (avatar/username/caption/4 ปุ่ม/like count/comment count/**view count**), Like (double-tap safe ตรวจแล้ว), **Comment (เพิ่ม/ลบ/Like ครบทั้ง 3 จริง — ตรวจโค้ด `pop_comment_sheet.dart` เองบรรทัดต่อบรรทัด ไม่ใช่แค่เชื่อ Coding Output)**, Views (นับผ่าน RPC), Follow (UI-only ตามที่ระบุ), Save (ใช้ `saves` table ร่วมกับ Drop), Share (share sheet + copy link), ลบ Pop ของตัวเอง — ผ่านหมด

**#4 Design Components** — ตรวจทั้ง 2 หน้าจอ:
- Screen 1 (Pop Feed): video เต็มจอ 9:16 cover ✓, แถบข้อมูลผู้โพสต์ (avatar+ชื่อ+Follow+ปุ่มลบเฉพาะเจ้าของ) ✓, **แถวปฏิสัมพันธ์แนวนอนด้านล่างแทนแถบตั้งขวาแบบ TikTok** ✓ (ตรวจโค้ดจริงว่าทุกปุ่มอยู่ใน `Row` เดียวที่ `Positioned(bottom: 16)` ไม่ใช่ `Column` ทางขวา — ตรงตามเจตนาการออกแบบจริง), gradient scrim ทึบไม่ใช่ Liquid Glass ✓ (ตรวจว่าไม่มี `BackdropFilter`/`ImageFilter.blur` ที่ไหนเลยในไฟล์), mute toggle จำค่าผ่าน `SharedPreferences` ✓, comment sheet เป็น modal ไม่ใช่หน้าแยก ✓ (วิดีโอเล่นต่อเบื้องหลังจริง เพราะ sheet ไม่ pop ตัว `_PopClipView` ออกจาก tree)
- Screen 2 (Create Pop): AppBar close+title+share ✓, action sheet เลือก/ถ่าย ✓, preview 9:16 เล่น/หยุดได้ ✓, caption+counter 500 ✓, แถบความยาว "m:ss / m:ss" ✓ (ตรวจพบว่า Coding แก้ format bug ไปแล้วระหว่างทาง — เดิมจะโชว์ "0:60" ผิดสำหรับวิดีโอเต็ม 60 วิ ตอนนี้โชว์ "1:00" ถูกต้อง), share disabled จนกว่ามีวิดีโอผ่านตรวจความยาว ✓, error state ไม่เสียข้อมูล ✓
- **ข้อสังเกต Minor**: Design spec ระบุ Accessibility ไว้ตรง ๆ ว่า "ปุ่ม Like/Save/**Follow**/mute ประกาศสถานะปัจจุบันเสมอ" (พร้อมตัวอย่าง "กดเพื่อ...") — ปุ่ม Like/Save/mute มี `Semantics(label: ...)` ครบตามรูปแบบนี้จริง แต่ปุ่ม Follow (`OutlinedButton` แสดง "ติดตาม"/"กำลังติดตาม") ไม่มี `Semantics` wrapper แบบเดียวกัน อาศัยแค่ข้อความปุ่มที่เปลี่ยนเอง (screen reader ยังอ่านสถานะได้ผ่านข้อความปุ่ม แต่ไม่มี hint "กดเพื่อ..." เหมือนปุ่มอื่น) — ไม่ block เพราะยังทำงานได้ ไม่ใช่ capability ที่หายไป

**#5 Acceptance Criteria** — ครบทุกข้อ (13/13 checkbox) รวมถึงข้อที่ WYN-005 เคยพลาดสองรอบ: "คอมเมนต์ได้ ลบคอมเมนต์ของตัวเองได้ กด Like คอมเมนต์ได้" ตรวจยืนยันแล้วว่าโค้ดมีครบทั้ง 3 จริงตั้งแต่การส่งมอบครั้งแรก (`_sendComment`/`_deleteComment` มี ownership check/`_toggleCommentLike` มี double-tap-safe pattern)

**#6 RLS** — ทุกตารางตรงตาม pattern ของ WYN-005 ทุกประการ: select-all-authenticated สำหรับ `pops`/`pop_likes`/`pop_comments`/`pop_comment_likes`, insert/delete จำกัดเฉพาะ `auth.uid()` ของตัวเอง, ไม่มี update policy บน `pops` เลย (ตรวจแล้วว่าตั้งใจ — ดู #7)

**#7 View-count RPC security** — `increment_pop_view_count(pop_id)` เป็น `security definer` และ `pops` ไม่มี update policy เลย ยืนยันว่า client เรียก `update` ตรง ๆ ผ่าน PostgREST ไม่ได้ (ไม่มี policy ให้ผ่าน) ต้องผ่าน RPC เท่านั้นซึ่งทำแค่ `view_count = view_count + 1` ไม่รับ input อื่นที่ set ค่าตามใจได้ — ปลอดภัยตามเจตนา
- **ข้อสังเกต Minor**: RPC ไม่มี rate-limit/anti-abuse ป้องกันการเรียกซ้ำ ๆ เพื่อปั่นยอด view ของ Pop ใดก็ได้ (ต่างจาก over-count จากการเลื่อนกลับไปกลับมาปกติที่ Product ยอมรับเป็น known limitation ไว้แล้ว — นี่คือ deliberate abuse ผ่าน API ตรง ๆ) ไม่ block เพราะ view count เป็นแค่ตัวเลขให้ข้อมูล ไม่มีผลต่อ ranking/algorithm/เงินใด ๆ ใน scope ปัจจุบันของ V0.1 (Advanced Recommendation Algorithm อยู่นอก scope) แนะนำพิจารณาเพิ่ม rate-limit ถ้า view count เริ่มมีผลต่อ business logic ในอนาคต

**#8 Video controller lifecycle** — ตรวจโค้ด `didUpdateWidget` จริง: `isActive: true→false` เรียก `_disposeController()` ทันที (ไม่ใช่แค่ pause), `dispose()` ของ State ก็เรียก `_disposeController()` เสมอ ไม่มี path ไหนที่ controller ค้างไม่ถูก dispose — ถูกต้องตามที่ Design Rules ระบุ

**#9 Double-tap safety** — ทำ red→green ด้วยตัวเอง (ไม่เชื่อแค่ Coding Output): ย้อน `_toggleLike` กลับไปอ่าน `widget.initialPop` (ค่าที่ frozen ตอน build) ชั่วคราว รัน `pop_feed_screen_test.dart --plain-name double-tap` ซ้ำ — **FAIL จริง** (`Expected: [false, true], Actual: [false, false]`) ก่อน restore กลับมาแก้แล้ว **PASS ทั้ง 95 เทสต์** — ยืนยันว่า regression test มีความหมายจริง

**#10 Follow UI-only** — ตรวจโค้ดจริง: `onPressed: () => setState(() => _isFollowing = !_isFollowing)` เป็น local state ล้วน ๆ ไม่มีการเรียก `popRepository`/`_client` ใด ๆ เลยในปุ่มนี้ — ตรงตามที่ Design ตั้งใจ มี comment ชี้ไป WYN-008 ชัดเจน

**#11 Regression กับ WYN-005** — `saves.content_type` CHECK ขยายจาก `in ('drop')` เป็น `in ('drop', 'pop')` เป็นการขยายเพิ่ม (ไม่ narrow) ไม่กระทบแถวเดิม ไม่มีการเปลี่ยน RLS policy ของ `saves` เลย ตรวจ `git diff` ของ commit ที่แก้แล้วว่าไม่มีจุดอื่นในสคีมาของ WYN-005 ถูกแตะเลย

Security Findings:
- ไม่พบ secret/credential hardcode ในโค้ดใหม่ทั้งหมดของ WYN-006
- RLS และ view-count RPC ตรวจแล้วปลอดภัยตามเจตนา (ดู #6/#7 ด้านบน)
- Storage bucket `pop-videos` policy จำกัด insert เฉพาะ path ของ `auth.uid()` ตัวเอง ตรงตาม pattern `drop-images`

Recommendation: **อนุมัติ WYN-006 เข้าสู่ `.wyn/tasks/approved/`** — 2 ข้อสังเกต Minor (Follow accessibility label, view-count RPC ไม่มี rate-limit) ให้บันทึกไว้เป็นรายการปรับปรุงสำหรับรอบถัดไปที่แตะไฟล์เหล่านี้ ไม่ต้องเปิดรอบ Debug แยก

Final Status: **PASS**
