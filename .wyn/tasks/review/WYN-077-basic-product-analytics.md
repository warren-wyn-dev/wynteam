# Product Task — WYN-077

Status: review
Owner: AI Product Manager
Feature: Basic Product Analytics (Signup Funnel + Retention)
Goal: ทำให้วัดผล Go-To-Market ได้จริง (ตอนนี้วัดไม่ได้เลย — ยืนยันจาก scope ของ WYN-050 Admin Dashboard ที่ต้องเลื่อน DAU/WAU/MAU ออกเพราะ "ไม่มี analytics/session tracking เลย")
Target User: Internal (Founder + AI Product Manager ใช้ตัดสินใจ), ไม่ใช่ user-facing feature
Problem: ก่อนเริ่มโปรโมทวงกว้าง (ดู `.wyn/docs/product/wynos-gtm-roadmap.md` Phase 3) จำเป็นต้องรู้ว่า user มาจากช่องทางไหน, signup สำเร็จกี่ %, retain กี่วัน — ปัจจุบันไม่มีทางรู้เลยแม้แต่ข้อมูลพื้นฐานที่สุด
Requirements:
- เก็บ event ขั้นต่ำ: `signup_started`, `signup_completed`, `first_core_action` (Drop แรก/Pop แรก/Club join แรก — อย่างใดอย่างหนึ่ง), `session_start` (proxy ง่ายๆ พอ ไม่ต้องซับซ้อน)
- เก็บ UTM/source parameter ตอน signup (เผื่อใช้ตอน Phase 3 ทดสอบหลายช่องทาง) — ต้องระบุว่าเก็บยังไงกับ Flutter Web (query param ตอนเข้าเว็บครั้งแรก)
- Dashboard ดูผลได้อย่างน้อยแบบพื้นฐาน (ต่อยอด `admin_dashboard_metrics()` เดิมของ WYN-050 ถ้าเป็นไปได้ แทนที่จะสร้างระบบใหม่คู่ขนาน)
- **แนวทางยืนยันแล้ว (Founder อนุมัติ 2026-09-02)**: เก็บ event เองใน Supabase table ใหม่ (ไม่ใช้ third-party) — ไม่มีข้อมูลผู้ใช้ไหลออกนอกระบบ ต่อยอด `admin_dashboard_metrics()` เดิมของ WYN-050 สำหรับ dashboard แทนที่จะสร้างระบบใหม่คู่ขนาน
Acceptance Criteria:
- นับ signup ต่อวันได้ถูกต้อง (เทียบกับจำนวนแถวใหม่ใน `profiles` จริง)
- นับ D1/D7 retention ได้ (มี session_start อย่างน้อย 1 ครั้งในวันที่ 1/7 หลัง signup)
- ไม่มี PII (email/ชื่อจริง) หลุดไปอยู่ใน event data โดยไม่จำเป็น (ต้องเป็น Acceptance Criteria ที่ QA ตรวจจริง)
- ไม่เพิ่ม service-role key ใหม่เข้าระบบ (ต่อยอด pattern ของ WYN-049/050)
- RLS ของ event table ใหม่ปิดไม่ให้ client อ่าน event ของ user คนอื่นได้ (insert-only จาก client ตัวเอง, อ่าน aggregate ได้เฉพาะผ่าน RPC role admin เหมือน `admin_dashboard_metrics()`)
Dependencies: ไม่มี — พร้อมส่งต่อ AI Design ได้ทันที
Priority: P0 — เป็น blocker ของ Phase 2/3 ใน GTM roadmap (Phase 1 closed beta เริ่มได้โดยไม่ต้องรอ task นี้)
Risks: เก็บเองใน Supabase ต้องระวังไม่ให้ event table เพิ่ม attack surface ใหม่ (RLS ต้องปิดไม่ให้ client อ่าน event ของคนอื่น) — ระบุเป็น Acceptance Criteria ให้ QA ตรวจ
Recommendation: เริ่ม Design ได้ทันที
Handoff: **Coding เสร็จแล้ว (2026-09-02)** — ส่งต่อ AI QA & Security ทันที ดูรายละเอียดเต็มที่ `.wyn/company/CONTEXT.md`

