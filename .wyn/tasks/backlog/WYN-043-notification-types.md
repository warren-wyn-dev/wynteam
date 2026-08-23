# Product Task — WYN-043

Status: backlog
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
