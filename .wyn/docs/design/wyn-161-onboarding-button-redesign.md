# Design Spec — WYN-161: Onboarding Button + Color Redesign

Owner: AI Design → Founder review → AI Coding
Ref: Founder ขอเองผ่านข้อความตรง (2026-09-19): "เรามาช่วยกันออกแบบ UX UI ปุ่มต่างๆใหม่ เริ่มจาก0" → ยืนยัน
เป็นการเปลี่ยนทิศทาง visual จริง (ไม่ใช่แค่จัดระเบียบแบบ WYN-106) → "เราจะออกแบบใหม่หมดเลย เริ่มตั้งแต่เลือกสี
ทุกอย่างใหม่หมด" → เริ่มจากหน้าจอ Onboarding/Login ตามที่ Founder ระบุ → รอบ 3: "โทนสี ขาว ดำ เทา ธีมสว่าง"
+ สั่งตัดปุ่ม "เข้าชม WYNOS ได้เลย" ออก → **ผลสุดท้าย: ไม่มีสีแดง/สีอื่นเลย เป็นขาว-ดำ-เทาล้วน**
Artifact: https://claude.ai/artifact/Gq2encfg9hTqbrAHJ45o7x (อาร์ตบอร์ด 1 = สี, อาร์ตบอร์ด 2 = ทรง, อาร์ตบอร์ด
3 = งานจริงทั้ง 5 หน้าจอ)
Decision log: `.wyn/company/DECISIONS.md` (2026-09-19, WYN-161, รอบ 1-3)

> **นี่คือ visual direction ใหม่ที่ Founder ร้องขอเอง** ไม่ขัดกับกติกา "ห้ามคิดทิศทาง visual ใหม่หากมี design
> system ที่อนุมัติแล้ว" เพราะ Founder เป็นฝ่ายเปิดคำขอเองตามข้อยกเว้นที่บันทึกไว้ 2026-09-07 ("ไม่ต้องเสนอ
> visual ใหม่จนกว่า Founder จะร้องขอเอง")

---

## Screen

`WelcomeScreen`, `AuthMethodScreen`, `PhoneEntryScreen`, `OtpVerificationScreen`, Username Setup step
(`app/lib/features/auth/presentation/**`) — ตาม WYN-002 ทั้ง 5 หน้าจอ

## Purpose

เปลี่ยนสี + ทรงปุ่มของหน้า Onboarding ทั้งหมดตามทิศทางใหม่ที่ Founder เลือก แทนที่ sapphire (บทบาทปุ่มหลัก)
ด้วย **ink ล้วน** (ไม่มีสีแดง/สีอื่นแล้ว ตามที่ Founder ยืนยัน "ขาว ดำ เทา ธีมสว่าง" รอบ 3) และเปลี่ยนทรงปุ่ม
จาก pill เต็ม (M3 default) เป็น rounded-rect 16px — เป็นจุดเริ่มของ button system ใหม่ทั้ง WYNOS (หน้าจอ
ถัดไปจะตามมาทีหลัง คนละรอบ)

## User Flow

ไม่เปลี่ยน — ทุกปุ่มนำทาง/เรียก action เดิมทุกประการ (Welcome → Auth Method → Google/Apple/Email หรือ
Phone → OTP → Username Setup → Home) งานนี้เป็น visual only

## Components

ปุ่มทั้งหมดที่ปรากฏใน 5 หน้าจอ แบ่งเป็น 4 ระดับความสำคัญ (คงโครงสร้าง 3 ระดับของ WYN-106 ไว้ + เพิ่ม 1 ระดับ
สำหรับปุ่ม text รอง เช่น "ส่งรหัสอีกครั้ง"):

> **[เปลี่ยนรอบ 3]** ปุ่ม "เข้าชม WYNOS ได้เลย" (guest browsing) **ตัดออกจากการออกแบบนี้ทั้งหมดตามคำสั่ง
> Founder** — ไม่อยู่ใน 4 ระดับด้านล่างอีกต่อไป โค้ดจริงยังปิดอยู่ด้วย flag `_guestBrowsingEnabled = false`
> เดิม (DECISIONS.md 2026-09-08) เอกสารนี้ไม่ได้สั่งลบ widget/flag ออกจากซอร์ส — เป็นแค่การไม่รวมอยู่ในระบบ
> ปุ่มใหม่ ถ้าต้องการลบโค้ดทิ้งจริงต้องแยกเป็นการตัดสินใจอีกครั้ง

1. **Primary CTA** (Filled) — "เริ่มต้นใช้งาน", "ส่งรหัส OTP", "เสร็จสิ้น", "กรอกโค้ดเชิญ"
   - พื้น `ink #12120F` เต็ม, ตัวหนังสือ `paper #FFFFFF`, `border-radius: 16px`, สูง 52px, เต็มความกว้าง
