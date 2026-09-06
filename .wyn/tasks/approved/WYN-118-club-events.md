# Product Task — WYN-118

Status: approved
Owner: AI Product Manager

Feature: Club Events — นัดกิจกรรม/meetup ภายใน Club พร้อม RSVP

Goal: เพิ่มเหตุผลให้สมาชิกกลับมาเปิดแอปและมีปฏิสัมพันธ์กันนอกเหนือจากโพสต์ปกติ — ตรงกับ target user ของ WYNOS (มหาวิทยาลัย/แฟนคลับ/งานอดิเรกเฉพาะทาง ตาม `wynos-gtm-roadmap.md`) มากที่สุดในบรรดา 4 ตัวเลือก

Target User: Owner/Admin ที่ต้องการนัดกิจกรรม และสมาชิกที่ต้องการเข้าร่วม/ดูว่าใครไปบ้าง

Problem: Founder Brief เดิม (ข้อ 19) ระบุ "Community Events" เป็นฟีเจอร์ future ตั้งแต่แรก ยังไม่มีระบบนี้เลยในปัจจุบัน — Club ที่เป็นกลุ่มกิจกรรมจริง (เช่น กลุ่มถ่ายภาพ/กีฬา/มหาวิทยาลัย) ไม่มีทางนัดรวมตัวกันในแอปได้ ต้องออกไปใช้เครื่องมืออื่น (LINE/Facebook Event) ซึ่งลดเหตุผลที่จะอยู่บน WYNOS ต่อ

Requirements:
- Owner/Admin/Moderator สร้าง Event ได้ (ชื่อ, รายละเอียด, วันเวลา, สถานที่ — ออนไลน์ระบุลิงก์ / ออฟไลน์ระบุที่อยู่ข้อความอิสระ ไม่ต้องมี map integration ใน V1)
- สมาชิกกด RSVP ได้ (ไป / ไม่ไป / อาจจะไป) เห็นจำนวน+รายชื่อคนที่ตอบรับ
- Event ที่จะถึงแสดงอยู่ในหน้า Club (เช่น การ์ดด้านบน Posts tab หรือแท็บใหม่ "Events" — ให้ Design ตัดสินใจตำแหน่งที่ไม่ทำให้ Club Page แน่นเกินไป)
- แจ้งเตือนสมาชิกที่ RSVP ไว้ก่อนกิจกรรมเริ่ม (ต่อยอด WYN-116 ถ้าทำเสร็จก่อนแล้ว)

Acceptance Criteria:
- สร้าง Event ในกติกาสิทธิ์เดียวกับ Pinned Post (Owner/Admin/Moderator เท่านั้น)
- สมาชิกทุกคนของ Club (approved) เห็น Event และ RSVP ได้ ไม่ใช่สมาชิกเห็น/RSVP ไม่ได้ (ตาม trust model เดิมของ Club)
- Event ที่ผ่านไปแล้วแยกจาก Event ที่กำลังจะถึง ไม่ปนกันจนหาไม่เจอ

Dependencies: ควรทำหลัง WYN-116 (re-engagement notification) เพื่อให้แจ้งเตือน RSVP reminder ใช้ infra เดียวกันได้เลย ไม่ต้องสร้างระบบแจ้งเตือนแยก

Priority: P2 — Founder เลือกเป็นลำดับ 4 (สุดท้าย) ใน Club Growth Roadmap — scope ใหญ่ที่สุดในกลุ่ม กระทบ data model ใหม่ทั้งหมด (ตาราง Event + RSVP)

Risks: Scope คืบง่ายที่สุดในบรรดา 4 ตัว (เช่น อยากเพิ่ม reminder หลายระดับ, recurring event, check-in ณ สถานที่จริง) — ต้องคุมให้อยู่แค่ "นัด + RSVP" ตามที่ Founder Brief เดิมเตือนไว้เรื่องไม่ใส่ฟีเจอร์อนาคตจนซับซ้อนเกินจำเป็น

Recommendation: ทำเป็นลำดับสุดท้ายตามที่ Founder เลือก — รอดูว่า WYN-115/116/117 ทำให้ Club active ขึ้นจริงหรือไม่ก่อน เพราะ Events มีค่าก็ต่อเมื่อ Club มีสมาชิกที่ active มากพอจะนัดรวมตัวกันได้จริง

