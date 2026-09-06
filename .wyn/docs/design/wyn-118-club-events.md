# Design — WYN-118 (Club Events)

> ต่อยอด Product spec ที่ `.wyn/tasks/active/WYN-118-club-events.md` — อ่านก่อนเริ่ม
> Scope ใหญ่ที่สุดในกลุ่ม Club Growth Roadmap (ตาราง Event/RSVP ใหม่ทั้งคู่) — Risks ของ Product เองเตือนเรื่อง scope creep ไว้แล้ว ("นัด + RSVP" เท่านั้น) จึงตัดสินใจเข้มงวดเป็นพิเศษในหัวข้อ "ของที่ตัดออกจาก V1" ด้านล่าง

## สรุปแนวทางที่ reuse จากงานเดิม

1. **สิทธิ์สร้าง/แก้ไข/ลบ Event = สิทธิ์เดียวกับ pin/unpin post** (`canModeratePosts`: owner/admin/moderator) ตาม Acceptance Criteria ที่ระบุตรงๆ — staff คนใดก็แก้/ลบ Event ของคนอื่นในทีมเดียวกันได้ ไม่ใช่แค่ Event ที่ตัวเองสร้าง (มิเรอร์ pattern เดิมของ pin ที่ staff จัดการโพสต์ของกันและกันได้)
2. **สิทธิ์ดู/RSVP = approved member เท่านั้น** เหมือน Club post ทุกอย่าง — ใช้ `club_role()` helper เดิม
3. **Validate RSVP ผ่าน `before insert or update` trigger** มิเรอร์ `validate_club_poll_vote()` (WYN-115) เป๊ะ: เช็ค event มีจริง, เป็นสมาชิก approved, ไม่ถูก posting-block — RSVP เขียนตรงผ่าน RLS ธรรมดา ไม่ต้องมี RPC พิเศษ (ต่างจาก create_poll_club_post ที่ต้อง atomic insert หลายตาราง Event สร้างครั้งเดียวตารางเดียวพอ)
4. **นับ RSVP ผ่าน RPC เดียว batch ทุก event พร้อมกัน** มิเรอร์ pattern `get_club_poll_results()`/`club_insights()` — ไม่ดึง raw rows มานับฝั่ง client

## จุดที่ต้องตัดสินใจใหม่

### 1. ตำแหน่งในหน้า Club: แท็บใหม่ "กิจกรรม" (ไม่ใช่การ์ดบน Posts tab)
เลือกแท็บใหม่เพราะ Event ต้องมีทั้งลิสต์ (กำลังจะถึง + ผ่านมาแล้ว) และ RSVP action ต่อรายการ ถ้ายัดเป็นการ์ดบน Posts tab จะแย่งพื้นที่ feed และไม่มีที่แสดง "ผ่านมาแล้ว" อย่างเป็นระเบียบตาม Acceptance Criteria ("ไม่ปนกันจนหาไม่เจอ")

**การเรียงแท็บ**: โพสต์(0) → สมาชิก(1) → เกี่ยวกับ(2) → **กิจกรรม(3, เห็นเฉพาะสมาชิก approved)** → Insights(4, เห็นเฉพาะ owner/admin, WYN-117) — วางกิจกรรมก่อน Insights เสมอเพราะ `canManageClub` (เงื่อนไขของ Insights) หมายถึงเป็น approved member อยู่แล้วเสมอ (เงื่อนไขของกิจกรรม) ดังนั้นลำดับนี้ไม่มีทาง index ขยับสลับกัน — ปุ่ม "จัดการสิทธิ์สมาชิก" ที่ jump ไป index 1 (สมาชิก) ไม่กระทบ เพราะ index 0-2 คงที่เสมอไม่ว่าจะมีกิจกรรม/Insights หรือไม่ — ต่อยอด `_tabControllerFor()` ที่ WYN-117 วางไว้แล้ว (เปลี่ยนแค่สูตรคำนวณ length เป็น `3 + (isApprovedMember?1:0) + (canManageClub?1:0)`)

ไม่ใช่สมาชิก (approved=false) เห็นแค่ 3 แท็บเดิม ไม่เห็น "กิจกรรม" เลย ตรงกับ Acceptance Criteria ("ไม่ใช่สมาชิกเห็น/RSVP ไม่ได้")

### 2. โครงสร้างหน้า "กิจกรรม" — List เดียว แบ่ง 2 ส่วนด้วย header ไม่ใช่ sub-tab
List เดียวเลื่อนต่อกัน: หัวข้อ "กำลังจะถึง" (เรียงใกล้สุดก่อน) → รายการ Event → หัวข้อ "ที่ผ่านมาแล้ว" (เรียงล่าสุดก่อน) → รายการ Event เก่า — ไม่ทำเป็น sub-`TabBar` ซ้อนใน tab (เพิ่ม complexity โดยไม่จำเป็นตาม scope V1) ปุ่ม "+" (สร้าง Event) เป็น FAB เห็นเฉพาะ staff (`canModeratePosts`)

### 3. RSVP UI: 3 ปุ่มตรงในการ์ด ไม่ต้องมีหน้า Detail แยก
แต่ละ Event card แสดงชื่อ/เวลา/สถานที่/สรุปจำนวน RSVP + ปุ่ม 3 ตัวกดโหวตตรงในการ์ดเลย (ไปแน่นอน/อาจจะไป/ไม่ไป) เหมือนกับที่ Poll (WYN-115) โหวตตรงในการ์ดโดยไม่ต้องเปิดหน้าใหม่ — กดตัวเลข "X ไป" เปิด bottom sheet แสดงรายชื่อ (ตาม Requirements "เห็น...รายชื่อคนที่ตอบรับ")

