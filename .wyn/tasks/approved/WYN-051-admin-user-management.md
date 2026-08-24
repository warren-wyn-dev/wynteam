# Product Task — WYN-051

Status: approved (Independent QA PASS 2026-08-24 — ดูหัวข้อ "Independent QA" ท้ายไฟล์ — ส่งต่อ AI Deploy & DevOps)
Owner: AI Product Manager

Feature: WYN Admin User Management — ค้นหาผู้ใช้, ดูสถานะบัญชี/ประวัติ, และดำเนินการ Warn/Restrict/Suspend/Ban/Unban/Force Logout โดยตรง

Goal: task ที่สามของ Phase 7 — เติมเนื้อหาจริงแทน placeholder "User Management" (Master Spec section 38: "ค้นหา User → ดู Profile/Account status/Reports/Moderation history/Login-security events (ตามสิทธิ์) — Action: Warn, Restrict, Suspend, Ban, Unban, Force Logout")

Target User: Admin/Moderator ที่ต้องจัดการผู้ใช้ที่มีปัญหาโดยตรง โดยไม่ต้องรอให้มี Report เข้าคิวก่อนเสมอไป (ต่างจาก Moderation Queue เดิมของ WYN-029 ที่เริ่มจาก Report เท่านั้น)

Problem: ตรวจโค้ดจริงพบว่า **กลไก moderation ที่มีอยู่แล้วทั้งหมด (WYN-029/030) ผูกกับ Report เสมอ** — `apply_moderation_action()` ต้องการ `p_report_id` (NOT NULL) และ `moderation_actions.report_id` เป็น `not null` — ไม่มีทางให้ Admin ค้นหาผู้ใช้แล้วสั่ง action ตรงๆ โดยไม่มี Report นำมาก่อนได้เลย — และ **ไม่มีกลไก "Unban"/"Force Logout" อยู่เลยแม้แต่จุดเดียว** (มีแค่ `overturned_at` ที่ตอนนี้ตั้งได้ผ่าน `decide_appeal()` เท่านั้น ซึ่งต้องมี Appeal เข้ามาก่อนเช่นกัน)

Requirements:

**1. ค้นหาและดู User — reuse โครงสร้างเดิมทั้งหมด ไม่มี SQL ใหม่**
- ค้นหาด้วย username/display name: query ตรงบน `profiles` (SELECT policy เดิม `using (true)` เปิดอยู่แล้ว ทุก authenticated เห็น profile ใครก็ได้ ไม่ต้องเพิ่ม RLS)
- Reports ที่มีต่อผู้ใช้คนนี้: reuse `public.moderation_queue` VIEW เดิม (WYN-029) กรอง `target_type = 'user' and target_id = <id>` ตรงๆ — VIEW นี้ซ่อน `reporter_id` โดยโครงสร้างอยู่แล้ว (ไม่ใช่แค่ column list แต่ unreachable จริงตามที่ comment ในสคีมาระบุไว้) ไม่ต้องสร้างอะไรใหม่

