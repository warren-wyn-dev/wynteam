# Design Task — WYN-163

Status: approved (deploy สำเร็จแล้ว 2026-09-19 — รอ Founder ยืนยันบน production จริงก่อนย้ายไป completed/)
Owner: AI Design → AI Coding → AI QA & Security (FAIL รอบ 1) → AI Debug Engineer (WYN-164) →
AI QA & Security (PASS รอบ 2) → AI Deploy & DevOps (**deploy สำเร็จ**) → **รอ Founder ยืนยัน**
Screen: Onboarding/Auth ของ **WYNOS Web** (`web/app/(auth-flow)/**`, component จริงที่
`web/components/auth-flow/screens.tsx`) — `WelcomeScreen`, `LoginScreen`, `SignupStep1Screen`,
`SignupStep2Screen`, `OnboardingProfileScreen`, `ForgotPasswordScreen`
Purpose: ทำทิศทาง "แนว Apple ขาว-ดำ" ที่ Founder อนุมัติล่าสุด (ตัวอักษรใหญ่มั่นใจ + ทรง squircle + เว้น
ระยะเยอะขึ้น + press motion เบาๆ, สียังขาว-ดำ-เทาล้วนเหมือนเดิม) ให้เกิดจริงบน WYNOS Web (แพลตฟอร์มเดียวที่
พัฒนาต่อตอนนี้ — ดู DECISIONS.md รอบ 4/VERSION_CONTROL.md) — **แทนที่ทิศทาง "border-radius 16px เรียบๆ" ที่
เคยอนุมัติไปก่อน** เพราะ Founder รู้สึกว่าแบบนั้น "เหมือนแอปอื่น"
User Flow: ไม่เปลี่ยน action ปุ่มไหนเลย เปลี่ยนแค่ลำดับการมองเห็น (ปุ่ม "เข้าสู่ระบบ" มาก่อน Google ในหน้า
Welcome ตามรอบ 6) งานนี้เป็น visual + motion เบาๆ ไม่แตะ business logic
Components: ปุ่ม Primary (`.btn-primary`), ปุ่ม Outline (`.btn-outline`) — ประกาศรวมไฟล์เดียว
`web/app/auth-reference.css`, บวก Text Input/Textarea (`.field .wyn-input`/`.field textarea`) และหัวข้อ
หน้าจอ (`screens.tsx` inline style) ที่เปลี่ยนพร้อมกันเพื่อให้เป็นภาษาภาพเดียวกัน — ไม่มีปุ่ม guest-browse
ในเว็บอยู่แล้ว (ต่างจาก Flutter)
Interactions: เพิ่ม press feedback ใหม่ `transform: scale(0.96)` บน `:active` (ลบกฎ `transform: none` เดิม)
+ ต้องมี `prefers-reduced-motion` fallback — logic อื่นไม่เปลี่ยน
States: Default/Disabled คงพฤติกรรมเดิม, เพิ่ม Pressed state ใหม่ (scale 0.96) แทนที่ "ไม่มีการเปลี่ยนภาพ"
เดิม
Responsive Behavior: ไม่กระทบโครงสร้าง (เว็บออกแบบมือถือเป็นหลักอยู่แล้ว) — QA ต้องตรวจว่าหัวข้อ 32px ไม่ล้น
จอแคบ 320px และปุ่ม/input ไม่ล้นที่ textScale สูง (จุดใหม่ที่เพิ่มความเสี่ยงจากตัวอักษร/ขนาดที่ใหญ่ขึ้น)
Accessibility: touch target สูงขึ้น (58px ปุ่ม/56px input) ดีขึ้นกว่าเดิม, contrast ขาว/ดำเดิมผ่าน AA อยู่แล้ว
(ไม่เปลี่ยนค่าสี), motion ใหม่ต้อง respect `prefers-reduced-motion`
Design Rules:
1. **[ยืนยันแล้ว ไม่ต้องแก้]** สีปุ่มเว็บทั้งระบบเป็นขาว-ดำ-เทาล้วนอยู่แล้ว ตรงกับที่ Founder ยืนยันซ้ำในรอบ 7
   ("โทน ขาว ดำ เหมือนเดิม") — ไม่มีสีที่สาม (`--red` สงวนไว้เฉพาะ error text)
