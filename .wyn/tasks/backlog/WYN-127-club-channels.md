# Product Task — WYN-127

Status: backlog
Owner: AI Product Manager

Feature: Club Channels — แบ่งการพูดคุยภายใน Club เป็นหลายห้อง แทนที่ฟีดเดียวรวมทุกเรื่อง

Goal: ทำให้ Club รู้สึกเหมือน Discord server จริง (มีหลาย # channel แยกหัวข้อ) แทนที่การโยนทุกโพสต์ (คุยเล่น, ประกาศ, ถามตอบ) ลงฟีดเดียวปนกันหมดแบบ Facebook Group — ดู `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` ข้อ 1

Target User: สมาชิกและ Owner/Admin ของทุก Club ที่มีเนื้อหาหลากหลายพอจะแยกหมวดได้ (Club เล็กมากอาจใช้แค่ #general ก็พอ ไม่บังคับสร้างหลาย channel)

Problem: ตอนนี้ `club_posts` ทุกโพสต์อยู่ใน feed เดียวของ Club ไม่ว่าจะเป็นเรื่องประกาศสำคัญ คุยเล่นทั่วไป หรือถามตอบเฉพาะทาง — สมาชิกที่สนใจแค่ประกาศต้องไถผ่านโพสต์คุยเล่นทั้งหมดก่อนเจอ ทำให้ Club ไม่มีความรู้สึก "หลายห้อง" แบบ Discord เลย

Requirements:
1. Owner/Admin สร้าง/แก้ไข/ลบ channel ภายใน Club ได้ (ชื่อ channel, ไอคอน/emoji ประจำ channel ไม่บังคับ) — Club ใหม่ทุกอันมี channel default ชื่อ "ทั่วไป" (#general) ให้อัตโนมัติ ไม่ต้องสร้างเอง
2. โพสต์ใหม่ทุกโพสต์ต้องเลือก channel ที่จะลงเสมอ (default = channel ที่กำลังเปิดดูอยู่ ถ้าเข้ามาจาก channel นั้น)
3. หน้า Posts tab ของ Club แสดงรายการ channel เป็นแถบ/dropdown ให้สลับดู แต่ละ channel มีฟีดของตัวเอง ไม่ปนกัน
4. Pinned Post (ที่มีอยู่แล้ว) ผูกกับ channel ที่มันอยู่ ไม่ใช่ pin ข้าม channel
5. จำนวน channel ต่อ Club มี cap สมเหตุสมผล (เช่นไม่เกิน 20) กัน spam สร้าง channel เยอะเกินจำเป็น — ตัวเลขจริงให้ Design ตัดสินใจ
6. ลบ channel ที่มีโพสต์อยู่แล้วต้องมี confirm ชัดเจนว่าโพสต์ในนั้นจะหายไปด้วย (หรือย้ายไป #general — ให้ Design เลือกแนวทาง)

Acceptance Criteria:
- สร้าง Club ใหม่ → มี channel "#ทั่วไป" อัตโนมัติ โพสต์แรกลงในนั้นได้ทันทีไม่ต้องตั้งค่าอะไรเพิ่ม
- Owner สร้าง channel ใหม่ (เช่น "#ประกาศ") → สมาชิกเห็น channel ใหม่ในรายการ สลับไปดูฟีดที่แยกจาก #ทั่วไปได้จริง
- โพสต์ที่สร้างใน channel A ไม่ปรากฏเมื่อเปิดดู channel B
- สมาชิกทั่วไป (ไม่ใช่ Owner/Admin) มองเห็นรายการ channel และสลับดูได้ แต่สร้าง/ลบ channel ไม่ได้
- ลบ channel ที่มีโพสต์ → มี dialog ยืนยันชัดเจนก่อนเสมอ ไม่ลบเงียบๆ

Dependencies: ต่อยอดตาราง `club_posts` เดิม (WYN-014) — ไม่ใช่ระบบใหม่ทั้งหมด แค่เพิ่มมิติ channel เข้าไป ไม่กระทบ Posts/Events/Insights tab ที่มีอยู่แล้ว (Events/Insights ยังคงเป็นข้อมูลระดับ Club ไม่ใช่ระดับ channel)

Priority: **สูง** — ต้นทุนต่ำ (ต่อยอดของเดิม ไม่ใช่ระบบใหม่) แต่แก้ปัญหา "ไม่เหมือน Discord" ที่คนสังเกตเห็นเร็วที่สุด ควรทำก่อน WYN-128 (Club Group Chat) เพื่อพิสูจน์ demand ก่อนลงทุนหนักในแชทสด

Risks:
- Club ที่มีสมาชิกน้อย/โพสต์น้อยอาจรู้สึกว่าแยก channel เป็นภาระเกินจำเป็น (over-engineering สำหรับ Club เล็ก) — บรรเทาด้วย default channel เดียวที่ใช้งานได้ปกติทันทีไม่ต้องตั้งค่าเพิ่ม ใครไม่อยากแยกก็ไม่ต้องสร้าง channel เพิ่มเลย
- ต้อง migrate โพสต์เก่าที่มีอยู่แล้วในทุก Club ปัจจุบันเข้า channel default โดยไม่ทำโพสต์หายหรือเปลี่ยนสิทธิ์การมองเห็น — Coding ต้องระวังเรื่อง data migration เป็นพิเศษ (ไม่ใช่ fresh schema ล้วนๆ เหมือนงานก่อนๆ)

Recommendation: เริ่ม Design ได้เลย — ประเด็นที่ต้องตัดสินใจในขั้น Design คือ (ก) UI การสลับ channel (แถบแนวนอน vs dropdown vs side drawer แบบ Discord จริง) (ข) cap จำนวน channel (ค) ลบ channel แล้วโพสต์เดิมไปไหน

Handoff: ส่งต่อ AI Design ออกแบบ UI การสลับ/จัดการ channel และ data migration plan → AI Coding → AI QA & Security (ตรวจ migration ไม่ทำโพสต์เก่าหาย, ตรวจสิทธิ์สร้าง/ลบ channel เฉพาะ Owner/Admin, ตรวจ pinned post ผูก channel ถูกต้อง)
