# Design Task — WYN-163

Status: review (spec เต็มเขียนเสร็จแล้ว รอ Founder อนุมัติก่อนส่ง AI Coding)
Owner: AI Design
Screen: Onboarding/Auth ของ **WYNOS Web** (`web/app/(auth-flow)/**`, component จริงที่
`web/components/auth-flow/screens.tsx`) — `WelcomeScreen`, `LoginScreen`, `SignupStep1Screen`,
`SignupStep2Screen`, `OnboardingProfileScreen`, `ForgotPasswordScreen`
Purpose: ทำสี+ทรงปุ่มที่ Founder ตัดสินใจไปแล้ว (ขาว-ดำ-เทาล้วน, โค้งมนปานกลาง 16px, ไม่มีปุ่ม guest-browse)
ให้เกิดจริงบน WYNOS Web (แพลตฟอร์มเดียวที่พัฒนาต่อตอนนี้ — ดู DECISIONS.md รอบ 4/VERSION_CONTROL.md)
User Flow: ไม่เปลี่ยน — ทุกปุ่มยังทำงาน/ไปหน้าเดิมทุกประการ งานนี้คือ visual only แก้ CSS ไฟล์เดียว
Components: ปุ่ม Primary (`.btn-primary`: สร้างบัญชีใหม่/ดำเนินการต่อ/หน้าถัดไป/สร้างบัญชี/เข้าสู่ระบบ/
เริ่มใช้งาน Wynos/ส่งลิงก์รีเซ็ตรหัสผ่าน), ปุ่ม Outline (`.btn-outline`: เข้าสู่ระบบด้วย Google, เข้าสู่ระบบ)
— ประกาศรวมอยู่ไฟล์เดียว `web/app/auth-reference.css` ไม่มีปุ่ม guest-browse ในเว็บอยู่แล้ว (ต่างจาก Flutter)
Interactions: ไม่เปลี่ยน — ไม่เพิ่ม motion/animation ใหม่ (นอกขอบเขตที่ Founder ขอ)
States: Default/Disabled/Hover-Active คงพฤติกรรมเดิมทั้งหมด (CSS เดิมตั้งใจปิด transform บน hover/active
อยู่แล้ว) — งานนี้ไม่แตะ state ใหม่
Responsive Behavior: ไม่กระทบ (เว็บออกแบบมือถือเป็นหลักอยู่แล้ว, ปุ่มกว้างเต็ม container)
Accessibility: touch target สูง 50px เกินเกณฑ์ 44px อยู่แล้ว, contrast ขาว/ดำเดิมผ่าน AA อยู่แล้ว (ไม่เปลี่ยน
ค่าสี จึงไม่มี contrast ใหม่ต้องเช็ค) — แก้แค่ `border-radius` ไม่กระทบ semantics/focus
Design Rules:
1. **[ยืนยันแล้ว ไม่ต้องแก้]** สีปุ่มเว็บทั้งระบบเป็นขาว-ดำ-เทาล้วนอยู่แล้วในโค้ดจริง (`--text-primary`/
   `--bg`/`--border-strong` alias ไปที่ `--wyn-*` tokens) ตรงกับที่ Founder ยืนยัน "โทนสี ขาว ดำ เทา ธีมสว่าง"
   เป๊ะอยู่แล้ว ไม่มีสีที่สามปนอยู่ (`--red` สงวนไว้เฉพาะ error text)
2. **[ต้องแก้]** ทรงปุ่ม: `border-radius: 999px` → **`16px`** ใน `web/app/auth-reference.css` (จุดเดียว
   ครอบคลุมทั้ง 6 หน้าจอ)
3. ปุ่ม guest-browse ไม่มีอยู่แล้วในเว็บ — ไม่ต้องทำอะไรเพิ่มสำหรับข้อนี้
4. ขอบเขตงานนี้ = ไฟล์ `auth-reference.css` (Onboarding/Auth เท่านั้น) ไม่ไล่แก้ปุ่มหน้าจออื่นของเว็บ
5. **แอป Flutter (`app/`) ไม่แตะเลยในรอบนี้** ตามคำสั่ง Founder พักงาน Flutter ยาว (DECISIONS.md 2026-09-19
   รอบ 4) — สเปกเวอร์ชันก่อนหน้าที่เขียนไว้สำหรับ Flutter เก็บเป็น reference เผื่อ Founder สั่งกลับมาทำต่อ
6. จุดอื่นที่ sapphire/ink เคยทำหน้าที่นอกปุ่ม (ฝั่ง Flutter: avatar ring, active tab ฯลฯ) ไม่เกี่ยวกับงานนี้
   เพราะเว็บใช้ token คนละชุด (`--wyn-*`) อยู่แล้ว
Handoff: spec เต็มเขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-163-onboarding-button-redesign.md` — ยังไม่ส่ง
AI Coding จนกว่า Founder จะตอบ 2 ข้อในหัวข้อ Handoff ของเอกสารนั้น (อนุมัติแก้ `border-radius` / จะเพิ่มโลโก้
Google จริงพร้อมกันไหม)

Artifact (canvas เดียว ใช้ต่อเนื่องทุกรอบ — ทำไว้ตอน scope ยังเป็น Flutter แต่ทิศทางสี/ทรง/การตัดปุ่มเข้าชม
ยังใช้อ้างอิงได้เหมือนเดิม): https://claude.ai/artifact/Gq2encfg9hTqbrAHJ45o7x

## Log

- 2026-09-19 รอบ 1: เสนอ 4 ทิศทางสี (Coral/Emerald/Violet/Ink+Red) พร้อม contrast จริง — Founder เลือก
  **D (Ink Mono + Red Signal)** บันทึกที่ `.wyn/company/DECISIONS.md` วันเดียวกัน
- 2026-09-19 รอบ 2: เสนอ 3 ทรงปุ่มบนสี D ที่เลือกแล้ว (pill / rounded-rect 16px / เหลี่ยม 8px) — Founder
  เลือก **"2" (โค้งมนปานกลาง 16px)**
- 2026-09-19: ทำ mockup งานจริงทั้ง 5 หน้าจอ Flutter (อาร์ตบอร์ด 3) ตามคำขอ "ขอดูงานจริง"
- 2026-09-19 รอบ 3: Founder ยืนยัน "โทนสี ขาว ดำ เทา ธีมสว่าง" + สั่งตัดปุ่ม "เข้าชม WYNOS ได้เลย" ออก →
  ยกเลิกสีแดงทั้งระบบปุ่มนี้
- แก้เลขงานจาก WYN-161 → **WYN-163** (ชนกับงานอื่นที่มีอยู่แล้วในระบบ — ดู DECISIONS.md)
- 2026-09-19 รอบ 4 (สำคัญ): Founder สั่ง "ตอนนี้มีแค่ Wynos Web Beta1 V.1.0.0 Beta4 พักไปก่อนยาวๆเลย" —
  **ย้าย scope งานนี้ทั้งหมดจากแอป Flutter มาเป็น WYNOS Web** ตรวจโค้ดเว็บจริงพบว่าสีตรงกับที่ตัดสินใจไว้แล้ว
  100% (ไม่ต้องแก้สี) เหลือแก้แค่ `border-radius` จุดเดียวใน `web/app/auth-reference.css` และไม่มีปุ่ม
  guest-browse ในเว็บอยู่แล้วจึงไม่ต้องแก้เรื่องนั้น — เขียน spec ใหม่ให้ตรง scope เว็บแล้ว
- ถัดไป: รอ Founder ยืนยัน 2 ข้อใน Handoff (อนุมัติแก้ border-radius / โลโก้ Google) ก่อนส่ง AI Coding
