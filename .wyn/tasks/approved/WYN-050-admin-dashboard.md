# Product Task — WYN-050

Status: approved (Independent QA FAIL รอบแรก — พบช่องโหว่ Major, แก้ทันทีเป็น fast-follow — PASS รอบสอง — ดูหัวข้อ "Independent QA" ท้ายไฟล์ — ส่งต่อ AI Deploy & DevOps)
Owner: AI Product Manager

Feature: WYN Admin Dashboard — Platform metrics (DAU/MAU/content/report counts)

Goal: task ที่สองของ Phase 7 (WYN Admin, Web) — เติมเนื้อหาจริงให้หน้า Dashboard ที่ WYN-049 สร้างไว้เป็น placeholder ("WYN Admin Dashboard พร้อมใช้งาน — ฟีเจอร์เต็มรูปแบบจะเพิ่มใน WYN-050") ตาม Master Spec section 37 ("WYN ADMIN DASHBOARD": "DAU, MAU, New Users, Drops, Views, Likes, Comments, ReDrops, Clubs, Messages, Reports, Storage, Errors, Server Health")

Target User: Admin/Moderator ที่ต้องการภาพรวมสุขภาพของแพลตฟอร์มอย่างรวดเร็วโดยไม่ต้องเปิด Supabase SQL editor เอง

Problem: ตรวจ repo จริงยืนยันว่า **ไม่มีกลไกเก็บ metrics ใดๆ ไว้ล่วงหน้าเลย** (ไม่มีตาราง `daily_stats`/snapshot ใดๆ, ไม่มี cron/scheduled job ในระบบเลยแม้แต่จุดเดียว — ยืนยันซ้ำจากข้อเท็จจริงเดียวกับที่ WYN-030/WYN-043 เคยบันทึกไว้) ตัวเลขทั้งหมดต้อง query สดจากตารางจริงทุกครั้งที่เปิดหน้า Dashboard — และ **ไม่มี admin ทำ query ข้ามผู้ใช้ได้เลยในตอนนี้** (WYN-049 ตั้งใจไม่สร้าง service-role client ไว้)

Requirements:

**1. ขอบเขตตัวเลข 11/14 หัวข้อจาก Master Spec section 37 — เหตุผลที่ตัดออก 3 หัวข้อ**

ทำได้จริงในรอบนี้ (มีข้อมูลอยู่แล้วในตารางที่มีอยู่ทั้งหมด):
- **DAU/WAU/MAU** — นิยามเป็น "จำนวนผู้ใช้ที่ไม่ซ้ำกันที่มี action อย่างน้อย 1 ครั้งใน 1/7/30 วันล่าสุด" โดย action ที่นับคือ: สร้าง Drop, Like (Drop/Pop/Club Post), Comment (Drop/Pop/Club Post), ReDrop, ส่งข้อความ (message), สร้าง Club Post — **ไม่ใช่ "เปิดแอป" จริงตามความหมายทั่วไปของ DAU** เพราะไม่มีระบบ session/analytics tracking การเปิดแอปเลยในระบบ (ไม่มี Firebase Analytics/Mixpanel/ระบบเทียบเท่า) เป็น proxy ที่ใกล้เคียงที่สุดที่ทำได้จากข้อมูลที่มีจริง — ต้องระบุคำอธิบายนี้ในหน้า UI ตรงๆ ไม่ปล่อยให้ Admin เข้าใจผิดว่าเป็น "app open" DAU มาตรฐาน
- **New Users** — `profiles.created_at` ในช่วงเวลา
- **Drops** — `drops.created_at` ในช่วงเวลา
- **Views** — `drop_views` (WYN-038) ในช่วงเวลา — **หมายเหตุ Known Gap**: Pop ไม่มี unique-viewer tracking (แค่ counter รวมไม่มี timestamp ต่อแถว จาก WYN-006) จึงนับได้แค่ view ของ Drop เท่านั้น ไม่รวม Pop
- **Likes** — รวม `drop_likes` + `pop_likes` + `club_post_likes` ในช่วงเวลา
- **Comments** — รวม `drop_comments` + `pop_comments` + `club_post_comments` ในช่วงเวลา
- **ReDrops** — `redrops.created_at` ในช่วงเวลา
- **Clubs** — จำนวนรวมทั้งหมด (total, ไม่ใช่ rate) + จำนวนที่สร้างใหม่ในช่วงเวลา
- **Messages** — `messages.created_at` ในช่วงเวลา (ข้อความจริง ไม่รวมที่ถูกลบ)
- **Reports** — จำนวนรวมทั้งหมด (total) + **จำนวนที่ `status = 'pending'` แยกต่างหาก** (ตัวเลขที่ actionable ที่สุดสำหรับ Admin จริงๆ ไม่ใช่แค่นับสะสม)

