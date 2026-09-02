# Product Task — WYN-077

Status: approved (QA PASS 2026-09-02, re-verified after Debug fix — see `.wyn/tasks/bugs/WYN-077-analytics-repository-uninitialized-supabase-crash.md`)
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

## QA notes (2026-09-02) — FAIL

Feature: WYN-077 Basic Product Analytics
Environment: local Postgres 16 (independent scratch DB, `schema.sql`'s own pre-existing SCHEMA-002 view bug patched around locally, not in the real file — see below), Node 22 / Next.js 16.3.2 admin app (`npm install && next build && npm run lint`, real). No Flutter SDK available in this sandbox — Dart changes verified by static trace only, not a real `flutter test` run.

Test Cases:
1. Independently re-derived and re-ran `supabase/tests/wyn_050_admin_dashboard_test.sh` (17 checks) — confirms no regression from extending `admin_dashboard_metrics()`.
2. Independently re-ran `supabase/tests/wyn_077_basic_product_analytics_test.sh` (11 checks) — all 8 new Growth columns + RLS insert/no-select.
3. 5 adversarial cases beyond what Coding's own test covered: `anon` role fully blocked (insert+select), an authenticated session with no JWT `sub` claim (`auth.uid()` NULL) correctly rejected on insert (proves this doesn't repeat the WYN-043/WYN-050 null-bypass bug class), an invalid `event_type` rejected by the CHECK constraint, an ordinary `user`-role account still rejected calling the *extended* (dropped+recreated) `admin_dashboard_metrics()` (proves the `coalesce()` role guard survived the recreate), and confirmed (not blocking, see Security Findings) that a normal user can insert unlimited self-attributed fake events with arbitrary `source` text — no rate limit.
4. `npx next build` + `npm run lint` on `admin/`, independently, from a clean `.next` — both pass, 0 errors/warnings.
5. Static trace of all 4 `AnalyticsRepository` call sites for a widget-test regression — **found one, see Failed below**.

Passed: 1, 2, 3, 4 (all SQL + Next.js checks — 28 total individual assertions across the 3 test runs, all correct; RLS/security boundary holds; retention/activation cohort window math is correct with no off-by-one).

Failed: `AnalyticsRepository(Supabase.instance.client)` is constructed inline at all 4 call sites, with no error handling around the `Supabase.instance` access itself (only the network `.insert()` call inside `_log()` is wrapped in try/catch). `Supabase.instance` throws synchronously if `Supabase.initialize()` was never called. `app/test/create_drop_screen_test.dart` never initializes Supabase (by design — it's built entirely on `RecordingDropRepository`/`RecordingProfileRepository` fakes specifically so it doesn't need to). Full bug report: `.wyn/tasks/bugs/WYN-077-analytics-repository-uninitialized-supabase-crash.md`.
Severity: Major — breaks 2 existing, currently-passing regression tests (`'sharing a valid poll calls createPollDrop...'`, `'publishing from an opened draft creates the Drop and deletes the draft'`), and the same root cause is latent (untested, not yet visible as a CI failure) in `EmailAuthScreen`'s sign-up path and `UsernameSetupScreen` (no test file exists for the latter at all).
Reproduction Steps: See bug report — run either of the two named `create_drop_screen_test.dart` tests.
Expected: The screen pops (`Navigator.pop(true)`) and `find.byType(CreateDropScreen)` finds nothing, same as before this task.
Actual (traced, not empirically run — no Flutter SDK in this sandbox): `Supabase.instance` throws while evaluating the analytics call's arguments, inside `_share()`'s existing try block; the catch handler sets an error message instead of popping, so the screen stays open and the `findsNothing` assertion fails.

Security Findings:
- RLS on `analytics_events`: insert-only, own-row-only, verified against `anon` (fully blocked at grant level), a NULL `auth.uid()` (rejected, not silently bypassed), and cross-user insert (rejected) — solid.
- `admin_dashboard_metrics()`'s admin/moderator gate survived the drop+recreate this task required — verified with a fresh ordinary-user rejection test against the *extended* function, not just trusting the original WYN-050 test still covers it.
- No XSS: `source` is fully attacker-controlled (any authenticated user, or anyone with direct REST API access, can set it to arbitrary text including `<script>` tags — demonstrated with 50 inserted rows) and rendered via plain JSX interpolation (`{s.source}`) in `top-sources-card.tsx` with no `dangerouslySetInnerHTML` anywhere in the new code — React escapes it, confirmed by reading the component, not assumed.
- No rate limiting / anti-gaming on `analytics_events` inserts (unlike `drop_views`, which has one specifically because view counts are a public-facing vanity metric). Not a blocker: this data is Admin-only, never shown to or benefiting the inserting user, so there's no product incentive to game it the way there is for `drop_views`. Worth a note for Product/Design if this table's purpose ever expands, not urgent now.

