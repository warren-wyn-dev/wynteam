# Product Task — WYN-125

Status: approved — deploy สำเร็จขึ้น production จริงแล้ว (schema applied, @warren + @wynos_online อยู่ใน allowlist แล้ว) — ยังไม่ completed จนกว่าจะมีฟีเจอร์จริงมาผูกใช้งาน flag นี้สำเร็จ (ดู `.wyn/logs/deployments/2026-09-06-wyn-125-developer-account-allowlist-deploy.md`)
Owner: AI Product Manager → AI Design → AI Coding → AI QA & Security → AI Deploy & DevOps (เสร็จรอบนี้)

Feature: Staged Rollout — ปล่อยอัปเดตให้บัญชีนักพัฒนา/ทีมภายในก่อน แล้วค่อยปล่อยให้ผู้ใช้ทั่วไป

Goal: ลดความเสี่ยงที่ build ใหม่มีบั๊กแล้วกระทบผู้ใช้จริงทุกคนพร้อมกัน โดยให้ทีมภายในทดสอบ build จริงบน production-like environment ก่อนเปิดให้ผู้ใช้ทั่วไปเห็น

Target User: ทีมภายใน (Founder + นักพัฒนา/ผู้ทดสอบที่ระบุ) เป็นกลุ่มแรก, ผู้ใช้ทั่วไปของ WYNOS เป็นกลุ่มถัดไป

Problem:
- สถาปัตยกรรมปัจจุบันของ WYNOS คือ Flutter Web (PWA) เพียง endpoint เดียว deploy ขึ้น Vercel production project เดียว (`.github/workflows/deploy-web.yml`) — ยังไม่มี native app บน Apple App Store (ไม่มี Apple Developer Account ตาม decision 2026-08-13/2026-09-01) และยังไม่มี pipeline ขึ้น Google Play เช่นกัน
- เมื่อรัน deploy workflow (`vercel deploy --prod`) ทุกคนที่เปิด URL production จะได้ build ใหม่ทันที ไม่มีกลไกแบ่งกลุ่มผู้ใช้ (ไม่มี feature flag / account allowlist / percentage rollout ในระบบตอนนี้)
- Founder ต้องการให้อัปเดตไปหาบัญชีนักพัฒนา/ทีมภายในก่อน รอจนพอใจ แล้วค่อยปล่อยให้ผู้ใช้ทั่วไปเห็น

Requirements:
1. **ทางลัดที่ทำได้ทันที (ไม่ต้องเขียนโค้ดเพิ่ม)** — ใช้ Vercel Preview Deployment ที่มีอยู่แล้ว (ระบบ auto-preview-per-branch ของ Vercel ในโปรเจกต์ "wynteam" ตามที่ comment ใน `deploy-web.yml` ระบุไว้) เป็น "staging URL" ให้ทีมภายในทดสอบ build จริงก่อน แล้วค่อยกด "Run workflow" เพื่อ promote build เดียวกันขึ้น production เมื่อพอใจ — deploy-web.yml เป็น `workflow_dispatch` (manual-only) อยู่แล้ว จึงมี checkpoint คนกดเองอยู่แล้วโดยธรรมชาติ
2. **ทางแก้ระยะยาว (ต้อง implement เพิ่ม)** — สร้างระบบ gate การมองเห็น feature/ build ใหม่ตาม "บัญชี" ภายใน production endpoint เดียว เช่น
   - Allowlist ตาม user id/email ในฝั่ง client หรือ Supabase (เช็คว่า user เป็น "internal/dev account" หรือไม่ ก่อนเปิดให้เห็น UI/behavior ใหม่)
   - หรือ Remote config / feature flag table ใน Supabase ที่ AI Coding เช็คก่อน render ฟีเจอร์ใหม่
   - ผู้ใช้ทั่วไปยังคงเห็น behavior เดิมจน Founder สั่งเปิด flag ให้ทุกคน
