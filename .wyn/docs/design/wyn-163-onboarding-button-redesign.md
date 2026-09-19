# Design Spec — WYN-163: Onboarding Button Redesign (WYNOS Web)

Owner: AI Design → Founder review → AI Coding
Ref: Founder ขอเองผ่านข้อความตรง (2026-09-19): "เรามาช่วยกันออกแบบ UX UI ปุ่มต่างๆใหม่ เริ่มจาก0" → ยืนยัน
เป็นการเปลี่ยนทิศทาง visual จริง → "เราจะออกแบบใหม่หมดเลย เริ่มตั้งแต่เลือกสี ทุกอย่างใหม่หมด" → เริ่มจากหน้าจอ
Onboarding/Login → รอบ 3: "โทนสี ขาว ดำ เทา ธีมสว่าง" + ตัดปุ่ม "เข้าชม" ออก → **รอบ 4 (สำคัญ)**: "ตอนนี้มีแค่
Wynos Web Beta1 V.1.0.0 Beta4 พักไปก่อนยาวๆเลย" — **งานนี้ย้าย scope จากแอป Flutter มาเป็น WYNOS Web ทั้งหมด**
Artifact: https://claude.ai/artifact/Gq2encfg9hTqbrAHJ45o7x (อาร์ตบอร์ด 1-3 ทำไว้ตอน scope ยังเป็น Flutter —
ใช้เป็น reference ทิศทางสี/ทรง/การตัดปุ่มเข้าชมได้เหมือนเดิม ค่า token/ชื่อไฟล์เปลี่ยนเป็นของเว็บ)
Decision log: `.wyn/company/DECISIONS.md` (2026-09-19, WYN-163 รอบ 1-7), `.wyn/company/VERSION_CONTROL.md`,
`.wyn/company/WEB_VERSION_CONTROL.md`

> **นี่คือ visual direction ใหม่ที่ Founder ร้องขอเอง** ไม่ขัดกับกติกา "ห้ามคิดทิศทาง visual ใหม่หากมี design
> system ที่อนุมัติแล้ว" — Founder เป็นฝ่ายเปิดคำขอเองตามข้อยกเว้นที่บันทึกไว้ 2026-09-07

---

## Screen

หน้าจอ Onboarding/Auth ทั้งหมดของ **WYNOS Web** (`web/app/(auth-flow)/**`, component จริงอยู่ที่
`web/components/auth-flow/screens.tsx`):

1. `WelcomeScreen` (`/welcome`)
2. `LoginScreen` (`/login`)
3. `SignupStep1Screen` (`/signup/step-1`)
4. `SignupStep2Screen` (`/signup/step-2`)
5. `OnboardingProfileScreen` (`/onboarding/profile`)
6. `ForgotPasswordScreen` (`/forgot-password`)

ปุ่มทุกหน้าใช้ CSS ชุดเดียวกัน (`.btn-primary`/`.btn-outline` scope ใต้ `.auth-ref-viewport`) ที่ประกาศรวมไว้
ที่ไฟล์เดียว: **`web/app/auth-reference.css`** — แก้ไฟล์นี้ไฟล์เดียวก็ครบทั้ง 6 หน้าจอ

## Purpose

ทำสิ่งที่ Founder ตัดสินใจไปแล้วให้เกิดขึ้นจริงบน **WYNOS Web** ซึ่งเป็นแพลตฟอร์มเดียวที่ยังพัฒนาต่อตอนนี้
(Flutter app พักยาว) — สีขาว-ดำ-เทาล้วน, ไม่มีปุ่ม guest-browse, โลโก้ Google จริง, สลับลำดับปุ่ม Login/Google

