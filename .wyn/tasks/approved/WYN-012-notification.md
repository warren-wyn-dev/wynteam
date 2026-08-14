# Product Task — WYN-012

Status: approved (QA รอบ 1 — PASS)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI QA & Security (เสร็จ — PASS รอบ 1) → AI Deploy & DevOps (รอ infra จาก Founder)

Feature: Notification (แจ้งเตือน Like/Comment/Follow — Mention defer)

Goal: ให้ผู้ใช้เห็นว่ามีใครมาปฏิสัมพันธ์กับตัวเอง (Like Drop/Pop, Comment, Follow) โดยไม่ต้องไล่เช็คเองทุกจุดในแอป

Target User: วัยรุ่น / Gen Z ที่อยากรู้ทันทีว่ามีคนกด Like/Comment ผลงานตัวเอง หรือมีคนใหม่มา Follow โดยไม่ต้องเปิด Drop/Pop/Follower list ของตัวเองไล่เช็คเอง

Problem: ตอนนี้แอปยังไม่มีระบบแจ้งเตือนเลยตั้งแต่เริ่มโปรเจกต์ — ผู้ใช้ต้องเปิด Drop/Pop ของตัวเองไล่ดู Like/Comment เอง หรือเปิด Followers list (WYN-008) เช็คว่ามีคนใหม่มา Follow หรือยัง ทั้งที่ระบบข้อมูลที่จำเป็น (`drop_likes`/`pop_likes`, `drop_comments`/`pop_comments`, `follows`) มีอยู่ครบแล้วตั้งแต่ WYN-005/006/008

Requirements:
- **สร้างตาราง `notifications` ใหม่ populated ด้วย DB trigger** ไม่ใช่ derived view แบบ `home_feed`/`saved_feed` — เหตุผล: `home_feed`/`saved_feed` เป็น "สถานะปัจจุบันของโลก" (query สดได้ทุกครั้งไม่มีปัญหา) แต่ notification คือ "ประวัติเหตุการณ์ที่เกิดขึ้นแล้ว" ที่ต้องมี state เพิ่มเติมต่อแถว (อ่านแล้ว/ยังไม่อ่าน) ซึ่ง derived view เก็บไม่ได้ (ต้องมีตารางแยกเก็บ read-state อยู่ดี ถ้าจะทำ view ก็ต้อง join กับตาราง read-state อีกที ซับซ้อนกว่าตารางเดียวที่จบในตัวโดยไม่ได้ประโยชน์อะไรเพิ่ม) — ใช้ Postgres trigger (`AFTER INSERT` บน `drop_likes`/`pop_likes`/`drop_comments`/`pop_comments`/`follows`) แทนที่จะให้ Flutter code เป็นคน insert แถว notification เอง เพราะ trigger รับประกันว่าทุก insert จริงจะสร้าง notification เสมอ ไม่ขึ้นกับว่า path ไหนของโค้ด client เรียก — ต่างจากถ้าให้ app logic รับผิดชอบเอง ซึ่งเสี่ยงจะมี path ไหนลืม insert ตามไปด้วย (Drop/Pop มี repository คนละตัว)
- **ชนิด notification ที่ทำรอบนี้**: Like (Drop/Pop), Comment (Drop/Pop), Follow — **ไม่ทำ Mention รอบนี้** (ดู Risks สำหรับเหตุผลเต็ม)
- **ไม่แจ้งเตือนตัวเอง**: Like/Comment เนื้อหาของตัวเอง (เช่น comment ใน Drop ตัวเอง) ต้อง**ไม่**สร้าง notification — enforce ที่ trigger function เอง (เทียบ `actor_id` กับเจ้าของเนื้อหา/โปรไฟล์ก่อน insert) ไม่ใช่กรองแค่ตอนแสดงผลฝั่ง UI (Self-follow guard ของ WYN-008 มี DB-level enforcement คู่กับ UI แล้ว — Notification ต้องมี pattern เดียวกัน)
- **Entry point ใหม่**: ไอคอนกระดิ่งพร้อม badge ตัวเลขนับที่ยังไม่อ่าน วางไว้ใน Home (ไม่ใช่ Bottom Nav tab ใหม่ — Bottom Nav เต็ม 4 ช่องอยู่แล้วสำหรับ core content, Notification เป็น utility screen เหมือน Search ที่เพิ่งเข้าทาง icon ไม่ใช่ tab ใหม่ ดู WYN-009)
- **หน้าจอรายการ Notification**: infinite-scroll list (reuse pattern เดียวกับ `FollowListScreen`) แต่ละแถวแสดง avatar+ชื่อผู้กระทำ + ข้อความอธิบาย type-specific ("ถูกใจ Drop ของคุณ" / "แสดงความคิดเห็นใน Pop ของคุณ" / "เริ่มติดตามคุณ") + เวลา แตะแล้วพาไปเนื้อหาที่เกี่ยวข้อง (Like/Comment Drop → `DropDetailScreen`, Like/Comment Pop → `PopSingleClipScreen`, Follow → `ViewProfileScreen` ของผู้ follow)
- **Mark-as-read**: เปิดหน้ารายการ Notification แล้ว mark ทั้งหมดเป็นอ่านแล้วทันที (ไม่ต้อง mark ทีละแถว) — badge ตัวเลขที่ไอคอนกระดิ่งหายไป/เป็น 0 หลังจากนั้น
- **Fetch-on-open + pull-to-refresh — ไม่ทำ Realtime รอบนี้**: โปรเจกต์นี้ยังไม่เคยใช้ Supabase Realtime เลยแม้แต่จุดเดียวในทุก feature ก่อนหน้า (Home/Drop/Pop/Follow/Search ทั้งหมดใช้ fetch-on-open + pull-to-refresh + infinite scroll) — Notification ควรทำแบบเดียวกันเพื่อความสม่ำเสมอและความเสี่ยงต่ำ ไม่ใช่เป็นจุดแรกที่นำเทคโนโลยีใหม่เข้ามา ถ้า Founder ต้องการ badge อัปเดตสด ๆ แบบ real-time ค่อยพิจารณาเป็น fast-follow ทีหลัง