**2. Moderation History — VIEW ใหม่ 1 ตัว มิเรอร์ pattern `moderation_queue` เป๊ะ**
- `public.admin_user_moderation_history` (plain VIEW, ไม่ใช้ `security_invoker`, role-gate ใน `where` เหมือน `moderation_queue`) แสดง action_type/reason/duration_days/expires_at/overturned_at/created_at + **username ของ reviewer** (ต่างจาก `moderation_queue` ที่ซ่อน reporter — เหตุผล: reviewer ไม่ใช่ข้อมูลที่ต้องปกปิดจาก Admin คนอื่นที่กำลังทำหน้าที่เดียวกัน เป็นความรับผิดชอบ (accountability) ปกติของทีมงาน ต่างจาก reporter ที่ต้องปกปิดจากทุกคนรวมถึง Admin ตาม WYN-026's Requirement เดิม)

**3. Action โดยตรง (ไม่ผ่าน Report) — 4 ประเภทแรก, เลื่อน Force Logout ไว้พิจารณาความเสี่ยงเพิ่มเติม**
- **`moderation_actions.report_id` เปลี่ยนเป็น nullable** (การเปลี่ยนแปลงเล็กที่สุดที่ทำให้ reuse โครงสร้างเดิมทั้งหมดได้ — `is_posting_blocked()`/`get_my_moderation_status()`/ทุกจุดที่พึ่งพา `moderation_actions` อยู่แล้วไม่ต้องแก้เลยแม้แต่บรรทัดเดียว เพราะไม่มีจุดไหน query อิง `report_id is not null`) — เทียบกับทางเลือกสร้างตารางคู่ขนานใหม่ที่ต้องแก้ `is_posting_blocked()` (ฟังก์ชันที่ถูกเรียกจาก RLS policy 15+ จุดทั่วสคีมา) ความเสี่ยงสูงกว่ามาก
- RPC ใหม่ `admin_apply_user_action(p_target_user_id, p_action_type, p_reason, p_duration_days)` จำกัด `p_action_type` แค่ **`warning`/`restrict`/`suspend`/`ban`** เท่านั้น (ไม่รวม `remove_content` เพราะเป็นเรื่องเนื้อหา ไม่ใช่ผู้ใช้โดยตรง — สโคปของ WYN-052 Content Moderation ในอนาคต, ไม่รวม `no_action` เพราะไม่มี Report ให้ dismiss) มิเรอร์ validation ของ `apply_moderation_action()` ทุกจุด (reason required, duration_days ∈ {1,3,7} สำหรับ restrict/suspend เท่านั้น) — insert `moderation_actions` โดย `report_id = null` — ส่ง notification `moderation_warning` เหมือนเดิมถ้าเป็น `warning` (restrict/suspend/ban ไม่ต้องส่ง notification ตรง เพราะผู้ใช้เห็นผ่าน `get_my_moderation_status()` ที่ AuthGate/RestrictionBanner เรียกอยู่แล้วเหมือนเดิมทุกประการ) — log audit เหมือนเดิม
- RPC ใหม่ `admin_unban_user(p_target_user_id, p_reason)` — ตั้ง `overturned_at = now()` ให้ทุกแถวที่กำลัง active อยู่จริง (ban แบบถาวร หรือ restrict/suspend ที่ยังไม่หมดอายุ, ยังไม่เคยถูก overturn) ของผู้ใช้คนนั้น — log audit
- **Force Logout — เลื่อนออก ไม่ทำในรอบนี้**: ต้องการ `delete from auth.sessions where user_id = ...` ซึ่งแตะ Supabase GoTrue's internal schema ที่ repo นี้ไม่เคยแตะมาก่อนเลยแม้แต่จุดเดียว ไม่มีทางยืนยัน schema จริง 100% โดยไม่มี Supabase project จริงให้ทดสอบ (ต่างจาก 3 action อื่นที่ reuse โครงสร้าง `moderation_actions` ที่มีอยู่แล้วและทดสอบได้เต็มรูปแบบในนี้) — เสนอเป็น follow-up ทันทีที่มี Supabase project จริงให้ verify ก่อนเขียนโค้ดจริง (มิเรอร์เหตุผลเดียวกับที่ WYN-050 เลื่อน Storage/Errors/Server Health ออก)

Acceptance Criteria:
- [ ] ค้นหา username เจอผู้ใช้จริง แสดง profile + platform_role + สถานะปัจจุบัน (ถ้ากำลังโดน restrict/suspend/ban อยู่ ต้องเห็นชัดเจนพร้อมวันหมดอายุ)
- [ ] เห็น Reports ที่มีต่อผู้ใช้คนนี้ (จาก `moderation_queue` filter) — ไม่เห็น reporter identity เลย (เหมือนหน้า Moderation Queue เดิม)
- [ ] เห็น Moderation history ครบ พร้อม reviewer username ของแต่ละ action
- [ ] Admin สั่ง Warn/Restrict/Suspend/Ban ผู้ใช้ตรงๆ โดยไม่ต้องมี Report → `moderation_actions` row ใหม่ถูกสร้างจริง `report_id is null`, `is_posting_blocked()` เห็นผลทันที (ทดสอบว่า user คนนั้นโพสต์ไม่ได้จริงหลัง restrict/suspend/ban)
- [ ] Admin สั่ง Unban → `overturned_at` ถูกตั้งค่า → `is_posting_blocked()` คืน false ทันที ผู้ใช้โพสต์ได้ปกติอีกครั้ง
- [ ] บัญชี `platform_role = 'user'` เรียก RPC ทั้งสองตัวใหม่ → ถูกปฏิเสธ (ทดสอบ NULL-role-bypass แบบเดียวกับที่ WYN-050 เจอมาก่อนด้วย — ต้องมี `coalesce()` ครอบทุกจุดที่เช็ค role)
- [ ] ทุก action ถูกบันทึกลง `audit_log` จริง

Dependencies: WYN-029 (Moderation Queue foundation, `moderation_actions`/`is_posting_blocked()`/`moderation_queue` view), WYN-030 (`overturned_at` mechanism), WYN-048 (`internal.log_audit_event()`), WYN-049 (Admin auth/layout), WYN-050 (`internal.current_platform_role()` NULL-safety lesson — ต้อง `coalesce()` ทุกจุด)

Priority: P1

Risks:
- **Blast radius ของการเปลี่ยน `report_id` เป็น nullable** — แม้จะประเมินแล้วว่าไม่มีจุดไหนพึ่ง NOT NULL แต่ต้องรัน regression suite เดิมทั้งหมดซ้ำหลังแก้เพื่อยืนยันจริง ไม่ใช่แค่เชื่อการวิเคราะห์เฉยๆ
- **NULL-role-bypass class เดิมที่เพิ่งเจอใน WYN-050** — RPC ใหม่ 2 ตัวในรอบนี้ต้องระวังจุดเดียวกันเป๊ะ (`coalesce()` ครอบ `current_platform_role()`/เทียบเท่าเสมอ)
- **Force Logout ที่เลื่อนออก** — ถ้า Founder ต้องการ capability นี้เร่งด่วน ต้องมี Supabase project จริงให้ verify schema ก่อน ไม่ใช่แค่เพิ่ม request

Recommendation: ทำต่อจาก WYN-050 ทันที — เริ่มจาก schema change (`report_id` nullable) + 2 RPC + VIEW ก่อน แล้วค่อยทำ UI

Handoff: AI Design — ออกแบบหน้า User Management (search bar + result list + user detail panel: Profile/Status/Reports/History/Action buttons) บน layout shell เดิมจาก WYN-049 — ตัดสินใจ confirmation dialog ก่อนสั่ง action ที่มีผลกระทบสูง (Ban โดยเฉพาะ)

## Coding Output (2026-08-24)

**SQL** (`supabase/schema.sql`, ต่อท้ายส่วน WYN-050 ท้ายไฟล์): `moderation_actions.report_id` เปลี่ยนเป็น nullable (`alter column ... drop not null`) — ตรวจสอบก่อนแก้ว่าไม่มี query ไหนในสคีมาพึ่ง NOT NULL จริง (grep ทุกจุดที่อ้าง `report_id` แล้วอ่านทีละจุด) — RPC ใหม่ 2 ตัว `admin_apply_user_action()`/`admin_unban_user()` มิเรอร์ validation ของ `apply_moderation_action()`/`decide_appeal()` ทุกจุดที่เกี่ยวข้อง — **ใช้ `coalesce(internal.current_platform_role(), '')` ครอบทุกจุดที่เช็ค role** ตามบทเรียนจาก WYN-050 ตรงๆ — VIEW ใหม่ `admin_user_moderation_history` มิเรอร์ pattern `moderation_queue` เป๊ะ (plain view ไม่มี `security_invoker`, role-gate ใน `where`) แต่ต่างกันตรงที่ **เปิดเผย reviewer username** (join `profiles`) ตามที่ Product/Design ตัดสินใจไว้ — ขยาย `audit_log_event_type_check` เพิ่ม 2 event type ใหม่ (`admin_user_action_applied`/`admin_user_unbanned`) ด้วย drop+recreate pattern เดิม (พบระหว่างเขียนโค้ดว่า `internal.log_audit_event()` ปฏิเสธ event type ที่ไม่รู้จักจริง ไม่ใช่แค่ insert เฉยๆ — ต้องขยาย constraint ก่อนถึงจะใช้งานได้)

**พบเพิ่มเติมระหว่างตรวจโค้ด (นอกสโคป WYN-051 โดยตรง)**: `public.send_system_notification()` (WYN-043, มีอยู่แล้วใน production ผ่าน PR #161) มีช่องโหว่ NULL-role-bypass **คลาสเดียวกับที่ QA เพิ่งพบใน WYN-050 เป๊ะ** — `if internal.current_platform_role() <> 'admin' then raise exception` ไม่มี `coalesce()` ครอบ ทำให้บัญชีที่ไม่มีแถว `profiles` เลยส่ง system notification ปลอมได้ (impersonate ประกาศทางการของ WYN) — **จะแก้แยกเป็น fast-follow ต่างหากหลัง WYN-051 เสร็จ ไม่ปนกับ diff ของ task นี้** เพื่อให้ QA/CONTEXT.md ติดตามแยกกันชัดเจนว่าเป็นคนละ task ที่พบบั๊กเดิมซ้ำ

**SQL test ใหม่** (`supabase/tests/wyn_051_admin_user_management_test.sh`, มิเรอร์ harness `wyn_050`) — 14 checks ครอบ: warning ไม่มี report_id + notification ส่งจริง, ban block posting ทันที, duration ผิดถูกปฏิเสธ, unban ปลด block + ตั้ง overturned_at จริง, no-profile-row/user-role/moderator ทั้ง 2 RPC, reviewer username โชว์จริง + ซ่อนจาก user role, **ยืนยัน report-driven path เดิม (`apply_moderation_action()`) ยังทำงานปกติหลัง `report_id` เปลี่ยนเป็น nullable** — **14/14 PASS** — รันซ้ำครบทั้ง 22 สคริปต์เดิม (`wyn_021` ถึง `wyn_050`) **ผ่านหมดไม่มี cross-task regression** — `check_schema_ordering.py` ผ่าน

**Next.js**: UI component ใหม่ 4 ตัว (`Badge`/`Textarea`/`Dialog`/`Select`, เขียนเองตาม shadcn source เหมือน WYN-049 เพราะ `ui.shadcn.com` ยังบล็อก) — `lib/admin-users.ts` (server-side fetch: search/profile/history/reports), `lib/admin-user-actions.ts` (client-side RPC wrapper สำหรับ Dialog เรียกตรง ไม่ผ่าน Server Action เพราะไม่มี cookie/redirect เกี่ยวข้อง) — `components/admin/action-dialog.tsx` (ใช้ซ้ำ 4 action: Warn/Restrict/Suspend/Unban) + `ban-dialog.tsx` แยกต่างหาก (typed-confirmation) + `user-actions-bar.tsx` — `app/(admin)/users/page.tsx` (ค้นหา, Suspense keyed ด้วย query) + `app/(admin)/users/[id]/page.tsx` (detail: header/badge/actions/2 ตาราง)

**พบและแก้เอง 1 จุดระหว่างทดสอบ runtime**: guest redirect ไป `/login` จาก `/users?q=test` พา query string เดิมติดไปด้วยโดยไม่ตั้งใจ (`url.pathname = "/login"` แต่ clone มาทั้ง URL ทำให้ `?q=test` ค้างอยู่) — แก้ด้วย `url.search = ""` ใน `lib/supabase/middleware.ts`

`next build` **clean 0 error/warning**, `npm run lint` **0 issues** — verify runtime: `/users`/`/users/[id]` (guest) redirect ไป `/login` สะอาดจริง (query string ไม่ค้างแล้วหลังแก้) — grep `.next/static` หา service-role key ไม่พบ

**Known Issues**: เหมือน WYN-049/050 — ไม่มี Supabase project จริงให้ทดสอบ live end-to-end (ค้นหา/action จริงบนข้อมูลจริง) — Force Logout ยังไม่ทำตามที่ Product ล็อกสโคปไว้

Handoff: AI QA & Security — ตรวจเน้นที่ (1) `report_id` nullable ไม่กระทบ path เดิมจริง (มี CHECK9 ยืนยันแล้วแต่ควร verify ซ้ำ) (2) NULL-role-bypass ปิดจริงทั้ง 2 RPC ใหม่ (3) reviewer username ไม่หลุดไปถึง user role (4) reporter identity ยังคงซ่อนสนิทในหน้า Reports (reuse `moderation_queue` เดิม ไม่ควรมีจุดรั่วใหม่) (5) พิจารณาว่าจะแก้ `send_system_notification()`'s bug ที่พบเพิ่มเติมพร้อมกันเลยหรือแยก task

## Independent QA (2026-08-24)

Feature: WYN-051 WYN Admin User Management — ค้นหาผู้ใช้, ดู Reports/Moderation history, สั่ง Warn/Restrict/Suspend/Ban/Unban ตรงๆ ไม่ผ่าน Report

Environment: local Postgres 16 (throwaway DB, role `authenticated` จริง) + Node.js v22.22.2/Next.js 16.3.2 — อ่าน diff แบบ adversarial ก่อนเชื่อผลของ Coding โดยเฉพาะจุดที่ Coding เองเพิ่งเจอบทเรียนจาก WYN-050 มา (NULL-role-bypass)

Test Cases:
1. รัน `wyn_051_admin_user_management_test.sh` เองอิสระ — 14/14 PASS
2. รันซ้ำครบ 22 สคริปต์เดิม (`wyn_021` ถึง `wyn_050`) — ผ่านหมด ยืนยัน `report_id` nullable ไม่กระทบอะไรเลยจริง (โดยเฉพาะ `wyn_029`/`wyn_030` ที่ใช้ `moderation_actions`/`overturned_at` โดยตรง)
3. `check_schema_ordering.py` — OK
4. `next build`/`npm run lint` — สะอาด
5. Adversarial probe เพิ่มเติม 5 จุดนอกเหนือ regression suite:
   - `admin_apply_user_action(..., 'remove_content', ...)` — ถูกปฏิเสธจริง (ไม่ใช่แค่ตามสเปก ทดสอบจริงว่า reject)
   - `admin_apply_user_action(..., 'no_action', ...)` — ถูกปฏิเสธจริง
   - `admin_unban_user()` กับผู้ใช้ที่ไม่มีสถานะ blocked เลย — เป็น no-op เงียบๆ ไม่ error (UX ที่ถูกต้อง ไม่ใช่แค่ไม่ crash)
   - `moderator` (ไม่ใช่แค่ `admin`) `select` ตรงบน `admin_user_moderation_history` VIEW เอง (ไม่ผ่าน RPC) — สำเร็จ ยืนยันว่า gate อยู่ที่ VIEW เองจริง ไม่ใช่แค่ที่ RPC
   - ตรวจ `information_schema.columns` ยืนยันว่า `moderation_queue` VIEW **ไม่มีคอลัมน์ `reporter_id` อยู่จริงเชิงโครงสร้าง** (ไม่ใช่แค่ query ที่ WYN-051 เขียนไม่ได้ select แต่ column ไม่มีอยู่เลย)

Passed: ทุกข้อข้างต้น
Failed: ไม่มี

Security Findings: ไม่พบช่องโหว่ใหม่ใน WYN-051 เอง — จุดเสี่ยงหลักที่ตรวจเจาะจง (NULL-role-bypass class ที่เพิ่งเจอใน WYN-050) ถูกป้องกันถูกต้องทั้ง 2 RPC ใหม่ยืนยันด้วยการทดสอบจริงไม่ใช่แค่อ่าน code — reviewer identity เปิดเผยตามที่ตั้งใจ (ต่างจาก reporter ที่ปิดสนิท) ตรงตามการตัดสินใจของ Design ไม่ใช่ regression

**พบเพิ่มเติมนอกสโคป (ยืนยันแล้วว่าเป็นบั๊กจริง ไม่ใช่แค่ Coding สงสัย)**: `public.send_system_notification()` (WYN-043, deployed อยู่ใน `main` แล้วผ่าน PR #161) มี NULL-role-bypass บั๊กคลาสเดียวกับที่ WYN-050 เพิ่งพบเป๊ะ (`if internal.current_platform_role() <> 'admin' then` ไม่มี `coalesce()` ครอบ) — เป็นช่องโหว่จริงที่ใช้งานอยู่ใน production track (แม้จะยังไม่มี production จริงก็ตาม) ปล่อยให้บัญชีที่ไม่มีแถว `profiles` เลยส่ง system notification ปลอมแอบอ้างเป็นประกาศทางการของ WYN ได้ — **ตัดสินใจ**: แก้แยกเป็น commit/fast-follow ต่างหากทันทีหลัง WYN-051 deploy เสร็จ (ไม่ปนกับ diff ของ WYN-051 เพื่อรักษา audit trail ให้ชัดเจนว่าเป็นคนละการค้นพบคนละเวลา) — บันทึกไว้ที่นี่เพื่อไม่ให้หลุดลืม

Recommendation: อนุมัติ WYN-051 — ไม่พบปัญหาในสโคปของ task นี้เอง หลังจากนี้จะดำเนินการแก้ `send_system_notification()` แยกทันที

Final Status: **PASS**