## Coding notes (2026-09-02)

Implementation:
- `supabase/schema.sql`: ตาราง `public.analytics_events` ใหม่ (insert-only RLS, ไม่มี select policy เลย) + `admin_dashboard_metrics()` ขยายเพิ่ม 8 คอลัมน์ Growth (`signup_started_24h`/`signup_completed_24h`/`signup_conversion_pct`/`activation_pct_24h`/`activation_count_24h`/`retention_d1_pct`/`retention_d7_pct`/`top_sources`) — ต้อง `drop function` ก่อน `create` เพราะเปลี่ยน RETURNS TABLE shape (Postgres ไม่ยอมให้ `create or replace` เปลี่ยน OUT parameters)
- `app/lib/features/analytics/data/analytics_repository.dart` (ใหม่): `AnalyticsRepository` best-effort, fire-and-forget, กลืน error เองเสมอ ตาม pattern `PushNotificationService` เดิม
- Instrumentation 4 จุด: `EmailAuthScreen` (signup_started, เฉพาะ branch สมัครใหม่ด้วย email/password), `UsernameSetupScreen` (signup_completed), `CreateDropScreen` (first_core_action, หลังโพสต์ Drop สำเร็จ), `RootShell.initState` (session_start, เฉพาะ non-guest)
- `admin/lib/admin-metrics.ts`, `admin/components/admin/dashboard-metrics.tsx`, `admin/components/admin/dashboard-skeleton.tsx`, `admin/components/admin/top-sources-card.tsx` (ใหม่): section "การเติบโต" ต่อท้าย dashboard เดิม ตาม Design spec เป๊ะ

Files Changed: `supabase/schema.sql`, `app/lib/features/analytics/data/analytics_repository.dart` (ใหม่), `app/lib/features/auth/presentation/email_auth_screen.dart`, `app/lib/features/auth/presentation/username_setup_screen.dart`, `app/lib/features/drop/presentation/create_drop_screen.dart`, `app/lib/features/root/presentation/root_shell.dart`, `admin/lib/admin-metrics.ts`, `admin/components/admin/dashboard-metrics.tsx`, `admin/components/admin/dashboard-skeleton.tsx`, `admin/components/admin/top-sources-card.tsx` (ใหม่), `supabase/tests/wyn_077_basic_product_analytics_test.sh` (ใหม่)

