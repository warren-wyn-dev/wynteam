# Product Task — WYN-029

Status: approved — merged to `main` (2026-08-22, commit `b04d455`), รอ infra จริงก่อน deploy ได้ (QA อิสระรอบ 2 — PASS, 2026-08-22 — ดู "Independent QA — Round 2" ท้ายไฟล์ — Major finding ของรอบ 1 แก้แล้วและยืนยันอิสระแล้ว, bug report ปิดที่ `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md`)
Owner: AI Product Manager (เสร็จ) → AI Design (เสร็จ) → AI Coding (เสร็จ) → AI Debug Engineer (เสร็จ — แก้ Major finding รอบ 1) → AI QA & Security (เสร็จ — PASS รอบ 2) → AI Deploy & DevOps (เสร็จ — merged to `main`, `flutter analyze`/`flutter test` 433/433 + SQL regression ยืนยันซ้ำหลัง merge, ดู `.wyn/logs/deployments/2026-08-22-wyn-029-merge-to-main.md` — รอ infra จาก Founder ก่อน deploy จริง)

Feature: Moderation Queue + Action (ขั้นต่ำในแอป Flutter เดิม)

Goal: ให้ Report ที่เข้ามาจาก WYN-026 ถูกตรวจสอบและดำเนินการได้จริงโดยผู้มีสิทธิ์ (moderator/admin) ตั้งแต่ Phase 1 นี้ ผ่านหน้าจอขั้นต่ำในแอป Flutter เดิม — โดยไม่ต้องรอ WYN Admin (เว็บ, Phase 7) ตามที่ Founder ยืนยัน (2026-08-22)

Target User: ผู้ใช้ที่มีบทบาท moderator/admin ของแพลตฟอร์ม (รอบแรกคือ Founder/ทีมภายในที่ Founder ตั้งค่าให้ผ่าน DB โดยตรง) — ผลลัพธ์ปลายทางคือผู้ใช้ทั่วไปที่ได้รับความปลอดภัยจากการที่ Report ถูกดำเนินการจริง ไม่ค้างเฉย ๆ

Problem: WYN-026 ทำให้ผู้ใช้ส่ง Report ได้แล้ว แต่ยังไม่มีใคร/ที่ใดให้ตรวจสอบและตัดสินใจ — Master Spec ข้อ 25 กำหนด Workflow ไว้ว่า "Report → Moderation Queue → Review → Action (No Action/Warning/Remove Content/Restrict/Suspend/Ban) → Appeal" — WYN Admin ที่ตั้งใจเป็นเครื่องมือหลักของทีม Moderation ยังไม่เริ่มสร้างจนกว่าจะถึง Phase 7 (แยก tech stack เป็นเว็บ) ทำให้ต้องมีหน้าจอขั้นต่ำในแอปเดิมไปก่อนตามที่ Founder ตัดสินใจ

Requirements:

**Platform Role (พื้นฐานใหม่ที่ยังไม่มีในระบบ)**
- เพิ่มคอลัมน์ `platform_role` ใน `profiles` (ค่า: `user` (default) / `moderator` / `admin`) — **ตั้งค่าได้เฉพาะทาง Supabase โดยตรงในรอบนี้เท่านั้น ไม่มี UI ในแอปให้ตั้งเอง** (ไม่มีใครสามารถเลื่อนสิทธิ์ตัวเองผ่าน client ได้ — ป้องกัน privilege escalation ตั้งแต่ต้น)
- `admin` เห็น/ทำได้ทุกอย่างที่ `moderator` ทำได้ + จัดการ `platform_role` ของคนอื่น (ผ่าน DB โดยตรงในรอบนี้เหมือนกัน ยังไม่มี UI จัดการ role ใครเลยในแอป)