Recommendation: Fix the bug report above (move `Supabase.instance` access inside `AnalyticsRepository`'s own try/catch, not just the network call) and re-request QA. Everything else in this task — the SQL, the RLS/security boundary, and the Next.js admin dashboard — is solid and does not need to be re-reviewed from scratch next round, just re-confirm the fix and re-run `create_drop_screen_test.dart` for real once a Flutter toolchain is available.
Final Status: FAIL

## Debug notes (2026-09-02) — Fixed

Bug: `.wyn/tasks/bugs/WYN-077-analytics-repository-uninitialized-supabase-crash.md`
Root Cause: `AnalyticsRepository(Supabase.instance.client)` evaluated `Supabase.instance` (throws synchronously if uninitialized) as a constructor *argument*, outside any of this class's own error handling — reached by `create_drop_screen_test.dart`'s existing tests, which never initialize Supabase by design.
Fix: `AnalyticsRepository` is now a no-arg `const` class; `Supabase.instance.client` is resolved inside `_log()`'s own `try` block instead, alongside the network call. Updated all 4 call sites (`EmailAuthScreen`, `UsernameSetupScreen`, `CreateDropScreen`, `RootShell`) to `const AnalyticsRepository().logX(...)`; removed the now-unused `supabase_flutter` import from `EmailAuthScreen`/`UsernameSetupScreen` (still needed and kept in the other two, used elsewhere there).
Files Changed: `app/lib/features/analytics/data/analytics_repository.dart`, `app/lib/features/auth/presentation/email_auth_screen.dart`, `app/lib/features/auth/presentation/username_setup_screen.dart`, `app/lib/features/drop/presentation/create_drop_screen.dart`, `app/lib/features/root/presentation/root_shell.dart`
Tests: Full detail in the bug report — still no Flutter SDK available in this sandbox to run `create_drop_screen_test.dart` for real; re-verified by re-tracing the exact failure path by hand and confirming it can no longer occur (`Supabase.instance` is no longer evaluated outside `_log()`'s try block anywhere). `EmailAuthScreen`'s equivalent test gap is pre-existing (not introduced or closed by this task) and out of scope to fix here.
Regression Risk: Low — contained to `analytics_repository.dart` plus 4 one-line call-site updates, no business logic touched.
Lessons recorded: `.wyn/learning/MISTAKES.md` and `.wyn/learning/LESSONS_LEARNED.md` (2026-09-02 entries — copying a "fire-and-forget, no DI" pattern without checking whether the *safety condition* that made the original safe still holds at the new call site; a best-effort helper depending on an external singleton must resolve that singleton *inside its own error handling*, not accept it as a constructor argument evaluated by the caller).
Handoff to QA: Sent back — re-verify `create_drop_screen_test.dart`'s 2 previously-broken tests, and re-confirm nothing else regressed. SQL/RLS/security/Next.js findings from the first QA round are unaffected by this fix and don't need re-review.

## QA re-verification (2026-09-02) — PASS

Feature: WYN-077 Basic Product Analytics (post-fix re-verification)
Environment: same as first round — no Flutter SDK available, re-verified by independent static trace (not empirically run) of the fixed code, not a re-read of Debug's own claim.

Test Cases: Re-traced all 4 `AnalyticsRepository` call sites against the fixed `analytics_repository.dart` by hand:
1. Confirmed `Supabase.instance` is no longer evaluated anywhere outside `_log()`'s own `try` block — grep-verified zero remaining `AnalyticsRepository(<argument>)` call sites (all 4 now `const AnalyticsRepository()`, matching the new no-arg constructor).
2. Traced `_log()`'s execution precisely: `Supabase.instance.client` access happens *inside* the `try`, before the `await`, in the synchronous prefix of the `async` function — a throw there is caught by the same `catch (_) {}` as a real network failure, exactly like Dart's normal try/catch semantics (no async-specific gap). No exception can escape `_log()`, `logX()`, or reach `unawaited()`'s argument evaluation at any of the 4 call sites anymore.
3. Confirmed `EmailAuthScreen`/`UsernameSetupScreen` no longer import `supabase_flutter` at all (dead import removed) and have zero remaining `Supabase.` references — would have been an `unused_import` lint failure otherwise.
4. Confirmed `CreateDropScreen`/`RootShell` still correctly import/use `supabase_flutter` for their own pre-existing, unrelated reasons (not broken by the removal in the other 2 files).
5. Re-confirmed via `git show --stat` that this fix touched only the 5 Dart files — zero SQL/Next.js changes, so the first round's SQL/RLS/security/Next.js PASS findings stand unchanged and don't need re-running.

Passed: All 5 checks above — the exact failure mode from the first round (a synchronous throw landing in `_share()`'s outer catch before `Navigator.pop`) can no longer occur, by construction.
Failed: None.
Severity: N/A
Security Findings: Unchanged from the first round (see that section) — this fix didn't touch RLS, the SQL schema, or the admin dashboard.
Recommendation: Approve. The one remaining honest caveat, carried over from both rounds: nothing in this task has been verified against a real Flutter toolchain (`flutter analyze`/`flutter test`), because none is available in this sandbox — this is a pre-existing, structural environment limitation (see `.wyn/company/CONTEXT.md`'s many prior notes on this same gap), not something specific to this task's quality. AI Deploy & DevOps or whoever has a real Flutter toolchain available should run `flutter test app/test/create_drop_screen_test.dart` for real before this ships, as a final empirical confirmation of everything this round traced by hand.
Final Status: PASS

## Deploy notes (2026-09-02) — DEPLOYED

Merged via PR #211 → `main`. Real merge conflict with a concurrent PR (#210/#212, "WYNOS First Login/Account Onboarding" — also collided on task ID "WYN-077", a naming collision from two independent sessions, not resolved). Resolved by relocating `logSignupCompleted()` from the deleted `UsernameSetupScreen` to the new `OnboardingFlow._enterWynos()`. A staging mistake during that resolution meant the first deploy (run #36, `b87872c`) shipped without that one call; caught immediately by this session's own stop-hook, fixed in PR #213, redeployed as run #37 (`8dc18d4`) — both `deploy-web.yml` runs completed `success`. Full narrative: `.wyn/logs/deployments/2026-09-02-wyn-077-real-deploy.md`.

Founder said they'd run the production SQL migration via Supabase Dashboard before this deploy — not independently confirmed from this session (no Supabase credentials here). Admin Dashboard's Growth section remains undeployed (no live `admin/` Vercel project yet — pre-existing gap, not new).
