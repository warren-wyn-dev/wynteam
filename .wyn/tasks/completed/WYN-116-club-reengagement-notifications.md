# Product Task — WYN-116

Status: completed -- schema gap fixed same day via `wyn116-apply-club-reengagement-schema.yml` (see DECISIONS.md, "P0: real Club pages broken in production"), Founder confirmed real Club pages load correctly again in production, 2026-09-06 ("เสร็จแล้ว")
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

## AI QA & Security Output

**Feature**: WYN-116 (Club Re-engagement Notifications) — commit `8d6d0dd`, PR #280

**Environment**: Local PostgreSQL 16 จริง (RLS ผ่าน `authenticated` role) + Flutter SDK เต็มชุด — Deno ไม่มีในแซนด์บ็อกซ์นี้ (เหมือนที่ Coding เจอ) ตรวจ `_lib.ts`/`_lib.test.ts` ด้วยการเทียบข้อความ Thai ทีละตัวอักษรกับฝั่ง Dart แทน

**Test Cases**:
1. `wyn_116_club_reengagement_notifications_test.sh` — 17 checks รันซ้ำอิสระ
2. `wyn_115_club_poll_test.sh`/`wyn_043_notification_types_test.sh`/`wyn_044_notification_settings_test.sh`/`wyn_021_club_post_mentions_rls_test.sh` — regression ครบ
3. `check_schema_ordering.py`, `flutter analyze`, `flutter test` เต็มชุด
4. อ่านโค้ด `notify_club_post_new()`/`notify_club_post_pinned()` ตรงๆ ตรวจ `SECURITY DEFINER` re-check `status='approved'` จริง ไม่ใช่แค่เชื่อ helper ที่ spoof ได้
5. ตรวจ asymmetry "pin แจ้ง author แต่ new-post ไม่แจ้ง author" ตรงกับ Design doc จริง
6. ตรวจขอบเขต mute ไม่กระทบ type เดิม (`club_post_like`/`club_post_comment`/`mention_club_post`/`club_join_*`)
7. วิเคราะห์ concurrent-throttle race condition (นอกเหนือจาก test script เดิมที่รันแบบ sequential เท่านั้น)
8. สแกน secret ใน commit diff

**Passed**: ครบทุกจุด — regression 17+65 checks (WYN-116 + ของเดิม), `flutter analyze` clean, `flutter test` 1273/1273 PASS, push message เทียบตรงกันทุกตัวอักษร, ทุกจุดตัดสินใจใน Design doc ตรงกับโค้ดจริง, ไม่พบ secret

**Failed**: ไม่มี

**Severity**: Low (ไม่ block) — 1 ข้อสังเกต

**Security Findings**: ไม่พบช่องโหว่ block — RLS ของ `club_notification_mutes` จำกัดแค่แถวตัวเองจริง (ยืนยันสด), ทั้ง 2 trigger function คำนวณ recipient set จาก `cm.status='approved'` ตรงๆ ไม่ผ่าน helper ที่ spoof ได้ (ยืนยันด้วย pending/banned ถูก exclude แม้ function จะเป็น SECURITY DEFINER), `notifications` table ไม่มี client insert policy เลยจึงสร้าง 2 type ใหม่ได้ทางเดียวคือผ่าน trigger เท่านั้น

**ข้อสังเกต Low severity (ไม่ block)**: throttle 3 ชม. ของ `notify_club_post_new()` ใช้ `not exists (...)` เฉยๆ ไม่มี unique index/advisory lock รองรับ — ภายใต้ READ COMMITTED ถ้ามี 2 insert เข้า `club_posts` ของ Club เดียวกัน "พร้อมกันจริงๆ" (concurrent transaction ที่ยังไม่ commit) ผู้รับคนเดียวกันอาจได้รับ `club_post_new` 2 ครั้งในหน้าต่าง 3 ชม.เดียวกันแทนที่จะเป็น 1 ครั้ง — โอกาสเกิดจริงต่ำมาก (ต้อง insert ชนกันระดับมิลลิวินาที) ผลกระทบเบา (แจ้งเตือนซ้ำ ไม่ใช่ data corruption/security) — บันทึกเป็น backlog item ไว้พิจารณาทำ partial unique index หรือ `pg_advisory_xact_lock` ในอนาคตถ้าเจอจริงใน production ไม่ต้องแก้ก่อน deploy รอบนี้

**Recommendation**: อนุมัติ deploy ได้

**Final Status: PASS**

**Handoff**: ส่งต่อ AI Deploy & DevOps
