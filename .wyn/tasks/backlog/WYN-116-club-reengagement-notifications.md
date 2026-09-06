# Product Task — WYN-116

Status: backlog
Owner: AI Product Manager

Feature: Club Re-engagement Notifications — แจ้งเตือนสมาชิกเมื่อ Club ที่เข้าร่วมมีความเคลื่อนไหวใหม่

Goal: ดึงสมาชิกกลับมาเปิดแอปอีกครั้งหลังเข้าร่วม Club แล้ว — ตรงกับปัญหา "engagement เป็นศูนย์หลังสมัคร" ที่ WYN-112 กำลังสืบอยู่โดยตรง (ถ้าไม่มีอะไรดึงกลับมา คนที่เพิ่งเข้าร่วม Club ก็จะเงียบหายไปเหมือนที่เกิดขึ้นแล้ว)

Target User: สมาชิกที่ approved ของ Club อย่างน้อย 1 Club

Problem: ตอนนี้ระบบแจ้งเตือนของ Club ครอบแค่ "มีคนตอบโพสต์ฉัน/กด Like โพสต์ฉัน/mention ฉัน" (แจ้งเตือนที่เกี่ยวกับตัวผู้ใช้เองโดยตรง) — ไม่มีการแจ้งเตือนแบบ "Club ของคุณมีอะไรใหม่" เลย (โพสต์ใหม่จากคนอื่นใน Club, ประกาศ/Pinned post ใหม่จาก Admin) ซึ่งเป็นแรงดึงกลับที่ Facebook Group/Discord ใช้เป็นหลัก

Requirements:
- แจ้งเตือนเมื่อ Club ที่เข้าร่วมมี Pinned Post ใหม่ (ให้ความสำคัญสูงสุด เพราะเป็นสิ่งที่ Admin ตั้งใจให้ทุกคนเห็น)
- แจ้งเตือนเมื่อ Club มีโพสต์ใหม่ (ต้อง throttle/รวมเป็นก้อนถ้าโพสต์บ่อย ไม่ใช่ยิงทุกโพสต์ทันที ป้องกัน notification fatigue) — ให้ Design ตัดสินใจ threshold/ความถี่ที่เหมาะสม
- ผู้ใช้ปิดแจ้งเตือนได้ต่อ Club (ไม่ใช่ all-or-nothing ทั้งแอป) — ต่อยอด notification preference system ที่มีอยู่แล้ว (WYN-043 mapping 7 หมวด รวม "club" อยู่แล้ว)
- ใช้ Push Notification (Firebase) ที่โค้ดพร้อมอยู่แล้วตาม `wynos-gtm-roadmap.md` — ถ้า Firebase project จริงยังไม่ config ให้ทำ in-app notification (กระดิ่ง) ก่อน แล้ว push message ตามทีหลังเมื่อ Firebase พร้อม (ไม่ block งานนี้)

Acceptance Criteria:
- สมาชิก Club เห็นแจ้งเตือนโพสต์ Pin ใหม่ทุกครั้งที่เกิดขึ้นจริง
- สมาชิก Club เห็นแจ้งเตือนโพสต์ใหม่แบบไม่ถี่จนรำคาญ (ตาม threshold ที่ Design กำหนด และ QA ทดสอบจริง)
- ปิดแจ้งเตือนเฉพาะ Club หนึ่งได้โดยไม่กระทบ Club อื่น/แจ้งเตือนประเภทอื่น

Dependencies: **ต้องรอ/ตรวจสอบสถานะ Firebase project จริงก่อน** (ตาม `wynos-gtm-roadmap.md` ข้อจำกัดที่ 5 — โค้ด Push พร้อมแต่ยังรอ config จริง) ถ้ายังไม่พร้อม ให้ทำ in-app notification ส่วนก่อนตามที่ระบุใน Requirements

Priority: P1 — Founder เลือกเป็นลำดับ 2 ใน Club Growth Roadmap

Risks: Notification fatigue ถ้า throttle ไม่ดี (คนปิดแจ้งเตือนทั้งหมดเลยแทนที่จะแค่ลดความถี่) — ต้องให้ Design คิด threshold รอบคอบ ไม่ใช่ยิงทุก event ทันที

Recommendation: เริ่ม Design คู่ขนานกับ WYN-115 ได้ (ไม่ทับซ้อนกัน) แต่ Coding ควรรอ WYN-114 (fix link) deploy ก่อน เพราะ deep link ที่ถูกต้องจำเป็นสำหรับให้แจ้งเตือนพาไปเปิด Club ที่ถูกต้องได้จริง

Handoff: AI Design (โดยเฉพาะเรื่อง throttle threshold + preference UI) → AI Coding → AI QA & Security