**Moderation Queue Screen (เข้าถึงได้เฉพาะ platform_role = moderator/admin)**
- Entry point ซ่อนอยู่ (ไม่ปรากฏในเมนูของผู้ใช้ทั่วไป) — แนะนำเข้าถึงผ่านปุ่มลับใน Settings ที่โผล่เฉพาะเมื่อ `platform_role != 'user'` เท่านั้น (ผู้ใช้ทั่วไปไม่เห็นแม้แต่ทางเข้า)
- แสดงรายการ Report ที่ status = `pending`/`reviewing` เรียงจากเก่าไปใหม่ (FIFO อย่างง่ายรอบนี้ — ไม่ทำ priority scoring ซับซ้อน)
- แต่ละแถวแสดง: Category, Target Type, สรุปเนื้อหา/ผู้ใช้เป้าหมาย (ลิงก์เปิดดูเนื้อหา/โปรไฟล์จริงได้), รายละเอียดเพิ่มเติมจากผู้รายงาน, เวลาที่รายงาน — **ไม่แสดงตัวตนผู้รายงาน** (คงกติกา privacy จาก WYN-026)
- แตะเข้ารายละเอียด Report หนึ่งอัน → เห็นปุ่ม Action 6 แบบตาม Master Spec: **No Action, Warning, Remove Content, Restrict, Suspend, Ban**
- เลือก Action → กรอกเหตุผล (บังคับ, ใช้เป็นข้อมูลให้ผู้ใช้เห็นตอน Appeal) → ยืนยัน → Report เปลี่ยน status เป็น `actioned` (หรือ `dismissed` ถ้าเลือก No Action) บันทึกลง `moderation_actions` พร้อม reviewer/เวลา

**ความหมายและผลของแต่ละ Action**
- **No Action**: ปิดเคส ไม่มีผลใด ๆ ต่อเนื้อหา/ผู้ใช้ (dismissed)
- **Warning**: ส่ง notification ถึงผู้ถูก Report แจ้งว่าเนื้อหา/พฤติกรรมของเขาละเมิดกฎ พร้อมเหตุผล ไม่มีผลจำกัดการใช้งานใด ๆ เพิ่มเติม
- **Remove Content**: เนื้อหาเป้าหมาย (Drop/Comment/Club Post) ถูกลบแบบ soft-delete (ผู้เขียนเห็นว่าเนื้อหาถูกลบเพราะละเมิดกฎ, คนอื่นมองไม่เห็นอีกต่อไป) — เฉพาะ target ที่เป็นเนื้อหา ไม่ใช้กับ target ที่เป็น User/Club
- **Restrict**: จำกัดความสามารถของบัญชีชั่วคราว (โพสต์ Drop ใหม่ไม่ได้, Comment ไม่ได้, สร้าง Club ไม่ได้ — ยังคง Login/ดู/Like/Follow ได้ปกติ) มีกำหนดระยะเวลา (เลือกได้: 1 วัน / 3 วัน / 7 วัน) หมดเวลาแล้วคืนสิทธิ์อัตโนมัติ
- **Suspend**: ระงับบัญชีชั่วคราว (Login ไม่ได้เลยระหว่างช่วงเวลาที่กำหนด — ตัวเลือกเดียวกับ Restrict: 1/3/7 วัน) หมดเวลาแล้วคืนสิทธิ์อัตโนมัติ
- **Ban**: ระงับบัญชีถาวร (Login ไม่ได้อีกเลยจนกว่า admin จะ Unban ด้วยมือ — ไม่มี auto-expire)

**บังคับใช้ Restrict/Suspend/Ban จริงในแอป**
- Suspend/Ban: พยายาม Login → แสดงข้อความแจ้งสถานะบัญชีและเหตุผล (ถ้ามี) ไม่ปล่อยเข้าแอป — เซสชันที่ login ค้างอยู่ก่อนหน้าต้องถูกบังคับ logout ด้วย (force logout)
- Restrict: ปุ่มโพสต์ Drop/Comment/สร้าง Club ถูกปิดใช้งานพร้อมข้อความอธิบายสถานะและวันหมดเขต

