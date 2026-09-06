# Product Task — WYN-124

Status: active — AI Design เสร็จแล้ว (Requirement 2) — ส่งต่อ AI Coding
Owner: AI Product Manager → AI Design → AI Coding

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
- [ ] ถ้าเลือกระบบ flag: มีวิธีระบุ "บัญชีนักพัฒนา" ที่ชัดเจน (เช่น allowlist email/user id ที่ Founder เป็นผู้กำหนด) และผู้ใช้ทั่วไปไม่เห็นการเปลี่ยนแปลงจนกว่า Founder จะสั่งเปิด — **design เสร็จแล้ว** (`.wyn/docs/design/wyn-124-staged-rollout-developer-accounts.md`), รอ AI Coding implement จริงก่อนเช็คให้ครบ
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

Design spec ฉบับเต็ม: `.wyn/docs/design/wyn-124-staged-rollout-developer-accounts.md`

**สรุปการตัดสินใจหลัก**:
1. **Reuse สถาปัตยกรรมของ WYN-122 (Chat Lockdown)** เกือบทั้งหมด แล้วทำให้ generic แทนที่จะผูกกับฟีเจอร์เดียว — pattern เดิม (allowlist table + SECURITY DEFINER status function + GitHub Actions workflow เป็นสวิตช์) พิสูจน์แล้วว่าใช้งานได้จริงบน production ของ WYN ภายใต้สถานะ auth ปัจจุบัน (anonymous sign-in) — ไม่ต้องคิดใหม่
2. **เก็บรายชื่อ "บัญชีนักพัฒนา" ที่**: ตาราง Supabase ใหม่ `public.developer_accounts` (user_id uuid → `profiles.id`, label, added_at) — **ไม่มี SELECT/INSERT/UPDATE/DELETE policy ใดๆ เลย** เข้าถึงได้เฉพาะผ่าน Supabase Management API เท่านั้น ป้องกันรั่วว่าใครเป็นนักพัฒนาด้วย
3. **Founder เพิ่ม/ลบบัญชีนักพัฒนาผ่าน GitHub Actions workflow ใหม่** (`wyn124-manage-developer-accounts.yml`, มิเรอร์ `wyn122-toggle-chat-lockdown.yml`) — action `list`/`add`/`remove` ระบุด้วย username (resolve เป็น profiles.id เอง ไม่ hardcode UUID) — ไม่ต้องสร้าง admin UI ใหม่ตามที่อนุญาตไว้ในโจทย์ เพราะเฉพาะคนที่ trigger workflow บน repo ได้ (Founder) เท่านั้นที่ทำได้
4. **Flag อยู่ระดับ boolean เดียว per-user: `is_developer_account()`** (ไม่ใช่ matrix ต่อฟีเจอร์) — ฟีเจอร์ใหม่ในอนาคตเรียก accessor ตัวเดียว (`DeveloperAccessService.isDeveloperAccount()` ใน `app/lib/core/`) แล้วเลือกเอง branch การ render/behavior — reusable ข้ามฟีเจอร์ได้ทันทีโดยไม่ต้องสร้างตาราง/ฟังก์ชันใหม่ทุกรอบ
5. **Fail-closed โดยโครงสร้าง**: error/null auth/ไม่อยู่ใน allowlist → คืน `false` เสมอ → ผู้ใช้ทั่วไป 100% ในวันนี้เห็น behavior เดิมทุกประการ ไม่มีทาง error ของระบบนี้จะไปโผล่เป็น UI แปลกให้ผู้ใช้ทั่วไปเห็น (ตรง Requirement 3)
6. **ไม่แตะ auth architecture**: อาศัย `profiles.username` ที่มีอยู่แล้วแม้ในโหมด anonymous sign-in ปัจจุบัน (กลไกเดียวกับที่ WYN-122 ใช้ระบุ @warren/@wynos_online สำเร็จมาแล้ว) — ไม่ต้องรอ Google/Apple OAuth หรือ Phone OTP กลับมาก่อน

**Handoff ให้ AI Coding ต้องทำ**:
1. เพิ่ม `public.developer_accounts` table + `public.is_developer_account()` function ใน `supabase/schema.sql` (ต้องมี `grant execute ... to authenticated;` — ระวังบั๊ก class เดียวกับที่ WYN-122 QA Round 1 เจอ คือลืม grant)
2. สร้าง `.github/workflows/wyn124-manage-developer-accounts.yml` (list/add/remove ผ่าน Supabase Management API, resolve username→id)
3. สร้าง `DeveloperAccessService` ใน `app/lib/core/` (generic, ไม่ผูกกับ feature ใดฟีเจอร์หนึ่ง, fail-closed, cache ต่อ session, invalidate เมื่อ auth state เปลี่ยน)
4. เขียน `supabase/tests/wyn_124_developer_accounts_test.sh` ตรวจ RLS lockdown เต็มรูปแบบ + fail-closed ทุก edge case + grant execute ถูกต้อง
5. งานรอบนี้ **ไม่มี UI ใดถูกแก้** (ส่งมอบแค่กลไก ยังไม่มีฟีเจอร์ไหนถูก gate จริง) — ต้องยืนยันกับ Founder เรื่องรายชื่อ username เริ่มต้นที่จะใส่เป็นบัญชีนักพัฒนาชุดแรก (แนะนำเริ่มจาก `@warren`) ก่อน merge จริง แต่ไม่บล็อกการเริ่ม implement

เสร็จแล้วส่งต่อ **AI QA & Security** เน้นตรวจ RLS lockdown ของตารางใหม่ + fail-closed ทุก edge case + grant execute + 0 regression กับฟีเจอร์เดิม ก่อนขึ้น production (ห้ามข้าม QA ตาม WORKFLOW.md)
