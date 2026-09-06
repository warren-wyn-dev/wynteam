# Design — WYN-116 (Club Re-engagement Notifications)

> ต่อยอด Product spec ที่ `.wyn/tasks/backlog/WYN-116-club-reengagement-notifications.md` — อ่านก่อนเริ่ม
> Reuse โครงสร้าง notification เดิมทั้งหมด (WYN-015 club notification triggers, WYN-043/044 `notification_settings`/`internal.notification_enabled()`) — ไม่ออกแบบระบบใหม่ มีแค่ 2 ของใหม่จริง: (1) 2 notification type ใหม่ (2) per-club mute table (เพราะ requirement "ปิดแจ้งเตือนต่อ Club" ไม่มีกลไกเดิมรองรับ)

## สรุปการสำรวจของเดิม (ไม่ต้องคิดใหม่)

1. **Pattern การสร้าง notification**: ทุก type ถูกสร้างผ่าน `security definer` trigger function เดียวเท่านั้น ไม่มี client insert ตรง (ดู `notify_club_post_like()`/`notify_club_post_comment()` เป็นต้นแบบสำหรับ single-recipient, `notify_club_join_request()` เป็นต้นแบบสำหรับ fan-out หลาย recipient)
2. **`notification_settings.club`** มีอยู่แล้วและถูกใช้จริงกับ `club_join_request`/`club_join_approved`/`club_post_like`/`club_post_comment`/`mention_club_post` — 2 type ใหม่ของ WYN-116 (`club_post_new`/`club_post_pinned`) ใช้ category เดียวกันนี้ต่อ ไม่สร้าง category ใหม่
3. **Push (Firebase) code พร้อมเต็มระบบแล้ว** (`supabase/functions/send-push-notification/`) รอแค่ secret จริง — งานนี้แค่ทำให้ 2 type ใหม่ผ่าน mirror ทั้งฝั่ง `_lib.ts`/Dart ให้ครบตั้งแต่วันแรก จะได้ไม่ต้องกลับมาแก้เพิ่มตอน Firebase พร้อมจริง (Requirements ข้อ 4 ของ Product spec)
4. **ไม่มี cron/batch job ใดๆ ในระบบ** (ยืนยันจากคอมเมนต์ `trending` category เอง) — throttle ของ "โพสต์ใหม่" ต้องทำเป็น time-window check ข้างในตัว trigger เอง ไม่ใช่ digest job แยก

## จุดที่ต้องตัดสินใจใหม่

### 1. Notification types ใหม่ 2 ตัว
- `club_post_new` — โพสต์ใหม่ (ที่ไม่ใช่โพสต์ของตัวเอง) ใน Club ที่เป็นสมาชิก approved
- `club_post_pinned` — มีคนปักหมุดโพสต์ใหม่ใน Club (แยกจาก `club_post_new` เพราะ Product ให้ priority สูงสุด ไม่ throttle เลย ต่างจากโพสต์ทั่วไป)

ทั้งคู่ fan-out ไปหา **สมาชิกที่ approved ทุกคนของ Club นั้น** (ไม่ใช่แค่ owner/admin เหมือน `club_join_request`) ยกเว้นตัวผู้กระทำเอง (คนโพสต์ / คนปักหมุด) — ผู้เขียนโพสต์เองก็ควรได้รับแจ้งเตือนตอนโพสต์ตัวเองถูกปักหมุด (เป็นเรื่องน่ายินดี) จึงไม่ exclude author ออกจาก `club_post_pinned`, exclude แค่ `auth.uid()` (คนกดปักหมุด) เท่านั้น

### 2. Throttle "โพสต์ใหม่" (Product บอกให้ Design กำหนด threshold เอง)
**ตัดสินใจ: จำกัดไม่เกิน 1 แจ้งเตือน `club_post_new` ต่อ (ผู้รับ, Club) ทุกหน้าต่างเวลา 3 ชั่วโมง** — เช็คโดยดูว่ามีแถว `club_post_new` ของ (recipient, club_id) นี้ที่ `created_at > now() - interval '3 hours'` อยู่แล้วหรือยัง ถ้ามีแล้วข้ามไปเลย (โพสต์ที่ 2, 3, ... ในหน้าต่างเดียวกันไม่แจ้งซ้ำ ไม่ต้องทำ digest/batch message เพราะเพิ่ม complexity โดยไม่จำเป็น — ผู้ใช้เปิดแอปมาก็เห็นโพสต์ที่พลาดไปเองอยู่แล้วใน feed)

**เหตุผลเลือก 3 ชั่วโมง**:ยาวพอกันไม่ให้ Club ที่โพสต์ถี่ (หลายโพสต์ต่อชั่วโมง) ยิงแจ้งเตือนรัวจนคนปิดแจ้งเตือนทั้งหมดทิ้ง (ความเสี่ยงที่ Product ระบุไว้ตรงๆ) แต่สั้นพอที่จะยังทำหน้าที่ "ดึงกลับมาเปิดแอป" ได้จริงในวันเดียวกัน ไม่ใช่แค่วันละครั้งซึ่งอาจช้าเกินไปสำหรับ Club ที่มีกิจกรรมช่วงเช้า-เย็นต่างกัน — ตัวเลขนี้ไม่มี A/B data รองรับ (ระบบยังไม่มี analytics สำหรับ tune ค่านี้) จึงเลือกค่ากลางที่ปลอดภัยไว้ก่อน ปรับได้ภายหลังจาก QA/production feedback โดยไม่ต้องแก้โครงสร้าง (แก้แค่ `interval '3 hours'` ในฟังก์ชันเดียว)