3. ไม่ใช้ native app store staged rollout (Google Play % rollout / TestFlight group) ในตอนนี้ เพราะยังไม่มี native distribution channel ที่ active อยู่ตามสถานะปัจจุบัน — เป็นตัวเลือกที่พิจารณาได้ในอนาคตถ้า Founder ตัดสินใจเปิด Apple Developer Account / Google Play

Acceptance Criteria:
- [x] Founder เลือกแนวทางที่ต้องการ — ทั้งสองอย่าง (process-only ใช้ได้แล้ว + ระบบ flag ถาวร ออกแบบเสร็จแล้ว รอ Coding)
- [ ] ถ้าเลือกระบบ flag: มีวิธีระบุ "บัญชีนักพัฒนา" ที่ชัดเจน (เช่น allowlist email/user id ที่ Founder เป็นผู้กำหนด) และผู้ใช้ทั่วไปไม่เห็นการเปลี่ยนแปลงจนกว่า Founder จะสั่งเปิด — **design เสร็จแล้ว** (`.wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md`), รอ AI Coding implement จริงก่อนเช็คให้ครบ
- [ ] มีขั้นตอน rollback/ปิด flag ได้ทันทีถ้าเจอปัญหาระหว่างทดสอบกับทีมภายใน โดยไม่กระทบผู้ใช้ทั่วไป (ซึ่งยังไม่เห็น feature อยู่แล้ว)
- [ ] บันทึกขั้นตอนนี้ลง deployment log ตาม `.wyn/company/WORKFLOW.md` (สิ่งที่ deploy, ผล verification, ใครทดสอบ, ผลลัพธ์)

Dependencies:
- `.github/workflows/deploy-web.yml` (deploy pipeline ปัจจุบัน)
- Vercel project "wynteam" (preview deployments ที่มีอยู่แล้ว) สำหรับทางลัด
- ถ้าเลือกระบบ flag: ต้องมี AI Design ออกแบบว่า flag ควรอยู่ระดับไหน (ทั้งแอป vs ต่อฟีเจอร์) และ AI Coding implement + AI QA ทดสอบก่อนขึ้น production

Priority: Medium — ไม่ใช่ P0 (ไม่มีบั๊ก production ตอนนี้) แต่เป็น process improvement ที่ลดความเสี่ยงของทุก deploy ถัดไป ควรทำก่อนที่ WYNOS จะมีผู้ใช้ทั่วไปจำนวนมากขึ้น

Risks:
- ถ้าไม่ทำอะไรเลย: ทุก deploy ในอนาคตยังคงกระทบผู้ใช้ทุกคนพร้อมกันเหมือนเดิม ความเสี่ยงเพิ่มขึ้นตามจำนวนผู้ใช้จริง
- ถ้าทำระบบ flag เร่งรีบ: อาจเพิ่มความซับซ้อนของโค้ด (ทุกฟีเจอร์ใหม่ต้องเช็ค flag) และมีจุดที่ลืมปิด flag ให้ผู้ใช้ทั่วไปได้ถ้าไม่มี process ชัดเจน
- Preview URL ไม่ได้ต่อกับข้อมูล production เดียวกันเสมอไป (ต้องตรวจสอบว่า preview ใช้ Supabase project เดียวกับ production หรือไม่ ก่อนใช้ทดสอบ flow ที่แตะข้อมูลจริง) — ต้องยืนยันจุดนี้ก่อนใช้เป็น staging จริงจัง

Recommendation:
แนะนำให้เริ่มจากทางลัด (ข้อ 1) ทันทีโดยไม่ต้องรอ coding — ใช้ preview deployment ของ Vercel เป็น staging ให้ทีมภายในทดสอบก่อน promote ขึ้น production ทุกครั้ง เพราะไม่มี cost เพิ่มและใช้ pipeline ที่มีอยู่แล้ว (`deploy-web.yml` เป็น manual-dispatch อยู่แล้ว) ส่วนระบบ feature-flag ถาวรตามบัญชี (ข้อ 2) ควรตั้งเป็น task แยกให้ AI Design ออกแบบก่อน เพราะมีผลต่อโครงสร้างโค้ดหลายฟีเจอร์ในอนาคต ไม่ควรรีบ implement โดยไม่มี design spec