Acceptance Criteria:
- [ ] บัญชี `platform_role = user` (ค่าเริ่มต้น) → ไม่เห็นทางเข้า Moderation Queue เลยในทุกจุดของแอป
- [ ] บัญชี `platform_role = moderator` หรือ `admin` → เห็นทางเข้าและเปิด Moderation Queue ได้ เห็นรายการ Report สถานะ pending/reviewing เรียง FIFO
- [ ] เปิดรายละเอียด Report → เห็นเนื้อหา/target ที่ถูกรายงานจริง ไม่เห็นตัวตนผู้รายงาน
- [ ] เลือก Action "No Action" → Report ปิดเป็น dismissed ไม่มีผลกับเนื้อหา/ผู้ใช้
- [ ] เลือก "Warning" → ผู้ถูก report ได้รับ notification พร้อมเหตุผล ไม่ถูกจำกัดสิทธิ์อะไร
- [ ] เลือก "Remove Content" บน Drop/Comment/Club Post → เนื้อหาถูกลบจริง (ผู้เขียนเห็นสถานะถูกลบเพราะละเมิดกฎ คนอื่นมองไม่เห็น)
- [ ] เลือก "Restrict" 3 วัน → บัญชีเป้าหมายโพสต์/comment ไม่ได้ทันที ยัง login/ดู/like ได้ปกติ ครบ 3 วันแล้วคืนสิทธิ์อัตโนมัติ
- [ ] เลือก "Suspend" 3 วัน → บัญชีเป้าหมาย login ไม่ได้ทันที เซสชันเดิมถูก force logout ครบ 3 วันแล้ว login ได้อัตโนมัติ
- [ ] เลือก "Ban" → บัญชีเป้าหมาย login ไม่ได้ถาวรจนกว่า admin จะ unban ด้วยมือ (ไม่มี auto-expire)
- [ ] ทุก Action บันทึกลง `moderation_actions` ครบ (report_id, action_type, reason, reviewer_id, เวลา) ตรวจสอบผ่าน DB ได้
- [ ] Regression: ผู้ใช้ทั่วไป (`platform_role = user`) ใช้งานทุกฟีเจอร์เดิมได้ปกติไม่มีอะไรเปลี่ยน

Dependencies: WYN-026 (Report — ต้องเสร็จก่อน เพราะ Queue อ่านจากตาราง `reports`), WYN-002/003 (Auth/Profile — Approved, ต้องแก้ login flow ให้เช็ค suspend/ban)

Priority: P0 — ตามคำตัดสินใจของ Founder (2026-08-22) ให้ Phase 1 ใช้งานได้จริงตั้งแต่ตอนนี้ ไม่รอ Phase 7

Risks:
- **Privilege escalation ผ่าน `platform_role`**: ต้องแน่ใจว่าไม่มี RLS/RPC ใดให้ client เปลี่ยนค่า `platform_role` ของตัวเองหรือคนอื่นได้เลย (ไม่มี update policy บน column นี้จาก client ฝั่งไหนทั้งสิ้น) — ตั้งค่าได้ทาง Supabase Dashboard/SQL โดย Founder เท่านั้นในรอบนี้ ล้อ pattern เดียวกับที่ WYN-014 ป้องกัน owner_id ไม่ให้ client แก้เอง
- **Restrict/Suspend/Ban ต้องบังคับใช้ที่ RLS ไม่ใช่แค่ UI**: ถ้าจำกัดแค่ฝั่ง Dart (ซ่อนปุ่ม) ผู้ใช้ที่ถูก Restrict ยังเรียก Supabase API ตรงเพื่อโพสต์ได้ — ต้องมี RLS policy บน `drops`/`club_posts`/`drop_comments` เช็คสถานะบัญชีก่อน insert เสมอ, Suspend/Ban ต้องเช็คตอน login (ก่อน issue session ใหม่) และ invalidate session เดิมจริง (ตรวจสอบวิธี force-logout ที่ Supabase Auth รองรับ)
- **Auto-expire ของ Restrict/Suspend ต้องมีกลไกจริง**: ไม่ใช่แค่เก็บ `expires_at` เฉย ๆ — ต้องมี logic เช็ค `expires_at < now()` ทุกจุดที่ enforce (RLS/login check) แทนพึ่ง cron job แยกที่ยังไม่มีในระบบ (แนะนำเช็คแบบ on-read/on-write ไม่ใช่ batch job เพื่อไม่ต้องเพิ่ม infrastructure ใหม่)
- **หน้าจอนี้เป็นเครื่องมือภายในชั่วคราว**: เมื่อถึง Phase 7 (WYN Admin) ต้องตัดสินใจว่าจะถอดหน้าจอนี้ออกจากแอป consumer หรือเก็บไว้เป็น fallback — บันทึกไว้เป็นการตัดสินใจที่ต้องทำตอนถึง Phase 7 ไม่ใช่ตอนนี้
- **ยังไม่มี Priority/Risk Classification อัตโนมัติ**: Master Spec ข้อ 41 (Admin Report Center, Phase 7) พูดถึง "Reports → Priority → Risk Classification" แต่รอบนี้ (ขั้นต่ำ) ใช้แค่ FIFO เรียงตามเวลา — ยกเว้นไว้เป็นงานของ Phase 7 ที่ทำเต็มรูปแบบ