Reason: ตาม Design spec ทุกจุด ไม่มีการตีความเพิ่มนอกเหนือที่ระบุ ยกเว้น 2 จุดที่ Design ปล่อยให้ Coding ตัดสินใจเอง (ระบุไว้แล้วใน Design's Handoff): (1) event table schema จริง — ดูด้านบน (2) นิยาม `signup_started` เชื่อมกับ Google/Apple OAuth หรือไม่ — **ตัดสินใจไม่เชื่อมรอบนี้** เพราะแยก "บัญชีใหม่" กับ "บัญชีเดิม" จาก client ฝั่ง OAuth ไม่ได้โดยไม่มี round-trip เพิ่ม — `signup_completed` ไม่มีช่องว่างนี้เพราะจับที่ `UsernameSetupScreen` (โชว์เฉพาะบัญชีที่ยังไม่มี username เท่านั้น ไม่ว่าจะสมัครผ่านช่องทางไหน)

Tests:
- **ไม่มี Flutter SDK ในสภาพแวดล้อมนี้** (เหมือนทุก session ก่อนหน้า) — `flutter analyze`/`flutter test` ยังไม่ได้รันจริง ตรวจสอบ syntax ด้วยมือแทน (brace/paren balance ทุกไฟล์ + อ่านทวนทุกจุดที่แก้) — **ต้องให้ QA/CI ยืนยันจริงก่อน deploy**
- SQL: เขียน `supabase/tests/wyn_077_basic_product_analytics_test.sh` ใหม่ (11 checks: RLS insert own/reject other user/no select policy at all, + 8 Growth column ด้วยข้อมูลจำลองที่คำนวณ expected ด้วยมือ) — **รันจริงไม่ได้กับ `schema.sql` ตัวจริงในนี้** เพราะเจอบั๊กเดิมที่ไม่เกี่ยวกับ WYN-077 เลย (ดู `.wyn/tasks/bugs/SCHEMA-002-home-feed-view-column-drift.md` — `create or replace view public.home_feed` พังตอน apply schema.sql สดๆ ตั้งแต่ก่อน WYN-077 เริ่ม ยืนยันด้วย `git stash` แล้ว) — **ยืนยันความถูกต้องของ SQL แทนด้วยสำเนาชั่วคราวนอก repo** (แพตช์เฉพาะ statement ที่พังให้เป็น `drop view ... cascade; create view ...` ไม่กระทบไฟล์จริงเลย) รันทั้ง `wyn_050_admin_dashboard_test.sh` เดิม (17/17 PASS ไม่กระทบของเดิม) และ `wyn_077_basic_product_analytics_test.sh` ใหม่ (11/11 PASS) ผ่านสำเนานั้น — QA ควรรันซ้ำจริงกับ `schema.sql` ตัวจริงหลังจากใครแก้ SCHEMA-002 แล้ว
- `python3 supabase/check_schema_ordering.py` → OK (ไม่มี forward reference ใหม่)
- Admin (Next.js): `npm install` + `npx next build` (TypeScript compile สะอาด, build สำเร็จ) + `npm run lint` (0 error/warning) — รันจริงทั้งคู่ ผ่านจริง

Build: Admin build ผ่านจริง (`next build` สำเร็จ, TypeScript type-check สะอาด) — Flutter build ไม่ได้รันจริง (ไม่มี SDK ในสภาพแวดล้อมนี้)

Known Issues:
1. **SCHEMA-002 (พบระหว่างทำ, ไม่ใช่บั๊กของ WYN-077)**: `schema.sql` apply สดๆ ตั้งแต่ต้นไม่ได้เพราะ `home_feed` view column-order พังก่อนถึงจุดที่ WYN-077 แก้เลย — บันทึกเป็น bug report แยกแล้ว (`.wyn/tasks/bugs/SCHEMA-002-home-feed-view-column-drift.md`) ไม่ใช่ scope ของ task นี้ให้แก้
2. `signup_started` ไม่ครอบคลุม Google/Apple OAuth รอบนี้ (ระบุเหตุผลไว้ใน `AnalyticsRepository`'s doc comment + Reason ด้านบน) — แปลว่า `signup_conversion_pct` สะท้อนเฉพาะ funnel ของการสมัครด้วย email/password เท่านั้น ไม่ใช่ทุกช่องทาง
3. Flutter ฝั่ง client ยังไม่ได้ verify ด้วย real Flutter toolchain (ดู Tests ด้านบน) — ต้องให้ QA/CI รันยืนยันก่อน deploy จริง
4. ค่า retention/activation percentage จะเป็น `null` (แสดงเป็น 0% ใน dashboard) จนกว่าจะมี cohort จริง (Phase 1 closed beta วันแรกๆ) — เป็นพฤติกรรมที่ตั้งใจ ไม่ใช่บั๊ก แต่ Admin อาจเข้าใจผิดว่า "0%" คือ "แย่" แทนที่จะเป็น "ยังไม่มีข้อมูล" — Design ไม่ได้ระบุ empty-state แยกสำหรับกรณีนี้ ทิ้งไว้ให้ Design/QA ตัดสินใจในรอบถัดไปถ้าเป็นปัญหาจริง

Handoff: ส่งต่อ AI QA & Security — จุดที่ต้องตรวจเป็นพิเศษ: (1) RLS ของ `analytics_events` (insert own only, ไม่มี select เลย) (2) `signup_completed_24h` vs `signup_conversion_pct` เป็นคนละ cohort กัน (มีคอมเมนต์อธิบายไว้ใน schema.sql แล้ว แต่ QA ควรตรวจว่า Coding เข้าใจถูกจริง ไม่ใช่แค่เขียนคอมเมนต์สวยๆ) (3) fire-and-forget ทุกจุด (4 instrumentation call sites) ต้องไม่มีทาง throw/บล็อก UI จริง (4) Flutter syntax ทั้งหมดยังไม่ได้ compile จริง ต้องรัน `flutter analyze`/`flutter test` ก่อนอนุมัติ