Acceptance Criteria:
- [ ] คนอื่นกด Like Drop/Pop ของฉัน → มี notification ใหม่ปรากฏในรายการ พร้อม badge ตัวเลขเพิ่มที่ไอคอนกระดิ่ง
- [ ] คนอื่น comment ใน Drop/Pop ของฉัน → มี notification ใหม่ปรากฏ
- [ ] คนอื่นเริ่ม Follow ฉัน → มี notification ใหม่ปรากฏ
- [ ] กด Like/Comment เนื้อหาของตัวเอง → **ไม่มี** notification เกิดขึ้นเลย
- [ ] แตะ notification ประเภท Like/Comment บน Drop → เปิด `DropDetailScreen` ของ Drop นั้นถูกต้อง
- [ ] แตะ notification ประเภท Like/Comment บน Pop → เปิด `PopSingleClipScreen` ของ Pop นั้นถูกต้อง
- [ ] แตะ notification ประเภท Follow → เปิด `ViewProfileScreen` ของผู้ follow ถูกต้อง
- [ ] เปิดหน้ารายการ Notification → badge ตัวเลขที่ไอคอนกระดิ่งหายไป (กลายเป็น 0/ไม่แสดง)
- [ ] ยังไม่มี notification เลย → เห็น empty state ที่สื่อความหมายชัดเจน ไม่ใช่ list ว่างเปล่าเฉย ๆ
- [ ] Like/Comment/Follow/Drop/Pop/Home/Search เดิมทั้งหมดยังทำงานปกติ ไม่มี regression (โดยเฉพาะ trigger ใหม่ต้องไม่ทำให้ insert เดิม (Like/Comment/Follow) ช้าลงจนสังเกตได้หรือ fail)

Dependencies: WYN-005 (Drop — Approved), WYN-006 (Pop — Approved), WYN-008 (Follow — Approved), WYN-013 (Profile V2 — Approved, ใช้ `ViewProfileScreen` สำหรับ notification ประเภท Follow)

Priority: P2 — ตาม roadmap เดิม แต่ Founder ยืนยันให้ทำต่อจาก WYN-009 ทันที (ข้ามการทำ WYN-010 Share ให้เป็น task ทางการไปก่อน) หลังดูสรุปภาพรวม roadmap (2026-08-14)

