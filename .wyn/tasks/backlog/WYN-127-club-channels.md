# Product Task — WYN-127

Status: active — Design เสร็จแล้ว (mockup Founder อนุมัติ 2026-09-07), handoff ให้ AI Coding
Owner: AI Product Manager → AI Design (เสร็จ) → AI Coding (ถัดไป)

Feature: Club Channels — แบ่งการพูดคุยภายใน Club เป็นหลายห้อง แทนที่ฟีดเดียวรวมทุกเรื่อง

Goal: ทำให้ Club รู้สึกเหมือน Discord server จริง (มีหลาย # channel แยกหัวข้อ) แทนที่การโยนทุกโพสต์ (คุยเล่น, ประกาศ, ถามตอบ) ลงฟีดเดียวปนกันหมดแบบ Facebook Group — ดู `.wyn/docs/product/wyn-club-discord-identity-roadmap.md` ข้อ 1

Target User: สมาชิกและ Owner/Admin ของทุก Club ที่มีเนื้อหาหลากหลายพอจะแยกหมวดได้ (Club เล็กมากอาจใช้แค่ #general ก็พอ ไม่บังคับสร้างหลาย channel)

Problem: ตอนนี้ `club_posts` ทุกโพสต์อยู่ใน feed เดียวของ Club ไม่ว่าจะเป็นเรื่องประกาศสำคัญ คุยเล่นทั่วไป หรือถามตอบเฉพาะทาง — สมาชิกที่สนใจแค่ประกาศต้องไถผ่านโพสต์คุยเล่นทั้งหมดก่อนเจอ ทำให้ Club ไม่มีความรู้สึก "หลายห้อง" แบบ Discord เลย

Requirements:
1. Owner/Admin สร้าง/แก้ไข/ลบ channel ภายใน Club ได้ (ชื่อ channel, ไอคอน/emoji ประจำ channel ไม่บังคับ) — Club ใหม่ทุกอันมี channel default ชื่อ "ทั่วไป" (#general) ให้อัตโนมัติ ไม่ต้องสร้างเอง
2. โพสต์ใหม่ทุกโพสต์ต้องเลือก channel ที่จะลงเสมอ (default = channel ที่กำลังเปิดดูอยู่ ถ้าเข้ามาจาก channel นั้น)
3. หน้า Posts tab ของ Club แสดงรายการ channel เป็นแถบ/dropdown ให้สลับดู แต่ละ channel มีฟีดของตัวเอง ไม่ปนกัน
4. Pinned Post (ที่มีอยู่แล้ว) ผูกกับ channel ที่มันอยู่ ไม่ใช่ pin ข้าม channel
5. **ไม่จำกัดจำนวน channel ต่อ Club** (Founder ยืนยัน 2026-09-07 — ไม่ต้องมี cap)
6. ลบ channel → **ลบโพสต์ในห้องนั้นทิ้งไปพร้อมกันทันที** ไม่ย้ายไป #ทั่วไป (Founder เลือกเอง "ประหยัดพื้นที่") — ต้องมี confirm dialog ชัดเจนก่อนเสมอว่าโพสต์จะหายไปถาวร

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

Recommendation: Design เสร็จแล้ว ดูหัวข้อ "AI Design Output" ด้านล่าง

Handoff: ส่งต่อ AI Coding → AI QA & Security (ตรวจ migration ไม่ทำโพสต์เก่าหาย, ตรวจสิทธิ์สร้าง/ลบ channel เฉพาะ Owner/Admin, ตรวจ pinned post ผูก channel ถูกต้อง, ตรวจลบ channel ลบโพสต์จริงไม่ทิ้งขยะ orphan record)

## AI Design Output

Screen: Club Page → Posts tab (เพิ่มแถบ channel switcher เหนือฟีด) + Club Page → Group Chat tab ใหม่ (ดู WYN-128, ใช้แถบ channel switcher หน้าตาเดียวกัน)

Purpose: ให้สมาชิกเลือกดูเฉพาะห้องที่สนใจ แทนที่ฟีดเดียวปนกันหมด — mockup เต็ม: https://claude.ai/code/artifact/d08fb9ad-0757-486b-9808-9c65cbe1d9b7 (แท็บ "WYN-127 Channels", Founder อนุมัติ 2026-09-07)

User Flow: เปิด Club Page → แถบ channel อยู่เหนือฟีด (เริ่มที่ #ทั่วไป เสมอ) → แตะห้องอื่นเพื่อสลับฟีด → กด "+ ห้องใหม่" (Owner/Admin เท่านั้น) เปิด dialog ตั้งชื่อห้อง → สร้างโพสต์ใหม่จากภายในห้องใด ห้องนั้นเป็น default channel ของโพสต์

Components:
- Channel chip row: แถบเลื่อนแนวนอน (`ListView` horizontal), chip ทรงเม็ดยา (`radiusFull`) — ห้องที่เลือกอยู่: พื้นหลัง sapphire ตัวอักษรขาว, ห้องอื่น: ขอบ hairline ตัวอักษร graphite
- ปุ่ม "+ ห้องใหม่" เป็น chip ท้ายแถวเสมอ ขอบเส้นประ สี mutedNeutral, มองเห็นได้ทุกคนแต่กดได้เฉพาะ Owner/Admin (สมาชิกทั่วไปกดแล้วไม่มีอะไรเกิดขึ้น หรือซ่อนไปเลย — ให้ Coding เลือกซ่อนไปเลยง่ายกว่า สอดคล้องกับ pattern ของปุ่มจัดการอื่นในระบบ)
- Dialog สร้าง/แก้ไข channel: ช่องกรอกชื่อ (จำกัดความยาว, กันชื่อว่าง/ซ้ำ), ปุ่มยืนยัน/ยกเลิกมาตรฐาน
- Dialog ลบ channel: ข้อความเตือนชัดเจนว่าโพสต์ในห้องนี้จะหายไปถาวร (ไม่ใช่ dialog ยืนยันทั่วไปแบบเบาๆ) ปุ่มลบใช้สี error

Interactions: แตะ chip → สลับฟีดทันที (ไม่ reload ทั้งหน้า), กด "+ ห้องใหม่" → bottom sheet/dialog ตั้งชื่อ, long-press หรือปุ่ม "..." บน chip (Owner/Admin) → แก้ไขชื่อ/ลบห้อง

States: ห้องว่างไม่มีโพสต์ → empty state เดียวกับที่ Posts tab ใช้อยู่แล้ว (ไม่ต้องออกแบบใหม่), กำลังลบห้อง → loading state บน dialog, ห้องเดียว (#ทั่วไป อย่างเดียว ยังไม่สร้างเพิ่ม) → แถบ channel ยังโชว์อยู่ (ไม่ซ่อนทั้งแถบ) เพื่อให้เห็นว่ากดสร้างห้องใหม่ได้ตรงไหน

Responsive Behavior: แถบ channel เลื่อนแนวนอนได้ไม่จำกัดจำนวน (ตามที่ Founder ยืนยันไม่จำกัด) ไม่ wrap หลายบรรทัด

Accessibility: แต่ละ chip เป็น tap target ขั้นต่ำ 44px ตาม `WynSpacing.touchTargetMin`, ห้องที่เลือกอยู่ต้องสื่อสารได้ทั้งสี+ตัวหนา (ไม่ใช่สีอย่างเดียว) กันปัญหา color-blind

Design Rules: ห้ามใช้สีอื่นนอกจาก sapphire เป็น active state (ตาม design system เดิม), ห้ามเปลี่ยน layout ของการ์ดโพสต์เดิมเลย (แค่กรองตาม channel เฉยๆ)

Handoff: AI Coding (schema: เพิ่มตาราง `club_channels` + คอลัมน์ `channel_id` บน `club_posts`, backfill ทุกโพสต์เดิมเข้า channel default "#ทั่วไป" ที่สร้างให้ทุก Club ที่มีอยู่แล้วอัตโนมัติ) → AI QA & Security
