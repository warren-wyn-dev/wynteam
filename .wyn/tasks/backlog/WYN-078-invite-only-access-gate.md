# Product Task — WYN-078

Status: backlog
Owner: AI Product Manager
Feature: Invite-Only Access Gate (Referral Code)
Goal: ควบคุมอัตราการไหลเข้าของผู้ใช้ใหม่ให้ทีมรับมือไหว (bug/feedback/moderation) และวัด viral loop ได้จริง ก่อนเปิด public signup เต็มรูปแบบ
Target User: ผู้ใช้ใหม่ที่สมัคร WYNOS ระหว่าง Phase 2 (Community Soft Launch) ของ `.wyn/docs/product/wynos-gtm-roadmap.md`
Problem: ตอนนี้ไม่มีระบบ invite/referral เลย — สมัครได้อิสระ (Google Sign-in หรือ email อะไรก็ได้ ไม่ต้องยืนยัน) ทำให้ (ก) ควบคุมจำนวนคนเข้าใหม่ไม่ได้ (ข) วัดไม่ได้ว่า user เดิมชวนเพื่อนมากี่คน (viral coefficient)
Requirements:
- Referral code ต่อ user 1 คน (สร้างอัตโนมัติตอน signup สำเร็จ หรือหลังทำ core action แรกก็ได้ — Design ตัดสินใจ)
- หน้าจอ redeem code ก่อนเข้าถึง signup จริง (หรือ query param ฝัง code ในลิงก์เชิญ เพื่อลดแรงเสียดทาน)
- Track ว่า code ไหนพา user ใหม่เข้ามากี่คน (ต่อยอด WYN-077 event tracking ถ้าเสร็จก่อน)
- Toggle เปิด/ปิดระบบ invite-gate ได้จาก config ง่ายๆ (ไม่ต้อง deploy ใหม่ทุกครั้งที่จะเปิด public เต็มรูปแบบตอน Phase 3)
- Admin ควรเห็นจำนวน invite ที่ใช้ไปได้ (ต่อยอด `admin/` ที่มีอยู่แล้วถ้าเวลาเอื้อ ไม่ block ถ้าทำไม่ทัน)
Acceptance Criteria:
- User ที่ไม่มี code ที่ถูกต้อง สมัครเข้าระบบไม่ได้ (ตอน invite-gate เปิดอยู่)
- Code ของ user แต่ละคนใช้ซ้ำได้หลายครั้ง (ไม่ใช่ single-use) เพื่อให้ชวนเพื่อนได้มากกว่า 1 คน เว้นแต่ Founder ต้องการจำกัดจำนวนต่อ code (ถามตอน Design)
- ปิด invite-gate ได้โดยไม่กระทบ user ที่สมัครไปแล้ว
Dependencies: ควรทำหลัง/คู่ขนานกับ WYN-077 (Analytics) เพื่อ track ผลได้ตั้งแต่วันแรก แต่ไม่ block กัน
Priority: P1 — จำเป็นก่อนเข้า Phase 2 ของ GTM roadmap ไม่ใช่ blocker ของ Phase 1 (closed beta ใช้การเชิญตรงแบบ manual ไปก่อนได้)
Risks: ถ้าออกแบบ single-use code ผิดตอนแรกแล้วเปลี่ยนทีหลัง อาจงงกับ code ที่แจกไปแล้ว — ควรถาม Founder เรื่อง single-use vs multi-use ตั้งแต่ spec นี้เลย
Recommendation: เริ่ม Design ได้เลย ไม่ต้องรอ WYN-077 เสร็จก่อน (ทำคู่ขนานได้)
Handoff: ส่งต่อ AI Design เพื่อออกแบบหน้าจอ redeem code + decide multi-use vs single-use