### 4. Location: ข้อความอิสระ ไม่มี map integration (ตรงตาม Requirements เป๊ะ)
`location_type` เป็น `'online'`/`'offline'` แค่เปลี่ยน label ของช่อง input ("ลิงก์" vs "ที่อยู่") และไอคอนตอนแสดงผล (`Icons.link` vs `Icons.location_on_outlined`) — ไม่ validate URL format, ไม่ผูก map/GPS ใดๆ

### 5. **ตัดออกจาก V1 อย่างชัดเจน: การแจ้งเตือน "ก่อนกิจกรรมเริ่ม"**
Requirements เขียนไว้แบบมีเงื่อนไข ("ต่อยอด WYN-116 ถ้าทำเสร็จก่อนแล้ว") — WYN-116 เสร็จแล้วจริง แต่การแจ้งเตือน "ก่อนเวลาเริ่ม N ชั่วโมง" ต้องใช้กลไก **time-based polling ตามเวลาจริง (cron/scheduled job)** ไม่ใช่ trigger ตอบสนอง event แบบที่ WYN-115/116 ใช้ (insert/update ของแถวในตาราง) ระบบนี้**ไม่มี cron/scheduled-job infrastructure อยู่เลยแม้แต่จุดเดียว** (ยืนยันซ้ำจากคอมเมนต์เดิมเรื่อง `trending` category และ Restrict/Suspend auto-expiry ใน `supabase/schema.sql`) การสร้าง cron จริง (เช่น `pg_cron` extension หรือ GitHub Actions scheduled workflow เรียก RPC) เป็นงาน infrastructure ใหม่ทั้งหมด ไม่ใช่แค่ "ต่อยอด WYN-116" ตามที่ Requirements บอกไว้ตรงๆ

**ตัดสินใจ**: **ไม่ทำการแจ้งเตือนก่อนกิจกรรมเริ่มใน V1 นี้** — ตรงกับ Risks ของ Product เองที่เตือนไว้ชัดว่า "ต้องคุมให้อยู่แค่ 'นัด + RSVP'" การเพิ่ม cron infra ใหม่ทั้งระบบเพื่อ reminder อย่างเดียวคือ scope ที่ใหญ่เกินกว่า "นัด+RSVP" มาก บันทึกเป็น backlog แยก (WYN-119-ish, ไม่ได้อยู่ใน roadmap ปัจจุบัน) ให้ Founder ตัดสินใจเพิ่มทีหลังถ้าต้องการจริง — งานรอบนี้ส่งมอบแค่ "สร้าง Event + RSVP + เห็นรายชื่อ" ตาม Acceptance Criteria ที่ระบุไว้จริง (ไม่มี AC ข้อไหนพูดถึง reminder เลย สังเกตว่า Requirements พูดถึง reminder แต่ Acceptance Criteria ไม่ได้ระบุเป็นเงื่อนไขผ่าน/ไม่ผ่าน)

## Schema ที่แนะนำ

1. `public.club_events` — `id, club_id, creator_id, title, description, starts_at, location_type ('online'|'offline'), location, created_at` + length constraints (มิเรอร์ `club_posts_content_length` เป็นต้นแบบ) — RLS: SELECT ให้ approved member, INSERT/UPDATE/DELETE ให้ `club_role() in ('owner','admin','moderator')` เท่านั้น (INSERT เพิ่ม `with check (creator_id = auth.uid())`)
2. `public.club_event_rsvps` — `event_id, user_id, status ('going'|'maybe'|'not_going'), created_at, updated_at`, PK `(event_id, user_id)` — RLS: SELECT ให้ approved member ของ Club นั้น (ผ่าน join เข้า club_events), INSERT/UPDATE/DELETE ให้เจ้าของแถวเท่านั้น (`auth.uid() = user_id`) — `validate_club_event_rsvp()` trigger เช็ค membership+posting-block เพิ่มอีกชั้น (RLS insert policy เช็คแค่ "เป็นตัวเอง" ไม่เช็ค membership)
3. `public.club_event_rsvp_counts(p_event_ids uuid[])` — RPC **ไม่ต้อง** `security definer` (ต่างจาก RPC อื่นๆ ในโปรเจกต์นี้) เพราะ RLS ของ `club_event_rsvps`/`club_events` เองครอบคลุมการมองเห็นที่ถูกต้องอยู่แล้วเมื่อรันเป็น invoker (`authenticated`) — ปล่อยให้ Postgres บังคับ RLS ตามปกติแทนที่จะ bypass แล้วมาเช็คเอง ง่ายกว่าและปลอดภัยกว่า

## Flutter ที่แนะนำ

- `ClubEvent`/`RsvpStatus` model ใหม่ (`club_event.dart`) — field ครบตาม schema + `myRsvpStatus`/`goingCount`/`maybeCount`/`notGoingCount` (เติมจาก batch RPC เหมือน poll)
- `ClubEventRepository` ใหม่ — `fetchUpcomingEvents`/`fetchPastEvents`/`createEvent`/`updateEvent`/`deleteEvent`/`setRsvp`/`fetchAttendees(eventId, status)`
- `ClubEventsTab` (list เดียว 2 ส่วนตามข้อ 2) + `ClubEventCard` (การ์ด+ปุ่ม RSVP ตามข้อ 3) + `CreateClubEventScreen` (ฟอร์ม title/description/date+time picker/location type toggle/location field) + attendee bottom sheet
- `ClubPage._tabControllerFor` length คำนวณใหม่: `3 + (myRole != null ? 1 : 0) + (myRole?.canManageClub == true ? 1 : 0)` ต่อท้าย `TabBar.tabs`/`TabBarView.children` ด้วย `if` guard เดียวกันทั้งคู่ (มิเรอร์ pattern Insights ของ WYN-117 เป๊ะ)

## Handoff

AI Coding → AI QA & Security
