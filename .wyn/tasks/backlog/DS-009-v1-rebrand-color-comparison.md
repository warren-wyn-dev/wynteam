# Product Task — DS-009

Status: backlog — พร้อมส่ง AI Design
Owner: AI Product Manager → AI Design

Feature: WYN V1.0.0 Rebrand — เปรียบเทียบ Design System "80–90% White + 10–20% Rainbow" กับของเดิม (Cyan + Orange)

Goal: ให้ Founder เห็นตัวอย่างจริงก่อนตัดสินใจว่าจะเปลี่ยน Design System อีกครั้งหรือไม่ — Founder ระบุในสเปก WYN V1.0.0 (2026-08-22) ว่า WYN Brand ควรเป็น "80–90% White / 10–20% Rainbow" แต่เมื่อถามยืนยันตรงๆ ผ่าน popup Founder เลือก **"ให้ AI Design เสนอทางเลือกเปรียบเทียบก่อนตัดสิน"** แทนที่จะล็อกทันที (ต่างจากตอนตัดสิน DS-001 ที่ Founder ก็ขอดูตัวอย่างก่อนเลือกเช่นกัน)

Target User: Founder (ผู้ตัดสินใจ) — ผลกระทบท้ายสุดคือผู้ใช้ WYN Social ทุกคนถ้าเปลี่ยนจริง

Problem: Cyan `#00C8FF` + Orange `#FF6B35` เพิ่งถูกเลือกและ implement ผ่าน DS-001 ถึง DS-008 ครบ 45 หน้าจอทั้งสองแอปไปแล้ว (2026-08-15) — การเปลี่ยนสีอีกครั้งเป็นงาน blast-radius สูงสุดเท่าที่เคยทำในโปรเจกต์ ถ้าไม่ดูตัวอย่างจริงก่อนอาจต้องเปลี่ยนซ้ำเป็นครั้งที่ 3

Requirements:

R1. ทำหน้าจอเปรียบเทียบ (เหมือน pattern ที่ทำสำเร็จมาแล้วตอน DS-001) แสดง **อย่างน้อย 2 ทางเลือก**:
   - ทางเลือก A: "Rainbow เต็มรูปแบบ" — แทนที่ Cyan ด้วย Rainbow gradient/multi-color บนพื้นขาว 80-90% ตามสเปกตรงตัว
   - ทางเลือก B: "Cyan เดิม + Rainbow เป็น accent เสริม" — คง Cyan เป็น primary แต่เพิ่มจุด Rainbow gradient ในบางจุด (เช่น highlight/active state/Story ring ถ้ามี) ตามที่ Founder เสนอเป็นทางเลือกไว้เอง
R2. แสดงทั้ง Light mode และ Dark mode ของทั้งสองทางเลือก (ตาม pattern เดิมของ DS-001 ที่ Founder ขอดูทั้งสองโหมดเสมอ)
R3. ใช้หน้าจอจริงที่มีอยู่แล้วเป็นตัวอย่าง (Home feed, Drop card, Profile) ไม่ทำ mockup แยกลอย ๆ เพื่อให้ Founder เห็นผลจริงตามที่เคยทำสำเร็จ
R4. ตรวจ WCAG AA contrast ratio ของทุกทางเลือกเหมือนที่ DS-001 เคยทำไว้ (บันทึกผลไว้ให้ Founder เห็นความเสี่ยงก่อนตัดสิน — Rainbow gradient มีความเสี่ยง contrast สูงกว่า solid color เดี่ยว ต้องตรวจเป็นพิเศษ)
R5. เก็บ ZOKY Orange `#FF6B35` ไว้พิจารณาแยก — ถ้า Founder เลือกเปลี่ยน WYN primary เป็น Rainbow ต้องถามต่อว่า ZOKY (ที่ถูกพักไว้ V2 แล้ว) ควรเปลี่ยนตามหรือคงเดิม (ความสำคัญต่ำเพราะ ZOKY ไม่แสดงผลใน `app/` แล้วหลัง WYN-024)

Acceptance Criteria:
- [ ] มีหน้าเปรียบเทียบอย่างน้อย 2 ทางเลือก × 2 โหมด (light/dark) = 4 ภาพ/สถานะ อย่างน้อย
- [ ] ใช้ข้อมูล/หน้าจอจริงของแอป ไม่ใช่ mockup
- [ ] มีตาราง contrast ratio ประกอบการตัดสินใจ
- [ ] Founder ตัดสินใจผ่าน popup ว่าจะเลือกทางเลือกไหน (หรือคงของเดิมทั้งหมด) ก่อนส่งต่อ AI Coding

Dependencies: ไม่มี hard dependency ทางเทคนิค — แต่เป็น **blocker เชิง priority** ของ Phase 0 เพราะทุกหน้าจอใหม่ตั้งแต่ Phase 1 เป็นต้นไปควรรู้สีสุดท้ายก่อนเริ่มออกแบบ ไม่งั้นเสี่ยง rework ซ้ำ

Priority: สูงสุด (เท่ากับ WYN-024) — ทั้งคู่เป็น Phase 0

Risks: ความเสี่ยงด้าน accessibility ของ Rainbow gradient สูงกว่า solid color — ต้องแจ้ง Founder ให้ชัดเหมือนที่เคยทำตอน DS-001 (Cyan/Orange บนพื้นขาวก็ต่ำกว่า WCAG AA อยู่แล้ว Rainbow อาจแย่กว่าถ้าไม่ระวัง)

Recommendation: ทำคู่ขนานกับ WYN-024 (Bottom Nav) ได้ทันที เพราะเป็นคนละไฟล์/คนละทีมงานในเชิงเนื้อหา (nav structure vs color token) — ไม่ต้องรอกัน

Handoff: ส่งต่อ AI Design (`/design`) เพื่อทำหน้าเปรียบเทียบ แล้วนำกลับมาถาม Founder ผ่าน popup ก่อนส่งต่อ AI Coding
