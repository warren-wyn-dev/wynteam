# Design Task — WYN-182

Status: active — design spec approved by Founder, ready for AI Coding
Owner: AI Design
Screen: แท็ปบาร์ล่าง (bottom navigation) ทั้งระบบเว็บ — `web/components/bottom-navigation.tsx`, `web/app/bottom-nav.css`
Purpose: ปรับ active/inactive treatment เป็น outline→filled icon (ไม่มีสี/chip/เส้น) + บาร์แบนราบไม่มีปุ่มยกลอย + เพิ่ม spacing ให้โปร่งขึ้น — 3 ลักษณะที่ Founder เลือกจากการอ้างอิง "เหมือนเธรด" (ไม่ใช่การก็อปทั้งหน้าจอ ตาม DS-001 ข้อ 2)
User Flow: ไม่เปลี่ยน
Components: ดูสเปกเต็มที่ `.wyn/docs/design/wyn-182-bottom-nav-filled-active-spacious.md`
Interactions: ดูสเปกเต็ม — เพิ่ม padding/gap ของ `.route-nav-link`, ไม่แตะ bar height
States: ดูสเปกเต็ม — filled icon ตอน active, ไม่มีสี/chip/เส้น
Responsive Behavior: ปรับสัดส่วน padding/gap ทั้ง 3 breakpoint, ต้อง verify ด้วย DOM measurement จริง
Accessibility: ไม่เปลี่ยน aria-label/touch target/contrast (สีเดิมทั้งหมด)
Design Rules: ห้ามก็อปโครงหน้าจอ/ปุ่ม/interaction ของ Threads, ไม่ใช้ accent แดง, ไม่แตะ bar height/icon size ที่เพิ่งอนุมัติใน WYN-179/180, 5 แท็บเดิมไม่เปลี่ยนลำดับ/ชื่อ
Handoff: → **AI Coding**: แก้ `web/components/bottom-navigation.tsx` (filled SVG variant ของ club/chat/profile ตอน selected) + `web/app/bottom-nav.css` (padding/gap ใหม่) → รัน `npm run check` → ส่งต่อ **AI QA & Security**

อ้างอิง: spec ฉบับเต็ม `.wyn/docs/design/wyn-182-bottom-nav-filled-active-spacious.md`, Artifact เปรียบเทียบ https://claude.ai/artifact/P2sAcfYmzKwDBU71UYE8BG, decision log `.wyn/company/DECISIONS.md` (2026-09-20, "WYN-182")
