# Design Task — WYN-160

Status: backlog
Owner: AI Design
Screen: ทั้งระบบเว็บ (WYN-158) เริ่มจากหน้าล็อกอิน/สมัคร/onboarding ตามที่ Founder สั่ง
Purpose: บังคับใช้ design system ที่อนุมัติแล้ว (`wynos-web-base-design-system.md`) ให้ตรงกันทุกหน้า — ไม่ใช่คิดสีใหม่ แต่ยุบตัวเลขที่หลุดสเปกไปแล้ว (font-size ~20 ค่า → 7 ค่า, border-radius ~20 ค่า → 5 ค่า, สีเทาที่ hardcode ใหม่ใน conversation-modern.css → กลับไปใช้ var(--wyn-*))
User Flow: ไม่เปลี่ยน — งาน token-level เท่านั้น
Components: เพิ่ม 3 primitive ที่ base doc เดิมยังไม่ครอบ (Card, Modal/Sheet, Tab/Pill) ต่อยอดจาก Button/Input/Avatar/PostCard/BottomNav/TopBar เดิม
Interactions: ไม่เปลี่ยน
States: ไม่มี state ใหม่
Responsive Behavior: ไม่เปลี่ยน breakpoint เดิม
Accessibility: คงมาตรฐานเดิม (44px touch target, AA contrast) — จุดนี้เว็บทำได้ดีอยู่แล้ว
Design Rules: ดูตารางเต็มที่ `.wyn/docs/design/wyn-160-web-design-system-consolidation.md` — สรุปสั้น: token สีห้าม hardcode hex, font-size ใช้ 7 ระดับ (12/13/14/16/17/20/22px), border-radius ใช้ 5 ระดับ (999/20/14/10/2-4px)
Handoff: rollout ทีละหน้าตามลำดับ (1) ประกาศ CSS variable กลาง (2) Auth/Login/Signup (3) Home/Nav (4) Composer (5) Chat — เฉพาะ conversation-modern.css เร่งก่อนสุดในกลุ่มนี้ (6) Profile/Settings (7) Search/Notifications/Club (8) ไล่ลบ CSS dead code — ต้องมีภาพก่อน-หลังของหน้าล็อกอินให้ Founder อนุมัติก่อนเริ่มโค้ดจริง ตามกติกา WYN-141