2. **Secondary Filled-outline** — "เข้าสู่ระบบด้วย Google" (และ Apple เมื่อเปิดใช้อีกครั้ง)
   - ขอบ 1.5px `ink`, พื้น `paper`, ตัวหนังสือ `ink`, `border-radius: 16px`, สูง 46-48px
   - **หมายเหตุสำคัญ**: ปุ่มนี้ในโค้ดปัจจุบัน (`auth_method_screen.dart`) ยังไม่ใช้ asset ทางการของ Google
     (`Icons.g_mobiledata` ธรรมดา) — ขัดกับ Design Rule เดิมของ WYN-002 ("ห้ามดัดแปลงโลโก้/สีปุ่ม Google/
     Apple เอง ต้องใช้ asset ทางการ") เป็น gap ที่มีอยู่ก่อนงานนี้ ไม่ใช่สิ่งที่ WYN-161 สร้างขึ้นใหม่ — บันทึก
     ไว้เป็นข้อสังเกตแยก ให้ Founder ตัดสินใจว่าจะแก้พร้อมกันในรอบนี้หรือแยกเป็นงานอื่น (ดู Handoff)
3. **Outline (tertiary)** — "เข้าสู่ระบบด้วยอีเมล", "ใช้เบอร์โทรศัพท์แทน"
   - ขอบ 1.5px `hairline #E8E6E0` (จางกว่าระดับ 2 เพื่อให้ลำดับสำคัญต่างกันชัด), พื้น `paper`, ตัวหนังสือ
     `ink`, `border-radius: 16px`, สูง 46-48px
4. **Text (quiet)** — "ส่งรหัสอีกครั้ง" (เมื่อ countdown หมด)
   - ไม่มีพื้น/ขอบ, ตัวหนังสือ **`graphite #8A8880`** (เทา — **[เปลี่ยนรอบ 3]** เดิมเสนอสีแดง `#E11D48` เป็น
     signal accent แต่ Founder ยืนยันธีมขาว-ดำ-เทาล้วน จึงตัดสีแดงออกทั้งระบบปุ่มนี้) น้ำหนัก 600, สูงที่เห็น
     36-40px แต่ขยาย hit-area โปร่งใสให้ครบ ≥44px เสมอ (pattern เดียวกับ `action_metric.dart`) — ตอน
     countdown ยังไม่หมด (`disabled`) ใช้ `faint #C7C4BC`

## Interactions

ไม่เปลี่ยนจากเดิม — `onPressed`/`onTap`, disable ระหว่าง `_isLoading`, debounce/validation ของแต่ละหน้าจอ
ยังทำงานเหมือนเดิมทุกประการ กด primary/secondary/outline ค้างจะย่อ scale 0.94 ตาม `WynMotion.pressedScale`
ที่มีอยู่แล้ว (DS-010) — ไม่สร้าง motion token ใหม่

## States

| State | Primary | Secondary/Outline | Text |
|---|---|---|---|
| Default | พื้น ink, ตัวหนังสือ paper | ขอบ+ตัวหนังสือตามระดับ | ตัวหนังสือ graphite |
| Pressed | scale 0.94 (DS-010 เดิม) | scale 0.94 | opacity 0.7 |
| Disabled (`_isLoading`/validation ไม่ผ่าน) | พื้น ink @ 38% opacity, ตัวหนังสือ paper @ 70% | ขอบ+ตัวหนังสือ @ 38% opacity | ตัวหนังสือ @ 38% opacity |
| Loading | แทนข้อความด้วย spinner ขนาด 18px สี paper อยู่กึ่งกลางปุ่ม (ปุ่มคงขนาดเดิม ไม่ยุบ) | เหมือน primary แต่สี ink | ไม่มี (ปุ่ม text ไม่มี loading state ของตัวเอง — ใช้ spinner กลางจอเดิมของ `AuthMethodScreen`) |

ไม่มีปุ่มไหนสื่อสารสถานะด้วยสีอย่างเดียว — ทุกปุ่มยังมีข้อความ/label ชัดเจนตามเดิม (ตรง DS-001 ข้อ 5)

## Responsive Behavior

ไม่กระทบ — px คงที่ทุกจอมือถือ (มาตรฐานเดียวกับ DS-008) ปุ่ม primary ยังเต็มความกว้างจอ (minus margin) และ
ขยับตามคีย์บอร์ดเหมือนเดิมในหน้า Phone Entry/Username

## Accessibility

- Touch target ทุกปุ่ม ≥44×44px จริง (ปุ่ม text ขยาย hit-area โปร่งใส) — ตรวจซ้ำด้วย widget test แบบ
  WYN-106
- Contrast: paper บน ink = **19.7:1 ✅**, ink บน paper (secondary/outline) = **19.7:1 ✅**, graphite
  `#8A8880` บน paper (ปุ่ม text) = **4.83:1 ✅** ผ่านเกณฑ์ตัวหนังสือปกติ (ค่าเดียวกับที่ DS-001 ยืนยันไว้แล้ว)
- `Semantics(label:..., button:true)` ทุกปุ่มที่ tappable เหมือนเดิม (ไม่แตะ)
- รองรับ textScale 130% เหมือนเดิม (ปุ่ม primary สูง 52px มีเนื้อที่พอสำหรับข้อความขยาย ไม่ overflow ในกรณี
  ทดสอบเบื้องต้น — QA ต้องตรวจซ้ำจริงตอน implement)

## Design Rules

1. สีปุ่มหลักทั้งระบบ (ไม่ใช่แค่ Onboarding): พื้น `ink #12120F` แทนที่ `sapphire` ในบทบาท "ปุ่มหลัก" — แต่
   งานนี้ **แก้เฉพาะ 5 หน้าจอ Onboarding เท่านั้น** หน้าจออื่น (Home ฯลฯ) ยังใช้ sapphire เดิมจนกว่าจะมีงาน
   ขยายขอบเขตแยกต่างหาก (ห้าม AI Coding ไล่แก้ทั้งแอปเองจากเอกสารนี้)
2. **[เปลี่ยนรอบ 3]** ไม่มีสีที่สามในระบบปุ่มนี้เลย — ขาว (`paper`) / ดำ (`ink`) / เทา (`graphite`,
   `hairline`, `faint`) เท่านั้น ตามที่ Founder ยืนยัน "โทนสี ขาว ดำ เทา ธีมสว่าง" (สีแดง `#E11D48` ที่เคย
   เสนอไว้ก่อนหน้าถูกตัดออกทั้งหมด — สีแดงยังคงความหมาย "ผิดพลาด/destructive"/หัวใจ Like ในจุดอื่นของแอป
   เหมือนเดิม เพียงแต่ไม่ถูกใช้ในระบบปุ่ม Onboarding นี้)
2b. ปุ่ม "เข้าชม WYNOS ได้เลย" ตัดออกจากขอบเขตการออกแบบนี้ทั้งหมด (ดู Components หัวข้อ 4)
3. ทรงปุ่มทุกประเภทในขอบเขตนี้ = `border-radius: 16px` แทน pill เต็ม
4. ปุ่ม Google/Apple ที่ต้องใช้ asset ทางการ — สีพื้น/โลโก้ของปุ่มนั้นเองยังคงตาม official guideline (ไม่ใช้
   ink) เปลี่ยนได้แค่กรอบ/รัศมีมุมของ container รอบนอกถ้ามี ไม่แตะตัว asset
5. ห้ามเพิ่มประเภทปุ่มที่ 5 นอกเหนือ 4 ระดับข้างต้นโดยไม่ทวนกับ Founder ก่อน (คงหลักการเดียวกับ WYN-106 ข้อ
   1)

## Handoff

**ยังไม่ส่ง AI Coding** — รอ Founder ยืนยัน 2 เรื่องนี้ก่อน (ถามในข้อความถัดไป):

1. อนุมัติ spec นี้ทั้งหมด (สีขาว-ดำ-เทาล้วน, ทรง 16px, ขนาด, states, ตัดปุ่ม "เข้าชม" ออก) ให้ส่ง AI Coding
   แก้ 5 หน้าจอ Onboarding ได้เลยหรือไม่
2. ปุ่ม Google ที่ยังไม่ใช้ asset ทางการ (พบระหว่างเขียน spec นี้ ไม่ใช่สิ่งที่ WYN-161 สร้างใหม่) — อยากให้
   แก้พร้อมกันในรอบนี้ หรือแยกเป็น task ใหม่ทำทีหลัง

เมื่ออนุมัติแล้ว ส่งต่อ AI Coding: แก้ theme-level button style (`app/lib/core/design/wyn_theme.dart` — เพิ่ม
`FilledButtonThemeData`/`OutlinedButtonThemeData`/`TextButtonThemeData` ที่ยังไม่มีอยู่ก่อน) + ปุ่ม
`FilledButton`/`OutlinedButton`/`TextButton` ใน 5 ไฟล์ Onboarding ให้ตรงตาม spec, เพิ่ม/แก้ widget test
ยืนยัน touch target ≥44px และสี, `flutter analyze` + `flutter test` ต้องผ่านครบไม่มี regression ก่อนเข้า QA