2. **[แก้ รอบ 7 — ค่าสุดท้าย แทนที่ 16px เดิม]** ปุ่ม: `border-radius` 999px → **24px**, `height` 50px →
   **58px**, ตัวหนังสือ 14px/600 → **16px/700**
3. **[แก้ รอบ 7]** Input/textarea: `border-radius` 10px → **18px**, `height` 44px → **56px**, `padding`
   0 14px → **0 18px**
4. **[แก้ รอบ 7]** หัวข้อหน้าจอทั้ง 6 หน้า: รวมเป็น **32px / weight 800 / letter-spacing -0.02em**
5. **[เพิ่ม รอบ 7]** press feedback `scale(0.96)` แทนที่ `transform: none` เดิม + reduced-motion fallback
5b. **[เพิ่ม รอบ 8]** ขยายโลโก้ WYNOS: `WelcomeScreen` `height: 62`→**`110`**, `LoginScreen` `height: 46`→
   **`64`** (`width: "auto"` คงสัดส่วนไฟล์ 660:426 เดิม) — Founder บอก "โลแบรนด์ไม่เด่น"
6. ปุ่ม guest-browse ไม่มีอยู่แล้วในเว็บ — ไม่ต้องทำอะไรเพิ่มสำหรับข้อนี้
7. ขอบเขตงานนี้ = `auth-reference.css` + typography ใน `screens.tsx` (Onboarding/Auth เท่านั้น) — ไม่ไล่แก้
   หน้าจออื่นของเว็บ (แต่ Founder อาจสั่งขยายทิศทางนี้ทั้งเว็บในอนาคต เพราะเป็นการเปลี่ยนความรู้สึกทั้งแอป)
8. **แอป Flutter (`app/`) ไม่แตะเลยในรอบนี้** ตามคำสั่ง Founder พักงาน Flutter ยาว (DECISIONS.md 2026-09-19
   รอบ 4)
9. จุดอื่นที่ sapphire/ink เคยทำหน้าที่นอกปุ่ม (ฝั่ง Flutter) ไม่เกี่ยวกับงานนี้ เว็บใช้ token คนละชุดอยู่แล้ว
Handoff: **อนุมัติแล้ว พร้อมส่ง AI Coding — 7 จุด** (spec เต็มที่
`.wyn/docs/design/wyn-163-onboarding-button-redesign.md`):
1. ปุ่ม: radius/height/font ตามข้อ 2 ด้านบน
2. Input/textarea: radius/height/padding ตามข้อ 3
3. หัวข้อหน้าจอ 6 หน้า: 32px/800/-0.02em ตามข้อ 4
4. press feedback ใหม่ตามข้อ 5
5. ขยายโลโก้ WYNOS (Welcome 110px / Login 64px) ตามข้อ 5b
6. เพิ่มโลโก้ Google ทางการในปุ่ม "เข้าสู่ระบบด้วย Google" (asset จริงตาม Google Identity branding
   guideline — ยังไม่มีใน repo ต้องหา/เพิ่มใหม่)
7. สลับลำดับปุ่ม "เข้าสู่ระบบ" มาก่อน Google ใน `WelcomeScreen` (รอบ 5-6 เดิม)

ทั้ง 7 จุดต้องผ่าน QA ก่อน deploy ขึ้น WYNOS Web Beta1 เสมอ (ห้ามข้าม QA ตาม AGENTS.md)

Artifact (canvas เดียว ใช้ต่อเนื่องทุกรอบ): https://claude.ai/artifact/Gq2encfg9hTqbrAHJ45o7x (อาร์ตบอร์ด 6
= เวอร์ชันล่าสุดที่อนุมัติแล้ว รวมทุกอย่าง, อาร์ตบอร์ด 1-5 เป็นประวัติการตัดสินใจ)

## Log

- 2026-09-19 รอบ 1: เสนอ 4 ทิศทางสี (Coral/Emerald/Violet/Ink+Red) พร้อม contrast จริง — Founder เลือก
  **D (Ink Mono + Red Signal)**