Handoff: AI Design (โครงสร้างหน้า Event + RSVP UI) → AI Coding (ตาราง Event/RSVP ใหม่ + RLS ตาม trust model ของ Club เดิม) → AI QA & Security

---

## AI Design Output

ดู `.wyn/docs/design/wyn-118-club-events.md` — แท็บใหม่ "กิจกรรม" เห็นเฉพาะ approved member (ต่อท้าย About, ก่อน Insights เสมอเพราะ canManageClub ⟹ approved member), RSVP โหวตตรงในการ์ดแบบ Poll ไม่มีหน้า Detail แยก, **ตัดการแจ้งเตือน "ก่อนกิจกรรมเริ่ม" ออกจาก V1 อย่างชัดเจน** เพราะต้องใช้ cron/scheduled-job infra ที่ระบบนี้ไม่มีเลย (ไม่ใช่แค่ trigger ตอบสนอง event แบบ WYN-115/116) — Acceptance Criteria จริงไม่ได้ระบุเงื่อนไข reminder ไว้เลย

## AI Coding Output

**Files Changed**:
- `supabase/schema.sql` — ตาราง `club_events`(สิทธิ์ insert/update/delete = `canModeratePosts` tier owner/admin/moderator, staff จัดการ event ของกันและกันได้ ไม่ใช่แค่ของตัวเอง) + `club_event_rsvps`(RLS select เปิดให้ approved member ทุกคนเห็น RSVP ของคนอื่นได้ ต่างจาก poll vote ที่ private) + `validate_club_event_rsvp()` trigger (มิเรอร์ `validate_club_poll_vote()`) + RPC `club_event_rsvp_counts()` (**ไม่ใช่** security definer เพราะ RLS เดิมครอบคลุมการมองเห็นให้แล้วเมื่อรันเป็น invoker)
- `supabase/tests/wyn_118_club_events_test.sh` — regression 19 checks (real Postgres, ครอบคลุม RLS/permission tier/posting-block/RSVP re-vote/cross-club leak)
- `app/lib/features/club/data/club_event.dart` (ใหม่) — `ClubEvent`/`RsvpStatus`/`ClubEventAttendee` model + `withRsvp()` optimistic-update มิเรอร์ `ClubPost.votedPoll()`
- `app/lib/features/club/data/club_event_repository.dart` (ใหม่) — fetch upcoming/past + batch RSVP-state fetch (มิเรอร์ pattern `_fetchPollStates`) + create/update/delete/setRsvp/fetchAttendees
- `app/lib/features/club/presentation/widgets/club_event_card.dart` (ใหม่) — การ์ด+ปุ่ม RSVP 3 ปุ่ม+attendee bottom sheet
- `app/lib/features/club/presentation/widgets/club_events_tab.dart` (ใหม่) — list เดียว 2 ส่วน (กำลังจะถึง/ผ่านมาแล้ว) + FAB สร้าง event เฉพาะ staff
- `app/lib/features/club/presentation/create_club_event_screen.dart` (ใหม่) — ฟอร์ม create/edit (ใช้ร่วมกันตาม `existingEvent` param)
- `app/lib/features/club/presentation/club_page.dart` — `_tabControllerFor` length สูตรใหม่ `3 + (approved?1:0) + (canManageClub?1:0)`, เพิ่ม `ClubEventRepository` แบบ injectable (optional param มิเรอร์ pattern `_profileRepository` ของ `CreateClubPostScreen`)
- Tests ใหม่: `club_events_tab_test.dart`, `create_club_event_screen_test.dart`, กลุ่ม "Events tab (WYN-118)" ใน `club_page_test.dart`, `recording_club_event_repository.dart` fake

**Tests**: `flutter analyze` clean, `flutter test` เต็มชุด 1299/1299 PASS, `wyn_118_club_events_test.sh` 19/19 PASS, `wyn_117`/`wyn_116`/`wyn_115`/`wyn_021` re-run ยืนยันไม่มี regression, `check_schema_ordering.py` OK

**Handoff**: ส่งต่อ AI QA & Security

## AI QA & Security Output

**Feature**: WYN-118 (Club Events) — commit `1673d01` (rebase แล้วหลัง WYN-117 merge, ผ่าน conflict resolution 1 จุดใน `club_page.dart`)

**Environment**: Local PostgreSQL 16 จริง (RLS ผ่าน `authenticated` role) + Flutter SDK เต็มชุด

