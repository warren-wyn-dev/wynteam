# Product Task — WYN-124

Status: active
Owner: AI Product Manager

Feature: Club Invite Notification — เปลี่ยนกลไก "เชิญจากผู้ติดตาม" (WYN-123) จากการส่งข้อความ Chat มาเป็นการแจ้งเตือน (Notification) โดยตรง

Goal: คนที่ถูกเชิญเข้าคลับควรเห็นคำเชิญในหน้า "การแจ้งเตือน" (Notification) ไม่ใช่หน้าแชท — ตรงกับสัญชาตญาณของ Notification ทั่วไป (follow, club_join_approved ฯลฯ) และไม่ผูกกับสถานะของฟีเจอร์แชท

Target User: ผู้ใช้ที่ถูกเชิญเข้า Club จาก Followers/Following ของสมาชิกคนอื่น (WYN-123's audience)

Problem: WYN-123 เปิดตัวจริงวันนี้ (2026-09-06) โดยส่ง invite เป็นข้อความ Chat ผ่าน `getOrCreateConversation()`+`sendMessage(sharedContentType: club)` — ตอนทดสอบจริงพบว่า:
1. คำเชิญไปโผล่ในกล่องแชท ไม่ใช่หน้าการแจ้งเตือน ตรงข้ามกับที่ Founder ตั้งใจ
2. โดยไม่ได้ตั้งใจ ผูกฟีเจอร์ invite เข้ากับ WYN-122 (Chat Lockdown) — ตอนที่ Lockdown เปิดทดสอบอยู่ การเชิญทุกคนยกเว้นคนใน allowlist ล้มเหลวด้วย error "Chat is temporarily closed for testing" (แสดงเป็น "เชิญไม่สำเร็จ" ให้ผู้ใช้เห็นแบบไม่มีคำอธิบาย)

Requirements:
- แทนที่กลไกเดิมทั้งหมดด้วย Notification ประเภทใหม่ `club_invite` (RPC `invite_to_club(p_club_id, p_invitee_id)`) — ไม่ส่งข้อความ Chat อีกต่อไป
- Audience/validation เดิมจาก WYN-123 คงไว้ทั้งหมด: ต้องเป็นสมาชิกที่ approved ของ Club ถึงจะเชิญได้, ผู้ถูกเชิญต้องเป็น follower หรือ following ของผู้เชิญ (ทางใดทางหนึ่ง), ห้ามเชิญตัวเอง, ห้ามเชิญผู้ใช้ที่ block กันอยู่
- คนที่ถูกเชิญเห็นข้อความ "{ชื่อผู้เชิญ} ชวนคุณเข้าร่วม {ชื่อ Club}" ในหน้าการแจ้งเตือน กดแล้วไปที่หน้า Club (Posts tab) — เหมือนกับ `club_join_approved` เดิม
- เคารพ notification settings หมวด "club" เดิมที่มีอยู่แล้ว (`notification_enabled(user, 'club')`)
- กัน spam เบื้องต้น: เชิญซ้ำคนเดิมเข้า Club เดิมภายใน 24 ชม. ไม่สร้าง notification ซ้ำ (มิเรอร์ pattern เดิมของ `notify_club_post_new()` ที่กัน spam โพสต์ใหม่ทุก 3 ชม.)

Acceptance Criteria:
- กด "เชิญ" ใน `InviteToClubScreen` แล้วไม่มีการสร้าง Chat message ใดๆ อีกต่อไป (ตรวจสอบได้ว่าไม่มีแถวใหม่ใน `messages`)
- ผู้ถูกเชิญเห็น notification ใหม่ในหน้าการแจ้งเตือนทันที กดแล้วเปิดหน้า Club ได้ถูกต้อง
- การเชิญไม่ขึ้นกับสถานะ Chat Lockdown อีกต่อไป — เชิญได้ปกติแม้ Lockdown เปิดอยู่
- Push notification ส่งข้อความภาษาไทยที่ถูกต้อง (mirror กับข้อความในแอป)

Dependencies: ต่อจาก WYN-123 (ต้อง merge/deploy แล้ว) — ไม่กระทบ WYN-115/116/117/119 ที่ deploy ไปพร้อมกันวันนี้

Priority: P0 — WYN-123 เพิ่ง deploy ขึ้น production จริงวันนี้ด้วยกลไกที่ผิดจุดประสงค์ตั้งแต่แรก ต้องแก้ก่อนมีคนใช้งานจริงมากขึ้น

Risks: เปลี่ยน public API ของ `InviteToClubScreen` (`chatRepository` → `clubRepository`) — จุดเรียกใช้เดียวคือ `share_sheet.dart`/`club_page.dart` ซึ่งแก้ในรอบเดียวกันนี้แล้ว ไม่มีจุดเรียกอื่นหลงเหลือ

Recommendation: ทำให้เสร็จเต็มรูปแบบและ deploy ทันที ตามที่ Founder ยืนยัน (2026-09-06) — เป็นการแก้ทิศทางของฟีเจอร์ที่เพิ่งเปิดตัว ยิ่งปล่อยไว้นานยิ่งมีคนได้รับ invite ผิดรูปแบบมากขึ้น

Handoff: AI Design (ตัดสินใจ notification type/ dedup window / ปลายทางตอนกด) → AI Coding → AI QA & Security → AI Deploy & DevOps

---

## AI Design Output

ดู `.wyn/docs/design/wyn-124-club-invite-notification.md` — สรุป: Notification ประเภทใหม่ `club_invite` มิเรอร์ `club_join_approved` (recipient/actor/club_id เท่านั้น ไม่ต้องมี field ใหม่ เพราะ `clubId`/`clubName` มีอยู่แล้วบน `WynNotification`), RPC `invite_to_club()` เป็น `security definer` ตรวจสิทธิ์/audience/block ทั้งหมดฝั่ง server (ไม่เชื่อ client ล้วนๆ), ใช้ dedup 24 ชม. ต่อ (ผู้เชิญ, ผู้ถูกเชิญ, Club) กัน spam, tap-destination และ push message มิเรอร์ `club_join_approved` เป๊ะ (เปิด Club ไปที่ Posts tab)

## AI Coding Output

**Files Changed**:
- `supabase/schema.sql` — เพิ่ม `'club_invite'` เข้า `notifications_type_check`, ฟังก์ชันใหม่ `public.invite_to_club(p_club_id, p_invitee_id)`
- `.github/workflows/wyn124-apply-club-invite-schema.yml` (ใหม่) — apply-to-production workflow **ในรอบเดียวกับที่ merge schema.sql** (บทเรียนจาก WYN-115/116 P0 วันนี้: ต้องมี workflow apply เสมอ ไม่ใช่แก้ทีหลังตอนพัง)
- `app/lib/features/club/data/club_repository.dart` — `inviteToClub({clubId, inviteeId})` (เรียก RPC ใหม่)
- `app/lib/features/club/presentation/invite_to_club_screen.dart` — `_invite()` เปลี่ยนจาก `chatRepository.getOrCreateConversation()+sendMessage()` เป็น `clubRepository.inviteToClub()`; constructor param เปลี่ยนจาก `chatRepository` เป็น `clubRepository`
- `app/lib/features/chat/presentation/share_sheet.dart` — เพิ่ม param `clubRepository`, `showInviteFromFollowers` ต้องมีครบทั้ง 3 param (`followRepository`/`clubRepository`/`clubName`)
- `app/lib/features/club/presentation/club_page.dart` — ส่ง `clubRepository: widget.clubRepository` ให้ `showShareSheet`
- `app/lib/features/notification/data/notification.dart` — `NotificationType.clubInvite` + `_typeFromString('club_invite')`
- `app/lib/features/notification/presentation/notification_list_screen.dart` — `_openNotification`/`_messageFor` เพิ่ม case `clubInvite` (เปิด Club แท็บ Posts, ข้อความ "{ชื่อ} ชวนคุณเข้าร่วม {Club}")
- `app/lib/features/push/presentation/push_notification_service.dart` — เพิ่ม case `'club_invite'` ในสวิตช์ deep-link ของ push tap (ปลายทางเดียวกับ `club_join_approved`)
- `supabase/functions/send-push-notification/_lib.ts` — เพิ่ม case `"club_invite"` ใน `messageFor()` (มิเรอร์ข้อความฝั่ง Dart คำต่อคำ)
- Tests: `recording_club_repository.dart` (`inviteToClub`/`inviteToClubError`/`inviteToClubGate`), `invite_to_club_screen_test.dart` (เปลี่ยนจาก Chat mock เป็น Club mock ทั้งไฟล์), `share_sheet_test.dart` (เพิ่ม `clubRepository` param), `notification_test.dart` (`fromMap` ของ `club_invite` ไม่ throw), `notification_list_screen_test.dart` (ข้อความ + tap destination ของ `clubInvite`), `send-push-notification/_lib.test.ts` (ข้อความ push ของ `club_invite`)

**Tests**: รอผลจาก CI (ไม่มี Flutter SDK ในเครื่องนี้) — ดู AI QA & Security Output

**Handoff**: ส่งต่อ AI QA & Security