**[อัปเดตรอบ 7 — สำคัญ]** หลังดูเวอร์ชัน "16px รอบเดียว" แล้ว Founder รู้สึกว่า "ไม่สวย เหมือนแอปอื่นเลย" —
AI Design เสนอทิศทาง "ถ้า Apple ออกแบบโซเชียล" (ตัวอักษรใหญ่มั่นใจ + ทรง squircle มุมโค้งต่อเนื่อง + เว้น
ระยะเยอะขึ้น) ทำมอคอัพให้ดู 2 เวอร์ชัน (มีสีส้ม accent / ขาว-ดำล้วน) — **Founder เลือกเวอร์ชันขาว-ดำล้วน
("ใช่แบบนี้เลย ทำจริงได้เลย")** เอกสารนี้จึงเขียนสเปกใหม่แทนที่ "border-radius 16px" เดิมทั้งหมดด้วยสเปก
squircle/typography/spacing รอบนี้ (ดู Components/Design Rules ด้านล่าง — ค่าทั้งหมดเปลี่ยนจากรอบ 5 แล้ว)

**สีไม่เปลี่ยนจากที่ยืนยันไปแล้ว**: `.btn-primary` ใช้ `background: var(--text-primary)` (ดำ) +
`color: var(--bg)` (ขาว) อยู่แล้ว ไม่มีสีที่สามปนอยู่เลยนอกจาก `--red: var(--wyn-accent)` ที่ใช้เฉพาะ error
text ปุ่ม guest-browse ก็**ไม่มีอยู่แล้ว**ในหน้า Welcome ของเว็บ (มีแค่ "สร้างบัญชีใหม่" / "เข้าสู่ระบบ" /
"เข้าสู่ระบบด้วย Google" — เรียงลำดับใหม่ตามรอบ 6)

## User Flow

ไม่เปลี่ยน action ของปุ่มไหนเลย แต่ **[เปลี่ยนรอบ 6]** ลำดับการมองเห็นในหน้า Welcome เปลี่ยน: เดิม
สร้างบัญชีใหม่ → Google → เข้าสู่ระบบ เปลี่ยนเป็น **สร้างบัญชีใหม่ → เข้าสู่ระบบ → เข้าสู่ระบบด้วย Google**
ตามคำสั่ง Founder (ให้ "เข้าสู่ระบบ" ธรรมดาอยู่ก่อน Google) — ปุ่มยังพาไปหน้า/action เดิมทุกประการ แค่สลับ
ตำแหน่งในลำดับ JSX

## Components

ปุ่มทั้งหมดในระบบมี 2 ระดับความสำคัญเท่านั้น (เว็บใช้ 2 คลาสอยู่แล้ว ไม่มีปุ่ม text/tertiary สีแยกแบบที่เคย
ออกแบบไว้ฝั่ง Flutter เพราะหน้าเว็บไม่มีปุ่ม "ส่งรหัสอีกครั้ง"/OTP แบบเดียวกัน — ฝั่งเว็บ auth ใช้ email/password
ไม่ใช้ OTP):

1. **Primary** (`.btn-primary`) — "สร้างบัญชีใหม่", "ดำเนินการต่อ", "หน้าถัดไป", "สร้างบัญชี", "เข้าสู่ระบบ",
   "เริ่มใช้งาน Wynos", "ส่งลิงก์รีเซ็ตรหัสผ่าน"
   - พื้น `var(--text-primary)` (ดำ), ตัวหนังสือ `var(--bg)` (ขาว) — **สีเดิมถูกต้องแล้ว ไม่แตะ**
   - **[แก้ รอบ 7 — แทนที่ 16px เดิม]** `border-radius: 999px` → **`24px`** (squircle)
   - **[แก้ รอบ 7]** `height: 50px` → **`58px`**
   - **[แก้ รอบ 7]** `font-size: 14px` / `font-weight: 600` → **`16px` / `700`**