Handoff:
[2026-09-06] Founder อนุมัติ: ทำทั้ง Requirement 1 (preview URL, ใช้ได้ทันทีโดยไม่ต้องรอ) และ Requirement 2 (ระบบ account allowlist/feature-flag) คู่ขนานกัน — ส่งต่อ **AI Design** ออกแบบรายละเอียดของ Requirement 2 ต่อทันที:
- เก็บรายชื่อ "บัญชีนักพัฒนา" ที่ไหน (เช่น ตาราง Supabase ใหม่ vs allowlist ในโค้ด) และ Founder เป็นผู้เพิ่ม/ลบได้อย่างไร
- flag ควรอยู่ระดับไหน (ทั้งแอป vs ต่อฟีเจอร์ต่อ build)
- UX เมื่อ flag เปิด/ปิด (ผู้ใช้ทั่วไปควรไม่รู้สึกว่าขาดอะไรไปจนกว่าจะเปิดให้)
เสร็จ Design แล้วส่งต่อ AI Coding → AI QA & Security ตาม workflow ปกติ ก่อนขึ้น production (ห้ามข้าม QA)
อ้างอิงการตัดสินใจเต็ม: `.wyn/company/DECISIONS.md` หัวข้อ "[2026-09-06] Staged Rollout สำหรับ WYNOS"

---

## AI Design Output (เสร็จแล้ว — ส่งต่อ AI Coding)

Design spec ฉบับเต็ม: `.wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md`

**สรุปการตัดสินใจหลัก**:
1. **Reuse สถาปัตยกรรมของ WYN-122 (Chat Lockdown)** เกือบทั้งหมด แล้วทำให้ generic แทนที่จะผูกกับฟีเจอร์เดียว — pattern เดิม (allowlist table + SECURITY DEFINER status function + GitHub Actions workflow เป็นสวิตช์) พิสูจน์แล้วว่าใช้งานได้จริงบน production ของ WYN ภายใต้สถานะ auth ปัจจุบัน (anonymous sign-in) — ไม่ต้องคิดใหม่
2. **เก็บรายชื่อ "บัญชีนักพัฒนา" ที่**: ตาราง Supabase ใหม่ `public.developer_accounts` (user_id uuid → `profiles.id`, label, added_at) — **ไม่มี SELECT/INSERT/UPDATE/DELETE policy ใดๆ เลย** เข้าถึงได้เฉพาะผ่าน Supabase Management API เท่านั้น ป้องกันรั่วว่าใครเป็นนักพัฒนาด้วย
3. **Founder เพิ่ม/ลบบัญชีนักพัฒนาผ่าน GitHub Actions workflow ใหม่** (`wyn125-manage-developer-accounts.yml`, มิเรอร์ `wyn122-toggle-chat-lockdown.yml`) — action `list`/`add`/`remove` ระบุด้วย username (resolve เป็น profiles.id เอง ไม่ hardcode UUID) — ไม่ต้องสร้าง admin UI ใหม่ตามที่อนุญาตไว้ในโจทย์ เพราะเฉพาะคนที่ trigger workflow บน repo ได้ (Founder) เท่านั้นที่ทำได้
4. **Flag อยู่ระดับ boolean เดียว per-user: `is_developer_account()`** (ไม่ใช่ matrix ต่อฟีเจอร์) — ฟีเจอร์ใหม่ในอนาคตเรียก accessor ตัวเดียว (`DeveloperAccessService.isDeveloperAccount()` ใน `app/lib/core/`) แล้วเลือกเอง branch การ render/behavior — reusable ข้ามฟีเจอร์ได้ทันทีโดยไม่ต้องสร้างตาราง/ฟังก์ชันใหม่ทุกรอบ
5. **Fail-closed โดยโครงสร้าง**: error/null auth/ไม่อยู่ใน allowlist → คืน `false` เสมอ → ผู้ใช้ทั่วไป 100% ในวันนี้เห็น behavior เดิมทุกประการ ไม่มีทาง error ของระบบนี้จะไปโผล่เป็น UI แปลกให้ผู้ใช้ทั่วไปเห็น (ตรง Requirement 3)
6. **ไม่แตะ auth architecture**: อาศัย `profiles.username` ที่มีอยู่แล้วแม้ในโหมด anonymous sign-in ปัจจุบัน (กลไกเดียวกับที่ WYN-122 ใช้ระบุ @warren/@wynos_online สำเร็จมาแล้ว) — ไม่ต้องรอ Google/Apple OAuth หรือ Phone OTP กลับมาก่อน

