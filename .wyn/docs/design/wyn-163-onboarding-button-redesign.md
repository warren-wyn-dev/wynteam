# Design Spec — WYN-163: Onboarding Button Redesign (WYNOS Web)

Owner: AI Design → Founder review → AI Coding
Ref: Founder ขอเองผ่านข้อความตรง (2026-09-19): "เรามาช่วยกันออกแบบ UX UI ปุ่มต่างๆใหม่ เริ่มจาก0" → ยืนยัน
เป็นการเปลี่ยนทิศทาง visual จริง → "เราจะออกแบบใหม่หมดเลย เริ่มตั้งแต่เลือกสี ทุกอย่างใหม่หมด" → เริ่มจากหน้าจอ
Onboarding/Login → รอบ 3: "โทนสี ขาว ดำ เทา ธีมสว่าง" + ตัดปุ่ม "เข้าชม" ออก → **รอบ 4 (สำคัญ)**: "ตอนนี้มีแค่
Wynos Web Beta1 V.1.0.0 Beta4 พักไปก่อนยาวๆเลย" — **งานนี้ย้าย scope จากแอป Flutter มาเป็น WYNOS Web ทั้งหมด**
Artifact: https://claude.ai/artifact/Gq2encfg9hTqbrAHJ45o7x (อาร์ตบอร์ด 1-3 ทำไว้ตอน scope ยังเป็น Flutter —
ใช้เป็น reference ทิศทางสี/ทรง/การตัดปุ่มเข้าชมได้เหมือนเดิม ค่า token/ชื่อไฟล์เปลี่ยนเป็นของเว็บ)
Decision log: `.wyn/company/DECISIONS.md` (2026-09-19, WYN-163 รอบ 1-4), `.wyn/company/VERSION_CONTROL.md`,
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

ทำสิ่งที่ Founder ตัดสินใจไปแล้ว 3 รอบก่อนหน้า (สีขาว-ดำ-เทาล้วน, ทรงปุ่มโค้งมนปานกลาง 16px, ไม่มีปุ่ม
guest-browse) ให้เกิดขึ้นจริงบน **WYNOS Web** ซึ่งเป็นแพลตฟอร์มเดียวที่ยังพัฒนาต่อตอนนี้ (Flutter app พักยาว)

**ข่าวดี**: ตรวจโค้ดจริงแล้วพบว่า **สีของปุ่มเว็บตอนนี้ตรงกับทิศทางที่ Founder เลือกอยู่แล้ว 100%** —
`.btn-primary` ใช้ `background: var(--text-primary)` ซึ่ง alias ไปที่ `var(--wyn-text)` (สีเข้ม/ดำ) และ
`color: var(--bg)` (ขาว) อยู่แล้ว ไม่มีสีที่สามปนอยู่เลยนอกจาก `--red: var(--wyn-accent)` ที่ใช้เฉพาะ error
text (`ErrorText` component) ไม่ได้ใช้กับปุ่ม — **งานนี้จึงไม่ต้องแก้สีเลย** สิ่งที่ต้องแก้จริงมีแค่ **ทรงปุ่ม**
(ตอนนี้ยังเป็น pill เต็ม `border-radius: 999px` ต้องเปลี่ยนเป็น 16px ตามที่ตัดสินใจไว้) และปุ่ม guest-browse
ก็**ไม่มีอยู่แล้ว**ในหน้า Welcome ของเว็บ (มีแค่ "สร้างบัญชีใหม่" / "เข้าสู่ระบบด้วย Google" / "เข้าสู่ระบบ")
ดังนั้นข้อตัดสินใจ "ตัดปุ่มเข้าชมออก" ไม่มีผลอะไรต้องแก้ในเว็บ

## User Flow

ไม่เปลี่ยน — ทุกปุ่มนำทาง/เรียก action เดิมทุกประการ งานนี้เป็น visual only (แก้ CSS ไฟล์เดียว)

## Components

ปุ่มทั้งหมดในระบบมี 2 ระดับความสำคัญเท่านั้น (เว็บใช้ 2 คลาสอยู่แล้ว ไม่มีปุ่ม text/tertiary สีแยกแบบที่เคย
ออกแบบไว้ฝั่ง Flutter เพราะหน้าเว็บไม่มีปุ่ม "ส่งรหัสอีกครั้ง"/OTP แบบเดียวกัน — ฝั่งเว็บ auth ใช้ email/password
ไม่ใช้ OTP):