- 2026-09-19 รอบ 2: เสนอ 3 ทรงปุ่มบนสี D — Founder เลือก **"2" (โค้งมนปานกลาง 16px)** [ค่านี้ถูกแทนที่แล้ว
  ในรอบ 7]
- 2026-09-19: ทำ mockup งานจริงทั้ง 5 หน้าจอ Flutter (อาร์ตบอร์ด 3) ตามคำขอ "ขอดูงานจริง"
- 2026-09-19 รอบ 3: Founder ยืนยัน "โทนสี ขาว ดำ เทา ธีมสว่าง" + สั่งตัดปุ่ม "เข้าชม WYNOS ได้เลย" ออก
- แก้เลขงานจาก WYN-161 → **WYN-163** (ชนกับงานอื่นที่มีอยู่แล้วในระบบ)
- 2026-09-19 รอบ 4 (สำคัญ): Founder สั่งพัก Flutter ยาว — **ย้าย scope งานนี้ทั้งหมดมาเป็น WYNOS Web**
- 2026-09-19 รอบ 5: Founder อนุมัติ scope — border-radius 16px + เพิ่มโลโก้ Google จริง [radius ถูกแทนที่
  แล้วในรอบ 7]
- 2026-09-19 รอบ 6: Founder สั่งสลับตำแหน่งปุ่ม "เข้าสู่ระบบ" มาก่อน "เข้าสู่ระบบด้วย Google"
- 2026-09-19 รอบ 7 (สำคัญ): Founder ดูเวอร์ชัน 16px แล้วบอก **"ไม่สวย เหมือนแอปอื่นเลย ท้อละ"** → ถามว่า
  "ถ้า Apple ออกแบบโซเชียลจะเป็นยังไง" → AI Design ทำมอคอัพแนว Apple (ตัวอักษรใหญ่ + squircle + สีเดียว/
  ขาว-ดำ) → Founder เลือกเวอร์ชันขาว-ดำล้วน แล้วอนุมัติ **"ใช่แบบนี้เลย ทำจริงได้เลย"** — เขียน spec ใหม่
  แทนที่ค่า radius/typography เดิมทั้งหมด บันทึกที่ `.wyn/company/DECISIONS.md` วันเดียวกัน
- 2026-09-19 รอบ 8: Founder ถาม "งานจริงจะออกมาแบบไหน" → AI Design ทำอาร์ตบอร์ด 6 รวมทุกการอนุมัติเข้าด้วย
  กัน (ครบ 6 หน้าจอ) → Founder ตอบ **"โลแบรนด์ไม่เด่น นอกนั้นโอเค"** → ขยายโลโก้ WYNOS หน้า Welcome/Login
  บันทึกที่ `.wyn/company/DECISIONS.md` วันเดียวกัน — **อนุมัติครบทุกจุดแล้ว**
- 2026-09-19 (AI Coding): Implement ครบทั้ง 7 จุดใน `web/app/auth-reference.css` +
  `web/components/auth-flow/screens.tsx` แล้ว — `npm run typecheck`/`npm run lint`/`npm run build` ผ่านหมด
  (0 error), เพิ่ม fix เสริม 1 จุดที่ spec ไม่ได้ระบุไว้ตรงๆ (ช่องกรอกชื่อผู้ใช้ในหน้า Signup 1 ใช้ inline
  style แยกจาก `.wyn-input` ทำให้มุมโค้งไม่ตรงกับช่องอื่น — แก้ให้ตรงกันด้วย), เช็คภาพจริงด้วย Playwright
  screenshot ทั้ง 6 หน้าจอผ่าน dev server จริง ตรงตามมอคอัพที่ Founder อนุมัติ, อัปเดต regression test
  `auth-reference-flow.spec.ts` 2 จุดที่ยังล็อกค่าเดิม (999px/50px, 10px/44px) ให้ตรงค่าใหม่ที่อนุมัติแล้ว —
  รายละเอียดเต็มดู commit `16d3ccaa`