**Handoff ให้ AI Coding ต้องทำ**:
1. เพิ่ม `public.developer_accounts` table + `public.is_developer_account()` function ใน `supabase/schema.sql` (ต้องมี `grant execute ... to authenticated;` — ระวังบั๊ก class เดียวกับที่ WYN-122 QA Round 1 เจอ คือลืม grant)
2. สร้าง `.github/workflows/wyn125-manage-developer-accounts.yml` (list/add/remove ผ่าน Supabase Management API, resolve username→id)
3. สร้าง `DeveloperAccessService` ใน `app/lib/core/` (generic, ไม่ผูกกับ feature ใดฟีเจอร์หนึ่ง, fail-closed, cache ต่อ session, invalidate เมื่อ auth state เปลี่ยน)
4. เขียน `supabase/tests/wyn_125_developer_accounts_test.sh` ตรวจ RLS lockdown เต็มรูปแบบ + fail-closed ทุก edge case + grant execute ถูกต้อง
5. งานรอบนี้ **ไม่มี UI ใดถูกแก้** (ส่งมอบแค่กลไก ยังไม่มีฟีเจอร์ไหนถูก gate จริง) — ต้องยืนยันกับ Founder เรื่องรายชื่อ username เริ่มต้นที่จะใส่เป็นบัญชีนักพัฒนาชุดแรก (แนะนำเริ่มจาก `@warren`) ก่อน merge จริง แต่ไม่บล็อกการเริ่ม implement

เสร็จแล้วส่งต่อ **AI QA & Security** เน้นตรวจ RLS lockdown ของตารางใหม่ + fail-closed ทุก edge case + grant execute + 0 regression กับฟีเจอร์เดิม ก่อนขึ้น production (ห้ามข้าม QA ตาม WORKFLOW.md)

---

## AI Coding Output (เสร็จแล้ว — ส่งต่อ AI QA & Security)

Status: coding เสร็จ — **ยังไม่ deploy** รอ AI QA & Security ตรวจก่อนเสมอ (ห้ามข้าม QA)

Implementation:
- เพิ่ม section "WYN-125: Developer account allowlist (staged rollout mechanism)" ท้าย `supabase/schema.sql`: table `public.developer_accounts` (`user_id uuid primary key references profiles(id) on delete cascade`, `label text`, `added_at timestamptz`), RLS enabled ไม่มี policy ใดๆ เลย (fail-closed จาก client ทุกทาง), function `public.is_developer_account()` (SECURITY DEFINER, ไม่รับ parameter, เช็คเฉพาะ `auth.uid()` ของผู้เรียก, `coalesce(..., false)`), พร้อม `grant execute on function public.is_developer_account() to authenticated;` (จุดที่ WYN-122 Round 1 เคยพลาด — ตรวจสอบครบแล้ว)
- สร้าง workflow ใหม่ 2 ตัวมิเรอร์ pattern ของ WYN-122 (แยกเป็น "apply schema" กับ "manage/switch" เหมือน WYN-122 แยก `wyn122-apply-chat-lockdown-schema.yml`/`wyn122-toggle-chat-lockdown.yml`):
  - `.github/workflows/wyn125-apply-developer-accounts-schema.yml` — `workflow_dispatch` เปล่า, apply table+function+grant ขึ้น production จริงผ่าน Supabase Management API (idempotent, copy-paste เดียวกับ schema.sql), ไม่เพิ่มใครเข้า allowlist
  - `.github/workflows/wyn125-manage-developer-accounts.yml` — `workflow_dispatch` พร้อม input `action` (choice: list/add/remove) และ `username` (string) — resolve username → `profiles.id` เสมอ (escape single-quote ก่อน interpolate กัน SQL injection จาก free-form input), fail ชัดเจนถ้า resolve ไม่ได้ 1 แถวพอดี ไม่เดา ไม่ hardcode UUID
