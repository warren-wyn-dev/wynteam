# Product Task — WYN-043

Status: approved (Independent QA PASS 2026-08-23 — ดูหัวข้อ "Independent QA" ท้ายไฟล์ — ส่งต่อ AI Deploy & DevOps)
Owner: AI Product Manager

Feature: Notification Types — แก้บั๊ก ReDrop crash + เพิ่ม System notification (Trending/Top 100 เลื่อนออกสโคป)

Goal: task แรกของ Phase 5 (Notification & Settings Expansion) — ปิดช่องว่างของระบบ Notification (WYN-012) ตาม roadmap ที่ระบุไว้ว่า "Notification type ใหม่ (ReDrop/Quote/FollowRequest/MessageRequest/Trending/Top100/System)" — **แต่หลังตรวจโค้ดจริงแล้วพบว่าสโคปที่เหลือจริงต่างจากที่ระบุไว้ในชื่อ task มาก**: ReDrop/Quote/FollowRequest/MessageRequest **มีอยู่แล้วในฝั่ง Database** (เพิ่มไปแล้วล่วงหน้าตอนทำ WYN-032/034/039 ตามที่ comment ในสคีมาระบุตรงๆ ว่า "mirrors message_request's addition (WYN-032) exactly, including going ahead of WYN-043/Phase 5's nominal 'new notification types' slot") — แต่ **พบบั๊กจริงที่ยังไม่มีใครแก้**: `redrop` ถูกเพิ่มใน DB (WYN-034) แล้วแต่**ไม่เคยถูกเพิ่มในฝั่ง Flutter client เลยแม้แต่จุดเดียว** ทำให้ระบบ Notification พังจริงสำหรับผู้ใช้ที่ได้รับ ReDrop

Target User: ผู้ใช้ WYN Social ทุกคนที่ใช้หน้า Notification — ต้องไม่เจอหน้าจอพังเวลามีคนมา ReDrop เนื้อหาตัวเอง และผู้ดูแลระบบ (admin) ต้องส่งประกาศ/แจ้งเตือนด้านความปลอดภัยหรือนโยบายถึงผู้ใช้รายบุคคลได้

Problem: ยืนยันจากการอ่านโค้ดจริงทั้ง 2 ฝั่ง (ไม่ใช่แค่เชื่อชื่อ task ใน roadmap) —

