# Design Task — WYN-147

Status: backlog
Owner: AI Design
Screen: Pop (create_pop, pop_feed, pop_single_clip)
Purpose: สเปก restyle 3 หน้าจอฟีเจอร์ Pop (คลิปสั้นแนวตั้ง) ให้ใช้ visual identity "Flare" (wyn-142/wyn-143) แทนโทน Sapphire เดิม — ⚠️ ต้องยืนยัน scope กับ PM ก่อน (`wyn-v1.0.0-master-spec.md` ระบุ Pop ไม่อยู่ใน scope V1.0 และ Founder เคยสั่งระงับการพัฒนาต่อยอด Pop ไว้ 2026-08-14) ดูรายละเอียดใน design doc
User Flow: Pop Feed (แท็บ Pop, ฟีดวิดีโอแนวตั้งปัดทีละคลิป) → Create Pop (เลือก/ถ่ายวิดีโอสูงสุด 60 วิ + แคปชัน + โพสต์) และ Pop Single Clip (เปิดคลิปเดียวจาก Home Pop card แบบไม่ paginate) — รายละเอียดเต็มในเอกสาร
Components: Media Viewer/Carousel, Avatar, Primary/Secondary/Text Button, Text Input, Bottom Sheet, List Item, Modal (ยืนยันลบ), Toast, Spinner, Empty State, Top App Bar
Interactions: ดูรายละเอียดในเอกสาร
States: ดูรายละเอียดในเอกสาร
Responsive Behavior: ดูรายละเอียดในเอกสาร
Accessibility: ดูรายละเอียดในเอกสาร
Design Rules: ดูรายละเอียดทั้งหมดใน `.wyn/docs/design/wyn-147-pop.md`
Handoff: รอ PM ยืนยัน scope + Founder ยืนยัน wyn-142/wyn-143 ก่อนส่งต่อ AI Coding
