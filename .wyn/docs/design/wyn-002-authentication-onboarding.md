# Design Spec — WYN-002: Authentication & Onboarding

อ้างอิง Design Principles: `.wyn/docs/design/design-principles.md`
อ้างอิง Product Spec: `.wyn/tasks/active/WYN-002-authentication-onboarding.md`

---

## Screen 1: Welcome

Purpose: หน้าแรกที่ผู้ใช้เห็นเมื่อเปิดแอปครั้งแรก (ยังไม่ login) แนะนำ WYN สั้น ๆ และพาไปสมัคร/เข้าสู่ระบบ

User Flow: เปิดแอป → เห็น Welcome screen → กด "เริ่มต้นใช้งาน" → ไป Screen 2 (Auth Method)

Components: Logo/App name, headline สั้น 1 บรรทัด (สื่อ Vision แบบเข้าใจง่าย), ปุ่ม Primary "เริ่มต้นใช้งาน"

Interactions: กดปุ่มเดียวเพื่อไปต่อ ไม่มี form ในหน้านี้

States: Default เท่านั้น (ไม่มี loading/error เพราะไม่มีการเรียก API)

Responsive Behavior: จัดกึ่งกลางแนวตั้ง ปุ่ม primary anchor ด้านล่างจอเสมอ รองรับความสูงจอที่ต่างกัน (จอเล็ก/จอใหญ่)

Accessibility: Headline และปุ่มต้องมี label ชัดเจนสำหรับ screen reader contrast ผ่าน AA

Design Rules: ใช้ primary color จาก `design-principles.md` เป็นพื้นหลังปุ่มหลักเท่านั้น ไม่ใช้เป็นพื้นหลังเต็มจอ (ลดความล้าสายตา)

Handoff: AI Coding — ทำเป็น stateless widget ไม่ต้องเชื่อม Supabase

---

## Screen 2: Auth Method Selection

Purpose: ให้ผู้ใช้เลือกวิธีสมัคร/เข้าสู่ระบบ

User Flow: จาก Welcome → เลือก "Sign in with Google" หรือ "Sign in with Apple" หรือ "ใช้เบอร์โทรศัพท์" → ไป flow ตามที่เลือก (Google/Apple ไป Screen 5 ทันทีถ้าสำเร็จ, เบอร์โทรไป Screen 3)

Components: ปุ่ม Social Login Google (asset ตามมาตรฐาน Google), ปุ่ม Social Login Apple (asset ตามมาตรฐาน Apple — บังคับตาม Apple Human Interface Guidelines), ปุ่ม secondary "ใช้เบอร์โทรศัพท์แทน", ข้อความ Terms/Privacy แบบย่อด้านล่าง

Interactions: กดปุ่มใดปุ่มหนึ่งเพื่อเริ่ม flow นั้น ปุ่มอื่นถูก disable ชั่วคราวระหว่างรอผล (prevent double-tap)

States:
- Default
- Loading (ระหว่างรอ OAuth popup/redirect ตอบกลับ)
- Error (เช่น ผู้ใช้ยกเลิก OAuth, เครือข่ายมีปัญหา) → แสดง inline error พร้อมปุ่มลองใหม่

Responsive Behavior: ปุ่มเรียงแนวตั้ง เต็มความกว้างจอ (minus margin) ใช้ได้ทั้งจอแคบ/กว้าง

Accessibility: ปุ่ม Social Login ต้องมี label เต็ม ("เข้าสู่ระบบด้วย Google") ไม่ใช่แค่ icon สำหรับ screen reader

Design Rules: ห้ามดัดแปลงโลโก้/สีของปุ่ม Google และ Apple เอง ต้องใช้ตาม official guideline ของแต่ละเจ้า

Handoff: AI Coding — เชื่อม Supabase Auth (Google OAuth provider, Apple OAuth provider) ตามที่อนุมัติใน WYN-002

---

## Screen 3: Phone Number Entry

Purpose: ให้ผู้ใช้กรอกเบอร์โทรศัพท์เพื่อรับ OTP

User Flow: จาก Screen 2 (เลือก "ใช้เบอร์โทรศัพท์") → กรอกเบอร์ → กด "ส่งรหัส OTP" → ไป Screen 4

Components: Country code selector (default +66), Text Input เบอร์โทร (ตัวเลขเท่านั้น), ปุ่ม Primary "ส่งรหัส OTP" (disabled จนกว่าเบอร์จะถูกต้องตามรูปแบบ)

Interactions: Real-time validation รูปแบบเบอร์ระหว่างพิมพ์ กดปุ่มแล้วเข้าสู่ state Loading ทันที

States:
- Default
- Invalid (เบอร์ผิดรูปแบบ) → inline error ใต้ input
- Loading (กำลังส่ง OTP)
- Error (ส่งไม่สำเร็จ เช่น rate limit) → inline error พร้อมคำแนะนำลองใหม่ภายหลัง

Responsive Behavior: Input เต็มความกว้าง คีย์บอร์ดตัวเลขเด้งอัตโนมัติ ปุ่ม primary ขยับตามคีย์บอร์ด (ไม่ถูกบัง)

