# Product Task — WYN-077

Status: active
Owner: AI Product Manager
Feature: Basic Product Analytics (Signup Funnel + Retention)
Goal: ทำให้วัดผล Go-To-Market ได้จริง (ตอนนี้วัดไม่ได้เลย — ยืนยันจาก scope ของ WYN-050 Admin Dashboard ที่ต้องเลื่อน DAU/WAU/MAU ออกเพราะ "ไม่มี analytics/session tracking เลย")
Target User: Internal (Founder + AI Product Manager ใช้ตัดสินใจ), ไม่ใช่ user-facing feature
Problem: ก่อนเริ่มโปรโมทวงกว้าง (ดู `.wyn/docs/product/wynos-gtm-roadmap.md` Phase 3) จำเป็นต้องรู้ว่า user มาจากช่องทางไหน, signup สำเร็จกี่ %, retain กี่วัน — ปัจจุบันไม่มีทางรู้เลยแม้แต่ข้อมูลพื้นฐานที่สุด
Requirements:
- เก็บ event ขั้นต่ำ: `signup_started`, `signup_completed`, `first_core_action` (Drop แรก/Pop แรก/Club join แรก — อย่างใดอย่างหนึ่ง), `session_start` (proxy ง่ายๆ พอ ไม่ต้องซับซ้อน)
- เก็บ UTM/source parameter ตอน signup (เผื่อใช้ตอน Phase 3 ทดสอบหลายช่องทาง) — ต้องระบุว่าเก็บยังไงกับ Flutter Web (query param ตอนเข้าเว็บครั้งแรก)
- Dashboard ดูผลได้อย่างน้อยแบบพื้นฐาน (ต่อยอด `admin_dashboard_metrics()` เดิมของ WYN-050 ถ้าเป็นไปได้ แทนที่จะสร้างระบบใหม่คู่ขนาน)
- **แนวทางยืนยันแล้ว (Founder อนุมัติ 2026-09-02)**: เก็บ event เองใน Supabase table ใหม่ (ไม่ใช้ third-party) — ไม่มีข้อมูลผู้ใช้ไหลออกนอกระบบ ต่อยอด `admin_dashboard_metrics()` เดิมของ WYN-050 สำหรับ dashboard แทนที่จะสร้างระบบใหม่คู่ขนาน
Acceptance Criteria:
- นับ signup ต่อวันได้ถูกต้อง (เทียบกับจำนวนแถวใหม่ใน `profiles` จริง)
- นับ D1/D7 retention ได้ (มี session_start อย่างน้อย 1 ครั้งในวันที่ 1/7 หลัง signup)
- ไม่มี PII (email/ชื่อจริง) หลุดไปอยู่ใน event data โดยไม่จำเป็น (ต้องเป็น Acceptance Criteria ที่ QA ตรวจจริง)
- ไม่เพิ่ม service-role key ใหม่เข้าระบบ (ต่อยอด pattern ของ WYN-049/050)
- RLS ของ event table ใหม่ปิดไม่ให้ client อ่าน event ของ user คนอื่นได้ (insert-only จาก client ตัวเอง, อ่าน aggregate ได้เฉพาะผ่าน RPC role admin เหมือน `admin_dashboard_metrics()`)
Dependencies: ไม่มี — พร้อมส่งต่อ AI Design ได้ทันที
Priority: P0 — เป็น blocker ของ Phase 2/3 ใน GTM roadmap (Phase 1 closed beta เริ่มได้โดยไม่ต้องรอ task นี้)
Risks: เก็บเองใน Supabase ต้องระวังไม่ให้ event table เพิ่ม attack surface ใหม่ (RLS ต้องปิดไม่ให้ client อ่าน event ของคนอื่น) — ระบุเป็น Acceptance Criteria ให้ QA ตรวจ
Recommendation: เริ่ม Design ได้ทันที
Handoff: **Design spec เสร็จแล้ว** (`.wyn/docs/design/wyn-077-basic-product-analytics.md`) — ส่งต่อ AI Coding ทันที → AI QA & Security