2. **Outline** (`.btn-outline`) — "เข้าสู่ระบบ", "เข้าสู่ระบบด้วย Google" (ลำดับใหม่ตามรอบ 6)
   - โปร่งใส + ขอบ `var(--border-strong)` + ตัวหนังสือ `var(--text-primary)` — **สีเดิมถูกต้องแล้ว ไม่แตะ**
   - **[แก้ รอบ 7]** เหมือน Primary ทุกค่า (`24px` / `58px` / `16px`-`700`) — ทั้งสองคลาสยังกำหนดขนาดร่วมกัน
     เป็น selector เดียว (`.btn-primary, .btn-outline`) เหมือนเดิม
   - **[อนุมัติแก้ในรอบนี้]** ปุ่มนี้ในโค้ดปัจจุบันเป็นแค่ตัวหนังสือล้วน ไม่มีโลโก้/ไอคอน Google เลยแม้แต่น้อย
     (ต่างจากฝั่ง Flutter ที่อย่างน้อยยังมีไอคอนเปล่า) — Founder อนุมัติให้เพิ่มโลโก้ทางการพร้อมกันในรอบนี้
     (ดูรายละเอียด asset ที่ Handoff)
3. **Text Input / Textarea** (`.field .wyn-input`, `.field textarea`) — ไม่ใช่ปุ่ม แต่เปลี่ยนพร้อมกันเพราะ
   เป็นส่วนหนึ่งของ "ทรง squircle" เดียวกันในมอคอัพที่อนุมัติ
   - **[แก้ รอบ 7]** `border-radius: 10px` → **`18px`**
   - **[แก้ รอบ 7]** `height: 44px` → **`56px`**
   - **[แก้ รอบ 7]** `padding: 0 14px` → **`0 18px`**
   - **[แก้ รอบ 7]** `.field label` เพิ่ม `font-weight: 600` (เดิมไม่ได้ระบุ น้ำหนักเริ่มต้นคือ 400)
4. **Screen headline** (inline style ในแต่ละ Screen component ของ `screens.tsx` — ไม่ใช่ class ใน CSS)
   ปัจจุบันแต่ละหน้าใช้ `fontSize: 20, fontWeight: 700` (Login/Signup1/Signup2/OnboardingProfile/
   ForgotPassword) และ Welcome ใช้ `fontSize: 17, fontWeight: 600` แยกต่างหาก
   - **[แก้ รอบ 7 — ทุกจุด]** เปลี่ยนเป็น **`fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em"`** ทั้ง
     6 หน้าจอให้เป็นค่าเดียวกัน (รวม Welcome ด้วย — เลิกใช้ 17/600 แยก)

ปุ่มทั้งสองคลาสยังใช้ selector ร่วมเดียวกันเหมือนเดิม แค่เปลี่ยนค่าตัวเลข

## Interactions

`onClick`, `disabled` ระหว่าง loading, validation ของแต่ละหน้าจอยังทำงานเหมือนเดิมทุกประการ ไม่เปลี่ยน logic

**[เพิ่มรอบ 7]** ก่อนหน้านี้ CSS ตั้งใจปิด transform ทั้งหมดบน hover/active (`transform: none`) — เพื่อให้ได้
"ความรู้สึก Apple" ตามที่ Founder อนุมัติ (กดแล้วมีการตอบสนอง ไม่ใช่นิ่งสนิท) **ลบกฎ `transform: none` ออก**
แล้วเพิ่ม press feedback แบบง่าย (CSS ล้วน ไม่ต้องพึ่ง JS/library ใหม่):
```css
.btn-primary, .btn-outline { transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1); }
.btn-primary:active:not(:disabled), .btn-outline:active:not(:disabled) { transform: scale(0.96); }
```
หมายเหตุ: นี่คือการประมาณ "สปริง" ด้วย CSS ล้วน (easing โค้งเกินจุดแล้วดีดกลับเล็กน้อย) ไม่ใช่ spring physics
เต็มรูปแบบแบบ Framer Motion/native iOS — ถ้า Founder อยากได้ bounce ที่สมจริงกว่านี้ (เด้งเกินแล้วดีดกลับ
มองเห็นชัด) เป็นงานเพิ่มเติมที่ต้องคุยแยก เพราะต้องพึ่ง JS animation ไม่ใช่ CSS transform ธรรมดา