Recommendation:
1. ทำหลัง WYN-026 เสร็จสมบูรณ์ (ต้องมี Report ให้ดูก่อนถึงจะทดสอบ Queue ได้จริง) — ทำขนานกับ WYN-027/028 ได้เพราะ scope ไม่ชนกัน
2. เก็บ UI ให้เรียบง่ายที่สุดเท่าที่ทำงานได้จริง (list + detail + action button) ไม่ต้องขัดเกลาสวยงามระดับ Production Admin เพราะจะถูกแทนที่ด้วย WYN Admin ใน Phase 7 อยู่แล้ว — ไม่ควรลงทุนเวลากับ UI polish ของหน้าจอนี้มากเกินจำเป็น
3. ตั้งค่า `platform_role` ให้ Founder เป็น `admin` ทันทีที่ deploy เป็นบัญชีแรก (ทำผ่าน SQL โดย AI Deploy & DevOps ตอน deploy จริง ไม่ใช่ AI Coding ตอน implement)

Handoff: AI Design — ออกแบบ Moderation Queue screen (list + detail + action confirmation ขั้นต่ำ), entry point ที่ซ่อนใน Settings, และ UI แจ้งสถานะบัญชีตอน Restrict/Suspend/Ban (ทั้งตอน login และตอนพยายามโพสต์)

---

## Design Output (2026-08-22)

ดูรายละเอียดเต็มที่ `.wyn/docs/design/wyn-029-moderation-queue.md` สรุปสั้น:

