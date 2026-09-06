# Product Task — WYN-116

Status: active
Owner: AI Product Manager

Feature: Club Re-engagement Notifications — แจ้งเตือนสมาชิกเมื่อ Club ที่เข้าร่วมมีความเคลื่อนไหวใหม่

Goal: ดึงสมาชิกกลับมาเปิดแอปอีกครั้งหลังเข้าร่วม Club แล้ว — ตรงกับปัญหา "engagement เป็นศูนย์หลังสมัคร" ที่ WYN-112 กำลังสืบอยู่โดยตรง (ถ้าไม่มีอะไรดึงกลับมา คนที่เพิ่งเข้าร่วม Club ก็จะเงียบหายไปเหมือนที่เกิดขึ้นแล้ว)

Target User: สมาชิกที่ approved ของ Club อย่างน้อย 1 Club

Problem: ตอนนี้ระบบแจ้งเตือนของ Club ครอบแค่ "มีคนตอบโพสต์ฉัน/กด Like โพสต์ฉัน/mention ฉัน" (แจ้งเตือนที่เกี่ยวกับตัวผู้ใช้เองโดยตรง) — ไม่มีการแจ้งเตือนแบบ "Club ของคุณมีอะไรใหม่" เลย (โพสต์ใหม่จากคนอื่นใน Club, ประกาศ/Pinned post ใหม่จาก Admin) ซึ่งเป็นแรงดึงกลับที่ Facebook Group/Discord ใช้เป็นหลัก

Requirements:
- แจ้งเตือนเมื่อ Club ที่เข้าร่วมมี Pinned Post ใหม่ (ให้ความสำคัญสูงสุด เพราะเป็นสิ่งที่ Admin ตั้งใจให้ทุกคนเห็น)
- แจ้งเตือนเมื่อ Club มีโพสต์ใหม่ (ต้อง throttle/รวมเป็นก้อนถ้าโพสต์บ่อย ไม่ใช่ยิงทุกโพสต์ทันที ป้องกัน notification fatigue) — ให้ Design ตัดสินใจ threshold/ความถี่ที่เหมาะสม
- ผู้ใช้ปิดแจ้งเตือนได้ต่อ Club (ไม่ใช่ all-or-nothing ทั้งแอป) — ต่อยอด notification preference system ที่มีอยู่แล้ว (WYN-043 mapping 7 หมวด รวม "club" อยู่แล้ว)
- ใช้ Push Notification (Firebase) ที่โค้ดพร้อมอยู่แล้วตาม `wynos-gtm-roadmap.md` — ถ้า Firebase project จริงยังไม่ config ให้ทำ in-app notification (กระดิ่ง) ก่อน แล้ว push message ตามทีหลังเมื่อ Firebase พร้อม (ไม่ block งานนี้)

Acceptance Criteria:
- สมาชิก Club เห็นแจ้งเตือนโพสต์ Pin ใหม่ทุกครั้งที่เกิดขึ้นจริง
- สมาชิก Club เห็นแจ้งเตือนโพสต์ใหม่แบบไม่ถี่จนรำคาญ (ตาม threshold ที่ Design กำหนด และ QA ทดสอบจริง)
- ปิดแจ้งเตือนเฉพาะ Club หนึ่งได้โดยไม่กระทบ Club อื่น/แจ้งเตือนประเภทอื่น

Dependencies: **ต้องรอ/ตรวจสอบสถานะ Firebase project จริงก่อน** (ตาม `wynos-gtm-roadmap.md` ข้อจำกัดที่ 5 — โค้ด Push พร้อมแต่ยังรอ config จริง) ถ้ายังไม่พร้อม ให้ทำ in-app notification ส่วนก่อนตามที่ระบุใน Requirements

Priority: P1 — Founder เลือกเป็นลำดับ 2 ใน Club Growth Roadmap

Risks: Notification fatigue ถ้า throttle ไม่ดี (คนปิดแจ้งเตือนทั้งหมดเลยแทนที่จะแค่ลดความถี่) — ต้องให้ Design คิด threshold รอบคอบ ไม่ใช่ยิงทุก event ทันที