## States

| State | Primary | Outline |
|---|---|---|
| Default | พื้นดำ ตัวหนังสือขาว | โปร่งใส ขอบเข้ม ตัวหนังสือดำ |
| Disabled | พึ่งพฤติกรรม native ของ `<button disabled>` (เดิมไม่มี custom style — คงเดิม ไม่ใช่ scope งานนี้) | เหมือนกัน |
| Pressed (`:active`) | **[ใหม่ รอบ 7]** `transform: scale(0.96)` transition 160ms | เหมือนกัน |

ไม่มีปุ่มไหนสื่อสารสถานะด้วยสีอย่างเดียว — ทุกปุ่มมีข้อความ label ของตัวเองอยู่แล้ว

## Responsive Behavior

ไม่กระทบ — ปุ่มกว้างเต็ม container (`width: 100%`) ของ `.phone` viewport อยู่แล้ว ไม่มี breakpoint แยก
(WYNOS Web ออกแบบมาสำหรับหน้าจอมือถือเป็นหลักอยู่แล้วตาม `wynos-web-base-design-system.md`)

## Accessibility

- Touch target: สูงขึ้นเป็น 58px (ปุ่ม) / 56px (input) — เกินเกณฑ์ขั้นต่ำ 44px มากขึ้นกว่าเดิมอีก (ดีขึ้น)
- Contrast: ตัวหนังสือขาวบนพื้นดำ (`--text-primary`) และตัวหนังสือดำบนพื้นขาวโปร่งใส — ทั้งคู่เป็นคู่สีเดิมที่
  ผ่าน AA อยู่แล้วจาก `--wyn-*` token system (ไม่ได้เปลี่ยนค่าสี จึงไม่มี contrast ใหม่ต้องตรวจ)
- หัวข้อใหญ่ขึ้น (32px) ช่วย readability ดีขึ้น ไม่ใช่ปัญหา — แต่ต้องตรวจว่าหัวข้อยาวๆ (เช่น "ตั้งรหัสผ่าน" ก็
  สั้นอยู่แล้ว ไม่มีปัญหา) ไม่ล้นจอที่ textScale/zoom สูงหรือจอแคบ (320px) — QA ต้องตรวจซ้ำจริง
- การเปลี่ยน `border-radius`/ขนาด/font-size ไม่กระทบ semantics/keyboard focus/screen reader ที่มีอยู่แล้ว
- press feedback ใหม่ (`transform: scale`) ต้อง respect `prefers-reduced-motion` — เพิ่ม media query กัน
  ไว้ด้วย: `@media (prefers-reduced-motion: reduce) { .btn-primary, .btn-outline { transition: none; } }`

## Design Rules

1. **[ยืนยันแล้ว ไม่ต้องแก้]** สีปุ่มทั้งระบบเว็บเป็นขาว-ดำ-เทาล้วนอยู่แล้ว (ดำ=`--text-primary`,
   ขาว=`--bg`, เทา=`--text-secondary`/`--text-muted`/`--border-strong`) แดง (`--red`) สงวนไว้เฉพาะ error
   text เท่านั้น ตรงกับที่ Founder ยืนยัน "โทนสี ขาว ดำ เทา ธีมสว่าง" เป๊ะอยู่แล้ว
2. **[แก้ รอบ 7 — ค่าสุดท้าย แทนที่ 16px]** ทรงปุ่ม/input ทุกประเภท: `border-radius: 999px`/`10px` →
   **`24px` (ปุ่ม) / `18px` (input)** — "squircle" มุมโค้งมากกว่าเดิมมาก ในไฟล์ `web/app/auth-reference.css`