- สร้าง `DeveloperAccessService` ที่ `app/lib/core/developer_access/developer_access_service.dart` — `Future<bool> isDeveloperAccount()` เรียก RPC `is_developer_account`, fail-closed จริง (try/catch คืน `false` เสมอ, ไม่โยน exception ต่อ, ไม่ cast แบบ `as bool` ที่อาจ throw), cache เป็น static ต่อ auth session ปัจจุบัน (เพราะทุกจุดเรียกสร้าง instance ใหม่ตาม convention ของ repository อื่นในโปรเจกต์ เช่น `ChatRepository`), invalidate cache อัตโนมัติผ่าน `auth.onAuthStateChange` listener (sign-out/anonymous session ใหม่/สลับบัญชี) — มี `resetForTest()` แบบ `@visibleForTesting` เหมือน `DeepLinkService.resetForTest()`
- เขียน `supabase/tests/wyn_125_developer_accounts_test.sh` (20 checks) ครอบคลุมครบตาม Handoff: allowlist ว่าง → false, allowlisted user → true, non-allowlisted user (2 คน) → false, "anonymous ใหม่" (authenticated-role user ที่ไม่เคยถูกเพิ่ม) → false, `authenticated`/`anon` เข้าถึงตาราง `developer_accounts` ตรงๆไม่ได้เลยทั้ง select/insert/update/delete (มิเรอร์ pattern จาก `wyn_048_audit_log_test.sh`/`wyn_030_appeal_system_test.sh`), grant execute ยืนยันด้วย `has_function_privilege()` และพิสูจน์ว่าเป็น grant จริง (รอดจากการ revoke PUBLIC default เหมือน WYN-122 CHECK12b/12c)
- **ไม่แก้ UI ใดๆ** ตามขอบเขต — ไม่มีฟีเจอร์ไหนถูก wrap ด้วย flag นี้ในรอบนี้

Files Changed:
- `supabase/schema.sql` (เพิ่ม section ท้ายไฟล์เท่านั้น, ไม่แก้ของเดิม)
- `.github/workflows/wyn125-apply-developer-accounts-schema.yml` (ใหม่)
- `.github/workflows/wyn125-manage-developer-accounts.yml` (ใหม่)
- `app/lib/core/developer_access/developer_access_service.dart` (ใหม่)
- `supabase/tests/wyn_125_developer_accounts_test.sh` (ใหม่)

Reason: ตาม Design spec เต็มรูปแบบ (`.wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md`) — reuse สถาปัตยกรรม WYN-122 (allowlist table + SECURITY DEFINER function + GitHub Actions เป็นสวิตช์) แบบ generic ไม่ผูกฟีเจอร์ใดฟีเจอร์หนึ่ง เพื่อให้ฟีเจอร์ในอนาคตเรียกใช้ซ้ำได้ทันทีโดยไม่ต้องสร้างตาราง/ฟังก์ชันใหม่

Tests:
- `bash supabase/tests/wyn_125_developer_accounts_test.sh` → **PASS ทั้ง 20 checks**
- รัน regression suite เดิมทั้งหมด (`supabase/tests/*.sh`, 35 ไฟล์รวมของใหม่) → ผ่าน 34/35 — มี 1 ไฟล์ที่ fail อยู่แล้วก่อนงานนี้: `wyn_038_view_counting_test.sh` (8 checks เกี่ยวกับ view-count dedup/rate-limit) — **ยืนยันแล้วว่าเป็น pre-existing failure ไม่เกี่ยวกับ WYN-125**: รัน `git stash` กลับไปที่ commit ก่อนงานนี้ (`fc4f264`) แล้วรันสคริปต์เดิมซ้ำ ได้ผล fail เหมือนเดิมทุกประการ (checks/ตัวเลขตรงกัน) — ไม่ใช่ regression ที่เกิดจากงานนี้ แต่เป็นปัญหาที่มีอยู่ก่อนแล้วในสภาพแวดล้อมทดสอบ ควรเปิด task แยกให้ Debug Engineer ตรวจสอบ
- `python3 supabase/check_schema_ordering.py` → OK (ไม่มี forward reference)