Recommendation: เริ่ม Design คู่ขนานกับ WYN-115 ได้ (ไม่ทับซ้อนกัน) แต่ Coding ควรรอ WYN-114 (fix link) deploy ก่อน เพราะ deep link ที่ถูกต้องจำเป็นสำหรับให้แจ้งเตือนพาไปเปิด Club ที่ถูกต้องได้จริง

Handoff: AI Design (โดยเฉพาะเรื่อง throttle threshold + preference UI) → AI Coding → AI QA & Security

---

## AI Design Output

ดู `.wyn/docs/design/wyn-116-club-reengagement-notifications.md` — reuse โครงสร้าง notification เดิมทั้งหมด (WYN-015 trigger pattern, WYN-043/044 category gate) ของใหม่จริงมีแค่ 2 อย่าง: (1) 2 notification type ใหม่ (`club_post_new`/`club_post_pinned`) fan-out ไปสมาชิก approved ทุกคน (2) ตาราง `club_notification_mutes` สำหรับปิดแจ้งเตือนต่อ Club (ขอบเขตเฉพาะ 2 type ใหม่นี้ ไม่กระทบ type เดิม) throttle โพสต์ใหม่: ไม่เกิน 1 ครั้งต่อ (ผู้รับ, Club) ทุก 3 ชั่วโมง (time-window check ในตัว trigger เอง เพราะระบบไม่มี cron/digest infra) — ปักหมุดไม่ throttle เลยตาม Acceptance Criteria

## AI Coding Output

**Files Changed**:
- `supabase/schema.sql` — เพิ่ม `club_post_new`/`club_post_pinned` เข้า `notifications_type_check`, ตาราง `club_notification_mutes` + RLS (มิเรอร์ `conversation_mutes`), `notify_club_post_new()` (fan-out+throttle 3 ชม.+mute+category gate) และ `notify_club_post_pinned()` (fan-out ไม่ throttle รวม author ของโพสต์ด้วย) + trigger ทั้งคู่
- `supabase/tests/wyn_116_club_reengagement_notifications_test.sh` — regression 17 checks (real Postgres, RLS ผ่าน `set role authenticated`)
- `app/lib/features/notification/data/notification.dart` — เพิ่ม `clubPostNew`/`clubPostPinned` เข้า enum + `_typeFromString`
- `app/lib/features/notification/presentation/notification_list_screen.dart` — เพิ่ม message template, tap routing ไป `_openClubPost`, badge push-pin สำหรับ `clubPostPinned` เท่านั้น
- `supabase/functions/send-push-notification/_lib.ts` + `_lib.test.ts` — mirror message template ให้ตรงกับฝั่ง Dart (พร้อม push ทันทีที่ Firebase config จริง ไม่ต้องแก้เพิ่ม)
- `app/lib/features/push/presentation/push_notification_service.dart` — เพิ่ม case ใน `_openFromPushData()`
- `app/lib/features/club/data/club_repository.dart` — `isClubMuted()`/`muteClubNotifications()`/`unmuteClubNotifications()`
- `app/lib/features/club/presentation/club_page.dart` — แถว "ปิด/เปิดการแจ้งเตือน Club นี้" ใน More menu (ทุกสมาชิก approved ไม่ผูก role)
- Tests ใหม่/แก้: `club_page_test.dart` (mute toggle group), `notification_list_screen_test.dart` (WYN-116 group), `recording_club_repository.dart`/`recording_club_post_repository.dart` fake overrides

**Tests**: `flutter analyze` clean, `flutter test` เต็มชุด 1273/1273 PASS, `wyn_116_club_reengagement_notifications_test.sh` 17/17 PASS, `wyn_115_club_poll_test.sh`/`wyn_043_notification_types_test.sh`/`wyn_044_notification_settings_test.sh`/`wyn_021_club_post_mentions_rls_test.sh` re-run ยืนยันไม่มี regression, `check_schema_ordering.py` OK — หมายเหตุ: `_lib.test.ts` (Deno) แก้แล้วแต่รันจริงไม่ได้ในแซนด์บ็อกซ์นี้ (ไม่มี `deno` ติดตั้ง) เป็นการ mirror ข้อความ Thai แบบ mechanical ตรงกับฝั่ง Dart ที่ทดสอบผ่านแล้ว — QA ควรรันยืนยันอิสระถ้ามี Deno

**Handoff**: ส่งต่อ AI QA & Security