Accessibility: Label "หมายเลขโทรศัพท์" ติดกับ input เสมอ ไม่ใช้แค่ placeholder เป็น label

Design Rules: ใช้ OTP Input component และ Text Input component ตาม `design-principles.md`

Handoff: AI Coding — เรียก Supabase Auth Phone OTP (signInWithOtp) แจ้ง Founder เรื่องต้นทุน SMS ต่อครั้งก่อน implement จริงตามที่ระบุใน WYN-002 Risks

---

## Screen 4: OTP Verification

Purpose: ให้ผู้ใช้กรอกรหัส OTP 6 หลักที่ได้รับทาง SMS เพื่อยืนยันตัวตน

User Flow: จาก Screen 3 → กรอก OTP 6 หลัก → ยืนยันอัตโนมัติเมื่อครบ 6 หลัก (ไม่ต้องกดปุ่มแยก) → สำเร็จไป Screen 5 (ถ้าเป็นผู้ใช้ใหม่) หรือเข้าแอปเลย (ถ้าเป็นผู้ใช้เดิม)

Components: OTP Input (6 ช่องแยก), Countdown timer สำหรับ "ส่งรหัสอีกครั้ง" (resend), ปุ่ม Text "ส่งรหัสอีกครั้ง" (active เมื่อ countdown หมด)

Interactions: Auto-submit เมื่อกรอกครบ 6 หลัก, auto-focus ช่องถัดไปเมื่อพิมพ์แต่ละหลัก

States:
- Default
- Loading (กำลังตรวจสอบ OTP)
- Error (OTP ผิด/หมดอายุ) → เคลียร์ช่อง input และแสดง error ชัดเจน
- Resend available / Resend on cooldown

Responsive Behavior: จัดกึ่งกลาง OTP boxes ปรับขนาดตามความกว้างจอ ไม่ overflow บนจอแคบ

Accessibility: แต่ละช่อง OTP ต้องประกาศลำดับ (เช่น "หลักที่ 1 จาก 6") สำหรับ screen reader

Design Rules: ใช้สี error ตาม `design-principles.md` เท่านั้น ไม่ประดิษฐ์สีใหม่

Handoff: AI Coding — เรียก Supabase Auth verifyOtp ตรวจสอบว่าเป็น user ใหม่หรือเก่า (ตาม Acceptance Criteria WYN-002: user เดิม login ซ้ำต้องไม่สร้าง account ซ้ำ)

---

## Screen 5: Username Setup (Onboarding)

Purpose: ผู้ใช้ใหม่ตั้งชื่อผู้ใช้ (username) ก่อนเข้าหน้าแรกของแอป ตามที่ WYN-002 กำหนดเป็น onboarding ขั้นต่ำ

User Flow: หลัง auth สำเร็จ (ผู้ใช้ใหม่เท่านั้น) → กรอก username → ระบบตรวจสอบว่าซ้ำหรือไม่แบบ real-time → กด "เสร็จสิ้น" → เข้าสู่แอป (หน้า Home — นอก scope ของ WYN-002)

Components: Text Input username (พร้อม prefix "@"), ข้อความ helper ("ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น"), ปุ่ม Primary "เสร็จสิ้น" (disabled จนกว่า username จะถูกต้องและไม่ซ้ำ)

Interactions: Debounced real-time check ว่า username ซ้ำหรือไม่ระหว่างพิมพ์ แสดง ✓ เมื่อใช้ได้

States:
- Default
- Checking (กำลังตรวจสอบ username ซ้ำ)
- Taken (username ถูกใช้แล้ว) → inline error
- Invalid format → inline error
- Valid → ปุ่มเปิดใช้งาน

Responsive Behavior: Input เต็มความกว้าง คีย์บอร์ดไม่บังปุ่ม primary

Accessibility: ประกาศผลการตรวจสอบ (ซ้ำ/ใช้ได้) ให้ screen reader ทราบทันทีที่เปลี่ยนแปลง (live region)

Design Rules: ใช้ pattern เดียวกับ Text Input ใน Screen 3 เพื่อความสม่ำเสมอ

Handoff: AI Coding — บันทึก username ลงตาราง profile ใน Supabase หลังยืนยันว่าไม่ซ้ำ แล้ว navigate เข้าแอป (Home เป็น placeholder จนกว่าจะมี feature ถัดไป)

---

## สรุป Flow รวม

```
Welcome → Auth Method Selection ─┬─ Google/Apple ──────────────┐
                                   └─ Phone → OTP Verification ──┤
                                                                  ├─ (ผู้ใช้ใหม่) → Username Setup → Home
                                                                  └─ (ผู้ใช้เดิม) → Home ทันที
```

## Handoff รวม
ส่งต่อ AI Coding (`/code`) เพื่อ implement 5 screens ข้างต้นด้วย Flutter ตาม Design Rules และเชื่อม Supabase Auth ตาม Product Spec ใน WYN-002 — ต้อง QA & Security ตรวจสอบก่อน deploy เสมอ (ห้ามข้าม QA)
