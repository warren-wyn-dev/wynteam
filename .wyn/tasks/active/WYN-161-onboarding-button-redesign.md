# Design Task — WYN-161

Status: review (spec เต็มเขียนเสร็จแล้ว รอ Founder อนุมัติก่อนส่ง AI Coding)
Owner: AI Design
Screen: Onboarding/Auth (WYN-002) — `WelcomeScreen`, `AuthMethodScreen`, `PhoneEntryScreen`,
`OtpVerificationScreen`, Username Setup step — จุดเริ่มต้นตามที่ Founder ระบุ ("เริ่มจากหน้าจอแรกสุด")
Purpose: ออกแบบสี + ระบบปุ่มของ WYNOS ใหม่ทั้งหมด ("ทุกอย่างใหม่หมด") ตามคำขอ Founder เอง (ไม่ใช่ AI Design
เสนอ visual ใหม่เอง — มีบันทึกยืนยันชัดเจนที่ `.wyn/company/DECISIONS.md` 2026-09-19 ว่า Founder เป็นฝ่าย
ร้องขอ ตามข้อยกเว้นที่บันทึกไว้ 2026-09-07)
User Flow: ไม่เปลี่ยน — ทุกปุ่มยังทำงาน/ไปหน้าเดิมทุกประการ งานนี้คือ visual only
Components: ปุ่ม Primary CTA ("เริ่มต้นใช้งาน"/"เสร็จสิ้น"/"ส่งรหัส OTP"), ปุ่ม Secondary (เข้าสู่ระบบด้วย
Google/Apple, ใช้เบอร์โทรศัพท์แทน), ปุ่ม Outline (เข้าสู่ระบบด้วยอีเมล), ปุ่ม Text/tertiary (เข้าชม WYNOS
ได้เลย, ส่งรหัสอีกครั้ง) — Google/Apple sign-in ใช้ asset ทางการของแต่ละเจ้า ไม่แตะสี/โลโก้ (Design Rule เดิม
ของ WYN-002 ยังบังคับใช้)
Interactions: ยังไม่กำหนด — รอเลือกทรง/ขนาดในรอบถัดไป (ปัจจุบันยังเป็น mockup ค่า contrast ล้วนๆ)
States: รอกำหนดต่อ (default/pressed/disabled/loading) หลังตกลงทรงปุ่ม
Responsive Behavior: ไม่กระทบ (mobile-first, px คงที่ ตาม DS-008)
Accessibility: ทุกสีที่เสนอเช็ค WCAG contrast แล้วก่อนนำเสนอ Founder (ดูรายละเอียดใน Artifact) — ต้องคง
touch target ≥44×44 ทุกปุ่มเหมือนเดิม
Design Rules:
1. **[ตัดสินใจแล้ว 2026-09-19]** สีปุ่มหลักทั้งระบบ: พื้น `ink #12120F` (ดำ) + ตัวหนังสือขาว/paper —
   แทนที่ sapphire `#1B3A6B` ในบทบาท "ปุ่มหลัก"
2. **[ตัดสินใจแล้ว]** สีแดง `#E11D48` (ค่าเดียวกับ `likeLight`) เป็น signal accent จุดเล็กๆ เท่านั้น (ลิงก์/
   ปุ่ม text รอง/badge) — ห้ามใช้เป็นพื้นปุ่มขนาดใหญ่
3. **[ตัดสินใจแล้ว 2026-09-19]** ทรงปุ่มทุกประเภท: `border-radius: 16px` (โค้งมนปานกลาง) แทนทรง pill เต็ม
   เดิม — ขนาดสูง: primary CTA 52px / secondary-outline 46-48px / text button 36-40px (ขยายพื้นที่กดโปร่งใส
   ให้ครบ ≥44px ทุกจุดตอนขึ้นโค้ดจริง ตามแบบ WYN-106)
4. **[ยังไม่ตัดสินใจ]** จุดอื่นที่ sapphire เคยทำหน้าที่อยู่นอกปุ่ม (avatar ring, active tab underline,
   verified badge, liked-heart) — คงไว้หรือเปลี่ยนตาม ink/red รอตรวจทีละจุดแยกจากงานนี้
5. ขอบเขตหน้าจอปัจจุบัน = Onboarding เท่านั้น ยังไม่ขยายไปหน้าอื่น (Home ที่ทำไปแล้วใน WYN-106 ฯลฯ) จนกว่า
   Founder จะสั่งขยาย
Handoff: spec เต็มเขียนเสร็จแล้วที่ `.wyn/docs/design/wyn-161-onboarding-button-redesign.md` (สี+ทรง+ขนาด+
states+accessibility ครบ) — ยังไม่ส่ง AI Coding จนกว่า Founder จะตอบ 2 ข้อในหัวข้อ Handoff ของเอกสารนั้น
(อนุมัติ spec / จะแก้ปุ่ม Google asset พร้อมกันไหม)

Artifact (canvas เดียว ใช้ต่อเนื่องทุกรอบ): https://claude.ai/artifact/Gq2encfg9hTqbrAHJ45o7x

## Log

- 2026-09-19 รอบ 1: เสนอ 4 ทิศทางสี (Coral/Emerald/Violet/Ink+Red) พร้อม contrast จริง — Founder เลือก
  **D (Ink Mono + Red Signal)** บันทึกที่ `.wyn/company/DECISIONS.md` วันเดียวกัน
- 2026-09-19 รอบ 2: เสนอ 3 ทรงปุ่มบนสี D ที่เลือกแล้ว (pill / rounded-rect 16px / เหลี่ยม 8px) — Founder
  เลือก **"2" (โค้งมนปานกลาง 16px)** บันทึกที่ `.wyn/company/DECISIONS.md` วันเดียวกัน
- ถัดไป: ยืนยัน states (default/pressed/disabled/loading) + จุดอื่นที่ sapphire เคยใช้อยู่ (avatar ring,
  active tab, verified badge, liked-heart) ว่าเปลี่ยนตามหรือคงไว้ แล้วสรุป spec เต็มก่อนส่ง AI Coding