**เลื่อนออกทั้งหมด (ไม่มีโครงสร้างพื้นฐานรองรับเลย, เสนอเป็น task แยก)**:
1. **Storage** — ต้องเรียก Supabase Management API (ข้อมูล storage usage ไม่ได้อยู่ใน database เอง เป็น metadata ระดับ project ที่ query ผ่าน SQL ธรรมดาไม่ได้) ต้องมี API token/permission ใหม่ที่ยังไม่มีการตัดสินใจ
2. **Errors** — ไม่มีระบบ error tracking/logging ใดๆ ในโปรเจกต์เลย (ไม่มี Sentry/เทียบเท่า) ต้องเลือกและติดตั้งเครื่องมือใหม่ทั้งชุดก่อน เป็นการตัดสินใจ Infrastructure ที่ควรถาม Founder แยกต่างหาก
3. **Server Health** — สถาปัตยกรรมเป็น Vercel (serverless) + Supabase (managed) ทั้งคู่ไม่มี "server" ให้ตรวจสุขภาพแบบ traditional VM/container monitoring — ถ้าต้องการ "health" จริงต้องนิยามใหม่ว่าหมายถึงอะไร (เช่น Vercel's own status API, Supabase status page) เป็นการตัดสินใจ scope ที่ควรถาม Founder ก่อน ไม่ใช่แค่เพิ่ม metric ธรรมดา

**2. กลไกดึงข้อมูล — RPC เดียว ไม่ใช้ service-role key** (ต่อยอดการตัดสินใจของ WYN-049)
- SECURITY DEFINER RPC ใหม่ `public.admin_dashboard_metrics()` เช็ค `internal.current_platform_role() in ('admin', 'moderator')` ก่อนเสมอ (raise exception ถ้าไม่ผ่าน มิเรอร์ pattern เดียวกับ `send_system_notification()`) แล้วคืน **แค่ตัวเลข aggregate เท่านั้น ไม่คืน raw row ระดับผู้ใช้เดี่ยวๆ เลย** — เป็นวิธีให้ Admin เห็นข้อมูลข้ามผู้ใช้ได้โดยไม่ต้องมี service-role key ในแอปเว็บเลย (ยังคงเป็น 0 service-role key ทั้งระบบเหมือน WYN-049)

**3. UI — Dashboard เดียว ไม่มีตัวกรองช่วงเวลาที่ซับซ้อนในรอบนี้**
- แสดงเป็น stat card grid: ตัวเลข "วันนี้" (24 ชม.ล่าสุด) ของ New Users/Drops/Views/Likes/Comments/ReDrops/Messages + DAU/WAU/MAU (3 ค่าแยกกัน) + Clubs (total, ไม่ใช่ rate) + Reports (total + pending แยกกันเด่นชัด เพราะเป็นตัวเลขที่ต้องรีบดำเนินการ)
- ไม่มี graph/chart ในรอบนี้ (ตัวเลขปัจจุบันอย่างเดียว ไม่มี historical trend เพราะไม่มี snapshot mechanism เก็บย้อนหลัง) — เสนอเป็น follow-up ถ้า Founder ต้องการ trend chart จริง (ต้องมี snapshot/cron infra ก่อน เหมือนที่ WYN-043 เคยเจอกรณี Trending notification)
- ปุ่ม "รีเฟรช" ให้ query ใหม่ด้วยตนเอง (ไม่ auto-refresh ต่อเนื่อง ลดความซับซ้อนรอบนี้)

Acceptance Criteria:
- [ ] บัญชี `admin`/`moderator` เปิดหน้า Dashboard เห็นตัวเลขจริงทั้ง 11 หัวข้อที่อยู่ในสโคป ไม่ใช่ placeholder อีกต่อไป
- [ ] ตัวเลขตรงกับการนับจริงจาก DB (สร้างข้อมูลทดสอบแล้วนับมือเทียบกับที่ RPC คืนมา)
- [ ] เรียก `admin_dashboard_metrics()` ด้วยบัญชี `platform_role = 'user'` → ถูกปฏิเสธ (ไม่มี privilege escalation ผ่านทางนี้)
- [ ] DAU/WAU/MAU section มีคำอธิบายชัดเจนว่านับจาก "action บนแพลตฟอร์ม" ไม่ใช่ "เปิดแอป"
- [ ] Reports card แยก "pending" ออกจาก "total" ชัดเจน ไม่ปนกัน
- [ ] Storage/Errors/Server Health **ไม่ปรากฏเป็นตัวเลข 0 หรือ N/A ที่ทำให้เข้าใจผิดว่าคำนวณแล้วได้ 0** — ต้องไม่แสดง card สำหรับ 3 หัวข้อนี้เลยในรอบนี้ (เหมือนที่ WYN-044 ไม่ใส่ toggle "Trending" ที่ไม่มีอะไรให้ปิดจริง)

Dependencies: WYN-049 (Admin Foundation — auth/layout/`internal.current_platform_role()` pattern), WYN-038 (drop_views), WYN-026 (reports), WYN-031 (messages), WYN-034 (redrops)

Priority: P1 — งานที่สองของ Phase 7 ต่อจาก Foundation

Risks:
- **DAU/MAU เป็น proxy ไม่ใช่นิยามมาตรฐาน** — ถ้า Founder ต้องการ DAU แบบ "เปิดแอปจริง" ต้องมีระบบ session/analytics tracking ใหม่ทั้งชุด (Phase 8's WYN-056 User Analytics อาจเกี่ยวข้อง แต่ยังไม่ใช่สโคปตอนนี้) — ต้องสื่อสารข้อจำกัดนี้ให้ชัดใน UI ไม่ใช่แค่ในเอกสาร
- **Query อาจช้าเมื่อข้อมูลเยอะขึ้นในอนาคต** — `admin_dashboard_metrics()` รวม query หลายตารางพร้อมกัน ยังไม่มีปัญหาตอนนี้ (ข้อมูลน้อย ไม่มี production จริง) แต่ควรพิจารณา index/materialized view ถ้าข้อมูลโตขึ้นมากในอนาคต ไม่ใช่ปัญหาที่ต้องแก้ตอนนี้

Recommendation: ทำต่อจาก WYN-049 ทันทีในเซสชันเดียวกัน — เริ่มจาก RPC (จุดเสี่ยงด้าน security สูงสุดของ task นี้) แล้วค่อยทำ UI

Handoff: AI Design — ออกแบบ stat card grid layout (11 การ์ด, จัดกลุ่มตามหมวด: Users/Content/Social/Reports) บนหน้า Dashboard ที่มี layout shell อยู่แล้วจาก WYN-049 — ตัดสินใจ label ภาษาไทยของแต่ละ metric + คำอธิบาย DAU/MAU ที่ต้องแสดงชัดเจน

## Coding Output (2026-08-24)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-048 ท้ายไฟล์): RPC ใหม่ `public.admin_dashboard_metrics()` (`security definer`, `plpgsql`) เช็ค `internal.current_platform_role() not in ('admin', 'moderator')` แล้ว `raise exception` ก่อนทำอะไรทั้งนั้น (มิเรอร์ pattern `send_system_notification()`) — คืน `returns table (...)` แถวเดียว 14 คอลัมน์ตรงกับ metric ที่ Product ล็อกสโคปไว้ทั้ง 11 หัวข้อ (Clubs/Reports รวม 2 ค่าไว้คนละคอลัมน์ในผลลัพธ์เดียวกัน) — DAU/WAU/MAU ใช้ CTE `actions` (UNION ALL ของ actor+created_at จาก 9 ตาราง: drop_likes/pop_likes/club_post_likes/drop_comments/pop_comments/club_post_comments/redrops/messages(ไม่รวมที่ลบ)/drops) แล้วนับ `count(distinct actor_id)` ต่อ window — **ไม่มี service-role key เพิ่มเลย** ต่อยอดการตัดสินใจของ WYN-049 ตรงๆ ตามที่ Design/Product ระบุ

**SQL test ใหม่** (`supabase/tests/wyn_050_admin_dashboard_test.sh`, มิเรอร์ harness ของ `wyn_048_audit_log_test.sh`) — seed ข้ามตาราง (Drop/Like/Comment/ReDrop/View/Club/Message ×2 (1 ลบ 1 ไม่ลบ)/Report ×2 (1 pending 1 dismissed)) แล้วนับมือเทียบกับ RPC ทุกคอลัมน์ (14 checks) + moderator เรียกได้ (CHECK2) + `user` role ถูกปฏิเสธ (CHECK3) — **16/16 PASS** — รันซ้ำครบทั้ง 21 สคริปต์เดิม (`wyn_021` ถึง `wyn_048`) **ผ่านหมดไม่มี cross-task regression** — `check_schema_ordering.py` ผ่าน

**Flutter/Next.js**: ไม่แตะฝั่ง Flutter เลย (นอกขอบเขต) — ฝั่ง `admin/`: `lib/admin-metrics.ts` (type + fetch function เรียก `.rpc('admin_dashboard_metrics').single()`), `components/admin/stat-card.tsx` (การ์ดใช้ซ้ำได้ทั้ง 1-ค่า และ 2-ค่า ผ่าน prop `secondaryValue`/`secondaryTone`), `components/admin/dashboard-metrics.tsx` (async Server Component, fetch ข้อมูลจริง 4 section), `components/admin/dashboard-skeleton.tsx` (โครงเดียวกับของจริงเป๊ะ กัน layout shift), `components/admin/refresh-button.tsx` (client component ใช้ `useTransition` + `router.refresh()` — เก็บตัวเลขเดิมไว้ระหว่าง refresh ตามที่ Design ระบุ ไม่ blank ซ้ำ), `app/(admin)/error.tsx` ใหม่ (retry boundary สำหรับทั้ง route group) — `app/(admin)/page.tsx` เขียนใหม่ทั้งไฟล์ ห่อ `DashboardMetrics` ด้วย `<Suspense fallback={<DashboardSkeleton />}>` ให้ skeleton ทำงานเฉพาะตอน fetch จริง ไม่ block ปุ่มรีเฟรช/ส่วนอื่นของหน้า

`next build` **clean 0 error/warning** (รวม TypeScript check), `npm run lint` **0 issues** — verify runtime: guest เข้า `/` ยัง redirect ไป `/login` เหมือนเดิม (ยืนยันว่าไม่กระทบ auth gate ของ WYN-049) — grep `.next/static` หา `service_role`/`SERVICE_ROLE` ไม่พบ (ยืนยันซ้ำว่ายังไม่มี key นั้นในระบบ)

**Known Issues**: ไม่มีบัญชี admin/moderator จริงในสภาพแวดล้อมนี้ (ไม่มี Supabase project จริง) จึงตรวจสอบ path ที่ authenticated ได้แค่ผ่านการอ่านโค้ด + SQL test เท่านั้น ไม่ได้เห็นตัวเลขจริงบนหน้าเว็บ — เหมือนข้อจำกัดเดียวกับ WYN-049

Handoff: AI QA & Security — ตรวจเน้นที่ (1) `admin_dashboard_metrics()` ปฏิเสธ `user` role จริง ไม่มี privilege escalation (2) ตัวเลขที่คืนมาไม่รั่ว raw row ระดับผู้ใช้เดี่ยวๆ เลย (แค่ aggregate) (3) DAU/WAU/MAU disclaimer แสดงตลอดเวลาจริงใน UI ไม่ใช่ tooltip ซ่อน (4) ไม่มี card สำหรับ Storage/Errors/Server Health หลุดออกมาเป็น 0/N/A

## Independent QA (2026-08-24)

Feature: WYN-050 WYN Admin Dashboard — RPC `admin_dashboard_metrics()` + stat card grid UI

Environment: local Postgres 16 (throwaway DB, role `authenticated` จริง) + Node.js v22.22.2/Next.js 16.3.2 — อ่าน diff แบบ adversarial ก่อนเชื่อผลทดสอบของ Coding

### รอบแรก — FAIL (พบช่องโหว่ Major)

Security Findings: **`admin_dashboard_metrics()`'s role guard เขียนแบบเดียวกับที่ project เคยบันทึกไว้เป็นกับดักที่รู้จักแล้ว** (`set_club_member_role()`'s comment เตือนตรงๆ ว่า `null not in (...)` = NULL ไม่ใช่ true) — `if internal.current_platform_role() not in ('admin', 'moderator') then raise exception` **ไม่มี `coalesce()` ครอบ** ทำให้ผู้ใช้ที่มีแถวใน `auth.users` แต่**ไม่มีแถวใน `profiles` เลย** (เช่น signup race, insert profiles ล้มเหลว) เรียก RPC แล้ว**ได้รับข้อมูล aggregate จริงกลับมาโดยไม่ถูกปฏิเสธ** — พิสูจน์ exploit จริง: seed บัญชีแบบนั้นแล้วเรียก RPC ตรงๆ ผ่าน role `authenticated` จริง ได้ผลลัพธ์เป็นแถวข้อมูลจริง ไม่ error

Severity: **Major** (ไม่ใช่ Critical เพราะข้อมูลที่รั่วเป็นแค่ aggregate count ไม่ใช่ raw per-user data — แต่ยังเป็น privilege bypass ที่แท้จริง ผู้ใช้ที่ไม่ผ่านการยืนยัน role ใดๆ เลยเห็นข้อมูลที่ควรสงวนไว้เฉพาะ Admin/Moderator ได้)

Reproduction Steps: seed `auth.users` row เดียว (ไม่มี `profiles` คู่กัน) → `set role authenticated` + `request.jwt.claim.sub` เป็น id นั้น → เรียก `admin_dashboard_metrics()` → ได้แถวข้อมูลกลับมา ไม่ raise exception

Expected: ถูกปฏิเสธ (raise exception) เหมือนบัญชี `platform_role = 'user'`

Actual: สำเร็จ คืนข้อมูล aggregate จริง

Recommendation (รอบแรก): fast-follow แก้ทันทีในเซสชันเดียวกัน (มิเรอร์ precedent ของ WYN-048's `log_audit_event()` missing-revoke — one-line fix ความเสี่ยงต่ำ ไม่ต้องเปิด Debug Engineer แยกรอบ) — บันทึก bug report ที่ `.wyn/tasks/bugs/WYN-050-admin-dashboard-metrics-null-role-bypass.md`

Final Status (รอบแรก): **FAIL**

### แก้ไข + รอบสอง — PASS

แก้ `admin_dashboard_metrics()`'s guard เป็น `coalesce(internal.current_platform_role(), '') not in ('admin', 'moderator')` — เพิ่ม `CHECK4` ใหม่ใน `supabase/tests/wyn_050_admin_dashboard_test.sh` จำลอง scenario เดียวกัน (auth user ไม่มี profiles row) — **พิสูจน์ red→green จริง**: revert การแก้ชั่วคราวแล้วรัน suite เห็น `CHECK4` fail จริงตรงตามที่รายงาน (`expected 1, got 0`) ก่อนค่อย restore การแก้แล้วเห็นผ่านทั้ง 17/17 checks — รันซ้ำครบทั้ง 21 สคริปต์เดิม (`wyn_021` ถึง `wyn_050`) **ผ่านหมดไม่มี cross-task regression** — `check_schema_ordering.py` ผ่าน — `next build`/`npm run lint` (ฝั่งเว็บ ไม่ได้แตะแต่ verify ซ้ำ) สะอาด 0 error/warning

Test Cases (รอบสอง, ครบทุกจุด):
1. รัน `wyn_050_admin_dashboard_test.sh` เอง — 17/17 PASS (14 metric ตรงกับที่นับมือ + moderator เรียกได้ + user ถูกปฏิเสธ + no-profile-row ถูกปฏิเสธ)
2. รันซ้ำ 21 สคริปต์เดิมทั้งหมด — ผ่านหมด
3. `check_schema_ordering.py` — OK
4. `next build`/`npm run lint` (ฝั่งเว็บ) — สะอาด
5. อ่าน `DashboardMetrics`/`StatCard`/`RefreshButton` แบบ adversarial — ยืนยันไม่มี raw per-user data ถูกส่งไป client เลย (แค่ตัวเลข aggregate 14 ค่า) DAU/MAU disclaimer เป็น paragraph ที่ render เสมอ ไม่ใช่ tooltip/hover-only — ไม่มี card สำหรับ Storage/Errors/Server Health ใน `dashboard-metrics.tsx` เลยจริง

Passed: ทุกข้อข้างต้น
Failed: ไม่มี (หลังแก้)

Security Findings (รอบสอง): ไม่พบเพิ่มเติม — จุดที่พบใน QA รอบแรกปิดแล้วและมี regression test กันไม่ให้กลับมาเกิดซ้ำ

Recommendation: อนุมัติ — ช่องโหว่ที่พบจริงถูกปิดแล้วพร้อมพิสูจน์ red→green และ regression test คุ้มครองไว้ ไม่มี cross-task regression

Final Status: **PASS**