- **Entry point**: `SettingsScreen` (WYN-027/028) เพิ่ม section ที่ 2 "เครื่องมือผู้ดูแล" — แสดงเฉพาะเมื่อ `platformRole != user` โดยส่งค่านี้เข้ามาจาก `ViewProfileScreen`'s profile ที่ fetch อยู่แล้ว (ไม่ยิง query เพิ่ม, ไม่มีทางส่ง userId อื่นมาแทนที่ได้จาก UI นี้)
- **Queue/Detail/Action ทั้งหมด reuse pattern เดิม ไม่ประดิษฐ์ของใหม่**: list ใช้โครง `BlockedListScreen`/`NotificationListScreen`, การยืนยัน Action (เหตุผลบังคับ + duration picker เฉพาะ Restrict/Suspend) เป็น **bottom sheet เดียวใช้ซ้ำทั้ง 6 action** (`ModerationActionSheet`) reuse โครง `ReportSheet` ทั้งดุ้น — ปุ่มยืนยันไม่ใช้สีแดงแม้กับ Ban (สืบทอดกติกาเดิมทั้งแอป), Ban มีข้อความเตือนพิเศษว่ายกเลิกได้เฉพาะทาง DB เท่านั้น (ไม่มีปุ่ม Unban ในแอปรอบนี้)
- **Warning/Remove Content ใช้ระบบ Notification เดิม (WYN-012) แทนสร้าง UI ใหม่**: เพิ่ม `NotificationType` 2 ค่าใหม่ — แถวของ 2 type นี้ **ซ่อนตัวตนผู้ตรวจสอบ (reviewer) เสมอ** (ไอคอนระบบคงที่ + คำว่า "ทีมงาน WYN" แทน avatar/username จริง) หลักการเดียวกับที่ WYN-026 ซ่อนตัวตนผู้รายงาน คนละทิศทาง — Remove Content ทำให้เนื้อหาหายไปจากทุกคนรวมเจ้าของเอง (เหมือนลบเอง) แทนการสร้าง grayed-out-tile ใหม่ใน 4+ grid/list ที่ต่างกัน
- **Suspend/Ban**: `AuthGate` เพิ่ม gate ใหม่ก่อนเช็ค `hasUsername` — พบว่าถูกระงับ → sign out ทันที + แสดง `AccountRestrictedScreen` ใหม่ (เหตุผล + กำหนดเวลาถ้า Suspend) — ระบุกับดักไว้ตรงๆ ว่าต้องเก็บเป็น local state ของ `_AuthGateState` ไม่ใช่อ่านจาก `StreamBuilder` ตรงๆ มิฉะนั้นข้อความจะหายทันทีที่ sign-out เสร็จเพราะ auth listener เดิม `popUntil isFirst` อยู่แล้ว
- **Restrict**: widget ใหม่ `RestrictionBanner` (reuse visual เดียวกับ `ViewProfileScreen._buildBlockedBanner`) แทรกที่ `CreateDropScreen`/Comment composer ของ `DropDetailScreen`+`ClubPostDetailScreen`/`CreateClubScreen` — ปุ่มโพสต์ปิดใช้งานเพิ่มเงื่อนไข `!_isRestricted` — **ไม่แตะ Pop เลยแม้แต่บรรทัดเดียว** ตามกติกาเดิม (Pop ระงับการพัฒนา)
- **Data/security notes สำคัญ**: `moderation_actions` ต้องไม่เปิดกว้างแบบ `profiles` (เหตุผลการถูกดำเนินการเป็นข้อมูลอ่อนไหว), แนะนำ RPC เดียว `get_my_moderation_status()` ให้ทั้ง login-check และ restrict-banner เรียกร่วมกัน, Remove Content/Restrict/Suspend ต้องบังคับใช้ที่ RLS จริงไม่ใช่แค่ UI (ตาม Product's Risk)
- **3 จุดตีความที่แนะนำให้ AI Coding ยืนยันสั้นๆ กับ Founder ก่อนเริ่ม** (ไม่ใช่ Founder-authority ตาม RULES.md แต่เป็นการตีความ HOW ที่อาจผิดเจตนา ดำเนินการตามค่าเริ่มต้นที่ Design เสนอไว้ได้เลยถ้า Founder ไม่ทักท้วง): (1) moderator เห็นตัวตนผู้รายงานได้หรือไม่ในการทำงานจริง (Design เสนอว่ายังไม่เห็น ตรงตาม WYN-026 เดิม), (2) Warning/Restrict/Suspend/Ban ต่อ report ประเภท `club` กระทำต่อ owner ของ Club, (3) Remove Content แจ้งผ่าน notification แทน UI แบบ grayed-out tile

Handoff: AI Coding — เริ่มจาก data layer ตามลำดับใน design doc's Handoff section: (1) `platform_role` column, (2) `reports` RLS สำหรับ moderator, (3) `moderation_actions` table + `apply_moderation_action()` RPC, (4) `get_my_moderation_status()` RPC, (5) RLS enforcement (soft-delete filter, restrict/suspend insert filter, login check) — แล้วค่อยเข้า UI ตาม Screen 1-7

---

## Coding Output (2026-08-22)

Implementation: Data layer per the Handoff order — `platform_role` column on `profiles` with **two-layer self-escalation guard** (INSERT policy pins `platform_role = 'user'` regardless of what a client sends; an UPDATE trigger, `profiles_prevent_platform_role_change`, mirrors `clubs_prevent_owner_id_change` and blocks any client-side change entirely — promotion only ever happens by a superuser disabling the trigger directly in SQL, documented inline), `moderation_queue` view (deliberately **not** `security_invoker` — re-implements caller-based visibility itself via `internal.current_platform_role() <> 'user'` in its own `where` clause, so `reporter_id` stays structurally unreachable to a moderator even via a raw REST call, not just omitted from the column list — `reports`' own reporter-only SELECT policy is untouched), `moderation_actions` table (`report_id`/`target_user_id`/`action_type`/`reason` (not-blank constraint)/`duration_days`+`expires_at` (CHECK ties these to exactly `restrict`/`suspend`)/`reviewer_id`), `apply_moderation_action()` RPC (single atomic entry point: validates caller is moderator/admin, validates reason/duration, `select ... for update` on the report row as the double-action guard instead of a claim/reviewing mechanic, resolves the target account per `target_type` the same way `submit_report()` already does, writes the audit row, closes the report, and performs the action's real effect — Remove Content **hard-deletes** the content, reusing the same mechanism self-delete already uses elsewhere rather than inventing a new soft-delete column), `get_my_moderation_status()` RPC (`auth.uid()`-scoped only, single source of truth for both the login gate and the posting banner), and `internal.is_posting_blocked()`/`internal.current_platform_role()` helpers (both in the `internal` schema per the WYN-027 lesson, not `public` with no grant). RLS enforcement added to `drops`/`drop_comments`/`clubs`/`club_posts`/`club_post_comments` INSERT policies via `internal.is_posting_blocked()` — auto-expiry is inherent to its own `expires_at > now()` check, no cron job. Pop untouched (no `pops`/`pop_comments` policy change, no `pop_*.dart` file touched).

Dart: new `app/lib/features/moderation/**` (`ModerationRepository`, `ModerationReport`/`ModerationActionType`/`ModerationStatus`/`ModerationTargetSummary` models, `ModerationQueueScreen`, `ModerationReportDetailScreen`, `ModerationActionSheet`), `AccountRestrictedScreen` + `AuthGate` changes for the Suspend/Ban login block, `RestrictionBanner` (new shared widget, reuses `ViewProfileScreen._buildBlockedBanner`'s visual shape) wired into `CreateDropScreen`, `DropDetailScreen`'s comment composer, `ClubPostDetailScreen`'s comment composer, `CreateClubScreen`, `SettingsScreen` gets the hidden "เครื่องมือผู้ดูแล" entry point gated on `platformRole` passed in from the already-fetched profile (no extra query), `Profile`/`ProfileRepository` gain `platformRole`, `ReportTargetType`/`ReportCategory` get label additions for the queue list, notification system gains `moderation_warning`/`moderation_content_removed` types with a denormalized `reason` column (moderation_actions itself is never readable by the target).

Tests: 8 new test files (`account_restricted_screen_test.dart`, `auth_gate_test.dart`, `moderation_action_sheet_test.dart`, `moderation_queue_screen_test.dart`, `moderation_report_detail_screen_test.dart`, `restriction_banner_test.dart`, `recording_auth_repository.dart`, `recording_moderation_repository.dart`) plus updates to `notification_list_screen_test.dart`/`settings_screen_test.dart`. `flutter test`: **426/426 passed** (baseline 395 + 31 new, no regression). `flutter analyze`: clean, 0 issues. SQL verified against real local Postgres 16 with a new persisted regression script, `supabase/tests/wyn_029_moderation_queue_test.sh` (32 checks: self-escalation insert+update guards, moderator-only queue access with reporter_id structurally unreachable, all 6 actions' real effects, double-action rejection, Restrict/Suspend enforcement + auto-expiry via `expires_at > now()`, Ban permanence, club-target-resolves-to-owner, Remove-Content-rejected-for-user/club, Pop untouched even for a banned author).

Known limitation, disclosed proactively: promoting a user to `moderator`/`admin` requires a superuser to run `alter table public.profiles disable trigger profiles_prevent_platform_role_change;`, the `UPDATE`, then re-`enable` — documented inline in `schema.sql` and matches the Product spec's "ตั้งค่าได้เฉพาะทาง Supabase โดยตรง" requirement, but is a manual, easy-to-get-wrong operational step worth a short runbook note for whoever (Founder) does the first promotion.

Note on delivery: this Coding session hit its own usage/session limit mid-task, immediately before running the test suite. The calling session verified the work independently afterward before writing this section: reviewed the full `schema.sql` diff, ran `flutter analyze` (clean) and `flutter test` (426/426) fresh, and ran `supabase/tests/wyn_029_moderation_queue_test.sh` plus the pre-existing `wyn_021_club_post_mentions_rls_test.sh`/`wyn_027_is_blocked_either_way_rpc_exposure_test.sh` (both still pass, no cross-task regression) against a fresh local Postgres 16 before committing this as done rather than as an unverified checkpoint.

Handoff: AI QA & Security — test WYN-029 against all Acceptance Criteria, in particular the 3 flagged interpretation calls (reporter-visibility-to-moderators, club-target semantics, Remove-Content-via-notification) and the login force-logout race condition Design's Screen 6 called out.

---

## Independent QA — Round 1 (AI QA & Security, 2026-08-22) — FAIL

**บริบท**: AI Coding ส่งมอบ WYN-029 แล้ว (ดู "Coding Output" ด้านบน) — session ที่ทำ Coding hit usage limit ของตัวเองตอนใกล้จะรัน test suite แต่งานที่ทำไว้ครบสมบูรณ์และผ่าน verification อิสระ (flutter analyze/test/SQL regression 32 เคส) ก่อนจะเข้าสู่ QA รอบนี้ — ทำ QA อิสระเต็มรูปแบบต่อทันที

**สิ่งที่ทำ**:

1. อ่าน diff เต็มของ `supabase/schema.sql` ทั้งหมดด้วยตัวเอง (ไม่ใช่แค่เชื่อ Coding Output) — ยืนยันว่า `platform_role` มี guard สองชั้นถูกต้อง (INSERT policy pin ค่า + UPDATE trigger กันเปลี่ยน), `moderation_queue` view ออกแบบถูกต้อง (ไม่ใช้ `security_invoker`, re-implement caller-based visibility เอง ทำให้ `reporter_id` ไม่มีทางเข้าถึงได้แม้แต่ moderator), helper function ใหม่ (`internal.current_platform_role`/`internal.is_posting_blocked`) อยู่ schema `internal` ถูกต้องตามบทเรียน WYN-027
2. รัน `supabase/tests/wyn_029_moderation_queue_test.sh` ที่ Coding เขียนไว้เอง — 32/32 PASS
3. รัน `wyn_021_club_post_mentions_rls_test.sh`/`wyn_027_is_blocked_either_way_rpc_exposure_test.sh` ซ้ำ (cross-task regression) — ผ่านทั้งคู่
4. รัน `flutter analyze`/`flutter test` อิสระเอง — สะอาด, 426/426 ตรงกับที่ Coding รายงาน
5. อ่านโค้ด `AuthGate` เจาะจงจุด race condition ที่ Design เคยเตือนไว้ (Screen 6) — ยืนยันว่าโค้ดจริงแก้ถูกต้อง (`_blockedInfo` เป็น local State เช็คก่อน StreamBuilder เสมอใน `build()` ไม่มีทาง race กับ auth-state event ที่ยิงหลัง signOut() เสร็จ)
6. **ทดสอบ input validation เพิ่มเติมนอกเหนือ AC** (ไม่มีใน 32 เคสเดิม): report_id ไม่มีจริงถูกปฏิเสธ, action_type ที่ไม่รู้จักถูกปฏิเสธ, duration_days ผิดค่า (เช่น 2) ถูกปฏิเสธ, restrict ไม่ระบุ duration ถูกปฏิเสธ, reason ว่างถูกปฏิเสธ — ผ่านหมดทุกเคส
7. **พบ Major finding ใหม่ที่ไม่มีใน AC**: ตั้งคำถามว่าการป้องกัน "reviewer identity ต้องไม่รั่วถึงผู้ถูกดำเนินการ" (ที่ comment ในโค้ดทั้ง SQL และ Dart ยืนยันตรงๆ ว่า "ต้องไม่มีทางรั่ว") ถูกบังคับใช้จริงที่ชั้นไหน — พบว่า `apply_moderation_action()` insert `actor_id = v_reviewer` (ตัวตนจริงของ moderator) ลงใน `notifications` table สำหรับ Warning/Remove Content ทั้งที่ `notifications`'s SELECT policy เปิดให้ผู้รับ (`recipient_id = auth.uid()`) เห็นทุกคอลัมน์ของแถวตัวเองอยู่แล้ว (RLS เป็น row-level ไม่ใช่ column-level) — พิสูจน์จริงด้วย Postgres: สร้าง moderator ชื่อ "Secret Moderator" ส่ง Warning ให้ Alice แล้ว query ในฐานะ Alice เองด้วย query รูปแบบเดียวกับที่ `notification_repository.dart` ใช้จริง (`actor:profiles!notifications_actor_id_fkey(...)`) → **เห็น `actor_username = 'the_mod'`, `actor_display_name = 'Secret Moderator'` ตรงๆ** — แม้ `NotificationListScreen` จะตั้งใจไม่แสดงชื่อนี้ในหน้าจอ (`_hidesActorIdentity()`) แต่เป็นการซ่อนที่ชั้น UI เท่านั้น ไม่ใช่ access-control boundary จริง ข้อมูลยังคง fetch ได้เต็มทุกครั้งที่แอปเรียก query เดิม (หรือผ่าน raw REST call ตรงๆ) — เป็นบั๊ก class เดียวกับที่เพิ่งเจอใน WYN-027 (`is_blocked_either_way`) เป๊ะ: พึ่งว่า "หน้าจอไม่แสดง" แทน "ข้อมูลเข้าถึงไม่ได้จริง" รายละเอียด/reproduction/fix เต็มที่ `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md`

**Regression**: ไม่มี regression ใดๆ นอกจาก finding ข้อ 7 ที่พบใหม่ — ทุกอย่างที่ Coding claim ว่าถูกต้อง (self-escalation guard, RLS enforcement ของ Restrict/Suspend/Ban, auto-expiry, reporter identity protection ใน `moderation_queue` view, Pop ไม่ถูกแตะ, AuthGate race condition) ยืนยันจริงด้วยตัวเองครบทุกจุด

**ผลลัพธ์: WYN-029 — FAIL (Major)** — ส่งต่อ AI Debug Engineer พร้อม bug report เต็มที่ `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` (ข้อเสนอ fix: relax `notifications.actor_id` เป็น nullable แล้ว insert null สำหรับ Warning/Remove Content แทน `v_reviewer` — `moderation_actions.reviewer_id` ที่ป้องกันไว้ถูกต้องอยู่แล้วยังคงเป็น audit trail หลักต่อไปโดยไม่ต้องเปลี่ยน)

---

## Independent QA — Round 2 (AI QA & Security, 2026-08-22) — PASS

**บริบท**: AI Debug Engineer แก้ Major finding จากรอบ 1 (commit `1595d6f` — relax `notifications.actor_id` เป็น nullable, `apply_moderation_action()` insert `null` แทน `v_reviewer` สำหรับ Warning/Remove Content, แก้ `WynNotification`/`notification_list_screen.dart` ให้ null-safe) — ตรวจสอบอิสระทั้งหมดเอง ไม่เชื่อรายงานของ Debug เฉยๆ

**สิ่งที่ทำ**:

1. อ่าน diff จริงของ `1595d6f` ทั้ง SQL และ Dart — ตรงตามข้อเสนอ fix ในรายงานบั๊กเป๊ะ, ไม่มีการเปลี่ยน logic อื่นนอกเหนือขอบเขต
2. รัน `flutter analyze` อิสระ — สะอาด 0 issues
3. รัน `supabase/tests/wyn_029_moderation_queue_test.sh` ที่ Debug ขยายเพิ่ม (36 เคสจาก 32 เดิม) — **36/36 PASS**
4. **สร้างฐานข้อมูล PostgreSQL 16 ใหม่ทั้งหมดของ QA เอง** (คนละ DB กับ Debug) apply schema.sql ตัวจริงที่แก้แล้ว แล้ว**เขียน probe ของตัวเองใหม่ทั้งหมด** (ไม่ reuse ของ Debug) จำลอง Alice โดน moderator "Secret Moderator" warn เหมือนรอบ 1 ทุกประการ แล้ว query ในฐานะ Alice 2 แบบ: (1) INNER JOIN แบบเดิมที่เคยพิสูจน์การรั่วได้ในรอบ 1 → **0 แถว** (2) **LEFT JOIN แบบตรงไปตรงมา** (เลี่ยงกับดักที่ INNER JOIN อาจแค่ "กรองแถวว่างทิ้งไปเงียบๆ" จนดูเหมือนไม่รั่วทั้งที่จริงอาจยังมีข้อมูลอยู่) → `actor_id`/`actor_username` เป็น **NULL ทั้งคู่จริง** ไม่ใช่แค่ไม่ match join — ยืนยันว่าปิดช่องโหว่จริง ไม่ใช่แค่ซ่อนผลลัพธ์
5. ยืนยัน `moderation_actions` (audit trail ตัวจริง) ยังคงถูกป้องกันเหมือนเดิม — target เห็น 0 แถว
6. รัน `wyn_021_club_post_mentions_rls_test.sh` (5/5) และ `wyn_027_is_blocked_either_way_rpc_exposure_test.sh` (9/9) ซ้ำ — ไม่มี cross-task regression
7. รัน `flutter test` อิสระเต็มโปรเจกต์ — **433/433 ผ่าน** ตรงกับที่ Debug รายงาน (เพิ่มจาก 426 เดิม, ไม่มี regression)

**ผลลัพธ์: WYN-029 — PASS (รอบ 2)** ย้ายกลับเข้า `.wyn/tasks/approved/` แล้ว ปิด `.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md` เป็น closed — พร้อมส่ง AI Deploy & DevOps เมื่อ Founder พร้อม deploy จริง (ยังไม่ deploy เพราะยังไม่มี production Supabase project จริง — gate เดิมที่ทุก task ก่อนหน้าเจอ)