`club_post_pinned` **ไม่ throttle เลย** ตาม Acceptance Criteria ที่ระบุตรงๆ ว่า "เห็นแจ้งเตือนโพสต์ Pin ใหม่ทุกครั้งที่เกิดขึ้นจริง"

### 3. Per-Club mute (Requirements ข้อ 3)
**ตัดสินใจ: ตารางใหม่ `club_notification_mutes (user_id, club_id)`** มิเรอร์ `conversation_mutes` เป๊ะ (RLS insert/delete ธรรมดา ไม่ต้องมี RPC) — **ขอบเขตของ mute นี้ครอบคลุมเฉพาะ `club_post_new`/`club_post_pinned` (2 type ใหม่ของงานนี้) เท่านั้น** ไม่ครอบคลุม `club_post_like`/`club_post_comment`/`mention_club_post`/`club_join_request`/`club_join_approved` ที่มีอยู่แล้ว เพราะ type เดิมทั้งหมดเป็นแจ้งเตือนเกี่ยวกับ**เนื้อหาของตัวเอง**(คนไลค์/คอมเมนต์/mention โพสต์ของฉัน, คำขอเข้าร่วมที่ต้องอนุมัติ) ซึ่งยังมีประโยชน์แม้จะปิดแจ้งเตือน "กิจกรรมทั่วไป" ของ Club นั้นไปแล้ว — ตรงกับเจตนาจริงของ requirement ("ปิดแจ้งเตือนต่อ Club" ถูกเขียนอยู่ในบริบทของฟีเจอร์นี้โดยเฉพาะ ไม่ใช่ all-or-nothing ของทุก type)

**UI**: เพิ่มแถว "ปิดการแจ้งเตือน Club นี้" / "เปิดการแจ้งเตือน Club นี้" ใน More menu ของ `ClubPage` (`_openMoreMenu`) — แสดงให้สมาชิกที่ approved ทุกคน (ทั้ง staff และสมาชิกทั่วไป) ไม่ผูกกับ role เหมือนแถวอื่นๆ ที่มีอยู่ วางเป็นแถวแรกเสมอเมื่อ approved

## Schema ที่แนะนำ (มิเรอร์ pattern เดิมเป๊ะ)

1. เพิ่ม `'club_post_new', 'club_post_pinned'` เข้า `notifications_type_check` constraint
2. ตารางใหม่ `club_notification_mutes (user_id, club_id, created_at)` — RLS เหมือน `conversation_mutes`
3. `notify_club_post_new()` — `after insert on club_posts` — fan-out ทุกสมาชิก approved ยกเว้นผู้โพสต์เอง, เช็ค `internal.notification_enabled(recipient, 'club')`, เช็ค `not exists (select 1 from club_notification_mutes where user_id=recipient and club_id=new.club_id)`, เช็ค throttle 3 ชม. ต่อ (recipient, club_id) — **ข้าม Poll Club Post ไม่ได้พิเศษอะไร** (โพลก็คือโพสต์ปกติ ควรแจ้งเตือนเหมือนโพสต์อื่น ไม่มีเหตุผลแยก)
4. `notify_club_post_pinned()` — `after update on club_posts when (old.pinned=false and new.pinned=true)` — fan-out ทุกสมาชิก approved ยกเว้น `auth.uid()` (ไม่ยกเว้น author เพราะ author เองก็ควรรู้ว่าโพสต์ตัวเองถูกปักหมุด), เช็ค `notification_enabled`+mute เหมือนกัน ไม่ throttle
5. Regression test ใหม่ `supabase/tests/wyn_116_club_reengagement_notifications_test.sh` มิเรอร์ harness เดิม (`wyn_115_club_poll_test.sh`)

## Flutter ที่แนะนำ

- `notification.dart`: เพิ่ม `clubPostNew`/`clubPostPinned` เข้า `NotificationType` enum + `_typeFromString` (ทั้งคู่ต้องเพิ่มพร้อมกัน ไม่งั้น crash ทั้ง list ตาม postmortem ของ `redrop` ที่มีอยู่แล้วในโค้ด)
- `notification_list_screen.dart`: เพิ่ม message template ใน `_messageFor()` (`'$actor โพสต์ใหม่ใน $club'` / `'$actor ปักหมุดโพสต์ใหม่ใน $club'`) + tap routing ไป `_openClubPost(clubPostId)` เหมือน `club_post_like`/`club_post_comment` — **ไม่เพิ่มเข้า `_groupableTypes`** (throttle ที่ DB จัดการความถี่ให้แล้ว ไม่ต้องเพิ่ม grouping ซ้อนอีกชั้นโดยไม่จำเป็น)
- `supabase/functions/send-push-notification/_lib.ts`: mirror `messageFor()`/`buildDataPayload()` ให้ตรงกับฝั่ง Dart เป๊ะ (ตามกติกาที่ comment หัวไฟล์กำหนดไว้)
- `push_notification_service.dart`: เพิ่ม case ใน `_openFromPushData()` เหมือน type club อื่น
- `ClubPage._openMoreMenu`: เพิ่มแถว mute/unmute ตามข้อ 3 ข้างบน — ต้องเช็คสถานะ muted ปัจจุบันก่อนเปิดเมนู (fetch ครั้งเดียวตอนโหลดหน้า เก็บใน state เหมือน `membership`)
- `ClubRepository`: เพิ่ม `isClubMuted(clubId)`/`muteClubNotifications(clubId)`/`unmuteClubNotifications(clubId)`

## Handoff

AI Coding → AI QA & Security