3. **[แก้ รอบ 7]** ขนาดปุ่ม/input สูงขึ้น: ปุ่ม `50px`→`58px`, input `44px`→`56px` ตัวหนังสือปุ่ม `14px/600`→
   `16px/700`
4. **[แก้ รอบ 7]** หัวข้อหน้าจอ (screen headline) ทุกหน้าจอ ทั้ง 6 หน้า: `32px / weight 800 /
   letter-spacing -0.02em` แทนค่าเดิมที่ไม่สม่ำเสมอ (20/700 บางหน้า, 17/600 หน้า Welcome)
5. **[เพิ่ม รอบ 7]** press feedback: `scale(0.96)` บน `:active` แทนที่กฎ `transform: none` เดิม (ดู
   Interactions) — ต้องมี `prefers-reduced-motion` fallback
5b. **[เพิ่ม รอบ 8]** โลโก้ WYNOS (`web/public/wynos_logo_mark.png`, สัดส่วนจริง 660:426) ในหน้า
   `WelcomeScreen` ปัจจุบันเล็กเกินไป (`height: 62`) — Founder บอก "โลแบรนด์ไม่เด่น" ให้ขยายเป็น
   **`height: 110`** (`width: "auto"` ตามสัดส่วนเดิม ได้กว้างประมาณ 170px) ส่วนโลโก้หน้า `LoginScreen`
   (ปัจจุบัน `height: 46`) ปรับเป็น **`height: 64`** ให้สัดส่วนทั้งเว็บสอดคล้องกัน (ไม่ต้องใหญ่เท่า Welcome)
6. **[กว้างขึ้นได้ตามดุลยพินิจ]** ระยะห่าง/padding ระหว่าง element ให้ "เพิ่มขึ้นจากเดิมอย่างเห็นได้ชัด"
   (มอคอัพใช้ padding เนื้อหา ~28px แทน 16-24px เดิม) — AI Coding ปรับตัวเลขปลีกย่อยระหว่าง field ได้เอง
   ตราบใดที่ยึดหลัก "หายใจได้มากกว่าเดิม" ไม่ต้อง pixel-match มอคอัพเป๊ะทุกจุด (คนละเรื่องกับข้อ 2-4 ที่ต้อง
   ตรงเป๊ะ)