1. **Primary** (`.btn-primary`) — "สร้างบัญชีใหม่", "ดำเนินการต่อ", "หน้าถัดไป", "สร้างบัญชี", "เข้าสู่ระบบ",
   "เริ่มใช้งาน Wynos", "ส่งลิงก์รีเซ็ตรหัสผ่าน"
   - พื้น `var(--text-primary)` (ดำ), ตัวหนังสือ `var(--bg)` (ขาว) — **สีเดิมถูกต้องแล้ว ไม่แตะ**
   - **[แก้]** `border-radius: 999px` → **`16px`**
2. **Outline** (`.btn-outline`) — "เข้าสู่ระบบด้วย Google", "เข้าสู่ระบบ" (ปุ่มรองในหน้า Welcome)
   - โปร่งใส + ขอบ `var(--border-strong)` + ตัวหนังสือ `var(--text-primary)` — **สีเดิมถูกต้องแล้ว ไม่แตะ**
   - **[แก้]** `border-radius: 999px` → **`16px`**
   - **[อนุมัติแก้ในรอบนี้]** ปุ่มนี้ในโค้ดปัจจุบันเป็นแค่ตัวหนังสือล้วน ไม่มีโลโก้/ไอคอน Google เลยแม้แต่น้อย
     (ต่างจากฝั่ง Flutter ที่อย่างน้อยยังมีไอคอนเปล่า) — Founder อนุมัติให้เพิ่มโลโก้ทางการพร้อมกันในรอบนี้
     (ดูรายละเอียด asset ที่ Handoff)

ทั้งสองคลาสกำหนดขนาดร่วมกันอยู่แล้วที่ `height: 50px` (ผ่าน touch target ≥44px อยู่แล้ว ไม่ต้องแก้)

## Interactions

ไม่เปลี่ยน — `onClick`, `disabled` ระหว่าง loading, validation ของแต่ละหน้าจอยังทำงานเหมือนเดิมทุกประการ CSS
ปัจจุบันตั้งใจปิด transform บน hover/active (`transform: none`) ไว้อยู่แล้ว — **ไม่เพิ่ม motion/animation ใหม่
ในรอบนี้** (นอกขอบเขตที่ Founder ขอ ซึ่งคือสี+ทรงเท่านั้น)

## States

| State | Primary | Outline |
|---|---|---|
| Default | พื้นดำ ตัวหนังสือขาว | โปร่งใส ขอบเข้ม ตัวหนังสือดำ |
| Disabled | พึ่งพฤติกรรม native ของ `<button disabled>` (เดิมไม่มี custom style — คงเดิม ไม่ใช่ scope งานนี้) | เหมือนกัน |
| Hover/Active | ไม่มีการเปลี่ยนภาพ (ตั้งใจ `transform: none` ไว้แล้วในโค้ดเดิม) | เหมือนกัน |

ไม่มีปุ่มไหนสื่อสารสถานะด้วยสีอย่างเดียว — ทุกปุ่มมีข้อความ label ของตัวเองอยู่แล้ว

## Responsive Behavior

ไม่กระทบ — ปุ่มกว้างเต็ม container (`width: 100%`) ของ `.phone` viewport อยู่แล้ว ไม่มี breakpoint แยก
(WYNOS Web ออกแบบมาสำหรับหน้าจอมือถือเป็นหลักอยู่แล้วตาม `wynos-web-base-design-system.md`)

## Accessibility

- Touch target: สูง 50px เกินเกณฑ์ขั้นต่ำ 44px อยู่แล้ว ไม่ต้องแก้
- Contrast: ตัวหนังสือขาวบนพื้นดำ (`--text-primary`) และตัวหนังสือดำบนพื้นขาวโปร่งใส — ทั้งคู่เป็นคู่สีเดิมที่
  ผ่าน AA อยู่แล้วจาก `--wyn-*` token system (ไม่ได้เปลี่ยนค่าสี จึงไม่มี contrast ใหม่ต้องตรวจ)
- การเปลี่ยน `border-radius` เพียงอย่างเดียวไม่กระทบ semantics/keyboard focus/screen reader ที่มีอยู่แล้ว

## Design Rules