Build:
- `flutter pub get` → สำเร็จ
- `flutter analyze` (app/) → **No issues found!**
- `flutter test` (app/) → **1293/1293 ผ่านหมด**
(ติดตั้ง Flutter 3.47.1 ตรงกับเวอร์ชันที่ pin ไว้ใน `.github/workflows/ci.yml` เพื่อรันในเครื่องมือ AI Coding นี้เอง — ผลลัพธ์ตรงกับที่ CI จะรัน)

Known Issues (สิ่งที่ QA ต้องเช็คเป็นพิเศษ):
1. **`wyn_038_view_counting_test.sh` fail อยู่ก่อนงานนี้แล้ว** (8/25 checks) — ไม่เกี่ยวกับ WYN-125 (ยืนยันด้วย git stash เทียบ baseline) แต่ QA ควรทราบและพิจารณาเปิด bug task แยกให้ Debug Engineer เพราะเป็นความเสี่ยงที่มีอยู่แล้วในฟีเจอร์ view-counting (WYN-038/083), ไม่ใช่สิ่งที่ต้อง block งานนี้
2. **รายชื่อ "บัญชีนักพัฒนา" ชุดแรกยังไม่ถูกเพิ่มจริงใน production** — Handoff ข้อ 5 ของ Design ต้องการให้ยืนยันกับ Founder ก่อน merge จริง (แนะนำเริ่มจาก `@warren`) แล้วรัน `wyn125-apply-developer-accounts-schema.yml` ตามด้วย `wyn125-manage-developer-accounts.yml` (action: add) — งานนี้ส่งมอบแค่กลไก ยังไม่ได้รันบน production จริง
3. `flutter analyze`/`flutter test` รันในเครื่องมือ AI Coding เอง (ติดตั้ง Flutter SDK ชั่วคราวเพื่อยืนยัน) ไม่ใช่ผลจาก CI run จริงบน GitHub Actions — แนะนำให้ QA/Deploy ยืนยันซ้ำด้วย CI run จริงอีกครั้งเมื่อ push ขึ้น branch/PR
4. Client `DeveloperAccessService` ยังไม่ถูกเรียกใช้จากที่ใดในแอปเลย (ตามขอบเขตงาน) — ยังไม่มี integration/widget test ที่ครอบคลุมมัน เพราะไม่มี UI ใดเรียกใช้ในรอบนี้ ให้ QA ตรวจแค่ logic ระดับ unit ผ่านการอ่านโค้ด + regression suite ของ schema/RLS เป็นหลัก

Handoff: ส่งต่อ **AI QA & Security** ตรวจตาม `.wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md` Handoff ข้อ 6: (1) RLS lockdown ของ `developer_accounts` (2) fail-closed ของ `is_developer_account()` ทุก edge case (null auth/ไม่อยู่ใน allowlist/allowlist ว่าง) (3) grant execute ถูกต้อง (4) 0 regression กับฟีเจอร์เดิม (ยกเว้น wyn_038 ที่เป็น pre-existing ตามข้างต้น) — **ห้ามข้าม QA และห้าม deploy เองก่อน QA อนุมัติ** ตาม WORKFLOW.md

---

## AI QA & Security Output (เสร็จแล้ว — PASS, ส่งต่อ AI Deploy & DevOps)

