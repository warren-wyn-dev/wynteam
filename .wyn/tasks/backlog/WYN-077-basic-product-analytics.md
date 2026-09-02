# Product Task — WYN-077

Status: backlog
Owner: AI Product Manager
Feature: Basic Product Analytics (Signup Funnel + Retention)
Goal: ทำให้วัดผล Go-To-Market ได้จริง (ตอนนี้วัดไม่ได้เลย — ยืนยันจาก scope ของ WYN-050 Admin Dashboard ที่ต้องเลื่อน DAU/WAU/MAU ออกเพราะ "ไม่มี analytics/session tracking เลย")
Target User: Internal (Founder + AI Product Manager ใช้ตัดสินใจ), ไม่ใช่ user-facing feature
Problem: ก่อนเริ่มโปรโมทวงกว้าง (ดู `.wyn/docs/product/wynos-gtm-roadmap.md` Phase 3) จำเป็นต้องรู้ว่า user มาจากช่องทางไหน, signup สำเร็จกี่ %, retain กี่วัน — ปัจจุบันไม่มีทางรู้เลยแม้แต่ข้อมูลพื้นฐานที่สุด
Requirements:
- เก็บ event ขั้นต่ำ: `signup_started`, `signup_completed`, `first_core_action` (Drop แรก/Pop แรก/Club join แรก — อย่างใดอย่างหนึ่ง), `session_start` (proxy ง่ายๆ พอ ไม่ต้องซับซ้อน)
- เก็บ UTM/source parameter ตอน signup (เผื่อใช้ตอน Phase 3 ทดสอบหลายช่องทาง) — ต้องระบุว่าเก็บยังไงกับ Flutter Web (query param ตอนเข้าเว็บครั้งแรก)
- Dashboard ดูผลได้อย่างน้อยแบบพื้นฐาน (ต่อยอด `admin_dashboard_metrics()` เดิมของ WYN-050 ถ้าเป็นไปได้ แทนที่จะสร้างระบบใหม่คู่ขนาน)
- **ต้องขออนุมัติ Founder ก่อนเริ่ม Coding**: เลือกระหว่าง (ก) เก็บ event เองใน Supabase table ใหม่ (ไม่มี third-party, ควบคุมข้อมูลได้เต็มที่ แต่ต้องสร้าง dashboard เอง) หรือ (ข) ใช้ third-party เช่น PostHog/Firebase Analytics (เร็วกว่า มี dashboard สำเร็จรูป แต่มีข้อมูล user ไหลออกไปนอกระบบ — เข้าข่าย "ความปลอดภัย/ข้อมูลผู้ใช้" ตาม RULES.md ต้องแจ้ง Founder ชัดๆ ว่าส่งอะไรออกไปบ้าง)
Acceptance Criteria:
- นับ signup ต่อวันได้ถูกต้อง (เทียบกับจำนวนแถวใหม่ใน `profiles` จริง)
- นับ D1/D7 retention ได้ (มี session_start อย่างน้อย 1 ครั้งในวันที่ 1/7 หลัง signup)
- ไม่มี PII (email/ชื่อจริง) หลุดไปอยู่ใน event data ถ้าเลือกใช้ third-party (ต้องเป็น Acceptance Criteria ที่ QA ตรวจจริง)
- ไม่เพิ่ม service-role key ใหม่เข้าระบบ (ต่อยอด pattern ของ WYN-049/050)
Dependencies: ต้องขออนุมัติแนวทาง (ก)/(ข) จาก Founder ก่อนส่งต่อ AI Design/Coding
Priority: P0 — เป็น blocker ของ Phase 2/3 ใน GTM roadmap (Phase 1 closed beta เริ่มได้โดยไม่ต้องรอ task นี้)
Risks: ถ้าเลือก third-party ต้องระวังเรื่อง PDPA (ข้อมูลผู้ใช้ไทยส่งไปประมวลผลนอกประเทศ) — ต้องแจ้ง Founder ก่อนตัดสินใจ ไม่ใช่ AI ตัดสินใจเอง
Recommendation: เริ่มจากแนวทาง (ก) เก็บเองใน Supabase ก่อน (ควบคุมความเสี่ยง PDPA ได้ง่ายกว่า, ต่อยอด `admin_dashboard_metrics()` เดิมได้ทันที) ยกเว้น Founder ต้องการ dashboard สำเร็จรูปเร็วกว่าและยอมรับความเสี่ยงข้อมูลไหลออก
Handoff: รอ Founder เลือกแนวทาง (ก)/(ข) ก่อน → AI Design → AI Coding → AI QA & Security
