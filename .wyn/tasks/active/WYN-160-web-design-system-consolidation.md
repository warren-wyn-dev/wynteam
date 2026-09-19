# Design Task — WYN-160

Status: active — เฟส 0 (Button Interaction Spec) เขียนเสร็จแล้ว รอ Founder อนุมัติก่อนแตะโค้ด
Owner: AI Design
Screen: ทั้งระบบเว็บ (WYN-158) เริ่มจากหน้าล็อกอิน/สมัคร/onboarding ตามที่ Founder สั่ง
Purpose: บังคับใช้ design system ที่อนุมัติแล้ว (`wynos-web-base-design-system.md`) ให้ตรงกันทุกหน้า — ไม่ใช่คิดสีใหม่ แต่ยุบตัวเลขที่หลุดสเปกไปแล้ว (font-size ~20 ค่า → 7 ค่า, border-radius ~20 ค่า → 5 ค่า, สีเทาที่ hardcode ใหม่ใน conversation-modern.css → กลับไปใช้ var(--wyn-*))

**[2026-09-19] ขยายขอบเขตรวม WYN-175 (System-wide Button Consistency) เข้ามาแล้ว** ตาม Founder ตัดสินใจ
("รวมเข้ากับ WYN-160 เป็นงานเดียว") — รายละเอียดเต็มอยู่ที่ `.wyn/tasks/backlog/WYN-175-system-wide-button-consistency.md`
(เก็บไว้เป็น reference ไม่ลบ) สรุปส่วนที่เพิ่มเข้ามา: ปุ่มทั่วระบบ (~72 class ใน `web/app/*.css`) มีแค่ 5
ไฟล์ที่มี `:active` state และ 3 ไฟล์ที่ใช้ motion token `scale(0.96)` (จาก WYN-169/170) — ต้องเพิ่ม
**Button Interaction Spec** (sizing/motion/danger-color/touch-target) เข้าไปใน
`wynos-web-base-design-system.md` เป็นส่วนหนึ่งของงานนี้ด้วย ไม่ใช่แค่ font-size/border-radius/สี
User Flow: ไม่เปลี่ยน — งาน token-level เท่านั้น
Components: เพิ่ม 3 primitive ที่ base doc เดิมยังไม่ครอบ (Card, Modal/Sheet, Tab/Pill) ต่อยอดจาก Button/Input/Avatar/PostCard/BottomNav/TopBar เดิม
Interactions: ไม่เปลี่ยน
States: ไม่มี state ใหม่
Responsive Behavior: ไม่เปลี่ยน breakpoint เดิม
Accessibility: คงมาตรฐานเดิม (44px touch target, AA contrast) — จุดนี้เว็บทำได้ดีอยู่แล้ว
Design Rules: ดูตารางเต็มที่ `.wyn/docs/design/wyn-160-web-design-system-consolidation.md` — สรุปสั้น: token สีห้าม hardcode hex, font-size ใช้ 7 ระดับ (12/13/14/16/17/20/22px), border-radius ใช้ 5 ระดับ (999/20/14/10/2-4px) — **บวก Button Interaction Spec ใหม่ (จาก WYN-175)**: motion token มาตรฐาน
`transform: scale(0.96)` บน `:active` + `transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1)`
+ `@media (prefers-reduced-motion: reduce)` เสมอ, ปุ่ม danger ใช้ `var(--wyn-accent)` เท่านั้น (ห้าม
hardcode เช่น `#d33c32` ที่เจอใน `wyn-note-delete`), touch target ≥44px สำหรับปุ่ม primary action
Handoff: **เฟส 0 (ใหม่ ก่อนเฟสอื่นทั้งหมด)** — AI Design เขียน Button Interaction Spec เพิ่มเข้า
`wynos-web-base-design-system.md` ก่อน ยังไม่แตะโค้ด ส่งให้ Founder อนุมัติ spec ก่อน จากนั้น rollout
ทีละหน้าตามลำดับเดิม: (1) ประกาศ CSS variable กลาง (2) Auth/Login/Signup (3) Home/Nav (4) Composer
(5) Chat — เฉพาะ conversation-modern.css เร่งก่อนสุดในกลุ่มนี้ (Chat Inbox ทำไปแล้วบางส่วนใน WYN-169/170/171
ใช้เป็น baseline เช็คว่าตรง spec ใหม่จริง) (6) Profile/Settings (7) Search/Notifications/Club (8) ไล่ลบ
CSS dead code — ต้องมีภาพก่อน-หลังของหน้าล็อกอินให้ Founder อนุมัติก่อนเริ่มโค้ดจริง ตามกติกา WYN-141