7. **สียังคงเดิมทั้งหมด ไม่เปลี่ยน** — ขาว-ดำ-เทาล้วน ไม่มีสีที่สาม (Founder ยืนยันซ้ำใน รอบ 7: "โทน ขาว ดำ
   เหมือนเดิม")
8. ปุ่ม guest-browse ไม่มีอยู่ในเว็บ — ไม่ต้องทำอะไรเพิ่มสำหรับข้อนี้
9. งานนี้แก้เฉพาะไฟล์ `auth-reference.css` + typography ใน `screens.tsx` (ขอบเขต Onboarding/Auth เท่านั้น)
   — ไม่ไล่แก้ปุ่ม/input หน้าจออื่นของเว็บ (Home/Feed/Profile ฯลฯ) จากเอกสารนี้ ถ้าจะขยายทั้งเว็บต้องเป็นงานแยก
   (แต่บันทึกไว้ว่า Founder อาจสั่งขยายทิศทางนี้ทั้งเว็บในอนาคต เพราะเป็นการเปลี่ยน "ความรู้สึก" ของทั้งแอป)
10. **แอป Flutter (`app/`) ไม่แตะเลยในรอบนี้** ตามคำสั่ง Founder พักงาน Flutter ยาว — งาน spec เดิมที่เคยเขียน
    ไว้สำหรับ Flutter เก็บไว้เป็น reference ในกรณีที่ Founder สั่งกลับมาทำ Flutter ต่อในอนาคตเท่านั้น

## Handoff

**อนุมัติแล้ว (2026-09-19 รอบ 5-8) — พร้อมส่ง AI Coding, 7 จุด ใน `web/app/auth-reference.css` +
`web/components/auth-flow/screens.tsx`**:

1. **[อนุมัติ รอบ 7 — ค่าสุดท้าย]** `.btn-primary`/`.btn-outline`: `border-radius: 999px` → **`24px`**,
   `height: 50px` → **`58px`**, `font-size: 14px`/`font-weight: 600` → **`16px`/`700`**
2. **[อนุมัติ รอบ 7]** `.field .wyn-input`, `.field textarea`: `border-radius: 10px` → **`18px`**,
   `height: 44px` → **`56px`**, `padding: 0 14px` → **`0 18px`**; `.field label` เพิ่ม `font-weight: 600`
3. **[อนุมัติ รอบ 7]** หัวข้อหน้าจอทั้ง 6 หน้าใน `screens.tsx`: รวมเป็นค่าเดียว **`32px / 800 /
   letter-spacing -0.02em`**
4. **[อนุมัติ รอบ 7]** ลบกฎ `transform: none` เดิม เพิ่ม press feedback `scale(0.96)` บน `:active` +
   `prefers-reduced-motion` fallback (โค้ดตัวอย่างอยู่ที่ Interactions ด้านบน)
5. **[อนุมัติรอบ 5]** เพิ่มโลโก้ Google ทางการในปุ่ม "เข้าสู่ระบบด้วย Google" (`WelcomeScreen`) — ปัจจุบันเป็น
   ตัวหนังสือล้วน ไม่มีไอคอนเลย ต้องใช้ asset ตาม [Google Identity branding
   guideline](https://developers.google.com/identity/branding-guidelines) จริง (โลโก้ "G" 4 สีทางการ) ห้าม
   วาดเลียนแบบเอง — ตรวจ repo แล้วไม่มี asset นี้อยู่ก่อน ต้องหา/เพิ่มใหม่ (SVG จาก official source หรือ npm
   package ที่ยี่ห้อ Google เผยแพร่เอง) ขนาด 18-20px วางซ้ายข้อความ เว้นระยะ ~10px
6. **[อนุมัติรอบ 6]** สลับลำดับปุ่มในหน้า `WelcomeScreen`: ย้ายปุ่ม "เข้าสู่ระบบ" มาไว้ **ก่อน** ปุ่ม
   "เข้าสู่ระบบด้วย Google" (เดิม Google อยู่ก่อน) — ตรวจโค้ดจริงว่ามีกี่จุด (state ปกติ / state
   `gate === "blocked"`) ที่ต้องสลับ
7. **[อนุมัติรอบ 8]** ขยายโลโก้ WYNOS: `WelcomeScreen` `height: 62` → **`110`**, `LoginScreen`
   `height: 46` → **`64`** (`width: "auto"` ทั้งคู่ ตามสัดส่วนไฟล์เดิม 660:426) — ใช้ไฟล์
   `/wynos_logo_mark.png` เดิม ไม่ใช่ไฟล์ใหม่

ส่งต่อ AI Coding: แก้ 7 จุดข้างต้น (ข้อ 1-2 เป็นค่าตัวเลขล้วนแก้ได้ตรงไปตรงมา, ข้อ 5 ต้องหา asset จริงของ
Google ก่อน), รัน visual/parity regression suite ที่มีอยู่แล้ว (ดู `.wyn/company/DECISIONS.md` งาน WYN-158
ก่อนหน้าที่ใช้ suite เดียวกันตรวจ CSS การ์ด) + screenshot ทั้ง 6 หน้าก่อน-หลังให้ Founder ดูก่อน merge/deploy
ขึ้น `WYNOS Web Beta1` — ต้องผ่าน QA ก่อน deploy เสมอ (ห้ามข้าม QA ตาม AGENTS.md) โดยเฉพาะเช็ค**ไม่ overflow
ที่หัวข้อ 32px บนจอแคบ 320px** และ**ปุ่ม/input ไม่ล้นเมื่อ textScale สูง**