**1. บั๊กจริงที่กำลังใช้งานอยู่ตอนนี้ (P0 — ต้องแก้ก่อนอย่างอื่น)**: `supabase/schema.sql`'s `notifications_type_check` มี `'redrop'` อยู่แล้ว (เพิ่มพร้อม WYN-034, `notify_redrop()` trigger insert แถวจริงทุกครั้งที่มีคน ReDrop) แต่ `app/lib/features/notification/data/notification.dart`'s `NotificationType` enum **ไม่มีค่า `redrop` เลย** และ `_typeFromString()` ไม่มี case รองรับ — เมื่อไหร่ก็ตามที่ `NotificationRepository.fetchNotifications()` ดึงแถวที่ `type = 'redrop'` มา `WynNotification.fromMap()` จะโยน `ArgumentError('Unknown notification type: redrop')` ทันที ซึ่งเกิดขึ้นข้างใน `.map()` ที่ไม่มี try/catch ครอบเลย — **ผลคือ fetch ทั้งก้อนพังทั้งลิสต์ ไม่ใช่แค่แถวนั้นแถวเดียว** เท่ากับว่าผู้ใช้ที่มีคน ReDrop เนื้อหาของตัวเองแม้แต่ครั้งเดียว จะเปิดหน้า Notification ไม่ได้เลยทั้งหน้าตั้งแต่นั้นมา (ทุกแถวอื่นก็มองไม่เห็นไปด้วย) — เป็น regression ที่ค้างมาตั้งแต่ WYN-034 merge เข้า `main` โดยไม่มีใครจับได้ (WYN-034's QA คงไม่ได้ทดสอบเส้นทาง "เจ้าของ Drop เปิดหน้า Notification ของตัวเองหลังถูก ReDrop" ตรงๆ)

**2. `follow_request`/`follow_request_accepted`/`message_request`** ตรวจแล้วมีครบทั้ง 2 ฝั่งจริง (DB + `NotificationType` enum + icon switch + message switch ใน `notification_list_screen.dart`) — **ไม่มีปัญหา ไม่ต้องแก้อะไรเพิ่ม**

**3. "Trending"/"Top 100" ตามชื่อ task เดิม — ยังสร้างไม่ได้จริงในรอบนี้**: ตรวจแล้วยืนยันว่า**ไม่มีโครงสร้างพื้นฐานรองรับเลย** — สถานะ "กำลังนิยม"/"ติด Top 100" ของเนื้อหา (WYN-041/042) เป็นการคำนวณชั่วคราวฝั่ง Dart ทุกครั้งที่เปิดหน้า (`engagementScore()` + fetch แล้ว sort สด ไม่มีการบันทึกผลไว้ที่ไหนใน DB เลย) จึง**ไม่มีข้อมูลอะไรให้ diff ว่า "เพิ่งติดอันดับใหม่หรือยัง"** และระบบนี้**ไม่มี cron/scheduled job infrastructure เลยแม้แต่จุดเดียว** (ยืนยันจาก comment ในสคีมาเองที่ WYN-030 เคยบันทึกไว้ตรงๆ ว่า "no cron/batch job anywhere in this project's infrastructure") การจะรู้ว่า "เนื้อหานี้เพิ่งขึ้น Top 100" ต้องมีกระบวนการรันเป็นระยะ (เช่น ทุกชั่วโมง) มา snapshot อันดับแล้วเทียบกับรอบก่อนหน้า ซึ่งไม่มีกลไกให้รันแบบนั้นได้เลยตอนนี้

**4. "System" (Security/Policy/Announcement, Master Spec section 20) — ยังไม่มีอยู่เลย**: ไม่มี notification type ไหนสำหรับ "ประกาศจากระบบ/แอดมิน" ที่ไม่ผูกกับการกระทำของผู้ใช้คนอื่น (ต่างจาก moderation_warning/moderation_content_removed ที่ผูกกับ report/moderation_actions เฉพาะเจาะจง) และไม่มีกลไกให้ admin ส่งข้อความอิสระถึงผู้ใช้ได้เลย

Requirements:

**1. [P0, bug fix] เพิ่ม `redrop` เข้า Flutter client ให้ครบทุกจุด**
- `NotificationType` enum เพิ่มค่า `redrop` + `_typeFromString()` เพิ่ม case `'redrop' → NotificationType.redrop`
- `notification_list_screen.dart` เพิ่ม case ใน icon switch + message switch (ข้อความแนะนำ: "ReDrop โพสต์ของคุณ" มิเรอร์โทนเดียวกับ `like_drop`/`comment_drop` ที่มีอยู่แล้ว) + tap handler เปิด `DropDetailScreen` ของ `drop_id` เดิม (ReDrop notification ใช้ `drop_id` เดิมของ WYN-012's schema อยู่แล้ว ไม่ต้องเพิ่มคอลัมน์ใหม่)
- **ต้องมี regression test พิสูจน์ red→green จริง** (mirror ที่ WYN-007/012 เคยทำ): จำลองแถว `type: 'redrop'` ปนกับแถวอื่นในลิสต์ แล้วยืนยันว่า fetch/render ทั้งหน้าไม่พังอีกต่อไป (ก่อนแก้ต้องพิสูจน์ว่า fail จริงด้วย ไม่ใช่แค่เขียนเทสต์แล้วผ่านเฉยๆ)
- **ตรวจสอบซ้ำ (ไม่ใช่แก้ใหม่ ถ้าครบแล้ว)**: `follow_request`/`follow_request_accepted`/`message_request` ให้ AI Coding ยืนยันอีกครั้งตรงๆ ว่าครบทั้ง enum/parsing/icon/message/tap-navigation จริงก่อนปิด task (Product ตรวจเบื้องต้นแล้วดูครบ แต่ Coding ควรยืนยันด้วยตาตัวเองอีกชั้นเพราะเป็นจุดเสี่ยงเดียวกับที่ `redrop` เพิ่งพลาดมา)

**2. เพิ่ม notification type ใหม่: `system` (Security/Policy/Announcement)**
- Type ใหม่ 1 ตัว (ไม่แยกเป็น security/policy/announcement 3 type ย่อย — ใช้ type เดียวแล้วให้เนื้อหาข้อความสื่อสารรายละเอียดแทน ลดความซับซ้อนของ enum/switch ที่ต้องดูแลไปเรื่อยๆ ทุกครั้งที่มี category ใหม่)
- `actor_id` เป็น `null` เสมอ (มิเรอร์ pattern เดิมของ `moderation_warning`/`moderation_content_removed`/`appeal_*` — เป็นการสื่อสารจากระบบ ไม่ใช่จากผู้ใช้คนอื่น ไม่มี actor ให้แสดง)
- เนื้อหาข้อความ: reuse คอลัมน์ `reason` เดิม (มีอยู่แล้วสำหรับ moderation types) แทนการเพิ่มคอลัมน์ใหม่ — เก็บข้อความประกาศตรงๆ
- **กลไกสร้าง**: RPC ใหม่ `send_system_notification(p_recipient_id uuid, p_message text)` (SECURITY DEFINER) — **จำกัดให้เรียกได้เฉพาะบัญชีที่ `platform_role = 'admin'` เท่านั้น** (reuse `internal.current_platform_role()`/pattern เดียวกับที่ `decide_appeal()` เช็ค moderator อยู่แล้ว) — **ส่งได้ทีละ 1 คนเท่านั้นในรอบนี้ (ไม่มี broadcast ส่งทุกคนพร้อมกัน)** ดูเหตุผลใน Risks
- **ไม่มีหน้า Admin UI ใหม่ในรอบนี้** — เรียกผ่าน RPC ตรงๆ (เช่นผ่าน Supabase SQL editor/future Admin panel) เพราะ "WYN Admin" เป็นระบบเบื้องหลังที่ยังไม่ถูกสร้างเลยทั้งระบบ (Master Spec: "4 ระบบเบื้องหลังที่ห้ามลืม") การสร้างหน้า Admin เต็มรูปแบบเป็นสโคปคนละขนาดที่ควรเป็น task ของตัวเอง

**3. Trending/Top 100 notification — เลื่อนออกจากสโคปนี้ทั้งหมด**
- ดู Problem ข้อ 3 — ต้องมี snapshot/diff mechanism + cron infrastructure ที่ไม่มีอยู่จริงในระบบตอนนี้เลย ไม่ใช่แค่ "เพิ่ม notification type" ธรรมดาเหมือน 6 ตัวอื่นที่เหลือ เป็นงานสถาปัตยกรรมคนละขนาด — เสนอเป็น task ใหม่แยก (ดู Recommendation)

Acceptance Criteria:
- [ ] จำลองบัญชี A ReDrop เนื้อหาของบัญชี B → บัญชี B เปิดหน้า Notification เห็นแถว ReDrop ถูกต้อง ไม่พังทั้งหน้า แม้จะมีแถวประเภทอื่นปนอยู่ในลิสต์เดียวกันก็ตาม
- [ ] แตะแถว ReDrop notification → เปิด `DropDetailScreen` ของ Drop ต้นฉบับถูกต้อง
- [ ] ยืนยัน red→green จริง: revert การแก้ชั่วคราวแล้วพิสูจน์ error เดิมกลับมาจริง ก่อนค่อย restore การแก้แล้วผ่าน
- [ ] บัญชี `platform_role = 'admin'` เรียก `send_system_notification()` ส่งข้อความถึงผู้ใช้รายหนึ่งได้สำเร็จ ผู้ใช้เห็นแถว System notification (ไม่มี actor แสดง) ข้อความตรงกับที่ส่ง
- [ ] บัญชีที่ไม่ใช่ admin (`user`/`moderator`) เรียก `send_system_notification()` ถูกปฏิเสธ (ไม่มี privilege escalation ผ่านทางนี้)
- [ ] Regression เต็มชุด: notification type เดิมทั้งหมด (like/comment/follow/club/order/mention/moderation/appeal/message_request/follow_request) ทำงานเหมือนเดิมทุกจุด ไม่มี regression จากการแก้ enum/switch

Dependencies: WYN-012 (Notification foundation), WYN-034 (ReDrop, ต้นตอของบั๊ก), WYN-029/030 (`platform_role`/`internal.current_platform_role()`, null-actor pattern, `reason` column precedent), WYN-041/042 (เหตุผลที่ Trending/Top100 เลื่อนสโคปออก)

Priority: **P0 สำหรับ Requirement 1** (บั๊กที่ทำให้ฟีเจอร์ที่ผ่าน QA แล้ว — Notification — พังจริงสำหรับผู้ใช้บางกลุ่ม ควรแก้ก่อนงานใหม่ใดๆ) — P2 สำหรับ Requirement 2 (System notification เป็น net-new capability ไม่ใช่บั๊ก)

Risks:
- **`send_system_notification()` ไม่มี broadcast-to-all ในรอบนี้** — ถ้า Founder ต้องการส่งประกาศถึงผู้ใช้ทุกคนพร้อมกันจริง (เช่น "เราปรับปรุงนโยบายความเป็นส่วนตัว") ต้องรอ task แยกที่ออกแบบการ insert เป็น bulk operation อย่างปลอดภัย (นับพัน/หมื่นแถวในคำสั่งเดียวมีความเสี่ยงด้าน performance/timeout ที่ควรออกแบบแยกต่างหาก ไม่ใช่ผนวกเข้ามาแบบเร่งรีบใน task นี้)
- **Trending/Top100 notification เลื่อนออกทั้งหมด** — ถ้า Founder ยืนยันว่าต้องการ feature นี้จริงจัง ต้องเริ่มจากคุยเรื่อง cron/scheduled-job infrastructure ก่อน (Supabase Edge Function + pg_cron หรือเทียบเท่า) ซึ่งเป็นการตัดสินใจด้าน infrastructure ที่ Founder ควรรับทราบก่อนเริ่ม ไม่ใช่แค่ "เพิ่ม notification type" ตามชื่อ task เดิมที่ทำให้เข้าใจผิดว่าเป็นงานเล็ก
- **บั๊ก `redrop` ที่พบเป็น regression ที่ค้างอยู่ใน production (`main`) มาตั้งแต่ WYN-034** — แม้แอปจะยังไม่ deploy ขึ้น production จริง (ไม่มีผู้ใช้จริงได้รับผลกระทบตอนนี้) แต่เป็นสัญญาณว่า QA ของ WYN-034 มีจุดบอดที่ไม่ครอบคลุม cross-feature interaction (ผลกระทบของ ReDrop ต่อ Notification screen ที่มีอยู่ก่อนแล้ว) — เสนอบันทึกเป็นบทเรียนใน `.wyn/learning/LESSONS_LEARNED.md` ให้ QA รอบถัดไปตรวจ cross-feature impact ให้ครอบคลุมกว่านี้เมื่อเพิ่ม type/state ใหม่ที่แชร์ enum เดียวกันข้าม feature

Recommendation: เริ่มจาก Requirement 1 (บั๊ก P0) ก่อนอย่างอื่นทั้งหมด เพราะเป็นการแก้ของเดิมที่พังอยู่แล้ว ไม่ใช่งานใหม่ ตามด้วย Requirement 2 (System notification, เป็น net-new capability แต่ scope เล็กและ reuse pattern เดิมทั้งหมด) — เสนอ **WYN-04X ใหม่แยกต่างหาก** สำหรับ "Trending/Top 100 Notification Engine" (ต้องออกแบบ cron/scheduled-job infrastructure ตั้งแต่ต้น + snapshot/diff mechanism ใหม่ทั้งชุด) ให้ Founder ตัดสินใจว่าจะทำเมื่อไหร่ ไม่ผูกกับ Phase 5 ต่อเนื่องอัตโนมัติเพราะเป็นงานสถาปัตยกรรมคนละขนาดจริงๆ

Handoff: AI Design — Requirement 1 (บั๊ก ReDrop) ไม่ต้องออกแบบ UI ใหม่เลย (ใช้ icon/message style เดิมของ notification list ทุกจุด) เป็นแค่การเติมจุดที่ขาดหายไป — Requirement 2 (System notification) ตัดสินใจ icon ที่ใช้แสดง (แนะนำ `Icons.campaign_outlined` หรือเทียบเท่าที่สื่อถึง "ประกาศ" ให้ตรวจสอบว่าไม่ซ้ำกับ icon ที่ใช้อยู่แล้วในหน้านี้) และยืนยัน copy ข้อความ default ใน UI (ถ้ามี) ให้เหมาะสมกับ context "ประกาศจากระบบ" ไม่ใช่จากผู้ใช้

## Coding Output (2026-08-23)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-041 ท้ายไฟล์): เพิ่ม `'system'` เข้า `notifications_type_check` (drop+recreate constraint มิเรอร์ pattern เดิมของ WYN-032/034/039/043 ทุกครั้งที่มีการเพิ่ม type ใหม่) — RPC ใหม่ `public.send_system_notification(p_recipient_id uuid, p_message text)` (`security definer`, `plpgsql` เพราะต้อง `raise exception`/มี logic เช็คก่อน insert ไม่ใช่แค่ query เดียวเหมือน SQL function ทั่วไป) เช็ค `internal.current_platform_role() <> 'admin'` แล้ว `raise exception` ปฏิเสธ (มิเรอร์ pattern การเช็ค role เดียวกับที่ใช้ทั่วสคีมา) เช็คข้อความไม่ blank ก่อน insert ด้วย — insert `actor_id = null` เสมอ, `type = 'system'`, ข้อความเข้า `reason` เดิม (ไม่เพิ่มคอลัมน์ใหม่) — **ไม่มี broadcast-to-all mechanism ตามที่ Product ล็อกสโคปไว้** ส่งได้ทีละ 1 คนเท่านั้น

**SQL test ใหม่** (`supabase/tests/wyn_043_notification_types_test.sh`, มิเรอร์ harness ของ `wyn_041_trending_engine_test.sh`) — 10 checks ครอบ: admin ส่งสำเร็จ, แถวที่ insert มี `type`/`actor_id`/`reason` ถูกต้องตรงตามที่ส่ง, `user`/`moderator` ถูกปฏิเสธทั้งคู่ (ไม่ใช่แค่ user — RPC นี้ admin-only จริง ไม่ใช่ moderator-or-admin แบบ `decide_appeal()`), ข้อความว่าง/`null` ถูกปฏิเสธทั้งคู่, ผู้รับเห็นแถวตัวเองได้ปกติ (RLS เดิมไม่เปลี่ยน), บุคคลที่สามไม่เห็นแถวของคนอื่นเลย (ยืนยันว่า RPC ไม่ได้เผลอเปิดช่องให้เห็นข้าม policy) — **10/10 checks PASS** — รันซ้ำครบทั้ง 15 สคริปต์เดิม (`wyn_021` ถึง `wyn_041`) **ผ่านหมดไม่มี cross-task regression** — `check_schema_ordering.py` ผ่าน

**Flutter — Requirement 1 (บั๊ก P0)**: `notification.dart` เพิ่ม `redrop` เข้า `NotificationType` enum + case ใน `_typeFromString()` (จุดที่ขาดหายไปตั้งแต่ WYN-034 ตามที่ Product ยืนยันด้วยการอ่านโค้ดจริง) — `notification_list_screen.dart` เพิ่ม case `redrop` ใน `_messageFor()` ("$name ReDrop โพสต์ของคุณ" มิเรอร์โทน `likeDrop`) และ `_openNotification()` (`_openDrop(notification.dropId!)` มิเรอร์ `mentionDrop`/`likeDrop` เป๊ะ) — **ตรวจสอบซ้ำตามที่ Product ขอ**: `follow_request`/`follow_request_accepted`/`message_request` ยืนยันแล้วว่าครบทั้ง enum/parsing/message/tap-navigation จริง (ไม่ต้องแก้เพิ่ม)

**Flutter — Requirement 2 (`system` type)**: `notification.dart` เพิ่ม `system` เข้า enum + parsing + อัปเดต doc comment ของ `actorId`/`reason` fields ให้ครอบคลุม type ใหม่ — `notification_list_screen.dart`: `_hidesActorIdentity()` เพิ่มเงื่อนไข `system` (actor null เหมือน moderation), เพิ่ม helper ใหม่ `_noActorIconFor(type)` คืน `Icons.campaign_outlined` สำหรับ `system` / `Icons.shield_outlined` สำหรับ 4 moderation types เดิม (ไม่ใช้ไอคอนเดียวซ้ำกันตามที่ Design ตัดสินใจ), `_messageFor()` เพิ่ม case คืน `notification.reason ?? 'มีประกาศจากระบบ WYN'` ตรงๆ ไม่มี prefix, `_openNotification()` เพิ่ม case คืน (no-op) ทันที

**Flutter test ใหม่**:
- `app/test/notification_test.dart` เพิ่ม 2 เทสต์: `WynNotification.fromMap` parse `type: 'redrop'`/`type: 'system'` ได้ถูกต้องไม่ throw — **พิสูจน์ red→green จริงตามที่ Design กำหนด**: revert case `'redrop'` ใน `_typeFromString()` ชั่วคราว รันเทสต์ยืนยัน fail ด้วย `ArgumentError('Unknown notification type: redrop')` ตรงเป๊ะตามที่ Product รายงานไว้ในบั๊ก (ไม่ใช่แค่คาดเดา) แล้ว restore ไฟล์กลับ (ยืนยันด้วย `diff` ว่าเหมือนเดิม 100% ก่อน commit)
- `app/test/notification_list_screen_test.dart` เพิ่ม 4 เทสต์ (2 กลุ่มใหม่ `redrop`/`system`): redrop message ถูกต้องเมื่อปนกับ type อื่นในลิสต์เดียวกันไม่ crash, tap redrop เปิด `DropDetailScreen`, system แสดงข้อความ+ไอคอน campaign ไม่ใช่ shield+ไม่มี avatar, tap system เป็น no-op — **บั๊กที่พบและแก้เองระหว่างเขียนเทสต์ (testing gotcha ไม่ใช่บั๊ก production)**: draft แรกสร้าง `RecordingNotificationRepository` ใหม่ตรงๆ ข้างใน `testWidgets` body (แทนที่จะอยู่ใน `setUp()`) ทำให้โดน `!timersPending` invariant เหมือน pattern ที่เคยเจอมาแล้วหลายรอบในโปรเจกต์นี้ (`RecordingDiscoveryRepository`/WYN-040 เป็นต้น) — แก้โดยย้ายไปสร้างเป็น field `mixedRedropAndLikeRepo` ใน `setUp()` แทน

**Build/Tests — รันจริงครบทุกจุด**:
- `flutter analyze`: **0 issues**
- `flutter test`: **665/665 pass** (baseline 659 จาก WYN-042 QA round + เคสใหม่ 6: 2 ใน `notification_test.dart` + 4 ใน `notification_list_screen_test.dart`)
- `dart format --set-exit-if-changed`: ผ่านทุกไฟล์ที่แก้ (2 ไฟล์ test ต้อง format ใหม่รอบแรก รันซ้ำแล้วผ่านสะอาด 0 changed)
- SQL: 10/10 checks (`wyn_043_notification_types_test.sh`) + รันซ้ำครบ 15 สคริปต์เดิม **ผ่านหมดไม่มี cross-task regression** — `check_schema_ordering.py` ผ่าน

**Known Issue/Gap (ตั้งใจ ไม่ใช่บั๊ก แจ้ง QA/Product ให้ตัดสินใจ)**:
- **Trending/Top 100 notification ยังไม่ถูกสร้างในรอบนี้เลย** ตามที่ Product ตัดสินใจไว้แล้ว (ต้องมี cron/scheduled-job infrastructure ที่ยังไม่มีในระบบ) — เสนอเป็น task ใหม่แยก
- **ไม่มี broadcast-to-all สำหรับ `send_system_notification()`** ตามสโคปที่ Product ล็อกไว้ — ส่งได้ทีละ 1 คนเท่านั้นในรอบนี้
- **ไม่มี Admin UI ใหม่ใดๆ** สำหรับเรียก `send_system_notification()` — เรียกผ่าน RPC ตรงเท่านั้น (เช่น SQL editor) ตามสโคปที่ Product/Design ล็อกไว้ทั้งคู่

**Acceptance Criteria — ไล่ตรวจครบทุกข้อจาก Product spec**: ครบทุกข้อ ยืนยันด้วย SQL test จริง (admin-only/blank-message rejection/RLS) + Flutter test จริง (redrop mixed-list no-crash + tap navigation, system message/icon/no-op) + red→green proof จริงสำหรับบั๊ก P0

Handoff: AI QA & Security — เน้นตรวจ 4 จุด: **(ก) บั๊ก redrop แก้จริงและมี red→green proof จริง** (ไม่ใช่แค่ comment อ้างว่าทำ — ควรลอง revert เองอิสระอีกรอบยืนยัน), **(ข) `send_system_notification()` เป็น admin-only จริง ไม่ใช่ moderator-or-admin** (ต่างจาก `decide_appeal()` ที่ moderator เรียกได้ด้วย — RPC นี้ต้อง admin เท่านั้น), **(ค) ข้อความ system notification ไม่มีทางถูกปลอมแปลงให้ actor_id ไม่ใช่ null** (ตรวจ RPC ตรงๆ ว่า insert `actor_id = null` เสมอ ไม่มีทางให้ caller กำหนดเอง), **(ง) regression เต็มชุดของ notification type เดิมทั้งหมดไม่พังจากการแก้ enum/switch ครั้งนี้**

## Independent QA (2026-08-23)

```
Feature: WYN-043 Notification Types — บั๊ก P0 (redrop crash) + system notification type ใหม่
Environment: Local sandbox — PostgreSQL 16 และ Flutter stable ชุดเดียวกับที่ใช้ทดสอบ WYN-040/041/042 — sync branch `claude/wyn-40-continuation-ul5ngq` ที่ commit `9316189` ก่อนเริ่มทดสอบ

Test Cases:
1. `flutter analyze`/`flutter test` เต็มชุดรันอิสระเอง — 0 issues, **665/665 pass**
2. **พิสูจน์ red→green ด้วยตัวเองอิสระ ไม่เชื่อ comment ของ Coding**: revert case `'redrop'` ใน `_typeFromString()` ชั่วคราวเอง (คนละรอบจาก Coding) รันเทสต์ยืนยัน fail จริงด้วย `ArgumentError('Unknown notification type: redrop')` ตรงจุดเดียวกับที่ Coding รายงาน (เทสต์อื่นที่ไม่เกี่ยวกับ redrop ยังผ่านหมด 39 เคสจาก 40 — ยืนยันว่า revert กระทบเฉพาะจุดที่ตั้งใจ) แล้ว restore ไฟล์กลับด้วย `diff` ยืนยันเหมือนเดิม 100% ก่อนดำเนินการต่อ
3. `supabase/tests/wyn_043_notification_types_test.sh` รันอิสระเอง — 10/10 PASS
4. รันซ้ำ SQL regression ทั้ง 16 สคริปต์ (`wyn_021` ถึง `wyn_043`) ยืนยันไม่มี cross-task regression
5. `check_schema_ordering.py` — ไม่มี forward reference
6. **Adversarial probe เพิ่มเติมที่ไม่มีอยู่ใน SQL test เดิมของ Coding**: (ก) `send_system_notification()` ด้วย `p_recipient_id` ที่ไม่มีอยู่จริงในระบบเลย → ถูกปฏิเสธด้วย FK constraint violation ทันที ไม่ insert เงียบๆ (ข) ตรวจ `pg_get_function_arguments()` ยืนยัน signature มีแค่ `p_recipient_id uuid, p_message text` 2 parameter เท่านั้น — ไม่มีทางส่ง `actor_id`/`type` เองผ่าน parameter ใดๆ เลย (ค) ส่งข้อความรูปแบบ SQL injection (`'; drop table public.notifications; --`) → เก็บเป็น literal text ตรงๆ ไม่ถูก execute (ตาราง `notifications` ยังอยู่ครบ ยืนยันด้วยการนับแถวจริงในฐานะ superuser bypass RLS) (ง) ข้อความยาว 10,000 ตัวอักษร → เก็บได้ครบไม่ตัด/crash (จ) ยืนยัน `actor_id` เป็น `NULL` จริงในแถวที่ insert จริง (อ่านตรงจากตารางในฐานะ superuser ไม่ใช่แค่เชื่อ SQL test) (ฉ) ยืนยันฟังก์ชันยังเป็น `security definer` (`prosecdef = t`) ไม่ได้ถูกเปลี่ยนพลาด
7. อ่าน diff ของ `notification_list_screen.dart`/`notification.dart` แบบ adversarial ทีละบรรทัด ยืนยัน `_hidesActorIdentity()`/`_noActorIconFor()`/`_messageFor()`/`_openNotification()` ทุกจุดต่อ `system`/`redrop` ตรงตาม Design spec เป๊ะ ไม่มีจุดไหนพลาด
8. ยืนยันด้วยการอ่านโค้ดตรงว่า `_messageFor()`'s `system` case ไม่เรียก `notification.actorNameOrUsername`/`name` เลย (ตัวแปร `name` ที่ประกาศต้นฟังก์ชันไม่ถูกใช้ในบรรทัดนี้) — ยืนยันไม่มีทางรั่ว string ว่างที่แปลกๆ ปนเข้าไปในข้อความ system

Passed: 0 issues (`flutter analyze`) + 665/665 (`flutter test`) + 10/10 (SQL ใหม่) + 16/16 สคริปต์ SQL ทั้งหมด + 6/6 adversarial probe เพิ่มเติม + red→green ยืนยันอิสระ — ทุกตัวเลขยืนยันด้วยการรันเอง/พิสูจน์เองอิสระ ไม่ใช่การเชื่อ Coding Output
Failed: 0

Severity: N/A (ไม่พบบั๊กที่ block การอนุมัติ)

Reproduction Steps: N/A — ไม่มีบั๊กให้ reproduce (บั๊กเดิมที่ task นี้แก้ ยืนยันแล้วว่าแก้จริง)

Expected: ครบ 4 จุดตาม Handoff ของ Coding — (ก) redrop แก้จริงมี red→green proof, (ข) admin-only จริง, (ค) actor_id ปลอมไม่ได้, (ง) ไม่มี regression

Actual: ตรงตามที่คาดทั้ง 4 จุด — (ก) พิสูจน์ red→green ด้วยตัวเองอิสระสำเร็จ ไม่ใช่แค่เชื่อ comment, (ข) SQL test ยืนยัน `moderator` ก็ถูกปฏิเสธเหมือน `user` ไม่ใช่แค่ non-admin ทั่วไป, (ค) ยืนยันด้วย `pg_get_function_arguments()` ว่าไม่มีช่องทางส่ง `actor_id` เข้าไปได้เลย และตรวจแถวจริงว่า `NULL` เสมอ, (ง) รันเทสต์เดิมทั้งหมดซ้ำอิสระผ่านหมด 665/665

Security Findings:
- ไม่พบช่องโหว่ privacy/injection ใดๆ ใหม่ — `send_system_notification()` เป็น parameterized function call ปกติ ไม่มี dynamic SQL string concatenation จุดไหนเลย พิสูจน์ด้วยการยิง SQL-injection-shaped payload จริงแล้วยืนยันว่าถูกเก็บเป็น literal text ไม่ถูก execute
- `actor_id` รับประกันเป็น NULL เสมอในทุกแถวที่สร้างผ่าน RPC นี้ (ไม่มี parameter ให้ override) — ตรงตามเจตนาป้องกันการสวมรอย/ปลอมตัวเป็นผู้ใช้อื่น
- Admin-only enforcement ยืนยันแยกกันทั้ง `user` และ `moderator` (ไม่ใช่แค่ทดสอบ role เดียวแล้วสรุปเหมา) — ไม่มี privilege escalation ผ่านทางนี้
- ไม่มีการเปลี่ยนแปลง RLS ใดๆ ของ `notifications` เดิม — ยืนยันด้วย probe จริงว่า recipient เห็นแถวตัวเองได้ปกติ บุคคลอื่นเห็นไม่ได้เหมือนเดิมทุกประการ

Recommendation: อนุมัติ — ครบทุก Acceptance Criteria จาก Product spec, พิสูจน์บั๊ก P0 แก้จริงด้วยการทดสอบอิสระ (revert แล้วเห็น error จริง), `send_system_notification()` ผ่าน adversarial probe ครบทุกมุม (injection/FK/signature/actor_id spoofing/role escalation) ไม่พบช่องโหว่ ไม่มี regression ต่อ notification type เดิมแม้แต่จุดเดียว — ไม่พบข้อสังเกตใดๆ แม้แต่ Minor ในรอบนี้

Final Status: PASS
```