Risks:
- **Mention notification defer รอบนี้ — เหตุผลเดียวกับ hashtag ใน WYN-009**: @mention ในแคปชัน/comment เป็นแค่ข้อความธรรมดาฝังอยู่ในสตริง ไม่เคยถูก parse เป็น entity ที่รู้ user id จริงมาก่อนเลย (ต่างจาก Like/Comment/Follow ที่มีตาราง structured อยู่แล้วสมบูรณ์ ผูก user id ตรง ๆ ทุกแถว) ถ้าจะทำ Mention notification ให้ทำงานได้จริง (ไม่ใช่ placeholder เปล่า) ต้องมี parsing @username ออกจากข้อความ + resolve เป็น user id จริง + ตรวจว่า username ที่ mention มีตัวตนจริง — เป็นงานอีกก้อนที่แยกออกจาก scope การสร้าง notification infra พื้นฐานได้ชัดเจน เสนอแยกเป็น fast-follow task หลัง Like/Comment/Follow notification พิสูจน์ตัวเองแล้วว่าใช้งานได้จริง
- **Trigger-based insert ต้องระวังไม่ทำให้ insert เดิมช้าลง/fail**: `AFTER INSERT` trigger บน `drop_likes`/`pop_likes`/`drop_comments`/`pop_comments`/`follows` รันอยู่ใน transaction เดียวกับ insert เดิม — ถ้า trigger function มี bug (เช่น query ผิด constraint violation) จะทำให้ **insert เดิมล้มเหลวไปด้วย** (เช่น กด Like ธรรมดาแล้ว fail เพราะ trigger notification พัง) ต้องเขียน trigger function ให้ปลอดภัยและทดสอบแยกทุก path (Like Drop/Like Pop/Comment Drop/Comment Pop/Follow) ไม่ใช่แค่ทดสอบ path เดียวแล้วสรุปว่าที่เหลือเหมือนกัน
- **Self-notification guard ต้องอยู่ที่ trigger ไม่ใช่แค่ UI**: ต่างจาก self-follow ที่มี DB `CHECK` constraint ตายตัวได้ (follower_id <> following_id) เพราะ Follow เป็นความสัมพันธ์ระหว่าง user 2 คนโดยตรง — self-notification guard สำหรับ Like/Comment ต้องเทียบ `actor_id` (คนกด Like/Comment) กับ `author_id` ของ Drop/Pop ที่ถูกกระทำ (ต้อง join เพื่อรู้เจ้าของ) เป็น conditional logic ใน trigger function ไม่ใช่ constraint แบบ static — ต้องเขียนและทดสอบให้ครบทุก content type (Drop/Pop)
- **Badge count ต้อง query เร็ว**: `count(*) where recipient_id = me and is_read = false` ควรมี index รองรับ (`recipient_id, is_read`) ตั้งแต่สร้างตาราง ไม่ใช่แก้ทีหลัง เพราะ badge count จะถูกเรียกบ่อยมาก (ทุกครั้งที่เปิด Home)

Recommendation:
1. เริ่ม WYN-012 ทันทีตามที่ Founder ยืนยันแล้ว
2. **สร้างตาราง `notifications` ด้วย DB trigger ไม่ใช่ derived view** — เหตุผลเต็มอยู่ใน Requirements ข้างต้น (ต้องมี mutable read-state ต่อแถวซึ่ง view ทำไม่ได้อยู่ดี)
3. **Mention defer เป็น fast-follow** — เหตุผลเดียวกับ hashtag ของ WYN-009 (ไม่มี entity parsing มาก่อน เป็นงานคนละก้อนจาก notification infra พื้นฐาน)
4. **Fetch-on-open + pull-to-refresh ไม่ทำ Realtime รอบนี้** — สม่ำเสมอกับทุก feature ก่อนหน้าในแอป ไม่ใช่จุดแรกที่นำเทคโนโลยีใหม่เข้ามาโดยไม่จำเป็น
5. **Entry point เป็นไอคอนกระดิ่งใน Home ไม่ใช่ Bottom Nav tab ใหม่** — สม่ำเสมอกับที่ WYN-009 (Search) เพิ่งวางไว้สำหรับ utility screen

Handoff: ส่งต่อ AI Design (`/design`) เพื่อออกแบบ: (1) ตำแหน่ง/รูปแบบไอคอนกระดิ่ง+badge ใน Home (2) หน้ารายการ Notification — โครงสร้างแถว, ข้อความ type-specific ทั้ง 3 ประเภท, เวลา (3) empty state (4) mark-as-read UX (เปิดหน้าแล้ว badge หายทันทีหรือหลังปิดหน้า — ให้ Design ตัดสินใจ)

---

## Design Output (AI Design)

เขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-012-notification.md` — สรุป: (1) ไอคอนกระดิ่งข้าง search bar ใน Home badge cap "9+" (2) `NotificationListScreen` reuse โครงสร้างแถวของ `FollowListScreen` พร้อมข้อความ type-specific ภาษาไทยทั้ง 5 ประเภท (3) relative time เริ่มใช้ครั้งแรกในโปรเจกต์ที่หน้านี้ (4) unread rows มีพื้นหลัง tint (5) mark-as-read ทันทีที่เปิดหน้า แต่ visual unread state คำนวณจาก snapshot ตอน fetch ไม่ re-render ตาม DB state ใหม่

Handoff: ส่งต่อ AI Coding (`/code`)

---

## Coding Output (AI Coding)

Implementation:
- Database: ตาราง `notifications` ใหม่ (recipient_id, actor_id, type, drop_id/pop_id nullable, is_read, created_at) — RLS select/update จำกัดเฉพาะ `recipient_id = auth.uid()` เท่านั้น **ไม่มี insert policy ให้ client เลย** (insert เกิดจาก trigger function เท่านั้นซึ่งเป็น security definer — bypass RLS แบบเดียวกับ `increment_pop_view_count` ของ WYN-006) index บน `(recipient_id, created_at desc)` และ `(recipient_id, is_read)` — trigger function 5 ตัว (`notify_drop_like`, `notify_pop_like`, `notify_drop_comment`, `notify_pop_comment`, `notify_follow`) แต่ละตัว `AFTER INSERT` บนตารางที่เกี่ยวข้อง self-notification guard เทียบ `actor_id`/`user_id` กับเจ้าของเนื้อหาก่อน insert (4 ตัวแรก) — `notify_follow` ไม่ต้อง guard ซ้ำเพราะ `follows_no_self_follow` CHECK constraint (WYN-008) ทำให้ `follower_id = following_id` insert ไม่ผ่านตั้งแต่ต้นอยู่แล้ว
- `DropRepository.fetchById(dropId)`/`PopRepository.fetchById(popId)` (ใหม่ทั้งคู่): fetch เนื้อหาเต็มพร้อม likedByMe/savedByMe สดสำหรับเปิดจาก notification (คืน `null` ถ้าเนื้อหาถูกลบไปแล้ว) — **ตัดสินใจไม่ join Drop/Pop เต็มเข้าไปใน notification fetch เอง** เพราะแถวใน `NotificationListScreen` ไม่แสดงเนื้อหา Drop/Pop เลย (แค่ avatar+ข้อความ) การ fetch ล่วงหน้าทุกแถวจะเสียโดยเปล่าประโยชน์ — fetch เฉพาะตอนแตะจริง (และได้ likedByMe/savedByMe ที่ fresh กว่าด้วย ไม่ใช่ค่าค้างจากตอน notification ถูกสร้าง)
- `app/lib/features/notification/data/notification.dart` (ใหม่ — `WynNotification`, ตั้งชื่อไม่ชนกับ Flutter's built-in `Notification` class), `notification_repository.dart` (ใหม่ — `fetchNotifications`, `countUnread`, `markAllAsRead`, ใช้ embedded-resource disambiguation `profiles!notifications_actor_id_fkey` แบบเดียวกับ `follows` ของ WYN-008 เพราะ `notifications` มี 2 FK ไป `profiles`)
- `app/lib/core/text_utils.dart`: เพิ่ม `relativeTimeLabel(DateTime, {required DateTime now})` ใหม่ — รับ `now` เป็น parameter (ไม่อ่าน `DateTime.now()` ข้างในตรงๆ) เพื่อให้ test pass เวลาคงที่ได้แทนเวลาจริงที่จะทำให้ assertion ไม่เสถียร
- `app/lib/features/notification/presentation/notification_list_screen.dart` (ใหม่): reuse โครงสร้างแถวของ `FollowListScreen` ตรงตาม Design spec, ข้อความ type-specific ครบ 5 ประเภท, `_unreadSnapshot` (Set ของ notification id ที่ unread ตอน fetch ครั้งแรก) ใช้ render highlight แทนการอ่าน `WynNotification.isRead` สดตรงๆ (ตาม Design spec "Mark-as-read timing" เป๊ะ), `markAllAsRead()` เรียกแบบ fire-and-forget (`unawaited`) ทันทีหลัง fetch สำเร็จ, กรณีเนื้อหาถูกลบไปแล้ว (`fetchById` คืน null) แสดง SnackBar แทนที่จะ crash
- `app/lib/features/home/presentation/home_feed_screen.dart`: แถวบนสุดเปลี่ยนจาก search bar เดี่ยวเป็น `Row(Expanded(search bar), ไอคอนกระดิ่ง+badge)` ตาม Design spec เป๊ะ (ไม่มีพื้นหลัง pill, badge cap "9+", ไม่แสดงเมื่อ 0) fetch unread count ตอน `initState` และ refresh อีกครั้งหลังกลับจาก `NotificationListScreen`
- `app/lib/features/root/presentation/root_shell.dart`: สร้าง `NotificationRepository` เป็น shared local ส่งต่อ `HomeFeedScreen`

Files Changed:
- `supabase/schema.sql` (เพิ่มตาราง `notifications` + trigger function 5 ตัว)
- ใหม่: `app/lib/features/notification/data/notification.dart`, `notification_repository.dart`, `app/lib/features/notification/presentation/notification_list_screen.dart`
- แก้: `app/lib/core/text_utils.dart` (`relativeTimeLabel` ใหม่), `app/lib/features/drop/data/drop_repository.dart` (`fetchById` ใหม่), `app/lib/features/pop/data/pop_repository.dart` (`fetchById` ใหม่), `app/lib/features/home/presentation/home_feed_screen.dart`, `app/lib/features/root/presentation/root_shell.dart`
- test ใหม่: `app/test/notification_list_screen_test.dart`, `app/test/support/recording_notification_repository.dart`
- test แก้: `app/test/home_feed_screen_test.dart` (badge/tap-to-notification tests ใหม่), `app/test/support/recording_drop_repository.dart`/`recording_pop_repository.dart` (เพิ่ม override `fetchById`)

Reason: implement ตาม Product spec + Design spec ของ WYN-012 ครบตามขอบเขต — Like/Comment/Follow notification ทำงานจริงผ่าน DB trigger ที่รับประกันว่าไม่มี path ไหนลืม insert, self-notification guard ที่ trigger level ไม่ใช่แค่ UI, mark-as-read ที่ไม่ทำให้ highlight หายก่อนผู้ใช้ทันเห็น

Tests:
- `flutter analyze`: No issues found
- `flutter test`: 124/124 ผ่านทั้งหมด (เพิ่มจาก 110 — 14 เทสต์ใหม่: 10 ใน `notification_list_screen_test.dart` ครอบคลุมข้อความ type-specific ทั้ง 5 ประเภท, empty state, mark-as-read call, unread/read highlight mapping, tap แต่ละประเภทไปถูกหน้า, กรณีเนื้อหาถูกลบไปแล้ว; 4 ใน `home_feed_screen_test.dart` ครอบคลุม badge count/cap "9+"/ซ่อนเมื่อ 0/tap เปิดหน้า)
- **ทำ red→green จริงด้วยตัวเอง 2 จุด**:
  1. Debounce-style self-check บนจุดที่เขียน test แรกแล้วสงสัยว่าอาจ vacuous (unread highlight test) — พบว่า test แรกที่เขียนไว้ ("keeps its highlight...") ใช้ notification เดียว (unread) เทียบ container.color ก่อน/หลัง markAllAsRead ซึ่ง**ไม่จับบั๊กได้จริง** เพราะ `RecordingNotificationRepository.markAllAsRead()` (test double) ไม่ mutate `WynNotification.isRead` ของ list เดิมเลย ทำให้แม้ implementation ที่ผิด (อ่าน `notification.isRead` สดแทน `_unreadSnapshot`) ก็จะผ่าน test เดิมเหมือนกัน — เขียนใหม่ให้มี notification 2 ตัวผสมกัน (unread 1 + read-already 1) เทียบ container.color ของทั้งคู่แยกกัน ทดสอบซ้ำ: เปลี่ยน `isUnread = _unreadSnapshot.contains(...)` เป็น `isUnread = false` เสมอ (จำลอง mapping พัง) → **FAIL จริง** (`Expected: not null, Actual: <null>`) restore แล้วรัน `flutter analyze`/`flutter test` เต็มอีกครั้ง → สะอาด 124/124
  2. (เดิมจาก WYN-009 pattern) ใช้ `RecordingXRepository` ทุกตัวสร้างใน `setUp()`/`setUpAll()` เท่านั้น ไม่เคยสร้าง inline ใน `testWidgets` callback — ระหว่างเขียน `notification_list_screen_test.dart` รอบแรกพลาดจุดนี้ (สร้าง `RecordingNotificationRepository` inline ในหลาย test) เจอ "Timer still pending" error ทันทีที่รัน แก้โดยย้ายทุกตัวไป `setUp()` ตามระเบียบเดิม

Known Issues:
- Mention notification ยังไม่ทำ (ตามที่ Product ตัดสินใจ defer) — เหมือน hashtag ของ WYN-009
- ยังไม่ทดสอบ trigger function จริงกับ Supabase project จริง (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า) — โดยเฉพาะว่า trigger จะไม่ทำให้ insert เดิมของ `drop_likes`/`pop_likes`/`drop_comments`/`pop_comments`/`follows` ช้าลงจนสังเกตได้หรือ fail จริงหรือไม่ เป็นสิ่งที่ทดสอบได้แค่ระดับ code review เท่านั้นในตอนนี้ (ไม่มี live Postgres ให้รัน `EXPLAIN ANALYZE`/integration test จริง)
- Badge count ไม่ real-time (ตามที่ Product ตัดสินใจ) — ต้องกลับมา Home ใหม่หรือเปิด/ปิด NotificationListScreen ถึงจะเห็นตัวเลขอัปเดต ไม่ใช่ push แบบทันที

Handoff: ส่งต่อ AI QA & Security (`/qa`) เพื่อทดสอบตาม Acceptance Criteria ของ WYN-012 ก่อนอนุมัติ — เน้นตรวจ: (ก) self-notification guard ทำงานจริงในทุก trigger function โดยเฉพาะอ่าน SQL logic ตรวจว่า `v_author_id <> new.user_id`/`new.author_id` เทียบถูกทิศจริง (ข) RLS ของ `notifications` ไม่มี insert policy ให้ client จริง (ค) `fetchById` คืน null อย่างปลอดภัยเมื่อเนื้อหาถูกลบ ไม่ throw (ง) unread highlight snapshot ไม่ re-derive จาก DB state ใหม่จริง (จ) badge count/cap "9+"/ซ่อนเมื่อ 0 ถูกต้อง (ฉ) regression กับ Drop/Pop/Home/Follow/Profile/Search เดิมทั้งหมด (ช) ไล่ Requirements/Design Components/Acceptance Criteria แยกกันทั้ง 3 หัวข้อทีละบรรทัด

---

## QA & Security Report — รอบ 1 (AI QA & Security)

```
Feature: WYN-012 Notification (Like/Comment/Follow ผ่าน DB trigger, ไอคอนกระดิ่ง+badge ใน Home)
Environment: flutter analyze + flutter test (static/widget-test level เท่านั้น — ยังไม่มี Supabase project จริง เหมือนทุก feature ก่อนหน้า, ตรวจ trigger/RLS/SQL ด้วยการอ่านโค้ดและให้เหตุผลเท่านั้น ไม่มี live Postgres ให้รันจริง)
```

**หมายเหตุก่อนเริ่ม**: sync branch จาก `origin/main` ใหม่ (พบ commit ค้างก่อน merge PR #59 อีกครั้ง — pattern เดิมที่เจอทุกรอบ) แล้วรัน `flutter analyze`/`flutter test` อิสระเองก่อนอ่านโค้ด — ไม่เชื่อตัวเลข 124/124 หรือคำอธิบาย testing-gap ที่ Coding Output รายงานไว้เฉย ๆ

### ไล่ Requirements ทีละบรรทัด (Product spec)
- [x] ตาราง `notifications` populated ด้วย DB trigger ไม่ใช่ derived view — ยืนยันจริงจาก schema.sql, ให้เหตุผลตรงตามที่ Product ระบุ (ต้องมี mutable read-state ต่อแถว)
- [x] ชนิด notification 3 ประเภท (Like/Comment/Follow) — ยืนยัน type CHECK constraint จำกัดแค่ 5 ค่า (`like_drop`/`like_pop`/`comment_drop`/`comment_pop`/`follow`) ไม่มี mention
- [x] ไม่แจ้งเตือนตัวเอง enforce ที่ trigger — **อ่าน SQL จริงยืนยันทิศทางถูกต้องครบทุกตัว**: `notify_drop_like`/`notify_pop_like` เทียบ `v_author_id <> new.user_id` (คนกด Like), `notify_drop_comment`/`notify_pop_comment` เทียบ `v_author_id <> new.author_id` (คนคอมเมนต์) — ทิศทางถูกต้องทั้งคู่ (เจ้าของเนื้อหา vs ผู้กระทำ ไม่ใช่เทียบผิดตัวจนไม่มีผล) `notify_follow` ไม่มี guard เพิ่มแต่พึ่ง `follows_no_self_follow` CHECK constraint (WYN-008) — **ยืนยันด้วยเหตุผลว่าใช้ได้จริง**: Postgres ตรวจ CHECK constraint ระหว่างการ INSERT ก่อนที่ AFTER trigger จะถูกเรียกเสมอ (CHECK ล้มเหลว = row ไม่ถูก insert เข้า `follows` เลย = trigger ไม่มีทางถูกเรียกด้วย `follower_id = following_id`) ไม่ใช่แค่เชื่อคำอธิบายใน Coding Output
- [x] Entry point ไอคอนกระดิ่งใน Home ไม่ใช่ Bottom Nav tab ใหม่ — ยืนยันจากโค้ด `home_feed_screen.dart` จริง ไม่มีการแก้ `root_shell.dart`'s `NavigationDestination` เลย
- [x] หน้ารายการ Notification reuse โครงสร้างแถวของ `FollowListScreen` — ยืนยันจากโค้ดจริง (avatar 20px, `InkWell` ทั้งแถว, โครงสร้าง Column เดียวกัน)
- [x] Mark-all-as-read ทันทีที่เปิดหน้า — ยืนยัน `unawaited(widget.notificationRepository.markAllAsRead())` เรียกทันทีหลัง fetch สำเร็จจริง
- [x] Fetch-on-open + pull-to-refresh ไม่ใช้ Realtime — ยืนยันไม่มีการ import/ใช้ Supabase Realtime API ใดๆ ในโค้ดทั้งหมด

### ไล่ Design Components ทีละบรรทัด (Screen 1-2)
- [x] Screen 1 — ไอคอนกระดิ่งไม่มีพื้นหลัง pill (ยืนยัน `IconButton` เปล่าไม่มี `Material`/`InkWell` แบบ search bar), badge cap "9+" (`count > 9 ? '9+' : '$count'`), ไม่แสดงเมื่อ 0 (`if (count > 0)`) ตรงตาม spec เป๊ะ
- [x] Screen 2 — ข้อความ type-specific ภาษาไทยทั้ง 5 ประเภทตรงตาม spec คำต่อคำ (ตรวจเทียบแล้ว), relative time 5 ระดับ (เมื่อสักครู่/นาที/ชั่วโมง/วัน/วันที่เต็ม) ตรงตาม spec, unread rows มีพื้นหลัง tint (`Container(color: isUnread ? ... : null)`), empty state ข้อความ+ไอคอนตรงตาม spec เป๊ะ, mark-as-read timing ตรงตาม spec (`_unreadSnapshot` แยกจาก live `isRead` จริง)

### ไล่ Acceptance Criteria ทีละข้อ
1-3. [x] Like/Comment/Follow สร้าง notification ใหม่พร้อม badge — ยืนยันด้วย trigger SQL logic ที่อ่านแล้วถูกต้อง (ไม่มี live DB ให้ทดสอบจริง — known limitation เดียวกับทุก feature ก่อนหน้า)
4. [x] ไม่มี notification เมื่อกระทำกับเนื้อหาตัวเอง — ยืนยันด้วย SQL guard ที่อ่านแล้วถูกต้องครบทั้ง 5 trigger (ดูรายละเอียดด้านบน)
5. [x] แตะ Like/Comment บน Drop → `DropDetailScreen` — มี regression test จริง (2 เทสต์แยก: Like Drop, Comment Drop)
6. [x] แตะ Like/Comment บน Pop → `PopSingleClipScreen` — มี regression test จริง (2 เทสต์แยก)
7. [x] แตะ Follow → `ViewProfileScreen` ของผู้ follow ถูกต้อง (ตรวจ `userId` ตรงกับ `actorId`) — มี regression test จริง
8. [x] เปิดหน้ารายการ → badge หายไป — มี regression test สำหรับ `markAllAsRead()` ถูกเรียกจริง แต่**ไม่มี regression test ถาวรที่ครอบคลุมทั้งวงจร** (เปิดจาก Home → กลับมา → badge query ถูกเรียกซ้ำ) — เขียน widget test ชั่วคราวขึ้นมาเองเพื่อพิสูจน์ functional correctness จริง (เปิด `NotificationListScreen` จาก Home ยืนยัน `markAllAsReadCalls == 1`, กลับมาที่ Home ไม่ throw, `countUnread()` ถูกเรียกซ้ำจริงตาม code path) **ผ่านจริง** ลบไฟล์ทดสอบชั่วคราวทิ้งหลังยืนยันแล้ว — ดู Minor finding ด้านล่าง
9. [x] Empty state ชัดเจน — มี regression test จริง
10. [x] Drop/Pop/Home/Follow/Profile/Search เดิมไม่มี regression — `flutter test` เต็ม 124/124 ผ่าน (รันเองอิสระ 2 ครั้ง)

### Red→Green Regression Proof (ทำเองอิสระ ไม่เชื่อคำอธิบายจาก Coding Output)
Reproduction Steps:
1. แก้ `isUnread = _unreadSnapshot.contains(notification.id)` เป็น `isUnread = true` เสมอ ใน `notification_list_screen.dart` (จำลอง mapping พังไปทิศตรงข้ามจากที่ Coding เคยทดสอบ — เพื่อยืนยันว่า test จับได้ทั้งสองทิศทาง ไม่ใช่แค่ทิศเดียวที่ Coding ลองแล้ว)
2. รัน `flutter test test/notification_list_screen_test.dart --plain-name "was already read is not"`
Expected: FAIL (แถวที่อ่านแล้วต้อง**ไม่มี** highlight แต่โค้ดที่พังจะ hardcode ให้ highlight เสมอ)
Actual: **FAIL จริง** ยืนยันว่า test นี้จับบั๊กได้จริงทั้งสองทิศทาง (Coding ทดสอบทิศ "unread ควร highlight แต่กลับไม่" ส่วน QA ทดสอบทิศตรงข้าม "read แล้วไม่ควร highlight แต่กลับมี")
3. Restore โค้ดเดิม รัน `flutter analyze` + `flutter test` เต็มอีกครั้ง → สะอาด 124/124 ทั้งคู่กลับมาเหมือนเดิม

### Security Findings
- **RLS ของ `notifications`**: ยืนยันมีแค่ select (`recipient_id = auth.uid()`) และ update (`recipient_id = auth.uid()` ทั้ง using/with check) เท่านั้น **ไม่มี insert/delete policy เลย** — client พยายาม insert/delete notification ตรงจะถูก RLS ปฏิเสธจริง ยืนยันจากการอ่าน schema.sql ทั้งไฟล์ไม่พบ policy อื่นนอกเหนือจาก 2 ตัวนี้
- **Trigger functions ทั้ง 5 ตัวเป็น `security definer` + `set search_path = public`** — ยืนยันครบทุกตัว ป้องกัน search_path injection attack แบบเดียวกับ `increment_pop_view_count` (WYN-006) ที่เคยตรวจผ่านมาแล้ว
- **Embedded-resource disambiguation `profiles!notifications_actor_id_fkey`**: ยืนยันด้วยเหตุผลว่าตรงกับ Postgres auto-generated constraint name (`<table>_<column>_fkey`) เพราะ FK ประกาศแบบ inline (`references public.profiles (id)`) ไม่มี `constraint <name>` กำกับเอง — ตรงตาม convention เดียวกับที่ตรวจผ่านมาแล้วใน WYN-008 (`follows_follower_id_fkey`)
- **`fetchById` ปลอดภัยเมื่อเนื้อหาถูกลบ**: ใช้ `.maybeSingle()` ไม่ใช่ `.single()` (คืน `null` แทนการ throw เมื่อไม่พบแถว) และ `NotificationListScreen` เช็ค `if (drop == null)`/`if (pop == null)` ก่อน navigate จริง แสดง SnackBar แทน — มี regression test จริงยืนยันสถานการณ์นี้ (`tapping a notification whose Drop was already deleted...`)
- ไม่พบ secret exposure ใหม่ใน diff

### Regression กับ Drop/Pop/Home/Follow/Profile/Search เดิม
`flutter test` เต็ม 124/124 ผ่าน ครอบคลุมทุก feature เดิมทั้งหมด — จุดเดียวที่แก้ของเดิมคือ `home_feed_screen.dart`'s แถวบนสุด (เปลี่ยนจาก search bar เดี่ยวเป็น Row) ซึ่งมี regression test คุ้มครองแล้ว (search bar ยังกดได้ปกติ, ไอคอนกระดิ่งใหม่ไม่ชนกับ search bar)

Passed: 124/124 (`flutter test`, รันเองอิสระ 2 ครั้ง — ครั้งแรกยืนยันตัวเลขจาก Coding Output, ครั้งที่สองหลัง red→green proof เพื่อยืนยัน restore ถูกต้อง)
Failed: 0
Severity: Minor เดียว (ไม่มี regression test ถาวรครอบคลุมวงจร badge-refresh-after-return เต็มรูปแบบ — ไม่ block)

Recommendation: เพิ่ม regression test ถาวรสำหรับวงจร "เปิด NotificationListScreen จาก Home → กลับมา → badge query ถูกเรียกซ้ำ" ใน `home_feed_screen_test.dart` เป็น fast-follow (ไม่ block การอนุมัติรอบนี้เพราะฟีเจอร์ทำงานถูกต้องจริงตามที่พิสูจน์แล้ว และ Acceptance Criteria ข้อ 8 ผ่านจริงในทางปฏิบัติ — เข้าเกณฑ์เดียวกับ Minor ของ WYN-013 ที่ไม่กระทบ Acceptance Criteria ที่ทดสอบแล้วว่าผ่านจริง)

Final Status: PASS
```

Handoff: อนุมัติ WYN-012 — ย้ายเข้า `.wyn/tasks/approved/` และส่งต่อ AI Deploy & DevOps (รอ infra จาก Founder เหมือนทุก feature ก่อนหน้า)