Environment: local sandbox — Postgres 16.13 (`sudo -u postgres`, ไม่ใช่ production Supabase — schema นี้ยังไม่เคย apply ขึ้น production), Flutter SDK 3.47.1 (ตรงกับ pin ใน `ci.yml`) รันจริงในเครื่องมือ QA เอง ไม่ใช่แค่เชื่อรายงานจาก AI Coding

**ทดสอบจริงทุกข้อ ไม่ใช่แค่ static review**:

1. **`bash supabase/tests/wyn_125_developer_accounts_test.sh`** รันจริงกับ Postgres local → **PASS ทั้ง 20/20 checks** ยืนยันด้วยตัวเอง (CHECK1-14 ครบ รวม empty-allowlist=false, allowlisted=true, non-allowlisted (alice/bob/diane-anon)=false, `authenticated`/`anon` เข้าถึงตาราง select/insert/update/delete ไม่ได้เลยแม้แต่แถวเดียว, `has_function_privilege` ยืนยัน grant execute จริงและรอดจากการ revoke PUBLIC default)
2. **Static review ของ `supabase/schema.sql` section WYN-125**: `grep` ยืนยันไม่มี `policy` ใดๆ ผูกกับ `developer_accounts` เลยในทั้งไฟล์ (0 matches) ตรงตาม Design Rule "ไม่มี SELECT/INSERT/UPDATE/DELETE policy ใดๆ" — `grant execute on function public.is_developer_account() to authenticated;` มี syntax ถูกต้อง (ไม่ใช่บั๊ก class เดียวกับ WYN-122 Round 1) — `set search_path = public` ป้องกัน search_path hijacking ของ SECURITY DEFINER function ถูกต้อง — `python3 supabase/check_schema_ordering.py` → OK (ไม่มี forward reference)
3. **Regression suite เต็มรูปแบบ**: รัน `supabase/tests/*.sh` ทั้ง 38 ไฟล์เองจริง (ไม่เชื่อ AI Coding เฉยๆ) → 37/38 PASS, เจอ `wyn_038_view_counting_test.sh` fail 8/29 checks เหมือนที่ AI Coding รายงาน — **ยืนยันซ้ำเองว่าเป็น pre-existing** ด้วยการสร้าง `git worktree` ที่ commit `fc4f264` (ก่อน WYN-125) แล้วรันสคริปต์เดิมซ้ำ ได้ตัวเลข fail เหมือนกันทุกประการ (CHECK2=4/1, CHECK3=5/1, CHECK4=6/2, CHECK8a-c=6/2, CHECK9b=6/2) → ไม่เกี่ยวกับ WYN-125 จริง แนะนำเปิด bug task แยกให้ Debug Engineer ตรวจ view-counting dedup/rate-limit ต่อไป (ไม่ block งานนี้)
4. **`flutter analyze` (app/)** รันเองจริง → **No issues found!**
5. **`flutter test` (app/)** รันเองจริง (ใช้ Flutter 3.47.1 ที่มีอยู่ในเครื่องมือ QA) → **1293/1293 ผ่านหมด**, exit code 0
6. **Dart `DeveloperAccessService` code review**: `try/catch` ครอบ RPC ทั้งก้อน คืน `false` เสมอเมื่อ error (ไม่โยน exception ต่อ), ใช้ `result == true` แทน `as bool` cast (กัน cast ที่ผิด shape หลุดออกนอก try ไม่ได้ เพราะ cast อยู่ใน try block เดียวกัน) ตรวจแล้วไม่มี path ใดโยน exception หลุด catch ได้จริง, cache invalidate ผ่าน `onAuthStateChange` ถูกต้อง, `resetForTest()` ตรง convention เดียวกับ `DeepLinkService.resetForTest()` — ไม่มีที่ใดในแอปเรียกใช้จริงตามขอบเขต (`grep` ยืนยัน 0 usage นอกไฟล์ตัวเอง) ตรงตาม scope ที่ตกลงไว้
7. **Workflow files**: เทียบ `wyn125-apply-developer-accounts-schema.yml`/`wyn125-manage-developer-accounts.yml` กับ `wyn122-apply-chat-lockdown-schema.yml`/`wyn122-toggle-chat-lockdown.yml` แบบ side-by-side — pattern สอดคล้องกัน 100% (ใช้ secrets เดิม `SUPABASE_ACCESS_TOKEN`/`SUPABASE_URL`, resolve username→`profiles.id` ก่อนเสมอไม่ hardcode UUID, escape single-quote ป้องกัน SQL injection จาก free-form `username` input, fail ชัดเจนถ้า resolve ได้ไม่ตรง 1 แถว) — `grep` ยืนยันไม่มี secret hardcode ในทั้ง 2 ไฟล์
8. **Information leak check**: ฟังก์ชันไม่รับ parameter ใดๆ เช็คแค่ `auth.uid()` ของผู้เรียกเอง ไม่มีทาง enumerate คนอื่นได้ — workflow "manage" list สมาชิกใน GitHub Actions log เป็น pattern เดียวกับที่ `wyn122-toggle-chat-lockdown.yml` ใช้อยู่แล้ว (เข้าถึงได้เฉพาะคนที่ trigger workflow บน repo ได้เท่านั้น) ไม่ใช่ความเสี่ยงใหม่ที่เกิดจากงานนี้