- 2026-09-19 (AI QA & Security) — **QA รอบ 1: FAIL**: ทดสอบจริงบน dev server ผ่าน Playwright (ทั้ง 6 หน้าจอ
  + คลิกผ่าน flow จริง Welcome→Login/Signup, ตรวจ console error 0 จุด, ตรวจ `prefers-reduced-motion` ทำงาน
  ถูกต้อง, ตรวจ 320/390/430px) เจอ 2 findings ระดับ MEDIUM: (1) `/account/add` ใช้ CSS ไฟล์เดียวกันแต่ไม่อยู่
  ใน scope ที่อนุมัติ — ได้ปุ่ม/input ใหญ่ขึ้นตามไปด้วยแบบไม่ได้ตั้งใจ แต่ไม่ได้โลโก้ Google/หัวข้อใหญ่ตามไป
  ด้วย ทำให้หน้าจอนี้ดูค้างกลางทาง (2) หัวข้อ Welcome 32px ตัดคำกลางคำที่จอ 320px (ปกติที่ 390px+) — ไม่มี
  security finding, ไม่มี functional break, ไม่มี regression ของฟีเจอร์เดิม รายละเอียดเต็ม/repro/fix ที่แนะนำ
  อยู่ที่ `.wyn/tasks/bugs/WYN-164-onboarding-redesign-followup.md`
- 2026-09-19 (AI Debug Engineer) — **WYN-164 แก้แล้ว**: ขยาย `/account/add` ให้ครบชุด (โลโก้ Google +
  หัวข้อ 32px) และลดขนาด tagline หน้า Welcome เหลือ 28px แก้ปัญหาตัดคำที่ 320px — typecheck/lint/build ผ่าน
  หมด, ตรวจซ้ำทั้ง 7 หน้าจอด้วย Playwright จริงไม่มี regression, เพิ่ม regression test 2 เคส รายละเอียดเต็ม
  ที่ `.wyn/tasks/bugs/WYN-164-onboarding-redesign-followup.md` (commit `a657e7bc`)
- 2026-09-19 (AI QA & Security) — **QA รอบ 2: PASS**: ยืนยัน `.auth-ref-viewport` มีแค่ 2 ไฟล์ที่ใช้จริงทั้ง
  repo (`screens.tsx`, `account-add-route.tsx` — ไม่มีจุดที่ 3 หลุดรอด), `typecheck`/`lint`/`build` ผ่านหมด
  (0 error, 3 pre-existing warning เดิม), ทดสอบจริงด้วย Playwright บน dev server: sweep ทั้ง 7 หน้าจอ ×
  320/390/430px ไม่มี console error เลย (0/21), `/account/add` มีโลโก้ Google + หัวข้อ 32px ตามที่แก้แล้ว,
  หัวข้อ Welcome ที่ 320px เหลือบรรทัดเดียว (44px จากเดิม ~102px), ปุ่ม/ลำดับปุ่มเดิมของ WYN-163 (58px/24px,
  สร้างบัญชีใหม่→เข้าสู่ระบบ→Google) ไม่ regression, คลิกผ่าน flow จริงได้ปกติ, โลโก้ Welcome/Login = 110px/
  64px ตรงสเปก — ไม่พบ finding ใหม่ ไม่มี security finding
- ย้ายไป `.wyn/tasks/approved/` แล้ว — ถัดไป: **AI Deploy & DevOps** deploy ขึ้น WYNOS Web Beta1 (รอ Founder
  อนุมัติ production deployment ตาม AGENTS.md ก่อนเสมอ)
- 2026-09-19 (AI Deploy & DevOps) — **Deploy สำเร็จ**: เปิด PR #545, CI เขียวครบ 8 checks, **Founder merge
  เอง** ผ่าน GitHub เข้า `main` — trigger `wyn-158-production-deploy.yml` run #132 อัตโนมัติ ผ่านครบทั้ง 3
  step (Production preflight / Deploy to Vercel production / Verify production routes) — AI ยืนยันได้เองแค่
  ระดับ workflow (sandbox นี้ออก network ไป wynos.online ไม่ได้ ทดสอบแล้วจริง) **ยังรอ Founder เปิดดูจริงบน
  `wynos.online` ก่อนถึงจะย้าย task นี้ไป `completed/` ได้** ตามกติกา WORKFLOW.md บันทึก deploy log เต็มที่
  `.wyn/logs/deployments/2026-09-19-wyn-163-164-onboarding-button-redesign-deploy.md`