1. **[ยืนยันแล้ว ไม่ต้องแก้]** สีปุ่มทั้งระบบเว็บเป็นขาว-ดำ-เทาล้วนอยู่แล้ว (ดำ=`--text-primary`,
   ขาว=`--bg`, เทา=`--text-secondary`/`--text-muted`/`--border-strong`) แดง (`--red`) สงวนไว้เฉพาะ error
   text เท่านั้น ตรงกับที่ Founder ยืนยัน "โทนสี ขาว ดำ เทา ธีมสว่าง" เป๊ะอยู่แล้ว
2. **[แก้]** ทรงปุ่มทุกประเภท: `border-radius: 999px` → **`16px`** ในไฟล์ `web/app/auth-reference.css`
   (2 selector: `.auth-ref-viewport .btn-primary, .auth-ref-viewport .btn-outline`)
3. ปุ่ม guest-browse ไม่มีอยู่ในเว็บ — ไม่ต้องทำอะไรเพิ่มสำหรับข้อนี้
4. งานนี้แก้เฉพาะไฟล์ `auth-reference.css` (ขอบเขต Onboarding/Auth เท่านั้น) — ไม่ไล่แก้ `border-radius` ของ
   ปุ่มหน้าจออื่นของเว็บ (Home/Feed/Profile ฯลฯ) จากเอกสารนี้ ถ้าจะขยายทั้งเว็บต้องเป็นงานแยก
5. **แอป Flutter (`app/`) ไม่แตะเลยในรอบนี้** ตามคำสั่ง Founder พักงาน Flutter ยาว — งาน spec เดิมที่เคยเขียน
   ไว้สำหรับ Flutter (เวอร์ชันก่อนหน้าของเอกสารนี้) เก็บไว้เป็น reference ในกรณีที่ Founder สั่งกลับมาทำ
   Flutter ต่อในอนาคตเท่านั้น

## Handoff

**อนุมัติแล้ว (2026-09-19 รอบ 5) — พร้อมส่ง AI Coding**:

1. **[อนุมัติ]** แก้ `web/app/auth-reference.css`: `.btn-primary`/`.btn-outline` `border-radius: 999px` →
   `16px` (จุดเดียว ครอบคลุมทั้ง 6 หน้าจอ Onboarding ของเว็บทันที)
2. **[อนุมัติ — เพิ่มสโคป]** เพิ่มโลโก้ Google ทางการในปุ่ม "เข้าสู่ระบบด้วย Google"
   (`web/components/auth-flow/screens.tsx`, `WelcomeScreen`) — ปัจจุบันเป็นตัวหนังสือล้วน ไม่มีไอคอนเลย
   ต้องใช้ asset ตาม [Google Identity branding
   guideline](https://developers.google.com/identity/branding-guidelines) จริง (โลโก้ "G" 4 สีทางการ) ห้าม
   วาดเลียนแบบเอง/ใช้ไอคอนเปล่าแทน — ตรวจ repo แล้วไม่มี asset นี้อยู่ก่อน ต้องหา/เพิ่มใหม่ (SVG จาก official
   source หรือ npm package ที่ยี่ห้อ Google เผยแพร่เอง) ขนาดไอคอนแนะนำ 18-20px วางซ้ายข้อความ เว้นระยะจาก
   ข้อความ ~10px สีพื้นปุ่ม/ขอบ/ตัวหนังสือ "เข้าสู่ระบบด้วย Google" ยังใช้ `.btn-outline` เดิม (ดำ/ขาว/เทา) ตาม
   Design Rule เดิม — เปลี่ยนแค่เพิ่มไอคอนโลโก้เข้าไป ไม่เปลี่ยนสี/ทรงปุ่มทั้งก้อนให้เป็นสีของ Google

ส่งต่อ AI Coding: แก้ 2 จุดข้างต้น, รัน visual/parity regression suite ที่มีอยู่แล้ว (ดู
`.wyn/company/DECISIONS.md` งาน WYN-158 ก่อนหน้าที่ใช้ suite เดียวกันตรวจ CSS การ์ด) + screenshot ทั้ง 6
หน้าก่อน-หลังให้ Founder ดูก่อน merge/deploy ขึ้น `WYNOS Web Beta1` — ต้องผ่าน QA ก่อน deploy เสมอ (ห้ามข้าม
QA ตาม AGENTS.md)