**บั๊ก/ปัญหาที่พบ**: ไม่พบบั๊กใดๆ ที่ต้องแก้ ทั้ง logic-level และ typo-level — ไม่มีอะไรต้องแก้เองในรอบนี้

**ข้อสังเกต (ไม่ block)**: ยังไม่มี Dart unit test เฉพาะของ `DeveloperAccessService` เอง (ตรวจผ่านแค่ code review + regression suite ระดับ schema/RLS) — แต่ตรวจแล้วว่า `core/` folder อื่นๆ ในโปรเจกต์นี้ก็ไม่มี unit test เช่นกัน (ไม่ใช่ gap ใหม่เฉพาะงานนี้) ไม่ block การ PASS รอบนี้เพราะยังไม่มี UI ใดเรียกใช้จริง

**Final Status: PASS**

**Handoff ต่อไปยัง AI Deploy & DevOps** — ต้องรันตามลำดับนี้เท่านั้น (ห้ามสลับลำดับ):
1. รัน `.github/workflows/wyn125-apply-developer-accounts-schema.yml` (`workflow_dispatch` เปล่า) ก่อนเสมอ — apply table + function + grant ขึ้น production จริง (ยังไม่เพิ่มใครเข้า allowlist)
2. หลังจากนั้นค่อยรัน `.github/workflows/wyn125-manage-developer-accounts.yml` (`action: add`, `username: warren` หรือ username อื่นตามที่ Founder ยืนยัน) เพื่อเพิ่มบัญชีนักพัฒนาชุดแรก — **ต้องยืนยันรายชื่อ username กับ Founder ก่อนรันขั้นตอนนี้** ตาม Handoff ข้อ 5 ของ Design spec (แนะนำเริ่มจาก `@warren`)
3. บันทึกผล verification ทั้งสอง workflow runs ลง deployment log ตาม `.wyn/company/WORKFLOW.md` (สิ่งที่ deploy, ผล verification จริงจาก step "Verify"/"After" ของแต่ละ workflow)
4. งานนี้ยังไม่มี UI ใดถูก gate จริง — ไม่มีอะไรให้ Founder ทดสอบผ่านหน้าจอในรอบนี้ แค่ยืนยันว่า 2 workflow รันสำเร็จและ `has_function_privilege`/allowlist ตรงตามที่ตั้งใจในผลลัพธ์ของ workflow เอง

**แยกออกจากงานนี้ (ไม่ block)**: `wyn_038_view_counting_test.sh` fail อยู่ก่อนแล้ว (pre-existing, ยืนยันซ้ำด้วย `git worktree` แล้วว่าไม่เกี่ยวกับ WYN-125) — แนะนำเปิด bug task แยกให้ AI Debug Engineer ตรวจ view-counting dedup/rate-limit (WYN-038/083) ต่อไปเป็นงานคนละ track