**Test Cases**:
1. `wyn_118_club_events_test.sh` — 19 checks รันซ้ำอิสระ
2. `wyn_117`/`wyn_116`/`wyn_115`/`wyn_021` — regression ครบ, `check_schema_ordering.py` OK
3. ตรวจ `club_event_rsvp_counts()` ที่จงใจไม่ใช้ `security definer` — trace ผ่าน Postgres RLS semantics ยืนยันว่าปลอดภัยจริง (event ของ Club ที่ผู้เรียกไม่ได้เป็นสมาชิกจะถูกกรองออกจาก join ตั้งแต่ RLS ของ `club_events` เอง ไม่ใช่แค่ zero ตัวเลข) ยืนยันซ้ำด้วย CHECK17
4. ตรวจ RLS ของ `club_events`/`club_event_rsvps` บรรทัดต่อบรรทัด — staff จัดการ event ของกันและกันได้จริง (ไม่จำกัดแค่ creator_id), RSVP select เปิดให้เห็นของคนอื่นจริง (ต่างจาก poll vote)
5. อ่าน `withRsvp()` ใน `club_event.dart` ทีละบรรทัดทุก transition (null→X, X→X, X→Y) ยืนยัน count ไม่ double-count/ไม่เพี้ยน
6. **อ่านทั้งไฟล์ `club_page.dart` (875 บรรทัด) ใหม่ทั้งหมด** ตรวจการแก้ conflict จาก rebase ว่าไม่มีโค้ดหาย/ซ้ำ, `TabBar.tabs`/`TabBarView.children` ใช้เงื่อนไขเดียวกันทั้งคู่ (`showEvents`/`showInsights`), ยืนยัน `canManageClub ⟹ approved member` จริงทั้งฝั่ง Flutter และ DB (`club_role()` กรอง `status='approved'` ก่อน return เสมอ)
7. ยืนยันเองว่าไม่มี cron/scheduled-job infra จริง (`grep` หา `pg_cron`/`cron.schedule` ใน schema.sql ไม่เจอเลย) — เหตุผลตัด reminder ออกจาก V1 มีมูลจริง ไม่ใช่ข้ออ้างลอยๆ
8. `flutter analyze` + `flutter test` เต็มชุด (1319/1319 PASS — ตัวเลขสูงกว่าที่ Coding รายงานเพราะมีงานคู่ขนานจากเซสชันอื่น merge เข้า main ระหว่างทาง ไม่ใช่ regression)
9. สแกน secret ใน commit diff — ไม่พบ (เจอแค่ dummy `'test-key'` fixture เดิมที่ทุก Recording*Repository ใช้อยู่แล้ว)

**Passed**: ครบทุกจุด — 19/19 + regression เดิมครบ, `flutter analyze` clean, `flutter test` 1319/1319 PASS, ไม่พบช่องโหว่, การแก้ conflict หลัง rebase ตรวจแล้วถูกต้องสมบูรณ์

**Failed**: ไม่มี

**Severity**: N/A — มี 2 ข้อสังเกตเล็กน้อยไม่ block: (1) การ์ด Event ไม่มีปุ่มดูรายชื่อ "ไม่ไป" (repository/RPC รองรับอยู่แล้ว แค่ UI ไม่เรียกใช้ — ไม่ใช่ AC ที่ต้องมี) (2) ฟอร์มสร้าง Event เลือกวันที่ย้อนหลังได้ถึงเมื่อวาน ไม่มี validation กันวันที่ผ่านมาแล้ว — ไม่ใช่ security issue ทั้งคู่เป็นแค่ backlog item ให้พิจารณาทีหลัง

**Security Findings**: ไม่พบช่องโหว่ — RPC ที่ไม่ใช้ security definer ปลอดภัยจริงตามที่ออกแบบไว้ (ยืนยันด้วยการ trace RLS semantics + CHECK17), staff จัดการ event ของกันและกันได้จริงตามเจตนา, `validate_club_event_rsvp()` trigger เป็นชั้นบังคับ membership+posting-block จริง (RLS insert อย่างเดียวเช็คแค่ "เป็นตัวเอง"), invariant `canManageClub ⟹ approved member` ยืนยันแล้วทั้ง 2 ชั้น

**Recommendation**: อนุมัติ deploy ได้

**Final Status: PASS**

**Handoff**: ส่งต่อ AI Deploy & DevOps
